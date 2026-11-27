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
}

extension TagLibMetadataManager {
    nonisolated static let mp4EditorFieldKeys: [MetadataFieldKey] = [
        .itunesAlbumID, .itunesArtistID, .itunesCatalogID, .explicitContent,
    ]

    /// Edits the native fields reported by `MetadataSnapshot.editableMP4Fields`
    /// and an optional exact PropertyMap delta in one verified MP4 transaction.
    /// Use `.integer` for IDs or advisory codes 0, 1 and 2, and `.remove` to clear
    /// the selected atom. A native edit preserves legacy text aliases.
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
        guard !nativeFields.isEmpty || hasRawChanges else { return MetadataWriteResult(warnings: []) }

        let atoms = try nativeFields.sorted { $0.key.rawValue < $1.key.rawValue }.map { field, value in
            guard mp4EditorFieldKeys.contains(field),
                  let schema = MetadataFieldRegistry.schema(for: field) else {
                throw MetadataPatchValidationError.unsupportedFieldForFormat(field: field, format: "MP4 metadata editor")
            }
            if let kind = value.kind, kind != .integer {
                throw MetadataPatchValidationError.incompatibleValue(field: field, expected: [.integer], actual: kind)
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
            let storage = try semanticStorage(for: field, formatIdentifier: "mp4", formats: [.mp4])
            guard let atom = structuredMP4Atom(for: storage.mechanism, value: value) else {
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
            let failures = before.editableMP4Fields.compactMap { row -> String? in
                let actual = after.structured.mp4Atoms.first { $0.key == row.atomKey }
                let matches: Bool
                if let edit = atomEdits[row.atomKey] {
                    matches = edit.remove ? actual == nil : actual?.value == edit.value
                } else {
                    matches = actual == row.atom
                }
                return matches ? nil : "MP4 atom \(row.atomKey) differs after editor save."
            }
            try throwOnVerificationFailures(failures)
            return MetadataWriteResult(warnings: after.structured.warnings)
        }
    }
}
