import Foundation

/// Bounded Ogg Vorbis/Opus packet reader, independent of TagLib. Page headers,
/// lacing, packet lengths and the comment vector are checked before slicing.
struct IndependentOggProbe {
    enum Invalid: Error { case packet }
    let comments: [String: [String]]
    let audio: [Data]

    static func read(_ url: URL) throws -> Self {
        let bytes = try Data(contentsOf: url)
        var offset = 0
        var pending = Data()
        var packets: [Data] = []
        while offset < bytes.count {
            guard bytes.count - offset >= 27,
                  bytes[offset..<(offset + 4)] == Data("OggS".utf8), bytes[offset + 4] == 0 else { throw Invalid.packet }
            let count = Int(bytes[offset + 26])
            let start = offset + 27
            guard count <= bytes.count - start else { throw Invalid.packet }
            var payload = start + count
            for size in bytes[start..<(start + count)] {
                guard Int(size) <= bytes.count - payload else { throw Invalid.packet }
                pending += bytes[payload..<(payload + Int(size))]
                payload += Int(size)
                if size < 255 { packets.append(pending); pending = Data() }
            }
            offset = payload
        }
        guard pending.isEmpty, packets.count >= 3 else { throw Invalid.packet }
        let opus = packets[0].starts(with: Data("OpusHead".utf8))
        let signature = opus ? Data("OpusTags".utf8) : Data([3]) + Data("vorbis".utf8)
        let packet = packets[1]
        guard packet.starts(with: signature) else { throw Invalid.packet }
        var cursor = signature.count
        func take(_ count: Int) throws -> Data {
            guard count >= 0, count <= packet.count - cursor else { throw Invalid.packet }
            defer { cursor += count }
            return Data(packet[cursor..<(cursor + count)])
        }
        func number() throws -> Int { try take(4).reversed().reduce(0) { ($0 << 8) | Int($1) } }
        _ = try take(number())
        let count = try number()
        guard count <= (packet.count - cursor) / 4 else { throw Invalid.packet }
        var comments: [String: [String]] = [:]
        for _ in 0..<count {
            guard let value = String(data: try take(number()), encoding: .utf8), let equals = value.firstIndex(of: "=") else { throw Invalid.packet }
            comments[String(value[..<equals]).uppercased(), default: []].append(String(value[value.index(after: equals)...]))
        }
        if !opus { guard try take(1) == Data([1]), cursor == packet.count else { throw Invalid.packet } }
        return .init(comments: comments, audio: Array(packets.dropFirst(opus ? 2 : 3)))
    }
}
