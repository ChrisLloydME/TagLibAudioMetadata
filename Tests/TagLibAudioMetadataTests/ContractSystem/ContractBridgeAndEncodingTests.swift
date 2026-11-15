import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

private func emptyMP4(_ url: URL) throws {
    try ContractMP4Seed.seed([], to: url)
}

private func seededMP4(_ url: URL, title: String = "Read Seed") throws -> Data {
    try ContractMP4Seed.seed([
        .init(key: "©nam", value: .text(title)),
        .init(key: "trkn", value: .intPair(first: 2, second: 9)),
        .init(key: "----:com.apple.iTunes:CONTRACT_UNKNOWN", value: .text("keep")),
    ], to: url)
    return try ContractMP4Oracle.read(url).audio
}

struct ContractBridgeAndEncodingTests {
    @Test func contractBridgeReadsRegistry() throws {
        try ContractFixture.withCopy("m4a") { url in
            let audio = try seededMP4(url)
            var evidence = ContractCase(
                scenario: "S-BRIDGE-READ-01",
                runtimeTest: "contractBridgeReadsRegistry",
                adapter: "facade reads+bridge reads"
            )
            let metadata = try PublicSurfaceAdapters.invoke(.facadeReadMetadataResult, url: url)
            guard case .metadata(let basic) = metadata else {
                evidence.check("facade.basic.type", false); try evidence.finish(); return
            }
            evidence.check("facade.basic.title", basic.title == "Read Seed")
            evidence.check("facade.basic.track", basic.track == 2 && basic.trackTotal == 9)

            let snapshot = try PublicSurfaceAdapters.invoke(.facadeReadSnapshot, url: url)
            if case .snapshot(let value) = snapshot {
                evidence.check("facade.snapshot.title", value.basic.title == "Read Seed")
                evidence.check("facade.snapshot.noAudio", value.audioContentIdentity == nil)
            } else { evidence.check("facade.snapshot.type", false) }

            let audioSnapshot = try PublicSurfaceAdapters.invoke(.facadeReadSnapshotWithAudio, url: url)
            if case .snapshot(let value) = audioSnapshot {
                // MP4 has no verified audio-content reader; nil is an explicit
                // unavailable result, not continuity evidence.
                evidence.check("facade.snapshot.audio.unavailable", value.audioContentIdentity == nil)
            } else { evidence.check("facade.snapshot.audio", false) }
            try ContractFixture.withCopy("flac") { flacURL in
                let flac = try PublicSurfaceAdapters.invoke(.facadeReadSnapshotWithAudio, url: flacURL)
                if case .snapshot(let value) = flac {
                    evidence.check("facade.snapshot.audio.flac", value.audioContentIdentity != nil)
                } else { evidence.check("facade.snapshot.audio.flac", false) }
            }

            let basicSnapshot = try PublicSurfaceAdapters.invoke(.facadeReadBasicSnapshot, url: url)
            if case .basicSnapshot(let value) = basicSnapshot {
                evidence.check("facade.basicSnapshot.title", value.metadata.title == "Read Seed")
            } else { evidence.check("facade.basicSnapshot", false) }

            let raw = try PublicSurfaceAdapters.invoke(.facadeReadRawMetadata, url: url)
            if case .raw(let value) = raw {
                evidence.check("facade.raw.nonempty", !value.properties.isEmpty)
            } else { evidence.check("facade.raw", false) }

            let structured = try PublicSurfaceAdapters.invoke(.facadeReadStructured, url: url)
            if case .structured(let value) = structured {
                evidence.check("facade.structured.atom", value.mp4Atoms.contains { $0.key == "©nam" })
            } else { evidence.check("facade.structured", false) }

            let bestBasic = try PublicSurfaceAdapters.invoke(.facadeBestEffortMetadata, url: url)
            if case .metadataOptional(let value) = bestBasic {
                evidence.check("facade.bestBasic", value?.title == "Read Seed")
            } else { evidence.check("facade.bestBasic", false) }
            let bestRaw = try PublicSurfaceAdapters.invoke(.facadeBestEffortRawMetadata, url: url)
            if case .rawOptional(let value) = bestRaw {
                evidence.check("facade.bestRaw", value?.properties.isEmpty == false)
            } else { evidence.check("facade.bestRaw", false) }
            let bestText = try PublicSurfaceAdapters.invoke(.facadeBestEffortRawMetadataText, url: url)
            if case .text(let value) = bestText {
                evidence.check("facade.bestText", value?.isEmpty == false)
            } else { evidence.check("facade.bestText", false) }
            let bestStructured = try PublicSurfaceAdapters.invoke(.facadeBestEffortStructured, url: url)
            if case .structuredOptional(let value) = bestStructured {
                evidence.check("facade.bestStructured", value?.mp4Atoms.isEmpty == false)
            } else { evidence.check("facade.bestStructured", false) }

            let bridgeModel = try PublicSurfaceAdapters.invoke(.bridgeExtractMetadata, url: url)
            if case .bridgeModel(let value) = bridgeModel {
                evidence.check("bridge.model.title", value?.title == "Read Seed")
            } else { evidence.check("bridge.model", false) }

            let projections = try PublicSurfaceAdapters.invoke(.bridgeMetadataProjections, url: url)
            if case .bridgeDictionary(let value) = projections {
                evidence.check("bridge.projections.keys", value["basic"] != nil && value["raw"] != nil && value["structured"] != nil)
            } else { evidence.check("bridge.projections", false) }

            for (mask, key) in [(UInt(1), "basic"), (2, "raw"), (4, "structured"), (8, "raw"), (16, "raw")] {
                let selected = try PublicSurfaceAdapters.invoke(.bridgeMetadataProjectionsOptions, url: url, input: .projections(mask: mask))
                if case .bridgeDictionary(let value) = selected {
                    evidence.check("bridge.projections.\(key).\(mask)", value[key] != nil)
                } else { evidence.check("bridge.projections.\(key).\(mask)", false) }
            }
            let zero = try PublicSurfaceAdapters.invoke(.bridgeMetadataProjectionsOptions, url: url, input: .projections(mask: 0))
            if case .bridgeDictionary(let value) = zero {
                evidence.check("bridge.projections.zero", value.isEmpty)
            } else { evidence.check("bridge.projections.zero", false) }

            let bridgeRaw = try PublicSurfaceAdapters.invoke(.bridgeRawMetadata, url: url)
            if case .bridgeDictionary(let value) = bridgeRaw {
                evidence.check("bridge.raw", value["properties"] != nil)
            } else { evidence.check("bridge.raw", false) }
            let bridgeStructured = try PublicSurfaceAdapters.invoke(.bridgeStructuredMetadata, url: url)
            if case .bridgeDictionary(let value) = bridgeStructured {
                evidence.check("bridge.structured", value["mp4Atoms"] != nil)
            } else { evidence.check("bridge.structured", false) }
            let dump = try PublicSurfaceAdapters.invoke(.bridgeDumpMetadataText, url: url)
            if case .text(let value) = dump {
                evidence.check("bridge.dump", value?.isEmpty == false)
            } else { evidence.check("bridge.dump", false) }
            let version = try PublicSurfaceAdapters.invoke(.facadeFileVersion, url: url)
            if case .version = version {
                evidence.check("facade.version", true)
            } else { evidence.check("facade.version", false) }
            let probe = try PublicSurfaceAdapters.invoke(.facadeProbeFile, url: url)
            if case .capability(let value) = probe {
                evidence.check("facade.probe", value?.identifier == "mp4")
            } else { evidence.check("facade.probe", false) }
            evidence.check("audio.unchanged", try ContractMP4Oracle.read(url).audio == audio)
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            _ = try seededMP4(url)
            var evidence = ContractCase(
                scenario: "S-BRIDGE-READ-02",
                runtimeTest: "contractBridgeReadsRegistry",
                adapter: "capability+registry queries"
            )
            let capability = try PublicSurfaceAdapters.invoke(.facadeCapability, url: url, input: .extensionName("m4a"))
            if case .capability(let value) = capability {
                evidence.check("capability.m4a", value?.identifier == "mp4" && value?.isWritable == true)
            } else { evidence.check("capability.m4a", false) }
            let support = try PublicSurfaceAdapters.invoke(.facadeFormatSupportLevel, url: url, input: .extensionName("m4a"))
            if case .support(let value) = support {
                evidence.check("support.m4a", value != .unsupported)
            } else { evidence.check("support.m4a", false) }
            let readable = try PublicSurfaceAdapters.invoke(.facadeIsReadableExtension, url: url, input: .extensionName("mp3"))
            if case .boolean(let value) = readable { evidence.check("isReadable.mp3", value) } else { evidence.check("isReadable.mp3", false) }
            let writable = try PublicSurfaceAdapters.invoke(.facadeIsWritableExtension, url: url, input: .extensionName("mka"))
            if case .boolean(let value) = writable { evidence.check("isWritable.mka", value == false) } else { evidence.check("isWritable.mka", false) }
            let readableExtensions = try PublicSurfaceAdapters.invoke(.facadeReadableExtensions, url: url)
            if case .strings(let values) = readableExtensions { evidence.check("readableExtensions", values.contains("m4a")) } else { evidence.check("readableExtensions", false) }
            let writableExtensions = try PublicSurfaceAdapters.invoke(.facadeWritableExtensions, url: url)
            if case .strings(let values) = writableExtensions { evidence.check("writableExtensions", values.contains("m4a")) } else { evidence.check("writableExtensions", false) }
            let capabilities = try PublicSurfaceAdapters.invoke(.facadeFormatCapabilities, url: url)
            if case .capabilities(let values) = capabilities {
                evidence.check("formatCapabilities", values.contains { $0.identifier == "mp4" })
            } else { evidence.check("formatCapabilities", false) }
            let bridgeReadable = try PublicSurfaceAdapters.invoke(.bridgeIsSupportedFormat, url: url, input: .extensionName("mp3"))
            if case .boolean(let value) = bridgeReadable { evidence.check("bridge.isSupportedFormat", value) } else { evidence.check("bridge.isSupportedFormat", false) }
            let bridgeWritable = try PublicSurfaceAdapters.invoke(.bridgeIsWritableFormat, url: url, input: .extensionName("mp3"))
            if case .boolean(let value) = bridgeWritable { evidence.check("bridge.isWritableFormat", value) } else { evidence.check("bridge.isWritableFormat", false) }
            let bridgeReadableExtensions = try PublicSurfaceAdapters.invoke(.bridgeSupportedExtensions, url: url)
            if case .strings(let values) = bridgeReadableExtensions { evidence.check("bridge.supportedExtensions", values.contains("m4a")) } else { evidence.check("bridge.supportedExtensions", false) }
            let bridgeWritableExtensions = try PublicSurfaceAdapters.invoke(.bridgeWritableExtensions, url: url)
            if case .strings(let values) = bridgeWritableExtensions { evidence.check("bridge.writableExtensions", values.contains("m4a")) } else { evidence.check("bridge.writableExtensions", false) }
            let bridgeCapability = try PublicSurfaceAdapters.invoke(.bridgeFormatCapability, url: url, input: .extensionName("m4a"))
            if case .bridgeOptionalDictionary(let value) = bridgeCapability {
                evidence.check("bridge.formatCapability", value?["identifier"] as? String == "mp4")
            } else { evidence.check("bridge.formatCapability", false) }
            let bridgeCapabilities = try PublicSurfaceAdapters.invoke(.bridgeFormatCapabilities, url: url)
            if case .bridgeDictionaries(let values) = bridgeCapabilities {
                evidence.check("bridge.formatCapabilities", values.contains { $0["identifier"] as? String == "mp4" })
            } else { evidence.check("bridge.formatCapabilities", false) }
            let keys = try PublicSurfaceAdapters.invoke(.bridgeKnownMetadataPropertyKeys, url: url)
            if case .strings(let values) = keys { evidence.check("bridge.knownKeys", values.contains("TITLE")) } else { evidence.check("bridge.knownKeys", false) }
            let mappings = try PublicSurfaceAdapters.invoke(.bridgeMetadataFieldMappings, url: url)
            if case .bridgeDictionaries(let values) = mappings { evidence.check("bridge.mappings", !values.isEmpty) } else { evidence.check("bridge.mappings", false) }

            let schema = try PublicSurfaceAdapters.invoke(.registrySchemaForKey, url: url, input: .schemaKey(.title))
            if case .schema(let value) = schema { evidence.check("registry.schema", value?.key == .title) } else { evidence.check("registry.schema", false) }
            let propertySchema = try PublicSurfaceAdapters.invoke(.registrySchemaForPropertyMapKey, url: url, input: .propertyKey("DATE"))
            if case .schema(let value) = propertySchema { evidence.check("registry.propertySchema", value?.key == .year) } else { evidence.check("registry.propertySchema", false) }
            let normalize = try PublicSurfaceAdapters.invoke(.registryNormalizeKey, url: url, input: .propertyKey(" album artist "))
            if case .text(let value) = normalize, let value { evidence.check("registry.normalize", value == "ALBUM ARTIST") } else { evidence.check("registry.normalize", false) }
            let schemas = try PublicSurfaceAdapters.invoke(.registrySchemas, url: url)
            if case .schemas(let values) = schemas {
                evidence.check("registry.schemas", values.contains { $0.key == .title })
            } else { evidence.check("registry.schemas", false) }
            let display = try PublicSurfaceAdapters.invoke(.registryShouldDisplayMultiValue, url: url, input: .propertyKey("PERFORMER:Role"))
            if case .boolean(let value) = display { evidence.check("registry.display", value) } else { evidence.check("registry.display", false) }
            let profile = try PublicSurfaceAdapters.invoke(.registryProfile, url: url, input: .propertyKey("TITLE"))
            if case .profile(let value) = profile { evidence.check("registry.profile", value?.semanticKey == "TITLE") } else { evidence.check("registry.profile", false) }
            let contract = try PublicSurfaceAdapters.invoke(.registryMappingContract, url: url)
            if case .text(let value) = contract {
                evidence.check("registry.contract", value == "AM-TLAM-MAPPING-2.2|2026-11-09")
            } else { evidence.check("registry.contract", false) }
            try evidence.finish()
        }
    }

    @Test func contractBridgeStructuredValidation() throws {
        let cases: [(String, [String: NSObject])] = [
            ("S-BRIDGE-VALID-01", ["mp4Atoms": [[
                "key": "trkn", "type": "intPair", "first": 70_000, "second": 0,
            ] as NSDictionary] as NSArray]),
            ("S-BRIDGE-VALID-02", ["mp4Atoms": [[
                "key": "tmpo", "type": "int", "value": 70_000,
            ] as NSDictionary] as NSArray]),
            ("S-BRIDGE-VALID-03", ["mp4Atoms": [[
                "key": "rtng", "type": "byte", "value": 256,
            ] as NSDictionary] as NSArray]),
            ("S-BRIDGE-VALID-04", ["mp4Atoms": [[
                "key": "pgap", "type": "bool", "value": "garbage",
            ] as NSDictionary] as NSArray]),
            ("S-BRIDGE-VALID-05", ["mp4Atoms": [[
                "key": "----:com.apple.iTunes:CONTRACT_INVALID", "type": "int", "value": 5,
            ] as NSDictionary] as NSArray]),
        ]
        for (scenario, payload) in cases {
            var evidence = ContractCase(
                scenario: scenario,
                runtimeTest: "contractBridgeStructuredValidation",
                adapter: "bridge.writeStructuredMetadata",
                outcome: "unsupported_reject"
            )
            let missing = FileManager.default.temporaryDirectory
                .appendingPathComponent("Contract-Missing-\(UUID().uuidString).m4a")
            do {
                _ = try PublicSurfaceAdapters.invoke(
                    .bridgeWriteStructuredMetadata, url: missing, input: .bridgeStructured(payload)
                )
                evidence.check("validation.reject", false, "invalid native payload was accepted")
            } catch {
                let nsError = error as NSError
                evidence.check("validation.domain", nsError.domain == "TagLibMetadataExtractor")
                evidence.check("validation.code", nsError.code == 243)
            }
            evidence.check("validation.no-file", !FileManager.default.fileExists(atPath: missing.path))
            try evidence.finish()
        }
    }

    @Test func contractBridgeWipe() throws {
        try ContractFixture.withCopy("m4a") { url in
            let audio = try seededMP4(url)
            var evidence = ContractCase(
                scenario: "S-BRIDGE-WIPE-01",
                runtimeTest: "contractBridgeWipe",
                adapter: "bridge.wipeMetadata"
            )
            let result = try PublicSurfaceAdapters.invoke(.bridgeWipeMetadata, url: url)
            if case .none = result { evidence.check("wipe.returned", true) } else { evidence.check("wipe.returned", false) }
            let after = try ContractMP4Oracle.read(url, allowingAbsentMetadata: true)
            evidence.check("wipe.metadata.absent", after.items.isEmpty)
            evidence.check("wipe.audio", after.audio == audio)
            evidence.check("wipe.reopen", try TagLibMetadataManager.readMetadataResult(from: url).title.isEmpty)
            try evidence.finish()
        }
    }

    @Test func contractEncodingFamilies() throws {
        // 01 — text atom through the exported structured surface.
        try ContractFixture.withCopy("m4a") { url in
            try emptyMP4(url)
            var evidence = ContractCase(
                scenario: "S-ENC-01", runtimeTest: "contractEncodingFamilies",
                adapter: "bridge.writeStructuredMetadata"
            )
            let audio = try ContractMP4Oracle.read(url).audio
            _ = try PublicSurfaceAdapters.invoke(.bridgeWriteStructuredMetadata, url: url, input: .bridgeStructured(
                ["mp4Atoms": [["key": "©nam", "type": "stringList", "values": ["Text Family"]] as NSDictionary] as NSArray]
            ))
            let after = try ContractMP4Oracle.read(url)
            evidence.check("text.native", try after.text("©nam") == "Text Family")
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        // 02 — duplicate array values through the facade raw-value surface.
        try ContractFixture.withCopy("flac") { url in
            try ContractFLACSeed.seed(comments: ["TITLE": ["Seed"], "CONTRACT": ["keep"]], to: url)
            var evidence = ContractCase(
                scenario: "S-ENC-02", runtimeTest: "contractEncodingFamilies",
                adapter: "facade.writeRawMapValues"
            )
            let audio = try ContractFLACOracle.read(url).audio
            _ = try PublicSurfaceAdapters.invoke(.facadeWriteRawMapValues, url: url, input: .rawValues(
                ["TITLE": ["First", "Second"]], mode: .replace, verify: true
            ))
            let after = try ContractFLACOracle.read(url)
            evidence.check("array.native", ContractAssertions.vorbisValues(after, "TITLE") == ["First", "Second"])
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        // 03 — boolean atom.
        try ContractFixture.withCopy("m4a") { url in
            try emptyMP4(url)
            var evidence = ContractCase(
                scenario: "S-ENC-03", runtimeTest: "contractEncodingFamilies",
                adapter: "bridge.writeStructuredMetadata"
            )
            let audio = try ContractMP4Oracle.read(url).audio
            _ = try PublicSurfaceAdapters.invoke(.bridgeWriteStructuredMetadata, url: url, input: .bridgeStructured(
                ["mp4Atoms": [["key": "pgap", "type": "bool", "value": true] as NSDictionary] as NSArray]
            ))
            let after = try ContractMP4Oracle.read(url)
            evidence.check("bool.native", after.payloads("pgap") == [Data([1])])
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        // 04 — byte-sized integer.
        try ContractFixture.withCopy("m4a") { url in
            try emptyMP4(url)
            var evidence = ContractCase(
                scenario: "S-ENC-04", runtimeTest: "contractEncodingFamilies",
                adapter: "bridge.writeStructuredMetadata"
            )
            let audio = try ContractMP4Oracle.read(url).audio
            _ = try PublicSurfaceAdapters.invoke(.bridgeWriteStructuredMetadata, url: url, input: .bridgeStructured(
                ["mp4Atoms": [["key": "rtng", "type": "byte", "value": 255] as NSDictionary] as NSArray]
            ))
            let after = try ContractMP4Oracle.read(url)
            evidence.check("byte.native", after.payloads("rtng") == [Data([255])])
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        // 05 — signed 16-bit integer.
        try ContractFixture.withCopy("m4a") { url in
            try emptyMP4(url)
            var evidence = ContractCase(
                scenario: "S-ENC-05", runtimeTest: "contractEncodingFamilies",
                adapter: "bridge.writeStructuredMetadata"
            )
            let audio = try ContractMP4Oracle.read(url).audio
            _ = try PublicSurfaceAdapters.invoke(.bridgeWriteStructuredMetadata, url: url, input: .bridgeStructured(
                ["mp4Atoms": [["key": "tmpo", "type": "int", "value": 32_767] as NSDictionary] as NSArray]
            ))
            let after = try ContractMP4Oracle.read(url)
            evidence.check("signed.native", after.payloads("tmpo") == [Data([0x7F, 0xFF])])
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        // 06 — unsigned 32-bit ASF integer, little-endian on the wire.
        try ContractFixture.withCopy("wma") { url in
            var evidence = ContractCase(
                scenario: "S-ENC-06", runtimeTest: "contractEncodingFamilies",
                adapter: "bridge.writeStructuredMetadata"
            )
            let before = try IndependentASF.attributes(Data(contentsOf: url))
            _ = try PublicSurfaceAdapters.invoke(.bridgeWriteStructuredMetadata, url: url, input: .bridgeStructured(
                ["asfAttributes": [[
                    "key": "CONTRACT_UINT", "type": "int", "value": 4_294_967_295,
                ] as NSDictionary] as NSArray]
            ))
            let after = try IndependentASF.attributes(Data(contentsOf: url))
            let attribute = try #require(after.first { $0.name == "CONTRACT_UINT" })
            evidence.check("unsigned.native", attribute.value == Data([0xFF, 0xFF, 0xFF, 0xFF]))
            evidence.check("unsigned.type", attribute.type == 3)
            evidence.check("read.unchanged", !before.contains { $0.name == "CONTRACT_UINT" })
            try evidence.finish()
        }

        // 07 — intPair through the facade typed planner.
        try ContractFixture.withCopy("m4a") { url in
            try emptyMP4(url)
            var evidence = ContractCase(
                scenario: "S-ENC-07", runtimeTest: "contractEncodingFamilies",
                adapter: "facade.applyPatch"
            )
            let audio = try ContractMP4Oracle.read(url).audio
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [.track: .integer(4), .trackTotal: .integer(11)])
            ))
            let after = try ContractMP4Oracle.read(url)
            let pair = try after.intPair("trkn")
            evidence.check("intPair.native", pair.first == 4 && pair.second == 11)
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        // 08 — UFID identifier bytes on ID3v2.4.
        try ContractFixture.withCopy("mp3") { url in
            let tag = try ContractID3Seed.tag(
                try ContractID3Seed.v24Frame("TIT2", ContractID3Seed.text("TIT2", "Seed", encoding: 3)),
                version: 4
            )
            try ContractID3Seed.seedMP3(url, tag: tag)
            var evidence = ContractCase(
                scenario: "S-ENC-08", runtimeTest: "contractEncodingFamilies",
                adapter: "bridge.writeStructuredMetadata"
            )
            let audio = try ContractID3Oracle.read(url).audio
            let owner = "http://musicbrainz.org"
            let data = Data([0x01, 0x02, 0x03, 0x04])
            _ = try PublicSurfaceAdapters.invoke(.bridgeWriteStructuredMetadata, url: url, input: .bridgeStructured(
                ["id3v2Frames": [[
                    "id": "UFID", "type": "ufid", "owner": owner, "data": data,
                ] as NSDictionary] as NSArray]
            ))
            let after = try ContractID3Oracle.read(url)
            let frame = try #require(after.frame("UFID"))
            evidence.check("identifier.owner", frame.payload.starts(with: Data(owner.utf8) + Data([0])))
            evidence.check("identifier.data", frame.payload.suffix(4) == data)
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        // 09 — artwork payload through the facade structured surface.
        try ContractFixture.withCopy("m4a") { url in
            try emptyMP4(url)
            var evidence = ContractCase(
                scenario: "S-ENC-09", runtimeTest: "contractEncodingFamilies",
                adapter: "facade.writeStructured"
            )
            let audio = try ContractMP4Oracle.read(url).audio
            let artwork = try ContractAssertions.artwork()
            _ = try PublicSurfaceAdapters.invoke(.facadeWriteStructured, url: url, input: .structured(
                StructuredMetadata(artwork: [.init(mimeType: "image/jpeg", data: artwork)]),
                includeProperties: false,
                replacing: [.artwork],
                verify: true
            ))
            let after = try ContractMP4Oracle.read(url)
            evidence.check("artwork.native", after.payloads("covr") == [artwork])
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        // 10 — qualified comment collection on ID3v2.4.
        try ContractFixture.withCopy("mp3") { url in
            let tag = try ContractID3Seed.tag(
                try ContractID3Seed.v24Frame("TIT2", ContractID3Seed.text("TIT2", "Seed", encoding: 3)),
                version: 4
            )
            try ContractID3Seed.seedMP3(url, tag: tag)
            var evidence = ContractCase(
                scenario: "S-ENC-10", runtimeTest: "contractEncodingFamilies",
                adapter: "bridge.writeStructuredMetadata"
            )
            let audio = try ContractID3Oracle.read(url).audio
            _ = try PublicSurfaceAdapters.invoke(.bridgeWriteStructuredMetadata, url: url, input: .bridgeStructured(
                ["comments": [[
                    "language": "eng", "description": "Contract", "text": "Qualified text",
                ] as NSDictionary] as NSArray]
            ))
            let after = try ContractID3Oracle.read(url)
            let comments = after.frames("COMM")
            evidence.check("qualified.count", comments.count == 1)
            let parsed = try ContractAssertions.id3Comment(try #require(comments.first))
            evidence.check("qualified.language", parsed.language == "eng")
            evidence.check("qualified.description", parsed.description == "Contract")
            evidence.check("qualified.text", parsed.text == "Qualified text")
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }
    }

    @Test func contractArtworkAndQualifiedCollections() throws {
        try ContractFixture.withCopy("m4a") { url in
            try emptyMP4(url)
            var evidence = ContractCase(
                scenario: "S-ART-01", runtimeTest: "contractArtworkAndQualifiedCollections",
                adapter: "facade.writeStructured"
            )
            let audio = try ContractMP4Oracle.read(url).audio
            let artwork = try ContractAssertions.artwork()
            _ = try PublicSurfaceAdapters.invoke(.facadeWriteStructured, url: url, input: .structured(
                StructuredMetadata(artwork: [.init(mimeType: "image/jpeg", data: artwork)]),
                includeProperties: false, replacing: [.artwork], verify: true
            ))
            evidence.check("artwork.replaced", try ContractMP4Oracle.read(url).payloads("covr") == [artwork])
            _ = try PublicSurfaceAdapters.invoke(.facadeWriteStructured, url: url, input: .structured(
                StructuredMetadata(), includeProperties: false, replacing: [.artwork], verify: true
            ))
            evidence.check("artwork.removed", try ContractMP4Oracle.read(url).has("covr") == false)
            evidence.check("audio.unchanged", try ContractMP4Oracle.read(url).audio == audio)
            try evidence.finish()
        }

        try ContractFixture.withCopy("mp3") { url in
            let tag = try ContractID3Seed.tag(
                try ContractID3Seed.v24Frame("TIT2", ContractID3Seed.text("TIT2", "Seed", encoding: 3)),
                version: 4
            )
            try ContractID3Seed.seedMP3(url, tag: tag)
            var evidence = ContractCase(
                scenario: "S-ART-02", runtimeTest: "contractArtworkAndQualifiedCollections",
                adapter: "bridge.writeStructuredMetadata"
            )
            let audio = try ContractID3Oracle.read(url).audio
            let artwork = try ContractAssertions.artwork()
            _ = try PublicSurfaceAdapters.invoke(.bridgeWriteStructuredMetadata, url: url, input: .bridgeStructured(
                ["artwork": [[
                    "mimeType": "image/jpeg", "pictureType": "Front Cover",
                    "description": "Contract", "data": artwork,
                ] as NSDictionary] as NSArray]
            ))
            let apic = try #require(try ContractID3Oracle.read(url).frame("APIC"))
            evidence.check("artwork.apic", apic.payload.suffix(artwork.count) == artwork)
            _ = try PublicSurfaceAdapters.invoke(.facadeWriteStructured, url: url, input: .structured(
                StructuredMetadata(), includeProperties: false, replacing: [.artwork], verify: true
            ))
            evidence.check("artwork.apic.removed", try ContractID3Oracle.read(url).frame("APIC") == nil)
            evidence.check("audio.unchanged", try ContractID3Oracle.read(url).audio == audio)
            try evidence.finish()
        }
    }
}
