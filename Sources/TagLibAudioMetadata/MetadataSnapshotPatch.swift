import Foundation
import CTagLibBridge
import CTagLibBridgeInternalAPI

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
    /// Nil unless explicitly requested and supported. Two nil values do not prove continuity.
    public let audioContentIdentity: MetadataAudioContentIdentity?

    public init(basic: BasicMetadata, raw: RawMetadataDump, structured: StructuredMetadata, fileVersion: MetadataFileVersion? = nil) {
        self.init(basic: basic, raw: raw, structured: structured, fileVersion: fileVersion, audioContentIdentity: nil)
    }

    public init(
        basic: BasicMetadata,
        raw: RawMetadataDump,
        structured: StructuredMetadata,
        fileVersion: MetadataFileVersion? = nil,
        audioContentIdentity: MetadataAudioContentIdentity?
    ) {
        self.basic = basic
        self.raw = raw
        self.structured = structured
        self.fileVersion = fileVersion
        self.audioContentIdentity = audioContentIdentity
    }
}

/// A focused read for list/editor loading that needs normalized Basic metadata
/// and an optimistic-concurrency token, but not structured inspector models.
public struct BasicMetadataSnapshot: Sendable {
    public var metadata: BasicMetadata
    public let fileVersion: MetadataFileVersion
    /// Nil unless explicitly requested and supported. Two nil values do not prove continuity.
    public let audioContentIdentity: MetadataAudioContentIdentity?

    public init(metadata: BasicMetadata, fileVersion: MetadataFileVersion) {
        self.init(metadata: metadata, fileVersion: fileVersion, audioContentIdentity: nil)
    }

    public init(
        metadata: BasicMetadata,
        fileVersion: MetadataFileVersion,
        audioContentIdentity: MetadataAudioContentIdentity?
    ) {
        self.metadata = metadata
        self.fileVersion = fileVersion
        self.audioContentIdentity = audioContentIdentity
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
    /// Removing one track/disc component preserves its sibling. MP4 uses
    /// the native zero sentinel for an absent component; ID3 writes /total.
    /// Layouts without a verified total-only codec reject that operation.
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
            if trimmed.contains("\0") {
                throw MetadataValidationError.embeddedNull(location: location)
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
                if trimmed.contains("\0") {
                    throw MetadataValidationError.embeddedNull(location: "\(location)[\(index)]")
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
    case roleQualifiedFieldRequiresRawAPI(MetadataFieldKey)
    case unsupportedPartialPairRemoval(field: MetadataFieldKey, format: String)
    case ambiguousNumberRecovery(field: String, identities: [String])
    case conflictingYearRepresentations

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
        case .roleQualifiedFieldRequiresRawAPI(let field):
            return "\(field.rawValue) requires a role-qualified key; use RawMetadataPatch or StructuredMetadata instead of the typed Patch field."
        case .unsupportedPartialPairRemoval(let field, let format):
            return "\(field.rawValue) requires a positive number when its paired total is present for \(format); set the number or remove both components."
        case .ambiguousNumberRecovery(let field, let identities):
            return "\(field) has ambiguous legacy numbering recovery; resolve the exact identities explicitly: \(identities.joined(separator: ", "))."
        case .conflictingYearRepresentations:
            return "Use either the deprecated .date YEAR spelling or .year in one patch, not both."
        }
    }
}

public enum MetadataArtworkPatch: Hashable, Sendable {
    case unchanged
    case replace([StructuredArtwork])
    case removeAll
}

/// An intentional formatted track/disc edit. Each optional independently means:
/// `nil` leaves that pair unchanged, a nonempty value sets it, and an empty string
/// removes it.
public struct MetadataNumberTextPatch: Hashable, Sendable {
    public var trackNumberText: String?
    public var discNumberText: String?

    public init(trackNumberText: String? = nil, discNumberText: String? = nil) {
        self.trackNumberText = trackNumberText
        self.discNumberText = discNumberText
    }

    public var isEmpty: Bool {
        trackNumberText == nil && discNumberText == nil
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
        fields.isEmpty && customFields.isEmpty && explicitAdvisory == nil && artwork == .unchanged && (numberText == nil || numberText?.isEmpty == true)
    }
}

extension TagLibMetadataManager {
    nonisolated static func validateNativeNumberPair(
        number: Int, total: Int, field: MetadataFieldKey, for url: URL
    ) throws {
        let format = capability(forExtension: url.pathExtension)?.identifier ?? url.pathExtension
        let maximum = format == "mp4" ? 65535 : Int(Int32.max)
        for value in [number, total] where value < 0 || value > maximum {
            throw MetadataPatchValidationError.integerOutOfRange(field: field, minimum: 0, maximum: maximum, actual: value)
        }
        if format == "asf", number == 0, total > 0 {
            throw MetadataPatchValidationError.unsupportedPartialPairRemoval(field: field, format: format)
        }
    }

    nonisolated static func validateNativeMovement(_ value: Int, field: MetadataFieldKey, for url: URL) throws {
        guard capability(forExtension: url.pathExtension)?.identifier == "mp4" else { return }
        guard (0...Int(Int16.max)).contains(value) else {
            throw MetadataPatchValidationError.integerOutOfRange(field: field, minimum: 0, maximum: Int(Int16.max), actual: value)
        }
    }

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
        if patch.fields[.date] != nil && patch.fields[.year] != nil {
            throw MetadataPatchValidationError.conflictingYearRepresentations
        }
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
            if schema.isRoleQualified {
                throw MetadataPatchValidationError.roleQualifiedFieldRequiresRawAPI(field)
            }
            normalizedFields[field] = try value.normalized(location: field.rawValue)
        }

        var normalizedCustomFields: [String: MetadataPatchValue] = [:]
        for (key, value) in patch.customFields {
            if key.contains("\0") {
                throw MetadataValidationError.embeddedNull(location: "customFields key")
            }
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
                if schema.isRoleQualified {
                    throw MetadataPatchValidationError.roleQualifiedFieldRequiresRawAPI(schema.key)
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
        try readSnapshot(from: url, afterExtraction: {})
    }

    /// Streams the encoded audio when requested. Unsupported layouts return a nil
    /// identity; callers must require explicit reload instead of automatic rebase.
    public nonisolated static func readSnapshot(
        from url: URL, includingAudioContent: Bool
    ) throws -> MetadataSnapshot {
        try readSnapshot(from: url, includingAudioContent: includingAudioContent, afterExtraction: {})
    }

    // Internal, per-call seam for deterministic external-change tests. No global
    // hook or public synchronization policy is added to the read API.
    nonisolated static func readSnapshot(
        from url: URL, includingAudioContent: Bool = false, afterExtraction: () throws -> Void
    ) throws -> MetadataSnapshot {
        let version = try fileVersion(at: url)
        let projections = try bridgeMetadataProjections(from: url)
        try afterExtraction()
        let audioIdentity = includingAudioContent ? try audioContentIdentity(at: url, version: version) : nil
        let raw = rawMetadataDump(fromBridgeDictionary: projections.raw)
        let structured = structuredMetadata(fromBridgeDictionary: projections.structured)
        let basic = basicMetadata(
            fromBridgeMetadata: projections.basic,
            rawDump: raw,
            fileExtension: url.pathExtension,
            structured: structured
        )
        guard version == (try? fileVersion(at: url)) else {
            throw TagLibManagerError.fileChanged
        }
        return MetadataSnapshot(basic: basic, raw: raw, structured: structured, fileVersion: version, audioContentIdentity: audioIdentity)
    }

    /// Applies only explicitly requested changes through the transactional coordinator.
    @discardableResult
    public nonisolated static func applyMetadataPatch(
        _ patch: MetadataPatch,
        to url: URL,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        try applyMetadataPatchValidatingAudio(patch, to: url, expectedVersion: expectedVersion, expectedAudioContent: nil)
    }

    /// Applies a rebased patch only if the baseline audio still matches. Both
    /// guards are required: audio identity allows metadata-only conflicts, while
    /// expectedVersion binds the caller's merge decision to the exact current revision.
    @discardableResult
    public nonisolated static func applyMetadataPatch(
        _ patch: MetadataPatch,
        to url: URL,
        expectedVersion: MetadataFileVersion,
        expectedAudioContent: MetadataAudioContentIdentity
    ) throws -> MetadataWriteResult {
        try applyMetadataPatchValidatingAudio(
            patch, to: url, expectedVersion: expectedVersion, expectedAudioContent: expectedAudioContent
        )
    }

    nonisolated private static func applyMetadataPatchValidatingAudio(
        _ patch: MetadataPatch,
        to url: URL,
        expectedVersion: MetadataFileVersion?,
        expectedAudioContent: MetadataAudioContentIdentity?
    ) throws -> MetadataWriteResult {
        guard !patch.isEmpty else { return MetadataWriteResult(warnings: []) }
        let validatedPatch = try validate(patch)
        for field in [MetadataFieldKey.movementNumber, .movementCount] {
            if case .integer(let value) = validatedPatch.fields[field] {
                try validateNativeMovement(value, field: field, for: url)
            }
        }
        let numberPairFields: Set<MetadataFieldKey> = [.track, .trackTotal, .disc, .discTotal]
        if patch.numberText != nil, !numberPairFields.isDisjoint(with: validatedPatch.fields.keys) {
            throw MetadataPatchValidationError.conflictingNumberRepresentations
        }
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }
        if let capability = capability(forExtension: ext),
           let writableFields = capability.writableFields {
            let requestedFields = Set(validatedPatch.fields.keys)
                .union(patch.explicitAdvisory == nil ? [] : [.explicitContent])
                .union(patch.artwork == .unchanged ? [] : [.artwork])
                .union(patch.numberText?.trackNumberText == nil ? [] : [.track, .trackTotal])
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

        // MP4 movement components have independent integer atoms, unlike
        // shared ID3 MVIN. Route them through the registry's native planner.
        let structuredNumberPairFields: Set<MetadataFieldKey> = Set([
            .track, .trackTotal, .disc, .discTotal, .movementNumber, .movementCount,
        ]).subtracting(capability(forExtension: ext)?.identifier == "mp4" ? [.movementNumber, .movementCount] : [])
        let fieldStorage = try validatedPatch.fields.reduce(into: [MetadataFieldKey: SemanticPropertyStorage]()) {
            result, entry in
            guard !structuredNumberPairFields.contains(entry.key) else { return }
            result[entry.key] = try semanticStorage(for: entry.key, fileExtension: ext)
        }

        return try withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
            if let expectedAudioContent {
                try requireAudioContent(at: mutationURL, matching: expectedAudioContent)
            }
            let before = try readSnapshot(from: mutationURL)
            if before.structured.id3v2MajorVersion == 3,
               let field = validatedPatch.fields.keys.first(where: {
                   [.year, .date, .standaloneDate, .releaseDate, .originalReleaseDate].contains($0)
               }) {
                throw MetadataPatchValidationError.unsupportedFieldForFormat(field: field, format: "ID3v2.3 independent dates (read-only)")
            }
            var warnings: [String] = []
            var propertyValues: [String: [String]] = [:]
            var keysToRemove: Set<String> = []
            var nativeFieldAliases: Set<String> = []
            var nativeAtoms: [StructuredMP4Atom] = []
            let patchesNumberPair = !structuredNumberPairFields.isDisjoint(with: validatedPatch.fields.keys)
            var expectedNumberPairs: [MetadataFieldKey: Int] = [:]

            if patchesNumberPair {
                let current = before.basic
                let inventory = numberingInventory(from: before)
                func resolved(_ component: MetadataNumberComponentInventory, field: String) throws -> Int {
                    if component.isUnresolved {
                        throw MetadataPatchValidationError.ambiguousNumberRecovery(
                            field: field,
                            identities: component.identities
                        )
                    }
                    return component.resolvedValue ?? 0
                }
                let updatesTrackPair = validatedPatch.fields[.track] != nil || validatedPatch.fields[.trackTotal] != nil
                let updatesDiscPair = validatedPatch.fields[.disc] != nil || validatedPatch.fields[.discTotal] != nil
                var track = updatesTrackPair ? try resolved(inventory.track.number, field: "track") : current.track
                var trackTotal = updatesTrackPair ? try resolved(inventory.track.total, field: "trackTotal") : current.trackTotal
                var disc = updatesDiscPair ? try resolved(inventory.disc.number, field: "disc") : current.disc
                var discTotal = updatesDiscPair ? try resolved(inventory.disc.total, field: "discTotal") : current.discTotal
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

                let updatesMovementPair = structuredNumberPairFields.contains(.movementNumber)
                    && (validatedPatch.fields[.movementNumber] != nil || validatedPatch.fields[.movementCount] != nil)
                if updatesTrackPair {
                    try validateNativeNumberPair(number: track, total: trackTotal, field: .track, for: url)
                }
                if updatesDiscPair {
                    try validateNativeNumberPair(number: disc, total: discTotal, field: .disc, for: url)
                }

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
                let inventory = numberingInventory(from: before)
                func resolvedTotal(_ component: MetadataNumberComponentInventory, field: String) throws -> Int {
                    if component.isUnresolved {
                        throw MetadataPatchValidationError.ambiguousNumberRecovery(
                            field: field,
                            identities: component.identities
                        )
                    }
                    return component.resolvedValue ?? 0
                }
                for (selected, group, name) in [
                    (numberText.trackNumberText != nil, inventory.track, "track"),
                    (numberText.discNumberText != nil, inventory.disc, "disc"),
                ] where selected && group.hasUnresolvedComponents {
                    throw MetadataPatchValidationError.ambiguousNumberRecovery(
                        field: name, identities: group.number.identities + group.total.identities
                    )
                }
                var trackPair = numberText.trackNumberText.map(parseNumberPair)
                var discPair = numberText.discNumberText.map(parseNumberPair)
                if let pair = trackPair, pair.total == 0 {
                    trackPair?.total = try resolvedTotal(inventory.track.total, field: "trackTotal")
                }
                if let pair = discPair, pair.total == 0 {
                    discPair?.total = try resolvedTotal(inventory.disc.total, field: "discTotal")
                }
                try TagLibMetadataExtractor.writeNumberPairsInPlace(
                    trackNumber: trackPair?.number ?? 0,
                    totalTracks: trackPair?.total ?? 0,
                    updateTrackPair: trackPair != nil,
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
                if let trackPair {
                    expectedNumberPairs[.track] = trackPair.number
                    expectedNumberPairs[.trackTotal] = trackPair.total
                }
                if let discPair {
                    expectedNumberPairs[.disc] = discPair.number
                    expectedNumberPairs[.discTotal] = discPair.total
                }
            }

            var id3Frames: [StructuredID3v2Frame] = []
            var nativeTextValues: [String: [String]] = [:]
            var nativeTextRemovals: Set<String> = []
            for (field, value) in validatedPatch.fields where !structuredNumberPairFields.contains(field) {
                guard let storage = fieldStorage[field] else { continue }
                switch storage.mechanism {
                case .mp4Atom:
                    nativeFieldAliases.formUnion(storage.keysToRemove)
                    nativeAtoms.append(contentsOf: storage.nativeAliasesToRemove.map {
                        StructuredMP4Atom(key: $0, type: "stringList", values: [], remove: true)
                    })
                    if let atom = structuredMP4Atom(for: storage.mechanism, value: value) {
                        nativeAtoms.append(atom)
                    }
                case .id3Frame(var frame):
                    nativeFieldAliases.formUnion(storage.keysToRemove)
                    frame.values = value.propertyMapValues
                    id3Frames.append(frame)
                case .nativeTextKey(let key):
                    nativeFieldAliases.formUnion(storage.keysToRemove)
                    nativeTextRemovals.formUnion(storage.keysToRemove)
                    if value.propertyMapValues.isEmpty {
                        nativeTextRemovals.insert(key)
                    } else {
                        nativeTextValues[key] = value.propertyMapValues
                    }
                case .propertyMap(let key):
                    keysToRemove.formUnion(storage.keysToRemove)
                    if !value.propertyMapValues.isEmpty {
                        propertyValues[key] = value.propertyMapValues
                    }
                }
            }

            // Scalar comments/lyrics own every qualified native entry.
            for field in [MetadataFieldKey.comment, .lyrics] where validatedPatch.fields[field] != nil {
                let prefix = field == .comment ? "COMMENT:" : "LYRICS:"
                for entry in before.raw.properties where entry.key.uppercased().hasPrefix(prefix) {
                    keysToRemove.insert(entry.key)
                }
            }

            for (key, value) in validatedPatch.customFields {
                if capability(forExtension: ext)?.identifier == "asf" {
                    // ASF PropertyMap cannot represent arbitrary attributes.
                    nativeTextRemovals.insert(key)
                    if !value.propertyMapValues.isEmpty { nativeTextValues[key] = value.propertyMapValues }
                } else {
                    keysToRemove.insert(key)
                    if !value.propertyMapValues.isEmpty { propertyValues[key] = value.propertyMapValues }
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

            if !nativeTextValues.isEmpty || !nativeTextRemovals.isEmpty {
                try TagLibMetadataExtractor.applyNativeTextKeyValuesInPlace(
                    nativeTextValues,
                    removingKeys: Array(nativeTextRemovals),
                    to: mutationURL
                )
            }

            if !propertyValues.isEmpty || !keysToRemove.isEmpty {
                if ext == "wav" {
                    try TagLibMetadataExtractor.applyPropertyMapValuesPreservingInfoSurfaceInPlace(
                        propertyValues, removingKeys: Array(keysToRemove), preserveInfoOnlyValues: false, to: mutationURL)
                } else {
                    try TagLibMetadataExtractor.applyPropertyMapValuesInPlace(
                        propertyValues, removingKeys: Array(keysToRemove), to: mutationURL)
                }
            }

            if !nativeAtoms.isEmpty || !id3Frames.isEmpty {
                try TagLibMetadataExtractor.writeStructuredMetadataInPlace(
                    bridgePayload(
                        from: StructuredMetadata(id3v2Frames: id3Frames, mp4Atoms: nativeAtoms),
                        includeProperties: false,
                        replacingCollections: [],
                        riffPolicy: .preserveInfo
                    ),
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
                    replacingCollections: [.artwork],
                    riffPolicy: .preserveInfo
                )
                try TagLibMetadataExtractor.writeStructuredMetadataInPlace(payload, to: mutationURL)
            case .removeAll:
                let payload = bridgePayload(
                    from: StructuredMetadata(),
                    includeProperties: false,
                    replacingCollections: [.artwork],
                    riffPolicy: .preserveInfo
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
            let afterStructured = (projections["structured"] as? [String: NSObject]).map {
                structuredMetadata(fromBridgeDictionary: $0)
            } ?? StructuredMetadata()
            let afterBasic = basicMetadata(
                fromBridgeMetadata: bridgeBasic,
                rawDump: afterRaw,
                fileExtension: mutationURL.pathExtension,
                structured: afterStructured
            )
            var intentionallyChangedKeys = keysToRemove.union(nativeFieldAliases)
            for field in validatedPatch.fields.keys {
                intentionallyChangedKeys.formUnion(
                    MetadataFieldRegistry.schema(for: field)?.propertyMapKeys ?? []
                )
            }
            for field in expectedNumberPairs.keys {
                intentionallyChangedKeys.formUnion(MetadataFieldRegistry.schema(for: field)?.propertyMapKeys ?? [])
            }
            if patch.explicitAdvisory != nil {
                intentionallyChangedKeys.formUnion(["ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT", "RTNG"])
            }
            // Engine DATE can project YEAR or standalone DATE depending on tag
            // contents. Native ownership is verified below, so that projection
            // must not make an independent DATE removal fail spuriously.
            if validatedPatch.fields[.year] != nil || validatedPatch.fields[.date] != nil
                || validatedPatch.fields[.standaloneDate] != nil {
                intentionallyChangedKeys.insert("DATE")
            }
            // TagLib projects MP4 ©grp as PropertyMap GROUPING, although
            // semantic GROUPING belongs to the independent iTunes freeform.
            // Allow this engine projection only for a Content Group edit;
            // exact native siblings are still checked below.
            let isMP4 = capability(forExtension: ext)?.identifier == "mp4"
            if isMP4, validatedPatch.fields[.contentGroup] != nil {
                intentionallyChangedKeys.insert("GROUPING")
            }
            if (isMP4 || capability(forExtension: ext)?.metadataFieldFormats.contains(.id3v2) == true), validatedPatch.fields[.encoderSettings] != nil {
                intentionallyChangedKeys.insert("ENCODING")
            }
            let primaryID3 = ["mpeg-id3", "mpeg-aac", "wav", "aiff", "trueaudio", "dsf", "dsdiff"]
                .contains(capability(forExtension: ext)?.identifier ?? "")
            if (primaryID3 || capability(forExtension: ext)?.identifier == "asf"), validatedPatch.fields[.contentGroup] != nil {
                // TagLib projects TIT1 and ASF Content Group as WORK.
                // Exact native siblings are verified separately below.
                intentionallyChangedKeys.insert("WORK")
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
            // PropertyMap aliases can overlap semantic identities. Exact native
            // Xiph/APE date values must remain unchanged even when their engine
            // spelling appears in intentionallyChangedKeys for another field.
            let nativeTextDateFamily = ["flac", "ogg-vorbis", "ogg-opus", "ogg-flac", "ogg-speex", "ape", "wavpack", "musepack"]
                .contains(capability(forExtension: ext)?.identifier ?? "")
            if nativeTextDateFamily {
                for (field, key) in [(MetadataFieldKey.year, "YEAR"), (.standaloneDate, "DATE"),
                                     (.releaseDate, "RELEASEDATE"), (.originalReleaseDate, "ORIGINALDATE")] {
                    let changed = validatedPatch.fields[field] != nil
                        || (field == .year && validatedPatch.fields[.date] != nil)
                    guard !changed else { continue }
                    let old = before.structured.properties.filter { $0.key.uppercased() == key }
                    let new = afterStructured.properties.filter { $0.key.uppercased() == key }
                    if old != new { warnings.append("Unedited native date field \(key) changed during the patch.") }
                }
            }
            let dateFields: [MetadataFieldKey] = [.year, .standaloneDate, .releaseDate, .originalReleaseDate]
            let identifier = capability(forExtension: ext)?.identifier ?? ""
            let independentNativeFields = dateFields
                + (identifier == "mp4" || primaryID3 ? [.contentGroup, .grouping, .work] : [])
                + (identifier == "mp4" || primaryID3 ? [.encodedBy, .encoderSettings] : [])
                + (identifier == "mp4" ? [.movementNumber, .movementCount] : [])
            for field in independentNativeFields {
                guard validatedPatch.fields[field] == nil,
                      !(field == .year && validatedPatch.fields[.date] != nil),
                      let schema = MetadataFieldRegistry.schema(for: field) else { continue }
                if identifier == "mp4" {
                    let keys = Set(schema.targets(for: .mp4).map { target in
                        target.storage == .mp4Freeform
                            ? "----:com.apple.iTunes:" + target.nativeIdentity : target.nativeIdentity
                    }).union(mp4ReadAliasDescriptions(for: field).map { "----:com.apple.iTunes:" + $0 })
                    if before.structured.mp4Atoms.filter({ keys.contains($0.key) })
                        != afterStructured.mp4Atoms.filter({ keys.contains($0.key) }) {
                        let kind = dateFields.contains(field) ? "date field" : "field"
                        warnings.append("Unedited native \(kind) \(field.rawValue) changed during the patch.")
                    }
                } else if !nativeTextDateFamily,
                          capability(forExtension: ext)?.metadataFieldFormats.contains(.id3v2) == true {
                    let targets = schema.targets(for: .id3v23) + schema.targets(for: .id3v24)
                    func owned(_ frame: StructuredID3v2Frame) -> Bool {
                        targets.contains { target in
                            target.storage == .userTextFrame
                                ? frame.frameID == "TXXX" && frame.description == target.nativeIdentity
                                : frame.frameID == target.nativeIdentity
                        }
                    }
                    // Creating the first rich tag promotes an existing ID3v1
                    // YEAR into ID3v2; it is the same semantic native value.
                    let promotedLegacyYear = field == .year && before.structured.id3v2Frames.isEmpty
                        && before.raw.properties.first(where: { $0.key == "DATE" })?.values == [afterBasic.year]
                    if !promotedLegacyYear, before.structured.id3v2Frames.filter(owned) != afterStructured.id3v2Frames.filter(owned) {
                        warnings.append("Unedited native date field \(field.rawValue) changed during the patch.")
                    }
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
                guard let storage = fieldStorage[field] else { continue }
                let actual: [String]
                switch storage.mechanism {
                case .mp4Atom(let key, let type):
                    let atom = afterStructured.mp4Atoms.first { $0.key == key }
                    if value == .remove {
                        actual = atom == nil ? [] : (atom?.values ?? [atom?.value ?? ""])
                        if let atom, !atom.values.isEmpty || !atom.value.isEmpty {
                            warnings.append("Patched field \(field.rawValue) remains after removal.")
                        }
                    } else if type == "stringList" {
                        actual = atom?.values ?? []
                    } else if type == "bool" {
                        actual = [structuredBoolean(atom?.value ?? "") == true ? "1" : "0"]
                    } else {
                        actual = [Int(atom?.value ?? "") ?? 0].map(String.init)
                    }
                    let stale = afterStructured.mp4Atoms.filter {
                        storage.nativeAliasesToRemove.contains($0.key)
                    }
                    if !stale.isEmpty {
                        warnings.append("Patched field \(field.rawValue) has stale native aliases.")
                    }
                case .id3Frame(let expectedFrame):
                    if expectedFrame.type == "versionedText" {
                        let frameIDs = [expectedFrame.v23ID, expectedFrame.v24ID].compactMap { $0 }
                        let descriptions = [expectedFrame.v23Description, expectedFrame.v24Description].compactMap { $0 }
                        if value == .remove {
                            let remains = afterStructured.id3v2Frames.contains { frame in
                                frameIDs.contains(frame.frameID)
                                    || (frame.frameID == "TXXX" && descriptions.contains(frame.description ?? ""))
                            }
                            if remains {
                                warnings.append("Patched field \(field.rawValue) remains after removal.")
                            }
                            actual = remains ? value.propertyMapValues : []
                        } else {
                            let matching = afterStructured.id3v2Frames.first { frame in
                                frameIDs.contains(frame.frameID)
                                    || (frame.frameID == "TXXX" && descriptions.contains(frame.description ?? ""))
                            }
                            actual = matching.map { $0.values.isEmpty ? [$0.value] : $0.values } ?? []
                        }
                    } else {
                        let matching = afterStructured.id3v2Frames.first {
                            $0.frameID == expectedFrame.frameID && $0.description == expectedFrame.description
                        }
                        actual = matching?.values ?? []
                    }
                case .nativeTextKey(let key), .propertyMap(let key):
                    // TagLib exposes these exact APE owners under its
                    // canonical PropertyMap dialect rather than native names.
                    let isAPE = ["ape", "wavpack", "musepack"].contains(capability(forExtension: ext)?.identifier ?? "")
                    let projectionKey: String = isAPE ? (["ALBUM ARTIST": "ALBUMARTIST", "MIXARTIST": "REMIXER"][key] ?? key) : key
                    let asfValues = afterStructured.asfAttributes
                        .filter { key.caseInsensitiveCompare($0.key) == .orderedSame }
                        .map(\.value)
                    if case .nativeTextKey = storage.mechanism,
                       capability(forExtension: ext)?.identifier == "asf" {
                        // Native absence is authoritative. Engine DATE can
                        // still project WM/Year after independent DATE removal.
                        actual = asfValues
                    } else {
                        actual = !asfValues.isEmpty
                            ? asfValues
                            : afterRaw.properties.first {
                                projectionKey.caseInsensitiveCompare($0.key) == .orderedSame
                            }?.values ?? []
                    }
                }
                if field != .date,
                   MetadataFieldRegistry.schema(for: field)?.acceptedPatchValueKinds.contains(.text) == true,
                   let semantic = basicProjectionValue(for: field, metadata: afterBasic) {
                    switch value {
                    case .text(let expected) where semantic != expected:
                        warnings.append("Patched semantic field \(field.rawValue) differs after save.")
                    case .remove where !semantic.isEmpty:
                        warnings.append("Patched semantic field \(field.rawValue) remains after removal.")
                    default: break
                    }
                }
                if actual != value.propertyMapValues {
                    warnings.append("Patched field \(field.rawValue) differs after save.")
                }
            }
            let formats = capability(forExtension: ext)?.metadataFieldFormats ?? []
            // FLAC may contain secondary ID3 tags, but its semantic comment
            // writes use Xiph. Verify the active family, not every possible tag.
            if formats.contains(.id3v2), !nativeTextDateFamily, !formats.contains(.asf) {
                for field in [MetadataFieldKey.comment, .lyrics] {
                    guard let value = validatedPatch.fields[field] else { continue }
                    let texts = field == .comment ? afterStructured.comments.map(\.text) : afterStructured.lyrics.map(\.text)
                    if texts != value.propertyMapValues {
                        warnings.append("Patched native \(field.rawValue) collection differs after save.")
                    }
                }
            }
            for (key, value) in validatedPatch.customFields {
                let actual: [String]
                if capability(forExtension: ext)?.identifier == "asf" {
                    actual = afterStructured.asfAttributes.filter {
                        $0.key.caseInsensitiveCompare(key) == .orderedSame
                    }.map(\.value)
                } else {
                    actual = afterRaw.properties.first {
                        $0.key.caseInsensitiveCompare(key) == .orderedSame
                    }?.values ?? []
                }
                if actual != value.propertyMapValues {
                    warnings.append("Patched custom field \(key) differs after save.")
                }
            }
            if let advisory = patch.explicitAdvisory, afterBasic.explicitAdvisory != advisory {
                warnings.append("Patched explicit advisory differs after save.")
            }
            if let numberText = patch.numberText {
                if let trackNumberText = numberText.trackNumberText {
                    let expectedTrackText = trackNumberText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let expectedTrackPair = parseNumberPair(expectedTrackText)
                    let trackPairStoredAcrossFields = afterBasic.track == expectedTrackPair.number &&
                        afterBasic.trackTotal == (expectedNumberPairs[.trackTotal] ?? expectedTrackPair.total)
                    if afterBasic.trackNumberText != expectedTrackText && !trackPairStoredAcrossFields {
                        warnings.append("Patched track number text differs after save.")
                    }
                }
                if let discNumberText = numberText.discNumberText {
                    let expectedDiscText = discNumberText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let expectedDiscPair = parseNumberPair(expectedDiscText)
                    let discPairStoredAcrossFields = afterBasic.disc == expectedDiscPair.number &&
                        afterBasic.discTotal == (expectedNumberPairs[.discTotal] ?? expectedDiscPair.total)
                    if afterBasic.discNumberText != expectedDiscText && !discPairStoredAcrossFields {
                        warnings.append("Patched disc number text differs after save.")
                    }
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

            try throwOnVerificationFailures(warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }

    @available(*, deprecated, message: "Verification mismatches always throw. Omit failurePolicy.")
    @discardableResult
    public nonisolated static func applyMetadataPatch(
        _ patch: MetadataPatch,
        to url: URL,
        expectedVersion: MetadataFileVersion? = nil,
        failurePolicy: VerificationFailurePolicy
    ) throws -> MetadataWriteResult {
        try applyMetadataPatch(patch, to: url, expectedVersion: expectedVersion)
    }
}
