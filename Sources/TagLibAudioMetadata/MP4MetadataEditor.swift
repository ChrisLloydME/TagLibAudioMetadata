import Foundation
import CTagLibBridge
import CTagLibBridgeInternalAPI

/// An editor row backed by one exact MP4 atom.
public struct MP4MetadataEditorField: Hashable, Sendable {
    public let field: MetadataFieldKey
    public let atomKey: String
    /// Nil represents an absent atom. Existing values, including legacy advisory
    /// codes, are reported as observed in the structured snapshot.
    public let atom: StructuredMP4Atom?

    public init(field: MetadataFieldKey, atomKey: String, atom: StructuredMP4Atom?) {
        self.field = field
        self.atomKey = atomKey
        self.atom = atom
    }
}

extension TagLibMetadataManager {
    nonisolated static let mp4EditorFieldKeys: [MetadataFieldKey] = [
        .itunesAlbumID,
        .itunesArtistID,
        .itunesCatalogID,
        .itunesGenreID,
        .itunesMediaType,
        .itunesPurchaseDate,
        .itunesAccount,
        .itunesComposerID,
        .itunesCountryID,
        .itunesHDVideo,
        .storeDescription,
        .explicitContent,
        .director,
        .publisher,
        .conductor,
    ]

    /// Edits the native fields reported by `MetadataSnapshot.editableMP4Fields`
    /// and an optional exact PropertyMap delta in one verified MP4 transaction.
    /// Use each field's schema value kind (`.integer` with codes 0, 1 and 2 for
    /// `.explicitContent`, `.integer` for Store IDs/media type, `.boolean` for
    /// `.itunesHDVideo`, `.text`/`.values` for native text atoms) and `.remove`
    /// to clear the selected atom. A native edit preserves legacy text aliases.
    /// Pass the reviewed version and, when rebasing, the baseline audio identity.
    @discardableResult
    public nonisolated static func applyMP4MetadataEditorPatch(
        _ nativeFields: [MetadataFieldKey: MetadataPatchValue],
        raw: RawMetadataPatch = RawMetadataPatch(),
        to url: URL,
        expectedVersion: MetadataFileVersion,
        expectedAudioContent: MetadataAudioContentIdentity? = nil
    ) throws -> MetadataWriteResult {
        guard capability(forExtension: url.pathExtension)?.identifier == "mp4",
              isWritableExtension(url.pathExtension) else {
            throw TagLibManagerError.unsupportedFormat
        }
        let raw = try validatedRawMetadataPatch(raw)
        let hasRawChanges = !raw.valuesToSet.isEmpty || !raw.removingKeys.isEmpty
        if nativeFields.isEmpty && !hasRawChanges {
            let version = try fileVersion(at: url)
            guard version == expectedVersion else { throw TagLibManagerError.fileChanged }
            if let expectedAudioContent {
                try requireAudioContent(at: url, matching: expectedAudioContent)
            }
            try MetadataProjectionReader.validateReadableAudioFile(at: url)
            guard version == (try? fileVersion(at: url)) else { throw TagLibManagerError.fileChanged }
            return MetadataWriteResult(warnings: [])
        }

        let atoms = try nativeFields.sorted { $0.key.rawValue < $1.key.rawValue }.map { field, value in
            guard mp4EditorFieldKeys.contains(field),
                  let schema = MetadataFieldRegistry.schema(for: field) else {
                throw MetadataPatchValidationError.unsupportedFieldForFormat(field: field, format: "MP4 metadata editor")
            }
            let expectedKinds: Set<MetadataPatchValueKind> = field == .explicitContent
                ? [.integer]
                : schema.acceptedPatchValueKinds
            if let kind = value.kind, !expectedKinds.contains(kind) {
                throw MetadataPatchValidationError.incompatibleValue(
                    field: field,
                    expected: expectedKinds,
                    actual: kind
                )
            }
            if case .integer(let number) = value {
                if field == .explicitContent {
                    guard (0...2).contains(number) else {
                        throw MetadataPatchValidationError.integerOutOfRange(field: field, minimum: 0, maximum: 2, actual: number)
                    }
                } else {
                    try validateInteger(number, field: field, schema: schema, formatIdentifier: "mp4")
                }
            }
            let normalizedValue = try value.normalized(location: field.rawValue)
            let storage = try semanticStorage(for: field, formatIdentifier: "mp4", formats: [.mp4])
            guard let atom = structuredMP4Atom(for: storage.mechanism, value: normalizedValue) else {
                throw MetadataPatchValidationError.unsupportedFieldForFormat(field: field, format: "MP4 metadata editor")
            }
            return atom
        }
        let atomEdits = Dictionary(uniqueKeysWithValues: atoms.map { ($0.key, $0) })
        let payload = bridgePayload(from: StructuredMetadata(mp4Atoms: atoms), includeProperties: false,
                                    replacingCollections: [], riffPolicy: .preserveInfo)

        return try MetadataFileTransaction.withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { staged in
            if let expectedAudioContent {
                try requireAudioContent(at: staged, matching: expectedAudioContent)
            }
            let before = try readSnapshot(from: staged)
            if hasRawChanges {
                try applyRawMetadataDeltaInPlace(raw.valuesToSet, removingKeys: raw.removingKeys, verify: false, to: staged)
            }
            if !atoms.isEmpty {
                try TagLibMetadataExtractor.writeStructuredMetadataInPlace(payload, to: staged)
            }
            let after = try readSnapshot(from: staged)
            try verifyRawMetadataDelta(raw, before: before.raw, after: after.raw)
            var failures = before.editableMP4Fields.compactMap { row -> String? in
                let actual = after.structured.mp4Atoms.first { $0.key == row.atomKey }
                let matches: Bool
                if let edit = atomEdits[row.atomKey] {
                    matches = mp4AtomMatchesEdit(actual, edit: edit)
                } else {
                    matches = actual == row.atom
                }
                return matches ? nil : "MP4 atom \(row.atomKey) differs after editor save."
            }
            if after.structured.artwork != before.structured.artwork {
                failures.append("MP4 artwork differs after editor save.")
            }
            failures.append(contentsOf: verifyUntouchedMP4Atoms(
                before: before.structured.mp4Atoms,
                after: after.structured.mp4Atoms,
                atomEdits: atomEdits,
                raw: raw,
                hasRawChanges: hasRawChanges
            ))
            try throwOnVerificationFailures(failures)
            return MetadataWriteResult(warnings: after.structured.warnings)
        }
    }

    private nonisolated static func expectedMP4AtomReadbackType(for edit: StructuredMP4Atom) -> String {
        switch edit.key {
        case "rtng": "byte"
        case "hdvd": "int"
        default: edit.type
        }
    }

    private nonisolated static func mp4AtomMatchesEdit(
        _ actual: StructuredMP4Atom?,
        edit: StructuredMP4Atom
    ) -> Bool {
        if edit.remove { return actual == nil }
        guard let actual else { return false }
        guard actual.type == expectedMP4AtomReadbackType(for: edit) else { return false }
        if edit.type == "stringList" {
            return actual.values == edit.values
        }
        return actual.value == edit.value
    }

    private nonisolated static func mp4ITunesFreeformDescription(for key: String) -> String? {
        let prefix = "----:com.apple.iTunes:"
        guard key.count > prefix.count,
              key.prefix(prefix.count).caseInsensitiveCompare(prefix) == .orderedSame else {
            return nil
        }
        return String(key.dropFirst(prefix.count))
    }

    private nonisolated static func verifyUntouchedMP4Atoms(
        before: [StructuredMP4Atom],
        after: [StructuredMP4Atom],
        atomEdits: [String: StructuredMP4Atom],
        raw: RawMetadataPatch,
        hasRawChanges: Bool
    ) -> [String] {
        let beforeByKey = Dictionary(grouping: before, by: \.key)
        let afterByKey = Dictionary(grouping: after, by: \.key)
        var failures: [String] = []

        if !hasRawChanges {
            for key in Set(beforeByKey.keys).union(afterByKey.keys).sorted() where atomEdits[key] == nil {
                if beforeByKey[key] != afterByKey[key] {
                    failures.append("Untouched MP4 atom \(key) changed during native-only editor save.")
                }
            }
            return failures
        }

        for key in Set(beforeByKey.keys).union(afterByKey.keys).sorted() where atomEdits[key] == nil {
            let isNonITunesFreeform = key.hasPrefix("----:") && mp4ITunesFreeformDescription(for: key) == nil
            if (key == "rate" || isNonITunesFreeform), beforeByKey[key] != afterByKey[key] {
                failures.append("Untouched MP4 atom \(key) changed during editor save.")
            }
        }

        let rawKeys = Set(raw.valuesToSet.keys).union(raw.removingKeys)
        for (nativeAtom, rawKey) in TagLibMetadataExtractor.mp4NativeAtomPropertyKeys() {
            let hadNative = beforeByKey[nativeAtom] != nil
            let beforeFreeforms = before.filter {
                mp4ITunesFreeformDescription(for: $0.key)?.uppercased() == rawKey
            }
            let afterFreeforms = after.filter {
                mp4ITunesFreeformDescription(for: $0.key)?.uppercased() == rawKey
            }
            if hadNative {
                if beforeFreeforms != afterFreeforms {
                    failures.append("MP4 freeform \(rawKey) changed while \(nativeAtom) owns \(rawKey).")
                }
            } else if !beforeFreeforms.isEmpty {
                if afterByKey[nativeAtom] != nil {
                    failures.append("MP4 atom \(nativeAtom) was created while freeform \(rawKey) owns \(rawKey).")
                }
            } else if rawKeys.contains(rawKey) && !afterFreeforms.isEmpty {
                failures.append("Duplicate MP4 freeform \(rawKey) was created alongside \(nativeAtom).")
            }
        }

        return failures
    }
}
