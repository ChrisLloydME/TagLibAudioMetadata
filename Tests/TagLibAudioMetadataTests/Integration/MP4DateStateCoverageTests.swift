import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

/// Test-owned native identities. No expected location or mask comes from the
/// production registry, and every argument starts from a separate file.
enum MP4DateStateFixture {
    struct State: Sendable {
        let mask: Int
        let arrays: Bool
        var label: String { "dates=\(mask), arrays=\(arrays)" }
    }
    static let owners = ["©day", "----:com.apple.iTunes:DATE", "----:com.apple.iTunes:RELEASEDATE", "----:com.apple.iTunes:ORIGINALDATE"]
    static let dates = ["2004", "2008-03-04", "2017-06-09", "1999-11-12"]
    static let states = (0..<16).map { State(mask: $0, arrays: false) }
    static let adversarial = [State(mask: 2, arrays: true), State(mask: 1, arrays: true), State(mask: 15, arrays: true)]
    static let keep = "----:com.apple.iTunes:X-STATE-KEEP"

    static func seed(_ state: State, at url: URL, extra: [StructuredMP4Atom] = []) throws {
        let overrides = Dictionary(uniqueKeysWithValues: extra.map { ($0.key, $0) })
        var atoms = owners.enumerated().filter { overrides[$0.element] == nil }.map { index, key in
            StructuredMP4Atom(key: key, type: "stringList",
                values: state.arrays ? [dates[index], "not-a-date", "duplicate", "duplicate", "  padded  "] : [dates[index]],
                remove: state.mask & (1 << index) == 0)
        }
        atoms.append(.init(key: keep, type: "stringList", values: ["literal; value", "duplicate", "duplicate"]))
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: atoms + extra), to: url)
        let native = try IndependentMP4Probe.read(url)
        for (index, key) in owners.enumerated() {
            let expected = overrides[key].map { !$0.remove } ?? (state.mask & (1 << index) != 0)
            #expect((native.items[key] != nil) == expected)
            let seededValues = overrides[key]?.values ?? (state.arrays
                ? [dates[index], "not-a-date", "duplicate", "duplicate", "  padded  "] : [dates[index]])
            #expect(native.values[key] == (expected ? seededValues.map { Data($0.utf8) } : nil))
        }
    }

    static func expectDatesAndPayload(_ before: IndependentMP4Probe, _ after: IndependentMP4Probe, excluding: String? = nil) {
        for key in owners where key != excluding { #expect(after.items[key] == before.items[key], "Untouched native date \(key)") }
        #expect(after.items[keep] == before.items[keep])
        #expect(after.audio == before.audio)
    }
}

struct MP4DateStateCoverageTests {
    struct Entry: Sendable {
        let state: MP4DateStateFixture.State
        let field: MetadataFieldKey
        var atom: String { field == .comment ? "©cmt" : "©lyr" }
    }
    static let cases = (MP4DateStateFixture.states + MP4DateStateFixture.adversarial).flatMap { state in
        [MetadataFieldKey.comment, .lyrics].map { Entry(state: state, field: $0) }
    }

    @Test func allSixteenDatePresenceMasksAreExplicit() {
        #expect(Set(MP4DateStateFixture.states.map(\.mask)) == Set(0..<16))
        #expect(Set(MP4DateStateFixture.owners).count == 4)
        #expect(Self.cases.count == 38)
    }

    @Test(.serialized, arguments: cases, SemanticLifecycleMatrixTests.Operation.allCases)
    func textLifecyclePreservesEveryDatePresenceState(_ entry: Entry, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            try MP4DateStateFixture.seed(entry.state, at: url, extra: [
                .init(key: entry.atom, type: "stringList", values: ["Original"], remove: operation == .set)
            ])
            let before = try IndependentMP4Probe.read(url)
            let expected: MetadataPatchValue = operation == .remove ? .remove : .text("Replacement")
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [entry.field: expected]), to: url)
            let after = try IndependentMP4Probe.read(url)
            try after.expectValue(expected, at: entry.atom)
            #expect(after.items.filter { $0.key != entry.atom } == before.items.filter { $0.key != entry.atom }, "\(entry.state.label) / \(entry.field) / \(operation)")
            MP4DateStateFixture.expectDatesAndPayload(before, after)
        }
    }
}

struct MP4WriteSurfaceStateTests {
    enum Surface: String, CaseIterable, Sendable {
        case semantic, customDelta, rawDelta, rawArrayMerge, rawScalarMerge
        case structuredProperties, structuredAtom, basicUpdate, basicReplace, lowLevel, rawArrayReplace
    }

    @Test(.serialized, arguments: MP4DateStateFixture.states, Surface.allCases)
    func unrelatedWriteSurfacesPreserveDateState(_ state: MP4DateStateFixture.State, _ surface: Surface) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            try MP4DateStateFixture.seed(state, at: url)
            let before = try IndependentMP4Probe.read(url)
            switch surface {
            case .semantic:
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.comment: .text("Changed")]), to: url)
            case .customDelta:
                try TagLibMetadataManager.applyMetadataPatch(.init(customFields: ["X-NEW": .text("Changed")]), to: url)
            case .rawDelta:
                try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["COMMENT": ["Changed"]]), to: url)
            case .rawArrayMerge:
                try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(["COMMENT": ["Changed"]], to: url, mode: .merge)
            case .rawScalarMerge:
                try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(["COMMENT": "Changed"], to: url, mode: .merge)
            case .structuredProperties:
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(properties: [.init(key: "COMMENT", values: ["Changed"])]), to: url, includeProperties: true)
            case .structuredAtom:
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [.init(key: "©cmt", type: "stringList", values: ["Changed"])]), to: url)
            case .basicUpdate:
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.comment = "Changed" }
            case .basicReplace:
                var basic = try TagLibMetadataManager.readMetadataResult(from: url)
                basic.comment = "Changed"
                try TagLibMetadataManager.replaceBasicMetadata(basic, to: url)
            case .lowLevel:
                let model = try TagLibMetadataExtractor.extractMetadata(from: url)
                model.comment = "Changed"
                _ = try TagLibMetadataManager.writeTagMetadata(model, to: url)
            case .rawArrayReplace:
                let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
                var properties = Dictionary(uniqueKeysWithValues: snapshot.raw.properties.map { ($0.key, $0.values) })
                properties["COMMENT"] = ["Changed"]
                try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(properties, to: url, mode: .replace)
            }
            let after = try IndependentMP4Probe.read(url)
            MP4DateStateFixture.expectDatesAndPayload(before, after)
            if surface == .customDelta { #expect(try TagLibMetadataManager.readMetadataResult(from: url).customFields["X-NEW"] == "Changed") }
            else { #expect(try TagLibMetadataManager.readMetadataResult(from: url).comment == "Changed") }
        }
    }
}
