import Foundation
import Testing
import TagLibAudioMetadata

// A deliberately bounded oracle for ASF header metadata, not an ASF decoder.
// Wire layouts: ASF specification 01.20.05, sections 3.11, 4.7 and 4.8.
enum IndependentASF {
    struct Attribute: Equatable {
        var name: String
        var type: Int
        var language: Int
        var stream: Int
        var value: Data
    }
    struct Object {
        var id: Data
        var payload: Data
        var bytes: Data { id + HardeningFixture.number(UInt64(payload.count + 24), bytes: 8, little: true) + payload }
    }
    static func hex(_ value: String) -> Data {
        let chars = Array(value)
        return Data(stride(from: 0, to: chars.count, by: 2).compactMap { UInt8(String(chars[$0...($0 + 1)]), radix: 16) })
    }
    static let header = hex("3026b2758e66cf11a6d900aa0062ce6c")
    static let extended = hex("40a4d0d207e3d21197f000a0c95ea850")
    static let extensionID = hex("b503bf5f2ea9cf118ee300c00c205365")
    static let metadata = hex("eacbf8c5af5b77488467aa8c44fa4cca")
    static let library = hex("941c23449894d149a1411d134e457054")
    static let languages = hex("a946437ce0effc4bb229393ede415c85")
    static let fileProperties = hex("a1dcab8c47a9cf118ee400c00c205365")

    struct Cursor {
        let data: Data
        var offset = 0
        mutating func take(_ count: Int) throws -> Data {
            guard count >= 0, offset <= data.count, count <= data.count - offset else { throw HardeningFixture.Invalid.container }
            defer { offset += count }
            return Data(data[offset..<(offset + count)])
        }
        mutating func int(_ count: Int) throws -> Int {
            try HardeningFixture.integer(take(count), 0, count, little: true)
        }
        mutating func text(_ count: Int) throws -> String {
            guard count % 2 == 0, let result = String(data: try take(count), encoding: .utf16LittleEndian) else { throw HardeningFixture.Invalid.container }
            return result.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        }
    }

    static func objects(_ bytes: Data) throws -> [Object] {
        var c = Cursor(data: bytes)
        var result: [Object] = []
        while c.offset < bytes.count {
            let id = try c.take(16)
            let size = try c.int(8)
            guard size >= 24 else { throw HardeningFixture.Invalid.container }
            result.append(Object(id: id, payload: try c.take(size - 24)))
        }
        return result
    }

    static func headerState(_ bytes: Data) throws -> (children: [Object], tail: Data) {
        var c = Cursor(data: bytes)
        guard try c.take(16) == header else { throw HardeningFixture.Invalid.container }
        let size = try c.int(8)
        let count = try c.int(4)
        guard try c.take(2) == Data([1, 2]), size >= 30 else { throw HardeningFixture.Invalid.container }
        let children = try objects(c.take(size - 30))
        guard children.count == count else { throw HardeningFixture.Invalid.container }
        return (children, try c.take(bytes.count - c.offset))
    }

    static func attributes(_ bytes: Data) throws -> [Attribute] {
        let state = try headerState(bytes)
        var result: [Attribute] = []
        func parse(_ object: Object, depth: Int = 0) throws {
            guard depth <= 1 else { throw HardeningFixture.Invalid.container }
            if object.id == extensionID {
                var c = Cursor(data: object.payload)
                _ = try c.take(18)
                let length = try c.int(4)
                let nested = try objects(c.take(length))
                guard c.offset == object.payload.count else { throw HardeningFixture.Invalid.container }
                for child in nested { try parse(child, depth: depth + 1) }
            } else if [extended, metadata, library].contains(object.id) {
                var c = Cursor(data: object.payload)
                let count = try c.int(2)
                guard count <= object.payload.count / 6 else { throw HardeningFixture.Invalid.container }
                for _ in 0..<count {
                    let language = object.id == extended ? 0 : try c.int(2)
                    let stream = object.id == extended ? 0 : try c.int(2)
                    let nameLength = try c.int(2)
                    let name: String
                    let type: Int
                    let length: Int
                    if object.id == extended {
                        name = try c.text(nameLength)
                        type = try c.int(2)
                        length = try c.int(2)
                    } else {
                        type = try c.int(2)
                        length = try c.int(4)
                        name = try c.text(nameLength)
                    }
                    let value = try c.take(length)
                    guard (0...6).contains(type), object.id != metadata || language == 0 else { throw HardeningFixture.Invalid.container }
                    result.append(.init(name: name, type: type, language: language, stream: stream, value: value))
                }
                guard c.offset == object.payload.count else { throw HardeningFixture.Invalid.container }
            }
        }
        for child in state.children { try parse(child) }
        return result
    }

    static func text(_ value: String) -> Data { Data(value.utf16.flatMap { [UInt8(truncatingIfNeeded: $0), UInt8($0 >> 8)] }) + Data([0, 0]) }

    static func seed(_ attributes: [Attribute], at url: URL) throws {
        let old = try Data(contentsOf: url)
        var state = try headerState(old)
        var records = HardeningFixture.number(UInt64(attributes.count), bytes: 2, little: true)
        for a in attributes {
            let name = text(a.name)
            for n in [a.language, a.stream, name.count, a.type] { records += HardeningFixture.number(UInt64(n), bytes: 2, little: true) }
            records += HardeningFixture.number(UInt64(a.value.count), bytes: 4, little: true) + name + a.value
        }
        var languagePayload = HardeningFixture.number(3, bytes: 2, little: true)
        for locale in ["en-US", "de-DE", "fr-FR"] {
            let value = text(locale)
            languagePayload += Data([UInt8(value.count)]) + value
        }
        let additions = Object(id: languages, payload: languagePayload).bytes + Object(id: library, payload: records).bytes
        if let index = state.children.firstIndex(where: { $0.id == extensionID }) {
            var cursor = Cursor(data: state.children[index].payload)
            let reserved = try cursor.take(18)
            let length = try cursor.int(4)
            var nested = try objects(cursor.take(length))
            // TagLib creates an empty library object when writing the initial
            // picture. Replace that object rather than creating an invalid duplicate.
            for object in nested where object.id == library {
                guard object.payload == Data([0, 0]) else { throw HardeningFixture.Invalid.container }
            }
            guard !nested.contains(where: { $0.id == languages }) else { throw HardeningFixture.Invalid.container }
            nested.removeAll { $0.id == library }
            let contents = nested.reduce(Data()) { $0 + $1.bytes } + additions
            state.children[index].payload = reserved
                + HardeningFixture.number(UInt64(contents.count), bytes: 4, little: true) + contents
        } else {
            let reserved = hex("11d2d3abbaa9cf118ee600c00c205365") + Data([6, 0])
            state.children.append(Object(id: extensionID, payload: reserved
                + HardeningFixture.number(UInt64(additions.count), bytes: 4, little: true) + additions))
        }
        func render() -> Data {
            let children = state.children.reduce(Data()) { $0 + $1.bytes }
            return header + HardeningFixture.number(UInt64(children.count + 30), bytes: 8, little: true)
                + HardeningFixture.number(UInt64(state.children.count), bytes: 4, little: true) + Data([1, 2]) + children + state.tail
        }
        let size = render().count
        guard let index = state.children.firstIndex(where: { $0.id == fileProperties }),
              state.children[index].payload.count >= 24 else { throw HardeningFixture.Invalid.container }
        state.children[index].payload.replaceSubrange(16..<24, with: HardeningFixture.number(UInt64(size), bytes: 8, little: true))
        try render().write(to: url)
    }
}

struct HardeningASFTests {
    @Test func nativeAttributeIdentityTypesAndAudioSurviveTargetedEdits() throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            let cover = try Data(contentsOf: HardeningFixture.url("jpg", name: "testCover"))
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                .init(artwork: [.init(pictureTypeCode: 4, mimeType: "image/jpeg", description: "ASF back", data: cover)]), to: url)
            let attributes: [IndependentASF.Attribute] = [
                .init(name: "HARDEN_SHARED", type: 0, language: 1, stream: 1, value: IndependentASF.text("Target")),
                .init(name: "HARDEN_SHARED", type: 0, language: 2, stream: 1, value: IndependentASF.text("Sibling language")),
                .init(name: "HARDEN_SHARED", type: 1, language: 1, stream: 1, value: Data([0, 255, 2, 3])),
                .init(name: "HARDEN_GUID", type: 6, language: 0, stream: 0, value: Data(0..<16)),
                .init(name: "HARDEN_WORD", type: 5, language: 0, stream: 1, value: Data([42, 0])),
                .init(name: "HARDEN_BOOL", type: 2, language: 0, stream: 1, value: Data([1, 0])),
                .init(name: "HARDEN_DWORD", type: 3, language: 0, stream: 1, value: Data([7, 0, 0, 0])),
                .init(name: "HARDEN_QWORD", type: 4, language: 0, stream: 1, value: Data([8, 0, 0, 0, 0, 0, 0, 0]))
            ]
            try IndependentASF.seed(attributes, at: url)
            let beforeBytes = try Data(contentsOf: url)
            let before = try IndependentASF.attributes(beforeBytes)
            for attribute in attributes { #expect(before.contains(attribute)) }
            let pictures = before.filter { $0.name == "WM/Picture" }
            #expect(pictures.count == 1)
            #expect(pictures.first?.value.range(of: cover) != nil)
            let read = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
            #expect(read.asfAttributes.contains { $0.key == "HARDEN_GUID" && $0.type == "guid" && $0.data == Data(0..<16) })
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                .init(key: "HARDEN_SHARED", type: "string", value: "Updated target", language: 1, stream: 1)
            ]), to: url)
            let afterBytes = try Data(contentsOf: url)
            let after = try IndependentASF.attributes(afterBytes)
            var updated = attributes[0]
            updated.value = IndependentASF.text("Updated target")
            #expect(after.contains(updated))
            #expect(!after.contains(attributes[0]))
            for attribute in attributes.dropFirst() { #expect(after.contains(attribute), "\(attribute.name), type \(attribute.type)") }
            #expect(after.filter { $0.name == "WM/Picture" } == pictures)
            #expect(try IndependentASF.headerState(afterBytes).tail == IndependentASF.headerState(beforeBytes).tail)
        }
    }

    @Test func wordAttributeUpdateRetainsNativeTypeAndCardinality() throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            try IndependentASF.seed([
                .init(name: "HARDEN_WORD", type: 5, language: 0, stream: 1, value: Data([42, 0]))
            ], at: url)
            let original = try IndependentASF.attributes(Data(contentsOf: url)).filter { $0.name == "HARDEN_WORD" }
            #expect(original.count == 1 && original.first?.type == 5)
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                .init(key: "HARDEN_WORD", type: "int", value: "7", language: 0, stream: 1)
            ]), to: url)
            let after = try IndependentASF.attributes(Data(contentsOf: url)).filter { $0.name == "HARDEN_WORD" }
            #expect(after == [.init(name: "HARDEN_WORD", type: 5, language: 0, stream: 1, value: Data([7, 0]))])
            let bytes = try Data(contentsOf: url)
            #expect(throws: (any Error).self) {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                    .init(key: "HARDEN_WORD", type: "int", value: "65536", language: 0, stream: 1)
                ]), to: url, verifyAfterWrite: false)
            }
            #expect(try Data(contentsOf: url) == bytes)
        }
    }

    @Test func ambiguousIntegerWidthsRejectBeforeCommit() throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            try IndependentASF.seed([
                .init(name: "HARDEN_INT", type: 5, language: 0, stream: 1, value: Data([42, 0])),
                .init(name: "HARDEN_INT", type: 3, language: 0, stream: 1, value: Data([43, 0, 0, 0]))
            ], at: url)
            let bytes = try Data(contentsOf: url)
            #expect(try IndependentASF.attributes(bytes).filter { $0.name == "HARDEN_INT" }.count == 2)
            #expect(throws: (any Error).self) {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                    .init(key: "HARDEN_INT", type: "int", value: "7", language: 0, stream: 1)
                ]), to: url, verifyAfterWrite: false)
            }
            #expect(try Data(contentsOf: url) == bytes)
        }
    }

    @Test func independentParserRejectsMalformedObjectAndRecordBounds() throws {
        let bytes = try Data(contentsOf: HardeningFixture.url("wma", name: "testAudioFile"))
        for length in [0, 15, 23, 29, bytes.count - 1] {
            #expect(throws: (any Error).self) {
                let truncated = Data(bytes.prefix(length))
                _ = try IndependentASF.objects(truncated)
                _ = try IndependentASF.attributes(truncated)
            }
        }
        var badSize = bytes
        badSize.replaceSubrange(16..<24, with: Data(repeating: 255, count: 8))
        #expect(throws: (any Error).self) { _ = try IndependentASF.attributes(badSize) }
        let record = IndependentASF.Object(id: IndependentASF.library, payload: Data([255, 255]))
        let malformed = IndependentASF.header + HardeningFixture.number(UInt64(30 + record.bytes.count), bytes: 8, little: true)
            + HardeningFixture.number(1, bytes: 4, little: true) + Data([1, 2]) + record.bytes
        #expect(throws: (any Error).self) { _ = try IndependentASF.attributes(malformed) }
    }
}
