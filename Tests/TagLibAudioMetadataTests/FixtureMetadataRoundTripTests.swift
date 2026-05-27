import XCTest
import TagLibAudioMetadata

final class FixtureMetadataRoundTripTests: XCTestCase {
    private let writableFixtures = ["mp3", "m4a", "flac", "aac", "ogg", "wav"]

    func testBasicMetadataWritesAndClearsAcrossFixtures() throws {
        for ext in writableFixtures {
            let url = try copyAudioFixture(ext)

            var metadata = BasicMetadata.empty
            metadata.title = "Roundtrip Title \(ext)"
            metadata.artist = "Roundtrip Artist"
            metadata.album = "Roundtrip Album"
            metadata.genre = "Roundtrip Genre"
            metadata.comment = "Roundtrip Comment"
            metadata.track = 1
            metadata.trackTotal = 10
            metadata.disc = 1
            metadata.discTotal = 2
            metadata.trackNumberText = "01/10"
            metadata.discNumberText = "01/02"
            metadata.isExplicit = true

            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .warn)

            var afterWrite = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(afterWrite.title, metadata.title, ext)
            XCTAssertEqual(afterWrite.artist, metadata.artist, ext)
            XCTAssertEqual(afterWrite.album, metadata.album, ext)
            XCTAssertEqual(afterWrite.genre, metadata.genre, ext)
            XCTAssertEqual(afterWrite.comment, metadata.comment, ext)
            XCTAssertEqual(afterWrite.track, 1, ext)
            XCTAssertEqual(afterWrite.trackTotal, 10, ext)
            XCTAssertEqual(afterWrite.disc, 1, ext)
            XCTAssertEqual(afterWrite.discTotal, 2, ext)
            XCTAssertEqual(afterWrite.isExplicit, true, ext)

            var cleared = BasicMetadata.empty
            cleared.trackNumberText = ""
            cleared.discNumberText = ""
            try TagLibMetadataManager.writeMetadataWithVerification(cleared, to: url, failurePolicy: .warn)

            afterWrite = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(afterWrite.title, "", ext)
            XCTAssertEqual(afterWrite.artist, "", ext)
            XCTAssertEqual(afterWrite.album, "", ext)
            XCTAssertEqual(afterWrite.genre, "", ext)
            XCTAssertEqual(afterWrite.comment, "", ext)
            XCTAssertEqual(afterWrite.track, 0, ext)
            XCTAssertEqual(afterWrite.trackTotal, 0, ext)
            XCTAssertEqual(afterWrite.disc, 0, ext)
            XCTAssertEqual(afterWrite.discTotal, 0, ext)
            XCTAssertEqual(afterWrite.isExplicit, false, ext)
        }
    }

    func testArtworkCanBeWrittenAndRemovedWhereSupported() throws {
        let artwork = try Data(contentsOf: artworkFixtureURL())

        for ext in ["mp3", "m4a", "flac", "ogg", "wav"] {
            let capability = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: ext))
            guard capability.canWriteArtwork else { continue }

            let url = try copyAudioFixture(ext)
            var metadata = BasicMetadata.empty
            metadata.title = "Artwork \(ext)"
            metadata.artworkData = artwork

            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .warn)
            XCTAssertNotNil(try TagLibMetadataManager.readMetadataResult(from: url).artworkData, ext)

            let removal = TagLibAudioMetadata()
            removal.removeArtwork = true
            try TagLibMetadataManager.writeTagMetadata(
                removal,
                to: url,
                verification: .init(
                    expectedTrackNumber: nil,
                    expectedTrackTotal: nil,
                    expectedTrackNumberText: nil,
                    expectedDiscNumber: nil,
                    expectedDiscTotal: nil,
                    expectedDiscNumberText: nil,
                    expectedExplicitContent: nil,
                    artworkExpectation: .absent,
                    customFieldKeys: []
                ),
                failurePolicy: .warn
            )
            XCTAssertNil(try TagLibMetadataManager.readMetadataResult(from: url).artworkData, ext)
        }
    }

    func testRawPropertyMapReplaceMergeAndMultiValueWrites() throws {
        for ext in ["flac", "ogg", "m4a"] {
            let url = try copyAudioFixture(ext)

            try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                ["TITLE": "Raw Title", "MOOD": "Focused", "CUSTOM_CASE": "Alpha"],
                to: url,
                mode: .replace,
                failurePolicy: .warn
            )

            var raw = try TagLibMetadataManager.rawMetadataResult(from: url)
            XCTAssertTrue(raw.containsProperty("TITLE", value: "Raw Title"), ext)
            XCTAssertTrue(raw.containsProperty("MOOD", value: "Focused"), ext)

            try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                ["MOOD": "", "CUSTOM_CASE": "Beta"],
                to: url,
                mode: .merge,
                failurePolicy: .warn
            )

            raw = try TagLibMetadataManager.rawMetadataResult(from: url)
            XCTAssertFalse(raw.containsProperty("MOOD"), ext)
            XCTAssertTrue(raw.containsProperty("CUSTOM_CASE", value: "Beta"), ext)

            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                ["ARTIST": ["One", "Two"]],
                to: url,
                failurePolicy: .warn
            )

            raw = try TagLibMetadataManager.rawMetadataResult(from: url)
            XCTAssertTrue(raw.properties.contains { $0.key.uppercased() == "ARTIST" && Set($0.values) == Set(["One", "Two"]) }, ext)
        }
    }

    func testStructuredMetadataWritesPropertiesAndContainerDataTogether() throws {
        let artwork = try Data(contentsOf: artworkFixtureURL())

        let mp3URL = try copyAudioFixture("mp3")
        let mp3Payload = StructuredMetadata(
            properties: [.init(key: "TITLE", values: ["Structured MP3"])],
            id3v2Frames: [.init(frameID: "TIT3", type: "text", value: "Subtitle Frame", values: ["Subtitle Frame"])],
            artwork: [.init(container: "id3v2", mimeType: "image/jpeg", data: artwork)],
            lyrics: [.init(text: "Structured lyrics")],
            comments: [.init(text: "Structured comment")]
        )
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            mp3Payload,
            to: mp3URL,
            includeProperties: true,
            failurePolicy: .warn
        )
        var structured = try TagLibMetadataManager.readStructuredMetadataResult(from: mp3URL)
        XCTAssertTrue(structured.properties.contains { $0.key.uppercased() == "TITLE" && $0.values.contains("Structured MP3") })
        XCTAssertTrue(structured.id3v2Frames.contains { $0.frameID == "TIT3" && $0.value.contains("Subtitle Frame") })
        XCTAssertFalse(structured.artwork.isEmpty)
        XCTAssertFalse(structured.lyrics.isEmpty)
        XCTAssertFalse(structured.comments.isEmpty)

        let m4aURL = try copyAudioFixture("m4a")
        let m4aPayload = StructuredMetadata(
            properties: [.init(key: "TITLE", values: ["Structured M4A"])],
            mp4Atoms: [.init(key: "----:com.apple.iTunes:TEST_STRUCTURED", type: "stringList", values: ["Atom Value"])]
        )
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            m4aPayload,
            to: m4aURL,
            includeProperties: true,
            failurePolicy: .warn
        )
        structured = try TagLibMetadataManager.readStructuredMetadataResult(from: m4aURL)
        XCTAssertTrue(structured.properties.contains { $0.key.uppercased() == "TITLE" && $0.values.contains("Structured M4A") })
        XCTAssertTrue(structured.mp4Atoms.contains { $0.key == "----:com.apple.iTunes:TEST_STRUCTURED" })
    }

    func testEraseAllMetadataReportsNoResidualCoreFields() throws {
        for ext in ["mp3", "m4a", "flac", "ogg", "wav"] {
            let url = try copyAudioFixture(ext)
            var metadata = BasicMetadata.empty
            metadata.title = "Erase Title"
            metadata.artist = "Erase Artist"
            metadata.album = "Erase Album"
            metadata.track = 3
            metadata.trackTotal = 9
            metadata.customFields = ["ERASE_CUSTOM": "present"]
            metadata.artworkData = try Data(contentsOf: artworkFixtureURL())

            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .warn)
            try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url, failurePolicy: .warn)

            let afterErase = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(afterErase.title, "", ext)
            XCTAssertEqual(afterErase.artist, "", ext)
            XCTAssertEqual(afterErase.album, "", ext)
            XCTAssertEqual(afterErase.track, 0, ext)
            XCTAssertEqual(afterErase.trackTotal, 0, ext)
            XCTAssertNil(afterErase.artworkData, ext)
            XCTAssertTrue(afterErase.customFields.isEmpty, ext)
        }
    }

    private func copyAudioFixture(_ ext: String) throws -> URL {
        let source = try XCTUnwrap(
            Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext)
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TagLibAudioMetadataTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("testAudioFile.\(ext)")
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    private func artworkFixtureURL() throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: "testCover", withExtension: "jpg", subdirectory: "Artwork")
                ?? Bundle.module.url(forResource: "testCover", withExtension: "jpg")
        )
    }
}

private extension RawMetadataDump {
    func containsProperty(_ key: String, value: String? = nil) -> Bool {
        let normalizedKey = key.uppercased()
        return properties.contains { entry in
            guard entry.key.uppercased() == normalizedKey else { return false }
            guard let value else { return true }
            return entry.values.contains(value) || entry.value == value
        }
    }
}
