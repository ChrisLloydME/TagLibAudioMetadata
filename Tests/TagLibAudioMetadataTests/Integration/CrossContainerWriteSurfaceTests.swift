import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

struct CrossContainerWriteSurfaceTests {
    struct State: Sendable { let ext: String; let mask: Int }
    static let states = CrossContainerTextStateTests.formats.flatMap { ext in (0..<16).map { State(ext: ext, mask: $0) } }
    static let surfaces = MP4WriteSurfaceStateTests.Surface.allCases.filter { $0 != .structuredAtom }

    @Test func allPublicWriteSurfacesRequireContainerStateEvidence() {
        #expect(Self.states.count == 208)
        #expect(Self.surfaces.count == 10)
        #expect(Set(Self.surfaces).union([.structuredAtom]) == Set(MP4WriteSurfaceStateTests.Surface.allCases))
    }

    @Test(.serialized, arguments: states, surfaces)
    func publicWriteSurfacesPreserveSparseNativeOwners(_ state: State, _ surface: MP4WriteSurfaceStateTests.Surface) throws {
        let name = ["dsf", "dff", "ape", "mpc"].contains(state.ext) ? "hardening" : state.ext == "aiff" ? "clean-room" : state.ext == "opus" ? "synthetic" : "testAudioFile"
        try HardeningFixture.withCopy(state.ext, name: name) { url in
            let id3 = ["mp3", "aac", "wav", "aiff", "tta", "dsf", "dff"].contains(state.ext)
            let helper = CrossContainerTextStateTests()
            if id3 {
                try helper.seedID3(.init(ext: state.ext, mask: state.mask, field: .comment), operation: .set, at: url)
            } else {
                var values = Dictionary(uniqueKeysWithValues: CrossContainerTextStateTests.dates.enumerated().compactMap { index, key in
                    state.mask & (1 << index) == 0 ? nil : (key, [MP4DateStateFixture.dates[index]])
                })
                values["X-STATE-KEEP"] = ["one", "duplicate", "duplicate", "  padded  "]
                try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: values,
                    removingKeys: Set(CrossContainerTextStateTests.dates + ["COMMENT"]).subtracting(values.keys)), to: url)
            }
            let beforeID3 = id3 ? try IndependentID3ContainerProbe.read(url) : nil
            let beforeText = id3 ? nil : try helper.textState(url)
            if let native = beforeID3 { CrossContainerTextStateTests.expectID3DateSeed(native, mask: state.mask) }
            if let native = beforeText { CrossContainerTextStateTests.expectTextDateSeed(native.values, mask: state.mask) }
            try Self.write(surface, at: url)
            let after = try TagLibMetadataManager.readMetadataResult(from: url)
            if surface == .customDelta { #expect(after.customFields["X-NEW"] == "Changed") }
            else { #expect(after.comment == "Changed") }
            if let before = beforeID3 {
                let native = try IndependentID3ContainerProbe.read(url)
                let target = surface == .customDelta ? "TXXX:X-NEW" : "COMM"
                let payload = try #require(native.frames[target]?.first)
                #expect(native.frames[target]?.count == 1)
                let encoding = try #require(payload.first)
                try #require(encoding == 0 || encoding == 3)
                let text = try #require(String(data: payload.dropFirst(surface == .customDelta ? 1 : 4), encoding: encoding == 0 ? .isoLatin1 : .utf8))
                #expect(text.components(separatedBy: "\0").dropFirst().joined(separator: "\0") == "Changed")
                let excluded: Set<String> = ["COMM", "TXXX:X-NEW"]
                #expect(native.frames.filter { !excluded.contains($0.key) } == before.frames.filter { !excluded.contains($0.key) }, "\(state.ext), mask=\(state.mask), \(surface)")
                #expect(native.audio == before.audio)
            } else if let before = beforeText {
                let native = try helper.textState(url)
                #expect(native.values[surface == .customDelta ? "X-NEW" : "COMMENT"] == ["Changed"])
                let excluded: Set<String> = ["COMMENT", "X-NEW"]
                #expect(native.values.filter { !excluded.contains($0.key) } == before.values.filter { !excluded.contains($0.key) }, "\(state.ext), mask=\(state.mask), \(surface)")
                #expect(native.audio == before.audio)
            }
        }
    }
    static func write(_ surface: MP4WriteSurfaceStateTests.Surface, at url: URL) throws {
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
                let raw = try TagLibMetadataManager.readSnapshot(from: url).raw
                var values = Dictionary(uniqueKeysWithValues: raw.properties.map { ($0.key, $0.values) })
                values["COMMENT"] = ["Changed"]
                try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(values, to: url, mode: .replace)
            case .structuredAtom:
                Issue.record("MP4 atoms are covered by the MP4-specific surface matrix")
            }
    }

}
