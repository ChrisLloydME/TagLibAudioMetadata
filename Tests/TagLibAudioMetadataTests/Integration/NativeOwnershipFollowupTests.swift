import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridgeInternalAPI

struct NativeOwnershipFollowupTests {
    @Test func combinedTrackAndMovementEditPreservesOtherMovementComponent() throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "©mvi", type: "uint", value: "3"),
                .init(key: "©mvc", type: "uint", value: "12")
            ]), to: url)
            let before = try IndependentMP4Probe.read(url)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(4), .movementNumber: .integer(5)]), to: url)
            let after = try IndependentMP4Probe.read(url)
            try after.expectValue(.integer(5), at: "©mvi")
            #expect(after.items["©mvc"] == before.items["©mvc"])
            #expect(after.items["----:com.apple.iTunes:MOVEMENTNUMBER"] == nil)
            #expect(after.items["----:com.apple.iTunes:MOVEMENTCOUNT"] == nil)
        }
    }

    @Test func basicAndLowLevelMovementWritersUseCanonicalIntegers() throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            var basic = try TagLibMetadataManager.readMetadataResult(from: url)
            basic.movementNumber = 2
            basic.movementCount = 7
            try TagLibMetadataManager.replaceBasicMetadata(basic, to: url)
            var probe = try IndependentMP4Probe.read(url)
            try probe.expectValue(.integer(2), at: "©mvi")
            try probe.expectValue(.integer(7), at: "©mvc")
            try TagLibMetadataExtractor.writeNumberPairsInPlace(trackNumber: 0, totalTracks: 0, updateTrackPair: false,
                discNumber: 0, totalDiscs: 0, updateDiscPair: false, movementNumber: 3, movementCount: 8,
                updateMovementPair: true, to: url)
            probe = try IndependentMP4Probe.read(url)
            try probe.expectValue(.integer(3), at: "©mvi")
            try probe.expectValue(.integer(8), at: "©mvc")
            #expect(probe.items["----:com.apple.iTunes:MOVEMENTNUMBER"] == nil)
            #expect(probe.items["----:com.apple.iTunes:MOVEMENTCOUNT"] == nil)
        }
    }

    @Test(arguments: [0, 255, 256, 32767])
    func nativeMovementIntegerBoundariesRoundTrip(_ value: Int) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.movementNumber: .integer(value), .movementCount: .integer(value)]), to: url)
            let probe = try IndependentMP4Probe.read(url)
            try probe.expectValue(.integer(value), at: "©mvi")
            try probe.expectValue(.integer(value), at: "©mvc")
            let basic = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(basic.movementNumber == value)
            #expect(basic.movementCount == value)
        }
    }

    @Test(arguments: [32768, 65535, 65536, Int(Int32.max)])
    func unrepresentableNativeMovementRejectsWithoutPartialCommit(_ value: Int) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            let before = try Data(contentsOf: url)
            #expect(throws: MetadataPatchValidationError.self) {
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("Must not commit"), .movementNumber: .integer(value)]), to: url)
            }
            var basic = try TagLibMetadataManager.readMetadataResult(from: url)
            basic.movementCount = value
            #expect(throws: MetadataPatchValidationError.self) { try TagLibMetadataManager.replaceBasicMetadata(basic, to: url) }
            #expect(throws: (any Error).self) {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [.init(key: "©mvi", type: "uint", value: String(value))]), to: url)
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test func encoderOwnersDoNotConsumeEachOthersLegacyStorage() throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "©enc", type: "stringList", values: ["Person"]),
                .init(key: "©too", type: "stringList", values: [], remove: true),
                .init(key: "----:com.apple.iTunes:ENCODING", type: "stringList", values: ["Settings", "second"])
            ]), to: url)
            let original = try IndependentMP4Probe.read(url)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.encodedBy: .remove]), to: url)
            let after = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(after.encodedBy.isEmpty)
            #expect(after.encoderSettings == "Settings; second")
            #expect(try IndependentMP4Probe.read(url).items["----:com.apple.iTunes:ENCODING"] == original.items["----:com.apple.iTunes:ENCODING"])
        }
    }

    @Test func id3ContentGroupPreservesIndependentGroupingAndWork() throws {
        try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
            let audio = try IndependentID3Probe.read(url).audio
            let frames = HardeningFixture.frame("GRP1", Data([3]) + Data("Keep grouping".utf8))
                + HardeningFixture.frame("TXXX", Data([3]) + Data("WORK\0Keep work".utf8))
            try (HardeningFixture.id3(frames) + audio).write(to: url)
            for value in [MetadataPatchValue.text("Group"), .text("Replacement"), .remove] {
                let before = try IndependentID3Probe.read(url)
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.contentGroup: value]), to: url)
                let after = try IndependentID3Probe.read(url)
                #expect(after.frames["GRP1"] == before.frames["GRP1"])
                #expect(after.frames["TXXX:WORK"] == before.frames["TXXX:WORK"])
                let basic = try TagLibMetadataManager.readMetadataResult(from: url)
                #expect(basic.grouping == "Keep grouping")
                #expect(basic.work == "Keep work")
            }
        }
    }
}
