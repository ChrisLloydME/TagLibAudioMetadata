import Foundation
import Testing

/// Self-tests for the test-owned builders and native oracles. These run before
/// any native matrix is trusted: a boundary vector, chunk bound, flag, grouping
/// byte or integer encoding failure is a test failure, never a skipped seed.
struct ContractBuilderOracleSelfTests {
    @Test func synchsafeBoundariesAndLiteralVectors() throws {
        let cases: [(Int, [UInt8])] = [
            (0, [0, 0, 0, 0]),
            (127, [0, 0, 0, 127]),
            (128, [0, 0, 1, 0]),
            (255, [0, 0, 1, 127]),
            (16_383, [0, 0, 127, 127]),
            (16_384, [0, 1, 0, 0]),
            (2_097_151, [0, 127, 127, 127]),
        ]
        for (value, bytes) in cases {
            let encoded = try ContractFixture.synchsafe(value)
            #expect(Array(encoded) == bytes, "synchsafe \(value)")
            #expect(try ContractFixture.readSynchsafe(encoded, 0) == value)
        }
        #expect(throws: (any Error).self) { _ = try ContractFixture.synchsafe(0x1000_0000) }
        #expect(throws: (any Error).self) {
            _ = try ContractFixture.readSynchsafe(Data([0, 0, 0x80, 0]), 0)
        }
    }

    @Test func id3FrameSizesAndVersionLayouts() throws {
        let payload = Data(repeating: 0x41, count: 128)
        let v23 = ContractID3Seed.frame("TIT2", payload)
        #expect(Array(v23[4..<8]) == [0, 0, 0, 128], "v2.3 frame sizes are plain 32-bit")
        let v24 = try ContractID3Seed.v24Frame("TIT2", payload)
        #expect(Array(v24[4..<8]) == [0, 0, 1, 0], "v2.4 frame sizes are synchsafe")
        let tag23 = try ContractID3Seed.tag(v23, version: 3)
        let parsed = try ContractID3Oracle.parse(tag23, audio: Data([1, 2, 3]))
        #expect(parsed.version == 3)
        #expect(parsed.frames.first?.payload.count == 128)
        #expect(parsed.audio == Data([1, 2, 3]))
    }

    @Test func id3FlagsGroupingAndTagFlagsRoundTrip() throws {
        try ContractFixture.withCopy("mp3") { url in
            let audioBefore = try ContractID3Oracle.read(url).audio
            let frames = ContractID3Seed.frame("TYER", ContractID3Seed.text("TYER", "2004"),
                                               status: 0x20, format: 0x20, groupID: 7)
                + ContractID3Seed.frame("TDAT", ContractID3Seed.text("TDAT", "0906"),
                                        status: 0, format: 0, groupID: nil)
            try ContractID3Seed.seedMP3(url, tag: try ContractID3Seed.tag(frames, version: 3, tagFlags: 0x40))
            let native = try ContractID3Oracle.read(url)
            #expect(native.version == 3)
            #expect(native.tagFlags == 0x40)
            #expect(native.frame("TYER")?.status == 0x20)
            #expect(native.frame("TYER")?.format == 0x20)
            #expect(native.frame("TYER")?.groupID == 7)
            #expect(native.frame("TDAT")?.groupID == nil)
            #expect(native.audio == audioBefore, "seed must not alter encoded audio")
        }
    }

    @Test func mp4IntegerEncodingsAndBounds() throws {
        try ContractFixture.withCopy("m4a") { url in
            let audioBefore = try ContractMP4Oracle.read(url).audio
            try ContractMP4Seed.seed([
                .init(key: "trkn", value: .intPair(first: 65_535, second: 32_768)),
                .init(key: "tmpo", value: .integer(255, byteCount: 2)),
                .init(key: "pgap", value: .boolean(false)),
                .init(key: "----:com.apple.iTunes:CONTRACT_VECTOR", value: .text("literal")),
            ], to: url)
            let native = try ContractMP4Oracle.read(url)
            #expect(native.payloads("trkn") == [Data([0, 0, 255, 255, 128, 0, 0, 0])])
            #expect((try native.intPair("trkn")).first == 65_535)
            #expect((try native.intPair("trkn")).second == 32_768)
            #expect(native.payloads("tmpo") == [Data([0, 255])])
            #expect(native.payloads("pgap") == [Data([0])])
            #expect(try native.text("----:com.apple.iTunes:CONTRACT_VECTOR") == "literal")
            #expect(native.audio == audioBefore)
            var truncated = try ContractFixture.bytes(url)
            truncated.removeLast(7)
            #expect(throws: (any Error).self) { _ = try ContractMP4Oracle.read(try Self.writeTemporary(truncated)) }
        }
    }

    @Test func riffChunkBoundsAlignmentAndTruncation() throws {
        try ContractFixture.withCopy("wav") { url in
            let tag = try ContractID3Seed.tag(ContractID3Seed.frame("TIT2", Data([0]) + Data("Odd".utf8)), version: 4)
            try ContractID3Seed.seedContainer(url, tag: tag)
            let oracle = try ContractRIFFOracle.read(url)
            #expect(try oracle.id3Tag() == tag)
            let chunk = try #require(oracle.chunks.first(where: { $0.id == "ID3 " }))
            #expect(chunk.raw.count == 8 + tag.count + tag.count % 2)
            #expect(oracle.declaredSize == (try ContractFixture.bytes(url)).count - 8)
            var bytes = try ContractFixture.bytes(url)
            bytes.removeLast(5)
            let truncated = try Self.writeTemporary(bytes)
            #expect(throws: (any Error).self) { _ = try ContractRIFFOracle.read(truncated) }
        }
    }

    @Test func flacBuilderPreservesDuplicatesWhitespaceAndAudio() throws {
        try ContractFixture.withCopy("flac") { url in
            let audioBefore = try ContractFLACOracle.read(url).audio
            try ContractFLACSeed.seed(comments: [
                "TITLE": ["First", "Second"],
                "YEAR": ["2001", " 2001 "],
                "CONTRACT": [" keep me "],
            ], to: url)
            let native = try ContractFLACOracle.read(url)
            #expect(native.values("TITLE") == ["First", "Second"])
            #expect(native.values("YEAR") == ["2001", " 2001 "])
            #expect(native.values("CONTRACT") == [" keep me "])
            #expect(native.audio == audioBefore)
            var bytes = try ContractFixture.bytes(url)
            bytes[5] = 0x7F
            bytes[6] = 0xFF
            bytes[7] = 0xFF
            let truncated = try Self.writeTemporary(bytes)
            #expect(throws: (any Error).self) { _ = try ContractFLACOracle.read(truncated) }
        }
    }

    @Test func malformedNativeEvidenceIsRejected() throws {
        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seed([.init(key: "©nam", value: .text("X"))], to: url)
            var data = try Data(contentsOf: url)
            // Locate the literal UTF-8 data byte in the test-owned seed.
            let marker = Data([0,0,0,1,0,0,0,0,88])
            let range = try #require(data.range(of: marker)); data[range.upperBound - 1] = 0xff
            try data.write(to: url)
            #expect(throws: (any Error).self) { _ = try ContractMP4Oracle.read(url).text("©nam") }
        }
        #expect(throws: (any Error).self) {
            _ = try ContractMP4Oracle.atoms(Data([0, 0, 0, 7] + Array("ftyp".utf8)), 0..<8)
        }
        #expect(throws: (any Error).self) {
            _ = try ContractMP4Oracle.atoms(Data([0, 0, 0, 9] + Array("ftyp".utf8)), 0..<8)
        }
        #expect(throws: (any Error).self) {
            _ = try ContractID3Oracle.parse(Data([0x49, 0x44, 0x33, 4, 0, 0, 0x80, 0, 0, 0]), audio: Data())
        }
        #expect(throws: (any Error).self) {
            _ = try ContractRIFFOracle.read(try Self.writeTemporary(Data("RIFF".utf8)
                + Data([0xFF, 0xFF, 0xFF, 0x7F]) + Data("WAVE".utf8)))
        }
    }

    private static func writeTemporary(_ data: Data, extension ext: String = "bin") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("oracle-self-\(UUID().uuidString).\(ext)")
        try data.write(to: url)
        return url
    }
}
