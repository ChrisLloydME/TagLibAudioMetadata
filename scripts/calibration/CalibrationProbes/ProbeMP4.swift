import Foundation

enum ProbeMP4 {
    struct Atom {
        let type: String
        let range: Range<Int>
        let payload: Range<Int>
    }

    struct Evidence {
        let values: [String: [Data]]
        let audio: Data

        func text(_ key: String) throws -> String {
            guard let payload = values[key]?.first,
                  let text = String(data: payload, encoding: .utf8) else {
                throw ProbeError.malformed("missing text atom \(key)")
            }
            return text
        }

        func has(_ key: String) -> Bool { values[key] != nil }

        func intPair(_ key: String) throws -> (Int, Int) {
            guard let payload = values[key]?.first, payload.count == 8 || payload.count == 6 else {
                throw ProbeError.malformed("bad intPair \(key)")
            }
            return (Int(payload[2]) << 8 | Int(payload[3]), Int(payload[4]) << 8 | Int(payload[5]))
        }
    }

    static func atoms(_ data: Data, _ range: Range<Int>) throws -> [Atom] {
        var result: [Atom] = []
        var offset = range.lowerBound
        while offset < range.upperBound {
            guard range.upperBound - offset >= 8 else {
                throw ProbeError.malformed("truncated atom header")
            }
            guard let type = String(data: data[(offset + 4)..<(offset + 8)], encoding: .isoLatin1) else {
                throw ProbeError.malformed("invalid atom type")
            }
            var size = data[offset..<(offset + 4)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            var header = 8
            if size == 1 {
                guard range.upperBound - offset >= 16 else { throw ProbeError.malformed("truncated extended atom") }
                size = data[(offset + 8)..<(offset + 16)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
                header = 16
            } else if size == 0 {
                size = UInt64(range.upperBound - offset)
            }
            guard size >= UInt64(header), size <= UInt64(range.upperBound - offset) else {
                throw ProbeError.malformed("atom exceeds parent")
            }
            let end = offset + Int(size)
            result.append(Atom(type: type, range: offset..<end, payload: (offset + header)..<end))
            offset = end
        }
        return result
    }

    static func read(_ url: URL) throws -> Evidence {
        let data = try Data(contentsOf: url)
        let top = try atoms(data, 0..<data.count)
        guard let moov = top.first(where: { $0.type == "moov" }) else { throw ProbeError.malformed("missing moov") }
        let moovChildren = try atoms(data, moov.payload)
        guard let udta = moovChildren.first(where: { $0.type == "udta" }) else {
            return Evidence(values: [:], audio: audio(top: top, data: data))
        }
        let udtaChildren = try atoms(data, udta.payload)
        guard let meta = udtaChildren.first(where: { $0.type == "meta" }), meta.payload.count >= 4 else {
            return Evidence(values: [:], audio: audio(top: top, data: data))
        }
        let metaChildren = try atoms(data, (meta.payload.lowerBound + 4)..<meta.payload.upperBound)
        guard let ilst = metaChildren.first(where: { $0.type == "ilst" }) else {
            return Evidence(values: [:], audio: audio(top: top, data: data))
        }
        var values: [String: [Data]] = [:]
        for item in try atoms(data, ilst.payload) {
            let fields = try atoms(data, item.payload)
            var key = item.type
            if key == "----" {
                func field(_ name: String) throws -> String {
                    guard let entry = fields.first(where: { $0.type == name }), entry.payload.count >= 4,
                          let text = String(data: data[(entry.payload.lowerBound + 4)..<entry.payload.upperBound], encoding: .utf8) else {
                        throw ProbeError.malformed("invalid freeform \(name)")
                    }
                    return text
                }
                key += ":" + (try field("mean")) + ":" + (try field("name"))
            }
            for field in fields where field.type == "data" {
                guard field.payload.count >= 8 else { throw ProbeError.malformed("short data atom") }
                values[key, default: []].append(Data(data[(field.payload.lowerBound + 8)..<field.payload.upperBound]))
            }
        }
        return Evidence(values: values, audio: audio(top: top, data: data))
    }

    private static func audio(top: [Atom], data: Data) -> Data {
        top.filter { $0.type == "mdat" }.reduce(Data()) { $0 + Data(data[$1.payload]) }
    }

    static func seed(
        text: [(String, String)] = [],
        intPairs: [(String, Int, Int)] = [],
        freeforms: [(String, String)] = [],
        binaries: [(String, Data)] = [],
        to url: URL
    ) throws {
        let data = try Data(contentsOf: url)
        let top = try atoms(data, 0..<data.count)
        guard let moov = top.first(where: { $0.type == "moov" }) else { throw ProbeError.malformed("missing moov") }
        var ilst = Data()
        for (key, value) in text {
            ilst += item(key, dataAtom(type: 1, payload: Data(value.utf8)))
        }
        for (key, first, second) in intPairs {
            let payload = Data([0, 0])
                + ProbeFixture.number(UInt64(first), bytes: 2)
                + ProbeFixture.number(UInt64(second), bytes: 2)
                + Data([0, 0])
            ilst += item(key, dataAtom(type: 0, payload: payload))
        }
        for (description, value) in freeforms {
            let mean = atom("mean", Data([0, 0, 0, 0]) + Data("com.apple.iTunes".utf8))
            let name = atom("name", Data([0, 0, 0, 0]) + Data(description.utf8))
            ilst += atom("----", mean + name + dataAtom(type: 1, payload: Data(value.utf8)))
        }
        for (key, payload) in binaries {
            ilst += item(key, dataAtom(type: 0, payload: payload))
        }
        let newILST = atom("ilst", ilst)
        let moovChildren = try atoms(data, moov.payload)
        let newUdta: Data
        if let udta = moovChildren.first(where: { $0.type == "udta" }) {
            let udtaChildren = try atoms(data, udta.payload)
            if let meta = udtaChildren.first(where: { $0.type == "meta" }) {
                let metaChildren = try replaceOrAppend(
                    in: data,
                    range: (meta.payload.lowerBound + 4)..<meta.payload.upperBound,
                    type: "ilst",
                    replacement: newILST
                )
                let newMeta = atom("meta", Data([0, 0, 0, 0]) + metaChildren)
                newUdta = atom("udta", try replaceOrAppend(
                    in: data, range: udta.payload, type: "meta", replacement: newMeta
                ))
            } else {
                newUdta = atom("udta", atom("meta", Data([0, 0, 0, 0]) + newILST))
            }
        } else {
            newUdta = atom("udta", atom("meta", Data([0, 0, 0, 0]) + newILST))
        }
        let newMoov = atom("moov", try replaceOrAppend(
            in: data, range: moov.payload, type: "udta", replacement: newUdta
        ))
        var output = Data()
        for candidate in top {
            output += candidate.type == "moov" ? newMoov : Data(data[candidate.range])
        }
        try output.write(to: url)
    }

    private static func replaceOrAppend(
        in data: Data, range: Range<Int>, type: String, replacement: Data
    ) throws -> Data {
        var output = Data()
        var replaced = false
        for child in try atoms(data, range) {
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
        let typeBytes = type.data(using: .isoLatin1) ?? Data(type.utf8)
        return ProbeFixture.number(UInt64(payload.count + 8), bytes: 4) + typeBytes + payload
    }

    private static func dataAtom(type: Int, payload: Data) -> Data {
        atom("data", ProbeFixture.number(UInt64(type), bytes: 4) + Data([0, 0, 0, 0]) + payload)
    }

    private static func item(_ key: String, _ payload: Data) -> Data {
        atom(key, payload)
    }
}
