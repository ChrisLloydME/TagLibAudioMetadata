import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

struct CleanRoomMPEGTests {
    private func legacyTag() -> Data {
        func fixed(_ text: String, _ width: Int) -> Data {
            let bytes = Data(text.utf8.prefix(width))
            return bytes + Data(repeating: 0, count: width - bytes.count)
        }
        return Data("TAG".utf8) + fixed("Legacy Title", 30) + fixed("Legacy Artist", 30)
            + fixed("Legacy Album", 30) + fixed("1999", 4) + fixed("Legacy Comment", 30) + Data([0])
    }

    private func audio(_ data: Data) -> Data {
        var bytes = data
        if bytes.prefix(3) == Data("ID3".utf8) {
            let length = bytes[6..<10].reduce(0) { ($0 << 7) | Int($1) }
            bytes = Data(bytes.dropFirst(10 + length))
        }
        if bytes.count >= 128, bytes.suffix(128).prefix(3) == Data("TAG".utf8) {
            bytes = Data(bytes.dropLast(128))
        }
        return bytes
    }

    @Test func firstID3v2PromotesLegacyFieldsWithoutChangingID3v1() throws {
        for ext in ["mp3", "mp2"] {
            for operation in 0..<4 {
                try HardeningFixture.withCopy("mp3", name: "testAudioFile") { source in
                    let url = source.deletingPathExtension().appendingPathExtension(ext)
                    let payload = audio(try Data(contentsOf: source))
                    let legacy = legacyTag()
                    try (payload + legacy).write(to: url)
                    switch operation {
                    case 0:
                        try TagLibMetadataManager.writeTrackNumberText("07/12", discNumberText: nil, to: url)
                    case 1:
                        try TagLibMetadataExtractor.writeTrackNumber(7, totalTracks: 12, padWidth: 2, to: url)
                    case 2:
                        try TagLibMetadataManager.applyMetadataPatch(
                            MetadataPatch(fields: [.track: .integer(7), .trackTotal: .integer(12)]), to: url)
                    default:
                        try TagLibMetadataManager.applyMetadataPatch(
                            MetadataPatch(explicitAdvisory: .explicit), to: url)
                    }
                    let result = try Data(contentsOf: url)
                    #expect(result.suffix(128) == legacy)
                    #expect(audio(result) == payload)
                    let frames = try HardeningFixture.frames(result)
                    // Independent preferred-tag oracle: fallback reads cannot satisfy these.
                    for (id, value) in ["TIT2": "Legacy Title", "TPE1": "Legacy Artist",
                                        "TALB": "Legacy Album", "TDRC": "1999"] {
                        let frame = try #require(frames[id]?.first)
                        #expect(String(decoding: frame.dropFirst(), as: UTF8.self) == value)
                    }
                    #expect(frames["COMM"]?.count == 1)
                }
            }
        }
    }

    @Test func mixedTagDeltaPreservesSecondaryBytesAndDoesNotCreateEmptyTags() throws {
        for advisory in [false, true] {
            try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
                let base = audio(try Data(contentsOf: url))
                let modern = HardeningFixture.id3(
                    HardeningFixture.frame("TIT2", Data([3]) + Data("Modern".utf8)))
                let legacy = legacyTag()
                try (modern + base + legacy).write(to: url)
                if advisory {
                    try TagLibMetadataManager.applyMetadataPatch(
                        MetadataPatch(explicitAdvisory: .explicit), to: url)
                } else {
                    try TagLibMetadataManager.applyMetadataPatch(
                        MetadataPatch(fields: [.track: .integer(7), .trackTotal: .integer(12)]), to: url)
                }
                let after = try Data(contentsOf: url)
                #expect(after.suffix(128) == legacy)
                #expect(audio(after) == base)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "Modern")
                try (modern + base).write(to: url)
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(explicitAdvisory: .explicit), to: url)
                #expect(try Data(contentsOf: url).suffix(128).prefix(3) != Data("TAG".utf8))
            }
        }
    }
    @Test func rawReplacementPreservesSecondaryID3v1Bytes() throws {
        for ext in ["mp3", "mp2"] {
            try HardeningFixture.withCopy("mp3", name: "testAudioFile") { source in
                let url = source.deletingPathExtension().appendingPathExtension(ext)
                let payload = audio(try Data(contentsOf: source))
                let legacy = legacyTag()
                let modern = HardeningFixture.id3(HardeningFixture.frame("TIT2", Data([3]) + Data("Modern".utf8)))
                for arrays in [false, true] {
                    try (modern + payload + legacy).write(to: url)
                    if arrays {
                        try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(["TITLE": ["Replacement"]], to: url)
                    } else {
                        try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(["TITLE": "Replacement"], to: url)
                    }
                    let result = try Data(contentsOf: url)
                    #expect(result.suffix(128) == legacy)
                    #expect(audio(result) == payload)
                    #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "Replacement")
                }
            }
        }
    }

}
