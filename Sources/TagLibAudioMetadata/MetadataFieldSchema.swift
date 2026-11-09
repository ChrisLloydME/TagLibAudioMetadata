//
//  MetadataFieldSchema.swift
//  TagLibAudioMetadata
//

import Foundation

public enum MetadataFieldCategory: String, CaseIterable, Hashable, Sendable {
    case basic
    case numbering
    case artwork
    case lyricsAndComments
    case dates
    case people
    case peopleRoles
    case sorting
    case identifiers
    case release
    case replayGain
    case itunes
    case technical
    case custom
}

public enum MetadataFieldFormat: String, CaseIterable, Hashable, Sendable {
    case tagLibPropertyMap
    case id3v2
    case mp4
    case xiph
    case ape
    case asf
    case riffInfo
    case flac
    /// Reserved for a future Matroska family; no family is registered.
    case matroska
}

public enum MetadataFieldStorageKind: String, Hashable, Sendable {
    case nativeTag
    case propertyMap
    case textFrame
    case userTextFrame
    case mp4Atom
    case mp4Freeform
    case complexProperty
    case extensionFrame
    case binary
    /// Reserved for future pattern-based fields; no schema currently uses it.
    case pattern
}

public enum MetadataPatchValueKind: String, CaseIterable, Hashable, Sendable {
    case text
    case integer
    case boolean
    case values
}

public struct MetadataIntegerConstraint: Hashable, Sendable {
    public var minimum: Int
    public var maximum: Int

    public init(minimum: Int, maximum: Int) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public struct MetadataFormatMapping: Hashable, Sendable {
    public var format: MetadataFieldFormat
    public var storageKind: MetadataFieldStorageKind
    public var keys: [String]
    public var note: String?

    public init(
        format: MetadataFieldFormat,
        storageKind: MetadataFieldStorageKind,
        keys: [String],
        note: String? = nil
    ) {
        self.format = format
        self.storageKind = storageKind
        self.keys = keys
        self.note = note
    }
}

public enum MetadataFieldKey: String, CaseIterable, Hashable, Sendable {
    case title
    case artist
    case album
    case albumArtist
    case date
    case year
    case standaloneDate
    case releaseDate
    case originalReleaseDate
    case track
    case trackTotal
    case disc
    case discTotal
    case artwork
    case lyrics
    case comment
    case genre
    case composer
    case conductor
    case remixer
    case performer
    case producer
    case engineer
    case lyricist
    case involvedPeople
    case musicianCredits
    case publisher
    case copyright
    case encodedBy
    case encoderSettings
    case isrc
    case barcode
    case catalogNumber
    case asin
    case releaseType
    case releaseStatus
    case releaseCountry
    case mediaType
    case work
    case movement
    case movementNumber
    case movementCount
    case discSubtitle
    case subtitle
    case grouping
    case contentGroup
    case artists
    case mood
    case language
    case musicalKey
    case bpm
    case compilation
    case explicitContent
    case sortTitle
    case sortArtist
    case sortAlbum
    case sortAlbumArtist
    case sortComposer
    case musicBrainzArtistID
    case musicBrainzAlbumID
    case musicBrainzAlbumArtistID
    case musicBrainzTrackID
    case musicBrainzReleaseGroupID
    case musicBrainzReleaseTrackID
    case musicBrainzWorkID
    case acoustID
    case acoustIDFingerprint
    case musicIPPUID
    case replayGainTrackGain
    case replayGainAlbumGain
    case replayGainTrackPeak
    case replayGainAlbumPeak
    case itunesAlbumID
    case itunesArtistID
    case itunesCatalogID
    case itunesGenreID
    case itunesMediaType
    case itunesPurchaseDate
    case itunesNorm
    case itunesSMPB
    case originalAlbum
    case originalArtist
    case artistType
    case trackerName

    // MP4-exclusive registrations from AM-TLAM-MAPPING-2.2 section 8.1.
    case director
    case itunesAccount
    case itunesComposerID
    case itunesCountryID
    case itunesGapless
    case itunesHDVideo
    case itunesOwner
    case rate
    case showMovement
    case storeDescription
    case tvEpisode
    case tvEpisodeID
    case tvNetwork
    case tvSeason
    case tvShow
    case tvShowSort

    case custom
}

public struct MetadataFieldSchema: Identifiable, Hashable, Sendable {
    public var id: MetadataFieldKey { key }
    public var key: MetadataFieldKey
    public var displayName: String
    public var category: MetadataFieldCategory
    /// Stable semantic identity shared by presentation aliases. It is not the
    /// engine PropertyMap key and may differ from the Swift case spelling.
    public var semanticKey: String
    /// Display/import and engine PropertyMap aliases. Presentation names do
    /// not create additional stored fields.
    public var propertyMapKeys: [String]
    /// Explicit native read/write targets from the mapping catalog.
    public var nativeTargets: [MetadataNativeTarget]
    /// Exactly one schema owns a semantic key for canonical enumeration.
    public var isCanonicalSemanticOwner: Bool
    /// The legacy `.date` spelling addresses the YEAR slot; it is not a
    /// standalone DATE identity.
    public var isLegacyYearAlias: Bool
    public var isMultiValue: Bool
    public var isPeopleField: Bool
    public var isRoleQualified: Bool
    public var isArtworkField: Bool
    /// A concrete reason typed writes are withheld despite readable targets.
    public var writeUnsupportedReason: String?
    public var mappingContractVersion: String

    /// A compatibility projection of the native target table in the older
    /// format-mapping vocabulary. It is derived, never hand-maintained, so the
    /// two views cannot drift.
    public var mappings: [MetadataFormatMapping] {
        MetadataFieldSchema.formatMappings(
            for: nativeTargets,
            propertyKeys: propertyMapKeys,
            isArtworkField: isArtworkField
        )
    }

    /// Value representations accepted by the high-level typed patch API.
    public var acceptedPatchValueKinds: Set<MetadataPatchValueKind> {
        switch key {
        case .track, .trackTotal, .disc, .discTotal, .movementNumber, .movementCount, .bpm,
             .itunesAlbumID, .itunesArtistID, .itunesCatalogID, .itunesGenreID,
             .itunesComposerID, .itunesCountryID, .itunesMediaType, .rate,
             .tvEpisode, .tvSeason:
            [.integer]
        case .compilation, .itunesGapless, .itunesHDVideo, .showMovement:
            [.boolean]
        case .artwork, .explicitContent, .custom:
            []
        default:
            isMultiValue ? [.text, .values] : [.text]
        }
    }

    /// Numeric limits shared with the Objective-C++ bridge's integer validation.
    /// MP4 pair components have narrower native limits; the planner applies
    /// those per destination family.
    public var integerConstraint: MetadataIntegerConstraint? {
        switch key {
        case .track, .trackTotal, .disc, .discTotal:
            MetadataIntegerConstraint(minimum: 1, maximum: Int(Int32.max))
        case .itunesAlbumID, .itunesArtistID, .itunesCatalogID, .itunesGenreID,
             .itunesComposerID, .itunesCountryID,
             .tvEpisode, .tvSeason:
            MetadataIntegerConstraint(minimum: 0, maximum: Int(UInt32.max))
        case .itunesMediaType:
            MetadataIntegerConstraint(minimum: 0, maximum: 255)
        case .rate:
            MetadataIntegerConstraint(minimum: 0, maximum: Int(Int32.max))
        case .movementNumber, .movementCount, .bpm:
            MetadataIntegerConstraint(minimum: 0, maximum: Int(Int32.max))
        default:
            nil
        }
    }

    public init(
        key: MetadataFieldKey,
        displayName: String,
        category: MetadataFieldCategory,
        semanticKey: String,
        propertyMapKeys: [String],
        nativeTargets: [MetadataNativeTarget] = [],
        isCanonicalSemanticOwner: Bool = true,
        isLegacyYearAlias: Bool = false,
        isMultiValue: Bool = false,
        isPeopleField: Bool = false,
        isRoleQualified: Bool = false,
        isArtworkField: Bool = false,
        writeUnsupportedReason: String? = nil,
        mappingContractVersion: String = MetadataMappingCatalog.contractVersion
    ) {
        self.key = key
        self.displayName = displayName
        self.category = category
        self.semanticKey = semanticKey
        self.propertyMapKeys = propertyMapKeys
        self.nativeTargets = nativeTargets
        self.isCanonicalSemanticOwner = isCanonicalSemanticOwner
        self.isLegacyYearAlias = isLegacyYearAlias
        self.isMultiValue = isMultiValue
        self.isPeopleField = isPeopleField
        self.isRoleQualified = isRoleQualified
        self.isArtworkField = isArtworkField
        self.writeUnsupportedReason = writeUnsupportedReason
        self.mappingContractVersion = mappingContractVersion
    }

    public func targets(for family: MetadataNativeFamily) -> [MetadataNativeTarget] {
        nativeTargets.filter { $0.family == family }
    }

    /// The single preferred write location for a family. Components of one
    /// numeric pair intentionally share a native slot; their semantic keys
    /// differ and the patch planner resolves both together.
    public func writeTarget(for family: MetadataNativeFamily) -> MetadataNativeTarget? {
        nativeTargets.first { $0.family == family && $0.preferredWrite }
    }

    public func capability(for family: MetadataNativeFamily) -> MetadataMappingCapability {
        MetadataTargetProfile(
            semanticKey: semanticKey,
            shape: MetadataValueShape(rawValue: nativeTargets.first?.shape.rawValue ?? "text") ?? .text,
            targets: nativeTargets,
            writeUnsupportedReason: writeUnsupportedReason
        ).capability(for: family)
    }

    public func capability(for format: MetadataFieldFormat) -> MetadataMappingCapability {
        let families: [MetadataNativeFamily] = switch format {
        case .id3v2: [.id3v23, .id3v24]
        case .mp4: [.mp4]
        case .xiph: [.vorbisComment]
        case .ape: [.apev2]
        case .asf: [.asf]
        case .riffInfo: [.riffInfo]
        case .matroska: [.matroska]
        case .flac: [.vorbisComment]
        case .tagLibPropertyMap: []
        }
        let states = families.map { capability(for: $0) }
        if states.contains(.native) { return .native }
        if states.contains(.conventionalExtension) { return .conventionalExtension }
        if states.contains(.ambiguous) { return .ambiguous }
        if states.contains(.readOnly) { return .readOnly }
        return .unsupported
    }

    public var aggregateCapability: MetadataMappingCapability {
        let states = MetadataNativeFamily.allCases.map { capability(for: $0) }
        if states.contains(.native) { return .native }
        if states.contains(.conventionalExtension) { return .conventionalExtension }
        if states.contains(.readOnly) { return .readOnly }
        return .unsupported
    }

    private static func formatMappings(
        for targets: [MetadataNativeTarget],
        propertyKeys: [String],
        isArtworkField: Bool
    ) -> [MetadataFormatMapping] {
        var result: [MetadataFormatMapping] = []
        if !propertyKeys.isEmpty {
            result.append(.init(format: .tagLibPropertyMap, storageKind: .propertyMap, keys: propertyKeys))
        }
        var seen = Set<MetadataFormatMapping>()
        for target in targets {
            let mapping: MetadataFormatMapping? = switch target.family {
            case .id3v23, .id3v24:
                switch target.storage {
                case .userTextFrame:
                    .init(format: .id3v2, storageKind: .userTextFrame, keys: [target.nativeIdentity])
                case .extensionFrame:
                    .init(format: .id3v2, storageKind: .extensionFrame, keys: [target.nativeIdentity])
                case .binaryFrame:
                    .init(format: .id3v2, storageKind: .binary, keys: [target.nativeIdentity])
                case .identifierFrame:
                    .init(format: .id3v2, storageKind: .binary, keys: ["UFID"])
                default:
                    .init(format: .id3v2, storageKind: .textFrame, keys: [target.nativeIdentity])
                }
            case .mp4:
                switch target.storage {
                case .mp4Freeform:
                    .init(format: .mp4, storageKind: .mp4Freeform,
                          keys: ["----:com.apple.iTunes:\(target.nativeIdentity)"])
                case .binaryFrame:
                    .init(format: .mp4, storageKind: .binary, keys: [target.nativeIdentity])
                default:
                    .init(format: .mp4, storageKind: .mp4Atom, keys: [target.nativeIdentity])
                }
            case .vorbisComment:
                .init(format: .xiph, storageKind: .propertyMap, keys: [target.nativeIdentity])
            case .apev2:
                .init(format: .ape, storageKind: .propertyMap, keys: [target.nativeIdentity])
            case .asf:
                .init(format: .asf, storageKind: .propertyMap, keys: [target.nativeIdentity])
            case .riffInfo:
                .init(format: .riffInfo, storageKind: .textFrame, keys: [target.nativeIdentity])
            case .matroska:
                .init(format: .matroska, storageKind: .nativeTag, keys: [target.nativeIdentity])
            }
            if let mapping, seen.insert(mapping).inserted {
                result.append(mapping)
            }
        }
        if isArtworkField, !result.contains(where: { $0.format == .flac }) {
            result.append(.init(format: .flac, storageKind: .complexProperty, keys: ["PICTURE"]))
        }
        return result
    }
}

public enum MetadataFieldRegistry {
    public nonisolated static let allSchemas: [MetadataFieldSchema] = [
        schema(.title, "Title", .basic, ["TITLE"], id3: ["TIT2"], mp4: ["\u{00A9}nam"]),
        schema(.artist, "Artist", .people, ["ARTIST"], id3: ["TPE1"], mp4: ["\u{00A9}ART"], multi: true, people: true),
        schema(.album, "Album", .basic, ["ALBUM"], id3: ["TALB"], mp4: ["\u{00A9}alb"]),
        schema(.albumArtist, "Album Artist", .people, ["ALBUMARTIST", "ALBUM ARTIST"], id3: ["TPE2"], mp4: ["aART"], multi: true, people: true),
        schema(.date, "Recording Date (legacy YEAR spelling)", .dates, ["DATE", "YEAR"], semantic: "YEAR",
               id3: ["TDRC", "TYER"], legacyYearAlias: true),
        schema(.year, "Year", .dates, ["YEAR", "DATE"], semantic: "YEAR"),
        schema(.standaloneDate, "Date", .dates, ["STANDALONEDATE"], semantic: "DATE"),
        schema(.releaseDate, "Release Date", .dates, ["RELEASEDATE"], id3: ["TDRL"], mp4: ["\u{00A9}day"]),
        schema(.originalReleaseDate, "Original Release Date", .dates, ["ORIGINALDATE", "ORIGINAL YEAR"], id3: ["TDOR"], mp4Freeform: ["ORIGINAL YEAR"]),
        schema(.track, "Track Number", .numbering, ["TRACKNUMBER", "TRACK"], id3: ["TRCK"], mp4: ["trkn"]),
        schema(.trackTotal, "Track Total", .numbering, ["TRACKTOTAL", "TOTALTRACKS"], id3: ["TRCK"], mp4: ["trkn"]),
        schema(.disc, "Disc Number", .numbering, ["DISCNUMBER", "DISC"], id3: ["TPOS"], mp4: ["disk"]),
        schema(.discTotal, "Disc Total", .numbering, ["DISCTOTAL", "TOTALDISCS"], id3: ["TPOS"], mp4: ["disk"]),
        MetadataFieldSchema(
            key: .artwork,
            displayName: "Artwork",
            category: .artwork,
            semanticKey: "PICTURE",
            propertyMapKeys: ["PICTURE"],
            nativeTargets: MetadataMappingCatalog.profile(forSemanticKey: "PICTURE")?.targets ?? [],
            isArtworkField: true
        ),
        schema(.lyrics, "Lyrics", .lyricsAndComments, ["LYRICS"], id3: ["USLT"], mp4: ["\u{00A9}lyr"]),
        schema(.comment, "Comment", .lyricsAndComments, ["COMMENT"], id3: ["COMM"], mp4: ["\u{00A9}cmt"]),
        schema(.genre, "Genre", .basic, ["GENRE"], id3: ["TCON"], mp4: ["\u{00A9}gen", "gnre"], multi: true),
        schema(.composer, "Composer", .people, ["COMPOSER"], id3: ["TCOM"], mp4: ["\u{00A9}wrt"], multi: true, people: true),
        schema(.conductor, "Conductor", .people, ["CONDUCTOR"], id3: ["TPE3"], mp4Freeform: ["CONDUCTOR"], multi: true, people: true),
        schema(.remixer, "Remixer", .people, ["REMIXER"], id3: ["TPE4"], mp4Freeform: ["REMIXER"], multi: true, people: true),
        schema(.performer, "Performer", .peopleRoles, ["PERFORMER"], id3: ["TMCL"], mp4Freeform: ["PERFORMER"], multi: true, people: true, role: true),
        schema(.producer, "Producer", .people, ["PRODUCER"], id3User: ["PRODUCER"], mp4Freeform: ["PRODUCER"], multi: true, people: true),
        schema(.engineer, "Engineer", .people, ["ENGINEER"], id3User: ["ENGINEER"], mp4Freeform: ["ENGINEER"], multi: true, people: true),
        schema(.lyricist, "Lyricist", .people, ["LYRICIST"], id3: ["TEXT"], mp4Freeform: ["LYRICIST"], multi: true, people: true),
        schema(.involvedPeople, "Involved People", .peopleRoles, ["INVOLVEDPEOPLE"], id3: ["TIPL"], mp4Freeform: ["INVOLVEDPEOPLE"], multi: true, people: true, role: true),
        schema(.musicianCredits, "Musician Credits", .peopleRoles, ["MUSICIANCREDITS"], id3: ["TMCL"], mp4Freeform: ["MUSICIANCREDITS"], multi: true, people: true, role: true),
        schema(.publisher, "Publisher", .release, ["LABEL", "PUBLISHER"], id3: ["TPUB"], mp4Freeform: ["LABEL"]),
        schema(.copyright, "Copyright", .release, ["COPYRIGHT"], id3: ["TCOP"], mp4: ["cprt"]),
        schema(.encodedBy, "Encoded By", .technical, ["ENCODEDBY", "ENCODING"], id3: ["TENC"], mp4: ["\u{00A9}too"]),
        schema(.encoderSettings, "Encoder Settings", .technical, ["ENCODERSETTINGS"], id3: ["TSSE"], mp4Freeform: ["ENCODERSETTINGS"]),
        schema(.isrc, "ISRC", .identifiers, ["ISRC"], id3: ["TSRC"], mp4Freeform: ["ISRC"]),
        schema(.barcode, "Barcode", .identifiers, ["BARCODE", "UPC", "EAN"], id3User: ["BARCODE"], mp4Freeform: ["BARCODE"]),
        schema(.catalogNumber, "Catalog Number", .release, ["CATALOGNUMBER", "CATALOG NUMBER", "CATALOG"], id3User: ["CATALOGNUMBER"], mp4Freeform: ["CATALOGNUMBER"]),
        schema(.asin, "ASIN", .identifiers, ["ASIN"], id3User: ["ASIN"], mp4Freeform: ["ASIN"]),
        schema(.releaseType, "Release Type", .release, ["RELEASETYPE", "MUSICBRAINZ_ALBUMTYPE", "MUSICBRAINZ ALBUM TYPE"], id3User: ["RELEASETYPE"], mp4Freeform: ["RELEASETYPE", "MusicBrainz Album Type"]),
        schema(.releaseStatus, "Release Status", .release, ["RELEASESTATUS", "MUSICBRAINZ_ALBUMSTATUS", "MUSICBRAINZ ALBUM STATUS"], id3User: ["RELEASESTATUS"], mp4Freeform: ["RELEASESTATUS", "MusicBrainz Album Status"]),
        schema(.releaseCountry, "Release Country", .release, ["RELEASECOUNTRY", "MUSICBRAINZ_ALBUMRELEASECOUNTRY", "MUSICBRAINZ ALBUM RELEASE COUNTRY"], id3User: ["RELEASECOUNTRY"], mp4Freeform: ["MusicBrainz Album Release Country"]),
        schema(.mediaType, "Media Type", .release, ["MEDIATYPE", "MEDIA", "MEDIA TYPE"], id3: ["TMED"], mp4Freeform: ["MEDIATYPE"]),
        schema(.work, "Work", .basic, ["WORK"], id3User: ["WORK"], mp4Freeform: ["WORK"]),
        schema(.movement, "Movement", .basic, ["MOVEMENT", "MOVEMENTNAME"], id3: ["MVNM"], mp4Freeform: ["MOVEMENT"]),
        schema(.movementNumber, "Movement Number", .numbering, ["MOVEMENTNUMBER"], id3: ["MVIN"], mp4Freeform: ["MOVEMENTNUMBER"]),
        schema(.movementCount, "Movement Count", .numbering, ["MOVEMENTCOUNT"], id3: ["MVIN"], mp4Freeform: ["MOVEMENTCOUNT"]),
        schema(.discSubtitle, "Disc Subtitle", .basic, ["DISCSUBTITLE"], id3: ["TSST"], mp4Freeform: ["DISCSUBTITLE"]),
        schema(.subtitle, "Subtitle", .basic, ["SUBTITLE"], id3: ["TIT3"], mp4Freeform: ["SUBTITLE"]),
        schema(.grouping, "Grouping", .basic, ["GROUPING"], multi: true),
        schema(.contentGroup, "Content Group", .basic, ["CONTENTGROUP"]),
        schema(.artists, "Artists", .people, ["ARTISTS"], multi: true, people: true),
        schema(.mood, "Mood", .basic, ["MOOD"], id3: ["TMOO"], mp4Freeform: ["MOOD"], multi: true),
        schema(.language, "Language", .basic, ["LANGUAGE"], id3: ["TLAN"], mp4Freeform: ["LANGUAGE"], multi: true),
        schema(.musicalKey, "Musical Key", .basic, ["INITIALKEY", "KEY"], id3: ["TKEY"], mp4Freeform: ["INITIALKEY"]),
        schema(.bpm, "BPM", .technical, ["BPM"], id3: ["TBPM"], mp4: ["tmpo"]),
        schema(.compilation, "Compilation", .release, ["COMPILATION"], id3: ["TCMP"], mp4: ["cpil"]),
        schema(.explicitContent, "Explicit Content", .itunes, ["ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT"], id3User: ["ITUNESADVISORY"], mp4: ["rtng"], mp4Freeform: ["ITUNESADVISORY"]),
        schema(.sortTitle, "Sort Title", .sorting, ["TITLESORT"], id3: ["TSOT"], mp4: ["sonm"]),
        schema(.sortArtist, "Sort Artist", .sorting, ["ARTISTSORT"], id3: ["TSOP"], mp4: ["soar"]),
        schema(.sortAlbum, "Sort Album", .sorting, ["ALBUMSORT"], id3: ["TSOA"], mp4: ["soal"]),
        schema(.sortAlbumArtist, "Sort Album Artist", .sorting, ["ALBUMARTISTSORT"], id3: ["TSO2"], mp4: ["soaa"]),
        schema(.sortComposer, "Sort Composer", .sorting, ["COMPOSERSORT"], id3: ["TSOC"], mp4: ["soco"]),
        schema(.musicBrainzArtistID, "MusicBrainz Artist ID", .identifiers, ["MUSICBRAINZ_ARTISTID", "MUSICBRAINZ ARTISTID", "MUSICBRAINZ ARTIST ID"], id3User: ["MusicBrainz Artist Id"], mp4Freeform: ["MusicBrainz Artist Id"]),
        schema(.musicBrainzAlbumID, "MusicBrainz Album ID", .identifiers, ["MUSICBRAINZ_ALBUMID", "MUSICBRAINZ ALBUMID", "MUSICBRAINZ ALBUM ID"], id3User: ["MusicBrainz Album Id"], mp4Freeform: ["MusicBrainz Album Id"]),
        schema(.musicBrainzAlbumArtistID, "MusicBrainz Album Artist ID", .identifiers, ["MUSICBRAINZ_ALBUMARTISTID", "MUSICBRAINZ ALBUMARTISTID", "MUSICBRAINZ ALBUM ARTIST ID"], id3User: ["MusicBrainz Album Artist Id"], mp4Freeform: ["MusicBrainz Album Artist Id"]),
        schema(.musicBrainzTrackID, "MusicBrainz Track ID", .identifiers, ["MUSICBRAINZ_TRACKID", "MUSICBRAINZ TRACKID", "MUSICBRAINZ TRACK ID"], id3User: ["MusicBrainz Track Id"], mp4Freeform: ["MusicBrainz Track Id"]),
        schema(.musicBrainzReleaseGroupID, "MusicBrainz Release Group ID", .identifiers, ["MUSICBRAINZ_RELEASEGROUPID", "MUSICBRAINZ RELEASEGROUPID", "MUSICBRAINZ RELEASE GROUP ID"], id3User: ["MusicBrainz Release Group Id"], mp4Freeform: ["MusicBrainz Release Group Id"]),
        schema(.musicBrainzReleaseTrackID, "MusicBrainz Release Track ID", .identifiers, ["MUSICBRAINZ_RELEASETRACKID", "MUSICBRAINZ RELEASETRACKID", "MUSICBRAINZ RELEASE TRACK ID"], id3User: ["MusicBrainz Release Track Id"], mp4Freeform: ["MusicBrainz Release Track Id"]),
        schema(.musicBrainzWorkID, "MusicBrainz Work ID", .identifiers, ["MUSICBRAINZ_WORKID", "MUSICBRAINZ WORKID", "MUSICBRAINZ WORK ID"], id3User: ["MusicBrainz Work Id"], mp4Freeform: ["MusicBrainz Work Id"]),
        schema(.acoustID, "AcoustID", .identifiers, ["ACOUSTID_ID", "ACOUSTID ID"], id3User: ["Acoustid Id"], mp4Freeform: ["Acoustid Id"]),
        schema(.acoustIDFingerprint, "AcoustID Fingerprint", .identifiers, ["ACOUSTID_FINGERPRINT", "ACOUSTID FINGERPRINT"], id3User: ["Acoustid Fingerprint"], mp4Freeform: ["Acoustid Fingerprint"]),
        schema(.musicIPPUID, "MusicIP PUID", .identifiers, ["MUSICIP_PUID", "MUSICIP PUID"], id3User: ["MusicIP PUID"], mp4Freeform: ["MusicIP PUID"]),
        schema(.replayGainTrackGain, "ReplayGain Track Gain", .replayGain, ["REPLAYGAIN_TRACK_GAIN"], id3User: ["REPLAYGAIN_TRACK_GAIN"], mp4Freeform: ["REPLAYGAIN_TRACK_GAIN"]),
        schema(.replayGainAlbumGain, "ReplayGain Album Gain", .replayGain, ["REPLAYGAIN_ALBUM_GAIN"], id3User: ["REPLAYGAIN_ALBUM_GAIN"], mp4Freeform: ["REPLAYGAIN_ALBUM_GAIN"]),
        schema(.replayGainTrackPeak, "ReplayGain Track Peak", .replayGain, ["REPLAYGAIN_TRACK_PEAK"], id3User: ["REPLAYGAIN_TRACK_PEAK"], mp4Freeform: ["REPLAYGAIN_TRACK_PEAK"]),
        schema(.replayGainAlbumPeak, "ReplayGain Album Peak", .replayGain, ["REPLAYGAIN_ALBUM_PEAK"], id3User: ["REPLAYGAIN_ALBUM_PEAK"], mp4Freeform: ["REPLAYGAIN_ALBUM_PEAK"]),
        schema(.itunesAlbumID, "iTunes Album ID", .itunes, ["ITUNESALBUMID"], id3User: ["ITUNESALBUMID"], mp4Freeform: ["ITUNESALBUMID"]),
        schema(.itunesArtistID, "iTunes Artist ID", .itunes, ["ITUNESARTISTID"], id3User: ["ITUNESARTISTID"], mp4Freeform: ["ITUNESARTISTID"]),
        schema(.itunesCatalogID, "iTunes Catalog ID", .itunes, ["ITUNESCATALOGID"], id3User: ["ITUNESCATALOGID"], mp4Freeform: ["ITUNESCATALOGID"]),
        schema(.itunesGenreID, "iTunes Genre ID", .itunes, ["ITUNESGENREID"], id3User: ["ITUNESGENREID"], mp4Freeform: ["ITUNESGENREID"]),
        schema(.itunesMediaType, "iTunes Media Type", .itunes, ["ITUNESMEDIATYPE"], id3User: ["ITUNESMEDIATYPE"], mp4Freeform: ["ITUNESMEDIATYPE"]),
        schema(.itunesPurchaseDate, "iTunes Purchase Date", .itunes, ["ITUNESPURCHASEDATE"], id3User: ["ITUNESPURCHASEDATE"], mp4Freeform: ["ITUNESPURCHASEDATE"]),
        schema(.itunesNorm, "iTunNORM", .itunes, ["ITUNNORM"], id3User: ["ITUNNORM"], mp4Freeform: ["ITUNNORM"]),
        schema(.itunesSMPB, "iTunSMPB", .itunes, ["ITUNSMPB"], id3User: ["ITUNSMPB"], mp4Freeform: ["ITUNSMPB"]),
        schema(.originalAlbum, "Original Album", .release, ["ORIGINALALBUM"], id3: ["TOAL"], mp4Freeform: ["ORIGINALALBUM"]),
        schema(.originalArtist, "Original Artist", .people, ["ORIGINALARTIST"], id3: ["TOPE"], mp4Freeform: ["ORIGINALARTIST"], multi: true, people: true),
        schema(.artistType, "Artist Type", .release, ["MUSICBRAINZ_ARTISTTYPE", "ARTISTTYPE", "MUSICBRAINZ ARTIST TYPE"], id3User: ["ARTISTTYPE"], mp4Freeform: ["ARTISTTYPE"]),
        schema(.trackerName, "Tracker Name", .technical, ["TRACKERNAME"]),
        schema(.director, "Director", .people, ["DIRECTOR"], multi: true, people: true),
        schema(.itunesAccount, "iTunes Account", .itunes, ["ITUNESACCOUNT"]),
        schema(.itunesComposerID, "iTunes Composer ID", .itunes, ["ITUNESCOMPOSERID"]),
        schema(.itunesCountryID, "iTunes Storefront ID", .itunes, ["ITUNESCOUNTRYID"]),
        schema(.itunesGapless, "Gapless Playback", .itunes, ["ITUNESGAPLESS", "GAPLESSPLAYBACK"]),
        schema(.itunesHDVideo, "HD Video", .itunes, ["ITUNESHDVIDEO", "HDVIDEO"]),
        schema(.itunesOwner, "Owner", .itunes, ["ITUNESOWNER", "OWNER"], semantic: "OWNER"),
        schema(.rate, "Rating", .itunes, ["RATE"]),
        schema(.showMovement, "Show Work and Movement", .itunes, ["SHOWMOVEMENT", "SHOWWORKMOVEMENT"]),
        schema(.storeDescription, "Store Description", .itunes, ["STOREDESCRIPTION"]),
        schema(.tvEpisode, "TV Episode", .itunes, ["TVEPISODE"]),
        schema(.tvEpisodeID, "TV Episode ID", .itunes, ["TVEPISODEID"]),
        schema(.tvNetwork, "TV Network", .itunes, ["TVNETWORK"]),
        schema(.tvSeason, "TV Season", .itunes, ["TVSEASON"]),
        schema(.tvShow, "TV Show", .itunes, ["TVSHOW"]),
        schema(.tvShowSort, "TV Show Sort", .itunes, ["TVSHOWSORT", "SHOWSORT"], semantic: "SHOWSORT"),
        MetadataFieldSchema(
            key: .custom,
            displayName: "Custom Field",
            category: .custom,
            semanticKey: "<explicit key>",
            propertyMapKeys: [],
            nativeTargets: MetadataMappingCatalog.profile(forSemanticKey: "<explicit key>")?.targets ?? [],
            isMultiValue: true
        ),
    ]

    public nonisolated static let schemasByKey: [MetadataFieldKey: MetadataFieldSchema] =
        Dictionary(uniqueKeysWithValues: allSchemas.map { ($0.key, $0) })

    /// One preferred semantic owner for each semantic key. Legacy API aliases
    /// such as `.date` remain addressable but are excluded here.
    public nonisolated static let canonicalSchemas: [MetadataFieldSchema] =
        allSchemas.filter(\.isCanonicalSemanticOwner)

    public nonisolated static let schemasBySemanticKey: [String: MetadataFieldSchema] =
        Dictionary(uniqueKeysWithValues: canonicalSchemas.map { ($0.semanticKey, $0) })

    public nonisolated static let canonicalPropertyMapKeys: Set<String> =
        Set(allSchemas.flatMap(\.propertyMapKeys).map(normalizePropertyMapKey))

    public nonisolated static let multiValuePropertyMapKeys: Set<String> =
        Set(allSchemas.filter(\.isMultiValue).flatMap(\.propertyMapKeys).map(normalizePropertyMapKey))

    public nonisolated static let peoplePropertyMapKeys: Set<String> =
        Set(allSchemas.filter(\.isPeopleField).flatMap(\.propertyMapKeys).map(normalizePropertyMapKey))

    /// Property-map keys with intentionally composite semantic ownership.
    /// YEAR/DATE are owned by both the canonical `.year` identity and the
    /// deprecated `.date` spelling; `.year` is the explicit preferred owner.
    public nonisolated static let sharedPropertyMapKeyOwners: [String: Set<MetadataFieldKey>] = [
        "DATE": [.date, .year],
        "YEAR": [.date, .year],
    ]

    /// The explicit owner used by scalar lookup when a storage key is shared.
    public nonisolated static let preferredSharedPropertyMapKeyOwner: [String: MetadataFieldKey] = [
        "DATE": .year,
        "YEAR": .year,
    ]

    public nonisolated static let propertyMapKeyOwners: [String: Set<MetadataFieldKey>] = {
        var result: [String: Set<MetadataFieldKey>] = [:]
        for schema in allSchemas {
            for key in schema.propertyMapKeys {
                result[normalizePropertyMapKey(key), default: []].insert(schema.key)
            }
        }
        return result
    }()

    public nonisolated static func schema(for key: MetadataFieldKey) -> MetadataFieldSchema? {
        schemasByKey[key]
    }

    public nonisolated static func canonicalSchema(forSemanticKey key: String) -> MetadataFieldSchema? {
        schemasBySemanticKey[key.uppercased()]
    }

    public nonisolated static func schema(forPropertyMapKey key: String) -> MetadataFieldSchema? {
        let normalized = normalizePropertyMapKey(key)
        let qualifiedPrefixes: [(String, MetadataFieldKey)] = [
            ("PERFORMER:", .performer),
            ("INVOLVEDPEOPLE:", .involvedPeople),
            ("MUSICIANCREDITS:", .musicianCredits),
            ("COMMENT:", .comment),
            ("LYRICS:", .lyrics),
        ]
        for (prefix, owner) in qualifiedPrefixes where normalized.hasPrefix(prefix) {
            return schemasByKey[owner]
        }
        guard let owners = propertyMapKeyOwners[normalized] else { return nil }
        let owner = owners.count == 1 ? owners.first : preferredSharedPropertyMapKeyOwner[normalized]
        return owner.flatMap { schemasByKey[$0] }
    }

    nonisolated static func schema(forHighLevelCustomKey key: String) -> MetadataFieldSchema? {
        let normalized = normalizePropertyMapKey(key)
        let prefixes = ["----:COM.APPLE.ITUNES:", "TXXX:"]
        let candidate = prefixes.first(where: normalized.hasPrefix).map {
            String(normalized.dropFirst($0.count))
        } ?? normalized
        return schema(forPropertyMapKey: candidate)
    }

    public nonisolated static func schemas(withMappingsFor format: MetadataFieldFormat) -> [MetadataFieldSchema] {
        allSchemas.filter { schema in
            schema.mappings.contains { $0.format == format }
        }
    }

    public nonisolated static func schemas(storableIn capability: FormatCapability) -> [MetadataFieldSchema] {
        guard capability.isWritable else { return [] }
        return canonicalSchemas.filter { schema in
            if let writableFields = capability.writableFields, !writableFields.contains(schema.key) {
                return false
            }
            if schema.isArtworkField, !capability.canWriteArtwork {
                return false
            }
            return capability.metadataFieldFormats.contains { format in
                schema.capability(for: format).isWritable
            }
        }
    }

    public nonisolated static func schema(_ key: MetadataFieldKey, hasMappingFor format: MetadataFieldFormat) -> Bool {
        guard let schema = schema(for: key) else { return false }
        return schema.capability(for: format) != .unsupported
    }

    public nonisolated static func shouldDisplayRawPropertyAsMultiValue(_ key: String) -> Bool {
        let normalized = normalizePropertyMapKey(key)
        let qualifiedPrefixes = [
            "PERFORMER:", "INVOLVEDPEOPLE:", "MUSICIANCREDITS:", "COMMENT:", "LYRICS:"
        ]
        return qualifiedPrefixes.contains(where: normalized.hasPrefix)
            || multiValuePropertyMapKeys.contains(normalized)
    }

    public nonisolated static func normalizePropertyMapKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// Independent writable fields must not own one native slot twice. The two
    /// components of a numeric pair legitimately share `TRCK`/`trkn`, so they
    /// are grouped by shared semantic pair rather than reported as collisions.
    public nonisolated static let duplicatePreferredWriteTargets: [String: [MetadataFieldKey]] = {
        var owners: [String: [MetadataFieldKey]] = [:]
        for schema in allSchemas where schema.key != .custom {
            for target in schema.nativeTargets where target.preferredWrite {
                let component = target.numberComponent?.rawValue ?? "-"
                let identity = "\(target.family.rawValue)|\(target.nativeIdentity)|\(component)"
                owners[identity, default: []].append(schema.key)
            }
        }
        return owners.filter { entry in
            guard entry.value.count > 1 else { return false }
            let schemas = entry.value.compactMap { schemasByKey[$0] }
            // Role-qualified performer/musician/involved collections share one
            // native role frame by contract; they are components of a shared
            // collection, not independent writable slots.
            if schemas.allSatisfy(\.isRoleQualified) { return false }
            return Set(schemas.map(\.semanticKey)).count > 1
        }
    }()

    private nonisolated static let semanticKeyOverrides: [MetadataFieldKey: String] = [
        .date: "YEAR",
        .year: "YEAR",
        .standaloneDate: "DATE",
        .publisher: "LABEL",
        .encoderSettings: "ENCODING",
        .mediaType: "MEDIA",
        .movement: "MOVEMENTNAME",
        .explicitContent: "ITUNESADVISORY",
        .itunesOwner: "OWNER",
        .tvShowSort: "SHOWSORT",
        .custom: "<explicit key>",
    ]

    private nonisolated static func semanticKey(
        for key: MetadataFieldKey,
        propertyKeys: [String]
    ) -> String {
        if let override = semanticKeyOverrides[key] { return override }
        return (propertyKeys.first ?? key.rawValue).uppercased()
    }

    private nonisolated static func schema(
        _ key: MetadataFieldKey,
        _ name: String,
        _ category: MetadataFieldCategory,
        _ propertyKeys: [String],
        semantic: String? = nil,
        id3: [String] = [],
        id3User: [String] = [],
        mp4: [String] = [],
        mp4Freeform: [String] = [],
        multi: Bool = false,
        people: Bool = false,
        role: Bool = false,
        legacyYearAlias: Bool = false
    ) -> MetadataFieldSchema {
        // Native identity is owned by the generated catalog; the legacy
        // id3/mp4 arguments remain only as descriptive call-site hints.
        _ = (id3, id3User, mp4, mp4Freeform)
        let semanticKey = semantic ?? semanticKey(for: key, propertyKeys: propertyKeys)
        let profile = MetadataMappingCatalog.profile(forSemanticKey: semanticKey)
        return MetadataFieldSchema(
            key: key,
            displayName: name,
            category: category,
            semanticKey: semanticKey,
            propertyMapKeys: propertyKeys,
            nativeTargets: profile?.targets ?? [],
            isCanonicalSemanticOwner: !legacyYearAlias,
            isLegacyYearAlias: legacyYearAlias,
            isMultiValue: multi,
            isPeopleField: people,
            isRoleQualified: role,
            writeUnsupportedReason: profile?.writeUnsupportedReason
        )
    }
}
