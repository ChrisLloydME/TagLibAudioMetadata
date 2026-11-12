import Foundation
import Testing
import TagLibAudioMetadata

/// Literal test expectations, frozen independently of the runtime registry.
/// Do not regenerate these from production schemas to make a mismatch pass.
struct SemanticLifecycleMatrixTests {
    enum Kind: Equatable, Sendable { case text, integer, boolean }
    struct Case: Sendable {
        let field: MetadataFieldKey
        let atom: String
        let kind: Kind
        init(_ field: MetadataFieldKey, _ atom: String, _ kind: Kind = .text) {
            self.field = field; self.atom = atom; self.kind = kind
        }
        func value(_ replacement: Bool) -> MetadataPatchValue {
            switch kind {
            case .integer: return .integer(replacement ? 2 : 1)
            case .boolean: return .boolean(replacement)
            case .text:
                if [.year, .standaloneDate, .releaseDate, .originalReleaseDate].contains(field) {
                    return .text(replacement ? "2018-07-10" : "2017-06-09")
                }
                if field == .itunesPurchaseDate { return .text(replacement ? "2018-07-10T10:00:00Z" : "2017-06-09T10:00:00Z") }
                return .text(replacement ? "Replacement" : "First")
            }
        }
    }
    static let cases: [Case] = [
        .init(.title, "©nam"),
        .init(.comment, "©cmt"),
        .init(.lyrics, "©lyr"),
        .init(.album, "©alb"),
        .init(.genre, "©gen"),
        .init(.work, "©wrk"),
        .init(.movement, "©mvn"),
        .init(.discSubtitle, "----:com.apple.iTunes:DISCSUBTITLE"),
        .init(.subtitle, "----:com.apple.iTunes:SUBTITLE"),
        .init(.grouping, "----:com.apple.iTunes:GROUPING"),
        .init(.contentGroup, "©grp"),
        .init(.mood, "----:com.apple.iTunes:MOOD"),
        .init(.language, "----:com.apple.iTunes:LANGUAGE"),
        .init(.musicalKey, "----:com.apple.iTunes:INITIALKEY"),
        .init(.movementNumber, "©mvi", .integer),
        .init(.movementCount, "©mvc", .integer),
        .init(.year, "©day"),
        .init(.standaloneDate, "----:com.apple.iTunes:DATE"),
        .init(.releaseDate, "----:com.apple.iTunes:RELEASEDATE"),
        .init(.originalReleaseDate, "----:com.apple.iTunes:ORIGINALDATE"),
        .init(.artist, "©ART"),
        .init(.albumArtist, "aART"),
        .init(.composer, "©wrt"),
        .init(.conductor, "©con"),
        .init(.remixer, "----:com.apple.iTunes:REMIXER"),
        .init(.producer, "----:com.apple.iTunes:PRODUCER"),
        .init(.engineer, "----:com.apple.iTunes:ENGINEER"),
        .init(.lyricist, "----:com.apple.iTunes:LYRICIST"),
        .init(.artists, "----:com.apple.iTunes:ARTISTS"),
        .init(.originalArtist, "----:com.apple.iTunes:ORIGINALARTIST"),
        .init(.director, "©dir"),
        .init(.sortTitle, "sonm"),
        .init(.sortArtist, "soar"),
        .init(.sortAlbum, "soal"),
        .init(.sortAlbumArtist, "soaa"),
        .init(.sortComposer, "soco"),
        .init(.isrc, "----:com.apple.iTunes:ISRC"),
        .init(.barcode, "----:com.apple.iTunes:BARCODE"),
        .init(.asin, "----:com.apple.iTunes:ASIN"),
        .init(.musicBrainzArtistID, "----:com.apple.iTunes:MusicBrainz Artist Id"),
        .init(.musicBrainzAlbumID, "----:com.apple.iTunes:MusicBrainz Album Id"),
        .init(.musicBrainzAlbumArtistID, "----:com.apple.iTunes:MusicBrainz Album Artist Id"),
        .init(.musicBrainzTrackID, "----:com.apple.iTunes:MusicBrainz Track Id"),
        .init(.musicBrainzReleaseGroupID, "----:com.apple.iTunes:MusicBrainz Release Group Id"),
        .init(.musicBrainzReleaseTrackID, "----:com.apple.iTunes:MusicBrainz Release Track Id"),
        .init(.musicBrainzWorkID, "----:com.apple.iTunes:MusicBrainz Work Id"),
        .init(.acoustID, "----:com.apple.iTunes:Acoustid Id"),
        .init(.acoustIDFingerprint, "----:com.apple.iTunes:Acoustid Fingerprint"),
        .init(.musicIPPUID, "----:com.apple.iTunes:MusicIP PUID"),
        .init(.publisher, "©pub"),
        .init(.copyright, "cprt"),
        .init(.catalogNumber, "----:com.apple.iTunes:CATALOGNUMBER"),
        .init(.releaseType, "----:com.apple.iTunes:MusicBrainz Album Type"),
        .init(.releaseStatus, "----:com.apple.iTunes:MusicBrainz Album Status"),
        .init(.releaseCountry, "----:com.apple.iTunes:MusicBrainz Album Release Country"),
        .init(.mediaType, "----:com.apple.iTunes:MEDIA"),
        .init(.compilation, "cpil", .boolean),
        .init(.originalAlbum, "----:com.apple.iTunes:ORIGINALALBUM"),
        .init(.artistType, "----:com.apple.iTunes:MusicBrainz Artist Type"),
        .init(.encodedBy, "©enc"),
        .init(.encoderSettings, "©too"),
        .init(.bpm, "tmpo", .integer),
        .init(.replayGainTrackGain, "----:com.apple.iTunes:REPLAYGAIN_TRACK_GAIN"),
        .init(.replayGainAlbumGain, "----:com.apple.iTunes:REPLAYGAIN_ALBUM_GAIN"),
        .init(.replayGainTrackPeak, "----:com.apple.iTunes:REPLAYGAIN_TRACK_PEAK"),
        .init(.replayGainAlbumPeak, "----:com.apple.iTunes:REPLAYGAIN_ALBUM_PEAK"),
        .init(.itunesAlbumID, "plID", .integer),
        .init(.itunesArtistID, "atID", .integer),
        .init(.itunesCatalogID, "cnID", .integer),
        .init(.itunesGenreID, "geID", .integer),
        .init(.itunesMediaType, "stik", .integer),
        .init(.itunesPurchaseDate, "purd"),
        .init(.itunesNorm, "----:com.apple.iTunes:iTunNORM"),
        .init(.itunesSMPB, "----:com.apple.iTunes:iTunSMPB"),
        .init(.itunesAccount, "apID"),
        .init(.itunesComposerID, "cmID", .integer),
        .init(.itunesCountryID, "sfID", .integer),
        .init(.itunesGapless, "pgap", .boolean),
        .init(.itunesHDVideo, "hdvd", .boolean),
        .init(.itunesOwner, "ownr"),
        .init(.showMovement, "shwm", .boolean),
        .init(.storeDescription, "sdes"),
        .init(.tvEpisode, "tves", .integer),
        .init(.tvEpisodeID, "tven"),
        .init(.tvNetwork, "tvnn"),
        .init(.tvSeason, "tvsn", .integer),
        .init(.tvShow, "tvsh"),
        .init(.tvShowSort, "sosn"),
    ]
    // Specialized API/codec decisions are explicit, not silently omitted.
    static let specialized: [MetadataFieldKey: String] = [
        .trackerName: "No MP4 target; format-specific tracker metadata remains outside MP4 lifecycle",
        .artwork: "Separate artwork patch; CleanRoomArtworkTests",
        .custom: "Separate customFields patch; RawMetadataPatchTests",
        .performer: "Role-qualified typed rejection; raw/structured API required",
        .involvedPeople: "Role-qualified typed rejection; raw/structured API required",
        .musicianCredits: "Role-qualified typed rejection; raw/structured API required",
        .rate: "Registered read-only; typed writes must reject",
        .explicitContent: "Separate explicitAdvisory patch; MP4ContentGroupVerificationTests/MP4ExclusiveFieldTests",
        .track: "Shared pair; NumberingRepairRegressionTests",
        .trackTotal: "Shared pair; NumberingRepairRegressionTests",
        .disc: "Shared pair; NumberingRepairRegressionTests",
        .discTotal: "Shared pair; NumberingRepairRegressionTests",
    ]

    @Test func everyFieldRequiresAnExplicitCoverageDecision() {
        let matrix = Set(Self.cases.map(\.field))
        #expect(matrix.count == Self.cases.count)
        #expect(matrix.isDisjoint(with: Self.specialized.keys))
        #expect(matrix.union(Self.specialized.keys) == Set(MetadataFieldKey.allCases))
        #expect(Self.specialized.values.allSatisfy { !$0.isEmpty })
    }

    @Test(arguments: [MetadataFieldKey.performer, .involvedPeople, .musicianCredits, .rate, .trackerName])
    func unavailableTypedMP4WritesRejectBeforeMutation(_ field: MetadataFieldKey) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            let before = try Data(contentsOf: url)
            #expect(throws: MetadataPatchValidationError.self) {
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [field: .text("First")]), to: url)
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    enum Operation: String, CaseIterable, Sendable { case set, replace, remove }

    @Test(arguments: cases, Operation.allCases)
    func mp4LifecycleHasNativeOwnerAndPreservesSiblings(_ item: Case, _ operation: Operation) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["X-MATRIX-KEEP": ["A; B", "duplicate", "duplicate", "  padded  "]]), to: url)
            let initial = item.value(false)
            let type: String = switch item.kind { case .text: "stringList"; case .integer: "uint"; case .boolean: "bool" }
            let seed: StructuredMP4Atom
            switch initial {
            case .text(let value): seed = .init(key: item.atom, type: type, values: [value], remove: operation == .set)
            case .integer(let value): seed = .init(key: item.atom, type: type, value: String(value), remove: operation == .set)
            case .boolean(let value): seed = .init(key: item.atom, type: type, value: value ? "1" : "0", remove: operation == .set)
            default: throw CocoaError(.coderInvalidValue)
            }
            // Setup uses the structured/native path. A broken semantic Set
            // must not prevent Replace and Remove from being exercised.
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [seed]), to: url)
            let before = try IndependentMP4Probe.read(url)
            let requested: MetadataPatchValue = switch operation {
            case .set: item.value(false)
            case .replace: item.value(true)
            case .remove: .remove
            }
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: requested]), to: url)
            let after = try IndependentMP4Probe.read(url)
            try after.expectValue(requested, at: item.atom)
            #expect(after.audio == before.audio)
            #expect(after.items.filter { $0.key != item.atom } == before.items.filter { $0.key != item.atom },
                    "Unedited native atoms changed for \(item.field), \(operation)")
        }
    }

    @Test(arguments: cases)
    func wrongValueKindCannotPartiallyCommitAnotherField(_ item: Case) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            let bytes = try Data(contentsOf: url)
            let invalid: MetadataPatchValue = item.kind == .text ? .boolean(true) : .text("not-a-number")
            var fields: [MetadataFieldKey: MetadataPatchValue] = [.comment: .text("Must not commit")]
            fields[item.field] = invalid
            #expect(throws: MetadataPatchValidationError.self) {
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: fields), to: url)
            }
            #expect(try Data(contentsOf: url) == bytes)
        }
    }
}
