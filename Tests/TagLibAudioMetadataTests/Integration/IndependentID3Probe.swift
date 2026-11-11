import Foundation

/// Limited to uncompressed, unsynchronized ID3v2.4 UTF-8/Latin-1 text frames.
/// Other tag versions/flags are rejected rather than guessed.
struct IndependentID3Probe {
    enum Invalid: Error { case tag }
    let frames: [String: [Data]]
    let texts: [String: [String]]
    let audio: Data

    static func read(_ url: URL) throws -> Self {
        let data = try Data(contentsOf: url)
        guard data.count >= 10, data.prefix(5) == Data([73, 68, 51, 4, 0]), data[5] == 0,
              data[6..<10].allSatisfy({ $0 < 128 }) else { throw Invalid.tag }
        let end = 10 + data[6..<10].reduce(0) { ($0 << 7) | Int($1) }
        guard end <= data.count else { throw Invalid.tag }
        var offset = 10
        var frames: [String: [Data]] = [:]
        var texts: [String: [String]] = [:]
        while offset < end, data[offset] != 0 {
            guard end - offset >= 10, let id = String(data: data[offset..<(offset + 4)], encoding: .ascii),
                  data[(offset + 4)..<(offset + 8)].allSatisfy({ $0 < 128 }),
                  data[offset + 8] == 0, data[offset + 9] == 0 else { throw Invalid.tag }
            let count = data[(offset + 4)..<(offset + 8)].reduce(0) { ($0 << 7) | Int($1) }
            let start = offset + 10
            guard count > 0, count <= end - start else { throw Invalid.tag }
            let payload = data[start..<(start + count)]
            var key = id
            if id.hasPrefix("T") || id == "GRP1" {
                let encoding: String.Encoding
                switch data[start] { case 0: encoding = .isoLatin1; case 3: encoding = .utf8; default: throw Invalid.tag }
                guard let text = String(data: payload.dropFirst(), encoding: encoding) else { throw Invalid.tag }
                var values = text.components(separatedBy: "\0")
                if id == "TXXX" { key += ":" + values.removeFirst() }
                texts[key, default: []].append(contentsOf: values)
            }
            frames[key, default: []].append(Data(data[offset..<(start + count)]))
            offset = start + count
        }
        guard data[offset..<end].allSatisfy({ $0 == 0 }), end < data.count else { throw Invalid.tag }
        return .init(frames: frames, texts: texts, audio: Data(data[end...]))
    }
}
