import Foundation
import Testing

enum HardeningFixture {
    enum Invalid: Error { case container }
    static func url(_ ext: String, name: String = "hardening") throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Audio")
            ?? Bundle.module.url(forResource: name, withExtension: ext))
    }

    static func withCopy(_ ext: String, name: String = "hardening", _ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Hardening-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let copy = directory.appendingPathComponent("fixture.\(ext)")
        try FileManager.default.copyItem(at: url(ext, name: name), to: copy)
        try body(copy)
    }

    static func number(_ value: UInt64, bytes: Int, little: Bool = false) -> Data {
        Data((0..<bytes).map { UInt8(truncatingIfNeeded: value >> ((little ? $0 : bytes - 1 - $0) * 8)) })
    }

    static func integer(_ data: Data, _ offset: Int, _ count: Int, little: Bool = false) throws -> Int {
        guard offset >= 0, count > 0, count <= 8, offset <= data.count,
              count <= data.count - offset else { throw Invalid.container }
        let bytes = data[offset..<(offset + count)]
        let value = (little ? Array(bytes.reversed()) : Array(bytes)).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard value <= UInt64(Int.max) else { throw Invalid.container }
        return Int(value)
    }

    static func frame(_ id: String, _ payload: Data) -> Data {
        let n = payload.count
        let size = Data([UInt8((n >> 21) & 127), UInt8((n >> 14) & 127), UInt8((n >> 7) & 127), UInt8(n & 127)])
        return Data(id.utf8) + size + Data([0, 0]) + payload
    }

    static func id3(_ frames: Data) -> Data {
        let n = frames.count
        return Data([73, 68, 51, 4, 0, 0, UInt8((n >> 21) & 127), UInt8((n >> 14) & 127),
                     UInt8((n >> 7) & 127), UInt8(n & 127)]) + frames
    }

    static func dsdState(_ data: Data, ext: String) throws -> (audio: Data, tag: Data) {
        if ext == "dsf" {
            guard data.prefix(4) == Data("DSD ".utf8), data.count >= 92,
                  try integer(data, 12, 8, little: true) == data.count,
                  data[28..<32] == Data("fmt ".utf8), data[80..<84] == Data("data".utf8) else { throw Invalid.container }
            let size = try integer(data, 84, 8, little: true)
            let metadata = try integer(data, 20, 8, little: true)
            guard size >= 12, size <= data.count - 80, metadata == 0 || metadata >= 80 + size,
                  metadata <= data.count else { throw Invalid.container }
            return (Data(data[92..<(80 + size)]), metadata == 0 ? Data() : Data(data[metadata...]))
        }
        guard data.count >= 16, data.prefix(4) == Data("FRM8".utf8),
              data[12..<16] == Data("DSD ".utf8),
              try integer(data, 4, 8) == data.count - 12 else { throw Invalid.container }
        var offset = 16
        var audio = Data()
        var tag = Data()
        while offset < data.count {
            let size = try integer(data, offset + 4, 8)
            let start = offset + 12
            guard size <= data.count - start else { throw Invalid.container }
            let name = Data(data[offset..<(offset + 4)])
            if name == Data("DSD ".utf8) { audio += data[start..<(start + size)] }
            if name == Data("ID3 ".utf8) { tag = Data(data[start..<(start + size)]) }
            offset = start + size + size % 2
            guard offset <= data.count else { throw Invalid.container }
        }
        guard !audio.isEmpty else { throw Invalid.container }
        return (audio, tag)
    }

    static func seedDSDTag(_ tag: Data, at url: URL) throws {
        var data = try Data(contentsOf: url)
        if url.pathExtension == "dsf" {
            let old = try integer(data, 20, 8, little: true)
            if old != 0 { data = Data(data.prefix(old)) }
            let offset = data.count
            data += tag
            data.replaceSubrange(12..<20, with: number(UInt64(data.count), bytes: 8, little: true))
            data.replaceSubrange(20..<28, with: number(UInt64(offset), bytes: 8, little: true))
        } else {
            // The upstream fixture has no ID3 chunk; append the conventional root ID3 chunk.
            guard try dsdState(data, ext: "dff").tag.isEmpty else { throw Invalid.container }
            data += Data("ID3 ".utf8) + number(UInt64(tag.count), bytes: 8) + tag
            if tag.count % 2 != 0 { data.append(0) }
            data.replaceSubrange(4..<12, with: number(UInt64(data.count - 12), bytes: 8))
        }
        try data.write(to: url)
    }

    static func frames(_ tag: Data) throws -> [String: [Data]] {
        guard tag.count >= 10, tag.prefix(3) == Data("ID3".utf8), tag[3] == 4, tag[5] == 0,
              tag[6..<10].allSatisfy({ $0 < 128 }) else { throw Invalid.container }
        let end = 10 + tag[6..<10].reduce(0) { ($0 << 7) | Int($1) }
        guard end <= tag.count else { throw Invalid.container }
        var offset = 10
        var result: [String: [Data]] = [:]
        while offset < end, tag[offset] != 0 {
            guard end - offset >= 10, tag[(offset + 4)..<(offset + 8)].allSatisfy({ $0 < 128 }),
                  let id = String(data: tag[offset..<(offset + 4)], encoding: .ascii) else { throw Invalid.container }
            let size = tag[(offset + 4)..<(offset + 8)].reduce(0) { ($0 << 7) | Int($1) }
            let start = offset + 10
            guard size <= end - start else { throw Invalid.container }
            result[id, default: []].append(Data(tag[start..<(start + size)]))
            offset = start + size
        }
        return result
    }

    static func writeAPE(audio: Data, items: [String: APEItem], to url: URL) throws {
        var payload = Data()
        for key in items.keys.sorted() {
            guard let item = items[key] else { throw Invalid.container }
            payload += number(UInt64(item.value.count), bytes: 4, little: true)
            payload += number(UInt64(item.flags), bytes: 4, little: true)
            payload += Data(key.utf8) + Data([0]) + item.value
        }
        let footer = Data("APETAGEX".utf8) + number(2000, bytes: 4, little: true)
            + number(UInt64(payload.count + 32), bytes: 4, little: true)
            + number(UInt64(items.count), bytes: 4, little: true) + Data(repeating: 0, count: 12)
        try (audio + payload + footer).write(to: url)
    }

    struct APEItem: Equatable {
        let flags: Int
        let value: Data
    }

    static func apeState(_ data: Data) throws -> (audio: Data, items: [String: APEItem]) {
        var end = data.count
        if end >= 128, data[(end - 128)..<(end - 125)] == Data("TAG".utf8) { end -= 128 }
        guard end >= 32 else { throw Invalid.container }
        let footer = end - 32
        if data[footer..<(footer + 8)] != Data("APETAGEX".utf8) {
            return (Data(data.prefix(end)), [:])
        }
        let size = try integer(data, footer + 12, 4, little: true)
        let count = try integer(data, footer + 16, 4, little: true)
        guard size >= 32, size <= end, count <= size / 9 else { throw Invalid.container }
        var offset = end - size
        let start = offset
        var items: [String: APEItem] = [:]
        for _ in 0..<count {
            let length = try integer(data, offset, 4, little: true)
            let flags = try integer(data, offset + 4, 4, little: true)
            offset += 8
            guard offset < footer, let nul = data[offset..<footer].firstIndex(of: 0),
                  let key = String(data: data[offset..<nul], encoding: .utf8), items[key.uppercased()] == nil else { throw Invalid.container }
            offset = nul + 1
            guard length <= footer - offset else { throw Invalid.container }
            items[key.uppercased()] = APEItem(flags: flags, value: Data(data[offset..<(offset + length)]))
            offset += length
        }
        guard offset == footer else { throw Invalid.container }
        var audioEnd = start
        if start >= 32, data[(start - 32)..<(start - 24)] == Data("APETAGEX".utf8) { audioEnd -= 32 }
        return (Data(data.prefix(audioEnd)), items)
    }
}
