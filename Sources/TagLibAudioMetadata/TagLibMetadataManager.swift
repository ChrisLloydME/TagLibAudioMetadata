//
//  TagLibMetadataManager.swift
//  AudioMator
//

import Foundation
@_exported import CTagLibBridge

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum MetadataValueSource: String, Hashable, Sendable {
    case nativeTag
    case propertyMap
    case id3v2Frame
    case rawFallback
    case derivedNumeric
    case none
}

public struct MetadataFieldProvenance: Hashable, Sendable {
    public var trackNumberText: MetadataValueSource
    public var discNumberText: MetadataValueSource
    public var explicitContent: MetadataValueSource
    public var artwork: MetadataValueSource

    public init(
        trackNumberText: MetadataValueSource,
        discNumberText: MetadataValueSource,
        explicitContent: MetadataValueSource,
        artwork: MetadataValueSource
    ) {
        self.trackNumberText = trackNumberText
        self.discNumberText = discNumberText
        self.explicitContent = explicitContent
        self.artwork = artwork
    }

    public nonisolated static let unknown = MetadataFieldProvenance(
        trackNumberText: .none,
        discNumberText: .none,
        explicitContent: .none,
        artwork: .none
    )
}

/// Mirrors the metadata fields used in `AudioFile.swift`.
public struct BasicMetadata: Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var composer: String
    public var genre: String
    public var comment: String
    public var lyrics: String
    public var track: Int
    public var trackTotal: Int
    public var disc: Int
    public var discTotal: Int
    public var trackNumberText: String
    public var discNumberText: String
    public var year: String
    public var albumArtist: String
    public var releaseDate: String
    public var originalReleaseDate: String
    public var isrc: String
    public var barcode: String
    public var musicBrainzArtistID: String
    public var musicBrainzAlbumID: String
    public var musicBrainzAlbumArtistID: String
    public var musicBrainzTrackID: String
    public var musicBrainzReleaseGroupID: String
    public var musicBrainzReleaseTrackID: String
    public var musicBrainzWorkID: String
    public var acoustID: String
    public var acoustIDFingerprint: String
    public var musicIPPUID: String
    public var publisher: String
    public var copyright: String
    public var encodedBy: String
    public var encoderSettings: String
    public var sortTitle: String
    public var sortArtist: String
    public var sortAlbum: String
    public var sortAlbumArtist: String
    public var sortComposer: String
    public var conductor: String
    public var remixer: String
    public var producer: String
    public var engineer: String
    public var lyricist: String
    public var subtitle: String
    public var grouping: String
    public var movement: String
    public var mood: String
    public var language: String
    public var musicalKey: String
    public var replayGainTrack: String
    public var replayGainAlbum: String
    public var mediaType: String
    public var itunesAlbumID: String
    public var itunesArtistID: String
    public var itunesCatalogID: String
    public var itunesGenreID: String
    public var itunesMediaType: String
    public var itunesPurchaseDate: String
    public var itunesNorm: String
    public var itunesSMPB: String
    public var releaseType: String
    public var releaseStatus: String
    public var catalogNumber: String
    public var releaseCountry: String
    public var artistType: String
    public var asin: String
    public var originalAlbum: String
    public var originalArtist: String
    public var discSubtitle: String
    public var work: String
    public var movementNumber: Int
    public var movementCount: Int
    public var bpm: Int
    public var isCompilation: Bool
    public var isExplicit: Bool
    public var duration: Double
    public var bitrate: Int
    public var sampleRate: Double
    public var channels: Int
    public var bitDepth: Int
    public var format: String
    public var artworkData: Data?
    public var customFields: [String: String]
    public var provenance: MetadataFieldProvenance

    public nonisolated static let empty = BasicMetadata(
        title: "",
        artist: "",
        album: "",
        composer: "",
        genre: "",
        comment: "",
        lyrics: "",
        track: 0,
        trackTotal: 0,
        disc: 0,
        discTotal: 0,
        trackNumberText: "",
        discNumberText: "",
        year: "",
        albumArtist: "",
        releaseDate: "",
        originalReleaseDate: "",
        isrc: "",
        barcode: "",
        musicBrainzArtistID: "",
        musicBrainzAlbumID: "",
        musicBrainzAlbumArtistID: "",
        musicBrainzTrackID: "",
        musicBrainzReleaseGroupID: "",
        musicBrainzReleaseTrackID: "",
        musicBrainzWorkID: "",
        acoustID: "",
        acoustIDFingerprint: "",
        musicIPPUID: "",
        publisher: "",
        copyright: "",
        encodedBy: "",
        encoderSettings: "",
        sortTitle: "",
        sortArtist: "",
        sortAlbum: "",
        sortAlbumArtist: "",
        sortComposer: "",
        conductor: "",
        remixer: "",
        producer: "",
        engineer: "",
        lyricist: "",
        subtitle: "",
        grouping: "",
        movement: "",
        mood: "",
        language: "",
        musicalKey: "",
        replayGainTrack: "",
        replayGainAlbum: "",
        mediaType: "",
        itunesAlbumID: "",
        itunesArtistID: "",
        itunesCatalogID: "",
        itunesGenreID: "",
        itunesMediaType: "",
        itunesPurchaseDate: "",
        itunesNorm: "",
        itunesSMPB: "",
        releaseType: "",
        releaseStatus: "",
        catalogNumber: "",
        releaseCountry: "",
        artistType: "",
        asin: "",
        originalAlbum: "",
        originalArtist: "",
        discSubtitle: "",
        work: "",
        movementNumber: 0,
        movementCount: 0,
        bpm: 0,
        isCompilation: false,
        isExplicit: false,
        duration: 0,
        bitrate: 0,
        sampleRate: 0,
        channels: 0,
        bitDepth: 0,
        format: "",
        artworkData: nil,
        customFields: [:],
        provenance: .unknown
    )
}

nonisolated private func preferredRawNumberText(_ currentValue: String, _ candidateValue: String) -> String {
    func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func score(_ value: String) -> Int {
        let trimmed = normalized(value)
        guard !trimmed.isEmpty else { return .min }

        let leftPart = trimmed.split(separator: "/", maxSplits: 1).first.map(String.init) ?? trimmed
        let hasLeadingZeros = leftPart.count > 1 && leftPart.hasPrefix("0")
        let hasExplicitTotal = trimmed.contains("/")
        return (hasLeadingZeros ? 1000 : 0) + (hasExplicitTotal ? 100 : 0) + trimmed.count
    }

    let trimmedCurrent = normalized(currentValue)
    let trimmedCandidate = normalized(candidateValue)

    guard !trimmedCandidate.isEmpty else { return trimmedCurrent }
    guard !trimmedCurrent.isEmpty else { return trimmedCandidate }
    return score(trimmedCandidate) > score(trimmedCurrent) ? trimmedCandidate : trimmedCurrent
}

nonisolated private func rawNumberTexts(from dump: RawMetadataDump) -> (track: String, disc: String) {
    let trackFromProperties = dump.properties
        .filter { ["TRACKNUMBER", "TRACK"].contains($0.key.uppercased()) }
        .reduce(into: "") { bestValue, entry in
            for value in entry.values {
                bestValue = preferredRawNumberText(bestValue, value)
            }
            bestValue = preferredRawNumberText(bestValue, entry.value)
        }

    let discFromProperties = dump.properties
        .filter { ["DISCNUMBER", "DISC"].contains($0.key.uppercased()) }
        .reduce(into: "") { bestValue, entry in
            for value in entry.values {
                bestValue = preferredRawNumberText(bestValue, value)
            }
            bestValue = preferredRawNumberText(bestValue, entry.value)
        }

    let trackFromFrames = dump.id3v2Frames
        .filter { $0.frameID.uppercased() == "TRCK" }
        .reduce(into: "") { bestValue, entry in
            bestValue = preferredRawNumberText(bestValue, entry.value)
        }

    let discFromFrames = dump.id3v2Frames
        .filter { $0.frameID.uppercased() == "TPOS" }
        .reduce(into: "") { bestValue, entry in
            bestValue = preferredRawNumberText(bestValue, entry.value)
        }

    return (
        track: preferredRawNumberText(trackFromProperties, trackFromFrames),
        disc: preferredRawNumberText(discFromProperties, discFromFrames)
    )
}

// MARK: - Raw Metadata Dump Models (for GUI display)

public struct RawMetadataDump: Hashable, Sendable {
    public var properties: [RawPropertyEntry]
    public var id3v2Frames: [RawID3v2FrameEntry]

    public init(properties: [RawPropertyEntry], id3v2Frames: [RawID3v2FrameEntry]) {
        self.properties = properties
        self.id3v2Frames = id3v2Frames
    }

    public nonisolated static let empty = RawMetadataDump(properties: [], id3v2Frames: [])
}

public struct RawPropertyEntry: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var key: String
    public var value: String
    public var values: [String]
    public var count: Int

    public init(key: String, value: String, values: [String], count: Int) {
        self.key = key
        self.value = value
        self.values = values
        self.count = count
    }

    public var schema: MetadataFieldSchema? {
        MetadataFieldRegistry.schema(forPropertyMapKey: key)
    }

    public var shouldDisplayAsMultiValue: Bool {
        MetadataFieldRegistry.shouldDisplayRawPropertyAsMultiValue(key)
    }
}

public struct RawID3v2FrameEntry: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var frameID: String
    public var value: String
    public var description: String?
    public var language: String?

    public init(frameID: String, value: String, description: String?, language: String?) {
        self.frameID = frameID
        self.value = value
        self.description = description
        self.language = language
    }
}

// MARK: - Structured Metadata Models

public enum RIFFMetadataWritePolicy: String, Hashable, Sendable {
    case id3v2Only
    case preserveInfo
    case syncBasicFieldsToInfo
}

public struct StructuredPropertyEntry: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var key: String
    public var values: [String]

    public init(key: String, values: [String]) {
        self.key = key
        self.values = values
    }
}

public struct StructuredID3v2Frame: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var frameID: String
    public var type: String
    public var value: String
    public var values: [String]
    public var description: String?
    public var language: String?
    public var url: String?
    public var owner: String?
    public var data: Data?
    public var fields: [String: String]

    public init(
        frameID: String,
        type: String,
        value: String = "",
        values: [String] = [],
        description: String? = nil,
        language: String? = nil,
        url: String? = nil,
        owner: String? = nil,
        data: Data? = nil,
        fields: [String: String] = [:]
    ) {
        self.frameID = frameID
        self.type = type
        self.value = value
        self.values = values
        self.description = description
        self.language = language
        self.url = url
        self.owner = owner
        self.data = data
        self.fields = fields
    }
}

public struct StructuredMP4Atom: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var key: String
    public var type: String
    public var value: String
    public var values: [String]
    public var first: Int?
    public var second: Int?
    public var freeformDescription: String?

    public init(key: String, type: String, value: String = "", values: [String] = [], first: Int? = nil, second: Int? = nil, freeformDescription: String? = nil) {
        self.key = key
        self.type = type
        self.value = value
        self.values = values
        self.first = first
        self.second = second
        self.freeformDescription = freeformDescription
    }
}

public struct StructuredASFAttribute: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var key: String
    public var type: String
    public var value: String
    public var data: Data?
    public var pictureType: String?
    public var mimeType: String?
    public var description: String?
    public var language: Int
    public var stream: Int

    public init(key: String, type: String, value: String = "", data: Data? = nil, pictureType: String? = nil, mimeType: String? = nil, description: String? = nil, language: Int = 0, stream: Int = 0) {
        self.key = key
        self.type = type
        self.value = value
        self.data = data
        self.pictureType = pictureType
        self.mimeType = mimeType
        self.description = description
        self.language = language
        self.stream = stream
    }
}

public struct StructuredArtwork: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var container: String
    public var pictureType: String?
    public var pictureTypeCode: Int?
    public var mimeType: String
    public var description: String?
    public var data: Data

    public init(container: String = "", pictureType: String? = nil, pictureTypeCode: Int? = nil, mimeType: String, description: String? = nil, data: Data) {
        self.container = container
        self.pictureType = pictureType
        self.pictureTypeCode = pictureTypeCode
        self.mimeType = mimeType
        self.description = description
        self.data = data
    }
}

public struct StructuredLyrics: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var language: String
    public var description: String
    public var text: String

    public init(language: String = "eng", description: String = "", text: String) {
        self.language = language
        self.description = description
        self.text = text
    }
}

public struct StructuredComment: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var language: String
    public var description: String
    public var text: String

    public init(language: String = "eng", description: String = "", text: String) {
        self.language = language
        self.description = description
        self.text = text
    }
}

public struct StructuredMetadata: Hashable, Sendable {
    public var properties: [StructuredPropertyEntry]
    public var id3v2Frames: [StructuredID3v2Frame]
    public var mp4Atoms: [StructuredMP4Atom]
    public var asfAttributes: [StructuredASFAttribute]
    public var artwork: [StructuredArtwork]
    public var lyrics: [StructuredLyrics]
    public var comments: [StructuredComment]
    public var warnings: [String]

    public init(
        properties: [StructuredPropertyEntry] = [],
        id3v2Frames: [StructuredID3v2Frame] = [],
        mp4Atoms: [StructuredMP4Atom] = [],
        asfAttributes: [StructuredASFAttribute] = [],
        artwork: [StructuredArtwork] = [],
        lyrics: [StructuredLyrics] = [],
        comments: [StructuredComment] = [],
        warnings: [String] = []
    ) {
        self.properties = properties
        self.id3v2Frames = id3v2Frames
        self.mp4Atoms = mp4Atoms
        self.asfAttributes = asfAttributes
        self.artwork = artwork
        self.lyrics = lyrics
        self.comments = comments
        self.warnings = warnings
    }
}

public enum TagLibManagerError: Error, Sendable {
    case unsupportedFormat
    @available(*, deprecated, message: "Use failedToReadWithUnderlying(_:) for throwing read failures.")
    case failedToRead
    case failedToReadWithUnderlying(String)
    case verificationFailed([String])
}

/// Thin wrapper around the Objective-C++ `TagLibMetadataExtractor`.
public struct TagLibMetadataManager {

    nonisolated private static let hiddenInternalRawFieldKeys: Set<String> = [
        "AUDIOMATOR_TRACKNUMBER_TEXT",
        "AUDIOMATOR_DISCNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:AUDIOMATOR_TRACKNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:AUDIOMATOR_DISCNUMBER_TEXT",
    ]

    public enum ArtworkVerificationExpectation: Sendable {
        case unchanged
        case present
        case absent
    }

    public struct MetadataWriteVerificationContext: Equatable, Sendable {
        public var expectedTrackNumber: Int?
        public var expectedTrackTotal: Int?
        public var expectedTrackNumberText: String?
        public var expectedDiscNumber: Int?
        public var expectedDiscTotal: Int?
        public var expectedDiscNumberText: String?
        public var expectedExplicitContent: Bool?
        public var artworkExpectation: ArtworkVerificationExpectation
        public var customFieldKeys: [String]

        public init(
            expectedTrackNumber: Int?,
            expectedTrackTotal: Int?,
            expectedTrackNumberText: String?,
            expectedDiscNumber: Int?,
            expectedDiscTotal: Int?,
            expectedDiscNumberText: String?,
            expectedExplicitContent: Bool?,
            artworkExpectation: ArtworkVerificationExpectation,
            customFieldKeys: [String]
        ) {
            self.expectedTrackNumber = expectedTrackNumber
            self.expectedTrackTotal = expectedTrackTotal
            self.expectedTrackNumberText = expectedTrackNumberText
            self.expectedDiscNumber = expectedDiscNumber
            self.expectedDiscTotal = expectedDiscTotal
            self.expectedDiscNumberText = expectedDiscNumberText
            self.expectedExplicitContent = expectedExplicitContent
            self.artworkExpectation = artworkExpectation
            self.customFieldKeys = customFieldKeys
        }

        public nonisolated static let none = MetadataWriteVerificationContext(
            expectedTrackNumber: nil,
            expectedTrackTotal: nil,
            expectedTrackNumberText: nil,
            expectedDiscNumber: nil,
            expectedDiscTotal: nil,
            expectedDiscNumberText: nil,
            expectedExplicitContent: nil,
            artworkExpectation: .unchanged,
            customFieldKeys: []
        )
    }

    public struct MetadataWriteResult: Sendable {
        public var warnings: [String]

        public init(warnings: [String]) {
            self.warnings = warnings
        }
    }

    public enum RawPropertyMapWriteMode: Sendable {
        /// Replace the file's TagLib PropertyMap with exactly the provided key/value pairs.
        case replace

        /// Merge the provided key/value pairs into the current TagLib PropertyMap.
        ///
        /// Empty values remove matching keys, mirroring the bridge's existing trimming behavior.
        case merge
    }

    public enum VerificationFailurePolicy: Sendable {
        case warn
        case `throw`
    }

    public nonisolated static func isReadableFormat(_ fileExtension: String) -> Bool {
        TagLibMetadataExtractor.isSupportedFormat(fileExtension)
    }

    public nonisolated static func isWritableFormat(_ fileExtension: String) -> Bool {
        TagLibMetadataExtractor.isWritableFormat(fileExtension)
    }

    public nonisolated static var readableExtensions: [String] {
        TagLibMetadataExtractor.supportedExtensions()
    }

    public nonisolated static var writableExtensions: [String] {
        TagLibMetadataExtractor.writableExtensions()
    }

    nonisolated private static func isHiddenInternalRawFieldKey(_ key: String) -> Bool {
        hiddenInternalRawFieldKeys.contains(
            key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        )
    }

    nonisolated private static func normalizedTrimmed(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func parseNumberPair(_ value: String) -> (number: Int, total: Int) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (0, 0) }

        let parts = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let number = parts.first.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
        let total = parts.count > 1
            ? Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            : 0
        return (max(0, number), max(0, total))
    }

    nonisolated private static func numberPairEquivalent(_ lhs: String?, _ rhs: String?) -> Bool {
        parseNumberPair(normalizedTrimmed(lhs)) == parseNumberPair(normalizedTrimmed(rhs))
    }

    nonisolated private static func rawPropertiesLookup(_ dump: RawMetadataDump) -> [String: [String]] {
        dump.properties.reduce(into: [:]) { result, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !key.isEmpty else { return }

            let mergedValues = (entry.values + [entry.value])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !mergedValues.isEmpty else { return }

            var existing = result[key] ?? []
            existing.append(contentsOf: mergedValues)
            result[key] = Array(Set(existing))
        }
    }

    nonisolated private static func rawContainsCustomKey(_ key: String, dump: RawMetadataDump) -> Bool {
        let expected = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !expected.isEmpty else { return true }

        let acceptedKeys = normalizedRawKeyAliases(for: expected)
        for property in dump.properties {
            let candidate = property.key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if acceptedKeys.contains(candidate) {
                return true
            }
        }

        return false
    }

    nonisolated private static func normalizedRawKeyAliases(for key: String) -> Set<String> {
        var aliases: Set<String> = [key]

        let mp4FreeformPrefix = "----:COM.APPLE.ITUNES:"
        if key.hasPrefix(mp4FreeformPrefix) {
            aliases.insert(String(key.dropFirst(mp4FreeformPrefix.count)))
        } else {
            aliases.insert("\(mp4FreeformPrefix)\(key)")
        }

        return aliases
    }

    nonisolated private static func applyVerificationFailurePolicy(
        _ policy: VerificationFailurePolicy,
        warnings: [String]
    ) throws {
        guard policy == .throw, !warnings.isEmpty else { return }
        throw TagLibManagerError.verificationFailed(warnings)
    }

    nonisolated private static func explicitValueSource(from dump: RawMetadataDump, fallback: Bool) -> MetadataValueSource {
        let explicitKeys = Set(["ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT", "RTNG"])
        if dump.properties.contains(where: { entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return explicitKeys.contains(key) || key.hasSuffix(":ITUNESADVISORY")
        }) {
            return .propertyMap
        }

        if dump.id3v2Frames.contains(where: { frame in
            if frame.frameID.uppercased() == "TXXX" {
                let description = frame.description?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
                return description == "ITUNESADVISORY" || description == "EXPLICIT"
            }
            return false
        }) {
            return .id3v2Frame
        }

        return fallback ? .nativeTag : .none
    }

    nonisolated private static func hasVerificationExpectations(_ verification: MetadataWriteVerificationContext) -> Bool {
        if verification.expectedTrackNumber != nil || verification.expectedTrackTotal != nil {
            return true
        }

        if let expectedTrack = verification.expectedTrackNumberText,
           !normalizedTrimmed(expectedTrack).isEmpty {
            return true
        }

        if verification.expectedDiscNumber != nil || verification.expectedDiscTotal != nil {
            return true
        }

        if let expectedDisc = verification.expectedDiscNumberText,
           !normalizedTrimmed(expectedDisc).isEmpty {
            return true
        }

        if verification.expectedExplicitContent != nil {
            return true
        }

        switch verification.artworkExpectation {
        case .unchanged:
            break
        case .present, .absent:
            return true
        }

        return !verification.customFieldKeys.isEmpty
    }

    nonisolated private static func metadataWriteWarnings(
        for url: URL,
        verification: MetadataWriteVerificationContext
    ) -> [String] {
        guard hasVerificationExpectations(verification) else { return [] }

        var warnings: [String] = []
        let afterWrite = readMetadata(from: url)
        let rawDump = rawMetadata(from: url)

        if let afterWrite {
            if let expectedTrackNumber = verification.expectedTrackNumber,
               afterWrite.track != expectedTrackNumber {
                warnings.append(
                    "Track number differs after save (expected \(expectedTrackNumber), got \(afterWrite.track))."
                )
            }

            if let expectedTrackTotal = verification.expectedTrackTotal,
               afterWrite.trackTotal != expectedTrackTotal {
                warnings.append(
                    "Total tracks differs after save (expected \(expectedTrackTotal), got \(afterWrite.trackTotal))."
                )
            }
        }

        if let expectedTrack = verification.expectedTrackNumberText,
           !normalizedTrimmed(expectedTrack).isEmpty,
           let afterWrite {
            if !numberPairEquivalent(expectedTrack, afterWrite.trackNumberText) {
                warnings.append(
                    "Track number text differs after save (expected \(expectedTrack), got \(afterWrite.trackNumberText))."
                )
            } else if normalizedTrimmed(expectedTrack) != normalizedTrimmed(afterWrite.trackNumberText) {
                warnings.append(
                    "Track number formatting was normalized by the container (\(expectedTrack) -> \(afterWrite.trackNumberText))."
                )
            }
        }

        if let afterWrite {
            if let expectedDiscNumber = verification.expectedDiscNumber,
               afterWrite.disc != expectedDiscNumber {
                warnings.append(
                    "Disc number differs after save (expected \(expectedDiscNumber), got \(afterWrite.disc))."
                )
            }

            if let expectedDiscTotal = verification.expectedDiscTotal,
               afterWrite.discTotal != expectedDiscTotal {
                warnings.append(
                    "Total discs differs after save (expected \(expectedDiscTotal), got \(afterWrite.discTotal))."
                )
            }
        }

        if let expectedDisc = verification.expectedDiscNumberText,
           !normalizedTrimmed(expectedDisc).isEmpty,
           let afterWrite {
            if !numberPairEquivalent(expectedDisc, afterWrite.discNumberText) {
                warnings.append(
                    "Disc number text differs after save (expected \(expectedDisc), got \(afterWrite.discNumberText))."
                )
            } else if normalizedTrimmed(expectedDisc) != normalizedTrimmed(afterWrite.discNumberText) {
                warnings.append(
                    "Disc number formatting was normalized by the container (\(expectedDisc) -> \(afterWrite.discNumberText))."
                )
            }
        }

        if let expectedExplicit = verification.expectedExplicitContent, let afterWrite {
            if expectedExplicit != afterWrite.isExplicit {
                warnings.append(
                    "Explicit flag differs after save (expected \(expectedExplicit ? "explicit" : "clean"), got \(afterWrite.isExplicit ? "explicit" : "clean"))."
                )
            }
        }

        if let afterWrite {
            switch verification.artworkExpectation {
            case .unchanged:
                break
            case .present:
                if afterWrite.artworkData == nil {
                    warnings.append("Artwork was expected to be present after save but no embedded artwork was found.")
                }
            case .absent:
                if afterWrite.artworkData != nil {
                    warnings.append("Artwork was expected to be removed but embedded artwork is still present.")
                }
            }
        }

        if !verification.customFieldKeys.isEmpty {
            guard let rawDump else {
                warnings.append("Could not verify custom field preservation after save.")
                return warnings
            }

            for key in verification.customFieldKeys where !rawContainsCustomKey(key, dump: rawDump) {
                warnings.append("Custom field \"\(key)\" could not be confirmed after save.")
            }
        }

        return warnings
    }

    nonisolated private static func rawPropertyMapWriteWarnings(
        requestedProperties: [String: String],
        for url: URL
    ) -> [String] {
        guard !requestedProperties.isEmpty else { return [] }
        guard let rawDump = rawMetadata(from: url) else {
            return ["Could not verify raw metadata write after save."]
        }

        var warnings: [String] = []
        let lookup = rawPropertiesLookup(rawDump)
        let riskyNumberKeys = Set([
            "TRACKNUMBER", "TRACK", "TRACKTOTAL", "TOTALTRACKS",
            "DISCNUMBER", "DISC", "DISCTOTAL", "TOTALDISCS"
        ])
        let riskyExplicitKeys = Set(["ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT"])

        for (rawKey, rawValue) in requestedProperties {
            let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }

            if value.isEmpty {
                if lookup.keys.contains(where: { normalizedRawKeyAliases(for: key).contains($0) }) {
                    warnings.append("Raw key \"\(rawKey)\" was expected to be removed after save.")
                }
                continue
            }

            let aliasKeys = normalizedRawKeyAliases(for: key)
            let persistedValues = aliasKeys
                .compactMap { lookup[$0] }
                .flatMap { $0 }

            guard !persistedValues.isEmpty else {
                warnings.append("Raw key \"\(rawKey)\" was not found after save.")
                continue
            }

            if riskyNumberKeys.contains(key) {
                let expectedPair = parseNumberPair(value)
                let pairMatched = persistedValues.contains { parseNumberPair($0) == expectedPair }
                if !pairMatched {
                    warnings.append("Raw number key \"\(rawKey)\" differs after save.")
                }
                continue
            }

            if riskyExplicitKeys.contains(key) {
                let normalizedPersisted = persistedValues.map { $0.uppercased() }
                if !normalizedPersisted.contains(value.uppercased()) {
                    warnings.append("Raw explicit key \"\(rawKey)\" differs after save.")
                }
                continue
            }

            if !persistedValues.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                warnings.append("Raw key \"\(rawKey)\" value changed after save.")
            }
        }

        return warnings
    }

    nonisolated private static func resolvedRawPropertyMapForWrite(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode
    ) throws -> [String: String] {
        switch mode {
        case .replace:
            return properties

        case .merge:
            var merged = try rawMetadataResult(from: url).properties.reduce(into: [String: String]()) { result, entry in
                let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty, !value.isEmpty else { return }
                result[key] = value
            }

            for (rawKey, rawValue) in properties {
                let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { continue }

                let normalizedAliases = normalizedRawKeyAliases(for: key.uppercased())
                for existingKey in Array(merged.keys) where normalizedAliases.contains(existingKey.uppercased()) {
                    merged.removeValue(forKey: existingKey)
                }

                let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    merged[key] = value
                }
            }

            return merged
        }
    }

    nonisolated private static func parsedPropertyEntries(fromDumpText text: String) -> [RawPropertyEntry] {
        var isInPropertiesSection = false
        var properties: [RawPropertyEntry] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                if isInPropertiesSection {
                    break
                }

                isInPropertiesSection = (trimmedLine == "[TagLib Properties]")
                continue
            }

            guard isInPropertiesSection else { continue }
            guard !trimmedLine.isEmpty else { continue }

            if trimmedLine == "(none)" || trimmedLine.hasPrefix("(unable to open") {
                break
            }

            guard let separatorRange = trimmedLine.range(of: " = ") else { continue }

            let key = String(trimmedLine[..<separatorRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmedLine[separatorRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !isHiddenInternalRawFieldKey(key) else { continue }
            guard !key.isEmpty, !value.isEmpty else { continue }

            let values = value
                .components(separatedBy: "; ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            properties.append(
                RawPropertyEntry(
                    key: key,
                    value: value,
                    values: values,
                    count: values.count
                )
            )
        }

        return properties.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    nonisolated private static func stringValue(_ dict: [String: Any], _ key: String) -> String {
        if let value = dict[key] as? String { return value }
        if let value = dict[key] as? NSNumber { return value.stringValue }
        return ""
    }

    nonisolated private static func intValue(_ dict: [String: Any], _ key: String) -> Int? {
        if let value = dict[key] as? Int { return value }
        if let value = dict[key] as? NSNumber { return value.intValue }
        if let value = dict[key] as? String { return Int(value) }
        return nil
    }

    nonisolated private static func stringArrayValue(_ dict: [String: Any], _ key: String) -> [String] {
        (dict[key] as? [String]) ?? []
    }

    nonisolated private static func dictionaryArray(_ dict: [String: NSObject], _ key: String) -> [[String: Any]] {
        (dict[key] as? [[String: Any]]) ?? []
    }

    nonisolated private static func bridgePayload(from metadata: StructuredMetadata, includeProperties: Bool) -> [String: NSObject] {
        var payload: [String: NSObject] = [:]

        if includeProperties {
            payload["properties"] = metadata.properties.map { entry in
                ["key": entry.key, "values": entry.values] as NSDictionary
            } as NSArray
        }

        if !metadata.id3v2Frames.isEmpty {
            payload["id3v2Frames"] = metadata.id3v2Frames.map { frame in
                var dict: [String: Any] = [
                    "id": frame.frameID,
                    "type": frame.type,
                    "value": frame.value,
                    "values": frame.values
                ]
                dict["description"] = frame.description
                dict["language"] = frame.language
                dict["url"] = frame.url
                dict["owner"] = frame.owner
                dict["data"] = frame.data
                for (key, value) in frame.fields { dict[key] = value }
                return dict as NSDictionary
            } as NSArray
        }

        if !metadata.mp4Atoms.isEmpty {
            payload["mp4Atoms"] = metadata.mp4Atoms.map { atom in
                var dict: [String: Any] = [
                    "key": atom.key,
                    "type": atom.type,
                    "value": atom.value,
                    "values": atom.values
                ]
                dict["first"] = atom.first
                dict["second"] = atom.second
                dict["freeformDescription"] = atom.freeformDescription
                return dict as NSDictionary
            } as NSArray
        }

        if !metadata.asfAttributes.isEmpty {
            payload["asfAttributes"] = metadata.asfAttributes.map { attribute in
                var dict: [String: Any] = [
                    "key": attribute.key,
                    "type": attribute.type,
                    "value": attribute.value,
                    "language": attribute.language,
                    "stream": attribute.stream
                ]
                dict["data"] = attribute.data
                dict["pictureType"] = attribute.pictureType
                dict["mimeType"] = attribute.mimeType
                dict["description"] = attribute.description
                return dict as NSDictionary
            } as NSArray
        }

        if !metadata.artwork.isEmpty {
            payload["artwork"] = metadata.artwork.map { artwork in
                var dict: [String: Any] = [
                    "container": artwork.container,
                    "mimeType": artwork.mimeType,
                    "data": artwork.data
                ]
                dict["pictureType"] = artwork.pictureType
                dict["pictureTypeCode"] = artwork.pictureTypeCode
                dict["description"] = artwork.description
                return dict as NSDictionary
            } as NSArray
        }

        if !metadata.lyrics.isEmpty {
            payload["lyrics"] = metadata.lyrics.map {
                ["language": $0.language, "description": $0.description, "text": $0.text] as NSDictionary
            } as NSArray
        }

        if !metadata.comments.isEmpty {
            payload["comments"] = metadata.comments.map {
                ["language": $0.language, "description": $0.description, "text": $0.text] as NSDictionary
            } as NSArray
        }

        return payload
    }

    nonisolated private static func structuredWriteWarnings(expected: StructuredMetadata, for url: URL) -> [String] {
        guard let after = try? readStructuredMetadataResult(from: url) else {
            return ["Could not verify structured metadata after save."]
        }

        var warnings: [String] = []
        for frame in expected.id3v2Frames {
            if !after.id3v2Frames.contains(where: { $0.frameID == frame.frameID && $0.type == frame.type }) {
                warnings.append("ID3v2 frame \(frame.frameID) could not be confirmed after save.")
            }
        }
        if !expected.comments.isEmpty, after.comments.count < expected.comments.count {
            warnings.append("Not all structured comments could be confirmed after save.")
        }
        if !expected.lyrics.isEmpty, after.lyrics.count < expected.lyrics.count {
            warnings.append("Not all structured lyrics could be confirmed after save.")
        }
        if !expected.artwork.isEmpty, after.artwork.count < expected.artwork.count {
            warnings.append("Not all artwork entries could be confirmed after save.")
        }
        for atom in expected.mp4Atoms {
            if !after.mp4Atoms.contains(where: { $0.key == atom.key }) {
                warnings.append("MP4 atom \(atom.key) could not be confirmed after save.")
            }
        }
        for attribute in expected.asfAttributes {
            if !after.asfAttributes.contains(where: { $0.key == attribute.key }) {
                warnings.append("ASF attribute \(attribute.key) could not be confirmed after save.")
            }
        }
        return warnings + after.warnings
    }

    // MARK: - Bridge Dump API

    /// Return a single plain-text dump of metadata as TagLib sees it.
    ///
    /// Preferred path: call the ObjC++ bridge API directly (Swift `throws`).
    /// Fallback path: attempt older single-argument selector names via `perform` for compatibility.
    nonisolated private static func bridgeTextDumpIfAvailable(for url: URL) -> String? {
        // Newer bridge (preferred): `dumpMetadataText(from:)` is exposed as a Swift-throwing method.
        if let text = try? TagLibMetadataExtractor.dumpMetadataText(from: url) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }

        // Older bridge variants: try a small set of single-argument selector names at runtime.
        let candidates = [
            "rawMetadataTextFor:",
            "rawMetadataTextForURL:",
            "dumpMetadataTextFor:",
            "dumpMetadataTextFrom:",
            "dumpMetadataTextFromURL:",
            "dumpMetadataTextForURL:"
        ]

        for name in candidates {
            let sel = NSSelectorFromString(name)
            guard TagLibMetadataExtractor.responds(to: sel) else { continue }

            // perform(_:with:) only supports single-argument selectors.
            if let unmanaged = TagLibMetadataExtractor.perform(sel, with: url) {
                let any = unmanaged.takeUnretainedValue()
                if let s = any as? String {
                    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
                if let s = any as? NSString {
                    let trimmed = (s as String).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
        }

        return nil
    }

    public nonisolated static func readMetadataResult(from url: URL) throws -> BasicMetadata {
        // 1. Quickly filter by file extension.
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { throw TagLibManagerError.unsupportedFormat }

        if !TagLibMetadataExtractor.isSupportedFormat(ext) {
            throw TagLibManagerError.unsupportedFormat
        }

        do {
            // ObjC++ bridge API imported into Swift as `throws`.
            let meta = try TagLibMetadataExtractor.extractMetadata(from: url)
            let trackNumberText = meta.trackNumberText ?? ""
            let discNumberText = meta.discNumberText ?? ""
            let needsTrackTextFallback =
                trackNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                meta.trackNumber > 0
            let needsDiscTextFallback =
                discNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                meta.discNumber > 0

            var rawDump: RawMetadataDump?
            let rawNumberText: (track: String, disc: String)
            if needsTrackTextFallback || needsDiscTextFallback {
                rawDump = rawMetadata(from: url)
                rawNumberText = rawDump.map(rawNumberTexts(from:)) ?? (track: "", disc: "")
            } else {
                rawNumberText = (track: "", disc: "")
            }

            if case nil = rawDump {
                rawDump = rawMetadata(from: url)
            }

            var trackSource: MetadataValueSource =
                trackNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? (meta.trackNumber > 0 ? .derivedNumeric : .none)
                : .nativeTag

            var discSource: MetadataValueSource =
                discNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? (meta.discNumber > 0 ? .derivedNumeric : .none)
                : .nativeTag

            if needsTrackTextFallback,
               !rawNumberText.track.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                trackSource = .rawFallback
            }

            if needsDiscTextFallback,
               !rawNumberText.disc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                discSource = .rawFallback
            }

            let explicitSource = rawDump.map {
                explicitValueSource(from: $0, fallback: meta.explicitContent)
            } ?? (meta.explicitContent ? .nativeTag : .none)
            let artworkSource: MetadataValueSource = (meta.artworkData as Data?) == nil ? .none : .nativeTag

            return BasicMetadata(
                title: meta.title ?? "",
                artist: meta.artist ?? "",
                album: meta.album ?? "",
                composer: meta.composer ?? "",
                genre: meta.genre ?? "",
                comment: meta.comment ?? "",
                lyrics: meta.lyrics ?? "",
                track: Int(meta.trackNumber),
                trackTotal: Int(meta.totalTracks),
                disc: Int(meta.discNumber),
                discTotal: Int(meta.totalDiscs),
                trackNumberText: needsTrackTextFallback
                    ? preferredRawNumberText(trackNumberText, rawNumberText.track)
                    : trackNumberText,
                discNumberText: needsDiscTextFallback
                    ? preferredRawNumberText(discNumberText, rawNumberText.disc)
                    : discNumberText,
                year: meta.year ?? "",
                albumArtist: meta.albumArtist ?? "",
                releaseDate: meta.releaseDate ?? meta.originalReleaseDate ?? "",
                originalReleaseDate: meta.originalReleaseDate ?? "",
                isrc: meta.isrc ?? "",
                barcode: meta.barcode ?? "",
                musicBrainzArtistID: meta.musicBrainzArtistId ?? "",
                musicBrainzAlbumID: meta.musicBrainzAlbumId ?? "",
                musicBrainzAlbumArtistID: meta.musicBrainzAlbumArtistId ?? "",
                musicBrainzTrackID: meta.musicBrainzTrackId ?? "",
                musicBrainzReleaseGroupID: meta.musicBrainzReleaseGroupId ?? "",
                musicBrainzReleaseTrackID: meta.musicBrainzReleaseTrackId ?? "",
                musicBrainzWorkID: meta.musicBrainzWorkId ?? "",
                acoustID: meta.acoustId ?? "",
                acoustIDFingerprint: meta.acoustIdFingerprint ?? "",
                musicIPPUID: meta.musicIpPuid ?? "",
                publisher: meta.label ?? "",
                copyright: meta.copyright ?? "",
                encodedBy: meta.encodedBy ?? "",
                encoderSettings: meta.encoderSettings ?? "",
                sortTitle: meta.sortTitle ?? "",
                sortArtist: meta.sortArtist ?? "",
                sortAlbum: meta.sortAlbum ?? "",
                sortAlbumArtist: meta.sortAlbumArtist ?? "",
                sortComposer: meta.sortComposer ?? "",
                conductor: meta.conductor ?? "",
                remixer: meta.remixer ?? "",
                producer: meta.producer ?? "",
                engineer: meta.engineer ?? "",
                lyricist: meta.lyricist ?? "",
                subtitle: meta.subtitle ?? "",
                grouping: meta.grouping ?? "",
                movement: meta.movement ?? "",
                mood: meta.mood ?? "",
                language: meta.language ?? "",
                musicalKey: meta.musicalKey ?? "",
                replayGainTrack: meta.replayGainTrack ?? "",
                replayGainAlbum: meta.replayGainAlbum ?? "",
                mediaType: meta.mediaType ?? "",
                itunesAlbumID: meta.itunesAlbumId ?? "",
                itunesArtistID: meta.itunesArtistId ?? "",
                itunesCatalogID: meta.itunesCatalogId ?? "",
                itunesGenreID: meta.itunesGenreId ?? "",
                itunesMediaType: meta.itunesMediaType ?? "",
                itunesPurchaseDate: meta.itunesPurchaseDate ?? "",
                itunesNorm: meta.itunesNorm ?? "",
                itunesSMPB: meta.itunesSmpb ?? "",
                releaseType: meta.releaseType ?? "",
                releaseStatus: meta.releaseStatus ?? "",
                catalogNumber: meta.catalogNumber ?? "",
                releaseCountry: meta.releaseCountry ?? "",
                artistType: meta.artistType ?? "",
                asin: meta.asin ?? "",
                originalAlbum: meta.originalAlbum ?? "",
                originalArtist: meta.originalArtist ?? "",
                discSubtitle: meta.discSubtitle ?? "",
                work: meta.work ?? "",
                movementNumber: Int(meta.movementNumber),
                movementCount: Int(meta.movementCount),
                bpm: Int(meta.bpm),
                isCompilation: meta.compilation,
                isExplicit: meta.explicitContent,
                duration: meta.duration,
                bitrate: Int(meta.bitrate),
                sampleRate: Double(meta.sampleRate),
                channels: Int(meta.channels),
                bitDepth: Int(meta.bitDepth),
                format: meta.codec ?? "",
                artworkData: meta.artworkData as Data?,
                customFields: meta.customFields ?? [:],
                provenance: MetadataFieldProvenance(
                    trackNumberText: trackSource,
                    discNumberText: discSource,
                    explicitContent: explicitSource,
                    artwork: artworkSource
                )
            )
        } catch {
            if let managerError = error as? TagLibManagerError {
                throw managerError
            }
            throw TagLibManagerError.failedToReadWithUnderlying(String(describing: error))
        }
    }

    public nonisolated static func readMetadata(from url: URL) -> BasicMetadata? {
        do {
            return try readMetadataResult(from: url)
        } catch {
            print("TagLib read error for \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    // MARK: - Write / Erase

    @discardableResult
    public nonisolated static func writeTagMetadata(
        _ metadata: TagLibAudioMetadata,
        to url: URL,
        verification: MetadataWriteVerificationContext = .none,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        try TagLibMetadataExtractor.writeMetadata(metadata, to: url)
        let warnings = metadataWriteWarnings(for: url, verification: verification)
        try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
        return MetadataWriteResult(
            warnings: warnings
        )
    }

    @discardableResult
    public nonisolated static func writeTrackNumberText(
        _ trackNumberText: String,
        discNumberText: String?,
        to url: URL,
        verifyAfterWrite: Bool = true,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        try TagLibMetadataExtractor.writeTrackNumberText(
            trackNumberText,
            discNumberText: discNumberText,
            to: url
        )

        if !verifyAfterWrite {
            return MetadataWriteResult(warnings: [])
        }

        let expectedTrackPair = parseNumberPair(trackNumberText)
        let expectedDiscPair = parseNumberPair(normalizedTrimmed(discNumberText))

        let warnings = metadataWriteWarnings(
            for: url,
            verification: MetadataWriteVerificationContext(
                expectedTrackNumber: expectedTrackPair.number > 0 ? expectedTrackPair.number : nil,
                expectedTrackTotal: expectedTrackPair.total > 0 ? expectedTrackPair.total : nil,
                expectedTrackNumberText: trackNumberText,
                expectedDiscNumber: expectedDiscPair.number > 0 ? expectedDiscPair.number : nil,
                expectedDiscTotal: expectedDiscPair.total > 0 ? expectedDiscPair.total : nil,
                expectedDiscNumberText: discNumberText,
                expectedExplicitContent: nil,
                artworkExpectation: .unchanged,
                customFieldKeys: []
            )
        )
        try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
        return MetadataWriteResult(warnings: warnings)
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMapWithVerification(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode = .replace,
        verifyAfterWrite: Bool = true,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        let resolvedProperties = try resolvedRawPropertyMapForWrite(properties, to: url, mode: mode)
        try TagLibMetadataExtractor.writeRawPropertyMap(resolvedProperties, to: url)

        let warnings = verifyAfterWrite
            ? rawPropertyMapWriteWarnings(requestedProperties: properties, for: url)
            : []
        try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
        return MetadataWriteResult(warnings: warnings)
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMapValuesWithVerification(
        _ properties: [String: [String]],
        to url: URL,
        verifyAfterWrite: Bool = true,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        try TagLibMetadataExtractor.writeRawPropertyMapValues(properties, to: url)

        let warnings: [String]
        if verifyAfterWrite {
            let after = try rawMetadataResult(from: url)
            let lookup = after.properties.reduce(into: [String: [String]]()) { result, entry in
                result[entry.key.uppercased()] = entry.values
            }
            warnings = properties.flatMap { key, values -> [String] in
                let persisted = lookup[key.uppercased()] ?? []
                return Set(persisted) == Set(values) ? [] : ["Raw multi-value key \"\(key)\" differs after save."]
            }
        } else {
            warnings = []
        }

        try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
        return MetadataWriteResult(warnings: warnings)
    }

    public nonisolated static func readStructuredMetadata(from url: URL) -> StructuredMetadata? {
        try? readStructuredMetadataResult(from: url)
    }

    public nonisolated static func readStructuredMetadataResult(from url: URL) throws -> StructuredMetadata {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isSupportedFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        let dict = try TagLibMetadataExtractor.structuredMetadata(for: url)

        let properties = dictionaryArray(dict, "properties").map {
            StructuredPropertyEntry(key: stringValue($0, "key"), values: stringArrayValue($0, "values"))
        }

        let frames = dictionaryArray(dict, "id3v2Frames").map {
            StructuredID3v2Frame(
                frameID: stringValue($0, "id"),
                type: stringValue($0, "type"),
                value: stringValue($0, "value"),
                values: stringArrayValue($0, "values"),
                description: stringValue($0, "description").nilIfEmpty,
                language: stringValue($0, "language").nilIfEmpty,
                url: stringValue($0, "url").nilIfEmpty,
                owner: stringValue($0, "owner").nilIfEmpty,
                data: $0["data"] as? Data,
                fields: $0.compactMapValues { $0 as? String }
            )
        }

        let atoms = dictionaryArray(dict, "mp4Atoms").map {
            StructuredMP4Atom(
                key: stringValue($0, "key"),
                type: stringValue($0, "type"),
                value: stringValue($0, "value"),
                values: stringArrayValue($0, "values"),
                first: intValue($0, "first"),
                second: intValue($0, "second"),
                freeformDescription: stringValue($0, "freeformDescription").nilIfEmpty
            )
        }

        let attributes = dictionaryArray(dict, "asfAttributes").map {
            StructuredASFAttribute(
                key: stringValue($0, "key"),
                type: stringValue($0, "type"),
                value: stringValue($0, "value"),
                data: $0["data"] as? Data,
                pictureType: stringValue($0, "pictureType").nilIfEmpty,
                mimeType: stringValue($0, "mimeType").nilIfEmpty,
                description: stringValue($0, "description").nilIfEmpty,
                language: intValue($0, "language") ?? 0,
                stream: intValue($0, "stream") ?? 0
            )
        }

        let artwork = dictionaryArray(dict, "artwork").compactMap { entry -> StructuredArtwork? in
            guard let data = entry["data"] as? Data else { return nil }
            return StructuredArtwork(
                container: stringValue(entry, "container"),
                pictureType: stringValue(entry, "pictureType").nilIfEmpty,
                pictureTypeCode: intValue(entry, "pictureTypeCode"),
                mimeType: stringValue(entry, "mimeType").nilIfEmpty ?? "application/octet-stream",
                description: stringValue(entry, "description").nilIfEmpty,
                data: data
            )
        }

        let lyrics = dictionaryArray(dict, "lyrics").map {
            StructuredLyrics(
                language: stringValue($0, "language").nilIfEmpty ?? "eng",
                description: stringValue($0, "description"),
                text: stringValue($0, "text")
            )
        }

        let comments = dictionaryArray(dict, "comments").map {
            StructuredComment(
                language: stringValue($0, "language").nilIfEmpty ?? "eng",
                description: stringValue($0, "description"),
                text: stringValue($0, "text")
            )
        }

        let warnings = (dict["warnings"] as? [String]) ?? []

        return StructuredMetadata(
            properties: properties,
            id3v2Frames: frames,
            mp4Atoms: atoms,
            asfAttributes: attributes,
            artwork: artwork,
            lyrics: lyrics,
            comments: comments,
            warnings: warnings
        )
    }

    @discardableResult
    public nonisolated static func writeStructuredMetadataWithVerification(
        _ metadata: StructuredMetadata,
        to url: URL,
        riffPolicy: RIFFMetadataWritePolicy = .preserveInfo,
        includeProperties: Bool = false,
        verifyAfterWrite: Bool = true,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        var warnings: [String] = []
        if ["wav", "aiff", "aif", "aifc", "afc"].contains(ext) {
            switch riffPolicy {
            case .id3v2Only, .preserveInfo:
                break
            case .syncBasicFieldsToInfo:
                warnings.append("syncBasicFieldsToInfo is documented but not yet applied by the structured bridge; existing INFO fields are preserved.")
            }
        }

        let payload = bridgePayload(from: metadata, includeProperties: includeProperties)
        try TagLibMetadataExtractor.writeStructuredMetadata(payload, to: url)

        if verifyAfterWrite {
            warnings.append(contentsOf: structuredWriteWarnings(expected: metadata, for: url))
        }
        try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
        return MetadataWriteResult(warnings: warnings)
    }

    nonisolated private static func residualWarningsAfterErase(for url: URL) -> [String] {
        var warnings: [String] = []

        if let metadata = readMetadata(from: url) {
            var residualFields: [String] = []
            if !metadata.title.isEmpty { residualFields.append("TITLE") }
            if !metadata.artist.isEmpty { residualFields.append("ARTIST") }
            if !metadata.album.isEmpty { residualFields.append("ALBUM") }
            if !metadata.comment.isEmpty { residualFields.append("COMMENT") }
            if !metadata.genre.isEmpty { residualFields.append("GENRE") }
            if !metadata.isrc.isEmpty { residualFields.append("ISRC") }
            if !metadata.barcode.isEmpty { residualFields.append("BARCODE") }
            if !metadata.asin.isEmpty { residualFields.append("ASIN") }
            if !metadata.releaseType.isEmpty { residualFields.append("RELEASETYPE") }
            if !metadata.releaseStatus.isEmpty { residualFields.append("RELEASESTATUS") }
            if !metadata.musicBrainzTrackID.isEmpty { residualFields.append("MUSICBRAINZ_TRACKID") }
            if !metadata.musicBrainzAlbumID.isEmpty { residualFields.append("MUSICBRAINZ_ALBUMID") }
            if !metadata.acoustID.isEmpty { residualFields.append("ACOUSTID_ID") }
            if metadata.track > 0 || metadata.trackTotal > 0 { residualFields.append("TRACK") }
            if metadata.disc > 0 || metadata.discTotal > 0 { residualFields.append("DISC") }
            if !metadata.work.isEmpty || !metadata.movement.isEmpty { residualFields.append("WORK/MOVEMENT") }
            if metadata.artworkData != nil { residualFields.append("ARTWORK") }
            if !metadata.customFields.isEmpty { residualFields.append("CUSTOM") }

            if !residualFields.isEmpty {
                warnings.append(
                    "Some metadata fields still remain after erase: \(residualFields.joined(separator: ", "))."
                )
            }
        } else {
            warnings.append("Could not verify erase result by re-reading metadata.")
        }

        if let rawDump = rawMetadata(from: url) {
            let remainingKeys = rawDump.properties
                .map(\.key)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !isHiddenInternalRawFieldKey($0) && !$0.isEmpty }
                .sorted()

            if !remainingKeys.isEmpty {
                let preview = remainingKeys.prefix(8).joined(separator: ", ")
                warnings.append(
                    "Raw metadata still contains \(remainingKeys.count) key(s) after erase (\(preview)\(remainingKeys.count > 8 ? ", ..." : ""))."
                )
            }
        }

        return warnings
    }

    @discardableResult
    public nonisolated static func eraseAllMetadataWithVerification(
        from url: URL,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let meta = TagLibAudioMetadata()
        meta.title = ""
        meta.artist = ""
        meta.album = ""
        meta.composer = ""
        meta.genre = ""
        meta.comment = ""
        meta.albumArtist = ""
        meta.year = ""
        meta.releaseDate = ""
        meta.originalReleaseDate = ""
        meta.label = ""
        meta.isrc = ""
        meta.barcode = ""
        meta.musicBrainzArtistId = ""
        meta.musicBrainzAlbumId = ""
        meta.musicBrainzAlbumArtistId = ""
        meta.musicBrainzTrackId = ""
        meta.musicBrainzReleaseGroupId = ""
        meta.musicBrainzReleaseTrackId = ""
        meta.musicBrainzWorkId = ""
        meta.acoustId = ""
        meta.acoustIdFingerprint = ""
        meta.musicIpPuid = ""
        meta.lyricist = ""
        meta.remixer = ""
        meta.producer = ""
        meta.engineer = ""
        meta.language = ""
        meta.mediaType = ""
        meta.releaseType = ""
        meta.releaseStatus = ""
        meta.catalogNumber = ""
        meta.releaseCountry = ""
        meta.asin = ""
        meta.originalAlbum = ""
        meta.originalArtist = ""
        meta.discSubtitle = ""
        meta.work = ""
        meta.movementNumber = 0
        meta.movementCount = 0
        meta.copyright = ""
        meta.trackNumber = 0
        meta.totalTracks = 0
        meta.discNumber = 0
        meta.totalDiscs = 0
        meta.trackNumberText = nil
        meta.discNumberText = nil
        meta.explicitContent = false
        meta.removeArtwork = true
        meta.customFields = nil

        var warnings: [String] = []
        warnings.append(
            contentsOf: try writeTagMetadata(
                meta,
                to: url,
                verification: MetadataWriteVerificationContext(
                    expectedTrackNumber: nil,
                    expectedTrackTotal: nil,
                    expectedTrackNumberText: nil,
                    expectedDiscNumber: nil,
                    expectedDiscTotal: nil,
                    expectedDiscNumberText: nil,
                    expectedExplicitContent: false,
                    artworkExpectation: .absent,
                    customFieldKeys: []
                ),
                failurePolicy: .warn
            ).warnings
        )

        warnings.append(
            contentsOf: try writeRawMetadataPropertyMapWithVerification(
                [:],
                to: url,
                mode: .replace,
                verifyAfterWrite: false
            ).warnings
        )

        warnings.append(contentsOf: residualWarningsAfterErase(for: url))
        try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
        return MetadataWriteResult(warnings: warnings)
    }

    @discardableResult
    public nonisolated static func writeMetadataWithVerification(
        _ meta: BasicMetadata,
        to url: URL,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        let m = TagLibAudioMetadata()

        func nilIfEmpty(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }

        // Core tags
        m.title = nilIfEmpty(meta.title)
        m.artist = nilIfEmpty(meta.artist)
        m.album = nilIfEmpty(meta.album)
        m.albumArtist = nilIfEmpty(meta.albumArtist)
        m.composer = nilIfEmpty(meta.composer)
        m.genre = nilIfEmpty(meta.genre)
        m.comment = nilIfEmpty(meta.comment)

        // Numbers
        // TagLib bridge uses `Int` for these fields; use 0 to represent “not set/clear”.
        m.trackNumber = meta.track
        m.totalTracks = meta.trackTotal
        m.discNumber = meta.disc
        m.totalDiscs = meta.discTotal
        m.trackNumberText = nilIfEmpty(meta.trackNumberText)
        m.discNumberText = nilIfEmpty(meta.discNumberText)

        // Dates
        m.year = nilIfEmpty(meta.year)
        m.releaseDate = nilIfEmpty(meta.releaseDate)
        m.originalReleaseDate = nilIfEmpty(meta.originalReleaseDate)

        // Legal / publisher
        m.label = nilIfEmpty(meta.publisher)
        m.copyright = nilIfEmpty(meta.copyright)
        m.lyrics = nilIfEmpty(meta.lyrics)
        m.encodedBy = nilIfEmpty(meta.encodedBy)
        m.encoderSettings = nilIfEmpty(meta.encoderSettings)
        m.sortTitle = nilIfEmpty(meta.sortTitle)
        m.sortArtist = nilIfEmpty(meta.sortArtist)
        m.sortAlbum = nilIfEmpty(meta.sortAlbum)
        m.sortAlbumArtist = nilIfEmpty(meta.sortAlbumArtist)
        m.sortComposer = nilIfEmpty(meta.sortComposer)
        m.conductor = nilIfEmpty(meta.conductor)
        m.remixer = nilIfEmpty(meta.remixer)
        m.producer = nilIfEmpty(meta.producer)
        m.engineer = nilIfEmpty(meta.engineer)
        m.lyricist = nilIfEmpty(meta.lyricist)
        m.subtitle = nilIfEmpty(meta.subtitle)
        m.grouping = nilIfEmpty(meta.grouping)
        m.movement = nilIfEmpty(meta.movement)
        m.mood = nilIfEmpty(meta.mood)
        m.language = nilIfEmpty(meta.language)
        m.musicalKey = nilIfEmpty(meta.musicalKey)
        m.replayGainTrack = nilIfEmpty(meta.replayGainTrack)
        m.replayGainAlbum = nilIfEmpty(meta.replayGainAlbum)
        m.mediaType = nilIfEmpty(meta.mediaType)
        m.itunesAlbumId = nilIfEmpty(meta.itunesAlbumID)
        m.itunesArtistId = nilIfEmpty(meta.itunesArtistID)
        m.itunesCatalogId = nilIfEmpty(meta.itunesCatalogID)
        m.itunesGenreId = nilIfEmpty(meta.itunesGenreID)
        m.itunesMediaType = nilIfEmpty(meta.itunesMediaType)
        m.itunesPurchaseDate = nilIfEmpty(meta.itunesPurchaseDate)
        m.itunesNorm = nilIfEmpty(meta.itunesNorm)
        m.itunesSmpb = nilIfEmpty(meta.itunesSMPB)
        m.releaseType = nilIfEmpty(meta.releaseType)
        m.releaseStatus = nilIfEmpty(meta.releaseStatus)
        m.catalogNumber = nilIfEmpty(meta.catalogNumber)
        m.releaseCountry = nilIfEmpty(meta.releaseCountry)
        m.artistType = nilIfEmpty(meta.artistType)
        m.asin = nilIfEmpty(meta.asin)
        m.originalAlbum = nilIfEmpty(meta.originalAlbum)
        m.originalArtist = nilIfEmpty(meta.originalArtist)
        m.discSubtitle = nilIfEmpty(meta.discSubtitle)
        m.work = nilIfEmpty(meta.work)
        m.movementNumber = meta.movementNumber
        m.movementCount = meta.movementCount

        // Explicit
        m.bpm = meta.bpm
        m.compilation = meta.isCompilation
        m.explicitContent = meta.isExplicit
        m.isrc = nilIfEmpty(meta.isrc)
        m.barcode = nilIfEmpty(meta.barcode)
        m.musicBrainzArtistId = nilIfEmpty(meta.musicBrainzArtistID)
        m.musicBrainzAlbumId = nilIfEmpty(meta.musicBrainzAlbumID)
        m.musicBrainzAlbumArtistId = nilIfEmpty(meta.musicBrainzAlbumArtistID)
        m.musicBrainzTrackId = nilIfEmpty(meta.musicBrainzTrackID)
        m.musicBrainzReleaseGroupId = nilIfEmpty(meta.musicBrainzReleaseGroupID)
        m.musicBrainzReleaseTrackId = nilIfEmpty(meta.musicBrainzReleaseTrackID)
        m.musicBrainzWorkId = nilIfEmpty(meta.musicBrainzWorkID)
        m.acoustId = nilIfEmpty(meta.acoustID)
        m.acoustIdFingerprint = nilIfEmpty(meta.acoustIDFingerprint)
        m.musicIpPuid = nilIfEmpty(meta.musicIPPUID)
        m.customFields = meta.customFields.isEmpty ? nil : meta.customFields

        // Persist through the write coordinator so all metadata entry points
        // share post-write verification policy.
        let result = try writeTagMetadata(
            m,
            to: url,
            verification: MetadataWriteVerificationContext(
                expectedTrackNumber: meta.track,
                expectedTrackTotal: meta.trackTotal,
                expectedTrackNumberText: meta.trackNumberText,
                expectedDiscNumber: meta.disc,
                expectedDiscTotal: meta.discTotal,
                expectedDiscNumberText: meta.discNumberText,
                expectedExplicitContent: meta.isExplicit,
                artworkExpectation: .unchanged,
                customFieldKeys: Array(meta.customFields.keys)
            ),
            failurePolicy: failurePolicy
        )
        return result
    }

    /// Write `BasicMetadata` back to the file using TagLib.
    ///
    /// Notes:
    /// - This is intended for formats supported by our TagLib bridge's write paths.
    /// - Fields that are empty strings are written as `nil` (i.e. removed/cleared).
    /// - `publisher` is mapped to TagLib's `label` field.
    @discardableResult
    public nonisolated static func writeMetadata(_ meta: BasicMetadata, to url: URL) throws -> Bool {
        let result = try writeMetadataWithVerification(meta, to: url)
        if !result.warnings.isEmpty {
            print("[AudioMator] Metadata write warnings for \(url.lastPathComponent): \(result.warnings.joined(separator: " | "))")
        }
        return true
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMap(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode = .replace
    ) throws -> Bool {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        let result = try writeRawMetadataPropertyMapWithVerification(properties, to: url, mode: mode)
        if !result.warnings.isEmpty {
            print("[AudioMator] Raw metadata write warnings for \(url.lastPathComponent): \(result.warnings.joined(separator: " | "))")
        }
        return true
    }

    /// Remove (as much as TagLib allows) all metadata from a file.
    ///
    /// Implementation strategy: write an empty `TagLibAudioMetadata` object.
    /// This should clear the common tag fields and reset numeric fields to 0.
    @discardableResult
    public nonisolated static func eraseAllMetadata(from url: URL) throws -> Bool {
        let result = try eraseAllMetadataWithVerification(from: url)
        if !result.warnings.isEmpty {
            print("[AudioMator] Erase warnings for \(url.lastPathComponent): \(result.warnings.joined(separator: " | "))")
        }
        return true
    }

    /// Raw metadata dump for GUI inspection ("show me everything TagLib sees").
    ///
    /// The extractor returns a dictionary with stable keys:
    /// - "properties": unified TagLib PropertyMap entries
    /// - "id3v2Frames": ID3v2 frames (MP3 only)
    ///
    /// Returns `nil` if format is not supported by TagLib in this app.
    public nonisolated static func rawMetadata(from url: URL) -> RawMetadataDump? {
        try? rawMetadataResult(from: url)
    }

    public nonisolated static func rawMetadataResult(from url: URL) throws -> RawMetadataDump {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else {
            throw TagLibManagerError.unsupportedFormat
        }

        guard TagLibMetadataExtractor.isSupportedFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        // ObjC++ returns a Foundation dictionary for display; normalize it into Swift models.
        let dict = try TagLibMetadataExtractor.rawMetadata(for: url)

        let propsAny = dict["properties"] as? [Any] ?? []
        let framesAny = dict["id3v2Frames"] as? [Any] ?? []

        let properties: [RawPropertyEntry] = propsAny.compactMap { item in
            guard let d = item as? NSDictionary else { return nil }

            let key = d["key"] as? String ?? ""
            let value = d["value"] as? String ?? ""

            let values: [String]
            if let arr = d["values"] as? [String] {
                values = arr
            } else if let arr = d["values"] as? [Any] {
                values = arr.compactMap { $0 as? String }
            } else {
                values = []
            }

            let count: Int
            if let n = d["count"] as? Int {
                count = n
            } else if let n = d["count"] as? NSNumber {
                count = n.intValue
            } else {
                count = values.count
            }

            guard !isHiddenInternalRawFieldKey(key) else { return nil }

            return RawPropertyEntry(key: key, value: value, values: values, count: count)
        }
        .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }

        let id3v2Frames: [RawID3v2FrameEntry] = framesAny.compactMap { item in
            guard let d = item as? NSDictionary else { return nil }

            let frameID = d["id"] as? String ?? ""
            let value = d["value"] as? String ?? ""
            let desc = d["description"] as? String
            let lang = d["language"] as? String

            return RawID3v2FrameEntry(frameID: frameID, value: value, description: desc, language: lang)
        }

        if !properties.isEmpty {
            return RawMetadataDump(properties: properties, id3v2Frames: id3v2Frames)
        }

        if let dumpText = try? TagLibMetadataExtractor.dumpMetadataText(from: url) {
            let fallbackProperties = parsedPropertyEntries(fromDumpText: dumpText)
            if !fallbackProperties.isEmpty {
                return RawMetadataDump(properties: fallbackProperties, id3v2Frames: id3v2Frames)
            }
        }

        return RawMetadataDump(properties: properties, id3v2Frames: id3v2Frames)
    }

    /// Formats *raw* metadata (as seen by TagLib) into a single text blob for GUI display.
    ///
    /// This is intentionally **not** the same as the structured fields shown in the right inspector.
    /// It surfaces:
    /// - TagLib `PropertyMap` entries (including multi-value fields)
    /// - ID3v2 frames (MP3 only), including TXXX/COMM details when available
    public nonisolated static func rawMetadataText(from url: URL) -> String? {
        // Prefer a direct text dump from the bridge if available.
        if let text = bridgeTextDumpIfAvailable(for: url) {
            return text
        }

        // Otherwise, build a readable text representation from the normalized dump models.
        guard let dump = rawMetadata(from: url) else { return nil }

        var lines: [String] = []
        lines.append("File: \(url.lastPathComponent)")
        lines.append("Path: \(url.path)")
        lines.append("")

        lines.append("[TagLib Properties]")
        if dump.properties.isEmpty {
            lines.append("(none)")
        } else {
            for p in dump.properties {
                // Prefer showing the full values array when present.
                if !p.values.isEmpty {
                    if p.values.count == 1 {
                        lines.append("\(p.key): \(p.values[0])")
                    } else {
                        lines.append("\(p.key):")
                        for v in p.values {
                            lines.append("  - \(v)")
                        }
                    }
                } else if !p.value.isEmpty {
                    lines.append("\(p.key): \(p.value)")
                } else {
                    lines.append("\(p.key):")
                }
            }
        }

        lines.append("")
        lines.append("[ID3v2 Frames]")
        if dump.id3v2Frames.isEmpty {
            lines.append("(none)")
        } else {
            for f in dump.id3v2Frames {
                let trimmedValue = f.value.trimmingCharacters(in: .whitespacesAndNewlines)

                // Provide richer labeling for common “multi-field” frames.
                if let desc = f.description, !desc.isEmpty {
                    // Typically TXXX / COMM
                    if let lang = f.language, !lang.isEmpty {
                        lines.append("\(f.frameID) [\(lang)] (\(desc)): \(trimmedValue)")
                    } else {
                        lines.append("\(f.frameID) (\(desc)): \(trimmedValue)")
                    }
                } else {
                    lines.append("\(f.frameID): \(trimmedValue)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
