import Foundation
import Testing
import TagLibAudioMetadata

struct CleanRoomNativeAliasTests {
    @Test func asfCommonFieldEditsRemoveStaleCustomAliasesAndPreserveOtherAttributes() throws {
        for typed in [false, true] {
            try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Original primary" }
                try IndependentASF.seed([
                    .init(name: "title", type: 0, language: 0, stream: 0, value: IndependentASF.text("Stale alias")),
                    .init(name: "PUBLISHER", type: 0, language: 0, stream: 0, value: IndependentASF.text("Keep publisher"))
                ], at: url)
                let original = try Data(contentsOf: url)
                #expect(try IndependentASF.attributes(original).contains { $0.name == "title" })
                if typed {
                    try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("New title")]), to: url)
                } else {
                    try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "New title" }
                }
                let result = try Data(contentsOf: url)
                let attributes = try IndependentASF.attributes(result)
                #expect(!attributes.contains { $0.name.uppercased() == "TITLE" })
                #expect(attributes.contains { $0.name == "PUBLISHER" && $0.value == IndependentASF.text("Keep publisher") })
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "New title")
                #expect(try IndependentASF.headerState(result).tail == IndependentASF.headerState(original).tail)
            }
        }
    }

    @Test func unchangedAPEDateAliasSurvivesNumberBasicAndRawDeltas() throws {
        try HardeningFixture.withCopy("wv", name: "testAudioFile") { url in
            let audio = try HardeningFixture.apeState(Data(contentsOf: url)).audio
            try HardeningFixture.writeAPE(audio: audio, items: [
                "Date": .init(flags: 0, value: Data("2021-07-15".utf8)),
                "Title": .init(flags: 0, value: Data("Original".utf8)),
                "KEEP_NATIVE": .init(flags: 0, value: Data("Keep".utf8))
            ], to: url)
            let before = try HardeningFixture.apeState(Data(contentsOf: url))
            #expect(before.items["DATE"] != nil && before.items["YEAR"] == nil)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(7), .trackTotal: .integer(12)]), to: url)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "New title" }
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["ARTIST": ["New artist"]]), to: url)
            let after = try HardeningFixture.apeState(Data(contentsOf: url))
            #expect(after.items["DATE"] == before.items["DATE"])
            #expect(after.items["YEAR"] == nil)
            #expect(after.items["KEEP_NATIVE"] == before.items["KEEP_NATIVE"])
            #expect(after.audio == before.audio)
        }
    }
}
