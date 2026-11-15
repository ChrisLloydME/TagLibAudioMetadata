import Foundation

/// Bounded native readers used as independent oracles. None of these call the
/// package reader to decide what a value should be; they only decode the bytes
/// that the production writer actually persisted.
struct ContractMP4Oracle {
    struct Atom {
        let type: String
        let range: Range<Int>
        let payload: Range<Int>
    }

    let items: [String: [Data]]
    let values: [String: [Data]]
    let audio: Data
    let topLevelTypes: [String]
    let allowsAbsentMetadata: Bool

    static func atoms(_ data: Data, _ range: Range<Int>) throws -> [Atom] {
        var result: [Atom] = []
        var offset = range.lowerBound
        while offset < range.upperBound {
            guard range.upperBound - offset >= 8 else {
                throw ContractOracleError.malformed("truncated MP4 atom header")
            }
            guard let type = String(data: data[(offset + 4)..<(offset + 8)], encoding: .isoLatin1) else {
                throw ContractOracleError.malformed("non-ASCII MP4 atom type")
            }
            var size = data[offset..<(offset + 4)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            var header = 8
            if size == 1 {
                guard range.upperBound - offset >= 16 else {
                    throw ContractOracleError.malformed("truncated extended MP4 atom header")
                }
                size = data[(offset + 8)..<(offset + 16)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
                header = 16
            } else if size == 0 {
                size = UInt64(range.upperBound - offset)
            }
            guard size >= UInt64(header) else {
                throw ContractOracleError.malformed("MP4 atom size below header")
            }
            guard size <= UInt64(range.upperBound - offset) else {
                throw ContractOracleError.malformed("MP4 atom exceeds parent")
            }
            let end = offset + Int(size)
            result.append(Atom(type: type, range: offset..<end, payload: (offset + header)..<end))
            offset = end
        }
        guard offset == range.upperBound else {
            throw ContractOracleError.malformed("MP4 children do not consume parent")
        }
        return result
    }

    static func read(_ url: URL, allowingAbsentMetadata: Bool = false) throws -> ContractMP4Oracle {
        let data = try ContractFixture.bytes(url)
        let top = try atoms(data, 0..<data.count)
        let audio = top.filter { $0.type == "mdat" }.map { Data(data[$0.payload]) }
        guard let moov = top.first(where: { $0.type == "moov" }) else {
            throw ContractOracleError.malformed("missing moov")
        }
        var children = try atoms(data, moov.payload)
        guard let udta = children.first(where: { $0.type == "udta" }) else {
            if allowingAbsentMetadata {
                return .init(items: [:], values: [:], audio: audio.reduce(Data(), +),
                             topLevelTypes: top.map(\.type), allowsAbsentMetadata: true)
            }
            throw ContractOracleError.missing("udta")
        }
        children = try atoms(data, udta.payload)
        guard let meta = children.first(where: { $0.type == "meta" }) else {
            if allowingAbsentMetadata {
                return .init(items: [:], values: [:], audio: audio.reduce(Data(), +),
                             topLevelTypes: top.map(\.type), allowsAbsentMetadata: true)
            }
            throw ContractOracleError.missing("meta")
        }
        guard meta.payload.count >= 4 else {
            throw ContractOracleError.malformed("meta atom is shorter than its version/flags")
        }
        let metaChildren = try atoms(data, (meta.payload.lowerBound + 4)..<meta.payload.upperBound)
        guard let ilst = metaChildren.first(where: { $0.type == "ilst" }) else {
            if allowingAbsentMetadata {
                return .init(items: [:], values: [:], audio: audio.reduce(Data(), +),
                             topLevelTypes: top.map(\.type), allowsAbsentMetadata: true)
            }
            throw ContractOracleError.missing("ilst")
        }
        var items: [String: [Data]] = [:]
        var values: [String: [Data]] = [:]
        for item in try atoms(data, ilst.payload) {
            let fields = try atoms(data, item.payload)
            var key = item.type
            if key == "----" {
                func text(_ name: String) throws -> String {
                    guard let field = fields.first(where: { $0.type == name }), field.payload.count >= 4,
                          let text = String(data: data[(field.payload.lowerBound + 4)..<field.payload.upperBound], encoding: .utf8) else {
                        throw ContractOracleError.malformed("malformed MP4 freeform \(name)")
                    }
                    return text
                }
                key += ":" + (try text("mean")) + ":" + (try text("name"))
            }
            for field in fields where field.type == "data" {
                guard field.payload.count >= 8 else {
                    throw ContractOracleError.malformed("MP4 data atom shorter than type/locale")
                }
                values[key, default: []].append(Data(data[(field.payload.lowerBound + 8)..<field.payload.upperBound]))
            }
            items[key, default: []].append(Data(data[item.range]))
        }
        return .init(items: items, values: values, audio: audio.reduce(Data(), +),
                     topLevelTypes: top.map(\.type), allowsAbsentMetadata: false)
    }

    func has(_ key: String) -> Bool { items[key] != nil }

    func payloads(_ key: String) -> [Data] { values[key] ?? [] }

    func text(_ key: String) throws -> String {
        guard let payload = values[key]?.first else {
            throw ContractOracleError.missing("MP4 item \(key)")
        }
        guard let text = String(data: payload, encoding: .utf8) else {
            throw ContractOracleError.malformed("MP4 item \(key) is not UTF-8")
        }
        return text
    }

    func integer(_ key: String) throws -> Int {
        guard let payload = values[key]?.first, !payload.isEmpty, payload.count <= 8 else {
            throw ContractOracleError.missing("MP4 integer \(key)")
        }
        return payload.reduce(0) { ($0 << 8) | Int($1) }
    }

    func intPair(_ key: String) throws -> (first: Int, second: Int) {
        guard let payload = values[key]?.first else {
            throw ContractOracleError.missing("MP4 intPair \(key)")
        }
        switch payload.count {
        case 8:
            return (Int(payload[2]) << 8 | Int(payload[3]), Int(payload[4]) << 8 | Int(payload[5]))
        case 6:
            // Some native writers use a compact layout without the trailing pair.
            return (Int(payload[2]) << 8 | Int(payload[3]), Int(payload[4]) << 8 | Int(payload[5]))
        default:
            throw ContractOracleError.malformed("MP4 intPair \(key) has an unsupported length")
        }
    }
}

struct ContractID3FrameEvidence: Equatable {
    var id: String
    var status: UInt8
    var format: UInt8
    var groupID: UInt8?
    var payload: Data
    var text: String?
}

struct ContractID3Oracle {
    let version: Int
    let tagFlags: UInt8
    let frames: [ContractID3FrameEvidence]
    let audio: Data

    static func read(_ url: URL) throws -> ContractID3Oracle {
        let ext = url.pathExtension.lowercased()
        let data: Data
        if ["wav", "aiff"].contains(ext) {
            let riff = try ContractRIFFOracle.read(url)
            data = try riff.id3Tag()
            return try parse(data, audio: riff.audio)
        }
        let bytes = try ContractFixture.bytes(url)
        guard bytes.count >= 10, bytes.prefix(3) == Data("ID3".utf8) else {
            throw ContractOracleError.missing("leading ID3 tag")
        }
        let end = 10 + (try ContractFixture.readSynchsafe(bytes, 6))
        guard end <= bytes.count else { throw ContractOracleError.malformed("ID3 tag exceeds file") }
        return try parse(Data(bytes.prefix(end)), audio: Data(bytes.dropFirst(end)))
    }

    static func parse(_ tag: Data, audio: Data) throws -> ContractID3Oracle {
        guard tag.count >= 10, tag.prefix(3) == Data("ID3".utf8) else {
            throw ContractOracleError.malformed("missing ID3 header")
        }
        let version = Int(tag[3])
        let revision = tag[4]
        let flags = tag[5]
        guard (version == 3 || version == 4), revision == 0 else {
            throw ContractOracleError.malformed("unsupported ID3 version/flags")
        }
        let size = try ContractFixture.readSynchsafe(tag, 6)
        guard 10 + size <= tag.count else { throw ContractOracleError.malformed("ID3 extended size exceeds tag") }
        let end = 10 + size
        var offset = 10
        var frames: [ContractID3FrameEvidence] = []
        while offset < end, tag[offset] != 0 {
            guard end - offset >= 10, let id = String(data: tag[offset..<(offset + 4)], encoding: .ascii) else {
                throw ContractOracleError.malformed("truncated ID3 frame header")
            }
            let frameSize = version == 4
                ? (try ContractFixture.readSynchsafe(tag, offset + 4))
                : (try ContractFixture.integer(tag, offset + 4, 4))
            let status = tag[offset + 8]
            let format = tag[offset + 9]
            let start = offset + 10
            guard frameSize <= end - start else {
                throw ContractOracleError.malformed("ID3 frame \(id) exceeds tag")
            }
            var payloadStart = start
            var groupID: UInt8?
            if version == 3, format & 0x20 != 0 {
                guard frameSize >= 1 else { throw ContractOracleError.malformed("grouped ID3 frame is empty") }
                groupID = tag[payloadStart]
                payloadStart += 1
            } else if version == 4, format & 0x40 != 0 {
                guard frameSize >= 1 else { throw ContractOracleError.malformed("grouped ID3 frame is empty") }
                groupID = tag[payloadStart]
                payloadStart += 1
            }
            let payload = Data(tag[payloadStart..<(start + frameSize)])
            var text: String?
            if id.hasPrefix("T") || id == "GRP1" {
                if let encoding = payload.first {
                    let body = Data(payload.dropFirst())
                    switch encoding {
                    case 0: text = String(data: body, encoding: .isoLatin1)
                    case 3: text = String(data: body, encoding: .utf8)
                    default: text = nil
                    }
                }
            }
            frames.append(.init(id: id, status: status, format: format, groupID: groupID, payload: payload, text: text))
            offset = start + frameSize
        }
        return .init(version: version, tagFlags: flags, frames: frames, audio: audio)
    }

    func frame(_ id: String) -> ContractID3FrameEvidence? {
        frames.first { $0.id == id }
    }

    func frames(_ id: String) -> [ContractID3FrameEvidence] {
        frames.filter { $0.id == id }
    }
}

struct ContractFLACOracle {
    let comments: [String: [String]]
    let otherBlocks: [Int: [Data]]
    let audio: Data

    static func read(_ url: URL) throws -> ContractFLACOracle {
        let data = try ContractFixture.bytes(url)
        guard data.prefix(4) == Data("fLaC".utf8) else { throw ContractOracleError.malformed("missing fLaC") }
        var offset = 4
        var comments: [String: [String]] = [:]
        var blocks: [Int: [Data]] = [:]
        var commentsSeen = false
        while true {
            guard data.count - offset >= 4 else { throw ContractOracleError.malformed("truncated FLAC block header") }
            let header = data[offset]
            let type = Int(header & 0x7F)
            let size = Int(data[(offset + 1)..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) })
            offset += 4
            guard size <= data.count - offset else { throw ContractOracleError.malformed("FLAC block exceeds file") }
            let block = Data(data[offset..<(offset + size)])
            offset += size
            if type == 4 {
                guard !commentsSeen else { throw ContractOracleError.malformed("duplicate Vorbis comment block") }
                commentsSeen = true
                var cursor = 0
                func take(_ count: Int) throws -> Data {
                    guard count >= 0, count <= block.count - cursor else {
                        throw ContractOracleError.malformed("Vorbis comment exceeds block")
                    }
                    defer { cursor += count }
                    return Data(block[cursor..<(cursor + count)])
                }
                func length() throws -> Int {
                    let bytes = try take(4)
                    return bytes.reversed().reduce(0) { ($0 << 8) | Int($1) }
                }
                func string() throws -> String {
                    let count = try length()
                    guard let text = String(data: try take(count), encoding: .utf8) else {
                        throw ContractOracleError.malformed("Vorbis comment is not UTF-8")
                    }
                    return text
                }
                _ = try string()
                let count = try length()
                guard count <= (block.count - cursor) / 4 else {
                    throw ContractOracleError.malformed("Vorbis comment count exceeds block")
                }
                for _ in 0..<count {
                    let entry = try string()
                    guard let equals = entry.firstIndex(of: "=") else {
                        throw ContractOracleError.malformed("Vorbis entry has no equals")
                    }
                    comments[String(entry[..<equals]), default: []].append(String(entry[entry.index(after: equals)...]))
                }
                guard cursor == block.count else {
                    throw ContractOracleError.malformed("Vorbis comment trailing bytes")
                }
            } else if type != 1 {
                blocks[type, default: []].append(block)
            }
            if header & 0x80 != 0 { break }
        }
        guard offset < data.count else { throw ContractOracleError.malformed("FLAC has no audio frames") }
        return .init(comments: comments, otherBlocks: blocks, audio: Data(data[offset...]))
    }

    func values(_ key: String) -> [String] {
        comments[key] ?? []
    }
}
