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
        for ext in ["xm", "s3m", "it"] {
            XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: ext), .experimental, ext)
        }
        XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: "mod"), .readOnly)
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
        XCTAssertEqual(xm.writeSupport(for: .trackerName), .experimental)
        XCTAssertEqual(xm.writeSupport(for: .album), .unsupported)
        XCTAssertEqual(xm.writeSupport(for: .artwork), .unsupported)

        let s3m = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "s3m"))
        XCTAssertEqual(s3m.readSupport(for: .trackerName), .experimental)
        XCTAssertEqual(s3m.writeSupport(for: .trackerName), .unsupported)

        let mod = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: "mod"))
        XCTAssertFalse(mod.isWritable)
        XCTAssertEqual(mod.readSupport(for: .title), .readOnly)
        XCTAssertEqual(mod.writeSupport(for: .title), .unsupported)

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

    func testBridgeFieldRestrictionsUseKnownUniqueSchemaKeys() {
        let bridgeCapabilities = TagLibMetadataExtractor.formatCapabilities()
        let capabilitiesByIdentifier = Dictionary(
            uniqueKeysWithValues: TagLibMetadataManager.formatCapabilities.map { ($0.identifier, $0) }
        )

        for bridgeCapability in bridgeCapabilities {
            guard let identifier = bridgeCapability["identifier"] as? String,
                  let capability = capabilitiesByIdentifier[identifier]
            else {
                return XCTFail("Bridge capability is missing a known identifier.")
            }

            if let readable = bridgeCapability["readableFields"] as? [String] {
                XCTAssertEqual(readable.count, Set(readable).count, identifier)
                XCTAssertEqual(readable.count, capability.readableFields?.count, identifier)
            }
            if let writable = bridgeCapability["writableFields"] as? [String] {
                XCTAssertEqual(writable.count, Set(writable).count, identifier)
                XCTAssertEqual(writable.count, capability.writableFields?.count, identifier)
            }
        }
    }

    func testBridgeKnownPropertyKeysMatchSwiftSchemaAliases() {
        let internalKeys: Set<String> = [
            "AUDIOMATOR_TRACKNUMBER_TEXT",
            "AUDIOMATOR_DISCNUMBER_TEXT",
        ]
        let bridgeKeys = Set(TagLibMetadataExtractor.knownMetadataPropertyKeys()).subtracting(internalKeys)

        XCTAssertEqual(bridgeKeys, MetadataFieldRegistry.canonicalPropertyMapKeys)
    }

    func testBridgeContainerMappingsAgreeWithSwiftSchema() throws {
        for mapping in TagLibMetadataExtractor.metadataFieldMappings() {
            let canonical = try XCTUnwrap(mapping["canonicalPropertyKey"] as? String)
            let aliases = mapping["propertyAliases"] as? [String] ?? []
            let propertyKeys = Set([canonical] + aliases)
            let schemas = MetadataFieldRegistry.allSchemas.filter {
                !propertyKeys.isDisjoint(with: Set($0.propertyMapKeys))
            }
            XCTAssertFalse(schemas.isEmpty, canonical)

            if let frame = mapping["id3v2TextFrame"] as? String {
                XCTAssertTrue(schemas.contains { schema in
                    schema.mappings.contains { $0.format == .id3v2 && $0.storageKind == .textFrame && $0.keys.contains(frame) }
                        || schema.mappings.contains { $0.format == .id3v2 && $0.storageKind == .binary && $0.keys.contains(frame) }
                }, "\(canonical) / \(frame)")
            }
            if let description = mapping["id3v2UserTextDescription"] as? String {
                XCTAssertTrue(schemas.contains { schema in
                    schema.mappings.contains { $0.format == .id3v2 && $0.storageKind == .userTextFrame && $0.keys.contains(description) }
                }, "\(canonical) / \(description)")
            }
            if let atom = mapping["mp4Atom"] as? String {
                XCTAssertTrue(schemas.contains { schema in
                    schema.mappings.contains { $0.format == .mp4 && $0.storageKind == .mp4Atom && $0.keys.contains(atom) }
                        || schema.mappings.contains { $0.format == .mp4 && $0.storageKind == .binary && $0.keys.contains(atom) }
                }, "\(canonical) / \(atom)")
            }
            if let description = mapping["mp4FreeformDescription"] as? String {
                let atom = "----:com.apple.iTunes:\(description)"
                XCTAssertTrue(schemas.contains { schema in
                    schema.mappings.contains { $0.format == .mp4 && $0.storageKind == .mp4Freeform && $0.keys.contains(atom) }
                }, "\(canonical) / \(atom)")
            }

            XCTAssertTrue(schemas.contains { $0.isMultiValue == ((mapping["multiValue"] as? NSNumber)?.boolValue ?? false) }, canonical)
            XCTAssertTrue(schemas.contains { $0.isPeopleField == ((mapping["peopleField"] as? NSNumber)?.boolValue ?? false) }, canonical)
            XCTAssertTrue(schemas.contains { $0.isRoleQualified == ((mapping["roleQualified"] as? NSNumber)?.boolValue ?? false) }, canonical)
        }
    }
}
