import Foundation
import Darwin
import TagLibAudioMetadata
import CTagLibBridge

private let packageM4A = "testAudioFile"
private let packageMP3 = "testAudioFile"

private func probeExportedNumeric() throws {
    try ProbeFixture.withCopy(packageM4A, "m4a") { url in
        try ProbeMP4.seed(to: url)
        try requireRejection("exported-numeric", url) {
            try TagLibMetadataExtractor.writeTrackNumber(70_000, totalTracks: 0, padWidth: 0, to: url)
        }
    }
}

private func probeKeyNormalization() throws {
    try ProbeFixture.withCopy(packageM4A, "m4a") { url in
        try ProbeMP4.seed(to: url)
        try TagLibMetadataExtractor.writeStructuredMetadata(
            ["mp4Atoms": [[
                "key": " trkn ", "type": "intPair", "first": 5, "second": 12,
            ] as NSDictionary] as NSArray],
            to: url
        )
        do {
            let evidence = try ProbeMP4.read(url)
            let pair = try evidence.intPair("trkn")
            try require(pair.0 == 5 && pair.1 == 12, "key-normalization")
        } catch let error as ProbeError {
            print("ACTIVATION key-normalization: canonical atom was not written after trimmed-key validation: \(error)")
            throw error
        }
    }
}

private func probeNumericTruncation() throws {
    try ProbeFixture.withCopy(packageM4A, "m4a") { url in
        try ProbeMP4.seed(to: url)
        try requireRejection("numeric-truncation", url) {
            try TagLibMetadataExtractor.writeStructuredMetadata(
                ["mp4Atoms": [[
                    "key": "trkn", "type": "intPair", "first": 65_536, "second": 0,
                ] as NSDictionary] as NSArray],
                to: url
            )
        }
    }
}

private func probeFormatterNilDelete() throws {
    try ProbeFixture.withCopy(packageM4A, "m4a") { url in
        try ProbeMP4.seed(intPairs: [("trkn", 3, 12)], to: url)
        try requireRejection("formatter-nil", url) {
            try TagLibMetadataExtractor.writeTrackNumber(3, totalTracks: 12, padWidth: 65, to: url)
        }
        let evidence = try ProbeMP4.read(url)
        try require(try evidence.intPair("trkn").0 == 3, "formatter-nil-preservation")
    }
}

private func probeRetentionFilter() throws {
    try ProbeFixture.withCopy(packageM4A, "flac") { url in
        try ProbeFLAC.seed(comments: [
            ("TITLE", "Seed"),
            ("TRACKERNAME", "Keep Tracker"),
            ("CONTRACT_UNKNOWN", "keep"),
        ], to: url)
        let metadata = try TagLibMetadataExtractor.extractMetadata(from: url)
        metadata.title = "Retention Title"
        try TagLibMetadataExtractor.writeMetadata(metadata, to: url)
        let evidence = try ProbeFLAC.read(url)
        try require(evidence.values("TRACKERNAME") == ["Keep Tracker"], "retention-filter-unmodeled")
        try require(evidence.values("CONTRACT_UNKNOWN") == ["keep"], "retention-filter-unknown")
    }
}

private func probeLegacyV4() throws {
    try ProbeFixture.withCopy(packageMP3, "mp3") { url in
        try ProbeID3.seedMP3(url, frames: ProbeID3.frame("TIT2", "Seed"))
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.title: .text("Version Edit")]),
            to: url
        )
        let evidence = try ProbeID3.read(url)
        try require(evidence.version == 3, "legacy-v4")
    }
}

private func probeStaleFreeform() throws {
    try ProbeFixture.withCopy(packageM4A, "m4a") { url in
        try ProbeMP4.seed(freeforms: [
            ("MUSICBRAINZ_ALBUMTYPE", "StaleAlias"),
            ("MusicBrainz Album Type", "OldCanonical"),
            ("CONTRACT_UNRELATED", "Keep"),
        ], to: url)
        let metadata = try TagLibMetadataExtractor.extractMetadata(from: url)
        metadata.releaseType = "Canonical"
        try TagLibMetadataExtractor.writeMetadata(metadata, to: url)
        let evidence = try ProbeMP4.read(url)
        try require(try evidence.text("----:com.apple.iTunes:MusicBrainz Album Type") == "Canonical",
                    "stale-freeform-canonical")
        try require(!evidence.has("----:com.apple.iTunes:MUSICBRAINZ_ALBUMTYPE"),
                    "stale-freeform-removal")
        try require(try evidence.text("----:com.apple.iTunes:CONTRACT_UNRELATED") == "Keep",
                    "stale-freeform-unrelated")
    }
}

private func probeNumberCoercion() throws {
    try ProbeFixture.withCopy(packageM4A, "m4a") { url in
        try ProbeMP4.seed(intPairs: [("trkn", 3, 12)], to: url)
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(numberText: .init(trackNumberText: "5/0")),
            to: url
        )
        let evidence = try ProbeMP4.read(url)
        let pair = try evidence.intPair("trkn")
        if pair.0 != 5 || pair.1 != 0 {
            print("ACTIVATION number-coercion: explicit zero total was recovered as \(pair.1)")
            throw ProbeError.cleanFailure("explicit zero total recovered")
        }
        try requireRejection("number-coercion-invalid", url) {
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(numberText: .init(trackNumberText: "garbage")),
                to: url
            )
        }
    }
}

private func probeAdvertisedRoute() throws {
    let managerWritable = TagLibMetadataManager.isWritableExtension("mka")
    let bridgeWritable = TagLibMetadataExtractor.isWritableFormat("mka")
    let declared = TagLibMetadataManager.capability(forExtension: "mka")
    if managerWritable || bridgeWritable || declared?.isWritable == true {
        print("ACTIVATION advertised-route: unreachable Matroska route was advertised")
        throw ProbeError.cleanFailure("unreachable route advertised")
    }
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("calibration-\(UUID().uuidString).mka")
    try Data([0x00]).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    try requireRejection("advertised-route-write", url) {
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.title: .text("Unreachable")]),
            to: url
        )
    }
}

private func probeAdapterInvocation() throws {
    try ProbeFixture.withCopy(packageM4A, "m4a") { url in
        try ProbeMP4.seed(to: url)
        _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
            MetadataPatch(fields: [.title: .text("Adapter Title")])
        ))
        do {
            let evidence = try ProbeMP4.read(url)
            try require(try evidence.text("©nam") == "Adapter Title", "adapter-invocation")
        } catch let error as ProbeError {
            print("ACTIVATION adapter-invocation: the named public call did not reach the native owner: \(error)")
            throw error
        }
    }
}

private func probePreservationAssertion() throws {
    try ProbeFixture.withCopy(packageM4A, "m4a") { url in
        try ProbeMP4.seed(freeforms: [("CONTRACT_UNKNOWN", "keep")], to: url)
        let audio = try ProbeMP4.read(url).audio
        _ = try PublicSurfaceAdapters.invoke(.facadeApplyPatch, url: url, input: .patch(
            MetadataPatch(fields: [.title: .text("Assertion Title")])
        ))
        let checks = try PreservationProbe.checks(for: url, audioBefore: audio)
        if checks.count != 3 || !checks.contains("unknown-owner") {
            print("ACTIVATION preservation-assertion: \(checks)")
            throw ProbeError.cleanFailure("preservation assertion was not executed")
        }
    }
}

private func probeOracleCorruption() throws {
    try ProbeFixture.withCopy(packageM4A, "m4a") { url in
        try ProbeMP4.seed(binaries: [("©nam", Data([0xFF, 0xFE]))], to: url)
        let evidence = try ProbeMP4.read(url)
        do {
            _ = try evidence.text("©nam")
            print("ACTIVATION oracle-corruption: corrupted UTF-8 text was accepted")
            throw ProbeError.cleanFailure("oracle accepted corrupted text evidence")
        } catch let error as ProbeError {
            if case .cleanFailure = error { throw error }
            // A malformed-evidence rejection is the clean oracle behavior.
        }
    }
}

let probes: [ String: () throws -> Void ] = [
    "exported-numeric": probeExportedNumeric,
    "key-normalization": probeKeyNormalization,
    "numeric-truncation": probeNumericTruncation,
    "formatter-nil": probeFormatterNilDelete,
    "retention-filter": probeRetentionFilter,
    "legacy-v4": probeLegacyV4,
    "stale-freeform": probeStaleFreeform,
    "number-coercion": probeNumberCoercion,
    "advertised-route": probeAdvertisedRoute,
    "adapter-invocation": probeAdapterInvocation,
    "preservation-assertion": probePreservationAssertion,
    "oracle-corruption": probeOracleCorruption,
]

let command = CommandLine.arguments.dropFirst().first ?? "control"
do {
    if command == "control" {
        for name in probes.keys.sorted() {
            try probes[name]!()
        }
        print("CLEAN OK")
    } else if let probe = probes[command] {
        try probe()
        print("CLEAN \(command)")
    } else {
        print("INCONCLUSIVE unknown probe command \(command)")
        exit(2)
    }
    exit(0)
} catch let error as ProbeError {
    print("FAIL \(command): \(error)")
    exit(1)
} catch {
    print("INCONCLUSIVE \(command): \(error)")
    exit(2)
}
