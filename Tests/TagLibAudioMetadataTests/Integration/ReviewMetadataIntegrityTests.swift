import Foundation
import Testing
import TagLibAudioMetadata

struct ReviewMetadataIntegrityTests {
    private func withFixture(_ ext: String, _ body: (URL) throws -> Void) throws {
        let source = try #require(
            Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext)
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IndependentReview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.\(ext)")
        try FileManager.default.copyItem(at: source, to: url)
        try body(url)
    }

    private func coverData() throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "testCover", withExtension: "jpg", subdirectory: "Artwork")
                ?? Bundle.module.url(forResource: "testCover", withExtension: "jpg")
        )
        return try Data(contentsOf: url)
    }

    @Test func structuredPropertyEditsPreserveOmittedArtwork() throws {
        let data = try coverData()
        for ext in ["wv", "wma"] {
            try withFixture(ext) { url in
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(artwork: [
                        StructuredArtwork(container: "", mimeType: "image/jpeg", data: data)
                    ]),
                    to: url
                )
                // Inspect the persisted picture bytes independently of the package reader.
                #expect(try Data(contentsOf: url).range(of: data) != nil)
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(properties: [.init(key: "TITLE", values: ["Property edit"])]),
                    to: url,
                    includeProperties: true
                )
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "Property edit")
                #expect(try Data(contentsOf: url).range(of: data) != nil, "\(ext) lost omitted artwork")
                #expect(try TagLibMetadataManager.readStructuredMetadataResult(from: url).artwork.first?.data == data)
            }
        }
    }

    @Test func emptyStructuredWritePreservesArtworkButExplicitRemovalClearsIt() throws {
        let data = try coverData()
        for ext in ["wv", "wma"] {
            try withFixture(ext) { url in
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(artwork: .replace([
                        StructuredArtwork(container: "", mimeType: "image/jpeg", data: data)
                    ])),
                    to: url
                )
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(StructuredMetadata(), to: url)
                #expect(try Data(contentsOf: url).range(of: data) != nil, "\(ext) lost omitted artwork")
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(), to: url, replacingCollections: [.artwork]
                )
                #expect(try Data(contentsOf: url).range(of: data) == nil)
                #expect(try TagLibMetadataManager.readStructuredMetadataResult(from: url).artwork.isEmpty)
            }
        }
    }
}
