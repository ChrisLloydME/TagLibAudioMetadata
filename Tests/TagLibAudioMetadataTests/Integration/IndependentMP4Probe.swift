import Foundation
import Testing
import TagLibAudioMetadata

/// Minimal test-only ISO BMFF reader. No TagLib/bridge decoding is used to
/// locate native owners, decode expected values, or compare media payloads.
struct IndependentMP4Probe {
    enum Invalid: Error { case atom }
    struct Atom { let type: String; let payload: Range<Int> }
    let items: [String: [Data]]
    let values: [String: [Data]]
    let audio: [Data]

    private static func atoms(_ data: Data, _ range: Range<Int>) throws -> [Atom] {
        var result: [Atom] = []
        var offset = range.lowerBound
        while offset < range.upperBound {
            guard range.upperBound - offset >= 8 else { throw Invalid.atom }
            guard let type = String(data: data[(offset + 4)..<(offset + 8)], encoding: .isoLatin1) else { throw Invalid.atom }
            var size = data[offset..<(offset + 4)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            var header = 8
            if size == 1 {
                guard range.upperBound - offset >= 16 else { throw Invalid.atom }
                size = data[(offset + 8)..<(offset + 16)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
                header = 16
            } else if size == 0 { size = UInt64(range.upperBound - offset) }
            guard size >= header && size <= UInt64(range.upperBound - offset) else { throw Invalid.atom }
            result.append(.init(type: type, payload: (offset + header)..<(offset + Int(size))))
            offset += Int(size)
        }
        return result
    }

    static func read(_ url: URL, allowingAbsentMetadata: Bool = false) throws -> Self {
        let data = try Data(contentsOf: url)
        let top = try atoms(data, 0..<data.count)
        let audio = top.filter { $0.type == "mdat" }.map { Data(data[$0.payload]) }
        guard !audio.isEmpty else { throw Invalid.atom }
        var children = top
        for name in ["moov", "udta", "meta", "ilst"] {
            guard let container = children.first(where: { $0.type == name }) else {
                // Erase may legitimately remove udta/meta/ilst. Keep moov,
                // mdat and every present atom's bounds mandatory.
                if allowingAbsentMetadata && name != "moov" {
                    return Self(items: [:], values: [:], audio: audio)
                }
                throw Invalid.atom
            }
            let start = container.payload.lowerBound + (name == "meta" ? 4 : 0)
            guard start <= container.payload.upperBound else { throw Invalid.atom }
            children = try atoms(data, start..<container.payload.upperBound)
        }
        var items: [String: [Data]] = [:]
        var values: [String: [Data]] = [:]
        for item in children {
            let fields = try atoms(data, item.payload)
            var key = item.type
            if key == "----" {
                func text(_ name: String) throws -> String {
                    guard let field = fields.first(where: { $0.type == name }), field.payload.count >= 4,
                          let text = String(data: data[(field.payload.lowerBound + 4)..<field.payload.upperBound], encoding: .utf8) else { throw Invalid.atom }
                    return text
                }
                key += ":" + (try text("mean")) + ":" + (try text("name"))
            }
            items[key, default: []].append(Data(data[item.payload]))
            for field in fields where field.type == "data" {
                guard field.payload.count >= 8 else { throw Invalid.atom }
                values[key, default: []].append(Data(data[(field.payload.lowerBound + 8)..<field.payload.upperBound]))
            }
        }
        return .init(items: items, values: values, audio: audio)
    }

    func expectValue(_ expected: MetadataPatchValue, at key: String) throws {
        if expected == .remove {
            #expect(items[key] == nil, "Removed native owner remains: \(key)")
            return
        }
        let payloads = try #require(values[key], "Missing native owner: \(key)")
        #expect(payloads.count == 1, "Expected one native data atom: \(key)")
        let payload = try #require(payloads.first)
        switch expected {
        case .text(let text): #expect(String(data: payload, encoding: .utf8) == text, "\(key)")
        case .integer(let number):
            try #require(!payload.isEmpty && payload.count <= 8)
            #expect(payload.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) } == UInt64(number), "\(key)")
        case .boolean(let flag):
            try #require(!payload.isEmpty && payload.count <= 8)
            #expect(payload.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) } == (flag ? 1 : 0), "\(key)")
        default: Issue.record("Unhandled oracle value: \(expected)")
        }
    }
}
