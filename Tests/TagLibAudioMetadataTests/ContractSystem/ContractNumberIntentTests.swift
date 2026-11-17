import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

/// Contract scenarios for number-text presence intent, selected-group
/// retirement, opaque-evidence rejection and ID3 explicit-zero follow-up.
struct ContractNumberIntentTests {
    private static func mp4Pair(_ first: Int, _ second: Int) -> Data {
        Data([0, 0])
            + ContractFixture.number(UInt64(first), bytes: 2)
            + ContractFixture.number(UInt64(second), bytes: 2)
            + Data([0, 0])
    }

    private static let privateTrack = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
    private static let privateTag = "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"
    private static let foreignTrack = "----:org.example:AUDIOMATOR_TRACKNUMBER_TEXT"

    private static func seedPrivate(_ url: URL, opaque: Bool = false) throws {
        try ContractMP4Seed.seed([
            .init(key: "trkn", value: .intPair(first: 3, second: opaque ? 0 : 12)),
            .init(key: privateTrack, value: opaque ? .textList(["03/12", "garbage"])
                : .text("03/12")),
            .init(key: privateTag, value: opaque ? .text("garbage") : .text("03/12")),
            .init(key: foreignTrack, value: .text("77/77")),
        ], to: url)
    }

    private static func seedPayloads(_ url: URL, _ evidence: inout ContractCase,
                                      opaque: Bool = false) throws -> Data {
        try ContractAssertions.verifyMP4Seed(url, expectedItems: [
            "trkn": mp4Pair(3, opaque ? 0 : 12),
            privateTrack: opaque ? Data("03/12".utf8) : Data("03/12".utf8),
            privateTag: opaque ? Data("garbage".utf8) : Data("03/12".utf8),
            foreignTrack: Data("77/77".utf8),
        ], &evidence)
    }

    @Test func contractNumberIntentAndRetirement() throws {
        try ContractFixture.withCopy("m4a") { url in
            try Self.seedPrivate(url)
            var evidence = ContractCase(
                scenario: "S-MP4-INTENT-01",
                runtimeTest: "contractNumberIntentAndRetirement",
                adapter: "facade.writeTrackNumberText"
            )
            let audio = try Self.seedPayloads(url, &evidence)
            let result = try PublicSurfaceAdapters.invoke(
                .facadeWriteTrackNumberText, url: url,
                input: .trackText(track: "5/0", disc: nil, verify: true)
            )
            if case .write = result { evidence.check("write.returned", true) } else {
                evidence.check("write.returned", false)
            }
            let after = try ContractMP4Oracle.read(url)
            let pair = try after.intPair("trkn")
            evidence.check("native.trkn.zero", pair.first == 5 && pair.second == 0)
            evidence.check("private.retired", !after.has(Self.privateTrack) && !after.has(Self.privateTag))
            evidence.check("foreign.preserved", after.payloads(Self.foreignTrack) == [Data("77/77".utf8)])
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            try Self.seedPrivate(url)
            var evidence = ContractCase(
                scenario: "S-MP4-INTENT-02",
                runtimeTest: "contractNumberIntentAndRetirement",
                adapter: "bridge.writeTrackNumberText"
            )
            let audio = try Self.seedPayloads(url, &evidence)
            let result = try PublicSurfaceAdapters.invoke(
                .bridgeWriteTrackNumberText, url: url,
                input: .trackText(track: "5/0", disc: nil, verify: false)
            )
            if case .none = result { evidence.check("write.returned", true) } else {
                evidence.check("write.returned", false)
            }
            let after = try ContractMP4Oracle.read(url)
            let pair = try after.intPair("trkn")
            evidence.check("native.trkn.zero", pair.first == 5 && pair.second == 0)
            evidence.check("private.preserved", after.has(Self.privateTrack) && after.has(Self.privateTag))
            evidence.check("foreign.preserved", after.payloads(Self.foreignTrack) == [Data("77/77".utf8)])
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            try Self.seedPrivate(url, opaque: true)
            var evidence = ContractCase(
                scenario: "S-MP4-INTENT-03",
                runtimeTest: "contractNumberIntentAndRetirement",
                adapter: "facade.applyPatch"
            )
            _ = try Self.seedPayloads(url, &evidence, opaque: true)
            try ContractAssertions.expectRejection(&evidence, name: "numberText", file: url) {
                _ = try PublicSurfaceAdapters.invoke(
                    .facadeApplyPatch, url: url,
                    input: .patch(MetadataPatch(numberText: .init(trackNumberText: "5")))
                )
            }
            try evidence.finish()
        }

        try ContractFixture.withCopy("m4a") { url in
            try Self.seedPrivate(url, opaque: true)
            var evidence = ContractCase(
                scenario: "S-MP4-INTENT-04",
                runtimeTest: "contractNumberIntentAndRetirement",
                adapter: "facade.writeTrackNumberText"
            )
            let audio = try Self.seedPayloads(url, &evidence, opaque: true)
            let result = try PublicSurfaceAdapters.invoke(
                .facadeWriteTrackNumberText, url: url,
                input: .trackText(track: "5/16", disc: nil, verify: true)
            )
            if case .write = result { evidence.check("write.returned", true) } else {
                evidence.check("write.returned", false)
            }
            let after = try ContractMP4Oracle.read(url)
            let pair = try after.intPair("trkn")
            evidence.check("native.trkn", pair.first == 5 && pair.second == 16)
            evidence.check("private.retired", !after.has(Self.privateTrack) && !after.has(Self.privateTag))
            evidence.check("audio.unchanged", after.audio == audio)
            try evidence.finish()
        }
    }

    @Test func contractID3NumberIntent() throws {
        for track in [true, false] {
            try ContractFixture.withCopy("mp3") { url in
                var evidence = ContractCase(
                    scenario: track ? "S-ID3-INTENT-01" : "S-ID3-INTENT-02",
                    runtimeTest: "contractID3NumberIntent",
                    adapter: "facade.applyPatch"
                )
                let audio = try ContractID3Oracle.read(url).audio
                let frame = track ? "TRCK" : "TPOS"
                let first = track ? "5/0" : "1/0"
                let firstResult = try PublicSurfaceAdapters.invoke(
                    .facadeApplyPatch, url: url,
                    input: .patch(MetadataPatch(numberText: .init(
                        trackNumberText: track ? first : nil,
                        discNumberText: track ? nil : first
                    )))
                )
                if case .write = firstResult { evidence.check("write.returned", true) } else {
                    evidence.check("write.returned", false)
                }
                let zero = try ContractID3Oracle.read(url)
                evidence.check("zero.text", zero.frame(frame)?.text == first)
                let inventory = try TagLibMetadataManager.numberingInventory(at: url)
                let group = track ? inventory.track : inventory.disc
                evidence.check("inventory.number", group.number.nativeValue == (track ? 5 : 1))
                evidence.check("inventory.total.absent", group.total.state == .absent)
                let followup = try PublicSurfaceAdapters.invoke(
                    .facadeApplyPatch, url: url,
                    input: .patch(MetadataPatch(fields: [
                        track ? .trackTotal : .discTotal: .integer(15),
                    ]))
                )
                if case .write = followup { evidence.check("followup.returned", true) } else {
                    evidence.check("followup.returned", false)
                }
                let edited = try ContractID3Oracle.read(url)
                evidence.check("followup.text", edited.frame(frame)?.text == (track ? "5/15" : "1/15"))
                evidence.check("audio.unchanged", edited.audio == audio)
                try evidence.finish()
            }
        }
    }
}
