import XCTest
import TagLibAudioMetadata

final class FixtureMetadataRoundTripTests: XCTestCase {
    private let writableFixtures = ["mp3", "m4a", "flac", "aac", "ogg", "oga", "wav"]

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

    func testExplicitAdvisoryPreservesAbsenceCleanAndExplicitStates() throws {
        for ext in writableFixtures {
            let url = try copyAudioFixture(ext)

            var metadata = BasicMetadata.empty
            metadata.explicitAdvisory = .unspecified
            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)
            XCTAssertEqual(
                try TagLibMetadataManager.readMetadataResult(from: url).explicitAdvisory,
                .unspecified,
                "\(ext) should preserve advisory absence"
            )

            metadata.explicitAdvisory = .clean
            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)
            var result = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(result.explicitAdvisory, .clean, "\(ext) should preserve an explicit clean advisory")
            XCTAssertFalse(result.isExplicit, ext)

            metadata.explicitAdvisory = .explicit
            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)
            result = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(result.explicitAdvisory, .explicit, "\(ext) should preserve an explicit advisory")
            XCTAssertTrue(result.isExplicit, ext)

            metadata.explicitAdvisory = .unspecified
            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)
            XCTAssertEqual(
                try TagLibMetadataManager.readMetadataResult(from: url).explicitAdvisory,
                .unspecified,
                "\(ext) should remove advisory metadata when set back to unspecified"
            )
        }
    }

    func testArtworkCanBeWrittenAndRemovedWhereSupported() throws {
        let artwork = try Data(contentsOf: artworkFixtureURL())

        for ext in ["mp3", "m4a", "flac", "ogg", "oga", "wav"] {
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

    func testJPEGArtworkBytesAndMIMETypeRoundTripTogether() throws {
        let artwork = try Data(contentsOf: artworkFixtureURL())

        for ext in ["mp3", "m4a", "flac", "ogg", "oga", "wav"] {
            let capability = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: ext))
            guard capability.canWriteArtwork else { continue }

            let url = try copyAudioFixture(ext)
            var metadata = BasicMetadata.empty
            metadata.artworkData = artwork
            metadata.artworkMIMEType = "image/jpeg"

            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)
            let result = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(result.artworkData, artwork, ext)
            XCTAssertEqual(result.artworkMIMEType, "image/jpeg", ext)
        }
    }

    func testPNGArtworkMIMETypeIsInferredAndRoundTripsWithBytes() throws {
        let artwork = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        ))

        for ext in ["mp3", "m4a", "flac", "ogg", "oga", "wav"] {
            let capability = try XCTUnwrap(TagLibMetadataManager.formatCapability(for: ext))
            guard capability.canWriteArtwork else { continue }

            let url = try copyAudioFixture(ext)
            var metadata = BasicMetadata.empty
            metadata.artworkData = artwork
            metadata.artworkMIMEType = nil

            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)
            let result = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(result.artworkData, artwork, ext)
            XCTAssertEqual(result.artworkMIMEType, "image/png", ext)
        }
    }

    func testRawPropertyMapReplaceMergeAndMultiValueWrites() throws {
        for ext in ["flac", "ogg", "oga", "m4a"] {
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
        for ext in ["flac", "ogg", "oga"] {
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

    func testBasicReadWritePreservesUnmodifiedCustomFieldCardinality() throws {
        for ext in ["mp3", "m4a", "flac", "ogg", "oga"] {
            let url = try copyAudioFixture(ext)
            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                ["CUSTOM_MULTI": ["Artist A", "Artist B"]],
                to: url,
                failurePolicy: .throw
            )

            var basic = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(basic.customFieldValues["CUSTOM_MULTI"], ["Artist A", "Artist B"], ext)
            basic.title = "Basic title edit"
            try TagLibMetadataManager.writeMetadataWithVerification(basic, to: url, failurePolicy: .throw)

            XCTAssertEqual(
                try TagLibMetadataManager.rawMetadataResult(from: url).values(for: "CUSTOM_MULTI"),
                ["Artist A", "Artist B"],
                "\(ext) must not flatten an untouched multi-value custom field"
            )
        }
    }

    func testBasicReadWritePreservesUnmodifiedStandardFieldCardinality() throws {
        let originalValues: [String: [String]] = [
            "ARTIST": ["Artist A", "Artist B"],
            "COMPOSER": ["Composer A", "Composer B"],
            "ALBUMARTIST": ["Album Artist A", "Album Artist B"],
            "GENRE": ["Rock", "Alternative"],
        ]

        for ext in ["mp3", "m4a", "flac", "ogg", "oga"] {
            let url = try copyAudioFixture(ext)
            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                originalValues,
                to: url,
                failurePolicy: .throw
            )

            var basic = try TagLibMetadataManager.readMetadataResult(from: url)
            basic.title = "Unrelated Basic title edit"
            try TagLibMetadataManager.writeMetadataWithVerification(basic, to: url, failurePolicy: .throw)

            let raw = try TagLibMetadataManager.rawMetadataResult(from: url)
            for (key, values) in originalValues {
                XCTAssertEqual(
                    raw.values(for: key),
                    values,
                    "\(ext) must preserve untouched \(key) cardinality during a Basic write"
                )
            }
        }
    }

    func testBasicReadWritePreservesKnownFieldsOutsideBasicMetadata() throws {
        let preservedValues: [String: [String]] = [
            "PERFORMER": ["Guitar", "Piano"],
            "INVOLVEDPEOPLE": ["Producer", "Engineer"],
            "TRACKERNAME": ["Non-Basic single value"],
            "UNREGISTERED_CUSTOM": ["Custom A", "Custom B"],
        ]

        for ext in ["flac", "ogg", "oga"] {
            let url = try copyAudioFixture(ext)
            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                preservedValues,
                to: url,
                failurePolicy: .throw
            )

            var basic = try TagLibMetadataManager.readMetadataResult(from: url)
            basic.title = "Only Basic title changed"
            basic.customFields.removeValue(forKey: "UNREGISTERED_CUSTOM")
            try TagLibMetadataManager.writeMetadataWithVerification(basic, to: url, failurePolicy: .throw)

            let raw = try TagLibMetadataManager.rawMetadataResult(from: url)
            for (key, values) in preservedValues {
                XCTAssertEqual(raw.values(for: key), values, "\(ext) must preserve \(key)")
            }
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

    func testStructuredID3ChapterAndTableOfContentsRoundTrip() throws {
        let url = try copyAudioFixture("mp3")
        let payload = StructuredMetadata(
            id3v2Frames: [
                .init(
                    frameID: "CHAP",
                    type: "chapter",
                    elementID: "chapter-1",
                    startTimeMilliseconds: 1_000,
                    endTimeMilliseconds: 5_000,
                    startOffset: Int(UInt32.max),
                    endOffset: Int(UInt32.max)
                ),
                .init(
                    frameID: "CTOC",
                    type: "tableOfContents",
                    elementID: "toc-root",
                    isTopLevel: true,
                    isOrdered: true,
                    children: ["chapter-1"]
                ),
                .init(frameID: "PCST", type: "podcast"),
            ]
        )

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            payload,
            to: url,
            failurePolicy: .throw
        )

        let result = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
        let chapter = try XCTUnwrap(result.id3v2Frames.first { $0.frameID == "CHAP" })
        XCTAssertEqual(chapter.elementID, "chapter-1")
        XCTAssertEqual(chapter.startTimeMilliseconds, 1_000)
        XCTAssertEqual(chapter.endTimeMilliseconds, 5_000)
        XCTAssertEqual(chapter.startOffset, Int(UInt32.max))
        XCTAssertEqual(chapter.endOffset, Int(UInt32.max))

        let toc = try XCTUnwrap(result.id3v2Frames.first { $0.frameID == "CTOC" })
        XCTAssertEqual(toc.elementID, "toc-root")
        XCTAssertEqual(toc.isTopLevel, true)
        XCTAssertEqual(toc.isOrdered, true)
        XCTAssertEqual(toc.children, ["chapter-1"])
        XCTAssertTrue(result.id3v2Frames.contains { $0.frameID == "PCST" && $0.type == "podcast" })
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

    func testBasicReadWritePreservesUnmodifiedAdditionalArtwork() throws {
        let firstArtwork = try Data(contentsOf: artworkFixtureURL())
        var secondArtwork = firstArtwork
        secondArtwork.append(0)

        for ext in ["mp3", "m4a"] {
            let url = try copyAudioFixture(ext)
            let container = ext == "mp3" ? "id3v2" : "mp4"
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(artwork: [
                    .init(container: container, mimeType: "image/jpeg", description: "Front", data: firstArtwork),
                    .init(container: container, mimeType: "image/jpeg", description: "Back", data: secondArtwork),
                ]),
                to: url,
                failurePolicy: .throw
            )

            var basic = try TagLibMetadataManager.readMetadataResult(from: url)
            basic.title = "Only the title changed"
            try TagLibMetadataManager.writeMetadataWithVerification(basic, to: url, failurePolicy: .throw)

            let artwork = try TagLibMetadataManager.readStructuredMetadataResult(from: url).artwork
            XCTAssertEqual(artwork.count, 2, ext)
            XCTAssertEqual(Set(artwork.map(\.data)), Set([firstArtwork, secondArtwork]), ext)
        }
    }

    func testMetadataPatchChangesOnlyRequestedFields() throws {
        let firstArtwork = try Data(contentsOf: artworkFixtureURL())
        var secondArtwork = firstArtwork
        secondArtwork.append(0)

        for ext in ["mp3", "m4a"] {
            let url = try copyAudioFixture(ext)
            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                ["TITLE": ["Before"], "CUSTOM_MULTI": ["One", "Two"]],
                to: url,
                failurePolicy: .throw
            )
            let container = ext == "mp3" ? "id3v2" : "mp4"
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(artwork: [
                    .init(container: container, mimeType: "image/jpeg", description: "Front", data: firstArtwork),
                    .init(container: container, mimeType: "image/jpeg", description: "Back", data: secondArtwork),
                ]),
                to: url,
                failurePolicy: .throw
            )

            let before = try TagLibMetadataManager.readSnapshot(from: url)
            XCTAssertEqual(before.raw.values(for: "CUSTOM_MULTI"), ["One", "Two"], ext)
            XCTAssertEqual(before.structured.artwork.count, 2, ext)

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.title: .text("After")], explicitAdvisory: .clean),
                to: url,
                failurePolicy: .throw
            )

            var after = try TagLibMetadataManager.readSnapshot(from: url)
            XCTAssertEqual(after.basic.title, "After", ext)
            XCTAssertEqual(after.basic.explicitAdvisory, .clean, ext)
            XCTAssertEqual(after.raw.values(for: "CUSTOM_MULTI"), ["One", "Two"], ext)
            XCTAssertEqual(Set(after.structured.artwork.map(\.data)), Set([firstArtwork, secondArtwork]), ext)

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(customFields: ["CUSTOM_MULTI": .values(["Three", "Four"])]),
                to: url,
                failurePolicy: .throw
            )
            after = try TagLibMetadataManager.readSnapshot(from: url)
            XCTAssertEqual(after.basic.title, "After", ext)
            XCTAssertEqual(after.raw.values(for: "CUSTOM_MULTI"), ["Three", "Four"], ext)
            XCTAssertEqual(after.structured.artwork.count, 2, ext)
        }
    }

    func testM4AMetadataPatchPreservesAndUpdatesNativeTrackDiscPairs() throws {
        struct Scenario {
            let name: String
            let fields: [MetadataFieldKey: MetadataPatchValue]
            let expectedTrack: Int
            let expectedTrackTotal: Int
            let expectedDisc: Int
            let expectedDiscTotal: Int
        }

        let scenarios = [
            Scenario(name: "track only", fields: [.track: .integer(5)], expectedTrack: 5, expectedTrackTotal: 12, expectedDisc: 1, expectedDiscTotal: 2),
            Scenario(name: "track total only", fields: [.trackTotal: .integer(20)], expectedTrack: 3, expectedTrackTotal: 20, expectedDisc: 1, expectedDiscTotal: 2),
            Scenario(name: "track pair", fields: [.track: .integer(6), .trackTotal: .integer(24)], expectedTrack: 6, expectedTrackTotal: 24, expectedDisc: 1, expectedDiscTotal: 2),
            Scenario(name: "disc only", fields: [.disc: .integer(2)], expectedTrack: 3, expectedTrackTotal: 12, expectedDisc: 2, expectedDiscTotal: 2),
            Scenario(name: "disc total only", fields: [.discTotal: .integer(4)], expectedTrack: 3, expectedTrackTotal: 12, expectedDisc: 1, expectedDiscTotal: 4),
            Scenario(name: "disc pair", fields: [.disc: .integer(3), .discTotal: .integer(5)], expectedTrack: 3, expectedTrackTotal: 12, expectedDisc: 3, expectedDiscTotal: 5),
        ]

        for scenario in scenarios {
            let url = try copyAudioFixture("m4a")
            var baseline = try TagLibMetadataManager.readMetadataResult(from: url)
            baseline.track = 3
            baseline.trackTotal = 12
            baseline.trackNumberText = "3/12"
            baseline.disc = 1
            baseline.discTotal = 2
            baseline.discNumberText = "1/2"
            try TagLibMetadataManager.writeMetadataWithVerification(baseline, to: url, failurePolicy: .throw)

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: scenario.fields),
                to: url,
                failurePolicy: .throw
            )

            let result = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(result.track, scenario.expectedTrack, scenario.name)
            XCTAssertEqual(result.trackTotal, scenario.expectedTrackTotal, scenario.name)
            XCTAssertEqual(result.disc, scenario.expectedDisc, scenario.name)
            XCTAssertEqual(result.discTotal, scenario.expectedDiscTotal, scenario.name)

            let atoms = try TagLibMetadataManager.readStructuredMetadataResult(from: url).mp4Atoms
            let trackAtom = try XCTUnwrap(atoms.first { $0.key == "trkn" }, scenario.name)
            let discAtom = try XCTUnwrap(atoms.first { $0.key == "disk" }, scenario.name)
            XCTAssertEqual(trackAtom.first, scenario.expectedTrack, scenario.name)
            XCTAssertEqual(trackAtom.second, scenario.expectedTrackTotal, scenario.name)
            XCTAssertEqual(discAtom.first, scenario.expectedDisc, scenario.name)
            XCTAssertEqual(discAtom.second, scenario.expectedDiscTotal, scenario.name)
        }
    }

    func testPropertyMapMetadataPatchPreservesTrackDiscPairComponents() throws {
        for ext in ["mp3", "flac", "ogg", "oga"] {
            let url = try copyAudioFixture(ext)
            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                [
                    "TRACKNUMBER": ["3/12"],
                    "TRACKTOTAL": ["12"],
                    "DISCNUMBER": ["1/2"],
                    "DISCTOTAL": ["2"],
                ],
                to: url,
                verifyAfterWrite: false,
                failurePolicy: .throw
            )

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.track: .integer(5), .discTotal: .integer(4)]),
                to: url,
                failurePolicy: .throw
            )

            let result = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(result.track, 5, ext)
            XCTAssertEqual(result.trackTotal, 12, ext)
            XCTAssertEqual(result.disc, 1, ext)
            XCTAssertEqual(result.discTotal, 4, ext)
        }
    }

    func testMetadataPatchBooleanFalseIsDistinctFromRemoval() throws {
        let url = try copyAudioFixture("flac")

        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.compilation: .boolean(false)]),
            to: url,
            failurePolicy: .throw
        )
        XCTAssertEqual(try TagLibMetadataManager.rawMetadataResult(from: url).values(for: "COMPILATION"), ["0"])

        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.compilation: .boolean(true)]),
            to: url,
            failurePolicy: .throw
        )
        XCTAssertEqual(try TagLibMetadataManager.rawMetadataResult(from: url).values(for: "COMPILATION"), ["1"])

        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.compilation: .remove]),
            to: url,
            failurePolicy: .throw
        )
        XCTAssertEqual(try TagLibMetadataManager.rawMetadataResult(from: url).values(for: "COMPILATION"), [])
    }

    func testM4AMetadataPatchMutatesNativeExplicitAdvisoryWithoutContradictoryFreeformValue() throws {
        struct Scenario {
            let name: String
            let initial: ExplicitAdvisory
            let patched: ExplicitAdvisory
            let expectedNativeValue: String?
        }

        let scenarios = [
            Scenario(name: "explicit to clean", initial: .explicit, patched: .clean, expectedNativeValue: "2"),
            Scenario(name: "clean to explicit", initial: .clean, patched: .explicit, expectedNativeValue: "4"),
            Scenario(name: "explicit to unspecified", initial: .explicit, patched: .unspecified, expectedNativeValue: nil),
            Scenario(name: "absent to explicit", initial: .unspecified, patched: .explicit, expectedNativeValue: "4"),
            Scenario(name: "absent to clean", initial: .unspecified, patched: .clean, expectedNativeValue: "2"),
        ]

        for scenario in scenarios {
            let url = try copyAudioFixture("m4a")
            var baseline = try TagLibMetadataManager.readMetadataResult(from: url)
            baseline.explicitAdvisory = scenario.initial
            try TagLibMetadataManager.writeMetadataWithVerification(baseline, to: url, failurePolicy: .throw)

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(explicitAdvisory: scenario.patched),
                to: url,
                failurePolicy: .throw
            )

            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            XCTAssertEqual(snapshot.basic.explicitAdvisory, scenario.patched, scenario.name)

            let nativeRating = snapshot.structured.mp4Atoms.first { $0.key == "rtng" }
            XCTAssertEqual(nativeRating?.value, scenario.expectedNativeValue, scenario.name)
            XCTAssertFalse(
                snapshot.structured.mp4Atoms.contains {
                    $0.key.uppercased().contains("ITUNESADVISORY")
                },
                "\(scenario.name) must not leave a contradictory MP4 freeform advisory"
            )
        }
    }

    func testMP3MetadataPatchUsesSingleID3AdvisoryRepresentation() throws {
        let url = try copyAudioFixture("mp3")
        var baseline = try TagLibMetadataManager.readMetadataResult(from: url)
        baseline.explicitAdvisory = .explicit
        try TagLibMetadataManager.writeMetadataWithVerification(baseline, to: url, failurePolicy: .throw)

        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(explicitAdvisory: .clean),
            to: url,
            failurePolicy: .throw
        )
        var snapshot = try TagLibMetadataManager.readSnapshot(from: url)
        XCTAssertEqual(snapshot.basic.explicitAdvisory, .clean)
        XCTAssertEqual(
            snapshot.raw.id3v2Frames.filter {
                $0.frameID == "TXXX" && $0.description?.uppercased() == "ITUNESADVISORY"
            }.map(\.value),
            ["[ITUNESADVISORY] 2"]
        )

        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(explicitAdvisory: .unspecified),
            to: url,
            failurePolicy: .throw
        )
        snapshot = try TagLibMetadataManager.readSnapshot(from: url)
        XCTAssertEqual(snapshot.basic.explicitAdvisory, .unspecified)
        XCTAssertFalse(snapshot.raw.id3v2Frames.contains {
            $0.frameID == "TXXX" && $0.description?.uppercased() == "ITUNESADVISORY"
        })
    }

    func testMetadataPatchRejectsInvalidValueTypesBeforeMutation() throws {
        let url = try copyAudioFixture("flac")
        let originalBytes = try Data(contentsOf: url)

        XCTAssertThrowsError(
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.title: .integer(123)]),
                to: url
            )
        ) { error in
            XCTAssertEqual(
                error as? MetadataPatchValidationError,
                .incompatibleValue(field: .title, expected: [.text], actual: .integer)
            )
        }
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)

        XCTAssertThrowsError(
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.bpm: .text("hello")]),
                to: url
            )
        ) { error in
            XCTAssertEqual(
                error as? MetadataPatchValidationError,
                .incompatibleValue(field: .bpm, expected: [.integer], actual: .text)
            )
        }
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
    }

    func testMetadataPatchCustomFieldsCannotBypassTypedSchemaValidation() throws {
        let url = try copyAudioFixture("flac")
        let originalBytes = try Data(contentsOf: url)

        XCTAssertThrowsError(try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(customFields: ["TITLE": .integer(123)]),
            to: url
        )) { error in
            XCTAssertEqual(
                error as? MetadataPatchValidationError,
                .knownFieldRequiresTypedAPI(customKey: "TITLE", field: .title)
            )
        }
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)

        XCTAssertThrowsError(try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(customFields: ["album artist": .text("Alias")]),
            to: url
        )) { error in
            XCTAssertEqual(
                error as? MetadataPatchValidationError,
                .knownFieldRequiresTypedAPI(customKey: "album artist", field: .albumArtist)
            )
        }

        XCTAssertThrowsError(try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.title: .text("Typed")], customFields: ["title": .text("Custom")]),
            to: url
        )) { error in
            XCTAssertEqual(
                error as? MetadataPatchValidationError,
                .conflictingFieldRepresentations(field: .title, customKey: "title")
            )
        }

        XCTAssertThrowsError(try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(customFields: ["case_key": .text("One"), "CASE_KEY": .text("Two")]),
            to: url
        )) { error in
            XCTAssertEqual(
                error as? MetadataPatchValidationError,
                .duplicateCustomField(normalizedKey: "CASE_KEY")
            )
        }

        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(customFields: ["truly_unknown": .values(["One", "Two"])]),
            to: url,
            failurePolicy: .throw
        )
        XCTAssertEqual(
            try TagLibMetadataManager.rawMetadataResult(from: url).values(for: "TRULY_UNKNOWN"),
            ["One", "Two"]
        )
    }

    func testMetadataPatchEnforcesSharedNumericConstraintsBeforeMutation() throws {
        for (field, value) in [
            (MetadataFieldKey.track, -1),
            (.disc, -1),
            (.bpm, -20),
        ] {
            let url = try copyAudioFixture("flac")
            let originalBytes = try Data(contentsOf: url)
            XCTAssertThrowsError(try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [field: .integer(value)]),
                to: url
            )) { error in
                XCTAssertEqual(
                    error as? MetadataPatchValidationError,
                    .integerOutOfRange(
                        field: field,
                        minimum: 0,
                        maximum: Int(Int32.max),
                        actual: value
                    )
                )
            }
            XCTAssertEqual(try Data(contentsOf: url), originalBytes)
        }

        let zeroURL = try copyAudioFixture("flac")
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.track: .integer(0), .disc: .integer(0), .bpm: .integer(0)]),
            to: zeroURL,
            failurePolicy: .throw
        )
        let zero = try TagLibMetadataManager.readMetadataResult(from: zeroURL)
        XCTAssertEqual(zero.track, 0)
        XCTAssertEqual(zero.disc, 0)
        XCTAssertEqual(zero.bpm, 0)

        let maximumURL = try copyAudioFixture("flac")
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.bpm: .integer(Int(Int32.max))]),
            to: maximumURL,
            failurePolicy: .throw
        )
        XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: maximumURL).bpm, Int(Int32.max))
        let maximumBytes = try Data(contentsOf: maximumURL)

        let aboveMaximum = Int(Int32.max) + 1
        XCTAssertThrowsError(try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.bpm: .integer(aboveMaximum)]),
            to: maximumURL
        )) { error in
            XCTAssertEqual(
                error as? MetadataPatchValidationError,
                .integerOutOfRange(
                    field: .bpm,
                    minimum: 0,
                    maximum: Int(Int32.max),
                    actual: aboveMaximum
                )
            )
        }
        XCTAssertEqual(try Data(contentsOf: maximumURL), maximumBytes)
    }

    func testEraseAllMetadataReportsNoResidualCoreFields() throws {
        for ext in ["mp3", "m4a", "flac", "ogg", "oga", "wav"] {
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

    func testFacadeTransactionsCleanTemporaryFilesAfterSuccessAndFailure() throws {
        let url = try copyAudioFixture("mp3")
        let directory = url.deletingLastPathComponent()
        var metadata = BasicMetadata.empty
        metadata.title = "Successful mutation"
        try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)
        XCTAssertTrue(try transactionTemporaryFiles(in: directory).isEmpty)

        let bridgeMetadata = TagLibAudioMetadata()
        bridgeMetadata.title = "Must roll back"
        let mismatched = TagLibMetadataManager.MetadataWriteVerificationContext(
            expectedTrackNumber: nil,
            expectedTrackTotal: nil,
            expectedTrackNumberText: nil,
            expectedDiscNumber: nil,
            expectedDiscTotal: nil,
            expectedDiscNumberText: nil,
            expectedExplicitContent: nil,
            artworkExpectation: .unchanged,
            customFieldKeys: [],
            expectedTextFields: ["title": "Different title"]
        )
        XCTAssertThrowsError(
            try TagLibMetadataManager.writeTagMetadata(
                bridgeMetadata,
                to: url,
                verification: mismatched,
                failurePolicy: .throw
            )
        )
        XCTAssertTrue(try transactionTemporaryFiles(in: directory).isEmpty)
    }

    func testUnifiedProjectionMatchesPublicBridgeReadersAcrossFixtures() throws {
        for ext in writableFixtures {
            let url = try copyAudioFixture(ext)
            let projections = try TagLibMetadataExtractor.metadataProjections(for: url)
            let projectedBasic = try XCTUnwrap(projections["basic"] as? TagLibAudioMetadata)
            let projectedRaw = try XCTUnwrap(projections["raw"] as? NSDictionary)
            let projectedStructured = try XCTUnwrap(projections["structured"] as? NSDictionary)

            let publicBasic = try TagLibMetadataExtractor.extractMetadata(from: url)
            let publicRaw = try TagLibMetadataExtractor.rawMetadata(for: url) as NSDictionary
            let publicStructured = try TagLibMetadataExtractor.structuredMetadata(for: url) as NSDictionary

            XCTAssertEqual(projectedBasic.title, publicBasic.title, ext)
            XCTAssertEqual(projectedBasic.artist, publicBasic.artist, ext)
            XCTAssertEqual(projectedBasic.album, publicBasic.album, ext)
            XCTAssertEqual(projectedBasic.trackNumber, publicBasic.trackNumber, ext)
            XCTAssertEqual(projectedBasic.totalTracks, publicBasic.totalTracks, ext)
            XCTAssertEqual(projectedBasic.discNumber, publicBasic.discNumber, ext)
            XCTAssertEqual(projectedBasic.totalDiscs, publicBasic.totalDiscs, ext)
            XCTAssertEqual(projectedBasic.explicitAdvisory, publicBasic.explicitAdvisory, ext)
            XCTAssertEqual(projectedBasic.artworkData, publicBasic.artworkData, ext)
            XCTAssertEqual(projectedBasic.artworkMimeType, publicBasic.artworkMimeType, ext)
            XCTAssertEqual(projectedBasic.customFields, publicBasic.customFields, ext)
            XCTAssertEqual(projectedRaw, publicRaw, ext)
            XCTAssertEqual(projectedStructured, publicStructured, ext)
        }
    }

    func testSelectiveProjectionExtractionReturnsOnlyRequestedRepresentations() throws {
        let url = try copyAudioFixture("mp3")

        let basicAndRaw = try TagLibMetadataExtractor.metadataProjections(
            for: url,
            options: [.basic, .raw]
        )
        XCTAssertNotNil(basicAndRaw["basic"])
        XCTAssertNotNil(basicAndRaw["raw"])
        XCTAssertNil(basicAndRaw["structured"])

        let structuredOnly = try TagLibMetadataExtractor.metadataProjections(
            for: url,
            options: .structured
        )
        XCTAssertNil(structuredOnly["basic"])
        XCTAssertNil(structuredOnly["raw"])
        XCTAssertNotNil(structuredOnly["structured"])
    }

    func testXMSupportedFieldsRoundTripWithoutCorruptingModule() throws {
        let url = try copyAudioFixture("xm")
        let beforeBytes = try Data(contentsOf: url)
        let before = try TagLibMetadataManager.rawMetadataResult(from: url)

        XCTAssertEqual(before.values(for: "TITLE"), ["title of song"])
        XCTAssertEqual(
            before.values(for: "TRACKERNAME").map { $0.trimmingCharacters(in: .whitespaces) },
            ["MilkyTracker"]
        )

        let result = try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
            [
                "TITLE": ["XM Round Trip"],
                "COMMENT": ["XM comment"],
                "TRACKERNAME": ["TagLibAudioMetadata"],
            ],
            to: url,
            verifyAfterWrite: false,
            failurePolicy: .throw
        )
        XCTAssertTrue(result.warnings.isEmpty)

        let after = try TagLibMetadataManager.rawMetadataResult(from: url)
        XCTAssertEqual(after.values(for: "TITLE"), ["XM Round Trip"])
        XCTAssertTrue(after.values(for: "COMMENT").first?.hasPrefix("XM comment") == true)
        XCTAssertEqual(
            after.values(for: "TRACKERNAME").map { $0.trimmingCharacters(in: .whitespaces) },
            ["TagLibAudioMetadata"]
        )
        XCTAssertNotEqual(try Data(contentsOf: url), beforeBytes)

        let basic = try TagLibMetadataManager.readMetadataResult(from: url)
        XCTAssertEqual(basic.title, "XM Round Trip")
        XCTAssertTrue(basic.comment.hasPrefix("XM comment"))
        XCTAssertEqual(basic.format, "XM")

        let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
        XCTAssertEqual(snapshot.basic.title, "XM Round Trip")
        XCTAssertEqual(snapshot.raw.values(for: "TITLE"), ["XM Round Trip"])
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

    private func transactionTemporaryFiles(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.contains(".taglib-") }
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
