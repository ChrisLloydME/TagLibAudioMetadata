import Foundation

enum ProbeFLAC {
    struct Evidence {
        let comments: [String: [String]]
        let audio: Data

        func values(_ key: String) -> [String] {
            comments.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value ?? []
        }
    }

    static func read(_ url: URL) throws -> Evidence {
        let data = try Data(contentsOf: url)
        guard data.prefix(4) == Data("fLaC".utf8) else { throw ProbeError.malformed("missing fLaC") }
        var offset = 4
        var comments: [String: [String]] = [:]
        var seen = false
        while true {
            guard data.count - offset >= 4 else { throw ProbeError.malformed("truncated FLAC header") }
            let header = data[offset]
            let type = Int(header & 0x7F)
            let size = Int(data[(offset + 1)..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) })
            offset += 4
            guard size <= data.count - offset else { throw ProbeError.malformed("FLAC block exceeds file") }
            let block = Data(data[offset..<(offset + size)])
            offset += size
            if type == 4 {
                guard !seen else { throw ProbeError.malformed("duplicate comments") }
                seen = true
                var cursor = 0
                func take(_ count: Int) throws -> Data {
                    guard count >= 0, count <= block.count - cursor else {
                        throw ProbeError.malformed("comment exceeds block")
                    }
                    defer { cursor += count }
                    return Data(block[cursor..<(cursor + count)])
                }
                func number() throws -> Int {
                    try take(4).reversed().reduce(0) { ($0 << 8) | Int($1) }
                }
                func string() throws -> String {
                    let count = try number()
                    guard let value = String(data: try take(count), encoding: .utf8) else {
                        throw ProbeError.malformed("comment is not UTF-8")
                    }
                    return value
                }
                _ = try string()
                let count = try number()
                for _ in 0..<count {
                    let entry = try string()
                    guard let equals = entry.firstIndex(of: "=") else {
                        throw ProbeError.malformed("comment has no equals")
                    }
                    comments[String(entry[..<equals]), default: []].append(String(entry[entry.index(after: equals)...]))
                }
                guard cursor == block.count else { throw ProbeError.malformed("trailing comment bytes") }
            }
            if header & 0x80 != 0 { break }
        }
        guard offset < data.count else { throw ProbeError.malformed("FLAC has no audio") }
        return Evidence(comments: comments, audio: Data(data[offset...]))
    }

    static func seed(comments: [(String, String)], to url: URL) throws {
        let data = try Data(contentsOf: url)
        guard data.prefix(4) == Data("fLaC".utf8) else { throw ProbeError.malformed("missing fLaC") }
        var offset = 4
        var blocks: [(Int, Data, Bool)] = []
        while true {
            guard data.count - offset >= 4 else { throw ProbeError.malformed("truncated FLAC header") }
            let header = data[offset]
            let type = Int(header & 0x7F)
            let size = Int(data[(offset + 1)..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) })
            offset += 4
            guard size <= data.count - offset else { throw ProbeError.malformed("FLAC block exceeds file") }
            blocks.append((type, Data(data[offset..<(offset + size)]), header & 0x80 != 0))
            offset += size
            if header & 0x80 != 0 { break }
        }
        var comment = Data()
        let vendor = Data("calibration-fixture".utf8)
        comment += ProbeFixture.number(UInt64(vendor.count), bytes: 4, little: true) + vendor
        comment += ProbeFixture.number(UInt64(comments.count), bytes: 4, little: true)
        for (key, value) in comments {
            let entry = Data("\(key)=\(value)".utf8)
            comment += ProbeFixture.number(UInt64(entry.count), bytes: 4, little: true) + entry
        }
        var rebuilt: [(Int, Data)] = []
        var inserted = false
        for block in blocks {
            if block.0 == 4 {
                if !inserted {
                    rebuilt.append((4, comment))
                    inserted = true
                }
            } else if block.0 != 1 {
                rebuilt.append((block.0, block.1))
            }
        }
        if !inserted { rebuilt.append((4, comment)) }
        var output = Data("fLaC".utf8)
        for (index, block) in rebuilt.enumerated() {
            output.append((index == rebuilt.count - 1 ? 0x80 : 0) | UInt8(block.0))
            output += ProbeFixture.number(UInt64(block.1.count), bytes: 3) + block.1
        }
        output += Data(data[offset...])
        try output.write(to: url)
    }
}
