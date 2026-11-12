import XCTest
import TagLibAudioMetadata
import CTagLibBridge

final class FormatCapabilityTests: XCTestCase {
    func testCachedDescriptorsMatchEveryBridgeExtensionAndRemainValueCopies() throws {
        for family in TagLibMetadataExtractor.formatCapabilities() {
            for ext in try XCTUnwrap(family["extensions"] as? [String]) {
                let source = try XCTUnwrap(TagLibMetadataExtractor.formatCapability(for: ext))
                let cached = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: ext))
                XCTAssertEqual(cached, TagLibMetadataManager.capability(forExtension: ext.uppercased()))
                XCTAssertEqual(cached.identifier, source["identifier"] as? String)
                XCTAssertEqual(cached.displayName, source["displayName"] as? String)
                XCTAssertEqual(cached.codecName, source["codecName"] as? String)
                XCTAssertEqual(cached.primaryExtension, source["primaryExtension"] as? String)
                XCTAssertEqual(cached.extensions, source["extensions"] as? [String])
                XCTAssertEqual(cached.containers, source["containers"] as? [String])
                XCTAssertEqual(cached.supportLevel.rawValue, source["supportLevel"] as? String)
                XCTAssertEqual(cached.extensionSupportLevels.mapValues(\.rawValue), source["extensionSupportLevels"] as? [String: String])
                XCTAssertEqual(cached.structuredReadSupport.rawValue, source["structuredReadSupport"] as? String)
                XCTAssertEqual(cached.structuredWriteSupport.rawValue, source["structuredWriteSupport"] as? String)
                XCTAssertEqual(cached.readOnlyReason, source["readOnlyReason"] as? String)
                XCTAssertEqual(cached.notes, source["notes"] as? String)
                for (key, value) in ["isReadable": cached.isReadable, "isWritable": cached.isWritable,
                    "canReadArtwork": cached.canReadArtwork, "canWriteArtwork": cached.canWriteArtwork,
                    "preservesMultiValueProperties": cached.preservesMultiValueProperties] {
                    XCTAssertEqual(value, (source[key] as? NSNumber)?.boolValue ?? false, "\(ext) / \(key)")
                }
                for (key, value) in ["readableFields": cached.readableFields, "writableFields": cached.writableFields] {
                    let expected = (source[key] as? [String]).map { Set($0.compactMap(MetadataFieldKey.init(rawValue:))) }
                    XCTAssertEqual(value, expected, "\(ext) / \(key)")
                }
                var copy = cached
                copy.containers = ["changed"]
                copy.identifier = "changed"
                copy.isWritable.toggle()
                copy.extensions.removeAll()
                XCTAssertEqual(TagLibMetadataManager.capability(forExtension: ext), cached)
                XCTAssertEqual(copy.metadataFieldFormats, [.tagLibPropertyMap])
            }
        }
        for unknown in ["", ".mp3", " mp3", "mp3 ", "unknown"] {
            XCTAssertNil(TagLibMetadataManager.capability(forExtension: unknown))
        }
        var families = TagLibMetadataManager.formatCapabilities
        let original = families
        families.removeAll()
        XCTAssertEqual(TagLibMetadataManager.formatCapabilities, original)
    }

    func testReadOnlyMP4RateRemainsReadableButIsNotAdvertisedWritable() throws {
        for ext in ["m4a", "mp4"] {
            let capability = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: ext))
            XCTAssertNotEqual(capability.readSupport(for: .rate), .unsupported, ext)
            XCTAssertEqual(capability.writeSupport(for: .rate), .unsupported, ext)
            XCTAssertEqual(capability.writeSupport(for: .itunesMediaType), capability.supportLevel, ext)
            XCTAssertEqual(capability.writeSupport(for: .title), capability.supportLevel, ext)
            XCTAssertEqual(capability.writeSupport(for: .artwork), capability.supportLevel, ext)
        }
    }

    func testPropertyMapAliasDoesNotInventNativeWriteSupport() throws {
        let asf = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "wma"))
        XCTAssertEqual(asf.writeSupport(for: .releaseDate), .unsupported)
        XCTAssertEqual(asf.writeSupport(for: .year), asf.supportLevel)
        XCTAssertEqual(asf.writeSupport(for: .standaloneDate), asf.supportLevel)

        let tracker = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "xm"))
        XCTAssertEqual(tracker.writeSupport(for: .title), tracker.supportLevel)
        XCTAssertEqual(tracker.writeSupport(for: .trackerName), tracker.supportLevel)
        XCTAssertEqual(tracker.writeSupport(for: .rate), .unsupported)
    }

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
        XCTAssertFalse(TagLibMetadataManager.isWritableExtension("shn"))
        XCTAssertTrue(TagLibMetadataManager.isReadableExtension("shn"))
    }

    func testAliasLookupReturnsFamilyCapability() {
        let m4a = TagLibMetadataManager.capability(forExtension: "m4a")
        let mp4 = TagLibMetadataManager.capability(forExtension: "MP4")
        let aifc = TagLibMetadataManager.capability(forExtension: "aifc")

        XCTAssertEqual(m4a?.identifier, "mp4")
        XCTAssertEqual(mp4?.identifier, "mp4")
        XCTAssertEqual(aifc?.identifier, "aiff")
    }

    func testConcreteFileProbeIsDistinctFromExtensionCapability() throws {
        XCTAssertNotNil(TagLibMetadataManager.capability(forExtension: "mp3"))

        let corruptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        try Data("not MPEG audio".utf8).write(to: corruptURL)
        defer { try? FileManager.default.removeItem(at: corruptURL) }

        XCTAssertThrowsError(try TagLibMetadataManager.probeFile(at: corruptURL))

        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(forResource: "testAudioFile", withExtension: "mp3", subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "mp3")
        )
        XCTAssertEqual(try TagLibMetadataManager.probeFile(at: fixtureURL).identifier, "mpeg-id3")
    }

    func testCapabilityCaveatsAreExplicit() throws {
        let shorten = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "shn"))

        XCTAssertTrue(shorten.isReadable)
        XCTAssertFalse(shorten.isWritable)
        XCTAssertEqual(shorten.structuredWriteSupport, .none)
        XCTAssertFalse((shorten.readOnlyReason ?? "").isEmpty)
    }

    func testStructuredSupportLevelsMatchKnownFamilies() throws {
        XCTAssertEqual(try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "mp3")).structuredReadSupport, .container)
        XCTAssertEqual(try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "m4a")).structuredWriteSupport, .container)
        XCTAssertEqual(try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "flac")).structuredWriteSupport, .propertyMap)
        XCTAssertEqual(try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "tta")).structuredWriteSupport, .container)
    }

    func testConfiguredCoverageDistinguishesFixturesUpstreamAndExperimentalFormats() throws {
        for ext in ["mp3", "m4a", "flac", "ogg", "oga", "wav", "aac", "xm", "tta", "wv", "wma", "ape", "mpc", "dsf", "dff", "opus"] {
            XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: ext), .fixtureCovered, ext)
        }
        for ext in ["mp2", "mp4", "aiff", "spx"] {
            XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: ext), .upstreamSupported, ext)
        }
        for ext in ["s3m", "it"] {
            XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: ext), .experimental, ext)
        }
        XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: "mod"), .readOnly)
        XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: "shn"), .readOnly)
        XCTAssertEqual(TagLibMetadataManager.formatSupportLevel(for: "not-a-format"), .unsupported)

        let mp4Family = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "m4a"))
        XCTAssertEqual(mp4Family.supportLevel, .fixtureCovered)
        XCTAssertEqual(mp4Family.supportLevel(forExtension: "m4a"), .fixtureCovered)
        XCTAssertEqual(mp4Family.supportLevel(forExtension: "mp4"), .upstreamSupported)
    }

    func testFieldLevelSupportReflectsMappingsArtworkAndWriteAvailability() throws {
        let xm = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "xm"))
        XCTAssertEqual(xm.readSupport(for: .title), .fixtureCovered)
        XCTAssertEqual(xm.writeSupport(for: .title), .fixtureCovered)
        XCTAssertEqual(xm.writeSupport(for: .trackerName), .fixtureCovered)
        XCTAssertEqual(xm.writeSupport(for: .album), .unsupported)
        XCTAssertEqual(xm.writeSupport(for: .artwork), .unsupported)

        let s3m = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "s3m"))
        XCTAssertEqual(s3m.readSupport(for: .trackerName), .experimental)
        XCTAssertEqual(s3m.writeSupport(for: .trackerName), .unsupported)

        let mod = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "mod"))
        XCTAssertFalse(mod.isWritable)
        XCTAssertEqual(mod.readSupport(for: .title), .readOnly)
        XCTAssertEqual(mod.writeSupport(for: .title), .unsupported)

        let shorten = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "shn"))
        XCTAssertEqual(shorten.readSupport(for: .title), .readOnly)
        XCTAssertEqual(shorten.writeSupport(for: .title), .unsupported)
    }

    func testMP4ExposesIndependentYearDateAndReleaseDateOwners() throws {
        let capability = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "m4a"))

        XCTAssertEqual(capability.readSupport(for: .year), .fixtureCovered)
        XCTAssertEqual(capability.writeSupport(for: .year), .fixtureCovered)
        XCTAssertEqual(capability.readSupport(for: .standaloneDate), .fixtureCovered)
        XCTAssertEqual(capability.writeSupport(for: .standaloneDate), .fixtureCovered)
        XCTAssertEqual(capability.readSupport(for: .releaseDate), .fixtureCovered)
        XCTAssertEqual(capability.writeSupport(for: .releaseDate), .fixtureCovered)

        let year = try XCTUnwrap(MetadataFieldRegistry.schema(for: .year))
        let date = try XCTUnwrap(MetadataFieldRegistry.schema(for: .standaloneDate))
        XCTAssertEqual(year.writeTarget(for: .mp4)?.nativeIdentity, "\u{00A9}day")
        XCTAssertEqual(date.writeTarget(for: .mp4)?.nativeIdentity, "DATE")
        XCTAssertNotEqual(year.writeTarget(for: .mp4)?.nativeIdentity, date.writeTarget(for: .mp4)?.nativeIdentity)
    }

    func testFieldSchemasCanBeFilteredByCapability() throws {
        let mp4 = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "m4a"))
        let mp4Schemas = MetadataFieldRegistry.schemas(storableIn: mp4)

        XCTAssertTrue(mp4.metadataFieldFormats.contains(.mp4))
        XCTAssertTrue(mp4Schemas.contains { $0.key == .title })
        XCTAssertTrue(MetadataFieldRegistry.schema(.title, hasMappingFor: .mp4))
    }

    func testReadOnlyCapabilitiesDoNotAdvertiseStorableFields() throws {
        let shorten = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "shn"))

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
            "TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT",
            "TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT",
            "AUDIOMATOR_TRACKNUMBER_TEXT",
            "AUDIOMATOR_DISCNUMBER_TEXT",
        ]
        let bridgeKeys = Set(TagLibMetadataExtractor.knownMetadataPropertyKeys()).subtracting(internalKeys)

        XCTAssertEqual(bridgeKeys, MetadataFieldRegistry.canonicalPropertyMapKeys)
    }

    func testPropertyMapKeysHaveOneOwnerUnlessExplicitlyShared() {
        let collisions = MetadataFieldRegistry.propertyMapKeyOwners.filter { $0.value.count > 1 }

        XCTAssertEqual(collisions, MetadataFieldRegistry.sharedPropertyMapKeyOwners)
        XCTAssertEqual(
            Set(MetadataFieldRegistry.preferredSharedPropertyMapKeyOwner.keys),
            Set(MetadataFieldRegistry.sharedPropertyMapKeyOwners.keys)
        )
        for (key, preferredOwner) in MetadataFieldRegistry.preferredSharedPropertyMapKeyOwner {
            XCTAssertTrue(MetadataFieldRegistry.sharedPropertyMapKeyOwners[key]?.contains(preferredOwner) == true)
            XCTAssertEqual(MetadataFieldRegistry.schema(forPropertyMapKey: key)?.key, preferredOwner)
        }
    }

    func testBridgeContainerMappingsAgreeWithSwiftSchema() throws {
        for mapping in TagLibMetadataExtractor.metadataFieldMappings() {
            let canonical = try XCTUnwrap(mapping["canonicalPropertyKey"] as? String)
            let aliases = mapping["propertyAliases"] as? [String] ?? []
            let propertyKeys = [canonical] + aliases
            let schemas = MetadataFieldRegistry.allSchemas.filter {
                propertyKeys == $0.propertyMapKeys
            }
            // Engine PropertyMap aliases are separate from typed field identities.
            let semanticKeys = Set(schemas.map(\.semanticKey))
            let schema = try XCTUnwrap(
                semanticKeys.count == 1 ? schemas.first(where: \.isCanonicalSemanticOwner) ?? schemas.first : nil,
                "Bridge ordered mapping \(propertyKeys) must exactly match one Swift semantic owner; found \(schemas.map { $0.key.rawValue })"
            )

            if let frame = mapping["id3v2TextFrame"] as? String {
                XCTAssertTrue(
                    schema.mappings.contains { $0.format == .id3v2 && $0.storageKind == .textFrame && $0.keys.contains(frame) }
                        || schema.mappings.contains { $0.format == .id3v2 && $0.storageKind == .binary && $0.keys.contains(frame) }
                        || schema.mappings.contains { $0.format == .id3v2 && $0.storageKind == .extensionFrame && $0.keys.contains(frame) },
                    "\(schema.key.rawValue) / \(frame)"
                )
            }
            if let description = mapping["id3v2UserTextDescription"] as? String {
                XCTAssertTrue(
                    schema.mappings.contains { $0.format == .id3v2 && $0.storageKind == .userTextFrame && $0.keys.contains(description) },
                    "\(schema.key.rawValue) / \(description)"
                )
            }
            if let atom = mapping["mp4Atom"] as? String {
                XCTAssertTrue(
                    schema.mappings.contains { $0.format == .mp4 && $0.storageKind == .mp4Atom && $0.keys.contains(atom) }
                        || schema.mappings.contains { $0.format == .mp4 && $0.storageKind == .binary && $0.keys.contains(atom) },
                    "\(schema.key.rawValue) / \(atom)"
                )
            }
            if let description = mapping["mp4FreeformDescription"] as? String {
                let atom = "----:com.apple.iTunes:\(description)"
                XCTAssertTrue(
                    schema.mappings.contains { $0.format == .mp4 && $0.storageKind == .mp4Freeform && $0.keys.contains(atom) },
                    "\(schema.key.rawValue) / \(atom)"
                )
            }

            XCTAssertEqual(schema.isMultiValue, (mapping["multiValue"] as? NSNumber)?.boolValue ?? false, canonical)
            XCTAssertEqual(schema.isPeopleField, (mapping["peopleField"] as? NSNumber)?.boolValue ?? false, canonical)
            XCTAssertEqual(schema.isRoleQualified, (mapping["roleQualified"] as? NSNumber)?.boolValue ?? false, canonical)
        }
    }

    func testArtistTypeCanonicalKeyMatchesEverySchemaSurface() throws {
        let swiftSchema = try XCTUnwrap(MetadataFieldRegistry.schema(for: .artistType))
        XCTAssertEqual(
            swiftSchema.propertyMapKeys,
            ["MUSICBRAINZ_ARTISTTYPE", "ARTISTTYPE", "MUSICBRAINZ ARTIST TYPE"]
        )
        let bridgeMapping = try XCTUnwrap(TagLibMetadataExtractor.metadataFieldMappings().first {
            ($0["canonicalPropertyKey"] as? String) == "MUSICBRAINZ_ARTISTTYPE"
        })
        XCTAssertEqual(bridgeMapping["propertyAliases"] as? [String], ["ARTISTTYPE", "MUSICBRAINZ ARTIST TYPE"])
    }

    func testMKVExclusiveRegistrationsExistWithoutWriteCapability() throws {
        let episode = try XCTUnwrap(MetadataFieldRegistry.schema(for: .tvEpisode))
        let season = try XCTUnwrap(MetadataFieldRegistry.schema(for: .tvSeason))
        let episodeTarget = try XCTUnwrap(episode.targets(for: MetadataNativeFamily.matroska).first)
        let seasonTarget = try XCTUnwrap(season.targets(for: MetadataNativeFamily.matroska).first)

        XCTAssertEqual(episodeTarget.nativeIdentity, "PART_NUMBER@TargetTypeValue=50")
        XCTAssertEqual(seasonTarget.nativeIdentity, "PART_NUMBER@TargetTypeValue=60")
        XCTAssertNotEqual(episodeTarget.nativeIdentity, seasonTarget.nativeIdentity)
        XCTAssertEqual(episode.capability(for: MetadataNativeFamily.matroska), .unsupported)
        XCTAssertEqual(season.capability(for: MetadataNativeFamily.matroska), .unsupported)
        XCTAssertNil(episode.writeTarget(for: MetadataNativeFamily.matroska))
        XCTAssertNil(season.writeTarget(for: MetadataNativeFamily.matroska))
    }

    func testIndependentWritableFieldsDoNotSharePreferredNativeSlots() {
        XCTAssertEqual(MetadataFieldRegistry.duplicatePreferredWriteTargets, [:])
    }

    func testMappingContractVersionIsIndependentOfPackageRelease() {
        XCTAssertEqual(MetadataMappingCatalog.contractVersion, "AM-TLAM-MAPPING-2.2")
        XCTAssertEqual(
            MetadataFieldRegistry.allSchemas.map(\.mappingContractVersion).filter {
                $0 != MetadataMappingCatalog.contractVersion
            },
            []
        )
    }
}
