import Foundation
import Testing
import TagLibAudioMetadata

struct CleanRoomLimitationTests {
    @Test func emptyURLAndUFIDRejectRatherThanPretendToRemove() throws {
        try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(StructuredMetadata(id3v2Frames: [
                .init(frameID: "WOAR", type: "url", url: "https://example.com/artist"),
                .init(frameID: "UFID", type: "ufid", owner: "example.com", data: Data([1, 2]))
            ]), to: url)
            let original = try Data(contentsOf: url)
            for frame in [StructuredID3v2Frame(frameID: "WOAR", type: "url", url: ""),
                          .init(frameID: "UFID", type: "ufid", owner: "example.com", data: Data())] {
                for verify in [true, false] {
                    #expect(throws: TagLibManagerError.self) {
                        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                            StructuredMetadata(id3v2Frames: [frame]), to: url, verifyAfterWrite: verify)
                    }
                    #expect(try Data(contentsOf: url) == original)
                }
            }
        }
    }

    @Test func genericNumberTextPreservesThePairWithDocumentedDisplayNormalization() throws {
        for ext in ["flac", "ogg"] {
            try HardeningFixture.withCopy(ext, name: "testAudioFile") { url in
                try TagLibMetadataManager.writeTrackNumberText("03/10", discNumberText: "01/02", to: url)
                let basic = try TagLibMetadataManager.readMetadataResult(from: url)
                #expect(basic.track == 3 && basic.trackTotal == 10)
                #expect(basic.disc == 1 && basic.discTotal == 2)
                #expect(basic.trackNumberText == "03" && basic.discNumberText == "01")
                let raw = try TagLibMetadataManager.rawMetadataResult(from: url)
                #expect(raw.properties.first { $0.key == "TRACKTOTAL" }?.values == ["10"])
                #expect(raw.properties.first { $0.key == "DISCTOTAL" }?.values == ["2"])
            }
        }
    }

    @Test func multiValueDisplaySeparatorsFollowTheActualProjection() throws {
        for ext in ["mp3", "m4a", "flac"] {
            try HardeningFixture.withCopy(ext, name: "testAudioFile") { url in
                try TagLibMetadataManager.applyRawMetadataPatch(
                    RawMetadataPatch(valuesToSet: ["ARTIST": ["Alpha", "Beta"]]), to: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).artist ==
                    (ext == "mp3" ? "Alpha, Beta" : "Alpha; Beta"))
                #expect(try TagLibMetadataManager.rawMetadataResult(from: url).properties.first { $0.key == "ARTIST" }?.values == ["Alpha", "Beta"])
            }
        }
    }
}
