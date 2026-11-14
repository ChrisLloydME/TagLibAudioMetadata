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
    /// All built-in entries are canonical after alias removal. Custom schema
    /// descriptions may still mark an alias with false.
    public var isCanonicalSemanticOwner: Bool
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
        schema(.title, "Title", .basic, ["TITLE"]),
        schema(.artist, "Artist", .people, ["ARTIST"], multi: true, people: true),
        schema(.album, "Album", .basic, ["ALBUM"]),
        schema(.albumArtist, "Album Artist", .people, ["ALBUMARTIST", "ALBUM ARTIST"], multi: true, people: true),
        schema(.year, "Year", .dates, ["YEAR", "DATE"], semantic: "YEAR"),
        schema(.standaloneDate, "Date", .dates, ["STANDALONEDATE"], semantic: "DATE"),
        schema(.releaseDate, "Release Date", .dates, ["RELEASEDATE"]),
        schema(.originalReleaseDate, "Original Release Date", .dates, ["ORIGINALDATE", "ORIGINAL YEAR"]),
        schema(.track, "Track Number", .numbering, ["TRACKNUMBER", "TRACK"]),
        schema(.trackTotal, "Track Total", .numbering, ["TRACKTOTAL", "TOTALTRACKS"]),
        schema(.disc, "Disc Number", .numbering, ["DISCNUMBER", "DISC"]),
        schema(.discTotal, "Disc Total", .numbering, ["DISCTOTAL", "TOTALDISCS"]),
        MetadataFieldSchema(
            key: .artwork,
            displayName: "Artwork",
            category: .artwork,
            semanticKey: "PICTURE",
            propertyMapKeys: ["PICTURE"],
            nativeTargets: MetadataMappingCatalog.profile(forSemanticKey: "PICTURE")?.targets ?? [],
            isArtworkField: true
        ),
        schema(.lyrics, "Lyrics", .lyricsAndComments, ["LYRICS"]),
        schema(.comment, "Comment", .lyricsAndComments, ["COMMENT"]),
        schema(.genre, "Genre", .basic, ["GENRE"], multi: true),
        schema(.composer, "Composer", .people, ["COMPOSER"], multi: true, people: true),
        schema(.conductor, "Conductor", .people, ["CONDUCTOR"], multi: true, people: true),
        schema(.remixer, "Remixer", .people, ["REMIXER"], multi: true, people: true),
        schema(.performer, "Performer", .peopleRoles, ["PERFORMER"], multi: true, people: true, role: true),
        schema(.producer, "Producer", .people, ["PRODUCER"], multi: true, people: true),
        schema(.engineer, "Engineer", .people, ["ENGINEER"], multi: true, people: true),
        schema(.lyricist, "Lyricist", .people, ["LYRICIST"], multi: true, people: true),
        schema(.involvedPeople, "Involved People", .peopleRoles, ["INVOLVEDPEOPLE"], multi: true, people: true, role: true),
        schema(.musicianCredits, "Musician Credits", .peopleRoles, ["MUSICIANCREDITS"], multi: true, people: true, role: true),
        schema(.publisher, "Publisher", .release, ["LABEL", "PUBLISHER"]),
        schema(.copyright, "Copyright", .release, ["COPYRIGHT"]),
        schema(.encodedBy, "Encoded By", .technical, ["ENCODEDBY"]),
        schema(.encoderSettings, "Encoder Settings", .technical, ["ENCODING", "ENCODERSETTINGS"]),
        schema(.isrc, "ISRC", .identifiers, ["ISRC"]),
        schema(.barcode, "Barcode", .identifiers, ["BARCODE", "UPC", "EAN"]),
        schema(.catalogNumber, "Catalog Number", .release, ["CATALOGNUMBER", "CATALOG NUMBER", "CATALOG"]),
        schema(.asin, "ASIN", .identifiers, ["ASIN"]),
        schema(.releaseType, "Release Type", .release, ["RELEASETYPE", "MUSICBRAINZ_ALBUMTYPE", "MUSICBRAINZ ALBUM TYPE"]),
        schema(.releaseStatus, "Release Status", .release, ["RELEASESTATUS", "MUSICBRAINZ_ALBUMSTATUS", "MUSICBRAINZ ALBUM STATUS"]),
        schema(.releaseCountry, "Release Country", .release, ["RELEASECOUNTRY", "MUSICBRAINZ_ALBUMRELEASECOUNTRY", "MUSICBRAINZ ALBUM RELEASE COUNTRY"]),
        schema(.mediaType, "Media Type", .release, ["MEDIATYPE", "MEDIA", "MEDIA TYPE"]),
        schema(.work, "Work", .basic, ["WORK"]),
        schema(.movement, "Movement", .basic, ["MOVEMENT", "MOVEMENTNAME"]),
        schema(.movementNumber, "Movement Number", .numbering, ["MOVEMENTNUMBER"]),
        schema(.movementCount, "Movement Count", .numbering, ["MOVEMENTCOUNT"]),
        schema(.discSubtitle, "Disc Subtitle", .basic, ["DISCSUBTITLE"]),
        schema(.subtitle, "Subtitle", .basic, ["SUBTITLE"]),
        schema(.grouping, "Grouping", .basic, ["GROUPING"], multi: true),
        schema(.contentGroup, "Content Group", .basic, ["CONTENTGROUP"]),
        schema(.artists, "Artists", .people, ["ARTISTS"], multi: true, people: true),
        schema(.mood, "Mood", .basic, ["MOOD"], multi: true),
        schema(.language, "Language", .basic, ["LANGUAGE"], multi: true),
        schema(.musicalKey, "Musical Key", .basic, ["INITIALKEY", "KEY"]),
        schema(.bpm, "BPM", .technical, ["BPM"]),
        schema(.compilation, "Compilation", .release, ["COMPILATION"]),
        schema(.explicitContent, "Explicit Content", .itunes, ["ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT"]),
        schema(.sortTitle, "Sort Title", .sorting, ["TITLESORT"]),
        schema(.sortArtist, "Sort Artist", .sorting, ["ARTISTSORT"]),
        schema(.sortAlbum, "Sort Album", .sorting, ["ALBUMSORT"]),
        schema(.sortAlbumArtist, "Sort Album Artist", .sorting, ["ALBUMARTISTSORT"]),
        schema(.sortComposer, "Sort Composer", .sorting, ["COMPOSERSORT"]),
        schema(.musicBrainzArtistID, "MusicBrainz Artist ID", .identifiers, ["MUSICBRAINZ_ARTISTID", "MUSICBRAINZ ARTISTID", "MUSICBRAINZ ARTIST ID"]),
        schema(.musicBrainzAlbumID, "MusicBrainz Album ID", .identifiers, ["MUSICBRAINZ_ALBUMID", "MUSICBRAINZ ALBUMID", "MUSICBRAINZ ALBUM ID"]),
        schema(.musicBrainzAlbumArtistID, "MusicBrainz Album Artist ID", .identifiers, ["MUSICBRAINZ_ALBUMARTISTID", "MUSICBRAINZ ALBUMARTISTID", "MUSICBRAINZ ALBUM ARTIST ID"]),
        schema(.musicBrainzTrackID, "MusicBrainz Track ID", .identifiers, ["MUSICBRAINZ_TRACKID", "MUSICBRAINZ TRACKID", "MUSICBRAINZ TRACK ID"]),
        schema(.musicBrainzReleaseGroupID, "MusicBrainz Release Group ID", .identifiers, ["MUSICBRAINZ_RELEASEGROUPID", "MUSICBRAINZ RELEASEGROUPID", "MUSICBRAINZ RELEASE GROUP ID"]),
        schema(.musicBrainzReleaseTrackID, "MusicBrainz Release Track ID", .identifiers, ["MUSICBRAINZ_RELEASETRACKID", "MUSICBRAINZ RELEASETRACKID", "MUSICBRAINZ RELEASE TRACK ID"]),
        schema(.musicBrainzWorkID, "MusicBrainz Work ID", .identifiers, ["MUSICBRAINZ_WORKID", "MUSICBRAINZ WORKID", "MUSICBRAINZ WORK ID"]),
        schema(.acoustID, "AcoustID", .identifiers, ["ACOUSTID_ID", "ACOUSTID ID"]),
        schema(.acoustIDFingerprint, "AcoustID Fingerprint", .identifiers, ["ACOUSTID_FINGERPRINT", "ACOUSTID FINGERPRINT"]),
        schema(.musicIPPUID, "MusicIP PUID", .identifiers, ["MUSICIP_PUID", "MUSICIP PUID"]),
        schema(.replayGainTrackGain, "ReplayGain Track Gain", .replayGain, ["REPLAYGAIN_TRACK_GAIN"]),
        schema(.replayGainAlbumGain, "ReplayGain Album Gain", .replayGain, ["REPLAYGAIN_ALBUM_GAIN"]),
        schema(.replayGainTrackPeak, "ReplayGain Track Peak", .replayGain, ["REPLAYGAIN_TRACK_PEAK"]),
        schema(.replayGainAlbumPeak, "ReplayGain Album Peak", .replayGain, ["REPLAYGAIN_ALBUM_PEAK"]),
        schema(.itunesAlbumID, "iTunes Album ID", .itunes, ["ITUNESALBUMID"]),
        schema(.itunesArtistID, "iTunes Artist ID", .itunes, ["ITUNESARTISTID"]),
        schema(.itunesCatalogID, "iTunes Catalog ID", .itunes, ["ITUNESCATALOGID"]),
        schema(.itunesGenreID, "iTunes Genre ID", .itunes, ["ITUNESGENREID"]),
        schema(.itunesMediaType, "iTunes Media Type", .itunes, ["ITUNESMEDIATYPE"]),
        schema(.itunesPurchaseDate, "iTunes Purchase Date", .itunes, ["ITUNESPURCHASEDATE"]),
        schema(.itunesNorm, "iTunNORM", .itunes, ["ITUNNORM"]),
        schema(.itunesSMPB, "iTunSMPB", .itunes, ["ITUNSMPB"]),
        schema(.originalAlbum, "Original Album", .release, ["ORIGINALALBUM"]),
        schema(.originalArtist, "Original Artist", .people, ["ORIGINALARTIST"], multi: true, people: true),
        schema(.artistType, "Artist Type", .release, ["MUSICBRAINZ_ARTISTTYPE", "ARTISTTYPE", "MUSICBRAINZ ARTIST TYPE"]),
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

    /// One semantic owner for each semantic key; there are no YEAR aliases.
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

    /// No public semantic fields currently share a PropertyMap key.
    /// Engine DATE projects YEAR; independent DATE uses STANDALONEDATE.
    public nonisolated static let sharedPropertyMapKeyOwners: [String: Set<MetadataFieldKey>] = [:]

    public nonisolated static let preferredSharedPropertyMapKeyOwner: [String: MetadataFieldKey] = [:]

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
        multi: Bool = false,
        people: Bool = false,
        role: Bool = false
    ) -> MetadataFieldSchema {
        // Native identities are declared only in MetadataMappingCatalog.
        let semanticKey = semantic ?? semanticKey(for: key, propertyKeys: propertyKeys)
        let profile = MetadataMappingCatalog.profile(forSemanticKey: semanticKey)
        return MetadataFieldSchema(
            key: key,
            displayName: name,
            category: category,
            semanticKey: semanticKey,
            propertyMapKeys: propertyKeys,
            nativeTargets: profile?.targets ?? [],
            isMultiValue: multi,
            isPeopleField: people,
            isRoleQualified: role,
            writeUnsupportedReason: profile?.writeUnsupportedReason
        )
    }
}
