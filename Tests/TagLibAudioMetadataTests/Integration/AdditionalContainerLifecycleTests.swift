import Foundation
import Testing
import TagLibAudioMetadata

struct AdditionalContainerLifecycleTests {
    struct Entry: Sendable { let item: FLACSemanticLifecycleTests.Case; let ext: String }
    // APE and Xiph have different native spellings for these two owners.
    // Keep literal expectations independent of the production registry.
    static let apeFields = FLACSemanticLifecycleTests.cases.map { item in
        FLACSemanticLifecycleTests.Case(item.field, item.field == .albumArtist ? "ALBUM ARTIST" : item.field == .remixer ? "MIXARTIST" : item.key)
    }
    static let apeCases = ["ape", "wv", "mpc"].flatMap { ext in apeFields.map { Entry(item: $0, ext: ext) } }
    static let oggCases = ["ogg", "opus"].flatMap { ext in FLACSemanticLifecycleTests.cases.map { Entry(item: $0, ext: ext) } }
    @Test(arguments: apeCases, SemanticLifecycleMatrixTests.Operation.allCases)
    func apeNativeItemLifecycle(_ entry: Entry, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        let (item, ext) = (entry.item, entry.ext)
        try HardeningFixture.withCopy(ext, name: ext == "wv" ? "testAudioFile" : "hardening") { url in
            let state = try HardeningFixture.apeState(Data(contentsOf: url))
            var items = state.items
            items[item.key] = operation == .set ? nil : .init(flags: 0, value: Data("Original".utf8))
            items["X-PRESERVE"] = .init(flags: 0, value: Data("first\0duplicate\0duplicate\0  padded  ".utf8))
            try HardeningFixture.writeAPE(audio: state.audio, items: items, to: url)
            let before = try HardeningFixture.apeState(Data(contentsOf: url))
            let date: Set<MetadataFieldKey> = [.year, .standaloneDate, .releaseDate, .originalReleaseDate]
            let replacement = date.contains(item.field) ? "2017-06-09" : "Replacement"
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: operation == .remove ? .remove : .text(replacement)]), to: url)
            let after = try HardeningFixture.apeState(Data(contentsOf: url))
            #expect(after.items[item.key]?.value == (operation == .remove ? nil : Data(replacement.utf8)))
            #expect(after.items.filter { $0.key != item.key } == before.items.filter { $0.key != item.key })
            #expect(after.audio == before.audio)
        }
    }

    @Test(arguments: oggCases, SemanticLifecycleMatrixTests.Operation.allCases)
    func oggNativeCommentLifecycle(_ entry: Entry, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        let (item, ext) = (entry.item, entry.ext)
        try HardeningFixture.withCopy(ext, name: ext == "opus" ? "synthetic" : "testAudioFile") { url in
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["X-PRESERVE": ["A; B", "duplicate", "duplicate", "  padded  "]]), to: url)
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: operation == .set ? [:] : [item.key: ["Original"]], removingKeys: operation == .set ? [item.key] : []), to: url)
            let before = try IndependentOggProbe.read(url)
            let date: Set<MetadataFieldKey> = [.year, .standaloneDate, .releaseDate, .originalReleaseDate]
            let value = date.contains(item.field) ? "2017-06-09" : "Replacement"
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: operation == .remove ? .remove : .text(value)]), to: url)
            let after = try IndependentOggProbe.read(url)
            #expect(after.comments[item.key] == (operation == .remove ? nil : [value]))
            #expect(after.comments.filter { $0.key != item.key } == before.comments.filter { $0.key != item.key })
            #expect(after.audio == before.audio)
        }
    }

    @Test(arguments: ["ogg", "opus"], [false, true])
    func basicOggDatesPreserveArraysAndAudio(_ ext: String, _ replace: Bool) throws {
        try HardeningFixture.withCopy(ext, name: ext == "opus" ? "synthetic" : "testAudioFile") { url in
            let values = Dictionary(uniqueKeysWithValues: ["YEAR", "DATE", "RELEASEDATE", "ORIGINALDATE"].map { ($0, ["2004", "not-a-date", "  padded  ", "duplicate", "duplicate"]) })
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: values), to: url)
            let before = try IndependentOggProbe.read(url)
            if replace {
                var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
                metadata.title = "Unrelated"
                try TagLibMetadataManager.replaceBasicMetadata(metadata, to: url)
            } else {
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
            }
            let after = try IndependentOggProbe.read(url)
            for key in values.keys { #expect(after.comments[key] == before.comments[key]) }
            #expect(after.audio == before.audio)
        }
    }
}
