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

    @Test func typedYearDateAndReleaseDateStayIndependent() throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [
                    .year: .text("2004"),
                    .standaloneDate: .text("2003-02-01"),
                    .originalReleaseDate: .text("1999"),
                ]),
                to: url
            )
            var basic = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(basic.year == "2004")
            #expect(basic.date == "2003-02-01")
            #expect(basic.originalReleaseDate == "1999")

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.year: .text("2005")]),
                to: url
            )
            basic = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(basic.year == "2005")
            #expect(basic.date == "2003-02-01")
            #expect(basic.originalReleaseDate == "1999")

            // The specification declares no ASF typed RELEASEDATE target.
            let before = try Data(contentsOf: url)
            #expect(throws: (any Error).self) {
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.releaseDate: .text("2017-06-09")]),
                    to: url
                )
            }
            #expect(try Data(contentsOf: url) == before)

            let attributes = try IndependentASF.attributes(try Data(contentsOf: url))
            #expect(attributes.contains { $0.name.uppercased().contains("YEAR") })
            #expect(attributes.contains { $0.name.uppercased().contains("DATE") && $0.name.uppercased() != "YEAR" })
        }
    }
}
