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

    func testVerificationLevelsDistinguishFixturesUpstreamAndExperimentalFormats() throws {
        for ext in ["mp3", "m4a", "flac", "ogg", "wav", "aac"] {
            XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: ext), .verified, ext)
        }
        for ext in ["mp2", "mp4", "ape", "wma", "dsf"] {
            XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: ext), .upstreamSupported, ext)
        }
        for ext in ["mod", "xm", "s3m", "it"] {
            XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: ext), .experimental, ext)
        }
        XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: "shn"), .readOnly)
        XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: "not-a-format"), .unsupported)

        let mp4Family = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "m4a"))
        XCTAssertEqual(mp4Family.supportLevel, .verified)
        XCTAssertEqual(mp4Family.supportLevel(forExtension: "m4a"), .verified)
        XCTAssertEqual(mp4Family.supportLevel(forExtension: "mp4"), .upstreamSupported)
    }

    func testFieldLevelSupportReflectsMappingsArtworkAndWriteAvailability() throws {
        let xm = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "xm"))
        XCTAssertEqual(xm.readSupport(for: .title), .experimental)
        XCTAssertEqual(xm.writeSupport(for: .title), .experimental)
        XCTAssertEqual(xm.writeSupport(for: .artwork), .unsupported)

        let shorten = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "shn"))
        XCTAssertEqual(shorten.readSupport(for: .title), .readOnly)
        XCTAssertEqual(shorten.writeSupport(for: .title), .unsupported)
    }

    func testFieldSchemasCanBeFilteredByCapability() throws {
        let mp4 = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "m4a"))
        let mp4Schemas = MetadataFieldRegistry.schemas(storableIn: mp4)

        XCTAssertTrue(mp4.metadataFieldFormats.contains(.mp4))
        XCTAssertTrue(mp4Schemas.contains { $0.key == .title })
        XCTAssertTrue(MetadataFieldRegistry.schema(.title, hasMappingFor: .mp4))
    }

    func testReadOnlyCapabilitiesDoNotAdvertiseStorableFields() throws {
        let shorten = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "shn"))

        XCTAssertFalse(shorten.isWritable)
        XCTAssertTrue(MetadataFieldRegistry.schemas(storableIn: shorten).isEmpty)
    }

    func testFieldRegistryCoversEveryFieldExactlyOnce() {
        let schemaKeys = MetadataFieldRegistry.allSchemas.map(\.key)

        XCTAssertEqual(schemaKeys.count, Set(schemaKeys).count, "Metadata field schemas must not contain duplicate keys.")
        XCTAssertEqual(Set(schemaKeys), Set(MetadataFieldKey.allCases), "Every public metadata field key needs one schema.")
    }

    func testCapabilityDescriptorsHaveUniqueIdentifiersAndExtensions() {
        let capabilities = TagLibMetadataManager.formatCapabilities
        let identifiers = capabilities.map(\.identifier)
        let extensions = capabilities.flatMap(\.extensions)

        XCTAssertEqual(identifiers.count, Set(identifiers).count)
        XCTAssertEqual(extensions.count, Set(extensions).count)
        for capability in capabilities {
            XCTAssertTrue(capability.extensions.contains(capability.primaryExtension), capability.identifier)
            XCTAssertEqual(capability.extensions, capability.extensions.map { $0.lowercased() }, capability.identifier)
        }
    }
}
