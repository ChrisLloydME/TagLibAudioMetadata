import Foundation
import CTagLibBridge

/// A comprehensive read result used as the source of truth for professional editing.
///
/// `BasicMetadata` is a normalized convenience projection. The raw and structured
/// representations retain value cardinality and container-specific entries.
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

    nonisolated var propertyMapValues: [String] {
        switch self {
        case .text(let value): [value]
        case .integer(let value): [String(value)]
        case .boolean(let value): value ? ["1"] : []
        case .values(let values): values
        case .remove: []
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
    /// Reads all public metadata representations while rejecting concurrent file changes.
    public nonisolated static func readSnapshot(from url: URL) throws -> MetadataSnapshot {
        let identity = regularFileIdentity(at: url)
        let basic = try readMetadataResult(from: url)
        let raw = try rawMetadataResult(from: url)
        let structured = try readStructuredMetadataResult(from: url)
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
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicFileMutation(at: url) { mutationURL in
            var warnings: [String] = []
            let before = try rawMetadataResult(from: mutationURL)
            var propertyValues = before.properties.reduce(into: [String: [String]]()) { result, entry in
                result[entry.key] = entry.values
            }

            for (field, value) in patch.fields {
                guard field != .artwork, field != .custom, field != .explicitContent,
                      let schema = MetadataFieldRegistry.schema(for: field),
                      let canonicalKey = schema.propertyMapKeys.first else {
                    warnings.append("Patch field \(field.rawValue) requires its dedicated patch property or is not writable.")
                    continue
                }
                for alias in schema.propertyMapKeys {
                    propertyValues.keys
                        .filter { $0.caseInsensitiveCompare(alias) == .orderedSame }
                        .forEach { propertyValues.removeValue(forKey: $0) }
                }
                if !value.propertyMapValues.isEmpty {
                    propertyValues[canonicalKey] = value.propertyMapValues
                }
            }

            for (key, value) in patch.customFields {
                propertyValues.keys
                    .filter { $0.caseInsensitiveCompare(key) == .orderedSame }
                    .forEach { propertyValues.removeValue(forKey: $0) }
                if !value.propertyMapValues.isEmpty {
                    propertyValues[key] = value.propertyMapValues
                }
            }

            if let advisory = patch.explicitAdvisory {
                for key in ["ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT", "RTNG"] {
                    propertyValues.keys
                        .filter { $0.caseInsensitiveCompare(key) == .orderedSame || $0.uppercased().hasSuffix(":ITUNESADVISORY") }
                        .forEach { propertyValues.removeValue(forKey: $0) }
                }
                switch advisory {
                case .unspecified: break
                case .clean: propertyValues["ITUNESADVISORY"] = ["2"]
                case .explicit: propertyValues["ITUNESADVISORY"] = ["1"]
                }
            }

            if !patch.fields.isEmpty || !patch.customFields.isEmpty || patch.explicitAdvisory != nil {
                try TagLibMetadataExtractor.writeRawPropertyMapValues(propertyValues, to: mutationURL)
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
                try TagLibMetadataExtractor.writeStructuredMetadata(payload, to: mutationURL)
            case .removeAll:
                let payload = bridgePayload(
                    from: StructuredMetadata(),
                    includeProperties: false,
                    replacingCollections: [.artwork]
                )
                try TagLibMetadataExtractor.writeStructuredMetadata(payload, to: mutationURL)
            }

            let after = try readSnapshot(from: mutationURL)
            for (field, value) in patch.fields {
                guard let schema = MetadataFieldRegistry.schema(for: field),
                      let key = schema.propertyMapKeys.first else { continue }
                let actual = after.raw.properties.first { entry in
                    schema.propertyMapKeys.contains { alias in
                        alias.caseInsensitiveCompare(entry.key) == .orderedSame
                    }
                }?.values ?? []
                if actual != value.propertyMapValues {
                    warnings.append("Patched field \(key) differs after save.")
                }
            }
            for (key, value) in patch.customFields {
                let actual = after.raw.properties.first {
                    $0.key.caseInsensitiveCompare(key) == .orderedSame
                }?.values ?? []
                if actual != value.propertyMapValues {
                    warnings.append("Patched custom field \(key) differs after save.")
                }
            }
            if let advisory = patch.explicitAdvisory, after.basic.explicitAdvisory != advisory {
                warnings.append("Patched explicit advisory differs after save.")
            }
            switch patch.artwork {
            case .unchanged: break
            case .replace(let expected) where expected != after.structured.artwork:
                warnings.append("Patched artwork differs after save.")
            case .removeAll where !after.structured.artwork.isEmpty:
                warnings.append("Patched artwork removal could not be confirmed.")
            default: break
            }

            try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }
}
