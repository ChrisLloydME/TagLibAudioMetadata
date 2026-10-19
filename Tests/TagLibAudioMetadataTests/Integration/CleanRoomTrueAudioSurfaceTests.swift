import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

struct CleanRoomTrueAudioSurfaceTests {
    @Test func unmodeledAPEv2SurfaceRejectsWritesAndPreservesOriginal() throws {
        try HardeningFixture.withCopy("tta", name: "testAudioFile") { url in
            let originalAudio = try Data(contentsOf: url)
            try HardeningFixture.writeAPE(audio: originalAudio,
                items: ["Title": .init(flags: 0, value: Data("APEv2 title".utf8))], to: url)
            let original = try Data(contentsOf: url)
            #expect(try HardeningFixture.apeState(original).items["TITLE"] != nil)
            for operation in 0..<7 {
                #expect(throws: (any Error).self) {
                    switch operation {
                    case 0:
                        try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "New" }
                    case 1:
                        try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("New")]), to: url)
                    case 2:
                        try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(7)]), to: url)
                    case 3:
                        try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                            ["TITLE": ["New"]], to: url, verifyAfterWrite: false)
                    case 4:
                        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                            .init(id3v2Frames: [.init(frameID: "TIT2", type: "text", value: "New")]),
                            to: url, verifyAfterWrite: false)
                    case 5:
                        try TagLibMetadataExtractor.writeTrackNumber(7, totalTracks: 12, padWidth: 2, to: url)
                    default:
                        try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url)
                    }
                }
                #expect(try Data(contentsOf: url) == original)
            }
        }
    }
}
