//
//  TagLibMetadataModels.swift
//  TagLibAudioMetadata
//

import Foundation

/// Keeps ephemeral UI identity out of synthesized semantic equality and hashing.
@propertyWrapper
public struct SemanticIdentityExcluded: Hashable, Sendable {
    public var wrappedValue: UUID

    public init(wrappedValue: UUID) {
        self.wrappedValue = wrappedValue
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { true }
    public func hash(into hasher: inout Hasher) {}
}

nonisolated func normalizedArtworkMIMEType(_ mimeType: String?, data: Data?) -> String? {
    if let mimeType {
        let normalized = mimeType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalized.isEmpty {
            return normalized == "image/jpg" ? "image/jpeg" : normalized
        }
    }

    guard let data else { return nil }
    let bytes = [UInt8](data.prefix(12))
    if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
    if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return "image/png" }
    if bytes.starts(with: Array("GIF87a".utf8)) || bytes.starts(with: Array("GIF89a".utf8)) { return "image/gif" }
    if bytes.starts(with: [0x42, 0x4D]) { return "image/bmp" }
    if bytes.starts(with: [0x49, 0x49, 0x2A, 0x00]) || bytes.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) { return "image/tiff" }
    if bytes.count >= 12,
       bytes[0..<4].elementsEqual(Array("RIFF".utf8)),
       bytes[8..<12].elementsEqual(Array("WEBP".utf8)) {
        return "image/webp"
    }
    return nil
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

public enum ExplicitAdvisory: String, Hashable, Sendable {
    /// No advisory field exists in the source metadata.
    case unspecified
    /// The source explicitly marks the recording as clean/non-explicit.
    case clean
    /// The source explicitly marks the recording as explicit.
    case explicit
}

/// A normalized editing and display projection of commonly used metadata.
///
/// Fields this model cannot express, including raw cardinality and supported
/// container-specific entries, are preservation data rather than editable
/// properties. Use `MetadataPatch`, Raw, or Structured APIs for precise edits.
public struct BasicMetadata: Sendable {
    /// Schema fields that this normalized projection can explicitly edit.
    /// Fields outside this set are preservation-only during a Basic round trip.
    nonisolated static let editableFieldKeys: Set<MetadataFieldKey> =
        Set(MetadataFieldKey.allCases).subtracting([
            .performer,
            .involvedPeople,
            .musicianCredits,
            .trackerName,
            .custom,
        ])

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
    /// Display/formatting projection for track numbering. On MP4, native `trkn`
    /// is authoritative for ordinary Basic writes.
    public var trackNumberText: String
    /// Display/formatting projection for disc numbering. On MP4, native `disk`
    /// is authoritative for ordinary Basic writes.
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
    public var explicitAdvisory: ExplicitAdvisory
    /// Compatibility convenience. Setting `false` records an explicit clean advisory.
    public var isExplicit: Bool {
        get { explicitAdvisory == .explicit }
        set { explicitAdvisory = newValue ? .explicit : .clean }
    }
    public var duration: Double
    public var bitrate: Int
    public var sampleRate: Double
    public var channels: Int
    public var bitDepth: Int
    public var format: String
    public var artworkData: Data?
    /// The declared media type for `artworkData`, normalized to lowercase when known.
    /// When a container omits it, reads infer common image types from reliable magic bytes.
    public var artworkMIMEType: String?
    public var customFields: [String: String]
    /// Original cardinality for custom fields read from a file.
    /// `customFields` remains the source-compatible, display-oriented projection.
    /// This read-only provenance is not caller-editable metadata.
    public internal(set) var customFieldValues: [String: [String]]
    /// Exact projected values captured during read, used to detect intentional Basic edits.
    /// This read-only provenance is not caller-editable metadata.
    public internal(set) var originalCustomFieldProjection: [String: String]
    /// Original raw cardinality for standard fields captured during read.
    /// The scalar properties above remain the normalized display projection.
    /// This read-only provenance is not caller-editable metadata.
    public internal(set) var originalStandardFieldValues: [String: [String]]
    /// Original scalar display values paired with `originalStandardFieldValues`.
    /// This read-only provenance is not caller-editable metadata.
    public internal(set) var originalStandardFieldProjection: [String: String]
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
        explicitAdvisory: .unspecified,
        duration: 0,
        bitrate: 0,
        sampleRate: 0,
        channels: 0,
        bitDepth: 0,
        format: "",
        artworkData: nil,
        artworkMIMEType: nil,
        customFields: [:],
        customFieldValues: [:],
        originalCustomFieldProjection: [:],
        originalStandardFieldValues: [:],
        originalStandardFieldProjection: [:],
        provenance: .unknown
    )
}

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
    @SemanticIdentityExcluded public var id = UUID()
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
    @SemanticIdentityExcluded public var id = UUID()
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

/// Structured collections whose bridge representation has replace-all semantics.
/// Include an empty collection here to remove every existing entry of that kind.
public enum StructuredMetadataReplaceableCollection: String, Hashable, Sendable {
    case artwork
    case lyrics
    case comments
}

public struct StructuredPropertyEntry: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded public var id = UUID()
    public var key: String
    public var values: [String]

    public init(key: String, values: [String]) {
        self.key = key
        self.values = values
    }
}

public struct StructuredID3v2Frame: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded public var id = UUID()
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
    public var elementID: String?
    public var startTimeMilliseconds: Int?
    public var endTimeMilliseconds: Int?
    public var startOffset: Int?
    public var endOffset: Int?
    public var isTopLevel: Bool?
    public var isOrdered: Bool?
    public var children: [String]
    public var embeddedFrameCount: Int?

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
        fields: [String: String] = [:],
        elementID: String? = nil,
        startTimeMilliseconds: Int? = nil,
        endTimeMilliseconds: Int? = nil,
        startOffset: Int? = nil,
        endOffset: Int? = nil,
        isTopLevel: Bool? = nil,
        isOrdered: Bool? = nil,
        children: [String] = [],
        embeddedFrameCount: Int? = nil
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
        self.elementID = elementID
        self.startTimeMilliseconds = startTimeMilliseconds
        self.endTimeMilliseconds = endTimeMilliseconds
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.isTopLevel = isTopLevel
        self.isOrdered = isOrdered
        self.children = children
        self.embeddedFrameCount = embeddedFrameCount
    }
}

public struct StructuredMP4Atom: Identifiable, Hashable, Sendable {
    @SemanticIdentityExcluded public var id = UUID()
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
    @SemanticIdentityExcluded public var id = UUID()
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
    @SemanticIdentityExcluded public var id = UUID()
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
    @SemanticIdentityExcluded public var id = UUID()
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
    @SemanticIdentityExcluded public var id = UUID()
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
    /// Atomic rename completed, but the parent-directory fsync failed.
    /// The new file is already visible and callers must not treat this as a pre-commit failure.
    case committedButDurabilityUncertain(String)
}
