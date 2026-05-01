import XCTest
import TagLibAudioMetadata

final class FormatCapabilityTests: XCTestCase {
    func testReadableExtensionsComeFromCapabilities() {
        let capabilityExtensions = TagLibMetadataManager.formatCapabilities.flatMap(\.extensions)

        XCTAssertEqual(Set(TagLibMetadataManager.readableExtensions), Set(capabilityExtensions))
        XCTAssertEqual(TagLibMetadataManager.readableExtensions.count, capabilityExtensions.count)
    }

    func testWritableExtensionsComeFromCapabilities() {
        let writableCapabilityExtensions = TagLibMetadataManager.formatCapabilities
            .filter(\.isWritable)
            .flatMap(\.extensions)

        XCTAssertEqual(Set(TagLibMetadataManager.writableExtensions), Set(writableCapabilityExtensions))
        XCTAssertFalse(TagLibMetadataManager.isWritableFormat("shn"))
        XCTAssertTrue(TagLibMetadataManager.isReadableFormat("shn"))
    }

    func testAliasLookupReturnsFamilyCapability() {
        let m4a = TagLibMetadataManager.formatCapability(for: "m4a")
        let mp4 = TagLibMetadataManager.formatCapability(for: "MP4")
        let aifc = TagLibMetadataManager.formatCapability(for: "aifc")

        XCTAssertEqual(m4a?.identifier, "mp4")
        XCTAssertEqual(mp4?.identifier, "mp4")
        XCTAssertEqual(aifc?.identifier, "aiff")
    }

    func testCapabilityCaveatsAreExplicit() throws {
        let shorten = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "shn"))

        XCTAssertTrue(shorten.isReadable)
        XCTAssertFalse(shorten.isWritable)
        XCTAssertEqual(shorten.structuredWriteSupport, .none)
        XCTAssertFalse((shorten.readOnlyReason ?? "").isEmpty)
    }

    func testStructuredSupportLevelsMatchKnownFamilies() throws {
        XCTAssertEqual(try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "mp3")).structuredReadSupport, .container)
        XCTAssertEqual(try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "m4a")).structuredWriteSupport, .container)
        XCTAssertEqual(try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "flac")).structuredWriteSupport, .propertyMap)
    }

    func testFieldSchemasCanBeFilteredByCapability() throws {
        let mp4 = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "m4a"))
        let mp4Schemas = MetadataFieldRegistry.schemas(storableIn: mp4)

        XCTAssertTrue(mp4.metadataFieldFormats.contains(.mp4))
        XCTAssertTrue(mp4Schemas.contains { $0.key == .title })
        XCTAssertTrue(MetadataFieldRegistry.schema(.title, hasMappingFor: .mp4))
    }
}
