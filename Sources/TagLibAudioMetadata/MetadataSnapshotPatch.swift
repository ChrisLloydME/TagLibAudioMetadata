import Foundation
import CTagLibBridge

/// An opaque local-file version, for optimistic edits based on a snapshot.
/// This detects observed filesystem changes; it is not a cross-process lock or
/// a content digest. Uncooperative external writers can still race a commit.
public struct MetadataFileVersion: Hashable, Sendable {
    private let device: Int64
    private let inode: UInt64
    private let size: Int64
    private let links: UInt64
    private let modifiedSeconds: Int64
    private let modifiedNanoseconds: Int64
    private let changedSeconds: Int64
    private let changedNanoseconds: Int64

    nonisolated init(_ identity: TagLibMetadataManager.FileIdentity) {
        device = Int64(identity.device)
        inode = UInt64(identity.inode)
        size = Int64(identity.size)
        links = UInt64(identity.linkCount)
        modifiedSeconds = Int64(identity.modificationTime.tv_sec)
        modifiedNanoseconds = Int64(identity.modificationTime.tv_nsec)
        changedSeconds = Int64(identity.statusChangeTime.tv_sec)
        changedNanoseconds = Int64(identity.statusChangeTime.tv_nsec)
    }
}

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
    public let fileVersion: MetadataFileVersion?

    public init(basic: BasicMetadata, raw: RawMetadataDump, structured: StructuredMetadata, fileVersion: MetadataFileVersion? = nil) {
        self.basic = basic
        self.raw = raw
        self.structured = structured
        self.fileVersion = fileVersion
    }
}

public enum MetadataPatchValue: Hashable, Sendable {
    /// Non-empty text. Leading and trailing whitespace is removed before mutation.
    case text(String)
    /// A schema-constrained integer. Track/disc pair components begin at one;
    /// use `.remove` to unset them. Other numeric fields retain their schema ranges.
    case integer(Int)
    case boolean(Bool)
    /// One or more non-empty values. Each value is trimmed before mutation.
    case values([String])
    /// Explicitly removes the field. Empty text and value arrays are not deletion aliases.
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
    case unsupportedFieldForFormat(field: MetadataFieldKey, format: String)
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
    case conflictingNumberRepresentations

    public var errorDescription: String? {
        switch self {
        case .unsupportedField(let field):
            return "\(field.rawValue) uses a dedicated patch property or is not writable."
        case .unsupportedFieldForFormat(let field, let format):
            return "\(field.rawValue) is not writable for the \(format) format through MetadataPatch."
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
            return "\(location) contains an empty value at index \(index); use .remove to delete the field."
        case .conflictingNumberRepresentations:
            return "Use either formatted number text or typed track/disc fields in one patch, not both."
        }
    }
}

public enum MetadataArtworkPatch: Hashable, Sendable {
    case unchanged
    case replace([StructuredArtwork])
    case removeAll
}

/// An intentional formatted track/disc edit. The track text is required because
/// the underlying cross-container operation always establishes the track pair;
/// `discNumberText == nil` leaves the disc pair unchanged, while an empty string
/// removes it.
public struct MetadataNumberTextPatch: Hashable, Sendable {
    public var trackNumberText: String
    public var discNumberText: String?

    public init(trackNumberText: String, discNumberText: String? = nil) {
        self.trackNumberText = trackNumberText
        self.discNumberText = discNumberText
    }
}

/// Only explicitly supplied semantic fields are intentionally modified.
/// Other supported metadata is preserved where the format and TagLib representation allow it.
public struct MetadataPatch: Hashable, Sendable {
    public var fields: [MetadataFieldKey: MetadataPatchValue]
    public var customFields: [String: MetadataPatchValue]
    public var explicitAdvisory: ExplicitAdvisory?
    public var artwork: MetadataArtworkPatch
    public var numberText: MetadataNumberTextPatch?

    public init(
        fields: [MetadataFieldKey: MetadataPatchValue] = [:],
        customFields: [String: MetadataPatchValue] = [:],
        explicitAdvisory: ExplicitAdvisory? = nil,
        artwork: MetadataArtworkPatch = .unchanged,
        numberText: MetadataNumberTextPatch? = nil
    ) {
        self.fields = fields
        self.customFields = customFields
        self.explicitAdvisory = explicitAdvisory
        self.artwork = artwork
        self.numberText = numberText
    }

    public var isEmpty: Bool {
        fields.isEmpty && customFields.isEmpty && explicitAdvisory == nil && artwork == .unchanged && numberText == nil
    }
}

extension TagLibMetadataManager {
    /// Captures a regular-file version without following a final symbolic link.
    public nonisolated static func fileVersion(at url: URL) throws -> MetadataFileVersion {
        guard url.isFileURL, let identity = regularFileIdentity(at: url) else {
            throw TagLibManagerError.invalidFile
        }
        return MetadataFileVersion(identity)
    }

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
        let version = try fileVersion(at: url)
        let projections = try bridgeMetadataProjections(from: url)
        let raw = rawMetadataDump(fromBridgeDictionary: projections.raw)
        let basic = basicMetadata(fromBridgeMetadata: projections.basic, rawDump: raw)
        let structured = structuredMetadata(fromBridgeDictionary: projections.structured)
        guard version == (try? fileVersion(at: url)) else {
            throw TagLibManagerError.fileChanged
        }
        return MetadataSnapshot(basic: basic, raw: raw, structured: structured, fileVersion: version)
    }

    /// Applies only explicitly requested changes through the transactional coordinator.
    @discardableResult
    public nonisolated static func applyMetadataPatch(
        _ patch: MetadataPatch,
        to url: URL,
        expectedVersion: MetadataFileVersion? = nil,
        failurePolicy: VerificationFailurePolicy = .throw
    ) throws -> MetadataWriteResult {
        guard !patch.isEmpty else { return MetadataWriteResult(warnings: []) }
        let validatedPatch = try validate(patch)
        let numberPairFields: Set<MetadataFieldKey> = [.track, .trackTotal, .disc, .discTotal]
        if patch.numberText != nil, !numberPairFields.isDisjoint(with: validatedPatch.fields.keys) {
            throw MetadataPatchValidationError.conflictingNumberRepresentations
        }
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }
        if let capability = formatCapability(for: ext),
           let writableFields = capability.writableFields {
            let requestedFields = Set(validatedPatch.fields.keys)
                .union(patch.explicitAdvisory == nil ? [] : [.explicitContent])
                .union(patch.artwork == .unchanged ? [] : [.artwork])
                .union(patch.numberText == nil ? [] : [.track, .trackTotal])
                .union(patch.numberText?.discNumberText == nil ? [] : [.disc, .discTotal])
            if let unsupported = requestedFields
                .filter({ !writableFields.contains($0) })
                .sorted(by: { $0.rawValue < $1.rawValue })
                .first {
                throw MetadataPatchValidationError.unsupportedFieldForFormat(
                    field: unsupported,
                    format: capability.identifier
                )
            }
        }

        return try withAtomicFileMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
            let before = try readSnapshot(from: mutationURL)
            var warnings: [String] = []
            var propertyValues: [String: [String]] = [:]
            var keysToRemove: Set<String> = []
            let structuredNumberPairFields: Set<MetadataFieldKey> = [
                .track, .trackTotal, .disc, .discTotal, .movementNumber, .movementCount,
            ]
            let patchesNumberPair = !structuredNumberPairFields.isDisjoint(with: validatedPatch.fields.keys)
            var expectedNumberPairs: [MetadataFieldKey: Int] = [:]

            if patchesNumberPair {
                let current = before.basic
                var track = current.track
                var trackTotal = current.trackTotal
                var disc = current.disc
                var discTotal = current.discTotal
                var movementNumber = current.movementNumber
                var movementCount = current.movementCount

                func patchedInteger(_ value: MetadataPatchValue, current: Int) -> Int {
                    switch value {
                    case .integer(let integer): integer
                    case .remove: 0
                    default: current
                    }
                }

                if let value = validatedPatch.fields[.track] {
                    track = patchedInteger(value, current: track)
                }
                if let value = validatedPatch.fields[.trackTotal] {
                    trackTotal = patchedInteger(value, current: trackTotal)
                }
                if let value = validatedPatch.fields[.disc] {
                    disc = patchedInteger(value, current: disc)
                }
                if let value = validatedPatch.fields[.discTotal] {
                    discTotal = patchedInteger(value, current: discTotal)
                }
                if let value = validatedPatch.fields[.movementNumber] {
                    movementNumber = patchedInteger(value, current: movementNumber)
                }
                if let value = validatedPatch.fields[.movementCount] {
                    movementCount = patchedInteger(value, current: movementCount)
                }

                let updatesTrackPair = validatedPatch.fields[.track] != nil || validatedPatch.fields[.trackTotal] != nil
                let updatesDiscPair = validatedPatch.fields[.disc] != nil || validatedPatch.fields[.discTotal] != nil
                let updatesMovementPair = validatedPatch.fields[.movementNumber] != nil || validatedPatch.fields[.movementCount] != nil
                if updatesTrackPair {
                    expectedNumberPairs[.track] = track
                    expectedNumberPairs[.trackTotal] = trackTotal
                }
                if updatesDiscPair {
                    expectedNumberPairs[.disc] = disc
                    expectedNumberPairs[.discTotal] = discTotal
                }
                if updatesMovementPair {
                    expectedNumberPairs[.movementNumber] = movementNumber
                    expectedNumberPairs[.movementCount] = movementCount
                }

                try TagLibMetadataExtractor.writeNumberPairsInPlace(
                    trackNumber: track,
                    totalTracks: trackTotal,
                    updateTrackPair: updatesTrackPair,
                    discNumber: disc,
                    totalDiscs: discTotal,
                    updateDiscPair: updatesDiscPair,
                    movementNumber: movementNumber,
                    movementCount: movementCount,
                    updateMovementPair: updatesMovementPair,
                    to: mutationURL
                )
            }

            if let numberText = patch.numberText {
                let trackPair = parseNumberPair(numberText.trackNumberText)
                let discPair = numberText.discNumberText.map(parseNumberPair)
                try TagLibMetadataExtractor.writeNumberPairsInPlace(
                    trackNumber: trackPair.number,
                    totalTracks: trackPair.total,
                    updateTrackPair: true,
                    discNumber: discPair?.number ?? 0,
                    totalDiscs: discPair?.total ?? 0,
                    updateDiscPair: discPair != nil,
                    movementNumber: 0,
                    movementCount: 0,
                    updateMovementPair: false,
                    to: mutationURL
                )
                try TagLibMetadataExtractor.writeTrackNumberTextInPlace(
                    numberText.trackNumberText,
                    discNumberText: numberText.discNumberText,
                    to: mutationURL
                )
                expectedNumberPairs[.track] = trackPair.number
                expectedNumberPairs[.trackTotal] = trackPair.total
                if let discPair {
                    expectedNumberPairs[.disc] = discPair.number
                    expectedNumberPairs[.discTotal] = discPair.total
                }
            }

            for (field, value) in validatedPatch.fields where !structuredNumberPairFields.contains(field) {
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
                case .notExplicit: .notExplicit
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

            let projections = try bridgeMetadataProjectionDictionary(
                from: mutationURL,
                options: .all
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
            var intentionallyChangedKeys = keysToRemove
            for field in expectedNumberPairs.keys {
                intentionallyChangedKeys.formUnion(MetadataFieldRegistry.schema(for: field)?.propertyMapKeys ?? [])
            }
            if patch.explicitAdvisory != nil {
                intentionallyChangedKeys.formUnion(["ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT", "RTNG"])
            }
            let beforeValues = exactPropertyValues(before.raw)
            let afterValues = exactPropertyValues(afterRaw)
            for key in Set(beforeValues.keys).union(afterValues.keys) {
                // MP4 may expose a known field through its freeform alias.
                let unqualified = key.hasPrefix("----:COM.APPLE.ITUNES:")
                    ? String(key.dropFirst("----:COM.APPLE.ITUNES:".count)) : key
                guard !intentionallyChangedKeys.contains(unqualified) else { continue }
                if beforeValues[key] != afterValues[key] {
                    warnings.append("Unedited PropertyMap field \(key) changed during the patch.")
                }
            }
            if patch.artwork == .unchanged, before.structured.artwork != afterStructured.artwork {
                warnings.append("Unedited artwork changed during the patch.")
            }
            for (field, expected) in expectedNumberPairs {
                let actual = switch field {
                case .track: afterBasic.track
                case .trackTotal: afterBasic.trackTotal
                case .disc: afterBasic.disc
                case .discTotal: afterBasic.discTotal
                case .movementNumber: afterBasic.movementNumber
                case .movementCount: afterBasic.movementCount
                default: expected
                }
                if actual != expected {
                    warnings.append("Patched field \(field.rawValue) differs after save (expected \(expected), got \(actual)).")
                }
            }
            for (field, value) in validatedPatch.fields where expectedNumberPairs[field] == nil {
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
            if let numberText = patch.numberText {
                if afterBasic.trackNumberText != numberText.trackNumberText.trimmingCharacters(in: .whitespacesAndNewlines) {
                    warnings.append("Patched track number text differs after save.")
                }
                if let discNumberText = numberText.discNumberText,
                   afterBasic.discNumberText != discNumberText.trimmingCharacters(in: .whitespacesAndNewlines) {
                    warnings.append("Patched disc number text differs after save.")
                }
            }
            switch patch.artwork {
            case .unchanged: break
            case .replace(let expected):
                if expected.count != afterStructured.artwork.count ||
                    !zip(expected, afterStructured.artwork).allSatisfy({ structuredArtworkMatches($0, $1) }) {
                    warnings.append("Patched artwork differs after save.")
                }
            case .removeAll where !afterStructured.artwork.isEmpty:
                warnings.append("Patched artwork removal could not be confirmed.")
            default: break
            }

            try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }
}
