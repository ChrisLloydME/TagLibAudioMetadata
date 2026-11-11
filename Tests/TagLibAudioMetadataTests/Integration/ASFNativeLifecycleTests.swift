import Foundation
import Testing
import TagLibAudioMetadata

struct ASFNativeLifecycleTests {
    struct Entry: Sendable { let field: MetadataFieldKey; let native: String }
    static let cases: [Entry] = [
        .init(field: .year, native: "WM/Year"), .init(field: .standaloneDate, native: "DATE"),
        .init(field: .originalReleaseDate, native: "WM/OriginalReleaseYear"),
        .init(field: .contentGroup, native: "WM/ContentGroupDescription"),
        .init(field: .encodedBy, native: "WM/EncodedBy"), .init(field: .encoderSettings, native: "WM/EncodingSettings"),
        .init(field: .artists, native: "WM/ARTISTS")
    ]

    @Test(arguments: cases, SemanticLifecycleMatrixTests.Operation.allCases)
    func nativeAttributeLifecycle(_ item: Entry, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: .remove]), to: url)
            #expect(try IndependentASF.attributes(Data(contentsOf: url)).filter { $0.name == item.native }.isEmpty)
            if operation != .set {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                    .init(key: item.native, type: "string", value: "2004")
                ]), to: url)
            }
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                .init(key: "X-KEEP", type: "string", value: "  padded  ", language: 0, stream: 0)
            ]), to: url)
            let beforeBytes = try Data(contentsOf: url)
            let before = try IndependentASF.attributes(beforeBytes)
            let replacement = [MetadataFieldKey.year, .standaloneDate, .originalReleaseDate].contains(item.field) ? "2017-06-09" : "Replacement"
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: operation == .remove ? .remove : .text(replacement)]), to: url)
            let afterBytes = try Data(contentsOf: url)
            let after = try IndependentASF.attributes(afterBytes)
            #expect(after.filter { $0.name == item.native }.map(\.value) == (operation == .remove ? [] : [IndependentASF.text(replacement)]))
            #expect(after.filter { $0.name != item.native } == before.filter { $0.name != item.native })
            #expect(try IndependentASF.headerState(afterBytes).tail == IndependentASF.headerState(beforeBytes).tail)
        }
    }
}
