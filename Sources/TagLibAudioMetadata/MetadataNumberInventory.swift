//
//  MetadataNumberInventory.swift
//  TagLibAudioMetadata
//
//  Full-fidelity track/disc numbering inventory and explicit legacy recovery.
//

import Foundation
import CTagLibBridge
import CTagLibBridgeInternalAPI

/// State of one semantic number component resolved from native storage and
/// legacy aliases. Absence, explicit removal, and unresolved recovery are
/// distinct throughout drafts, previews, and exports.
public enum MetadataNumberComponentState: String, Hashable, Sendable {
    case absent
    case native
    case recoveredLegacy
    case ambiguous
    case invalid
}

public struct MetadataNumberComponentInventory: Hashable, Sendable {
    public var state: MetadataNumberComponentState
    public var nativeValue: Int?
    public var recoveredValue: Int?
    /// Exact original candidate strings, retained even when unparsable.
    public var candidates: [String]
    /// Exact native identities that supplied the candidates.
    public var identities: [String]
    public var hasUnresolvedNativeValues: Bool

    public init(
        state: MetadataNumberComponentState,
        nativeValue: Int? = nil,
        recoveredValue: Int? = nil,
        candidates: [String] = [],
        identities: [String] = [],
        hasUnresolvedNativeValues: Bool = false
    ) {
        self.state = state
        self.nativeValue = nativeValue
        self.recoveredValue = recoveredValue
        self.candidates = candidates
        self.identities = identities
        self.hasUnresolvedNativeValues = hasUnresolvedNativeValues
    }

    /// The value an explicit pair write should use, or nil when the component
    /// is absent. Ambiguous/invalid recovery must be resolved explicitly.
    public var resolvedValue: Int? {
        switch state {
        case .native: nativeValue
        case .recoveredLegacy: recoveredValue
        default: nil
        }
    }

    public var isUnresolved: Bool {
        state == .ambiguous || state == .invalid
    }
}

public struct MetadataNumberPrivateTextInventory: Hashable, Sendable {
    /// Exact fully-qualified MP4 freeform key.
    public var identity: String
    public var description: String
    public var namespace: String
    public var values: [String]
    public var parsedNumber: Int?
    public var parsedTotal: Int?
    public var isStrictlyNumeric: Bool

    public init(
        identity: String,
        description: String,
        namespace: String,
        values: [String],
        parsedNumber: Int?,
        parsedTotal: Int?,
        isStrictlyNumeric: Bool
    ) {
        self.identity = identity
        self.description = description
        self.namespace = namespace
        self.values = values
        self.parsedNumber = parsedNumber
        self.parsedTotal = parsedTotal
        self.isStrictlyNumeric = isStrictlyNumeric
    }
}

public struct MetadataNumberGroupInventory: Hashable, Sendable {
    public var number: MetadataNumberComponentInventory
    public var total: MetadataNumberComponentInventory
    /// Native pair identities in the source surface (for example `trkn`).
    public var nativeIdentities: [String]
    /// Exact standalone alias identities that duplicate or supply a component.
    public var legacyAliasIdentities: [String]
    /// Legacy MP4 private formatting provenance for this pair.
    public var privateTexts: [MetadataNumberPrivateTextInventory]
    public var warnings: [String]

    public init(
        number: MetadataNumberComponentInventory,
        total: MetadataNumberComponentInventory,
        nativeIdentities: [String] = [],
        legacyAliasIdentities: [String] = [],
        privateTexts: [MetadataNumberPrivateTextInventory] = [],
        warnings: [String] = []
    ) {
        self.number = number
        self.total = total
        self.nativeIdentities = nativeIdentities
        self.legacyAliasIdentities = legacyAliasIdentities
        self.privateTexts = privateTexts
        self.warnings = warnings
    }

    public var hasUnresolvedComponents: Bool {
        number.isUnresolved || total.isUnresolved
    }
}

public struct MetadataNumberingInventory: Hashable, Sendable {
    public var track: MetadataNumberGroupInventory
    public var disc: MetadataNumberGroupInventory
    public var fileVersion: MetadataFileVersion?
    public var warnings: [String]

    public init(
        track: MetadataNumberGroupInventory,
        disc: MetadataNumberGroupInventory,
        fileVersion: MetadataFileVersion? = nil,
        warnings: [String] = []
    ) {
        self.track = track
        self.disc = disc
        self.fileVersion = fileVersion
        self.warnings = warnings
    }
}

/// Explicit resolution policy for a normalization plan. Headless callers must
/// choose one; there is no implicit app preference.
public enum MetadataNumberResolutionPolicy: Hashable, Sendable {
    case useNative
    case useLegacy
    case replace(number: Int?, total: Int?)
}

public enum MetadataNumberGroup: String, CaseIterable, Hashable, Sendable {
    case track
    case disc
}

public struct MetadataNumberNormalizationPlan: Hashable, Sendable {
    public let groups: Set<MetadataNumberGroup>
    public let fileVersion: MetadataFileVersion
    public let trackNumber: Int?
    public let trackTotal: Int?
    public let discNumber: Int?
    public let discTotal: Int?
    /// Exact MP4 freeform keys, ID3 TXXX descriptions, or Xiph/APE keys.
    public let removals: [String]
    /// Exact private MP4 freeform keys selected for retirement.
    public let privateRemovals: [String]
    public let warnings: [String]
    public let inventory: MetadataNumberingInventory

    public init(
        groups: Set<MetadataNumberGroup>,
        fileVersion: MetadataFileVersion,
        trackNumber: Int?,
        trackTotal: Int?,
        discNumber: Int?,
        discTotal: Int?,
        removals: [String],
        privateRemovals: [String],
        warnings: [String],
        inventory: MetadataNumberingInventory
    ) {
        self.groups = groups
        self.fileVersion = fileVersion
        self.trackNumber = trackNumber
        self.trackTotal = trackTotal
        self.discNumber = discNumber
        self.discTotal = discTotal
        self.removals = removals
        self.privateRemovals = privateRemovals
        self.warnings = warnings
        self.inventory = inventory
    }
}

extension TagLibMetadataManager {
    nonisolated static func parseStrictNumber(_ raw: String, allowZero: Bool = false) -> Int? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.unicodeScalars.allSatisfy({ (48...57).contains($0.value) }),
              let value = Int(text), value >= (allowZero ? 0 : 1), value <= Int(Int32.max) else { return nil }
        return value
    }

    nonisolated static func parseStrictPair(_ raw: String) -> (number: Int, total: Int?)? {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2 else { return nil }
        let number: Int
        if parts[0].isEmpty, parts.count == 2 {
            number = 0
        } else {
            guard let parsed = parseStrictNumber(String(parts[0]), allowZero: parts.count == 2) else { return nil }
            number = parsed
        }
        if parts.count == 2 {
            guard let total = parseStrictNumber(String(parts[1])) else { return nil }
            return (number, total)
        }
        return (number, nil)
    }

    private struct NumberCandidate {
        var identity: String
        var text: String
        var value: Int?
    }

    nonisolated private static func resolveNumberComponent(
        native: [NumberCandidate], legacy: [NumberCandidate]
    ) -> MetadataNumberComponentInventory {
        let nativeValues = Set(native.compactMap(\.value))
        let legacyValues = Set(legacy.compactMap(\.value))
        let nativeInvalid = native.contains { $0.value == nil }
            || Dictionary(grouping: native, by: \.identity).values.contains { $0.count > 1 }
            || nativeValues.count > 1
        let legacyInvalid = legacy.contains { $0.value == nil }
            || Dictionary(grouping: legacy, by: \.identity).values.contains { $0.count > 1 }
        let nativeValue = !nativeInvalid && nativeValues.count == 1 ? nativeValues.first : nil
        let invalid = (native + legacy).contains { $0.value == nil }
        let distinct = nativeValues.union(legacyValues)
        let state: MetadataNumberComponentState
        if invalid && distinct.isEmpty {
            state = .invalid
        } else if nativeInvalid || legacyInvalid || distinct.count > 1 || invalid {
            state = .ambiguous
        } else if nativeValue != nil {
            state = .native
        } else if !legacyValues.isEmpty {
            state = .recoveredLegacy
        } else {
            state = .absent
        }
        return MetadataNumberComponentInventory(
            state: state,
            nativeValue: nativeValue,
            recoveredValue: legacyValues.count == 1 && !legacyInvalid
                ? legacyValues.first : nil,
            candidates: legacy.map(\.text),
            identities: legacy.map(\.identity), hasUnresolvedNativeValues: nativeInvalid
        )
    }

    public nonisolated static func numberingInventory(at url: URL) throws -> MetadataNumberingInventory {
        numberingInventory(from: try readSnapshot(from: url))
    }

    nonisolated static func numberingInventory(from snapshot: MetadataSnapshot) -> MetadataNumberingInventory {
        numberingInventory(
            raw: snapshot.raw, structured: snapshot.structured,
            isMP4: !snapshot.structured.mp4Atoms.isEmpty,
            isID3: !snapshot.structured.id3v2Frames.isEmpty || !snapshot.raw.id3v2Frames.isEmpty,
            version: snapshot.fileVersion
        )
    }

    nonisolated static func numberingInventory(
        raw: RawMetadataDump, structured: StructuredMetadata,
        isMP4: Bool, isID3: Bool, version: MetadataFileVersion?
    ) -> MetadataNumberingInventory {
        func rawEntries(_ keys: [String]) -> [(String, [String])] {
            raw.properties.filter { entry in keys.contains { $0.caseInsensitiveCompare(entry.key) == .orderedSame } }
                .map { ($0.key, $0.values.isEmpty ? [$0.value] : $0.values) }
        }
        func group(_ track: Bool) -> MetadataNumberGroupInventory {
            let frameID = track ? "TRCK" : "TPOS"
            let atomKey = track ? "trkn" : "disk"
            let numbers = track ? ["TRACKNUMBER", "TRACK"] : ["DISCNUMBER", "DISC"]
            let totals = track ? ["TRACKTOTAL", "TOTALTRACKS"] : ["DISCTOTAL", "TOTALDISCS"]
            var nativeNumbers: [NumberCandidate] = []
            var nativeTotals: [NumberCandidate] = []
            var legacyNumbers: [NumberCandidate] = []
            var legacyTotals: [NumberCandidate] = []
            var nativeIdentities: [String] = []
            var aliasIdentities: [String] = []
            var privateTexts: [MetadataNumberPrivateTextInventory] = []
            let maximum = isMP4 ? 65535 : Int(Int32.max)
            func scalar(_ identity: String, _ text: String) -> NumberCandidate {
                let value = parseStrictNumber(text)
                return NumberCandidate(identity: identity, text: text, value: value.flatMap { $0 <= maximum ? $0 : nil })
            }
            func pair(_ identity: String, _ text: String, native: Bool) {
                guard let parsed = parseStrictPair(text), parsed.number <= maximum,
                      (parsed.total ?? 0) <= maximum else {
                    let invalid = NumberCandidate(identity: identity, text: text, value: nil)
                    if native { nativeNumbers.append(invalid) } else { legacyNumbers.append(invalid) }
                    return
                }
                if parsed.number > 0 {
                    let candidate = NumberCandidate(identity: identity, text: text, value: parsed.number)
                    if native { nativeNumbers.append(candidate) } else { legacyNumbers.append(candidate) }
                }
                if let total = parsed.total {
                    let candidate = NumberCandidate(identity: identity, text: text, value: total)
                    if native { nativeTotals.append(candidate) } else { legacyTotals.append(candidate) }
                }
            }
            if isMP4 {
                for atom in structured.mp4Atoms where atom.key == atomKey {
                    nativeIdentities.append(atom.key)
                    if let value = atom.first, value > 0 { nativeNumbers.append(scalar(atom.key, String(value))) }
                    if let value = atom.second, value > 0 { nativeTotals.append(scalar(atom.key, String(value))) }
                }
                let descriptions = track
                    ? ["AUDIOMATOR_TRACKNUMBER_TEXT", "TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"]
                    : ["AUDIOMATOR_DISCNUMBER_TEXT", "TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT"]
                for atom in structured.mp4Atoms {
                    // Only this exact namespace is ours. Preserve the actual
                    // description spelling for removal; never broaden by prefix.
                    let prefix = "----:com.apple.iTunes:"
                    guard atom.key.hasPrefix(prefix) else { continue }
                    let description = String(atom.key.dropFirst(prefix.count))
                    let values = atom.values.isEmpty ? [atom.value] : atom.values
                    if descriptions.contains(description) {
                        let parsed = values.count == 1 ? parseStrictPair(values[0]) : nil
                        let strict = parsed.map { $0.number <= maximum && ($0.total ?? 0) <= maximum } ?? false
                        privateTexts.append(.init(
                            identity: atom.key, description: description, namespace: "com.apple.iTunes",
                            values: values, parsedNumber: strict ? parsed.flatMap { $0.number > 0 ? $0.number : nil } : nil,
                            parsedTotal: strict ? parsed?.total : nil, isStrictlyNumeric: strict
                        ))
                        for text in values { pair(atom.key, text, native: false) }
                    } else if numbers.contains(description.uppercased()) {
                        aliasIdentities.append(atom.key)
                        for text in values { pair(atom.key, text, native: false) }
                    } else if totals.contains(description.uppercased()) {
                        aliasIdentities.append(atom.key)
                        legacyTotals += values.map { scalar(atom.key, $0) }
                    }
                }
            } else if isID3 {
                let frames = structured.id3v2Frames.filter { $0.frameID == frameID }
                for frame in frames {
                    nativeIdentities.append(frameID)
                    for text in frame.values.isEmpty ? [frame.value] : frame.values { pair(frameID, text, native: true) }
                }
                for frame in structured.id3v2Frames where frame.frameID == "TXXX" {
                    guard let description = frame.description, totals.contains(description.uppercased()) else { continue }
                    let identity = "TXXX:\(description)"
                    aliasIdentities.append(identity)
                    legacyTotals += (frame.values.isEmpty ? [frame.value] : frame.values).map { scalar(identity, $0) }
                }
            } else {
                let asfKey = track ? "WM/TrackNumber" : "WM/PartOfSet"
                let attributes = structured.asfAttributes.filter { $0.key == asfKey }
                if !attributes.isEmpty {
                    nativeIdentities.append(asfKey)
                    for attribute in attributes { pair(asfKey, attribute.value, native: true) }
                } else {
                    // Engine projection uses TRACKNUMBER for some APE layouts.
                    // The existing ordinary number key is native, not recovery.
                    let entries = rawEntries(numbers)
                    for (index, entry) in entries.enumerated() {
                        if index == 0 { nativeIdentities.append(entry.0) } else { aliasIdentities.append(entry.0) }
                        for text in entry.1 { pair(entry.0, text, native: index == 0) }
                    }
                }
                for entry in rawEntries(totals) {
                    if entry.0.uppercased() == totals[0] {
                        nativeIdentities.append(entry.0)
                        nativeTotals += entry.1.map { scalar(entry.0, $0) }
                    } else {
                        aliasIdentities.append(entry.0)
                        legacyTotals += entry.1.map { scalar(entry.0, $0) }
                    }
                }
            }
            return MetadataNumberGroupInventory(
                number: resolveNumberComponent(native: nativeNumbers, legacy: legacyNumbers),
                total: resolveNumberComponent(native: nativeTotals, legacy: legacyTotals),
                nativeIdentities: nativeIdentities, legacyAliasIdentities: aliasIdentities,
                privateTexts: privateTexts, warnings: []
            )
        }
        return MetadataNumberingInventory(track: group(true), disc: group(false), fileVersion: version)
    }

    public nonisolated static func planNumberNormalization(
        at url: URL, policy: MetadataNumberResolutionPolicy,
        groups: Set<MetadataNumberGroup> = [.track, .disc]
    ) throws -> MetadataNumberNormalizationPlan {
        let inventory = try numberingInventory(at: url)
        guard let version = inventory.fileVersion else { throw TagLibManagerError.fileChanged }
        func resolve(_ group: MetadataNumberGroup) throws -> (Int?, Int?) {
            let value = group == .track ? inventory.track : inventory.disc
            guard groups.contains(group) else { return (value.number.resolvedValue, value.total.resolvedValue) }
            switch policy {
            case .useNative:
                // Multiple/malformed native values cannot be resolved by merely
                // choosing a native policy. An explicit replacement is required.
                if value.number.hasUnresolvedNativeValues || value.total.hasUnresolvedNativeValues {
                    throw MetadataPatchValidationError.ambiguousNumberRecovery(field: group.rawValue, identities: value.nativeIdentities)
                }
                return (value.number.nativeValue, value.total.nativeValue)
            case .useLegacy:
                func component(_ item: MetadataNumberComponentInventory) throws -> Int? {
                    if !item.candidates.isEmpty {
                        guard let recovered = item.recoveredValue else {
                            throw MetadataPatchValidationError.ambiguousNumberRecovery(field: group.rawValue, identities: item.identities)
                        }
                        return recovered
                    }
                    guard !item.isUnresolved else {
                        throw MetadataPatchValidationError.ambiguousNumberRecovery(field: group.rawValue, identities: value.nativeIdentities)
                    }
                    return item.nativeValue
                }
                return (try component(value.number), try component(value.total))
            case .replace(let number, let total): return (number, total)
            }
        }
        let track = try resolve(.track)
        let disc = try resolve(.disc)
        var removals = Set<String>()
        var privateRemovals = Set<String>()
        for group in groups {
            let value = group == .track ? inventory.track : inventory.disc
            removals.formUnion(value.legacyAliasIdentities)
            privateRemovals.formUnion(value.privateTexts.map(\.identity))
            let pair = group == .track ? track : disc
            try validateNativeNumberPair(number: pair.0 ?? 0, total: pair.1 ?? 0, field: group == .track ? .track : .disc, for: url)
        }
        return MetadataNumberNormalizationPlan(
            groups: groups, fileVersion: version, trackNumber: track.0, trackTotal: track.1,
            discNumber: disc.0, discTotal: disc.1, removals: removals.sorted(),
            privateRemovals: privateRemovals.sorted(), warnings: inventory.warnings, inventory: inventory
        )
    }

    @discardableResult
    public nonisolated static func applyNumberNormalization(
        _ plan: MetadataNumberNormalizationPlan, to url: URL,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        guard expectedVersion == nil || expectedVersion == plan.fileVersion else { throw TagLibManagerError.fileChanged }
        if plan.groups.isEmpty {
            guard plan.removals.isEmpty, plan.privateRemovals.isEmpty,
                  try fileVersion(at: url) == plan.fileVersion else { throw TagLibManagerError.fileChanged }
            return MetadataWriteResult(warnings: plan.warnings)
        }
        return try MetadataFileTransaction.withAtomicMetadataWriteMutation(at: url, expectedVersion: plan.fileVersion) { mutationURL in
            let before = try readSnapshot(from: mutationURL)
            let beforeInventory = numberingInventory(from: before)
            let allowedAliases = plan.groups.flatMap { ($0 == .track ? plan.inventory.track : plan.inventory.disc).legacyAliasIdentities }
            let allowedPrivate = plan.groups.flatMap { ($0 == .track ? plan.inventory.track : plan.inventory.disc).privateTexts.map(\.identity) }
            guard Set(plan.removals).isSubset(of: Set(allowedAliases)),
                  Set(plan.privateRemovals).isSubset(of: Set(allowedPrivate)) else {
                throw TagLibManagerError.operationFailed("Numbering cleanup contains identities outside its selected groups.")
            }
            for group in plan.groups {
                try validateNativeNumberPair(
                    number: (group == .track ? plan.trackNumber : plan.discNumber) ?? 0,
                    total: (group == .track ? plan.trackTotal : plan.discTotal) ?? 0,
                    field: group == .track ? .track : .disc, for: mutationURL
                )
            }
            try TagLibMetadataExtractor.writeNumberPairsInPlace(
                trackNumber: plan.trackNumber ?? 0, totalTracks: plan.trackTotal ?? 0,
                updateTrackPair: plan.groups.contains(.track),
                discNumber: plan.discNumber ?? 0, totalDiscs: plan.discTotal ?? 0,
                updateDiscPair: plan.groups.contains(.disc), to: mutationURL
            )
            var mp4Atoms: [StructuredMP4Atom] = []
            var id3Frames: [StructuredID3v2Frame] = []
            var nativeRemovals: [String] = []
            for identity in plan.removals + plan.privateRemovals {
                if identity.hasPrefix("----:") {
                    mp4Atoms.append(.init(key: identity, type: "stringList", values: [], remove: true))
                } else if identity.hasPrefix("TXXX:") {
                    id3Frames.append(.init(frameID: "TXXX", type: "userText", description: String(identity.dropFirst(5))))
                } else { nativeRemovals.append(identity) }
            }
            if !mp4Atoms.isEmpty || !id3Frames.isEmpty {
                try TagLibMetadataExtractor.writeStructuredMetadataInPlace(
                    bridgePayload(from: StructuredMetadata(id3v2Frames: id3Frames, mp4Atoms: mp4Atoms),
                                  includeProperties: false, replacingCollections: [], riffPolicy: .preserveInfo),
                    to: mutationURL
                )
            }
            if !nativeRemovals.isEmpty {
                try TagLibMetadataExtractor.applyNativeTextKeyValuesInPlace([:], removingKeys: nativeRemovals, to: mutationURL)
            }
            let after = try readSnapshot(from: mutationURL)
            let afterInventory = numberingInventory(from: after)
            var failures: [String] = []
            for group in MetadataNumberGroup.allCases {
                let actual = group == .track ? afterInventory.track : afterInventory.disc
                if plan.groups.contains(group) {
                    let number = group == .track ? plan.trackNumber : plan.discNumber
                    let total = group == .track ? plan.trackTotal : plan.discTotal
                    if actual.number.nativeValue != number || actual.total.nativeValue != total {
                        failures.append("Normalized \(group.rawValue) native pair differs after save.")
                    }
                } else {
                    let names = group == .track
                        ? ["TRACKNUMBER", "TRACK", "TRACKTOTAL", "TOTALTRACKS", "AUDIOMATOR_TRACKNUMBER_TEXT", "TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"]
                        : ["DISCNUMBER", "DISC", "DISCTOTAL", "TOTALDISCS", "AUDIOMATOR_DISCNUMBER_TEXT", "TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT"]
                    let pairKey = group == .track ? "trkn" : "disk"
                    let frameID = group == .track ? "TRCK" : "TPOS"
                    let attribute = group == .track ? "WM/TrackNumber" : "WM/PartOfSet"
                    func rawValues(_ snapshot: MetadataSnapshot) -> [RawPropertyEntry] {
                        snapshot.raw.properties.filter { names.contains($0.key.uppercased()) }
                    }
                    func atoms(_ snapshot: MetadataSnapshot) -> [StructuredMP4Atom] {
                        snapshot.structured.mp4Atoms.filter {
                            $0.key == pairKey || names.contains($0.freeformDescription?.uppercased() ?? "")
                        }
                    }
                    func frames(_ snapshot: MetadataSnapshot) -> [StructuredID3v2Frame] {
                        snapshot.structured.id3v2Frames.filter {
                            $0.frameID == frameID || ($0.frameID == "TXXX" && names.contains($0.description?.uppercased() ?? ""))
                        }
                    }
                    if actual != (group == .track ? beforeInventory.track : beforeInventory.disc)
                        || rawValues(before) != rawValues(after) || atoms(before) != atoms(after)
                        || frames(before) != frames(after)
                        || before.structured.asfAttributes.filter({ $0.key == attribute })
                            != after.structured.asfAttributes.filter({ $0.key == attribute }) {
                        failures.append("Unselected \(group.rawValue) numbering changed during cleanup.")
                    }
                }
            }
            for identity in plan.removals + plan.privateRemovals {
                let remains: Bool
                if identity.hasPrefix("----:") { remains = after.structured.mp4Atoms.contains { $0.key == identity } }
                else if identity.hasPrefix("TXXX:") { remains = after.structured.id3v2Frames.contains { $0.frameID == "TXXX" && $0.description == String(identity.dropFirst(5)) } }
                else { remains = after.raw.properties.contains { $0.key == identity } }
                if remains { failures.append("Selected numbering alias \(identity) remains after cleanup.") }
            }
            try throwOnVerificationFailures(failures)
            return MetadataWriteResult(warnings: plan.warnings)
        }
    }
}
