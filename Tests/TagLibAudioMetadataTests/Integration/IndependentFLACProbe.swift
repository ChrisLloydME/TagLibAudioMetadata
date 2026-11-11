import Foundation

/// Test-only native FLAC/Vorbis-comment reader. Throws on malformed lengths;
/// neither the package bridge nor its metadata projection is used.
struct IndependentFLACProbe {
    enum Invalid: Error { case container }
    let comments: [String: [String]]
    let otherBlocks: [Int: [Data]]
    let audio: Data

    static func read(_ url: URL) throws -> Self {
        let data = try Data(contentsOf: url)
        guard data.starts(with: Data("fLaC".utf8)) else { throw Invalid.container }
        var offset = 4
        var comments: [String: [String]] = [:]
        var blocks: [Int: [Data]] = [:]
        var hasComments = false
        while true {
            guard data.count - offset >= 4 else { throw Invalid.container }
            let header = data[offset]
            let type = Int(header & 0x7f)
            let size = data[(offset + 1)..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
            offset += 4
            guard size <= data.count - offset else { throw Invalid.container }
            let block = Data(data[offset..<(offset + size)])
            if type == 4 {
                guard !hasComments else { throw Invalid.container }
                hasComments = true
                var cursor = 0
                func length() throws -> Int {
                    guard block.count - cursor >= 4 else { throw Invalid.container }
                    let value = block[cursor..<(cursor + 4)].reversed().reduce(0) { ($0 << 8) | Int($1) }
                    cursor += 4
                    return value
                }
                func string() throws -> String {
                    let count = try length()
                    guard count <= block.count - cursor,
                          let value = String(data: block[cursor..<(cursor + count)], encoding: .utf8) else { throw Invalid.container }
                    cursor += count
                    return value
                }
                _ = try string() // Vendor is metadata, not an audio-preservation oracle.
                let count = try length()
                guard count <= (block.count - cursor) / 4 else { throw Invalid.container }
                for _ in 0..<count {
                    let entry = try string()
                    guard let equals = entry.firstIndex(of: "=") else { throw Invalid.container }
                    comments[String(entry[..<equals]), default: []].append(String(entry[entry.index(after: equals)...]))
                }
                guard cursor == block.count else { throw Invalid.container }
            } else if type != 1 { // Metadata padding may legitimately resize.
                blocks[type, default: []].append(block)
            }
            offset += size
            if header & 0x80 != 0 { break }
        }
        guard offset < data.count else { throw Invalid.container }
        return .init(comments: comments, otherBlocks: blocks, audio: Data(data[offset...]))
    }
}
