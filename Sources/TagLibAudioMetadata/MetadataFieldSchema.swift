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
    case flac
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
    case binary
    case pattern
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
    case custom
}

public struct MetadataFieldSchema: Identifiable, Hashable, Sendable {
    public var id: MetadataFieldKey { key }
    public var key: MetadataFieldKey
    public var displayName: String
    public var category: MetadataFieldCategory
    public var propertyMapKeys: [String]
    public var mappings: [MetadataFormatMapping]
    public var isMultiValue: Bool
    public var isPeopleField: Bool
    public var isRoleQualified: Bool
    public var isArtworkField: Bool

    public init(
        key: MetadataFieldKey,
        displayName: String,
        category: MetadataFieldCategory,
        propertyMapKeys: [String],
        mappings: [MetadataFormatMapping] = [],
        isMultiValue: Bool = false,
        isPeopleField: Bool = false,
        isRoleQualified: Bool = false,
        isArtworkField: Bool = false
    ) {
        self.key = key
        self.displayName = displayName
        self.category = category
        self.propertyMapKeys = propertyMapKeys
        self.mappings = mappings
        self.isMultiValue = isMultiValue
        self.isPeopleField = isPeopleField
        self.isRoleQualified = isRoleQualified
        self.isArtworkField = isArtworkField
    }
}

public enum MetadataFieldRegistry {
    public nonisolated static let allSchemas: [MetadataFieldSchema] = [
        schema(.title, "Title", .basic, ["TITLE"], id3: ["TIT2"], mp4: ["\u{00A9}nam"]),
        schema(.artist, "Artist", .people, ["ARTIST", "ARTISTS"], id3: ["TPE1"], mp4: ["\u{00A9}ART"], multi: true, people: true),
        schema(.album, "Album", .basic, ["ALBUM"], id3: ["TALB"], mp4: ["\u{00A9}alb"]),
        schema(.albumArtist, "Album Artist", .people, ["ALBUMARTIST", "ALBUM ARTIST"], id3: ["TPE2"], mp4: ["aART"], multi: true, people: true),
        schema(.date, "Date", .dates, ["DATE", "YEAR"], id3: ["TDRC", "TYER"], mp4: ["\u{00A9}day"]),
        schema(.releaseDate, "Release Date", .dates, ["RELEASEDATE", "DATE"], id3: ["TDRC", "TDRL"], mp4: ["\u{00A9}day"]),
        schema(.originalReleaseDate, "Original Release Date", .dates, ["ORIGINALDATE", "ORIGINAL YEAR"], id3: ["TDOR"], mp4Freeform: ["ORIGINAL YEAR"]),
        schema(.track, "Track Number", .numbering, ["TRACKNUMBER", "TRACK"], id3: ["TRCK"], mp4: ["trkn"]),
        schema(.trackTotal, "Track Total", .numbering, ["TRACKTOTAL", "TOTALTRACKS"], id3: ["TRCK"], mp4: ["trkn"]),
        schema(.disc, "Disc Number", .numbering, ["DISCNUMBER", "DISC"], id3: ["TPOS"], mp4: ["disk"]),
        schema(.discTotal, "Disc Total", .numbering, ["DISCTOTAL", "TOTALDISCS"], id3: ["TPOS"], mp4: ["disk"]),
        MetadataFieldSchema(
            key: .artwork,
            displayName: "Artwork",
            category: .artwork,
            propertyMapKeys: ["PICTURE"],
            mappings: [
                .init(format: .id3v2, storageKind: .binary, keys: ["APIC"]),
                .init(format: .mp4, storageKind: .binary, keys: ["covr"]),
                .init(format: .flac, storageKind: .complexProperty, keys: ["PICTURE"]),
                .init(format: .xiph, storageKind: .complexProperty, keys: ["PICTURE"]),
                .init(format: .asf, storageKind: .complexProperty, keys: ["PICTURE", "WM/Picture"]),
            ],
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
        schema(.movementCount, "Movement Count", .numbering, ["MOVEMENTCOUNT"], id3: ["MVC"], mp4Freeform: ["MOVEMENTCOUNT"]),
        schema(.discSubtitle, "Disc Subtitle", .basic, ["DISCSUBTITLE"], id3: ["TSST"], mp4Freeform: ["DISCSUBTITLE"]),
        schema(.subtitle, "Subtitle", .basic, ["SUBTITLE"], id3: ["TIT3"], mp4Freeform: ["SUBTITLE"]),
        schema(.grouping, "Grouping", .basic, ["GROUPING"], id3: ["TIT1"], mp4: ["\u{00A9}grp"], multi: true),
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
        schema(.musicIPPUID, "MusicIP PUID", .identifiers, ["MUSICIP_PUID"], id3User: ["MusicIP PUID"], mp4Freeform: ["MusicIP PUID"]),
        schema(.replayGainTrackGain, "ReplayGain Track Gain", .replayGain, ["REPLAYGAIN_TRACK_GAIN"], id3User: ["REPLAYGAIN_TRACK_GAIN"], mp4Freeform: ["REPLAYGAIN_TRACK_GAIN"]),
        schema(.replayGainAlbumGain, "ReplayGain Album Gain", .replayGain, ["REPLAYGAIN_ALBUM_GAIN"], id3User: ["REPLAYGAIN_ALBUM_GAIN"], mp4Freeform: ["REPLAYGAIN_ALBUM_GAIN"]),
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
        schema(.artistType, "Artist Type", .release, ["ARTISTTYPE", "MUSICBRAINZ_ARTISTTYPE", "MUSICBRAINZ ARTIST TYPE"], id3User: ["ARTISTTYPE"], mp4Freeform: ["ARTISTTYPE"]),
        MetadataFieldSchema(
            key: .custom,
            displayName: "Custom Field",
            category: .custom,
            propertyMapKeys: [],
            mappings: [
                .init(format: .id3v2, storageKind: .userTextFrame, keys: ["TXXX:<description>"]),
                .init(format: .mp4, storageKind: .mp4Freeform, keys: ["----:com.apple.iTunes:<description>"]),
                .init(format: .tagLibPropertyMap, storageKind: .propertyMap, keys: ["<property key>"]),
            ]
        ),
    ]

    public nonisolated static let schemasByKey: [MetadataFieldKey: MetadataFieldSchema] =
        Dictionary(uniqueKeysWithValues: allSchemas.map { ($0.key, $0) })

    public nonisolated static let canonicalPropertyMapKeys: Set<String> =
        Set(allSchemas.flatMap(\.propertyMapKeys).map(normalizePropertyMapKey))

    public nonisolated static let multiValuePropertyMapKeys: Set<String> =
        Set(allSchemas.filter(\.isMultiValue).flatMap(\.propertyMapKeys).map(normalizePropertyMapKey))

    public nonisolated static let peoplePropertyMapKeys: Set<String> =
        Set(allSchemas.filter(\.isPeopleField).flatMap(\.propertyMapKeys).map(normalizePropertyMapKey))

    public nonisolated static func schema(for key: MetadataFieldKey) -> MetadataFieldSchema? {
        schemasByKey[key]
    }

    public nonisolated static func schema(forPropertyMapKey key: String) -> MetadataFieldSchema? {
        let normalized = normalizePropertyMapKey(key)
        if normalized.hasPrefix("PERFORMER:") {
            return schemasByKey[.performer]
        }
        return allSchemas.first { schema in
            schema.propertyMapKeys.map(normalizePropertyMapKey).contains(normalized)
        }
    }

    public nonisolated static func shouldDisplayRawPropertyAsMultiValue(_ key: String) -> Bool {
        let normalized = normalizePropertyMapKey(key)
        return normalized.hasPrefix("PERFORMER:")
            || multiValuePropertyMapKeys.contains(normalized)
    }

    public nonisolated static func normalizePropertyMapKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private nonisolated static func schema(
        _ key: MetadataFieldKey,
        _ name: String,
        _ category: MetadataFieldCategory,
        _ propertyKeys: [String],
        id3: [String] = [],
        id3User: [String] = [],
        mp4: [String] = [],
        mp4Freeform: [String] = [],
        multi: Bool = false,
        people: Bool = false,
        role: Bool = false
    ) -> MetadataFieldSchema {
        var mappings: [MetadataFormatMapping] = [
            .init(format: .tagLibPropertyMap, storageKind: .propertyMap, keys: propertyKeys),
            .init(format: .xiph, storageKind: .propertyMap, keys: propertyKeys),
            .init(format: .ape, storageKind: .propertyMap, keys: propertyKeys),
            .init(format: .asf, storageKind: .propertyMap, keys: propertyKeys),
        ]
        if !id3.isEmpty {
            mappings.append(.init(format: .id3v2, storageKind: .textFrame, keys: id3))
        }
        if !id3User.isEmpty {
            mappings.append(.init(format: .id3v2, storageKind: .userTextFrame, keys: id3User))
        }
        if !mp4.isEmpty {
            mappings.append(.init(format: .mp4, storageKind: .mp4Atom, keys: mp4))
        }
        if !mp4Freeform.isEmpty {
            mappings.append(.init(format: .mp4, storageKind: .mp4Freeform, keys: mp4Freeform.map { "----:com.apple.iTunes:\($0)" }))
        }
        return MetadataFieldSchema(
            key: key,
            displayName: name,
            category: category,
            propertyMapKeys: propertyKeys,
            mappings: mappings,
            isMultiValue: multi,
            isPeopleField: people,
            isRoleQualified: role
        )
    }
}
