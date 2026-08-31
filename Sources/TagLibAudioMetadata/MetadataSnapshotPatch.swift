import Foundation
import CTagLibBridge

/// A comprehensive semantic metadata snapshot for professional editing.
///
/// `BasicMetadata` is a normalized convenience projection. The raw and structured
/// representations retain value cardinality and supported container-specific entries.
/// Unsupported or opaque native frames/items may be summarized rather than copied as
/// reconstructable payloads, so this is not a lossless native serialization.
public struct MetadataSnapshot: Sendable {
    public var basic: BasicMetadata
    public var raw: RawMetadataDump
    public var structured: StructuredMetadata

    public init(basic: BasicMetadata, raw: RawMetadataDump, structured: StructuredMetadata) {
        self.basic = basic
        self.raw = raw
        self.structured = structured
    }
}

public enum MetadataPatchValue: Hashable, Sendable {
    case text(String)
    case integer(Int)
    case boolean(Bool)
    case values([String])
    case remove

    nonisolated var kind: MetadataPatchValueKind? {
        switch self {
        case .text: .text
        case .integer: .integer
        case .boolean: .boolean
        case .values: .values
        case .remove: nil
        }
    }

    nonisolated var propertyMapValues: [String] {
        switch self {
        case .text(let value): [value]
        case .integer(let value): [String(value)]
        case .boolean(let value): [value ? "1" : "0"]
        case .values(let values): values
        case .remove: []
        }
    }
}

public enum MetadataPatchValidationError: Error, Equatable, Sendable, LocalizedError {
    case unsupportedField(MetadataFieldKey)
    case incompatibleValue(
        field: MetadataFieldKey,
        expected: Set<MetadataPatchValueKind>,
        actual: MetadataPatchValueKind
    )

    public var errorDescription: String? {
        switch self {
        case .unsupportedField(let field):
            return "\(field.rawValue) uses a dedicated patch property or is not writable."
        case .incompatibleValue(let field, let expected, let actual):
            let expectedNames = expected.map(\.rawValue).sorted().joined(separator: " or ")
            return "\(field.rawValue) requires \(expectedNames); received \(actual.rawValue)."
        }
    }
}

public enum MetadataArtworkPatch: Hashable, Sendable {
    case unchanged
    case replace([StructuredArtwork])
    case removeAll
}

/// Only the fields present in a patch are changed. Everything else is preserved.
public struct MetadataPatch: Hashable, Sendable {
    public var fields: [MetadataFieldKey: MetadataPatchValue]
    public var customFields: [String: MetadataPatchValue]
    public var explicitAdvisory: ExplicitAdvisory?
    public var artwork: MetadataArtworkPatch

    public init(
        fields: [MetadataFieldKey: MetadataPatchValue] = [:],
        customFields: [String: MetadataPatchValue] = [:],
        explicitAdvisory: ExplicitAdvisory? = nil,
        artwork: MetadataArtworkPatch = .unchanged
    ) {
        self.fields = fields
        self.customFields = customFields
        self.explicitAdvisory = explicitAdvisory
        self.artwork = artwork
    }

    public var isEmpty: Bool {
        fields.isEmpty && customFields.isEmpty && explicitAdvisory == nil && artwork == .unchanged
    }
}

extension TagLibMetadataManager {
    nonisolated private static func validate(_ patch: MetadataPatch) throws {
        for (field, value) in patch.fields {
            guard field != .artwork, field != .custom, field != .explicitContent,
                  let schema = MetadataFieldRegistry.schema(for: field),
                  !schema.propertyMapKeys.isEmpty,
                  !schema.acceptedPatchValueKinds.isEmpty else {
                throw MetadataPatchValidationError.unsupportedField(field)
            }
            if let kind = value.kind, !schema.acceptedPatchValueKinds.contains(kind) {
                throw MetadataPatchValidationError.incompatibleValue(
                    field: field,
                    expected: schema.acceptedPatchValueKinds,
                    actual: kind
                )
            }
        }
    }

    /// Reads all public metadata representations while rejecting concurrent file changes.
    public nonisolated static func readSnapshot(from url: URL) throws -> MetadataSnapshot {
        let identity = regularFileIdentity(at: url)
        let projections = try bridgeMetadataProjections(from: url)
        let raw = rawMetadataDump(fromBridgeDictionary: projections.raw)
        let basic = basicMetadata(fromBridgeMetadata: projections.basic, rawDump: raw)
        let structured = structuredMetadata(fromBridgeDictionary: projections.structured)
        guard identity == regularFileIdentity(at: url) else {
            throw TagLibManagerError.failedToReadWithUnderlying(
                "The audio file changed while its metadata snapshot was being read."
            )
        }
        return MetadataSnapshot(basic: basic, raw: raw, structured: structured)
    }

    /// Applies only explicitly requested changes through the transactional coordinator.
    @discardableResult
    public nonisolated static func applyMetadataPatch(
        _ patch: MetadataPatch,
        to url: URL,
        failurePolicy: VerificationFailurePolicy = .throw
    ) throws -> MetadataWriteResult {
        guard !patch.isEmpty else { return MetadataWriteResult(warnings: []) }
        try validate(patch)
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicFileMutation(at: url) { mutationURL in
            var warnings: [String] = []
            var propertyValues: [String: [String]] = [:]
            var keysToRemove: Set<String> = []
            let numberPairFields: Set<MetadataFieldKey> = [.track, .trackTotal, .disc, .discTotal]
            let patchesNumberPair = !numberPairFields.isDisjoint(with: patch.fields.keys)
            var expectedNumberPairs: [MetadataFieldKey: Int] = [:]

            if patchesNumberPair {
                let current = try readMetadataResult(from: mutationURL)
                var track = current.track
                var trackTotal = current.trackTotal
                var disc = current.disc
                var discTotal = current.discTotal

                func patchedInteger(_ value: MetadataPatchValue, current: Int) -> Int {
                    switch value {
                    case .integer(let integer): integer
                    case .remove: 0
                    default: current
                    }
                }

                if let value = patch.fields[.track] {
                    track = patchedInteger(value, current: track)
                    expectedNumberPairs[.track] = track
                }
                if let value = patch.fields[.trackTotal] {
                    trackTotal = patchedInteger(value, current: trackTotal)
                    expectedNumberPairs[.trackTotal] = trackTotal
                }
                if let value = patch.fields[.disc] {
                    disc = patchedInteger(value, current: disc)
                    expectedNumberPairs[.disc] = disc
                }
                if let value = patch.fields[.discTotal] {
                    discTotal = patchedInteger(value, current: discTotal)
                    expectedNumberPairs[.discTotal] = discTotal
                }

                try TagLibMetadataExtractor.writeNumberPairsInPlace(
                    trackNumber: track,
                    totalTracks: trackTotal,
                    updateTrackPair: patch.fields[.track] != nil || patch.fields[.trackTotal] != nil,
                    discNumber: disc,
                    totalDiscs: discTotal,
                    updateDiscPair: patch.fields[.disc] != nil || patch.fields[.discTotal] != nil,
                    to: mutationURL
                )
            }

            for (field, value) in patch.fields where !numberPairFields.contains(field) {
                guard let schema = MetadataFieldRegistry.schema(for: field),
                      let canonicalKey = schema.propertyMapKeys.first else {
                    continue
                }
                keysToRemove.formUnion(schema.propertyMapKeys)
                if !value.propertyMapValues.isEmpty {
                    propertyValues[canonicalKey] = value.propertyMapValues
                }
            }

            for (key, value) in patch.customFields {
                keysToRemove.insert(key)
                if !value.propertyMapValues.isEmpty {
                    propertyValues[key] = value.propertyMapValues
                }
            }

            if let advisory = patch.explicitAdvisory {
                let bridgeAdvisory: TagLibExplicitAdvisory = switch advisory {
                case .unspecified: .unspecified
                case .clean: .clean
                case .explicit: .explicit
                }
                try TagLibMetadataExtractor.writeExplicitAdvisoryInPlace(
                    bridgeAdvisory,
                    to: mutationURL
                )
            }

            if !propertyValues.isEmpty || !keysToRemove.isEmpty {
                try TagLibMetadataExtractor.applyPropertyMapValuesInPlace(
                    propertyValues,
                    removingKeys: Array(keysToRemove),
                    to: mutationURL
                )
            }

            switch patch.artwork {
            case .unchanged:
                break
            case .replace(let artwork):
                let payload = bridgePayload(
                    from: StructuredMetadata(artwork: artwork),
                    includeProperties: false,
                    replacingCollections: [.artwork]
                )
                try TagLibMetadataExtractor.writeStructuredMetadataInPlace(payload, to: mutationURL)
            case .removeAll:
                let payload = bridgePayload(
                    from: StructuredMetadata(),
                    includeProperties: false,
                    replacingCollections: [.artwork]
                )
                try TagLibMetadataExtractor.writeStructuredMetadataInPlace(payload, to: mutationURL)
            }

            let extractionOptions: MetadataExtractionOptions = switch patch.artwork {
            case .unchanged: [.basic, .raw]
            case .replace, .removeAll: .all
            }
            let projections = try bridgeMetadataProjectionDictionary(
                from: mutationURL,
                options: extractionOptions
            )
            guard let bridgeBasic = projections["basic"] as? TagLibAudioMetadata,
                  let bridgeRaw = projections["raw"] as? [String: NSObject] else {
                throw TagLibManagerError.failedToReadWithUnderlying(
                    "The bridge returned incomplete patch verification projections."
                )
            }
            let afterRaw = rawMetadataDump(fromBridgeDictionary: bridgeRaw)
            let afterBasic = basicMetadata(fromBridgeMetadata: bridgeBasic, rawDump: afterRaw)
            let afterStructured = (projections["structured"] as? [String: NSObject]).map {
                structuredMetadata(fromBridgeDictionary: $0)
            } ?? StructuredMetadata()
            for (field, value) in patch.fields {
                if let expected = expectedNumberPairs[field] {
                    let actual = switch field {
                    case .track: afterBasic.track
                    case .trackTotal: afterBasic.trackTotal
                    case .disc: afterBasic.disc
                    case .discTotal: afterBasic.discTotal
                    default: expected
                    }
                    if actual != expected {
                        warnings.append("Patched field \(field.rawValue) differs after save (expected \(expected), got \(actual)).")
                    }
                    continue
                }
                guard let schema = MetadataFieldRegistry.schema(for: field),
                      let key = schema.propertyMapKeys.first else { continue }
                let actual = afterRaw.properties.first { entry in
                    schema.propertyMapKeys.contains { alias in
                        alias.caseInsensitiveCompare(entry.key) == .orderedSame
                    }
                }?.values ?? []
                if actual != value.propertyMapValues {
                    warnings.append("Patched field \(key) differs after save.")
                }
            }
            for (key, value) in patch.customFields {
                let actual = afterRaw.properties.first {
                    $0.key.caseInsensitiveCompare(key) == .orderedSame
                }?.values ?? []
                if actual != value.propertyMapValues {
                    warnings.append("Patched custom field \(key) differs after save.")
                }
            }
            if let advisory = patch.explicitAdvisory, afterBasic.explicitAdvisory != advisory {
                warnings.append("Patched explicit advisory differs after save.")
            }
            switch patch.artwork {
            case .unchanged: break
            case .replace(let expected) where expected != afterStructured.artwork:
                warnings.append("Patched artwork differs after save.")
            case .removeAll where !afterStructured.artwork.isEmpty:
                warnings.append("Patched artwork removal could not be confirmed.")
            default: break
            }

            try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }
}
