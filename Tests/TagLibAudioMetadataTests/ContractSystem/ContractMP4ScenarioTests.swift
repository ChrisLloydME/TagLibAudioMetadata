import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

private func mp4Pair(_ first: Int, _ second: Int) -> Data {
    Data([0, 0])
        + ContractFixture.number(UInt64(first), bytes: 2)
        + ContractFixture.number(UInt64(second), bytes: 2)
        + Data([0, 0])
}

private func mp4DataText(_ text: String) -> Data { Data(text.utf8) }

private func mp4Payload(_ atoms: [[String: Any]]) -> [String: NSObject] {
    ["mp4Atoms": atoms as NSArray]
}

private func seedMP4Vertical(_ url: URL, title: String = "Seed Title") throws {
    try ContractMP4Seed.seed([
        .init(key: "trkn", value: .intPair(first: 3, second: 12)),
        .init(key: "©nam", value: .text(title)),
        .init(key: "©alb", value: .text("Seed Album")),
        .init(key: "----:com.apple.iTunes:CONTRACT_UNKNOWN", value: .text("keep")),
    ], to: url)
}

struct ContractMP4ScenarioTests {
    // MARK: - Vertical public scenario

    @Test func contractMP4TypedVertical() throws {
        try ContractFixture.withCopy("m4a") { url in
            try seedMP4Vertical(url)
            var evidence = ContractCase(
                scenario: "S-MP4-TYPED-01",
                runtimeTest: "contractMP4TypedVertical",
                adapter: "facade.applyPatch"
            )
            let audio = try ContractAssertions.verifyMP4Seed(url, expectedItems: [
                "trkn": mp4Pair(3, 12),
                "©nam": mp4DataText("Seed Title"),
                "©alb": mp4DataText("Seed Album"),
                "----:com.apple.iTunes:CONTRACT_UNKNOWN": mp4DataText("keep"),
            ], &evidence)
            let versionBefore = try TagLibMetadataManager.fileVersion(at: url)
            let result = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [
                    .title: .text("Contract Title"),
                    .track: .integer(5),
                    .trackTotal: .integer(12),
                ])
            ))
            if case .write(let write) = result {
                evidence.check("write.result", write.warnings.isEmpty, "unexpected warnings: \(write.warnings)")
            } else {
                evidence.check("write.result", false, "wrong adapter output")
            }
            let after = try ContractMP4Oracle.read(url)
            evidence.check("native.trkn", (try after.intPair("trkn")).first == 5)
            evidence.check("native.trkn.total", (try after.intPair("trkn")).second == 12)
            evidence.check("native.title", try after.text("©nam") == "Contract Title")
            evidence.check("native.untouched.album", try after.text("©alb") == "Seed Album")
            evidence.check("native.untouched.unknown", try after.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep")
            evidence.check("audio.unchanged", after.audio == audio)
            let reopened = try TagLibMetadataManager.readSnapshot(from: url)
            evidence.check("reopen.title", reopened.basic.title == "Contract Title")
            evidence.check("reopen.track", reopened.basic.track == 5 && reopened.basic.trackTotal == 12)
            evidence.check("reopen.version", reopened.fileVersion != versionBefore)
            try evidence.finish()
        }
    }

    @Test func contractMP4PublicSequence() throws {
        try ContractFixture.withCopy("m4a") { url in
            try seedMP4Vertical(url)
            var evidence = ContractCase(
                scenario: "S-MP4-SEQ-01",
                runtimeTest: "contractMP4PublicSequence",
                adapter: "facade.applyPatch+facade.writeStructured+facade.eraseAll"
            )
            let audio = try ContractAssertions.verifyMP4Seed(url, expectedItems: [
                "trkn": mp4Pair(3, 12),
                "©nam": mp4DataText("Seed Title"),
                "----:com.apple.iTunes:CONTRACT_UNKNOWN": mp4DataText("keep"),
            ], &evidence)
            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            evidence.check("snapshot.title", snapshot.basic.title == "Seed Title")
            let firstVersion = snapshot.fileVersion

            let first = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [.title: .text("First Edit")])
            ))
            if case .write = first { evidence.check("first.returned", true) } else {
                evidence.check("first.returned", false)
            }
            let afterFirst = try ContractMP4Oracle.read(url)
            evidence.check("first.title", try afterFirst.text("©nam") == "First Edit")
            evidence.check("first.unknown", try afterFirst.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep")

            let second = try PublicSurfaceAdapters.invoke(
                .bridgeWriteStructuredMetadata,
                url: url,
                input: .bridgeStructured(mp4Payload([[
                    "key": "©nam",
                    "type": "stringList",
                    "values": ["Second Edit"],
                ]]))
            )
            if case .none = second { evidence.check("second.returned", true) } else {
                evidence.check("second.returned", false)
            }
            let afterSecond = try ContractMP4Oracle.read(url)
            evidence.check("second.title", try afterSecond.text("©nam") == "Second Edit")
            evidence.check("second.unknown", try afterSecond.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep")

            let third = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [.title: .remove])
            ))
            if case .write = third { evidence.check("third.returned", true) } else {
                evidence.check("third.returned", false)
            }
            let afterThird = try ContractMP4Oracle.read(url)
            evidence.check("third.title.absent", !afterThird.has("©nam"))
            evidence.check("third.unknown", try afterThird.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep")
            evidence.check("third.version", try TagLibMetadataManager.fileVersion(at: url) != firstVersion)

            let erased = try PublicSurfaceAdapters.invoke(.facadeEraseAll, url: url)
            if case .write = erased { evidence.check("erase.returned", true) } else {
                evidence.check("erase.returned", false)
            }
            let afterErase = try ContractMP4Oracle.read(url, allowingAbsentMetadata: true)
            evidence.check("erase.metadata.absent", afterErase.items.isEmpty)
            evidence.check("erase.audio", afterErase.audio == audio)
            let reopened = try TagLibMetadataManager.readSnapshot(from: url)
            evidence.check("erase.reopen.title", reopened.basic.title.isEmpty)
            try evidence.finish()
        }
    }

    @Test func contractFullModelRetention() throws {
        try ContractFixture.withCopy("m4a") { url in
            try seedMP4Vertical(url)
            var evidence = ContractCase(
                scenario: "S-MP4-FULL-01",
                runtimeTest: "contractFullModelRetention",
                adapter: "facade.writeTagMetadata+bridge.writeMetadata"
            )
            let audio = try ContractAssertions.verifyMP4Seed(url, expectedItems: [
                "©alb": mp4DataText("Seed Album"),
                "----:com.apple.iTunes:CONTRACT_UNKNOWN": mp4DataText("keep"),
            ], &evidence)
            let bridgeMetadata = try TagLibMetadataExtractor.extractMetadata(from: url)
            bridgeMetadata.title = "Facade Full Model"
            let verification = TagLibMetadataManager.MetadataWriteVerificationContext(
                expectedTrackNumber: nil,
                expectedTrackTotal: nil,
                expectedTrackNumberText: nil,
                expectedDiscNumber: nil,
                expectedDiscTotal: nil,
                expectedDiscNumberText: nil,
                artworkExpectation: .skip,
                customFieldKeys: [],
                expectedTextFields: ["title": "Facade Full Model"]
            )
            let facade = try PublicSurfaceAdapters.invoke(
                .facadeWriteTagMetadata,
                url: url,
                input: .model(bridgeMetadata, verification)
            )
            if case .write = facade { evidence.check("facade.returned", true) } else {
                evidence.check("facade.returned", false)
            }
            let afterFacade = try ContractMP4Oracle.read(url)
            evidence.check("facade.title", try afterFacade.text("©nam") == "Facade Full Model")
            evidence.check("facade.unknown", try afterFacade.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep")
            evidence.check("facade.album", try afterFacade.text("©alb") == "Seed Album")

            let secondModel = try TagLibMetadataExtractor.extractMetadata(from: url)
            secondModel.title = "Bridge Full Model"
            let bridge = try PublicSurfaceAdapters.invoke(
                .bridgeWriteMetadata,
                url: url,
                input: .model(secondModel, .none)
            )
            if case .none = bridge { evidence.check("bridge.returned", true) } else {
                evidence.check("bridge.returned", false)
            }
            let afterBridge = try ContractMP4Oracle.read(url)
            evidence.check("bridge.title", try afterBridge.text("©nam") == "Bridge Full Model")
            evidence.check("bridge.unknown", try afterBridge.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep")
            evidence.check("bridge.album", try afterBridge.text("©alb") == "Seed Album")
            evidence.check("audio.unchanged", afterBridge.audio == audio)
            try evidence.finish()
        }
    }

    // MARK: - Raw write modes and deltas

    @Test func contractRawValueModes() throws {
        for (scenario, mode) in [("S-MP4-RAW-01", TagLibMetadataManager.RawPropertyMapWriteMode.replace),
                                 ("S-MP4-RAW-02", .merge)] {
            try ContractFixture.withCopy("m4a") { url in
                try ContractMP4Seed.seed([
                    .init(key: "©alb", value: .text("Seed Album")),
                    .init(key: "©nam", value: .text("Seed Title")),
                    .init(key: "----:com.apple.iTunes:CONTRACT_UNKNOWN", value: .text("keep")),
                ], to: url)
                var evidence = ContractCase(
                    scenario: scenario,
                    runtimeTest: "contractRawValueModes",
                    adapter: "facade.writeRawMapValues"
                )
                let audio = try ContractAssertions.verifyMP4Seed(url, expectedItems: [
                    "©alb": mp4DataText("Seed Album"),
                    "----:com.apple.iTunes:CONTRACT_UNKNOWN": mp4DataText("keep"),
                ], &evidence)
                let result = try PublicSurfaceAdapters.invoke(.facadeWriteRawMapValues, url: url, input:
                    .rawValues(["TITLE": ["Raw Title"]], mode: mode, verify: true))
                if case .write = result { evidence.check("write.returned", true) } else {
                    evidence.check("write.returned", false)
                }
                let after = try ContractMP4Oracle.read(url)
                evidence.check("native.title", try after.text("©nam") == "Raw Title")
                evidence.check("unknown.\(mode == .replace ? "removed" : "preserved")",
                               mode == .replace ? !after.has("----:com.apple.iTunes:CONTRACT_UNKNOWN")
                                                : (try after.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep"))
                evidence.check("album.\(mode == .replace ? "removed" : "preserved")",
                               mode == .replace ? !after.has("©alb") : (try after.text("©alb") == "Seed Album"))
                evidence.check("audio.unchanged", after.audio == audio)
                try evidence.finish()
            }
        }
    }

    @Test func contractRawDeltaAndBridgeReplace() throws {
        // Raw delta: explicit set plus explicit removal, leaving an unmentioned
        // owner alone.
        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seed([
                .init(key: "©alb", value: .text("Seed Album")),
                .init(key: "©nam", value: .text("Seed Title")),
                .init(key: "----:com.apple.iTunes:CONTRACT_UNKNOWN", value: .text("keep")),
            ], to: url)
            var evidence = ContractCase(
                scenario: "S-MP4-RAW-03",
                runtimeTest: "contractRawDeltaAndBridgeReplace",
                adapter: "facade.applyRawPatch"
            )
            let audio = try ContractAssertions.verifyMP4Seed(url, expectedItems: [
                "©alb": mp4DataText("Seed Album"),
                "©nam": mp4DataText("Seed Title"),
            ], &evidence)
            let result = try PublicSurfaceAdapters.invoke(.facadeApplyRawPatch, url: url, input:
                .rawPatch(RawMetadataPatch(valuesToSet: ["TITLE": ["Delta Title"]], removingKeys: ["ALBUM"])))
            if case .write = result { evidence.check("write.returned", true) } else {
                evidence.check("write.returned", false)
            }
            let after = try ContractMP4Oracle.read(url)
            evidence.check("native.title", try after.text("©nam") == "Delta Title")
            evidence.check("native.album.absent", !after.has("©alb"))
            evidence.check("native.unknown.preserved",
                           try after.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep")
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        // Direct exported bridge replacement is a separate adapter from the
        // facade merge/replace path.
        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seed([
                .init(key: "©alb", value: .text("Seed Album")),
                .init(key: "©nam", value: .text("Seed Title")),
                .init(key: "----:com.apple.iTunes:CONTRACT_UNKNOWN", value: .text("keep")),
            ], to: url)
            var evidence = ContractCase(
                scenario: "S-MP4-RAW-04",
                runtimeTest: "contractRawDeltaAndBridgeReplace",
                adapter: "bridge.writeRawPropertyMap"
            )
            let audio = try ContractAssertions.verifyMP4Seed(url, expectedItems: [
                "©nam": mp4DataText("Seed Title"),
            ], &evidence)
            let result = try PublicSurfaceAdapters.invoke(.bridgeWriteRawPropertyMap, url: url, input:
                .rawStrings(["TITLE": "Bridge Raw"], mode: .replace, verify: false))
            if case .none = result { evidence.check("write.returned", true) } else {
                evidence.check("write.returned", false)
            }
            let after = try ContractMP4Oracle.read(url)
            evidence.check("native.title", try after.text("©nam") == "Bridge Raw")
            evidence.check("native.album.absent", !after.has("©alb"))
            evidence.check("native.unknown.absent", !after.has("----:com.apple.iTunes:CONTRACT_UNKNOWN"))
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }
    }

    // MARK: - Number text and numeric boundaries

    @Test func contractNumberTextSurfaces() throws {
        try ContractFixture.withCopy("m4a") { url in
            var evidence = ContractCase(
                scenario: "S-MP4-NUMTEXT-01",
                runtimeTest: "contractNumberTextSurfaces",
                adapter: "facade.writeTrackNumberText"
            )
            let result = try PublicSurfaceAdapters.invoke(.facadeWriteTrackNumberText, url: url, input:
                .trackText(track: "05/12", disc: nil, verify: true))
            if case .write = result { evidence.check("write.returned", true) } else {
                evidence.check("write.returned", false)
            }
            let after = try ContractMP4Oracle.read(url)
            let pair5 = try after.intPair("trkn")
            evidence.check("native.trkn", pair5.first == 5 && pair5.second == 12)
            let reopened = try TagLibMetadataManager.readMetadataResult(from: url)
            evidence.check("reopen.track", reopened.track == 5 && reopened.trackTotal == 12)
            evidence.check("reopen.text", reopened.trackNumberText == "5/12", reopened.trackNumberText)
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            var evidence = ContractCase(
                scenario: "S-MP4-NUMTEXT-02",
                runtimeTest: "contractNumberTextSurfaces",
                adapter: "bridge.writeTrackNumber"
            )
            let result = try PublicSurfaceAdapters.invoke(.bridgeWriteTrackNumber, url: url, input:
                .trackNumber(track: 7, total: 12, padWidth: 3))
            if case .none = result { evidence.check("write.returned", true) } else {
                evidence.check("write.returned", false)
            }
            let after = try ContractMP4Oracle.read(url)
            let pair7 = try after.intPair("trkn")
            evidence.check("native.trkn", pair7.first == 7 && pair7.second == 12)
            let reopened = try TagLibMetadataManager.readMetadataResult(from: url)
            evidence.check("reopen.track", reopened.track == 7 && reopened.trackTotal == 12)
            evidence.check("reopen.text", reopened.trackNumberText == "7/12", reopened.trackNumberText)
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            var evidence = ContractCase(
                scenario: "S-MP4-NUMTEXT-03",
                runtimeTest: "contractNumberTextSurfaces",
                adapter: "bridge.writeTrackNumberText"
            )
            let result = try PublicSurfaceAdapters.invoke(.bridgeWriteTrackNumberText, url: url, input:
                .trackText(track: "9", disc: nil, verify: false))
            if case .none = result { evidence.check("write.returned", true) } else {
                evidence.check("write.returned", false)
            }
            let after = try ContractMP4Oracle.read(url)
            let pair9 = try after.intPair("trkn")
            evidence.check("native.trkn", pair9.first == 9 && pair9.second == 0)
            let reopened = try TagLibMetadataManager.readMetadataResult(from: url)
            evidence.check("reopen.track", reopened.track == 9 && reopened.trackTotal == 0)
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            try seedMP4Vertical(url)
            var evidence = ContractCase(
                scenario: "S-MP4-NUMTEXT-04",
                runtimeTest: "contractNumberTextSurfaces",
                adapter: "facade.writeTrackNumberText"
            )
            let audio = try ContractMP4Oracle.read(url).audio
            let result = try PublicSurfaceAdapters.invoke(.facadeWriteTrackNumberText, url: url, input:
                .trackText(track: "", disc: nil, verify: true))
            if case .write = result { evidence.check("write.returned", true) } else {
                evidence.check("write.returned", false)
            }
            let after = try ContractMP4Oracle.read(url)
            evidence.check("native.trkn.removed", !after.has("trkn"))
            let reopened = try TagLibMetadataManager.readMetadataResult(from: url)
            evidence.check("reopen.track", reopened.track == 0 && reopened.trackTotal == 0)
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }
    }

    @Test func contractMP4NumericBounds() throws {
        try ContractFixture.withCopy("m4a") { url in
            var evidence = ContractCase(
                scenario: "S-MP4-NUM-01",
                runtimeTest: "contractMP4NumericBounds",
                adapter: "facade.applyPatch"
            )
            let result = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [.track: .integer(65_535), .trackTotal: .integer(65_535)])
            ))
            if case .write = result { evidence.check("write.returned", true) } else {
                evidence.check("write.returned", false)
            }
            let after = try ContractMP4Oracle.read(url)
            let boundary = try after.intPair("trkn")
            evidence.check("native.boundary", boundary.first == 65_535 && boundary.second == 65_535)
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            var evidence = ContractCase(
                scenario: "S-MP4-NUM-02",
                runtimeTest: "contractMP4NumericBounds",
                adapter: "facade.applyPatch",
                outcome: "unsupported_reject"
            )
            try seedMP4Vertical(url)
            try ContractAssertions.expectRejection(&evidence, name: "track.65536", file: url) {
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                    MetadataPatch(fields: [.track: .integer(65_536)])
                ))
            }
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            var evidence = ContractCase(
                scenario: "S-MP4-NUM-03",
                runtimeTest: "contractMP4NumericBounds",
                adapter: "facade.applyPatch",
                outcome: "unsupported_reject"
            )
            try seedMP4Vertical(url)
            try ContractAssertions.expectRejection(&evidence, name: "track.negative", file: url) {
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                    MetadataPatch(fields: [.track: .integer(-1)])
                ))
            }
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            var evidence = ContractCase(
                scenario: "S-MP4-NUM-04",
                runtimeTest: "contractMP4NumericBounds",
                adapter: "facade.applyPatch"
            )
            let upper = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [.movementNumber: .integer(32_767)])
            ))
            if case .write = upper { evidence.check("movement.boundary.write", true) } else {
                evidence.check("movement.boundary.write", false)
            }
            let after = try ContractMP4Oracle.read(url)
            evidence.check("movement.boundary.atom", try after.integer("©mvi") == 32_767)
            let bytes = try Data(contentsOf: url)
            do {
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                    MetadataPatch(fields: [.movementNumber: .integer(32_768)])
                ))
                evidence.check("movement.overflow.reject", false)
            } catch {
                evidence.check("movement.overflow.reject", true)
            }
            evidence.check("movement.overflow.unchanged", try Data(contentsOf: url) == bytes)
            try evidence.finish()
        }
    }

    @Test func contractInvalidNumberTextRejects() throws {
        let texts = ["garbage", "1/2/3", String(repeating: "9", count: 40), "1\0/2"]
        for (index, text) in texts.enumerated() {
            try ContractFixture.withCopy("m4a") { url in
                try seedMP4Vertical(url)
                var evidence = ContractCase(
                    scenario: "S-MP4-BADNUM-0\(index + 1)",
                    runtimeTest: "contractInvalidNumberTextRejects",
                    adapter: "facade.applyPatch",
                    outcome: "unsupported_reject"
                )
                try ContractAssertions.expectRejection(&evidence, name: "numberText", file: url) {
                    _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                        MetadataPatch(numberText: .init(trackNumberText: text))
                    ))
                }
                try evidence.finish()
            }
        }
    }

    @Test func contractVerificationDisabled() throws {
        try ContractFixture.withCopy("m4a") { url in
            try seedMP4Vertical(url)
            var evidence = ContractCase(
                scenario: "S-MP4-VERIFYOFF-01",
                runtimeTest: "contractVerificationDisabled",
                adapter: "facade.writeStructured"
            )
            let audio = try ContractAssertions.verifyMP4Seed(url, expectedItems: [
                "©nam": mp4DataText("Seed Title"),
            ], &evidence)
            let result = try PublicSurfaceAdapters.invoke(.facadeWriteStructured, url: url, input: .structured(
                StructuredMetadata(mp4Atoms: [
                    .init(key: "©nam", type: "stringList", values: ["Unverified Write"]),
                ]),
                includeProperties: false,
                replacing: [],
                verify: false
            ))
            if case .write = result { evidence.check("write.returned", true) } else {
                evidence.check("write.returned", false)
            }
            let after = try ContractMP4Oracle.read(url)
            evidence.check("native.title", try after.text("©nam") == "Unverified Write")
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }
    }

    @Test func contractEraseAndReopen() throws {
        try ContractFixture.withCopy("m4a") { url in
            try seedMP4Vertical(url)
            var evidence = ContractCase(
                scenario: "S-MP4-ERASE-01",
                runtimeTest: "contractEraseAndReopen",
                adapter: "facade.eraseAll"
            )
            let audio = try ContractAssertions.verifyMP4Seed(url, expectedItems: [
                "trkn": mp4Pair(3, 12),
                "©nam": mp4DataText("Seed Title"),
            ], &evidence)
            let result = try PublicSurfaceAdapters.invoke(.facadeEraseAll, url: url)
            if case .write = result { evidence.check("erase.returned", true) } else {
                evidence.check("erase.returned", false)
            }
            let after = try ContractMP4Oracle.read(url, allowingAbsentMetadata: true)
            evidence.check("native.metadata.absent", after.items.isEmpty)
            evidence.check("audio.unchanged", after.audio == audio)
            let reopened = try TagLibMetadataManager.readMetadataResult(from: url)
            evidence.check("reopen.title", reopened.title.isEmpty)
            evidence.check("reopen.track", reopened.track == 0 && reopened.trackTotal == 0)
            try evidence.finish()
        }
    }

    // MARK: - Transactions and batches

    @Test func contractStaleGuards() throws {
        try ContractFixture.withCopy("m4a") { url in
            try seedMP4Vertical(url)
            var evidence = ContractCase(
                scenario: "S-MP4-STALE-01",
                runtimeTest: "contractStaleGuards",
                adapter: "facade.applyPatch",
                outcome: "unsupported_reject"
            )
            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            let external = try TagLibMetadataExtractor.extractMetadata(from: url)
            external.album = "External Edit"
            _ = try PublicSurfaceAdapters.invoke(.bridgeWriteMetadata, url: url, input: .model(external, .none))
            let bytesAfterExternal = try Data(contentsOf: url)
            do {
                _ = try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.title: .text("Stale")]),
                    to: url,
                    expectedVersion: snapshot.fileVersion
                )
                evidence.check("stale.version.reject", false)
            } catch {
                evidence.check("stale.version.reject", true)
            }
            evidence.check("stale.version.unchanged", try Data(contentsOf: url) == bytesAfterExternal)
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            var evidence = ContractCase(
                scenario: "S-MP4-STALE-02",
                runtimeTest: "contractStaleGuards",
                adapter: "facade.applyPatchGuarded",
                outcome: "unsupported_reject"
            )
            let mp4Version = try TagLibMetadataManager.fileVersion(at: url)
            let flacURL = try ContractFixture.copy("flac")
            defer { try? FileManager.default.removeItem(at: flacURL.deletingLastPathComponent()) }
            let flacSnapshot = try TagLibMetadataManager.readSnapshot(from: flacURL, includingAudioContent: true)
            let otherAudio = try #require(flacSnapshot.audioContentIdentity)
            let before = try Data(contentsOf: url)
            do {
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatchGuarded, url: url, input: .patchGuarded(
                    MetadataPatch(fields: [.title: .text("Wrong Audio")]),
                    expectedVersion: mp4Version,
                    audio: otherAudio
                ))
                evidence.check("audio.guard.reject", false)
            } catch {
                evidence.check("audio.guard.reject", true)
            }
            evidence.check("audio.guard.unchanged", try Data(contentsOf: url) == before)
            try evidence.finish()
        }
    }

    @Test func contractBatchPerFile() throws {
        var copies: [URL] = []
        defer {
            for url in copies { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        }
        for index in 0..<3 {
            let url = try ContractFixture.copy("m4a")
            copies.append(url)
            try ContractMP4Seed.seed([
                .init(key: "©nam", value: .text("Batch \(index)")),
                .init(key: "----:com.apple.iTunes:CONTRACT_UNKNOWN", value: .text("keep-\(index)")),
            ], to: url)
        }
        var audio: [Data] = []
        for (index, url) in copies.enumerated() {
            let oracle = try ContractMP4Oracle.read(url)
            try #require(oracle.audio.count > 0, "batch seed audio \(index)")
            audio.append(oracle.audio)
        }

        var success = ContractCase(
            scenario: "S-MP4-BATCH-01",
            runtimeTest: "contractBatchPerFile",
            adapter: "facade.applyPatch"
        )
        _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: copies[0], input: .patch(
            MetadataPatch(fields: [.title: .text("Batch One")])
        ))
        let first = try ContractMP4Oracle.read(copies[0])
        success.check("file0.title", try first.text("©nam") == "Batch One")
        success.check("file0.unknown", try first.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep-0")
        success.check("file0.audio", first.audio == audio[0])
        try success.finish()

        var rejected = ContractCase(
            scenario: "S-MP4-BATCH-02",
            runtimeTest: "contractBatchPerFile",
            adapter: "facade.applyPatch",
            outcome: "unsupported_reject"
        )
        try ContractAssertions.expectRejection(&rejected, name: "file1.overflow", file: copies[1]) {
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: copies[1], input: .patch(
                MetadataPatch(fields: [.track: .integer(65_536)])
            ))
        }
        let second = try ContractMP4Oracle.read(copies[1])
        rejected.check("file1.title.unchanged", try second.text("©nam") == "Batch 1")
        rejected.check("file1.audio", second.audio == audio[1])
        try rejected.finish()

        var independent = ContractCase(
            scenario: "S-MP4-BATCH-03",
            runtimeTest: "contractBatchPerFile",
            adapter: "facade.applyPatch"
        )
        _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: copies[2], input: .patch(
            MetadataPatch(fields: [.title: .text("Batch Three")])
        ))
        let third = try ContractMP4Oracle.read(copies[2])
        independent.check("file2.title", try third.text("©nam") == "Batch Three")
        independent.check("file2.unknown", try third.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep-2")
        independent.check("file2.audio", third.audio == audio[2])
        try independent.finish()
    }
}


extension ContractMP4ScenarioTests {
    @Test func contractFullModelRetiresEditedReleaseAlias() throws {
        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seed([
                .init(key: "----:com.apple.iTunes:MUSICBRAINZ_ALBUMTYPE", value: .text("StaleAlias")),
                .init(key: "----:com.apple.iTunes:MusicBrainz Album Type", value: .text("OldCanonical")),
                .init(key: "----:com.apple.iTunes:CONTRACT_UNKNOWN", value: .text("keep"))
            ], to: url)
            let before = try ContractMP4Oracle.read(url)
            var evidence = ContractCase(scenario: "S-FULL-ALIAS-01", runtimeTest: "contractFullModelRetiresEditedReleaseAlias", adapter: "bridge.writeMetadata")
            evidence.check("seed.release", try before.text("----:com.apple.iTunes:MusicBrainz Album Type") == "OldCanonical")
            let model = try TagLibMetadataExtractor.extractMetadata(from: url); model.releaseType = "Canonical"
            _ = try PublicSurfaceAdapters.invoke(.bridgeWriteMetadata, url: url, input: .model(model, .none))
            let after = try ContractMP4Oracle.read(url)
            evidence.check("release.canonical", try after.text("----:com.apple.iTunes:MusicBrainz Album Type") == "Canonical")
            evidence.check("unknown.preserved", try after.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep")
            evidence.check("audio.preserved", after.audio == before.audio)
            try evidence.finish()
        }
    }
}
