import Foundation
import Testing
import TagLibAudioMetadata

struct HardeningAudioPayloadTests {
    private func payload(_ bytes: Data, ext: String) throws -> [Data] {
        if ext == "flac" {
            guard bytes.prefix(4) == Data("fLaC".utf8) else { throw HardeningFixture.Invalid.container }
            var offset = 4
            while true {
                guard bytes.count - offset >= 4 else { throw HardeningFixture.Invalid.container }
                let last = bytes[offset] & 128 != 0
                let length = try HardeningFixture.integer(bytes, offset + 1, 3)
                offset += 4
                guard length <= bytes.count - offset else { throw HardeningFixture.Invalid.container }
                offset += length
                if last { return [Data(bytes[offset...])] }
            }
        }
        if ["ogg", "opus"].contains(ext) {
            var offset = 0
            var packet = Data()
            var packets: [Data] = []
            while offset < bytes.count {
                guard bytes.count - offset >= 27, bytes[offset..<(offset + 4)] == Data("OggS".utf8),
                      bytes[offset + 4] == 0 else { throw HardeningFixture.Invalid.container }
                let segments = Int(bytes[offset + 26])
                guard segments <= bytes.count - offset - 27 else { throw HardeningFixture.Invalid.container }
                let sizes = bytes[(offset + 27)..<(offset + 27 + segments)]
                var start = offset + 27 + segments
                for size in sizes {
                    let length = Int(size)
                    guard length <= bytes.count - start else { throw HardeningFixture.Invalid.container }
                    packet += bytes[start..<(start + length)]
                    start += length
                    if length < 255 {
                        if !packet.starts(with: Data([3]) + Data("vorbis".utf8)),
                           !packet.starts(with: Data("OpusTags".utf8)) { packets.append(packet) }
                        packet = Data()
                    }
                }
                offset = start
            }
            guard packet.isEmpty, packets.count > 2 else { throw HardeningFixture.Invalid.container }
            return packets
        }
        var data = bytes
        if data.prefix(3) == Data("ID3".utf8) {
            guard data.count >= 10, data[6..<10].allSatisfy({ $0 < 128 }) else { throw HardeningFixture.Invalid.container }
            let size = data[6..<10].reduce(0) { ($0 << 7) | Int($1) }
            let end = 10 + size + ((data[3] == 4 && data[5] & 16 != 0) ? 10 : 0)
            guard end <= data.count else { throw HardeningFixture.Invalid.container }
            data = Data(data.dropFirst(end))
        }
        return [try HardeningFixture.apeState(data).audio]
    }

    @Test func representativeMetadataOperationsPreserveEncodedAudio() throws {
        for ext in ["flac", "mp3", "aac", "ogg", "opus", "tta", "wv"] {
            let name = ext == "opus" ? "synthetic" : "testAudioFile"
            try HardeningFixture.withCopy(ext, name: name) { url in
                let expected = try payload(Data(contentsOf: url), ext: ext)
                #expect(!expected.isEmpty && expected.allSatisfy { !$0.isEmpty })
                func check() throws { #expect(try payload(Data(contentsOf: url), ext: ext) == expected, "\(ext)") }
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Payload Basic edit" }
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "Payload Basic edit")
                try check()
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.album: .text("Payload typed album")]), to: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).album == "Payload typed album")
                try check()
                try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["PAYLOAD_CUSTOM": ["one", "two"]]), to: url)
                #expect(try TagLibMetadataManager.rawMetadataResult(from: url).properties.contains {
                    $0.key == "PAYLOAD_CUSTOM" && $0.values == ["one", "two"]
                })
                try check()
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    .init(properties: [.init(key: "TITLE", values: ["Payload structured edit"])]), to: url, includeProperties: true)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "Payload structured edit")
                try check()
                let cover = try Data(contentsOf: HardeningFixture.url("jpg", name: "testCover"))
                try TagLibMetadataManager.applyMetadataPatch(.init(artwork: .replace([
                    .init(mimeType: "image/jpeg", data: cover)
                ])), to: url)
                #expect(try TagLibMetadataManager.readStructuredMetadataResult(from: url).artwork.contains { $0.data == cover })
                try check()
                try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).title.isEmpty)
                #expect(try TagLibMetadataManager.readStructuredMetadataResult(from: url).artwork.isEmpty)
                try check()
            }
        }
    }
}
