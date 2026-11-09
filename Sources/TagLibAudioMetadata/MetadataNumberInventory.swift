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

    public init(
        state: MetadataNumberComponentState,
        nativeValue: Int? = nil,
        recoveredValue: Int? = nil,
        candidates: [String] = [],
        identities: [String] = []
    ) {
        self.state = state
        self.nativeValue = nativeValue
        self.recoveredValue = recoveredValue
        self.candidates = candidates
        self.identities = identities
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
    public var groups: Set<MetadataNumberGroup>
    public var fileVersion: MetadataFileVersion
    public var trackNumber: Int?
    public var trackTotal: Int?
    public var discNumber: Int?
    public var discTotal: Int?
    /// Exact MP4 freeform keys, ID3 TXXX descriptions, or Xiph/APE keys.
    public var removals: [String]
    /// Exact private MP4 freeform keys selected for retirement.
    public var privateRemovals: [String]
    public var warnings: [String]
    public var inventory: MetadataNumberingInventory

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
        guard !text.isEmpty, text.unicodeScalars.allSatisfy({ $0.value >= 48 && $0.value <= 57 }) else {
            return nil
        }
        guard let value = Int(text), value >= (allowZero ? 0 : 1) else { return nil }
        return value
    }

    nonisolated static func parseStrictPair(_ raw: String) -> (number: Int, total: Int?)? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let parts = text.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2, !parts.contains(where: \.isEmpty) else {
            return nil
        }
        guard let number = parseStrictNumber(String(parts[0])) else { return nil }
        if parts.count == 2 {
            guard let total = parseStrictNumber(String(parts[1])) else { return nil }
            return (number, total)
        }
        return (number, nil)
    }

    nonisolated static func numberComponent(
        native: Int?,
        candidates: [(identity: String, text: String, totalOnly: Bool)]
    ) -> MetadataNumberComponentInventory {
        if let native, native > 0 {
            return MetadataNumberComponentInventory(state: .native, nativeValue: native)
        }
        guard !candidates.isEmpty else {
            return MetadataNumberComponentInventory(state: .absent)
        }
        var valid: [(value: Int, identity: String, text: String)] = []
        var invalid: [(identity: String, text: String)] = []
        for candidate in candidates {
            if candidate.totalOnly {
                if let value = parseStrictNumber(candidate.text) {
                    valid.append((value, candidate.identity, candidate.text))
                } else {
                    invalid.append((candidate.identity, candidate.text))
                }
            } else if let pair = parseStrictPair(candidate.text) {
                valid.append((pair.number, candidate.identity, candidate.text))
            } else {
                invalid.append((candidate.identity, candidate.text))
            }
        }
        let distinct = Set(valid.map(\.value))
        let candidatesText = candidates.map(\.text)
        let identities = candidates.map(\.identity)
        if distinct.count == 1, invalid.isEmpty, let value = distinct.first {
            return MetadataNumberComponentInventory(
                state: .recoveredLegacy,
                recoveredValue: value,
                candidates: candidatesText,
                identities: identities
            )
        }
        if distinct.count > 1 || (distinct.count >= 1 && !invalid.isEmpty) {
            return MetadataNumberComponentInventory(
                state: .ambiguous,
                candidates: candidatesText,
                identities: identities
            )
        }
        return MetadataNumberComponentInventory(
            state: .invalid,
            candidates: candidatesText,
            identities: identities
        )
    }

    nonisolated static func totalComponent(
        native: Int?,
        candidates: [(identity: String, text: String, combined: Bool)]
    ) -> MetadataNumberComponentInventory {
        if let native, native > 0 {
            return MetadataNumberComponentInventory(state: .native, nativeValue: native)
        }
        guard !candidates.isEmpty else {
            return MetadataNumberComponentInventory(state: .absent)
        }
        var valid: [(value: Int, identity: String, text: String)] = []
        var invalid: [(identity: String, text: String)] = []
        for candidate in candidates {
            let value: Int?
            if candidate.combined {
                value = parseStrictPair(candidate.text)?.total
            } else {
                value = parseStrictNumber(candidate.text)
            }
            if let value, value > 0 {
                valid.append((value, candidate.identity, candidate.text))
            } else {
                invalid.append((candidate.identity, candidate.text))
            }
        }
        let distinct = Set(valid.map(\.value))
        let candidatesText = candidates.map(\.text)
        let identities = candidates.map(\.identity)
        if distinct.count == 1, invalid.isEmpty, let value = distinct.first {
            return MetadataNumberComponentInventory(
                state: .recoveredLegacy,
                recoveredValue: value,
                candidates: candidatesText,
                identities: identities
            )
        }
        if distinct.count > 1 || (distinct.count >= 1 && !invalid.isEmpty) {
            return MetadataNumberComponentInventory(
                state: .ambiguous,
                candidates: candidatesText,
                identities: identities
            )
        }
        return MetadataNumberComponentInventory(
            state: .invalid,
            candidates: candidatesText,
            identities: identities
        )
    }

    public nonisolated static func numberingInventory(at url: URL) throws -> MetadataNumberingInventory {
        let snapshot = try readSnapshot(from: url)
        return numberingInventory(from: snapshot)
    }

    nonisolated static func numberingInventory(from snapshot: MetadataSnapshot) -> MetadataNumberingInventory {
        let isMP4 = snapshot.structured.mp4Atoms.contains { $0.key == "trkn" || $0.key == "disk" }
            || snapshot.structured.mp4Atoms.contains { $0.freeformDescription != nil }
        let isID3 = snapshot.structured.id3v2Frames.contains { $0.frameID == "TRCK" || $0.frameID == "TPOS" }
            || snapshot.raw.id3v2Frames.contains { $0.frameID == "TRCK" || $0.frameID == "TPOS" }
        return numberingInventory(
            raw: snapshot.raw,
            structured: snapshot.structured,
            isMP4: isMP4,
            isID3: isID3,
            version: snapshot.fileVersion
        )
    }

    nonisolated static func numberingInventory(
        raw: RawMetadataDump,
        structured: StructuredMetadata,
        isMP4: Bool,
        isID3: Bool,
        version: MetadataFileVersion?
    ) -> MetadataNumberingInventory {
        let trackAliasDescriptions = ["TRACKNUMBER", "TRACK", "TRACKTOTAL", "TOTALTRACKS"]
        let discAliasDescriptions = ["DISCNUMBER", "DISC", "DISCTOTAL", "TOTALDISCS"]
        let privateDescriptions = [
            "AUDIOMATOR_TRACKNUMBER_TEXT", "AUDIOMATOR_DISCNUMBER_TEXT",
            "TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT", "TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT",
        ]

        func rawValue(_ key: String) -> String? {
            raw.properties.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.values.first
        }

        func frameValues(_ frameID: String) -> [String] {
            structured.id3v2Frames.filter { $0.frameID.caseInsensitiveCompare(frameID) == .orderedSame }
                .flatMap { $0.values.isEmpty ? [$0.value] : $0.values }
        }

        func userText(_ description: String) -> [String] {
            structured.id3v2Frames.filter {
                $0.frameID == "TXXX" && $0.description?.caseInsensitiveCompare(description) == .orderedSame
            }.flatMap { $0.values.isEmpty ? [$0.value] : $0.values }
        }

        func freeform(_ description: String) -> (identity: String, values: [String])? {
            guard let atom = structured.mp4Atoms.first(where: {
                $0.freeformDescription?.caseInsensitiveCompare(description) == .orderedSame
            }) else { return nil }
            return (atom.key, atom.values.isEmpty ? [atom.value] : atom.values)
        }

        func nativePair(_ key: String) -> (Int?, Int?) {
            guard let atom = structured.mp4Atoms.first(where: { $0.key == key }) else { return (nil, nil) }
            return (atom.first, atom.second)
        }

        var trackCandidates: [(identity: String, text: String, totalOnly: Bool)] = []
        var trackTotals: [(identity: String, text: String, combined: Bool)] = []
        var discCandidates: [(identity: String, text: String, totalOnly: Bool)] = []
        var discTotals: [(identity: String, text: String, combined: Bool)] = []
        var aliasIdentities: [String] = []
        var warnings: [String] = []

        if isMP4 {
            for description in trackAliasDescriptions {
                guard let candidate = freeform(description) else { continue }
                aliasIdentities.append(candidate.identity)
                let isTotal = description == "TRACKTOTAL" || description == "TOTALTRACKS"
                for value in candidate.values {
                    if isTotal {
                        trackTotals.append((candidate.identity, value, false))
                    } else {
                        trackCandidates.append((candidate.identity, value, false))
                        if parseStrictPair(value)?.total != nil {
                            trackTotals.append((candidate.identity, value, true))
                        }
                    }
                }
            }
            for description in discAliasDescriptions {
                guard let candidate = freeform(description) else { continue }
                aliasIdentities.append(candidate.identity)
                let isTotal = description == "DISCTOTAL" || description == "TOTALDISCS"
                for value in candidate.values {
                    if isTotal {
                        discTotals.append((candidate.identity, value, false))
                    } else {
                        discCandidates.append((candidate.identity, value, false))
                        if parseStrictPair(value)?.total != nil {
                            discTotals.append((candidate.identity, value, true))
                        }
                    }
                }
            }
        } else {
            let trackKeys = ["TRACKNUMBER", "TRACK"]
            let trackTotalKeys = ["TRACKTOTAL", "TOTALTRACKS"]
            let discKeys = ["DISCNUMBER", "DISC"]
            let discTotalKeys = ["DISCTOTAL", "TOTALDISCS"]
            for key in trackKeys {
                if let value = rawValue(key) {
                    aliasIdentities.append(key)
                    trackCandidates.append((key, value, false))
                    if parseStrictPair(value)?.total != nil {
                        trackTotals.append((key, value, true))
                    }
                }
            }
            for key in trackTotalKeys {
                if let value = rawValue(key) {
                    aliasIdentities.append(key)
                    trackTotals.append((key, value, false))
                }
            }
            for key in discKeys {
                if let value = rawValue(key) {
                    aliasIdentities.append(key)
                    discCandidates.append((key, value, false))
                    if parseStrictPair(value)?.total != nil {
                        discTotals.append((key, value, true))
                    }
                }
            }
            for key in discTotalKeys {
                if let value = rawValue(key) {
                    aliasIdentities.append(key)
                    discTotals.append((key, value, false))
                }
            }
            if isID3 {
                for description in trackAliasDescriptions where description.contains("TOTAL") {
                    for value in userText(description) {
                        aliasIdentities.append("TXXX:\(description)")
                        trackTotals.append(("TXXX:\(description)", value, false))
                    }
                }
                for description in discAliasDescriptions where description.contains("TOTAL") {
                    for value in userText(description) {
                        aliasIdentities.append("TXXX:\(description)")
                        discTotals.append(("TXXX:\(description)", value, false))
                    }
                }
            }
        }

        let nativeTrack = isMP4 ? nativePair("trkn").0 : parseStrictPair(frameValues("TRCK").first ?? rawValue("TRCK") ?? "")?.number
        let nativeTrackTotal = isMP4 ? nativePair("trkn").1 : parseStrictPair(frameValues("TRCK").first ?? rawValue("TRCK") ?? "")?.total
        let nativeDisc = isMP4 ? nativePair("disk").0 : parseStrictPair(frameValues("TPOS").first ?? rawValue("TPOS") ?? "")?.number
        let nativeDiscTotal = isMP4 ? nativePair("disk").1 : parseStrictPair(frameValues("TPOS").first ?? rawValue("TPOS") ?? "")?.total

        var trackPrivate: [MetadataNumberPrivateTextInventory] = []
        var discPrivate: [MetadataNumberPrivateTextInventory] = []
        if isMP4 {
            for description in privateDescriptions {
                guard let candidate = freeform(description) else { continue }
                let isTrack = description.contains("TRACKNUMBER")
                var parsedNumber: Int?
                var parsedTotal: Int?
                var strict = false
                if let first = candidate.values.first, let pair = parseStrictPair(first),
                   candidate.values.count == 1 {
                    parsedNumber = pair.number
                    parsedTotal = pair.total
                    strict = true
                }
                let inventory = MetadataNumberPrivateTextInventory(
                    identity: candidate.identity,
                    description: description,
                    namespace: "com.apple.iTunes",
                    values: candidate.values,
                    parsedNumber: parsedNumber,
                    parsedTotal: parsedTotal,
                    isStrictlyNumeric: strict
                )
                if isTrack { trackPrivate.append(inventory) } else { discPrivate.append(inventory) }
                if !strict {
                    warnings.append("Private numbering text \(description) is not strictly numeric and cannot be recovered.")
                }
            }
        }

        let track = MetadataNumberGroupInventory(
            number: numberComponent(native: nativeTrack, candidates: trackCandidates),
            total: totalComponent(native: nativeTrackTotal, candidates: trackTotals),
            nativeIdentities: isMP4 ? ["trkn"] : ["TRCK"],
            legacyAliasIdentities: aliasIdentities,
            privateTexts: trackPrivate,
            warnings: []
        )
        let disc = MetadataNumberGroupInventory(
            number: numberComponent(native: nativeDisc, candidates: discCandidates),
            total: totalComponent(native: nativeDiscTotal, candidates: discTotals),
            nativeIdentities: isMP4 ? ["disk"] : ["TPOS"],
            legacyAliasIdentities: aliasIdentities,
            privateTexts: discPrivate,
            warnings: []
        )
        return MetadataNumberingInventory(track: track, disc: disc, fileVersion: version, warnings: warnings)
    }

    public nonisolated static func planNumberNormalization(
        at url: URL,
        policy: MetadataNumberResolutionPolicy,
        groups: Set<MetadataNumberGroup> = [.track, .disc]
    ) throws -> MetadataNumberNormalizationPlan {
        let inventory = try numberingInventory(at: url)
        guard let version = inventory.fileVersion else {
            throw TagLibManagerError.operationFailed("Numbering plans require a captured file version.")
        }
        var track: (Int?, Int?) = (inventory.track.number.resolvedValue, inventory.track.total.resolvedValue)
        var disc: (Int?, Int?) = (inventory.disc.number.resolvedValue, inventory.disc.total.resolvedValue)
        switch policy {
        case .useNative:
            track = (inventory.track.number.nativeValue, inventory.track.total.nativeValue)
            disc = (inventory.disc.number.nativeValue, inventory.disc.total.nativeValue)
        case .useLegacy:
            if inventory.track.number.isUnresolved || inventory.track.total.isUnresolved ||
                inventory.disc.number.isUnresolved || inventory.disc.total.isUnresolved {
                throw MetadataPatchValidationError.ambiguousNumberRecovery(
                    field: "track/disc",
                    identities: inventory.track.number.identities
                        + inventory.track.total.identities
                        + inventory.disc.number.identities
                        + inventory.disc.total.identities
                )
            }
        case .replace(let number, let total):
            track = (number, total)
            disc = (inventory.disc.number.resolvedValue, inventory.disc.total.resolvedValue)
        }
        var removals = Set<String>()
        var privateRemovals = Set<String>()
        for group in groups {
            let value = group == .track ? inventory.track : inventory.disc
            if value.total.state == .recoveredLegacy || value.total.state == .ambiguous {
                removals.formUnion(value.legacyAliasIdentities)
            }
            for privateText in value.privateTexts
            where privateText.isStrictlyNumeric && privateText.parsedNumber == value.number.resolvedValue
                && privateText.parsedTotal == value.total.resolvedValue {
                privateRemovals.insert(privateText.identity)
            }
        }
        return MetadataNumberNormalizationPlan(
            groups: groups,
            fileVersion: version,
            trackNumber: track.0,
            trackTotal: track.1,
            discNumber: disc.0,
            discTotal: disc.1,
            removals: removals.sorted(),
            privateRemovals: privateRemovals.sorted(),
            warnings: inventory.warnings,
            inventory: inventory
        )
    }

    @discardableResult
    public nonisolated static func applyNumberNormalization(
        _ plan: MetadataNumberNormalizationPlan,
        to url: URL,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        let expected = expectedVersion ?? plan.fileVersion
        return try withAtomicMetadataWriteMutation(at: url, expectedVersion: expected) { mutationURL in
            let trackNumber = plan.trackNumber ?? 0
            let trackTotal = plan.trackTotal ?? 0
            let discNumber = plan.discNumber ?? 0
            let discTotal = plan.discTotal ?? 0
            try validateNativeNumberPair(number: trackNumber, total: trackTotal, field: .track, for: mutationURL)
            try validateNativeNumberPair(number: discNumber, total: discTotal, field: .disc, for: mutationURL)
            try TagLibMetadataExtractor.writeNumberPairsInPlace(
                trackNumber: trackNumber,
                totalTracks: trackTotal,
                updateTrackPair: plan.groups.contains(.track),
                discNumber: discNumber,
                totalDiscs: discTotal,
                updateDiscPair: plan.groups.contains(.disc),
                to: mutationURL
            )
            if !plan.removals.isEmpty || !plan.privateRemovals.isEmpty {
                let snapshot = try readSnapshot(from: mutationURL)
                var mp4Atoms: [StructuredMP4Atom] = []
                var id3Frames: [StructuredID3v2Frame] = []
                var nativeRemovals: [String] = []
                for identity in plan.removals + plan.privateRemovals {
                    if identity.hasPrefix("----:") {
                        mp4Atoms.append(.init(key: identity, type: "stringList", values: [], remove: true))
                    } else if identity.hasPrefix("TXXX:") {
                        id3Frames.append(.init(
                            frameID: "TXXX",
                            type: "userText",
                            description: String(identity.dropFirst(5))
                        ))
                    } else if snapshot.raw.properties.contains(where: { $0.key.caseInsensitiveCompare(identity) == .orderedSame }) {
                        nativeRemovals.append(identity)
                    }
                }
                if !mp4Atoms.isEmpty || !id3Frames.isEmpty {
                    try TagLibMetadataExtractor.writeStructuredMetadataInPlace(
                        bridgePayload(
                            from: StructuredMetadata(id3v2Frames: id3Frames, mp4Atoms: mp4Atoms),
                            includeProperties: false,
                            replacingCollections: [],
                            riffPolicy: .preserveInfo
                        ),
                        to: mutationURL
                    )
                }
                if !nativeRemovals.isEmpty {
                    try TagLibMetadataExtractor.applyNativeTextKeyValuesInPlace(
                        [:],
                        removingKeys: nativeRemovals,
                        to: mutationURL
                    )
                }
            }

            let after = try readSnapshot(from: mutationURL)
            var warnings = plan.warnings
            if let expectedTrack = plan.trackNumber, after.basic.track != expectedTrack {
                warnings.append("Track number did not persist (expected \(expectedTrack), got \(after.basic.track)).")
            }
            if let expectedTotal = plan.trackTotal, after.basic.trackTotal != expectedTotal {
                warnings.append("Total tracks did not persist (expected \(expectedTotal), got \(after.basic.trackTotal)).")
            }
            if let expectedDisc = plan.discNumber, after.basic.disc != expectedDisc {
                warnings.append("Disc number did not persist (expected \(expectedDisc), got \(after.basic.disc)).")
            }
            if let expectedTotal = plan.discTotal, after.basic.discTotal != expectedTotal {
                warnings.append("Total discs did not persist (expected \(expectedTotal), got \(after.basic.discTotal)).")
            }
            for identity in plan.removals + plan.privateRemovals {
                if after.structured.mp4Atoms.contains(where: { $0.key == identity }) {
                    warnings.append("Selected numbering alias \(identity) remains after cleanup.")
                }
            }
            try throwOnVerificationFailures(warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }
}
