import Foundation
import Testing
import TagLibAudioMetadata

/// Scalar text edits through every fixture-backed rich container. This catches
/// engine projection collisions without relying on AudioMator or its models.
struct CrossContainerTextStateTests {
    struct Entry: Sendable {
        let ext: String
        let mask: Int
        let field: MetadataFieldKey
        var key: String { field == .comment ? "COMMENT" : "LYRICS" }
        var id: String { field == .comment ? "COMM" : "USLT" }
    }
    static let formats = ["mp3", "aac", "wav", "aiff", "tta", "dsf", "dff", "flac", "ogg", "opus", "ape", "wv", "mpc"]
    static let cases = formats.flatMap { ext in
        (0..<16).flatMap { mask in [MetadataFieldKey.comment, .lyrics].map { Entry(ext: ext, mask: mask, field: $0) } }
    }
    static let dates = ["YEAR", "DATE", "RELEASEDATE", "ORIGINALDATE"]
    static let frameIDs = ["TDRC", "TXXX", "TDRL", "TDOR"]

    @Test func everyContainerAndDateMaskRequiresTextLifecycleEvidence() {
        #expect(Self.cases.count == 416)
        for ext in Self.formats {
            #expect(Set(Self.cases.filter { $0.ext == ext }.map(\.mask)) == Set(0..<16))
        }
    }

    @Test(.serialized, arguments: cases, SemanticLifecycleMatrixTests.Operation.allCases)
    func nativeTextLifecycleAcrossSparseContainerStates(_ entry: Entry, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        let ext = entry.ext
        let name = ["dsf", "dff", "ape", "mpc"].contains(ext) ? "hardening" : ext == "aiff" ? "clean-room" : ext == "opus" ? "synthetic" : "testAudioFile"
        try HardeningFixture.withCopy(ext, name: name) { url in
            if ["mp3", "aac", "wav", "aiff", "tta", "dsf", "dff"].contains(ext) {
                try seedID3(entry, operation: operation, at: url)
                let before = try IndependentID3ContainerProbe.read(url)
                Self.expectID3DateSeed(before, mask: entry.mask)
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [entry.field: operation == .remove ? .remove : .text("Replacement")]), to: url)
                let after = try IndependentID3ContainerProbe.read(url)
                if operation == .remove { #expect(after.frames[entry.id] == nil) }
                else {
                    let payload = try #require(after.frames[entry.id]?.first)
                    #expect(after.frames[entry.id]?.count == 1)
                    let encoding = try #require(payload.first)
                    try #require(encoding == 0 || encoding == 3)
                    let decoded = try #require(String(data: payload.dropFirst(4), encoding: encoding == 0 ? .isoLatin1 : .utf8))
                    #expect(decoded.components(separatedBy: "\0").dropFirst().joined(separator: "\0") == "Replacement")
                }
                #expect(after.frames.filter { $0.key != entry.id } == before.frames.filter { $0.key != entry.id }, "\(ext) / mask=\(entry.mask) / \(entry.field) / \(operation)")
                #expect(after.audio == before.audio)
            } else {
                var values = Dictionary(uniqueKeysWithValues: Self.dates.enumerated().compactMap { index, key in
                    entry.mask & (1 << index) == 0 ? nil : (key, [MP4DateStateFixture.dates[index]])
                })
                values["X-STATE-KEEP"] = ["one", "duplicate", "duplicate", "  padded  "]
                if operation != .set { values[entry.key] = ["Original"] }
                try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: values,
                    removingKeys: Set(Self.dates + ["COMMENT", "LYRICS"]).subtracting(values.keys)), to: url)
                let before = try textState(url)
                Self.expectTextDateSeed(before.values, mask: entry.mask)
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [entry.field: operation == .remove ? .remove : .text("Replacement")]), to: url)
                let after = try textState(url)
                #expect(after.values[entry.key] == (operation == .remove ? nil : ["Replacement"]))
                #expect(after.values.filter { $0.key != entry.key } == before.values.filter { $0.key != entry.key }, "\(ext) / mask=\(entry.mask) / \(entry.field) / \(operation)")
                #expect(after.audio == before.audio)
            }
        }
    }

    static func expectID3DateSeed(_ native: IndependentID3ContainerProbe, mask: Int) {
        for (index, key) in ["TDRC", "TXXX:DATE", "TDRL", "TDOR"].enumerated() {
            let prefix = index == 1 ? "DATE\0" : ""
            let value = Data([3]) + Data((prefix + MP4DateStateFixture.dates[index]).utf8)
            #expect(native.frames[key] == (mask & (1 << index) == 0 ? nil : [value]), "Seed mask=\(mask), \(key)")
        }
    }

    static func expectTextDateSeed(_ values: [String: [String]], mask: Int) {
        for (index, key) in Self.dates.enumerated() {
            #expect(values[key] == (mask & (1 << index) == 0 ? nil : [MP4DateStateFixture.dates[index]]), "Seed mask=\(mask), \(key)")
        }
    }

    func textState(_ url: URL) throws -> (values: [String: [String]], audio: [Data]) {
        if url.pathExtension == "flac" {
            let value = try IndependentFLACProbe.read(url)
            return (value.comments, [value.audio])
        }
        if ["ogg", "opus"].contains(url.pathExtension) {
            let value = try IndependentOggProbe.read(url)
            return (value.comments, value.audio)
        }
        let value = try HardeningFixture.apeState(Data(contentsOf: url))
        let items = try value.items.reduce(into: [String: [String]]()) { result, item in
            guard let text = String(data: item.value.value, encoding: .utf8) else { throw HardeningFixture.Invalid.container }
            result[item.key] = text.components(separatedBy: "\0")
        }
        return (items, [value.audio])
    }

    func seedID3(_ entry: Entry, operation: SemanticLifecycleMatrixTests.Operation, at url: URL) throws {
        if ["dsf", "dff"].contains(entry.ext) {
            var frames = Data()
            for index in 0..<4 where entry.mask & (1 << index) != 0 {
                let prefix = index == 1 ? "DATE\0" : ""
                frames += HardeningFixture.frame(Self.frameIDs[index], Data([3]) + Data((prefix + MP4DateStateFixture.dates[index]).utf8))
            }
            frames += HardeningFixture.frame("TXXX", Data([3]) + Data("X-KEEP\0Untouched".utf8))
            if operation != .set { frames += HardeningFixture.frame(entry.id, Data([3]) + Data("eng\0Original".utf8)) }
            try HardeningFixture.seedDSDTag(HardeningFixture.id3(frames), at: url)
        } else {
            var frames = (0..<4).map { index in
                StructuredID3v2Frame(frameID: Self.frameIDs[index], type: index == 1 ? "userText" : "text",
                    values: entry.mask & (1 << index) == 0 ? [] : [MP4DateStateFixture.dates[index]], description: index == 1 ? "DATE" : nil)
            }
            frames.append(.init(frameID: "TXXX", type: "userText", values: ["Untouched"], description: "X-KEEP"))
            let comments: [StructuredComment] = entry.field == .comment && operation != .set ? [.init(language: "eng", text: "Original")] : []
            let lyrics: [StructuredLyrics] = entry.field == .lyrics && operation != .set ? [.init(language: "eng", text: "Original")] : []
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: frames, lyrics: lyrics, comments: comments), to: url, replacingCollections: [.comments, .lyrics])
        }
    }
}
