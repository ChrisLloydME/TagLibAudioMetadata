import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

private func txxxPayload(description: String, value: String) -> Data {
    Data([3]) + Data(description.utf8) + Data([0]) + Data(value.utf8)
}

private func seedV23Flagged(_ url: URL) throws -> Data {
    let frames = ContractID3Seed.frame("TYER", ContractID3Seed.text("TYER", "2004", encoding: 0),
                                       status: 0x20, format: 0x20, groupID: 7)
        + ContractID3Seed.frame("TDAT", ContractID3Seed.text("TDAT", "0906", encoding: 0),
                                status: 0x20, format: 0x20, groupID: 1)
        + ContractID3Seed.frame("TORY", ContractID3Seed.text("TORY", "1999", encoding: 0))
        + ContractID3Seed.frame("TIT2", ContractID3Seed.text("TIT2", "Seed", encoding: 0))
        + ContractID3Seed.frame("TXXX", txxxPayload(description: "TAGLIBAUDIOMETADATA_YEAR_TEXT", value: "2004"))
    let audio = try ContractID3Oracle.read(url).audio
    try ContractID3Seed.seedMP3(url, tag: try ContractID3Seed.tag(frames, version: 3, tagFlags: 0))
    return audio
}

struct ContractNativeContainerTests {
    @Test func contractV23FlaggedPreservation() throws {
        try ContractFixture.withCopy("mp3") { url in
            var evidence = ContractCase(
                scenario: "S-ID3-V23-FLAGS-01",
                runtimeTest: "contractV23FlaggedPreservation",
                adapter: "facade.applyPatch"
            )
            let audio = try seedV23Flagged(url)
            let seeded = try ContractID3Oracle.read(url)
            evidence.check("seed.version", seeded.version == 3)
            evidence.check("seed.tyer.flags", seeded.frame("TYER")?.status == 0x20
                && seeded.frame("TYER")?.format == 0x20 && seeded.frame("TYER")?.groupID == 7)
            evidence.check("seed.tdat.group", seeded.frame("TDAT")?.groupID == 1)
            let privateBefore = try ContractID3Oracle.read(url).frames("TXXX").map(\.payload)
            let bytesBefore = try Data(contentsOf: url)
            var mutationError: Error?
            do {
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                    MetadataPatch(fields: [.title: .text("Unrelated Edit")])
                ))
            } catch {
                mutationError = error
            }
            let after = try ContractID3Oracle.read(url)
            evidence.check("mutation.outcome", true,
                           mutationError == nil ? "saved" : "rejected safely: \(mutationError!)")
            if mutationError == nil {
                evidence.check("version.preserved", after.version == 3)
                evidence.check("tyer.value", after.frame("TYER")?.text == "2004")
                evidence.check("tdat.value", after.frame("TDAT")?.text == "0906")
                evidence.check("tyer.status.flag", after.frame("TYER")?.status == 0x20)
                evidence.check("tyer.format.flag", after.frame("TYER")?.format == 0x20)
                evidence.check("tyer.group.identity", after.frame("TYER")?.groupID == 7)
                evidence.check("tdat.group.identity", after.frame("TDAT")?.groupID == 1)
                evidence.check("private.payloads", after.frames("TXXX").map(\.payload) == privateBefore)
                evidence.check("audio.unchanged", after.audio == audio)
            } else {
                evidence.check("rejected.bytes.unchanged", try Data(contentsOf: url) == bytesBefore)
                evidence.check("rejected.version.unchanged", after.version == 3)
                evidence.check("rejected.tyer.value", after.frame("TYER")?.text == "2004")
                evidence.check("rejected.tdat.value", after.frame("TDAT")?.text == "0906")
                evidence.check("rejected.tyer.status.flag", after.frame("TYER")?.status == 0x20)
                evidence.check("rejected.tyer.group.identity", after.frame("TYER")?.groupID == 7)
                evidence.check("rejected.private.payloads", after.frames("TXXX").map(\.payload) == privateBefore)
                evidence.check("rejected.audio.unchanged", after.audio == audio)
            }
            try evidence.finish()
        }
    }

    @Test func contractV23DateRejections() throws {
        try ContractFixture.withCopy("mp3") { url in
            _ = try seedV23Flagged(url)
            var evidence = ContractCase(
                scenario: "S-ID3-V23-DATE-01",
                runtimeTest: "contractV23DateRejections",
                adapter: "facade.applyPatch",
                outcome: "read_only_reject"
            )
            try ContractAssertions.expectRejection(&evidence, name: "typed.year", file: url) {
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                    MetadataPatch(fields: [.year: .text("2005")])
                ))
            }
            try evidence.finish()
        }

        try ContractFixture.withCopy("mp3") { url in
            _ = try seedV23Flagged(url)
            var evidence = ContractCase(
                scenario: "S-ID3-V23-DATE-02",
                runtimeTest: "contractV23DateRejections",
                adapter: "facade.writeStructured",
                outcome: "read_only_reject"
            )
            try ContractAssertions.expectRejection(&evidence, name: "structured.year", file: url) {
                _ = try PublicSurfaceAdapters.invoke(.facadeWriteStructured, url: url, input: .structured(
                    StructuredMetadata(id3v2Frames: [
                        .init(frameID: "TYER", type: "text", values: ["2005"]),
                    ]),
                    includeProperties: false,
                    replacing: [],
                    verify: true
                ))
            }
            try evidence.finish()
        }

        try ContractFixture.withCopy("mp3") { url in
            _ = try seedV23Flagged(url)
            var evidence = ContractCase(
                scenario: "S-ID3-V23-DATE-03",
                runtimeTest: "contractV23DateRejections",
                adapter: "bridge.writeStructuredMetadata",
                outcome: "read_only_reject"
            )
            try ContractAssertions.expectRejection(&evidence, name: "bridge.structured.year", file: url) {
                _ = try PublicSurfaceAdapters.invoke(.bridgeWriteStructuredMetadata, url: url, input: .bridgeStructured(
                    ["id3v2Frames": [[
                        "id": "TYER", "type": "text", "values": ["2005"],
                    ] as NSDictionary] as NSArray]
                ))
            }
            try evidence.finish()
        }
    }

    @Test func contractPrivateProvenance() throws {
        try ContractFixture.withCopy("mp3") { url in
            let frames = try ContractID3Seed.v24Frame("TIT2", ContractID3Seed.text("TIT2", "Seed", encoding: 3))
                + (try ContractID3Seed.v24Frame("TXXX", txxxPayload(description: "AUDIOMATOR_YEAR_TEXT", value: "2004")))
                + (try ContractID3Seed.v24Frame("TXXX", txxxPayload(description: "TAGLIBAUDIOMETADATA_YEAR_TEXT", value: "2005")))
                + (try ContractID3Seed.v24Frame("TXXX", txxxPayload(description: "AUDIOMATOR_TRACKNUMBER_TEXT", value: "03/12")))
            try ContractID3Seed.seedMP3(url, tag: try ContractID3Seed.tag(frames, version: 4))
            var evidence = ContractCase(
                scenario: "S-ID3-PRIVATE-01",
                runtimeTest: "contractPrivateProvenance",
                adapter: "facade.applyPatch"
            )
            let audio = try ContractID3Oracle.read(url).audio
            let before = try ContractID3Oracle.read(url).frames("TXXX").map(\.payload)
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [.title: .text("Provenance Edit")])
            ))
            let after = try ContractID3Oracle.read(url)
            evidence.check("private.both.namespaces", after.frames("TXXX").map(\.payload) == before)
            let parsed = try after.frames("TXXX").map { try ContractAssertions.id3UserText($0) }
            evidence.check("private.audiomator", parsed.contains { $0.description == "AUDIOMATOR_YEAR_TEXT" && $0.values == ["2004"] })
            evidence.check("private.taglibaudiometadata",
                           parsed.contains { $0.description == "TAGLIBAUDIOMETADATA_YEAR_TEXT" && $0.values == ["2005"] })
            evidence.check("private.track.text", parsed.contains { $0.description == "AUDIOMATOR_TRACKNUMBER_TEXT" && $0.values == ["03/12"] })
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }
    }

    @Test func contractFLACArrayPreservation() throws {
        try ContractFixture.withCopy("flac") { url in
            try ContractFLACSeed.seed(comments: [
                "TITLE": ["Seed"],
                "YEAR": ["2001", "2001"],
                "CONTRACT": [" keep "],
                "AUDIOMATOR_YEAR_TEXT": ["2001"],
                "TAGLIBAUDIOMETADATA_YEAR_TEXT": ["legacy"],
            ], to: url)
            var evidence = ContractCase(
                scenario: "S-FLAC-ARRAY-01",
                runtimeTest: "contractFLACArrayPreservation",
                adapter: "facade.applyPatch"
            )
            let audio = try ContractFLACOracle.read(url).audio
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [.title: .text("Edited Title")])
            ))
            let after = try ContractFLACOracle.read(url)
            evidence.check("title.written", ContractAssertions.vorbisValues(after, "TITLE") == ["Edited Title"])
            evidence.check("year.duplicates", ContractAssertions.vorbisValues(after, "YEAR") == ["2001", "2001"])
            evidence.check("unknown.whitespace", ContractAssertions.vorbisValues(after, "CONTRACT") == [" keep "])
            evidence.check("audiomator.namespace", ContractAssertions.vorbisValues(after, "AUDIOMATOR_YEAR_TEXT") == ["2001"])
            evidence.check("taglibaudiometadata.namespace",
                           ContractAssertions.vorbisValues(after, "TAGLIBAUDIOMETADATA_YEAR_TEXT") == ["legacy"])
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }
    }

    @Test func contractFLACExplicitRemoval() throws {
        try ContractFixture.withCopy("flac") { url in
            try ContractFLACSeed.seed(comments: [
                "YEAR": ["2001"],
                "DATE": ["0906"],
                "CONTRACT": ["keep"],
                "AUDIOMATOR_YEAR_TEXT": ["2001"],
            ], to: url)
            var evidence = ContractCase(
                scenario: "S-FLAC-REMOVE-01",
                runtimeTest: "contractFLACExplicitRemoval",
                adapter: "facade.applyPatch"
            )
            let audio = try ContractFLACOracle.read(url).audio
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [.standaloneDate: .remove])
            ))
            let after = try ContractFLACOracle.read(url)
            evidence.check("date.removed", ContractAssertions.vorbisValues(after, "DATE").isEmpty)
            evidence.check("year.retained", ContractAssertions.vorbisValues(after, "YEAR") == ["2001"])
            evidence.check("unknown.retained", ContractAssertions.vorbisValues(after, "CONTRACT") == ["keep"])
            evidence.check("private.retained", ContractAssertions.vorbisValues(after, "AUDIOMATOR_YEAR_TEXT") == ["2001"])
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }
    }

    @Test func contractWAVAndAIFFID3() throws {
        for (scenario, ext, name) in [("S-WAV-ID3-01", "wav", "info-only"), ("S-AIFF-ID3-01", "aiff", "clean-room")] {
            try ContractFixture.withCopy(ext, name: name) { url in
                let tag = try ContractID3Seed.tag(
                    try ContractID3Seed.v24Frame("TIT2", ContractID3Seed.text("TIT2", "Seed", encoding: 3)),
                    version: 4
                )
                try ContractID3Seed.seedContainer(url, tag: tag)
                var evidence = ContractCase(
                    scenario: scenario,
                    runtimeTest: "contractWAVAndAIFFID3",
                    adapter: "facade.applyPatch"
                )
                let before = try ContractRIFFOracle.read(url)
                let audio = before.audio
                let infoBefore = before.chunks.first { $0.id == "LIST" }?.raw
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                    MetadataPatch(fields: [.title: .text("Container Title")])
                ))
                let after = try ContractRIFFOracle.read(url)
                let id3 = try ContractID3Oracle.read(url)
                evidence.check("id3.title", id3.frame("TIT2")?.text == "Container Title")
                evidence.check("container.declared.size", after.declaredSize == (try Data(contentsOf: url)).count - 8)
                evidence.check("container.chunk.alignment",
                               after.chunks.allSatisfy { $0.raw.count == 8 + $0.payload.count + $0.payload.count % 2 })
                evidence.check("audio.unchanged", after.audio == audio)
                if let infoBefore {
                    evidence.check("info.chunk.preserved", after.chunks.first { $0.id == "LIST" }?.raw == infoBefore)
                } else {
                    evidence.check("container.readable", !after.chunks.isEmpty)
                }
                try evidence.finish()
            }
        }
    }

    @Test func contractASFAdvisoryPreservation() throws {
        try ContractFixture.withCopy("wma") { url in
            try IndependentASF.seed([
                .init(name: "ITUNESADVISORY", type: 0, language: 0, stream: 0,
                      value: IndependentASF.text("4")),
            ], at: url)
            var evidence = ContractCase(
                scenario: "S-ASF-ADV-01",
                runtimeTest: "contractASFAdvisoryPreservation",
                adapter: "facade.applyPatch"
            )
            let before = try TagLibMetadataManager.readMetadataResult(from: url)
            evidence.check("unknown.raw.read", before.explicitAdvisory == .unspecified && before.explicitAdvisoryRawValue == "4")
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [.title: .text("ASF Unrelated")])
            ))
            let attributes = try IndependentASF.attributes(Data(contentsOf: url))
            evidence.check("unknown.raw.preserved",
                           attributes.contains { $0.name == "ITUNESADVISORY" && $0.value == IndependentASF.text("4") })
            let after = try TagLibMetadataManager.readMetadataResult(from: url)
            evidence.check("unknown.semantic.unspecified", after.explicitAdvisory == .unspecified)
            evidence.check("unknown.raw.reopen", after.explicitAdvisoryRawValue == "4")
            try evidence.finish()
        }

        try ContractFixture.withCopy("wma") { url in
            var evidence = ContractCase(
                scenario: "S-ASF-ADV-02",
                runtimeTest: "contractASFAdvisoryPreservation",
                adapter: "facade.applyPatch"
            )
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(explicitAdvisory: .clean)
            ))
            let after = try TagLibMetadataManager.readMetadataResult(from: url)
            evidence.check("known.semantic.clean", after.explicitAdvisory == .clean)
            evidence.check("known.raw.cleared", after.explicitAdvisoryRawValue == nil)
            evidence.check("native.attribute.present", !(try IndependentASF.attributes(Data(contentsOf: url)))
                .filter { ["ITUNESADVISORY", "ADVISORY"].contains($0.name.uppercased()) }.isEmpty)
            try evidence.finish()
        }
    }

    @Test func contractASFPartialPairRejects() throws {
        try ContractFixture.withCopy("wma") { url in
            try IndependentASF.seed([
                .init(name: "WM/TrackNumber", type: 0, language: 0, stream: 0,
                      value: IndependentASF.text("3/12")),
            ], at: url)
            var evidence = ContractCase(
                scenario: "S-ASF-PAIR-01",
                runtimeTest: "contractASFPartialPairRejects",
                adapter: "facade.applyPatch",
                outcome: "unsupported_reject"
            )
            try ContractAssertions.expectRejection(&evidence, name: "partial.pair", file: url) {
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                    MetadataPatch(fields: [.track: .integer(0)])
                ))
            }
            let attributes = try IndependentASF.attributes(Data(contentsOf: url))
            evidence.check("native.pair.unchanged",
                           attributes.contains { $0.name == "WM/TrackNumber" && $0.value == IndependentASF.text("3/12") })
            try evidence.finish()
        }
    }

    @Test func contractTrackerRoute() throws {
        try ContractFixture.withCopy("xm") { url in
            var evidence = ContractCase(
                scenario: "S-TRACKER-01",
                runtimeTest: "contractTrackerRoute",
                adapter: "facade.applyPatch"
            )
            let before = try RepairXMHeader.read(url)
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [.trackerName: .text("ContractTracker")])
            ))
            let after = try RepairXMHeader.read(url)
            evidence.check("tracker.bytes", after.rawTrackerBytes.prefix(15) == Data("ContractTracker".utf8), String(decoding: after.rawTrackerBytes, as: UTF8.self))
            evidence.check("tracker.padding", after.rawTrackerBytes.count == 20
                && after.rawTrackerBytes.dropFirst(15).allSatisfy { $0 == 0 })
            evidence.check("module.unchanged", after.moduleName == before.moduleName)
            evidence.check("audio.suffix.unchanged", after.suffix == before.suffix)
            try evidence.finish()
        }
    }

    @Test func contractUnsupportedRoutesReject() throws {
        try ContractFixture.withCopy("m4a") { url in
            var evidence = ContractCase(
                scenario: "S-UNSUP-01",
                runtimeTest: "contractUnsupportedRoutesReject",
                adapter: "facade.applyPatch",
                outcome: "unsupported_reject"
            )
            try ContractAssertions.expectRejection(&evidence, name: "role.qualified.performer", file: url) {
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                    MetadataPatch(fields: [.performer: .text("Someone")])
                ))
            }
            try evidence.finish()
        }

        try ContractFixture.withCopy("flac") { url in
            var evidence = ContractCase(
                scenario: "S-UNSUP-02",
                runtimeTest: "contractUnsupportedRoutesReject",
                adapter: "facade.applyPatch",
                outcome: "unsupported_reject"
            )
            try ContractAssertions.expectRejection(&evidence, name: "rate.on.flac", file: url) {
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                    MetadataPatch(fields: [.rate: .integer(1)])
                ))
            }
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            let mka = url.deletingLastPathComponent().appendingPathComponent("fixture.mka")
            try FileManager.default.moveItem(at: url, to: mka)
            var evidence = ContractCase(
                scenario: "S-UNSUP-03",
                runtimeTest: "contractUnsupportedRoutesReject",
                adapter: "facade.applyPatch",
                outcome: "unsupported_reject"
            )
            let declared = try PublicSurfaceAdapters.invoke(.facadeIsWritableExtension, url: mka, input: .extensionName("mka"))
            if case .boolean(let writable) = declared { evidence.check("matroska.notWritable", !writable) }
            else { evidence.check("matroska.notWritable", false) }
            try ContractAssertions.expectRejection(&evidence, name: "matroska.extension", file: mka) {
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: mka, input: .patch(
                    MetadataPatch(fields: [.title: .text("Unsupported")])
                ))
            }
            try evidence.finish()
        }
    }

    @Test func contractNormalizationPlan() throws {
        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seed([
                .init(key: "trkn", value: .intPair(first: 3, second: 12)),
                .init(key: "disk", value: .intPair(first: 1, second: 2)),
                .init(key: "©nam", value: .text("Normalize")),
                .init(key: "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT", value: .text("03/12")),
            ], to: url)
            var evidence = ContractCase(
                scenario: "S-NORM-01",
                runtimeTest: "contractNormalizationPlan",
                adapter: "facade.planNormalization+facade.applyNormalization"
            )
            let audio = try ContractMP4Oracle.read(url).audio
            let inventoryResult = try PublicSurfaceAdapters.invoke(.facadeNumberingInventory, url: url)
            if case .inventory(let inventory) = inventoryResult {
                evidence.check("inventory.track.total", inventory.track.total.resolvedValue == 12)
            } else { evidence.check("inventory.track.total", false) }
            let planResult = try PublicSurfaceAdapters.invoke(
                .facadePlanNormalization, url: url,
                input: .normalization(.replace(number: 5, total: 10), [.track])
            )
            guard case .plan(let plan) = planResult else {
                evidence.check("plan.returned", false); try evidence.finish(); return
            }
            evidence.check("plan.track", plan.trackNumber == 5 && plan.trackTotal == 10)
            evidence.check("plan.private.cleanup", plan.privateRemovals.contains("----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"))
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyNormalization, url: url, input: .applyPlan(plan))
            let after = try ContractMP4Oracle.read(url)
            let pair = try after.intPair("trkn")
            evidence.check("native.normalized", pair.first == 5 && pair.second == 10)
            evidence.check("native.private.removed", !after.has("----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"))
            let disk = try after.intPair("disk")
            evidence.check("native.disc.untouched", disk.first == 1 && disk.second == 2, "first=\(disk.first) second=\(disk.second) count=\(after.payloads("disk").first?.count ?? -1)")
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seed([
                .init(key: "trkn", value: .intPair(first: 3, second: 12)),
                .init(key: "©nam", value: .text("Before")),
            ], to: url)
            var evidence = ContractCase(
                scenario: "S-NORM-02",
                runtimeTest: "contractNormalizationPlan",
                adapter: "facade.applyNormalization",
                outcome: "unsupported_reject"
            )
            let planResult = try PublicSurfaceAdapters.invoke(
                .facadePlanNormalization, url: url,
                input: .normalization(.replace(number: 4, total: 10), [.track])
            )
            guard case .plan(let plan) = planResult else {
                evidence.check("plan.returned", false); try evidence.finish(); return
            }
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                MetadataPatch(fields: [.title: .text("External")])
            ))
            let bytes = try Data(contentsOf: url)
            do {
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyNormalization, url: url, input: .applyPlan(plan))
                evidence.check("stale.plan.reject", false)
            } catch {
                evidence.check("stale.plan.reject", true)
            }
            evidence.check("stale.plan.unchanged", try Data(contentsOf: url) == bytes)
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seed([
                .init(key: "trkn", value: .intPair(first: 4, second: 12)),
                .init(key: "disk", value: .intPair(first: 2, second: 3)),
            ], to: url)
            var evidence = ContractCase(
                scenario: "S-NORM-03",
                runtimeTest: "contractNormalizationPlan",
                adapter: "facade.planNormalization+facade.applyNormalization"
            )
            let audio = try ContractMP4Oracle.read(url).audio
            let planResult = try PublicSurfaceAdapters.invoke(
                .facadePlanNormalization, url: url,
                input: .normalization(.useNative, [.track, .disc])
            )
            guard case .plan(let plan) = planResult else {
                evidence.check("plan.returned", false); try evidence.finish(); return
            }
            evidence.check("plan.track", plan.trackNumber == 4 && plan.trackTotal == 12)
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyNormalization, url: url, input: .applyPlan(plan))
            let after = try ContractMP4Oracle.read(url)
            let track = try after.intPair("trkn")
            let disc = try after.intPair("disk")
            evidence.check("native.track", track.first == 4 && track.second == 12)
            evidence.check("native.disc", disc.first == 2 && disc.second == 3)
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        try ContractFixture.withCopy("mp3") { url in
            let frames = try ContractID3Seed.v24Frame("TRCK", ContractID3Seed.text("TRCK", "3", encoding: 3))
                + (try ContractID3Seed.v24Frame("TXXX", txxxPayload(description: "TRACKTOTAL", value: "12")))
                + (try ContractID3Seed.v24Frame("TIT2", ContractID3Seed.text("TIT2", "Seed", encoding: 3)))
            try ContractID3Seed.seedMP3(url, tag: try ContractID3Seed.tag(frames, version: 4))
            var evidence = ContractCase(
                scenario: "S-NORM-04",
                runtimeTest: "contractNormalizationPlan",
                adapter: "facade.planNormalization+facade.applyNormalization"
            )
            let audio = try ContractID3Oracle.read(url).audio
            let planResult = try PublicSurfaceAdapters.invoke(
                .facadePlanNormalization, url: url,
                input: .normalization(.useLegacy, [.track])
            )
            guard case .plan(let plan) = planResult else {
                evidence.check("plan.returned", false); try evidence.finish(); return
            }
            evidence.check("plan.legacy.total", plan.trackNumber == 3 && plan.trackTotal == 12)
            _ = try PublicSurfaceAdapters.invoke(.facadeApplyNormalization, url: url, input: .applyPlan(plan))
            let after = try ContractID3Oracle.read(url)
            evidence.check("native.track", after.frame("TRCK")?.text == "3/12")
            let txxxDescriptions = after.frames("TXXX").compactMap { frame -> String? in
                guard let parsed = try? ContractAssertions.id3UserText(frame) else { return nil }
                return parsed.description
            }
            evidence.check("native.alias.removed", !txxxDescriptions.contains("TRACKTOTAL"))
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }
    }
}

extension ContractNativeContainerTests {
    /// Xiph/Ogg, Opus, APE and WavPack native text families. These reuse the
    /// existing bounded native readers, verify the copied seed before the
    /// public call, and compare every untouched comment/item plus audio.
    @Test func contractNativeTextOtherFamilies() throws {
        for (scenario, ext, name) in [("S-OGG-01", "ogg", "testAudioFile"), ("S-OPUS-01", "opus", "synthetic")] {
            try ContractFixture.withCopy(ext, name: name) { url in
                var evidence = ContractCase(
                    scenario: scenario,
                    runtimeTest: "contractNativeTextOtherFamilies",
                    adapter: "facade.applyPatch"
                )
                let before = try IndependentOggProbe.read(url)
                evidence.check("seed.comments", !before.comments.isEmpty)
                evidence.check("seed.audio", !before.audio.isEmpty)
                let untouched = before.comments.filter { $0.key != "TITLE" }
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                    MetadataPatch(fields: [.title: .text("Native Text Title")])
                ))
                let after = try IndependentOggProbe.read(url)
                evidence.check("native.title", after.comments["TITLE"] == ["Native Text Title"])
                evidence.check("untouched.comments", after.comments.filter { $0.key != "TITLE" } == untouched)
                evidence.check("audio.unchanged", after.audio == before.audio)
                try evidence.finish()
            }
        }

        for (scenario, ext, name) in [("S-APE-01", "ape", "hardening"), ("S-WV-01", "wv", "testAudioFile")] {
            try ContractFixture.withCopy(ext, name: name) { url in
                var evidence = ContractCase(
                    scenario: scenario,
                    runtimeTest: "contractNativeTextOtherFamilies",
                    adapter: "facade.applyPatch"
                )
                var state = try HardeningFixture.apeState(Data(contentsOf: url))
                if state.items["TITLE"] == nil || state.items["CONTRACT"] == nil {
                    var items = state.items
                    items["TITLE"] = .init(flags: 0, value: Data("Seed".utf8))
                    items["CONTRACT"] = .init(flags: 0, value: Data(" keep ".utf8))
                    try HardeningFixture.writeAPE(audio: state.audio, items: items, to: url)
                    state = try HardeningFixture.apeState(Data(contentsOf: url))
                }
                evidence.check("seed.items", state.items["TITLE"] != nil && state.items["CONTRACT"] != nil)
                evidence.check("seed.audio", !state.audio.isEmpty)
                let untouched = state.items.filter { $0.key != "TITLE" }
                _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
                    MetadataPatch(fields: [.title: .text("Native Text Title")])
                ))
                let after = try HardeningFixture.apeState(Data(contentsOf: url))
                evidence.check("native.title", after.items["TITLE"]?.value == Data("Native Text Title".utf8))
                evidence.check("untouched.items", after.items.filter { $0.key != "TITLE" } == untouched)
                evidence.check("audio.unchanged", after.audio == state.audio)
                try evidence.finish()
            }
        }
    }
}
