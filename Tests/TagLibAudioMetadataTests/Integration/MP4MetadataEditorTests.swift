import Foundation
import TagLibAudioMetadata
import Testing

struct MP4MetadataEditorTests {
    @Test func editsProviderWrittenAtomsAndSeparateTextInOneTransaction() throws {
        try ContractFixture.withCopy("m4a") { url in
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [
                    .itunesAlbumID: .integer(6_829_122_413),
                    .itunesArtistID: .integer(479_756_766),
                    .itunesCatalogID: .integer(6_829_122_414),
                ], explicitAdvisory: .notExplicit),
                to: url
            )
            let legacy = "----:com.apple.iTunes:ITUNESALBUMID"
            try TagLibMetadataManager.applyRawMetadataPatch(
                RawMetadataPatch(valuesToSet: ["ITUNESALBUMID": ["42"], "EDITOR_NOTE": ["One", "Two"]]),
                to: url
            )
            let original = try ContractMP4Oracle.read(url)
            var evidence = ContractCase(
                scenario: "S-MP4-EDITOR-01",
                runtimeTest: "editsProviderWrittenAtomsAndSeparateTextInOneTransaction",
                adapter: "facade.applyMP4EditorPatch"
            )
            evidence.check("seed.album", try original.integer("plID") == 6_829_122_413)
            evidence.check("seed.catalog", try original.integer("cnID") == 6_829_122_414)
            evidence.check("seed.advisory", try original.integer("rtng") == 0)
            evidence.check("seed.albumAlias", try original.text(legacy) == "42")
            var snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            let rows = Dictionary(uniqueKeysWithValues: snapshot.editableMP4Fields.map { ($0.field, $0) })
            #expect(rows[.itunesAlbumID]?.atomKey == "plID")
            evidence.check("projection.album", rows[.itunesAlbumID]?.atom?.value == "6829122413")
            #expect(rows[.itunesArtistID]?.atom?.value == "479756766")
            #expect(rows[.itunesCatalogID]?.atom?.value == "6829122414")
            #expect(rows[.explicitContent]?.atom?.value == "0")
            #expect(snapshot.raw.properties.first { $0.key == "ITUNESALBUMID" }?.values == ["42"])
            #expect(!snapshot.raw.properties.contains { $0.key == "ITUNESCATALOGID" })

            let result = try PublicSurfaceAdapters.invoke(.facadeApplyMP4EditorPatch, url: url, input:
                .mp4EditorPatch([
                    .itunesAlbumID: .integer(6_829_122_415),
                    .itunesArtistID: .integer(Int(UInt32.max)),
                    .itunesCatalogID: .remove,
                ], RawMetadataPatch(valuesToSet: ["EDITOR_NOTE": ["New", "New"]]),
                    expectedVersion: try #require(snapshot.fileVersion)))
            if case .write = result { evidence.check("write.returned", true) }
            else { evidence.check("write.returned", false) }
            let edited = try ContractMP4Oracle.read(url)
            evidence.check("native.album", try edited.integer("plID") == 6_829_122_415)
            #expect(edited.values["plID"]?.first?.count == 8)
            #expect(try edited.integer("atID") == Int(UInt32.max))
            #expect(edited.values["atID"]?.first?.count == 4)
            evidence.check("native.catalog.absent", edited.items["cnID"] == nil)
            evidence.check("legacy.albumAlias.preserved", edited.items[legacy] == original.items[legacy])
            evidence.check("native.advisory.preserved", edited.items["rtng"] == original.items["rtng"])
            evidence.check("audio.unchanged", edited.audio == original.audio)

            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            evidence.check("raw.note", snapshot.raw.properties.first { $0.key == "EDITOR_NOTE" }?.values == ["New", "New"])
            try evidence.finish()
            let catalog = try #require(snapshot.editableMP4Fields.first { $0.field == .itunesCatalogID })
            #expect(catalog.atomKey == "cnID")
            #expect(catalog.atom == nil)
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [.itunesAlbumID: .remove, .itunesCatalogID: .integer(6_829_122_414), .explicitContent: .remove],
                raw: RawMetadataPatch(removingKeys: ["EDITOR_NOTE"]),
                to: url,
                expectedVersion: try #require(snapshot.fileVersion)
            )
            let cleared = try ContractMP4Oracle.read(url)
            #expect(cleared.items["plID"] == nil)
            #expect(cleared.items["rtng"] == nil)
            #expect(try cleared.integer("cnID") == 6_829_122_414)
            #expect(cleared.values["cnID"]?.first?.count == 8)
            #expect(try cleared.text(legacy) == "42")
            #expect(cleared.items["----:com.apple.iTunes:EDITOR_NOTE"] == nil)
            #expect(cleared.items["----:com.apple.iTunes:ITUNESCATALOGID"] == nil)
        }
    }

    @Test func preservesLegacyAdvisoryUntilAnExactNativeEdit() throws {
        try ContractFixture.withCopy("m4a") { url in
            let legacy = "----:com.apple.iTunes:ITUNESADVISORY"
            try ContractMP4Seed.seed([
                .init(key: "rtng", value: .integer(4, byteCount: 1)),
                .init(key: legacy, value: .text("1")),
            ], to: url)
            let before = try ContractMP4Oracle.read(url)
            #expect(try before.integer("rtng") == 4)
            #expect(try before.text(legacy) == "1")
            var snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(snapshot.editableMP4Fields.first { $0.field == .explicitContent }?.atom?.value == "4")
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [:], raw: RawMetadataPatch(valuesToSet: ["ITUNESADVISORY": ["2"]]),
                to: url, expectedVersion: try #require(snapshot.fileVersion)
            )
            let rawOnly = try ContractMP4Oracle.read(url)
            #expect(rawOnly.items["rtng"] == before.items["rtng"])
            #expect(try rawOnly.text(legacy) == "2")
            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [.explicitContent: .integer(0)],
                raw: RawMetadataPatch(removingKeys: ["ITUNESADVISORY"]),
                to: url, expectedVersion: try #require(snapshot.fileVersion)
            )
            let edited = try ContractMP4Oracle.read(url)
            #expect(try edited.integer("rtng") == 0)
            #expect(edited.values["rtng"]?.first?.count == 1)
            #expect(edited.items[legacy] == nil)
        }
    }

    @Test func rejectsInvalidAndStaleChangesWithoutPartialWrites() throws {
        try ContractFixture.withCopy("m4a") { url in
            let version = try TagLibMetadataManager.fileVersion(at: url)
            let before = try ContractFixture.bytes(url)
            let raw = RawMetadataPatch(valuesToSet: ["TITLE": ["Must not save"]])
            let invalidEdits: [(MetadataFieldKey, Int, Int)] = [
                (.itunesArtistID, Int(UInt32.max) + 1, Int(UInt32.max)), (.explicitContent, 4, 2),
            ]
            for (field, value, maximum) in invalidEdits {
                #expect(throws: MetadataPatchValidationError.integerOutOfRange(
                    field: field, minimum: 0, maximum: maximum, actual: value
                )) {
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [field: .integer(value)], raw: raw, to: url, expectedVersion: version
                    )
                }
                #expect(try ContractFixture.bytes(url) == before)
            }
            do {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.itunesAlbumID: .integer(6_829_122_413)],
                    raw: RawMetadataPatch(valuesToSet: ["TRACKNUMBER": ["01/02"]]),
                    to: url, expectedVersion: version
                )
                Issue.record("A normalized raw value must fail exact verification.")
            } catch TagLibManagerError.verificationFailed(let mismatches) {
                #expect(mismatches.contains { $0.contains("TRACKNUMBER") })
            }
            #expect(try ContractFixture.bytes(url) == before)

            try ContractFixture.withCopy("flac") { flacURL in
                let baseline = try TagLibMetadataManager.readSnapshot(from: flacURL, includingAudioContent: true)
                let audioIdentity = try #require(baseline.audioContentIdentity)
                #expect(throws: MetadataAudioContentError.unavailable) {
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [.itunesAlbumID: .integer(1)], raw: raw, to: url,
                        expectedVersion: version, expectedAudioContent: audioIdentity
                    )
                }
            }
            #expect(try ContractFixture.bytes(url) == before)

            try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields: [.title: .text("New revision")]), to: url)
            let after = try ContractFixture.bytes(url)
            do {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.itunesAlbumID: .integer(1)], raw: raw, to: url, expectedVersion: version
                )
                Issue.record("A stale editor version must be rejected.")
            } catch TagLibManagerError.fileChanged {}
            #expect(try ContractFixture.bytes(url) == after)
        }
    }

    @Test func offersNativeRowsOnlyForMP4Files() throws {
        try ContractFixture.withCopy("flac") { url in
            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(snapshot.editableMP4Fields.isEmpty)
            do {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.itunesAlbumID: .integer(1)], to: url, expectedVersion: try #require(snapshot.fileVersion)
                )
                Issue.record("The MP4 editor operation requires an MP4 file.")
            } catch TagLibManagerError.unsupportedFormat {}
        }
    }
}
