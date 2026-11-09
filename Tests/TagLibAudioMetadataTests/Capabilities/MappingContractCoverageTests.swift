import Foundation
import Testing
import TagLibAudioMetadata

struct MappingContractCoverageTests {
    /// The complete 8.1 MP4-exclusive list, bound to its canonical semantic
    /// key and preferred native atom/identity.
    private let mp4Exclusive: [(MetadataFieldKey, String)] = [
        (.director, "\u{00A9}dir"),
        (.itunesAccount, "apID"),
        (.explicitContent, "rtng"),
        (.itunesAlbumID, "plID"),
        (.itunesArtistID, "atID"),
        (.itunesCatalogID, "cnID"),
        (.itunesComposerID, "cmID"),
        (.itunesCountryID, "sfID"),
        (.itunesGapless, "pgap"),
        (.itunesGenreID, "geID"),
        (.itunesHDVideo, "hdvd"),
        (.itunesMediaType, "stik"),
        (.itunesOwner, "ownr"),
        (.itunesPurchaseDate, "purd"),
        (.rate, "rate"),
        (.showMovement, "shwm"),
        (.storeDescription, "sdes"),
        (.discTotal, "disk"),
        (.trackTotal, "trkn"),
        (.tvEpisode, "tves"),
        (.tvEpisodeID, "tven"),
        (.tvNetwork, "tvnn"),
        (.tvSeason, "tvsn"),
        (.tvShow, "tvsh"),
        (.tvShowSort, "sosn"),
        (.work, "\u{00A9}wrk"),
    ]

    @Test func allTwentySixMP4ExclusiveEntriesAreRegisteredWithExactAtoms() throws {
        #expect(mp4Exclusive.count == 26)
        for (field, atom) in mp4Exclusive {
            let schema = try #require(MetadataFieldRegistry.schema(for: field), Comment(rawValue: field.rawValue))
            let target = try #require(schema.targets(for: .mp4).first, Comment(rawValue: field.rawValue))
            #expect(target.nativeIdentity == atom, Comment(rawValue: field.rawValue))
        }
    }

    @Test func rateIsTheOnlyMP4ExclusiveReadOnlyEntry() throws {
        for (field, _) in mp4Exclusive {
            let schema = try #require(MetadataFieldRegistry.schema(for: field), Comment(rawValue: field.rawValue))
            if field == .rate {
                #expect(schema.writeTarget(for: .mp4) == nil)
                #expect(schema.capability(for: MetadataNativeFamily.mp4) == .readOnly)
                #expect(schema.writeUnsupportedReason?.isEmpty == false)
            } else {
                #expect(schema.writeTarget(for: .mp4) != nil, Comment(rawValue: field.rawValue))
                #expect(
                    schema.capability(for: MetadataNativeFamily.mp4).isWritable,
                    Comment(rawValue: field.rawValue)
                )
            }
        }
    }

    @Test func totalComponentsUseTheNativePairWithoutPrivateDuplicates() throws {
        let track = try #require(MetadataFieldRegistry.schema(for: .trackTotal))
        let disc = try #require(MetadataFieldRegistry.schema(for: .discTotal))
        let trackTarget = try #require(track.writeTarget(for: .mp4))
        let discTarget = try #require(disc.writeTarget(for: .mp4))

        #expect(trackTarget.nativeIdentity == "trkn")
        #expect(trackTarget.numberComponent == .total)
        #expect(discTarget.nativeIdentity == "disk")
        #expect(discTarget.numberComponent == .total)
        #expect(!track.nativeTargets.contains { $0.nativeIdentity.uppercased().contains("TOTALTRACKS") })
        #expect(!disc.nativeTargets.contains { $0.nativeIdentity.uppercased().contains("TOTALDISCS") })
    }

    @Test func yearAndDateRepresentationsAreMutuallyExclusive() throws {
        let source = try #require(
            Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a", subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a")
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        try FileManager.default.copyItem(at: source, to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = try Data(contentsOf: url)

        #expect(throws: MetadataPatchValidationError.self) {
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [
                    .date: .text("2021"),
                    .year: .text("2021"),
                ]),
                to: url
            )
        }
        #expect(try Data(contentsOf: url) == original)

        let year = try #require(MetadataFieldRegistry.schema(for: .year))
        let legacy = try #require(MetadataFieldRegistry.schema(for: .date))
        #expect(year.isCanonicalSemanticOwner)
        #expect(!legacy.isCanonicalSemanticOwner)
        #expect(year.semanticKey == legacy.semanticKey)
        #expect(MetadataFieldRegistry.canonicalSchema(forSemanticKey: "YEAR")?.key == .year)
    }

    @Test func everyFieldHasOneSchemaAndOneCanonicalSemanticOwner() {
        #expect(MetadataFieldRegistry.allSchemas.count == MetadataFieldKey.allCases.count)
        #expect(MetadataFieldRegistry.canonicalSchemas.count == MetadataFieldKey.allCases.count - 1)
        #expect(MetadataMappingCatalog.semanticKeys.count == 100)
        #expect(
            Set(MetadataFieldRegistry.canonicalSchemas.map(\.semanticKey)).count
                == MetadataFieldRegistry.canonicalSchemas.count
        )
        for key in MetadataFieldKey.allCases {
            #expect(MetadataFieldRegistry.schema(for: key)?.key == key)
        }
    }
}
