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

            let writeResult = try TagLibMetadataManager.writeMetadataWithVerification(
                metadata,
                to: url,
                failurePolicy: .warn
            )
            XCTAssertTrue(
                writeResult.warnings.allSatisfy { $0.contains("formatting was normalized") },
                "Unexpected verification warning for \(ext): \(writeResult.warnings)"
            )

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
            let clearResult = try TagLibMetadataManager.writeMetadataWithVerification(
                cleared,
                to: url,
                failurePolicy: .warn
            )
            XCTAssertTrue(
                clearResult.warnings.isEmpty,
                "Unexpected clear warning for \(ext): \(clearResult.warnings)"
            )

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

            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)
            XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: url).artworkData, artwork, ext)

            let removal = TagLibAudioMetadata()
            removal.removeArtwork = true
            _ = try TagLibMetadataManager.writeTagMetadata(
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
                failurePolicy: .throw
            )
            XCTAssertNil(try TagLibMetadataManager.readMetadataResult(from: url).artworkData, ext)
        }
    }

    func testRawPropertyMapReplaceMergeAndMultiValueWrites() throws {
        for ext in ["flac", "ogg", "m4a"] {
            let url = try copyAudioFixture(ext)

            try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                ["OLD_SENTINEL": "remove me"],
                to: url,
                mode: .replace,
                failurePolicy: .throw
            )

            try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                ["TITLE": "Raw Title", "MOOD": "Focused", "CUSTOM_CASE": "Alpha"],
                to: url,
                mode: .replace,
                failurePolicy: .throw
            )

            var raw = try TagLibMetadataManager.rawMetadataResult(from: url)
            XCTAssertFalse(raw.containsProperty("OLD_SENTINEL"), ext)
            XCTAssertTrue(raw.containsProperty("TITLE", value: "Raw Title"), ext)
            XCTAssertTrue(raw.containsProperty("MOOD", value: "Focused"), ext)

            try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                ["MOOD": "", "CUSTOM_CASE": "Beta"],
                to: url,
                mode: .merge,
                failurePolicy: .throw
            )

            raw = try TagLibMetadataManager.rawMetadataResult(from: url)
            XCTAssertFalse(raw.containsProperty("MOOD"), ext)
            XCTAssertTrue(raw.containsProperty("TITLE", value: "Raw Title"), ext)
            XCTAssertTrue(raw.containsProperty("CUSTOM_CASE", value: "Beta"), ext)

            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                ["ARTIST": ["One", "Two"]],
                to: url,
                failurePolicy: .throw
            )

            raw = try TagLibMetadataManager.rawMetadataResult(from: url)
            XCTAssertTrue(raw.properties.contains { $0.key.uppercased() == "ARTIST" && Set($0.values) == Set(["One", "Two"]) }, ext)
        }
    }

    func testRawMergePreservesUnmodifiedMultiValueProperties() throws {
        for ext in ["flac", "ogg"] {
            let url = try copyAudioFixture(ext)

            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                ["ARTIST": ["One", "Two"]],
                to: url,
                failurePolicy: .throw
            )
            try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                ["MOOD": "Focused"],
                to: url,
                mode: .merge,
                failurePolicy: .throw
            )

            let raw = try TagLibMetadataManager.rawMetadataResult(from: url)
            XCTAssertEqual(raw.values(for: "ARTIST"), ["One", "Two"], ext)
            XCTAssertEqual(raw.values(for: "MOOD"), ["Focused"], ext)
        }
    }

    func testStructuredWAVAdvisoriesDoNotFailVerifiedWrites() throws {
        let url = try copyAudioFixture("wav")
        let payload = StructuredMetadata(
            properties: [.init(key: "TITLE", values: ["Verified WAV"])]
        )

        let result = try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            payload,
            to: url,
            riffPolicy: .preserveInfo,
            includeProperties: true,
            failurePolicy: .throw
        )

        XCTAssertFalse(result.warnings.isEmpty, "WAV capability advisories should remain visible to callers.")
        XCTAssertTrue(
            try TagLibMetadataManager.rawMetadataResult(from: url).containsProperty("TITLE", value: "Verified WAV")
        )
    }

    func testVerificationFailurePolicyRollsBackOrCommitsAsRequested() throws {
        let rollbackURL = try copyAudioFixture("mp3")
        let rollbackBytes = try Data(contentsOf: rollbackURL)
        let metadata = TagLibAudioMetadata()
        metadata.title = "Written title"
        let mismatchedVerification = TagLibMetadataManager.MetadataWriteVerificationContext(
            expectedTrackNumber: nil,
            expectedTrackTotal: nil,
            expectedTrackNumberText: nil,
            expectedDiscNumber: nil,
            expectedDiscTotal: nil,
            expectedDiscNumberText: nil,
            expectedExplicitContent: nil,
            artworkExpectation: .unchanged,
            customFieldKeys: [],
            expectedTextFields: ["TITLE": "Different title"]
        )

        XCTAssertThrowsError(
            try TagLibMetadataManager.writeTagMetadata(
                metadata,
                to: rollbackURL,
                verification: mismatchedVerification,
                failurePolicy: .throw
            )
        ) { error in
            guard case TagLibManagerError.verificationFailed = error else {
                return XCTFail("Expected verificationFailed, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: rollbackURL), rollbackBytes)

        let warningURL = try copyAudioFixture("mp3")
        let result = try TagLibMetadataManager.writeTagMetadata(
            metadata,
            to: warningURL,
            verification: mismatchedVerification,
            failurePolicy: .warn
        )
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: warningURL).title, "Written title")
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
            failurePolicy: .throw
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
            failurePolicy: .throw
        )
        structured = try TagLibMetadataManager.readStructuredMetadataResult(from: m4aURL)
        XCTAssertTrue(structured.properties.contains { $0.key.uppercased() == "TITLE" && $0.values.contains("Structured M4A") })
        XCTAssertTrue(structured.mp4Atoms.contains { $0.key == "----:com.apple.iTunes:TEST_STRUCTURED" })
    }

    func testStructuredMP4BooleanRoundTripPreservesTrue() throws {
        let url = try copyAudioFixture("m4a")
        let payload = StructuredMetadata(
            mp4Atoms: [
                .init(key: "cpil", type: "bool", value: "true"),
            ]
        )

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            payload,
            to: url,
            failurePolicy: .throw
        )

        let structured = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
        let compilation = try XCTUnwrap(structured.mp4Atoms.first { $0.key == "cpil" })
        XCTAssertEqual(compilation.type, "bool")
        XCTAssertEqual(compilation.value, "1")
    }

    func testExtendedBasicFieldsRoundTripAcrossID3AndMP4() throws {
        for ext in ["mp3", "m4a"] {
            let url = try copyAudioFixture(ext)
            var metadata = BasicMetadata.empty
            metadata.releaseStatus = "Official"
            metadata.asin = "B000000001"
            metadata.originalAlbum = "Original Album"
            metadata.originalArtist = "Original Artist"
            metadata.discSubtitle = "Bonus Disc"
            metadata.work = "Example Work"
            metadata.conductor = "Example Conductor"
            metadata.producer = "Example Producer"
            metadata.movement = "Example Movement"
            metadata.movementNumber = 2
            metadata.movementCount = 4
            metadata.bpm = 120
            metadata.isCompilation = true
            metadata.replayGainTrack = "-3.50 dB"
            metadata.musicBrainzWorkID = "00000000-0000-0000-0000-000000000001"

            try TagLibMetadataManager.writeMetadataWithVerification(
                metadata,
                to: url,
                failurePolicy: .throw
            )

            let result = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(result.releaseStatus, metadata.releaseStatus, ext)
            XCTAssertEqual(result.asin, metadata.asin, ext)
            XCTAssertEqual(result.originalAlbum, metadata.originalAlbum, ext)
            XCTAssertEqual(result.originalArtist, metadata.originalArtist, ext)
            XCTAssertEqual(result.discSubtitle, metadata.discSubtitle, ext)
            XCTAssertEqual(result.work, metadata.work, ext)
            XCTAssertEqual(result.conductor, metadata.conductor, ext)
            XCTAssertEqual(result.producer, metadata.producer, ext)
            XCTAssertEqual(result.movement, metadata.movement, ext)
            XCTAssertEqual(result.movementNumber, metadata.movementNumber, ext)
            XCTAssertEqual(result.movementCount, metadata.movementCount, ext)
            XCTAssertEqual(result.bpm, metadata.bpm, ext)
            XCTAssertEqual(result.isCompilation, metadata.isCompilation, ext)
            XCTAssertEqual(result.replayGainTrack, metadata.replayGainTrack, ext)
            XCTAssertEqual(result.musicBrainzWorkID, metadata.musicBrainzWorkID, ext)
        }
    }

    func testOriginalReleaseDateDoesNotBecomeCurrentReleaseDate() throws {
        let url = try copyAudioFixture("mp3")
        var metadata = BasicMetadata.empty
        metadata.originalReleaseDate = "1984-01-24"

        try TagLibMetadataManager.writeMetadataWithVerification(
            metadata,
            to: url,
            failurePolicy: .throw
        )

        let result = try TagLibMetadataManager.readMetadataResult(from: url)
        XCTAssertEqual(result.releaseDate, "")
        XCTAssertEqual(result.originalReleaseDate, metadata.originalReleaseDate)
    }

    func testStructuredCollectionsCanRemoveTheirLastEntry() throws {
        let url = try copyAudioFixture("mp3")
        let artwork = try Data(contentsOf: artworkFixtureURL())
        let initial = StructuredMetadata(
            artwork: [.init(container: "id3v2", mimeType: "image/jpeg", data: artwork)],
            lyrics: [.init(text: "Temporary lyrics")],
            comments: [.init(text: "Temporary comment")]
        )

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            initial,
            to: url,
            failurePolicy: .throw
        )

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(),
            to: url,
            replacingCollections: [.artwork, .lyrics, .comments],
            failurePolicy: .throw
        )

        let result = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
        XCTAssertTrue(result.artwork.isEmpty)
        XCTAssertTrue(result.lyrics.isEmpty)
        XCTAssertTrue(result.comments.isEmpty)
    }

    func testStructuredArtworkRoundTripsMultipleEntriesAndCanBeCleared() throws {
        let firstArtwork = try Data(contentsOf: artworkFixtureURL())
        var secondArtwork = firstArtwork
        secondArtwork.append(0)

        for ext in ["mp3", "m4a"] {
            let url = try copyAudioFixture(ext)
            let container = ext == "mp3" ? "id3v2" : "mp4"
            let payload = StructuredMetadata(
                artwork: [
                    .init(container: container, mimeType: "image/jpeg", description: "Front", data: firstArtwork),
                    .init(container: container, mimeType: "image/jpeg", description: "Alternate", data: secondArtwork),
                ]
            )

            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                payload,
                to: url,
                failurePolicy: .throw
            )

            var result = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
            XCTAssertEqual(result.artwork.count, 2, ext)
            XCTAssertEqual(Set(result.artwork.map(\.data)), Set([firstArtwork, secondArtwork]), ext)

            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(),
                to: url,
                replacingCollections: [.artwork],
                failurePolicy: .throw
            )

            result = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
            XCTAssertTrue(result.artwork.isEmpty, ext)
        }
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

            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)
            try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url, failurePolicy: .throw)

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

    func testVerificationFailurePreservesOriginalFile() throws {
        let url = try copyAudioFixture("wav")
        let originalBytes = try Data(contentsOf: url)
        let payload = StructuredMetadata(
            properties: [.init(key: "TITLE", values: ["Must not persist"])]
        )

        XCTAssertThrowsError(
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                payload,
                to: url,
                riffPolicy: .syncBasicFieldsToInfo,
                includeProperties: true,
                verifyAfterWrite: false,
                failurePolicy: .throw
            )
        ) { error in
            guard case TagLibManagerError.verificationFailed = error else {
                return XCTFail("Expected verificationFailed, got \(error)")
            }
        }

        XCTAssertEqual(
            try Data(contentsOf: url),
            originalBytes,
            "A failed write must leave the original file byte-for-byte unchanged."
        )
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
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
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

    func values(for key: String) -> [String] {
        properties.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.values ?? []
    }
}
