import Foundation

enum ProbeID3 {
    struct Frame {
        let id: String
        let status: UInt8
        let format: UInt8
        let groupID: UInt8?
        let payload: Data
        var text: String? {
            guard let encoding = payload.first else { return nil }
            let body = Data(payload.dropFirst())
            return String(data: body, encoding: encoding == 3 ? .utf8 : .isoLatin1)
        }
    }

    struct Evidence {
        let version: Int
        let tagFlags: UInt8
        let frames: [Frame]
        let audio: Data

        func frame(_ id: String) -> Frame? { frames.first { $0.id == id } }
    }

    static func frame(
        _ id: String,
        _ text: String,
        status: UInt8 = 0,
        format: UInt8 = 0,
        groupID: UInt8? = nil
    ) -> Data {
        var payload = Data([0]) + Data(text.utf8)
        if let groupID { payload = Data([groupID]) + payload }
        return Data(id.utf8) + ProbeFixture.number(UInt64(payload.count), bytes: 4)
            + Data([status, format]) + payload
    }

    static func tag(_ frames: Data) throws -> Data {
        guard frames.count <= 0x0FFF_FFFF else { throw ProbeError.malformed("tag too large") }
        let synchsafe = Data([
            UInt8((frames.count >> 21) & 0x7F),
            UInt8((frames.count >> 14) & 0x7F),
            UInt8((frames.count >> 7) & 0x7F),
            UInt8(frames.count & 0x7F),
        ])
        return Data([0x49, 0x44, 0x33, 3, 0, 0]) + synchsafe + frames
    }

    static func seedMP3(_ url: URL, frames: Data) throws {
        var data = try Data(contentsOf: url)
        if data.count >= 10, data.prefix(3) == Data("ID3".utf8),
           data[6..<10].allSatisfy({ $0 < 0x80 }) {
            let end = 10 + data[6..<10].reduce(0) { ($0 << 7) | Int($1) }
            guard end <= data.count else { throw ProbeError.malformed("existing tag exceeds file") }
            data = Data(data.dropFirst(end))
        }
        try (try tag(frames) + data).write(to: url)
    }

    static func read(_ url: URL) throws -> Evidence {
        let data = try Data(contentsOf: url)
        guard data.count >= 10, data.prefix(3) == Data("ID3".utf8),
              data[6..<10].allSatisfy({ $0 < 0x80 }) else {
            throw ProbeError.malformed("missing ID3 tag")
        }
        let version = Int(data[3])
        guard version == 3 || version == 4 else { throw ProbeError.malformed("unsupported ID3 version") }
        let end = 10 + data[6..<10].reduce(0) { ($0 << 7) | Int($1) }
        guard end <= data.count else { throw ProbeError.malformed("tag exceeds file") }
        var offset = 10
        var frames: [Frame] = []
        while offset < end, data[offset] != 0 {
            guard end - offset >= 10, let id = String(data: data[offset..<(offset + 4)], encoding: .ascii) else {
                throw ProbeError.malformed("truncated frame header")
            }
            let size = version == 4
                ? data[(offset + 4)..<(offset + 8)].reduce(0) { ($0 << 7) | Int($1) }
                : (try ProbeFixture.integer(data, offset + 4, 4))
            let status = data[offset + 8]
            let format = data[offset + 9]
            let start = offset + 10
            guard size <= end - start else { throw ProbeError.malformed("frame exceeds tag") }
            var payloadStart = start
            var groupID: UInt8?
            if format & 0x20 != 0 {
                guard size >= 1 else { throw ProbeError.malformed("grouped frame is empty") }
                groupID = data[payloadStart]
                payloadStart += 1
            }
            frames.append(Frame(
                id: id, status: status, format: format, groupID: groupID,
                payload: Data(data[payloadStart..<(start + size)])
            ))
            offset = start + size
        }
        return Evidence(version: version, tagFlags: data[5], frames: frames, audio: Data(data[end...]))
    }
}
