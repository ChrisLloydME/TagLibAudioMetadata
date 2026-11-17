import Foundation
import Testing
@testable import TagLibAudioMetadata

/// Narrow pre-release audit regressions. Each test exercises a package-owned
/// public contract on a fresh fixture and compares native owners with the
/// independent test-only probes that live in this target.
struct PreReleaseAuditTests {
    private func copy(_ ext: String) throws -> URL {
        let source = try #require(
            Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext)
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    private func mp4Pair(_ url: URL, key: String = "trkn") throws -> [Int] {
        let probe = try IndependentMP4Probe.read(url)
        guard let bytes = probe.values[key]?.first else { return [] }
        try #require(bytes.count == 6 || bytes.count == 8)
        return [Int(bytes[2]) << 8 | Int(bytes[3]), Int(bytes[4]) << 8 | Int(bytes[5])]
    }

    private func seedPair(_ url: URL, track: Int = 3, total: Int = 12) throws {
        _ = try TagLibMetadataManager.applyMetadataPatch(
            .init(fields: [.track: .integer(track), .trackTotal: .integer(total)]),
            to: url
        )
    }

    // MARK: - Explicit zero in the formatted-number convenience API

    /// A supplied pair total of zero is authoritative. This is the same
    /// semantics the `MetadataPatch.numberText` path already implements and
    /// the ID3 form of `writeTrackNumberText` already follows.
    @Test(arguments: ["m4a", "flac", "ogg", "mp3"])
    func convenienceNumberTextExplicitZeroIsAuthoritative(_ ext: String) throws {
        let url = try copy(ext)
        defer { try? FileManager.default.removeItem(at: url) }
        try seedPair(url)
        _ = try TagLibMetadataManager.writeTrackNumberText("5/0", discNumberText: nil, to: url)
        switch ext {
        case "m4a":
            #expect(try mp4Pair(url) == [5, 0])
        case "flac":
            let probe = try IndependentFLACProbe.read(url)
            #expect(probe.comments["TRACKNUMBER"] == ["5"])
            #expect(probe.comments["TRACKTOTAL"] == nil)
        case "ogg":
            let probe = try IndependentOggProbe.read(url)
            #expect(probe.comments["TRACKNUMBER"] == ["5"])
            #expect(probe.comments["TRACKTOTAL"] == nil)
        case "mp3":
            #expect(try IndependentID3Probe.read(url).texts["TRCK"] == ["5/0"])
        default:
            Issue.record("Unexpected fixture \(ext)")
        }
    }

    /// Control: the ordinary number-text patch clears the total and retires
    /// private provenance on the same fixture set. This isolates the defect to
    /// the convenience entry point rather than the number-pair grammar.
    @Test(arguments: ["m4a", "flac", "ogg"])
    func metadataPatchNumberTextExplicitZeroIsAuthoritative(_ ext: String) throws {
        let url = try copy(ext)
        defer { try? FileManager.default.removeItem(at: url) }
        try seedPair(url)
        let key = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        if ext == "m4a" {
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                .init(mp4Atoms: [.init(key: key, type: "stringList", values: ["3/12"])]), to: url)
        }
        _ = try TagLibMetadataManager.applyMetadataPatch(
            .init(numberText: .init(trackNumberText: "5/0")), to: url)
        switch ext {
        case "m4a":
            #expect(try mp4Pair(url) == [5, 0])
            #expect(try IndependentMP4Probe.read(url).values[key] == nil)
        case "flac":
            let probe = try IndependentFLACProbe.read(url)
            #expect(probe.comments["TRACKNUMBER"] == ["5"])
            #expect(probe.comments["TRACKTOTAL"] == nil)
        case "ogg":
            let probe = try IndependentOggProbe.read(url)
            #expect(probe.comments["TRACKNUMBER"] == ["5"])
            #expect(probe.comments["TRACKTOTAL"] == nil)
        default:
            Issue.record("Unexpected fixture \(ext)")
        }
    }

    /// The same explicit-zero rule applies to the disc component. The
    /// convenience signature writes the track pair as well, so supply a
    /// consistent explicit track pair and ask for the disc total to clear.
    @Test(arguments: ["m4a", "flac", "ogg"])
    func convenienceDiscExplicitZeroIsAuthoritative(_ ext: String) throws {
        let url = try copy(ext)
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try TagLibMetadataManager.applyMetadataPatch(
            .init(fields: [.track: .integer(3), .trackTotal: .integer(12),
                           .disc: .integer(1), .discTotal: .integer(2)]),
            to: url
        )
        _ = try TagLibMetadataManager.writeTrackNumberText(
            "5/12", discNumberText: "1/0", to: url)
        switch ext {
        case "m4a":
            #expect(try mp4Pair(url) == [5, 12])
            #expect(try mp4Pair(url, key: "disk") == [1, 0])
        case "flac":
            let probe = try IndependentFLACProbe.read(url)
            #expect(probe.comments["DISCNUMBER"] == ["1"])
            #expect(probe.comments["DISCTOTAL"] == nil)
        case "ogg":
            let probe = try IndependentOggProbe.read(url)
            #expect(probe.comments["DISCNUMBER"] == ["1"])
            #expect(probe.comments["DISCTOTAL"] == nil)
        default:
            Issue.record("Unexpected fixture \(ext)")
        }
    }

    // MARK: - Convenience API provenance retirement

    /// The amended "normal number edit" policy retires recognized private
    /// provenance for the edited group on the same transaction. The typed,
    /// Basic and `MetadataPatch.numberText` entry points do; this convenience
    /// entry point currently does not.
    @Test func convenienceNumberTextRetiresEditedGroupProvenance() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let trackKey = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        let tagKey = "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"
        let discKey = "----:com.apple.iTunes:AUDIOMATOR_DISCNUMBER_TEXT"
        let foreignKey = "----:org.example:AUDIOMATOR_TRACKNUMBER_TEXT"
        let unrelatedKey = "----:com.apple.iTunes:UNRELATED"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 0),
            .init(key: "disk", type: "intPair", first: 1, second: 2),
            .init(key: trackKey, type: "stringList", values: ["03/12"]),
            .init(key: tagKey, type: "stringList", values: ["03/12"]),
            .init(key: discKey, type: "stringList", values: ["01/02"]),
            .init(key: foreignKey, type: "stringList", values: ["77/77"]),
            .init(key: unrelatedKey, type: "stringList", values: ["keep"]),
        ]), to: url)
        let before = try IndependentMP4Probe.read(url)
        _ = try TagLibMetadataManager.writeTrackNumberText("5/12", discNumberText: nil, to: url)
        let after = try IndependentMP4Probe.read(url)
        #expect(try mp4Pair(url) == [5, 12])
        #expect(after.values[trackKey] == nil)
        #expect(after.values[tagKey] == nil)
        #expect(after.values[discKey] == ["01/02"].map { Data($0.utf8) })
        #expect(after.values[foreignKey] == ["77/77"].map { Data($0.utf8) })
        #expect(after.values[unrelatedKey] == ["keep"].map { Data($0.utf8) })
        #expect(after.audio == before.audio)
    }

    // MARK: - Opaque/malformed missing siblings

    /// A private formatting atom that contains both a parseable pair and an
    /// unparseable value is not unambiguous evidence for the missing sibling.
    /// Recovery must reject and leave the original bytes untouched rather than
    /// choose the parseable total and retire the opaque evidence.
    @Test(arguments: [["03/12", "garbage"], ["03/12", "A1/13"]])
    func partialMalformedPrivateTextMustNotSupplyMissingSibling(_ values: [String]) throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let key = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 0),
            .init(key: key, type: "stringList", values: values),
        ]), to: url)
        let before = try Data(contentsOf: url)
        #expect(throws: (any Error).self) {
            _ = try TagLibMetadataManager.applyMetadataPatch(
                .init(fields: [.track: .integer(5)]), to: url)
        }
        #expect(try Data(contentsOf: url) == before)
    }

    /// Control: a single strict private pair is unambiguous and is recovered
    /// into the native pair for an explicitly edited number.
    @Test func strictPrivateTextStillRecoversMissingSibling() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let key = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 0),
            .init(key: key, type: "stringList", values: ["03/12"]),
        ]), to: url)
        _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(5)]), to: url)
        #expect(try mp4Pair(url) == [5, 12])
        #expect(try IndependentMP4Probe.read(url).values[key] == nil)
    }

    /// Native MP4 zero components are absence sentinels. A recoverable
    /// counterpart must still be used for an edited group, and stale private
    /// evidence for the counterpart must be retired.
    @Test func zeroValuedNativeComponentUsesCanonicalOrRecoveredCounterpart() throws {
        do {
            let url = try copy("m4a")
            defer { try? FileManager.default.removeItem(at: url) }
            let key = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "trkn", type: "intPair", first: 0, second: 12),
                .init(key: key, type: "stringList", values: ["03/12"]),
            ]), to: url)
            _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(5)]), to: url)
            #expect(try mp4Pair(url) == [5, 12])
            #expect(try IndependentMP4Probe.read(url).values[key] == nil)
        }
        do {
            let url = try copy("m4a")
            defer { try? FileManager.default.removeItem(at: url) }
            let key = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "trkn", type: "intPair", first: 3, second: 0),
                .init(key: key, type: "stringList", values: ["03/12"]),
            ]), to: url)
            _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.trackTotal: .integer(15)]), to: url)
            #expect(try mp4Pair(url) == [3, 15])
            #expect(try IndependentMP4Probe.read(url).values[key] == nil)
        }
    }

    // MARK: - No migration on unrelated writes

    /// A title-only edit must not create a native pair or change provenance.
    /// This assertion deliberately checks atom absence, not a zero-pair
    /// projection.
    @Test func titleOnlyWriteDoesNotCreateOrMigrateNumberPair() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let key = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", remove: true),
            .init(key: key, type: "stringList", values: ["03/12"]),
            .init(key: "----:org.example:AUDIOMATOR_TRACKNUMBER_TEXT", type: "stringList", values: ["77/77"]),
        ]), to: url)
        let before = try IndependentMP4Probe.read(url)
        _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("Only the title")]), to: url)
        let after = try IndependentMP4Probe.read(url)
        #expect(after.values["trkn"] == nil)
        #expect(after.values[key] == ["03/12"].map { Data($0.utf8) })
        #expect(after.values["----:org.example:AUDIOMATOR_TRACKNUMBER_TEXT"] == ["77/77"].map { Data($0.utf8) })
        #expect(after.values["©nam"] == ["Only the title"].map { Data($0.utf8) })
        #expect(after.audio == before.audio)
    }

    // MARK: - Read stability

    @Test func readsDoNotMutateBytesOrVersion() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let key = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 12),
            .init(key: key, type: "stringList", values: ["03/12"]),
        ]), to: url)
        let bytes = try Data(contentsOf: url)
        let version = try TagLibMetadataManager.fileVersion(at: url)
        for _ in 0..<3 {
            _ = try TagLibMetadataManager.readBasicSnapshot(from: url)
            _ = try TagLibMetadataManager.readSnapshot(from: url)
            _ = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
            _ = try TagLibMetadataManager.numberingInventory(at: url)
        }
        #expect(try Data(contentsOf: url) == bytes)
        #expect(try TagLibMetadataManager.fileVersion(at: url) == version)
    }

    // MARK: - Full explicit replacement

    @Test func fullExplicitReplacementRetiresOnlyEditedGroup() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let trackKey = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        let tagKey = "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"
        let discKey = "----:com.apple.iTunes:AUDIOMATOR_DISCNUMBER_TEXT"
        let foreignKey = "----:org.example:AUDIOMATOR_TRACKNUMBER_TEXT"
        let unrelatedKey = "----:com.apple.iTunes:UNRELATED"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 0),
            .init(key: "disk", type: "intPair", first: 1, second: 2),
            .init(key: trackKey, type: "stringList", values: ["03/12"]),
            .init(key: tagKey, type: "stringList", values: ["04/14"]),
            .init(key: discKey, type: "stringList", values: ["01/02"]),
            .init(key: foreignKey, type: "stringList", values: ["77/77"]),
            .init(key: unrelatedKey, type: "stringList", values: ["keep"]),
        ]), to: url)
        let before = try IndependentMP4Probe.read(url)
        _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [
            .track: .integer(5), .trackTotal: .integer(16), .title: .text("Full replacement"),
        ]), to: url)
        let after = try IndependentMP4Probe.read(url)
        #expect(try mp4Pair(url) == [5, 16])
        #expect(try mp4Pair(url, key: "disk") == [1, 2])
        #expect(after.values[trackKey] == nil)
        #expect(after.values[tagKey] == nil)
        #expect(after.values[discKey] == ["01/02"].map { Data($0.utf8) })
        #expect(after.values[foreignKey] == ["77/77"].map { Data($0.utf8) })
        #expect(after.values[unrelatedKey] == ["keep"].map { Data($0.utf8) })
        #expect(after.audio == before.audio)
    }
}
