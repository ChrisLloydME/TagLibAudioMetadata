import Foundation
import Testing
@testable import TagLibAudioMetadata

struct AutomaticNumberingTests {
    private func copy() throws -> URL {
        let source = try #require(Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a", subdirectory: "Audio")
            ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    private func seed(_ url: URL, track: Bool = true, prefixes: [String], native: (Int, Int)? = nil,
                      values: [String] = ["03/12"]) throws {
        let kind = track ? "TRACKNUMBER_TEXT" : "DISCNUMBER_TEXT"
        var atoms: [StructuredMP4Atom] = [
            .init(key: track ? "trkn" : "disk", type: "intPair", first: native?.0, second: native?.1, remove: native == nil),
            .init(key: track ? "disk" : "trkn", type: "intPair", first: 1, second: 2),
            .init(key: "----:com.apple.iTunes:AUDIOMATOR_" + (track ? "DISCNUMBER_TEXT" : "TRACKNUMBER_TEXT"), type: "stringList", values: ["opaque", "untouched"]),
            .init(key: "----:org.example:AUDIOMATOR_" + kind, type: "stringList", values: ["99/99"]),
            .init(key: "----:com.apple.iTunes:AUDIOMATOR_" + kind.lowercased(), type: "stringList", values: ["77/77"]),
        ]
        atoms += prefixes.map { .init(key: "----:com.apple.iTunes:\($0)_\(kind)", type: "stringList", values: values) }
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: atoms), to: url)
    }

    private func pair(_ probe: IndependentMP4Probe, key: String) throws -> [Int] {
        guard let bytes = probe.values[key]?.first else { return [0, 0] }
        try #require(bytes.count == 6 || bytes.count == 8)
        return [Int(bytes[2]) << 8 | Int(bytes[3]), Int(bytes[4]) << 8 | Int(bytes[5])]
    }

    @Test(arguments: ["AUDIOMATOR", "TAGLIBAUDIOMETADATA", "BOTH"], 0..<7)
    func ordinaryNumberEditsRecoverAndRetireOnlyOwnedGroup(_ prefix: String, _ operation: Int) throws {
        for track in [true, false] {
            let url = try copy(); defer { try? FileManager.default.removeItem(at: url) }
            let prefixes = prefix == "BOTH" ? ["AUDIOMATOR", "TAGLIBAUDIOMETADATA"] : [prefix]
            try seed(url, track: track, prefixes: prefixes)
            let before = try IndependentMP4Probe.read(url)
            for owner in prefixes {
                #expect(before.values["----:com.apple.iTunes:\(owner)_\(track ? "TRACKNUMBER_TEXT" : "DISCNUMBER_TEXT")"] == [Data("03/12".utf8)])
            }
            #expect(try pair(before, key: track ? "disk" : "trkn") == [1, 2])
            let number: MetadataFieldKey = track ? .track : .disc
            let total: MetadataFieldKey = track ? .trackTotal : .discTotal
            let key = track ? "trkn" : "disk"
            var fields: [MetadataFieldKey: MetadataPatchValue]
            let expected: [Int]
            switch operation {
            case 0: fields = [number: .integer(5)]; expected = [5, 12]
            case 1: fields = [total: .integer(15)]; expected = [3, 15]
            case 2: fields = [number: .remove]; expected = [0, 12]
            case 3: fields = [total: .remove]; expected = [3, 0]
            case 4: fields = [number: .remove, total: .remove]; expected = [0, 0]
            case 5: fields = [.title: .text("Unrelated")]; expected = [0, 0]
            default: fields = [number: .integer(5), .title: .text("One transaction")]; expected = [5, 12]
            }
            final class Stages: @unchecked Sendable {
                let lock = NSLock(); var value = 0
                func add() { lock.lock(); value += 1; lock.unlock() }
            }
            let stages = Stages()
            try MetadataFileTransaction.$willStageForTesting.withValue({ _ in stages.add() }) {
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: fields), to: url)
            }
            #expect(stages.value == 1)
            let after = try IndependentMP4Probe.read(url)
            #expect(try pair(after, key: key) == expected)
            if operation == 6 { try after.expectValue(.text("One transaction"), at: "©nam") }
            for identity in before.items.keys where identity != key && identity != "©nam" {
                let owned = prefixes.contains { identity == "----:com.apple.iTunes:\($0)_\(track ? "TRACKNUMBER_TEXT" : "DISCNUMBER_TEXT")" }
                if operation != 5 && owned { #expect(after.items[identity] == nil) }
                else { #expect(after.items[identity] == before.items[identity]) }
            }
            #expect(after.audio == before.audio)
            if operation == 4 {
                let recovered = try TagLibMetadataManager.numberingInventory(at: url)
                #expect((track ? recovered.track : recovered.disc).number.resolvedValue == nil)
                #expect((track ? recovered.track : recovered.disc).total.resolvedValue == nil)
            }
        }
    }

    @Test(arguments: ["5", "5/0", "/12", ""])
    func numberTextRetiresProvenanceInSameSave(_ text: String) throws {
        let url = try copy(); defer { try? FileManager.default.removeItem(at: url) }
        try seed(url, prefixes: ["AUDIOMATOR", "TAGLIBAUDIOMETADATA"])
        let before = try IndependentMP4Probe.read(url)
        try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("Mixed")], numberText: .init(trackNumberText: text)), to: url)
        let after = try IndependentMP4Probe.read(url)
        let expected = text == "5" ? [5, 12] : text == "5/0" ? [5, 0] : text == "/12" ? [0, 12] : [0, 0]
        #expect(try pair(after, key: "trkn") == expected)
        #expect(after.items["----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"] == nil)
        #expect(after.items["----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"] == nil)
        #expect(after.audio == before.audio)
    }

    @Test func canonicalNumbersBeatConflictingOrMalformedPrivateProvenance() throws {
        for values in [["03/12"], ["bad", "data"]] {
            let url = try copy(); defer { try? FileManager.default.removeItem(at: url) }
            try seed(url, prefixes: ["AUDIOMATOR"], native: (3, 6), values: values)
            let before = try IndependentMP4Probe.read(url)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(5)]), to: url)
            let after = try IndependentMP4Probe.read(url)
            #expect(try pair(after, key: "trkn") == [5, 6])
            #expect(after.items["----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"] == nil)
            #expect(after.audio == before.audio)
        }
    }

    @Test func ambiguousMissingSiblingNeedsValueButFullReplacementSucceeds() throws {
        let url = try copy(); defer { try? FileManager.default.removeItem(at: url) }
        try seed(url, prefixes: ["AUDIOMATOR"])
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT", type: "stringList", values: ["04/14"])
        ]), to: url)
        let bytes = try Data(contentsOf: url)
        #expect(throws: (any Error).self) { try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(5)]), to: url) }
        #expect(try Data(contentsOf: url) == bytes)
        try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(5), .trackTotal: .integer(16), .title: .text("Chosen values")]), to: url)
        #expect(try pair(IndependentMP4Probe.read(url), key: "trkn") == [5, 16])
    }

    @Test func malformedMissingSiblingDoesNotDisappearDuringPartialEdit() throws {
        let url = try copy(); defer { try? FileManager.default.removeItem(at: url) }
        try seed(url, prefixes: ["AUDIOMATOR"], values: ["A1/12"])
        let before = try Data(contentsOf: url)
        #expect(throws: (any Error).self) { try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(5)]), to: url) }
        #expect(try Data(contentsOf: url) == before)
        try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .remove, .trackTotal: .remove]), to: url)
        #expect(try IndependentMP4Probe.read(url).items["----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"] == nil)
    }

    @Test func staleAndInvalidMixedWritesCannotPartiallyCleanPrivateData() throws {
        let url = try copy(); defer { try? FileManager.default.removeItem(at: url) }
        try seed(url, prefixes: ["AUDIOMATOR"])
        let version = try TagLibMetadataManager.fileVersion(at: url)
        try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("External")]), to: url)
        let before = try Data(contentsOf: url)
        #expect(throws: (any Error).self) {
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(5)]), to: url, expectedVersion: version)
        }
        #expect(try Data(contentsOf: url) == before)
        #expect(throws: (any Error).self) {
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(70000), .title: .text("Must not commit")]), to: url)
        }
        #expect(try Data(contentsOf: url) == before)
    }
}
