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

    nonisolated func normalized(location: String) throws -> MetadataPatchValue {
        switch self {
        case .text(let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw MetadataPatchValidationError.emptyText(location: location)
            }
            return .text(trimmed)
        case .values(let values):
            guard !values.isEmpty else {
                throw MetadataPatchValidationError.emptyValueList(location: location)
            }
            var normalizedValues: [String] = []
            normalizedValues.reserveCapacity(values.count)
            for (index, value) in values.enumerated() {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw MetadataPatchValidationError.emptyValue(location: location, index: index)
                }
                normalizedValues.append(trimmed)
            }
            return .values(normalizedValues)
        case .integer, .boolean, .remove:
            return self
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
    case integerOutOfRange(field: MetadataFieldKey, minimum: Int, maximum: Int, actual: Int)
    case knownFieldRequiresTypedAPI(customKey: String, field: MetadataFieldKey)
    case conflictingFieldRepresentations(field: MetadataFieldKey, customKey: String)
    case duplicateCustomField(normalizedKey: String)
    case invalidCustomFieldKey(String)
    case emptyText(location: String)
    case emptyValueList(location: String)
    case emptyValue(location: String, index: Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedField(let field):
            return "\(field.rawValue) uses a dedicated patch property or is not writable."
        case .incompatibleValue(let field, let expected, let actual):
            let expectedNames = expected.map(\.rawValue).sorted().joined(separator: " or ")
            return "\(field.rawValue) requires \(expectedNames); received \(actual.rawValue)."
        case .integerOutOfRange(let field, let minimum, let maximum, let actual):
            return "\(field.rawValue) must be between \(minimum) and \(maximum); received \(actual)."
        case .knownFieldRequiresTypedAPI(let customKey, let field):
            return "Custom key \(customKey) is the known \(field.rawValue) field; use the typed MetadataPatch API."
        case .conflictingFieldRepresentations(let field, let customKey):
            return "\(field.rawValue) was specified through both typed fields and custom key \(customKey)."
        case .duplicateCustomField(let normalizedKey):
            return "Multiple custom field keys normalize to \(normalizedKey)."
        case .invalidCustomFieldKey(let key):
            return "Custom field key \(key.debugDescription) is empty after normalization."
        case .emptyText(let location):
            return "\(location) requires non-empty text; use .remove to delete the field."
        case .emptyValueList(let location):
            return "\(location) requires at least one value; use .remove to delete the field."
        case .emptyValue(let location, let index):
            return "\(location) contains an empty value at index \(index)."
        }
    }
}

public enum MetadataArtworkPatch: Hashable, Sendable {
    case unchanged
    case replace([StructuredArtwork])
    case removeAll
}

/// Only explicitly supplied semantic fields are intentionally modified.
/// Other supported metadata is preserved where the format and TagLib representation allow it.
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
    private struct ValidatedMetadataPatch: Sendable {
        var fields: [MetadataFieldKey: MetadataPatchValue]
        var customFields: [String: MetadataPatchValue]
    }

    nonisolated private static func validate(_ patch: MetadataPatch) throws -> ValidatedMetadataPatch {
        var normalizedFields: [MetadataFieldKey: MetadataPatchValue] = [:]
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
            if case .integer(let integer) = value, let constraint = schema.integerConstraint,
               !(constraint.minimum...constraint.maximum).contains(integer) {
                throw MetadataPatchValidationError.integerOutOfRange(
                    field: field,
                    minimum: constraint.minimum,
                    maximum: constraint.maximum,
                    actual: integer
                )
            }
            normalizedFields[field] = try value.normalized(location: field.rawValue)
        }

        var normalizedCustomFields: [String: MetadataPatchValue] = [:]
        for (key, value) in patch.customFields {
            let normalizedKey = MetadataFieldRegistry.normalizePropertyMapKey(key)
            guard !normalizedKey.isEmpty else {
                throw MetadataPatchValidationError.invalidCustomFieldKey(key)
            }
            if let schema = MetadataFieldRegistry.schema(forHighLevelCustomKey: normalizedKey) {
                if patch.fields[schema.key] != nil {
                    throw MetadataPatchValidationError.conflictingFieldRepresentations(
                        field: schema.key,
                        customKey: key
                    )
                }
                throw MetadataPatchValidationError.knownFieldRequiresTypedAPI(
                    customKey: key,
                    field: schema.key
                )
            }
            guard normalizedCustomFields[normalizedKey] == nil else {
                throw MetadataPatchValidationError.duplicateCustomField(normalizedKey: normalizedKey)
            }
            normalizedCustomFields[normalizedKey] = try value.normalized(location: key)
        }
        return ValidatedMetadataPatch(fields: normalizedFields, customFields: normalizedCustomFields)
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
        let validatedPatch = try validate(patch)
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicFileMutation(at: url) { mutationURL in
            var warnings: [String] = []
            var propertyValues: [String: [String]] = [:]
            var keysToRemove: Set<String> = []
            let numberPairFields: Set<MetadataFieldKey> = [.track, .trackTotal, .disc, .discTotal]
            let patchesNumberPair = !numberPairFields.isDisjoint(with: validatedPatch.fields.keys)
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

                if let value = validatedPatch.fields[.track] {
                    track = patchedInteger(value, current: track)
                    expectedNumberPairs[.track] = track
                }
                if let value = validatedPatch.fields[.trackTotal] {
                    trackTotal = patchedInteger(value, current: trackTotal)
                    expectedNumberPairs[.trackTotal] = trackTotal
                }
                if let value = validatedPatch.fields[.disc] {
                    disc = patchedInteger(value, current: disc)
                    expectedNumberPairs[.disc] = disc
                }
                if let value = validatedPatch.fields[.discTotal] {
                    discTotal = patchedInteger(value, current: discTotal)
                    expectedNumberPairs[.discTotal] = discTotal
                }

                try TagLibMetadataExtractor.writeNumberPairsInPlace(
                    trackNumber: track,
                    totalTracks: trackTotal,
                    updateTrackPair: validatedPatch.fields[.track] != nil || validatedPatch.fields[.trackTotal] != nil,
                    discNumber: disc,
                    totalDiscs: discTotal,
                    updateDiscPair: validatedPatch.fields[.disc] != nil || validatedPatch.fields[.discTotal] != nil,
                    to: mutationURL
                )
            }

            for (field, value) in validatedPatch.fields where !numberPairFields.contains(field) {
                guard let schema = MetadataFieldRegistry.schema(for: field),
                      let canonicalKey = schema.propertyMapKeys.first else {
                    continue
                }
                keysToRemove.formUnion(schema.propertyMapKeys)
                if !value.propertyMapValues.isEmpty {
                    propertyValues[canonicalKey] = value.propertyMapValues
                }
            }

            for (key, value) in validatedPatch.customFields {
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
            case .unchanged: [.basic, .propertyMap]
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
            for (field, value) in validatedPatch.fields {
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
            for (key, value) in validatedPatch.customFields {
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
