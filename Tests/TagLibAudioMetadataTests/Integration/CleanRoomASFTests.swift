import Foundation
import Testing
import TagLibAudioMetadata

struct CleanRoomASFTests {
    @Test func eraseClearsAllNativeAttributesAndPicturesWithoutChangingPackets() throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            let coverURL = try #require(Bundle.module.url(forResource: "testCover", withExtension: "jpg"))
            let cover = try Data(contentsOf: coverURL)
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(StructuredMetadata(
                asfAttributes: [
                    .init(key: "ERASE_CUSTOM", type: "string", value: "Private"),
                    .init(key: "ERASE_BINARY", type: "binary", data: Data([1, 0, 2, 0])),
                    .init(key: "ERASE_NUMBER", type: "int", value: "123")
                ], artwork: [.init(pictureTypeCode: 3, mimeType: "image/jpeg", data: cover)]), to: url)
            let before = try Data(contentsOf: url)
            #expect(try IndependentASF.attributes(before).contains { $0.name == "ERASE_BINARY" })
            let audio = try IndependentASF.headerState(before).tail
            try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url)
            let after = try Data(contentsOf: url)
            #expect(try IndependentASF.attributes(after).isEmpty)
            #expect(try IndependentASF.headerState(after).tail == audio)
            #expect(try TagLibMetadataManager.readStructuredMetadataResult(from: url).asfAttributes.isEmpty)
            let basic = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(basic.title.isEmpty && basic.customFields.isEmpty && basic.artworkData == nil)
        }
    }
}
