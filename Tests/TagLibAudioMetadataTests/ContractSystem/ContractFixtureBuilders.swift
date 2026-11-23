import Foundation
import Testing

/// Bounded, independently specified fixture builders. Every builder writes a
/// complete container layout and the oracle verifies it before the public call
/// under test is made.
enum ContractFixture {
    static func url(_ ext: String, name: String = "testAudioFile") throws -> URL {
        try #require(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: name, withExtension: ext),
            "missing committed fixture \(name).\(ext)"
        )
    }

    static func copy(_ ext: String, name: String = "testAudioFile") throws -> URL {
        let source = try url(ext, name: name)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Contract-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let copy = directory.appendingPathComponent("fixture.\(ext)")
        try FileManager.default.copyItem(at: source, to: copy)
        return copy
    }

    static func withCopy(_ ext: String, name: String = "testAudioFile", _ body: (URL) throws -> Void) throws {
        let url = try copy(ext, name: name)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try body(url)
    }

    static func bytes(_ url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    static func number(_ value: UInt64, bytes count: Int, little: Bool = false) -> Data {
        Data((0..<count).map {
            UInt8(truncatingIfNeeded: value >> UInt64((little ? $0 : count - 1 - $0) * 8))
        })
    }

    static func integer(_ data: Data, _ offset: Int, _ count: Int, little: Bool = false) throws -> Int {
        guard offset >= 0, count > 0, count <= 8, offset <= data.count, count <= data.count - offset else {
            throw ContractOracleError.malformed("integer read outside bounds")
        }
        let slice = data[offset..<(offset + count)]
        let ordered = little ? Array(slice.reversed()) : Array(slice)
        let value = ordered.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard value <= UInt64(Int.max) else { throw ContractOracleError.malformed("integer exceeds Int") }
        return Int(value)
    }

    static func synchsafe(_ value: Int) throws -> Data {
        guard value >= 0, value <= 0x0FFF_FFFF else {
            throw ContractOracleError.malformed("synchsafe value outside 28-bit range")
        }
        return Data([
            UInt8((value >> 21) & 0x7F),
            UInt8((value >> 14) & 0x7F),
            UInt8((value >> 7) & 0x7F),
            UInt8(value & 0x7F),
        ])
    }

    static func readSynchsafe(_ data: Data, _ offset: Int) throws -> Int {
        guard offset >= 0, offset <= data.count, 4 <= data.count - offset else {
            throw ContractOracleError.malformed("synchsafe read outside bounds")
        }
        let bytes = data[offset..<(offset + 4)]
        guard bytes.allSatisfy({ $0 < 0x80 }) else {
            throw ContractOracleError.malformed("non-synchsafe byte")
        }
        return bytes.reduce(0) { ($0 << 7) | Int($1) }
    }
}

enum ContractOracleError: Error, CustomStringConvertible {
    case malformed(String)
    case missing(String)
    case unexpected(String)

    var description: String {
        switch self {
        case .malformed(let reason): "malformed native evidence: \(reason)"
        case .missing(let reason): "missing native evidence: \(reason)"
        case .unexpected(let reason): "unexpected native evidence: \(reason)"
        }
    }
}

// MARK: - ID3 builders

struct ContractID3Frame: Equatable {
    var id: String
    var payload: Data
    var status: UInt8 = 0
    var format: UInt8 = 0
    var groupID: UInt8?
}

enum ContractID3Seed {
    static func text(_ id: String, _ text: String, encoding: UInt8 = 3) -> Data {
        Data([encoding]) + Data(text.utf8)
    }

    static func frame(
        _ id: String,
        _ payload: Data,
        status: UInt8 = 0,
        format: UInt8 = 0,
        groupID: UInt8? = nil
    ) -> Data {
        var body = payload
        if let groupID { body = Data([groupID]) + body }
        return Data(id.utf8) + ContractFixture.number(UInt64(body.count), bytes: 4)
            + Data([status, format]) + body
    }

    static func v24Frame(
        _ id: String,
        _ payload: Data,
        status: UInt8 = 0,
        format: UInt8 = 0,
        groupID: UInt8? = nil
    ) throws -> Data {
        var body = payload
        if let groupID { body = Data([groupID]) + body }
        return Data(id.utf8) + (try ContractFixture.synchsafe(body.count))
            + Data([status, format]) + body
    }

    static func tag(_ frames: Data, version: Int, tagFlags: UInt8 = 0) throws -> Data {
        guard version == 3 || version == 4 else {
            throw ContractOracleError.malformed("unsupported ID3 seed version")
        }
        return Data([0x49, 0x44, 0x33, UInt8(version), 0, tagFlags])
            + (try ContractFixture.synchsafe(frames.count)) + frames
    }

    static func seedMP3(_ url: URL, tag: Data) throws {
        var data = try ContractFixture.bytes(url)
        if data.count >= 10, data.prefix(3) == Data("ID3".utf8) {
            let end = 10 + (try ContractFixture.readSynchsafe(data, 6))
            guard end <= data.count else { throw ContractOracleError.malformed("existing tag exceeds file") }
            data = Data(data.dropFirst(end))
        }
        try (tag + data).write(to: url)
    }

    static func seedContainer(_ url: URL, tag: Data) throws {
        let oracle = try ContractRIFFOracle.read(url)
        var chunks = oracle.chunks.filter { $0.id != "ID3 " }
        var chunk = Data("ID3 ".utf8)
            + ContractFixture.number(UInt64(tag.count), bytes: 4, little: oracle.isLittleEndian)
            + tag
        if tag.count % 2 != 0 { chunk.append(0) }
        chunks.insert(ContractRIFFChunk(id: "ID3 ", payload: tag, raw: chunk), at: 0)
        try ContractRIFFOracle.write(oracle: oracle, chunks: chunks, to: url)
    }
}

// MARK: - MP4 builder

struct ContractMP4Item {
    enum Value {
        case text(String)
        case textList([String])
        case intPair(first: Int, second: Int)
        case integer(Int, byteCount: Int)
        case boolean(Bool)
        case binary(Data)
        case jpegCovers([Data])
    }

    var key: String
    var value: Value
}

enum ContractMP4Seed {
    static func seed(_ items: [ContractMP4Item], to url: URL) throws {
        let data = try ContractFixture.bytes(url)
        let top = try ContractMP4Oracle.atoms(data, 0..<data.count)
        guard let moov = top.first(where: { $0.type == "moov" }) else {
            throw ContractOracleError.malformed("fixture has no moov")
        }
        let newILST = atom("ilst", try makeILST(items))
        let moovChildren = try ContractMP4Oracle.atoms(data, moov.payload)
        let newMeta: Data
        let newUdta: Data
        if let udta = moovChildren.first(where: { $0.type == "udta" }) {
            let udtaChildren = try ContractMP4Oracle.atoms(data, udta.payload)
            if let meta = udtaChildren.first(where: { $0.type == "meta" }) {
                guard meta.payload.count >= 4 else {
                    throw ContractOracleError.malformed("meta is shorter than version/flags")
                }
                let metaChildrenRange = (meta.payload.lowerBound + 4)..<meta.payload.upperBound
                let newMetaChildren = try replaceOrAppend(
                    in: data, range: metaChildrenRange, type: "ilst", replacement: newILST
                )
                newMeta = atom("meta", Data([0, 0, 0, 0]) + newMetaChildren)
            } else {
                newMeta = atom("meta", Data([0, 0, 0, 0]) + newILST)
            }
            let newUdtaChildren = try replaceOrAppend(
                in: data, range: udta.payload, type: "meta", replacement: newMeta
            )
            newUdta = atom("udta", newUdtaChildren)
        } else {
            newMeta = atom("meta", Data([0, 0, 0, 0]) + newILST)
            newUdta = atom("udta", newMeta)
        }
        let newMoovChildren = try replaceOrAppend(
            in: data, range: moov.payload, type: "udta", replacement: newUdta
        )
        let newMoov = atom("moov", newMoovChildren)
        var output = Data()
        for candidate in top {
            if candidate.type == "moov" { output += newMoov } else { output += Data(data[candidate.range]) }
        }
        try output.write(to: url)
    }

    private static func replaceOrAppend(
        in data: Data, range: Range<Int>, type: String, replacement: Data
    ) throws -> Data {
        let children = try ContractMP4Oracle.atoms(data, range)
        var output = Data()
        var replaced = false
        for child in children {
            if child.type == type {
                if !replaced {
                    output += replacement
                    replaced = true
                }
            } else {
                output += Data(data[child.range])
            }
        }
        if !replaced { output += replacement }
        return output
    }

    private static func atom(_ type: String, _ payload: Data) -> Data {
        guard let typeBytes = type.data(using: .isoLatin1), typeBytes.count == 4 else {
            preconditionFailure("MP4 atom type must be four ISO-Latin-1 bytes")
        }
        return ContractFixture.number(UInt64(payload.count + 8), bytes: 4) + typeBytes + payload
    }

    private static func makeILST(_ items: [ContractMP4Item]) throws -> Data {
        var result = Data()
        for item in items {
            switch item.value {
            case .text(let text):
                result += makeDataItem(item.key, type: 1, payload: Data(text.utf8))
            case .textList(let values):
                for value in values {
                    result += makeDataItem(item.key, type: 1, payload: Data(value.utf8))
                }
            case .intPair(let first, let second):
                guard (0...65535).contains(first), (0...65535).contains(second) else {
                    throw ContractOracleError.malformed("MP4 intPair seed outside uint16")
                }
                let payload = Data([0, 0])
                    + ContractFixture.number(UInt64(first), bytes: 2)
                    + ContractFixture.number(UInt64(second), bytes: 2)
                    + Data([0, 0])
                result += makeDataItem(item.key, type: 0, payload: payload)
            case .integer(let value, let byteCount):
                guard value >= 0, (1...8).contains(byteCount) else {
                    throw ContractOracleError.malformed("MP4 integer seed outside bounds")
                }
                result += makeDataItem(item.key, type: 21,
                                       payload: ContractFixture.number(UInt64(value), bytes: byteCount))
            case .boolean(let flag):
                result += makeDataItem(item.key, type: 21, payload: Data([flag ? 1 : 0]))
            case .binary(let payload):
                result += makeDataItem(item.key, type: 0, payload: payload)
            case .jpegCovers(let covers):
                let fields = covers.reduce(into: Data()) { atoms, cover in
                    atoms += makeDataAtom(type: 13, payload: cover)
                }
                result += atom(item.key, fields)
            }
        }
        return result
    }

    private static func makeDataAtom(type: Int, payload: Data) -> Data {
        atom("data", ContractFixture.number(UInt64(type), bytes: 4) + Data([0, 0, 0, 0]) + payload)
    }

    private static func makeDataItem(_ key: String, type: Int, payload: Data) -> Data {
        let dataAtom = makeDataAtom(type: type, payload: payload)
        if key.hasPrefix("----:") {
            let parts = key.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else { preconditionFailure("freeform identity must have mean and name") }
            let mean = atom("mean", Data([0, 0, 0, 0]) + Data(parts[1].utf8))
            let name = atom("name", Data([0, 0, 0, 0]) + Data(parts[2].utf8))
            return atom("----", mean + name + dataAtom)
        }
        precondition(key.data(using: .isoLatin1)?.count == 4, "standard MP4 atom key must be four ISO-Latin-1 bytes")
        return atom(key, dataAtom)
    }
}

// MARK: - FLAC builder

enum ContractFLACSeed {
    static func seed(comments: [String: [String]], vendor: String = "contract-fixture", to url: URL) throws {
        let data = try ContractFixture.bytes(url)
        guard data.prefix(4) == Data("fLaC".utf8) else {
            throw ContractOracleError.malformed("missing fLaC marker")
        }
        var offset = 4
        var blocks: [(type: Int, payload: Data, last: Bool)] = []
        while true {
            guard data.count - offset >= 4 else { throw ContractOracleError.malformed("truncated FLAC block header") }
            let header = data[offset]
            let type = Int(header & 0x7F)
            let size = Int(data[(offset + 1)..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) })
            offset += 4
            guard size <= data.count - offset else { throw ContractOracleError.malformed("FLAC block exceeds file") }
            blocks.append((type, Data(data[offset..<(offset + size)]), header & 0x80 != 0))
            offset += size
            if header & 0x80 != 0 { break }
        }
        var comment = Data()
        let vendorBytes = Data(vendor.utf8)
        comment += ContractFixture.number(UInt64(vendorBytes.count), bytes: 4, little: true) + vendorBytes
        let entries = comments.keys.sorted().flatMap { key in (comments[key] ?? []).map { "\(key)=\($0)" } }
        comment += ContractFixture.number(UInt64(entries.count), bytes: 4, little: true)
        for entry in entries {
            let bytes = Data(entry.utf8)
            comment += ContractFixture.number(UInt64(bytes.count), bytes: 4, little: true) + bytes
        }
        var rebuilt: [(type: Int, payload: Data)] = []
        var inserted = false
        for block in blocks {
            if block.type == 4 {
                if !inserted {
                    rebuilt.append((4, comment))
                    inserted = true
                }
            } else if block.type != 1 {
                rebuilt.append((block.type, block.payload))
            }
        }
        if !inserted { rebuilt.append((4, comment)) }
        var output = Data("fLaC".utf8)
        for (index, block) in rebuilt.enumerated() {
            let last: UInt8 = index == rebuilt.count - 1 ? 0x80 : 0
            output.append(last | UInt8(block.type))
            output += ContractFixture.number(UInt64(block.payload.count), bytes: 3)
            output += block.payload
        }
        output += Data(data[offset...])
        try output.write(to: url)
    }
}

// MARK: - RIFF builder/reader

struct ContractRIFFChunk: Equatable {
    var id: String
    var payload: Data
    var raw: Data
}

struct ContractRIFFOracle {
    let isLittleEndian: Bool
    let chunks: [ContractRIFFChunk]
    let declaredSize: Int

    static func read(_ url: URL) throws -> ContractRIFFOracle {
        let data = try ContractFixture.bytes(url)
        let ext = url.pathExtension.lowercased()
        let little = ext == "wav"
        let marker = little ? Data("RIFF".utf8) : Data("FORM".utf8)
        guard data.count >= 12, data.prefix(4) == marker else {
            throw ContractOracleError.malformed("missing RIFF/FORM marker")
        }
        let declared = try ContractFixture.integer(data, 4, 4, little: little)
        guard declared <= data.count - 8 else {
            throw ContractOracleError.malformed("declared container size exceeds file")
        }
        var offset = 12
        var chunks: [ContractRIFFChunk] = []
        while offset < data.count {
            guard data.count - offset >= 8 else { throw ContractOracleError.malformed("truncated chunk header") }
            let id = String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
            let size = try ContractFixture.integer(data, offset + 4, 4, little: little)
            let start = offset + 8
            guard size <= data.count - start else { throw ContractOracleError.malformed("chunk exceeds file") }
            let payload = Data(data[start..<(start + size)])
            let padded = size + size % 2
            guard padded <= data.count - start else { throw ContractOracleError.malformed("padded chunk exceeds file") }
            let raw = Data(data[offset..<(start + padded)])
            chunks.append(ContractRIFFChunk(id: id, payload: payload, raw: raw))
            offset = start + padded
        }
        return ContractRIFFOracle(isLittleEndian: little, chunks: chunks, declaredSize: declared)
    }

    static func write(oracle: ContractRIFFOracle, chunks: [ContractRIFFChunk], to url: URL) throws {
        let marker = oracle.isLittleEndian ? Data("RIFF".utf8) : Data("FORM".utf8)
        let form = oracle.isLittleEndian ? Data("WAVE".utf8) : Data("AIFF".utf8)
        var body = form
        for chunk in chunks {
            body += chunk.raw
        }
        var output = marker + ContractFixture.number(UInt64(body.count), bytes: 4, little: oracle.isLittleEndian) + body
        if output.count % 2 != 0 { output.append(0) }
        try output.write(to: url)
    }

    func id3Tag() throws -> Data {
        guard let chunk = chunks.first(where: { $0.id == "ID3 " }) else {
            throw ContractOracleError.missing("ID3 chunk")
        }
        return chunk.payload
    }

    var audio: Data {
        let id = isLittleEndian ? "data" : "SSND"
        return chunks.first(where: { $0.id == id })?.payload ?? Data()
    }
}
