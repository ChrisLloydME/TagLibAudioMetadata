import Foundation
import Testing
import TagLibAudioMetadata

struct MP4ExclusiveFieldTests {
    private func copy(_ ext: String) throws -> URL {
        let source = try #require(
            Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext)
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    private func atom(_ snapshot: MetadataSnapshot, _ key: String) -> StructuredMP4Atom? {
        snapshot.structured.mp4Atoms.first { $0.key == key }
    }

    @Test func integerStoreAndEpisodeFieldsRoundTripAndRemove() throws {
        struct Case {
            let field: MetadataFieldKey
            let key: String
            let value: Int
            let legacy: String?
        }
        let cases = [
            Case(field: .itunesAlbumID, key: "plID", value: 1_234_567_890, legacy: nil),
            Case(field: .itunesArtistID, key: "atID", value: 42, legacy: nil),
            Case(field: .itunesCatalogID, key: "cnID", value: 765_432_109, legacy: nil),
            Case(field: .itunesGenreID, key: "geID", value: 6007, legacy: nil),
            Case(field: .itunesComposerID, key: "cmID", value: 9001, legacy: nil),
            Case(field: .itunesCountryID, key: "sfID", value: 143_441, legacy: nil),
            Case(field: .itunesMediaType, key: "stik", value: 9, legacy: nil),
            Case(field: .tvEpisode, key: "tves", value: 7, legacy: nil),
            Case(field: .tvSeason, key: "tvsn", value: 0, legacy: nil),
        ]
        for test in cases {
            let url = try copy("m4a")
            defer { try? FileManager.default.removeItem(at: url) }
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [test.field: .integer(test.value)]),
                to: url
            )
            var snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            let written = try #require(atom(snapshot, test.key))
            #expect(["uint", "int", "byte", "longLong"].contains(written.type), Comment(rawValue: test.field.rawValue))
            #expect(Int(written.value) == test.value, Comment(rawValue: test.field.rawValue))
            switch test.field {
            case .itunesAlbumID: #expect(snapshot.basic.itunesAlbumID == String(test.value))
            case .itunesArtistID: #expect(snapshot.basic.itunesArtistID == String(test.value))
            case .itunesCatalogID: #expect(snapshot.basic.itunesCatalogID == String(test.value))
            case .itunesGenreID: #expect(snapshot.basic.itunesGenreID == String(test.value))
            case .itunesComposerID: #expect(snapshot.basic.itunesComposerID == String(test.value))
            case .itunesCountryID: #expect(snapshot.basic.itunesCountryID == String(test.value))
            case .itunesMediaType: #expect(snapshot.basic.itunesMediaType == String(test.value))
            case .tvEpisode: #expect(snapshot.basic.tvEpisode == test.value)
            case .tvSeason: #expect(snapshot.basic.tvSeason == test.value)
            default: break
            }

            // An unrelated Title edit preserves the present value, including
            // the zero season and the media-kind code.
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.title: .text("Unrelated")]),
                to: url
            )
            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(Int(atom(snapshot, test.key)?.value ?? "") == test.value, Comment(rawValue: test.field.rawValue))

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [test.field: .remove]),
                to: url
            )
            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(atom(snapshot, test.key) == nil, Comment(rawValue: test.field.rawValue))
        }
    }

    @Test func booleanMP4FieldsPreservePresentFalseAndDistinguishRemoval() throws {
        struct Case {
            let field: MetadataFieldKey
            let key: String
        }
        let cases = [
            Case(field: .itunesGapless, key: "pgap"),
            Case(field: .itunesHDVideo, key: "hdvd"),
            Case(field: .showMovement, key: "shwm"),
        ]
        for test in cases {
            let url = try copy("m4a")
            defer { try? FileManager.default.removeItem(at: url) }
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [test.field: .boolean(false)]),
                to: url
            )
            var snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            let presentFalse = try #require(atom(snapshot, test.key))
            #expect(["0", "false"].contains(presentFalse.value.lowercased()))

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.title: .text("Unrelated")]),
                to: url
            )
            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(atom(snapshot, test.key) != nil, Comment(rawValue: test.field.rawValue))

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [test.field: .boolean(true)]),
                to: url
            )
            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(["1", "true"].contains(atom(snapshot, test.key)?.value.lowercased() ?? ""))

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [test.field: .remove]),
                to: url
            )
            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(atom(snapshot, test.key) == nil, Comment(rawValue: test.field.rawValue))
        }
    }

    @Test func textMP4FieldsRoundTripIndependentlyFromCommentAndMedia() throws {
        struct Case {
            let field: MetadataFieldKey
            let key: String
            let value: String
            let basicPath: KeyPath<BasicMetadata, String>
        }
        let cases = [
            Case(field: .director, key: "\u{00A9}dir", value: "Director One", basicPath: \.director),
            Case(field: .itunesAccount, key: "apID", value: "account@example.invalid", basicPath: \.itunesAccount),
            Case(field: .itunesOwner, key: "ownr", value: "Owner Name", basicPath: \.itunesOwner),
            Case(field: .storeDescription, key: "sdes", value: "Store description text", basicPath: \.storeDescription),
            Case(field: .itunesPurchaseDate, key: "purd", value: "2019-01-02 03:04:05", basicPath: \.itunesPurchaseDate),
            Case(field: .tvEpisodeID, key: "tven", value: "S01E007", basicPath: \.tvEpisodeID),
            Case(field: .tvNetwork, key: "tvnn", value: "Network", basicPath: \.tvNetwork),
            Case(field: .tvShow, key: "tvsh", value: "Show Title", basicPath: \.tvShow),
            Case(field: .tvShowSort, key: "sosn", value: "Show Sort", basicPath: \.tvShowSort),
        ]
        for test in cases {
            let url = try copy("m4a")
            defer { try? FileManager.default.removeItem(at: url) }
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [test.field: .text(test.value)]),
                to: url
            )
            var snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(atom(snapshot, test.key)?.values == [test.value], Comment(rawValue: test.field.rawValue))
            #expect(snapshot.basic[keyPath: test.basicPath] == test.value)
            #expect(snapshot.basic.comment.isEmpty)

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.title: .text("Unrelated")]),
                to: url
            )
            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(atom(snapshot, test.key)?.values == [test.value], Comment(rawValue: test.field.rawValue))

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [test.field: .remove]),
                to: url
            )
            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(atom(snapshot, test.key) == nil, Comment(rawValue: test.field.rawValue))
        }
    }

    @Test func mediaKindUnknownCodeIsPreservedAndRateWriteIsRefused() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(mp4Atoms: [.init(key: "stik", type: "uint", value: "250")]),
            to: url
        )
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.title: .text("Unrelated")]),
            to: url
        )
        let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
        #expect(snapshot.structured.mp4Atoms.first { $0.key == "stik" }?.value == "250")
        #expect(snapshot.basic.itunesMediaType == "250")

        let original = try Data(contentsOf: url)
        #expect(throws: (any Error).self) {
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.rate: .integer(5)]),
                to: url
            )
        }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func advisoryFourStatesUseExactNativeCodesAndPreserveUnknown() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        for (state, code) in [
            (ExplicitAdvisory.notExplicit, "0"),
            (.explicit, "1"),
            (.clean, "2"),
        ] {
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(explicitAdvisory: state),
                to: url
            )
            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            let rating = try #require(snapshot.structured.mp4Atoms.first { $0.key == "rtng" })
            #expect(Int(rating.value) == Int(code))
            #expect(snapshot.basic.explicitAdvisory == state)
        }
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(explicitAdvisory: .unspecified),
            to: url
        )
        #expect(try TagLibMetadataManager.readSnapshot(from: url).structured.mp4Atoms.first { $0.key == "rtng" } == nil)

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(mp4Atoms: [.init(key: "rtng", type: "int", value: "4")]),
            to: url
        )
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.title: .text("Title only")]),
            to: url
        )
        let preserved = try TagLibMetadataManager.readSnapshot(from: url)
        #expect(preserved.structured.mp4Atoms.first { $0.key == "rtng" }?.value == "4")
        #expect(preserved.basic.explicitAdvisory == .unspecified)
        #expect(preserved.basic.explicitAdvisoryRawValue == "4")
    }

    @Test func advisoryPresentZeroIsDistinctFromAbsentOnTextExtension() throws {
        let url = try copy("flac")
        defer { try? FileManager.default.removeItem(at: url) }
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(explicitAdvisory: .notExplicit),
            to: url
        )
        #expect(try TagLibMetadataManager.rawMetadataResult(from: url).properties.first {
            $0.key.uppercased() == "ITUNESADVISORY"
        }?.values == ["0"])
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(explicitAdvisory: .unspecified),
            to: url
        )
        #expect(try TagLibMetadataManager.rawMetadataResult(from: url).properties.first {
            $0.key.uppercased() == "ITUNESADVISORY"
        } == nil)
    }
}
