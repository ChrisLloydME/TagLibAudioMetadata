import Foundation

/// Bounded native ID3v2.4 reader for the test containers. RIFF/AIFF chunks,
/// DSD metadata offsets and leading ID3 lengths are read without TagLib.
struct IndependentID3ContainerProbe {
    enum Invalid: Error { case container }
    let frames: [String: [Data]]
    let audio: Data

    static func read(_ url: URL) throws -> Self {
        let bytes = try Data(contentsOf: url)
        let ext = url.pathExtension
        let tag: Data
        let audio: Data
        if ["dsf", "dff"].contains(ext) {
            let state = try HardeningFixture.dsdState(bytes, ext: ext)
            (tag, audio) = (state.tag, state.audio)
        } else if ["wav", "aiff"].contains(ext) {
            guard bytes.count >= 12, bytes.prefix(4) == Data((ext == "wav" ? "RIFF" : "FORM").utf8) else { throw Invalid.container }
            var position = 12
            var foundTag: Data?
            var foundAudio: Data?
            while position < bytes.count {
                guard bytes.count - position >= 8 else { throw Invalid.container }
                let name = String(decoding: bytes[position..<(position + 4)], as: UTF8.self)
                let length = try HardeningFixture.integer(bytes, position + 4, 4, little: ext == "wav")
                let start = position + 8
                guard length <= bytes.count - start else { throw Invalid.container }
                let payload = Data(bytes[start..<(start + length)])
                if name.uppercased() == "ID3 " { foundTag = payload }
                if name == (ext == "wav" ? "data" : "SSND") { foundAudio = payload }
                position = start + length + length % 2
                guard position <= bytes.count else { throw Invalid.container }
            }
            guard let nativeTag = foundTag, let payload = foundAudio else { throw Invalid.container }
            (tag, audio) = (nativeTag, payload)
        } else {
            guard bytes.count >= 10, bytes.prefix(3) == Data("ID3".utf8), bytes[6..<10].allSatisfy({ $0 < 128 }) else { throw Invalid.container }
            let end = 10 + bytes[6..<10].reduce(0) { ($0 << 7) | Int($1) }
            guard end <= bytes.count else { throw Invalid.container }
            (tag, audio) = (Data(bytes.prefix(end)), Data(bytes.dropFirst(end)))
        }
        var qualified: [String: [Data]] = [:]
        for (id, payloads) in try HardeningFixture.frames(tag) {
            for payload in payloads {
                var key = id
                if id == "TXXX" {
                    guard let encoding = payload.first, [UInt8(0), 3].contains(encoding),
                          let text = String(data: payload.dropFirst(), encoding: encoding == 3 ? .utf8 : .isoLatin1),
                          let end = text.firstIndex(of: "\0") else { throw Invalid.container }
                    key += ":" + text[..<end]
                }
                qualified[key, default: []].append(payload)
            }
        }
        return .init(frames: qualified, audio: audio)
    }
}
