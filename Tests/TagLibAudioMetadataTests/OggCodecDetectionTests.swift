import Foundation
import XCTest
@testable import TagLibAudioMetadata

final class OggCodecDetectionTests: XCTestCase {
    func testOpusWithOtherOggExtensionsUsesIdentificationPacket() throws {
        for ext in ["ogg", "oga", "spx"] {
            try assertMisleadingExtensionRoundTrip(
                sourceExtension: "opus", misleadingExtension: ext,
                expectedCodec: "Opus", identificationSignature: Data("OpusHead".utf8)
            )
        }
    }

    func testNonBOSPageCannotMasqueradeAsIdentificationHeader() throws {
        let url = try temporaryDirectory().appendingPathComponent("invalid.ogg")
        var bytes = try Data(contentsOf: fixtureURL("ogg"))
        bytes[5] = 0 // no BOS flag
        try bytes.write(to: url)
        XCTAssertThrowsError(try TagLibMetadataManager.readSnapshot(from: url))
        XCTAssertThrowsError(try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.title: .text("Must not commit")]), to: url
        ))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testVorbisWithOgaExtensionUsesVorbisHandlerAndPreservesUnrelatedValues() throws {
        try assertMisleadingExtensionRoundTrip(
            sourceExtension: "ogg",
            misleadingExtension: "oga",
            expectedCodec: "Vorbis",
            identificationSignature: Data([0x01]) + Data("vorbis".utf8)
        )
    }

    func testOggFLACWithOggExtensionUsesOggFLACHandlerAndPreservesUnrelatedValues() throws {
        try assertMisleadingExtensionRoundTrip(
            sourceExtension: "oga",
            misleadingExtension: "ogg",
            expectedCodec: "OGG FLAC",
            identificationSignature: Data([0x7f]) + Data("FLAC".utf8)
        )
    }

    private func assertMisleadingExtensionRoundTrip(
        sourceExtension: String,
        misleadingExtension: String,
        expectedCodec: String,
        identificationSignature: Data
    ) throws {
        let directory = try temporaryDirectory()
        let seededURL = directory.appendingPathComponent("seeded.\(sourceExtension)")
        try FileManager.default.copyItem(at: try fixtureURL(sourceExtension), to: seededURL)
        try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
            [
                "TITLE": ["Before"],
                "ARTIST": ["Unrelated artist"],
                "CUSTOM": ["Symphony; Live Version", "Second value"],
            ],
            to: seededURL,
            failurePolicy: .throw
        )

        let misleadingURL = directory.appendingPathComponent("misleading.\(misleadingExtension)")
        try FileManager.default.moveItem(at: seededURL, to: misleadingURL)
        XCTAssertTrue(try firstOggPacket(at: misleadingURL).starts(with: identificationSignature))

        let before = try TagLibMetadataManager.readSnapshot(from: misleadingURL)
        XCTAssertEqual(before.basic.format, expectedCodec)

        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.title: .text("After")]),
            to: misleadingURL
        )

        let after = try TagLibMetadataManager.readSnapshot(from: misleadingURL)
        XCTAssertEqual(after.basic.format, expectedCodec)
        XCTAssertEqual(after.basic.title, "After")
        XCTAssertEqual(values(for: "ARTIST", in: after.raw), ["Unrelated artist"])
        XCTAssertEqual(
            values(for: "CUSTOM", in: after.raw),
            ["Symphony; Live Version", "Second value"]
        )
    }

    private func firstOggPacket(at url: URL) throws -> Data {
        let bytes = try Data(contentsOf: url)
        guard bytes.count >= 27,
              bytes.prefix(4) == Data("OggS".utf8) else {
            throw OggTestError.invalidPage
        }
        let segmentCount = Int(bytes[26])
        guard bytes.count >= 27 + segmentCount else { throw OggTestError.invalidPage }
        let packetLength = bytes[27..<(27 + segmentCount)].reduce(0) { partial, lace in
            partial + Int(lace)
        }
        let packetStart = 27 + segmentCount
        guard bytes.count >= packetStart + packetLength else { throw OggTestError.invalidPage }
        return bytes[packetStart..<(packetStart + packetLength)]
    }

    private func values(for key: String, in raw: RawMetadataDump) -> [String] {
        raw.properties.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.values ?? []
    }

    private func fixtureURL(_ ext: String) throws -> URL {
        let name = ext == "opus" ? "synthetic" : "testAudioFile"
        return try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: name, withExtension: ext)
        )
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TagLibAudioMetadataOggDetection-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }
}

private enum OggTestError: Error {
    case invalidPage
}
