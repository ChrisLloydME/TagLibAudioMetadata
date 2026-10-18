import Foundation
import XCTest
@testable import TagLibAudioMetadata

final class AuditRemediationRegressionTests: XCTestCase {
    private func copyFixture(_ ext: String, named name: String = "testAudioFile") throws -> URL {
        let source = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: name, withExtension: ext)
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AuditRemediation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("\(name).\(ext)")
        try FileManager.default.copyItem(at: source, to: destination)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return destination
    }

    private func artworkData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "testCover", withExtension: "jpg", subdirectory: "Artwork")
                ?? Bundle.module.url(forResource: "testCover", withExtension: "jpg")
        )
        return try Data(contentsOf: url)
    }

    private func values(_ key: String, in url: URL) throws -> [String] {
        try TagLibMetadataManager.rawMetadataResult(from: url).properties
            .first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.values ?? []
    }

    func testStructuredPropertyWriteMergesOmittedM4APropertiesAndHiddenAtoms() throws {
        let url = try copyFixture("m4a")
        var seed = BasicMetadata.empty
        seed.title = "Seed"
        seed.artist = "Artist"
        seed.album = "Album"
        seed.track = 3
        seed.trackTotal = 10
        seed.disc = 1
        seed.discTotal = 2
        seed.customFields = ["HIDDEN_KEEP": "secret"]
        seed.artworkData = try artworkData()
        seed.artworkMIMEType = "image/jpeg"
        try TagLibMetadataManager.replaceBasicMetadata(seed, to: url)

        let before = try TagLibMetadataManager.readSnapshot(from: url)
        let warnings = try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(properties: [.init(key: "TITLE", values: ["Merged"])]),
            to: url,
            includeProperties: true
        ).warnings
        XCTAssertTrue(warnings.isEmpty)

        let after = try TagLibMetadataManager.readSnapshot(from: url)
        XCTAssertEqual(after.basic.title, "Merged")
        XCTAssertEqual(after.basic.artist, "Artist")
        XCTAssertEqual(after.basic.album, "Album")
        XCTAssertEqual(after.basic.track, 3)
        XCTAssertEqual(after.basic.trackTotal, 10)
        XCTAssertEqual(after.basic.disc, 1)
        XCTAssertEqual(after.basic.discTotal, 2)
        XCTAssertEqual(after.basic.customFields["HIDDEN_KEEP"], "secret")
        XCTAssertEqual(after.basic.artworkData, seed.artworkData)
        XCTAssertEqual(
            Set(after.structured.mp4Atoms.map(\.key)),
            Set(before.structured.mp4Atoms.map(\.key))
        )
        XCTAssertFalse(after.structured.mp4Atoms.contains {
            $0.key.localizedCaseInsensitiveContains("TAGLIBAUDIOMETADATA_")
        })
    }

    func testStructuredPropertiesRequireExplicitInclusionAndEmptyValuesRemove() throws {
        let url = try copyFixture("m4a")
        try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
            ["TITLE": ["Stable"], "MOOD": ["Focused"]],
            to: url
        )
        let before = try Data(contentsOf: url)
        XCTAssertThrowsError(try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(properties: [.init(key: "TITLE", values: ["Ignored"])]),
            to: url
        )) { error in
            guard case MetadataValidationError.propertiesRequireIncludeProperties = error else {
                return XCTFail("Expected propertiesRequireIncludeProperties, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), before)

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(properties: [.init(key: "MOOD", values: [])]),
            to: url,
            includeProperties: true
        )
        XCTAssertEqual(try values("TITLE", in: url), ["Stable"])
        XCTAssertTrue(try values("MOOD", in: url).isEmpty)
    }

    func testStructuredCollectionFrameTypesAreRejectedAndNotReturnedAsFrames() throws {
        let url = try copyFixture("mp3")
        var seed = BasicMetadata.empty
        seed.title = "Stable"
        seed.comment = "Comment"
        seed.artworkData = try artworkData()
        seed.artworkMIMEType = "image/jpeg"
        try TagLibMetadataManager.replaceBasicMetadata(seed, to: url)
        let before = try Data(contentsOf: url)

        let structured = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
        XCTAssertTrue(structured.artwork.contains { $0.container == "id3v2" })
        XCTAssertTrue(structured.comments.contains { $0.text == "Comment" })
        XCTAssertFalse(structured.id3v2Frames.contains { ["APIC", "COMM", "USLT"].contains($0.frameID) })

        let frame = StructuredID3v2Frame(frameID: "APIC", type: "artwork", data: try artworkData())
        XCTAssertThrowsError(try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(id3v2Frames: [frame]),
            to: url
        )) { error in
            guard case MetadataValidationError.unsupportedID3v2FrameType("artwork") = error else {
                return XCTFail("Expected unsupportedID3v2FrameType, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testBasicPreservesFullRecordingDateWithoutLegacyYearDuplication() throws {
        for ext in ["mp3", "flac", "ogg"] {
            let url = try copyFixture(ext)
            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                ["DATE": ["2021-07-15"], "TITLE": ["Date"]],
                to: url
            )
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }

            XCTAssertEqual(try values("DATE", in: url), ["2021-07-15"], ext)
            XCTAssertTrue(try values("YEAR", in: url).isEmpty, ext)
            XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: url).year, "2021", ext)
            if ext == "mp3" {
                let frames = try TagLibMetadataManager.rawMetadataResult(from: url).id3v2Frames
                XCTAssertEqual(frames.filter { $0.frameID == "TDRC" }.map(\.value), ["2021-07-15"])
                XCTAssertFalse(frames.contains { $0.frameID == "TYER" })
            }

            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.year = "2020" }
            XCTAssertEqual(try values("DATE", in: url), ["2020"], ext)
            XCTAssertTrue(try values("YEAR", in: url).isEmpty, ext)
        }
    }

    func testBasicPreservesDocumentedAliasesAndQualifiedPeopleFields() throws {
        for ext in ["flac", "ogg"] {
            let url = try copyFixture(ext)
            try TagLibMetadataManager.applyRawMetadataPatch(
                RawMetadataPatch(valuesToSet: [
                    "TITLE": ["Alias test"],
                    "DATE": ["2021-07-15"],
                    "PUBLISHER": ["Acme"],
                    "CATALOG": ["CAT-1"],
                    "ORIGINAL YEAR": ["1984"],
                    "MUSICBRAINZ ARTISTID": ["mbid"],
                    "PERFORMER:GUITAR": ["Guitarist"],
                    "COMMENT:C1": ["Comment one"],
                    "COMMENT:C2": ["Comment two"],
                    "LYRICS:D1": ["Lyric one"],
                    "LYRICS:D2": ["Lyric two"],
                ]),
                to: url
            )

            let before = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(before.publisher, "Acme", ext)
            XCTAssertEqual(before.catalogNumber, "CAT-1", ext)
            XCTAssertEqual(before.originalReleaseDate, "1984", ext)
            XCTAssertEqual(before.musicBrainzArtistID, "mbid", ext)
            XCTAssertEqual(before.comment, "Comment one", ext)
            XCTAssertEqual(before.lyrics, "Lyric one", ext)
            XCTAssertFalse(before.customFields.keys.contains { $0.hasPrefix("PERFORMER:") || $0.hasPrefix("COMMENT:") })

            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Changed" }

            XCTAssertEqual(try values("PUBLISHER", in: url), ["Acme"], ext)
            XCTAssertEqual(try values("CATALOG", in: url), ["CAT-1"], ext)
            XCTAssertEqual(try values("ORIGINAL YEAR", in: url), ["1984"], ext)
            XCTAssertEqual(try values("MUSICBRAINZ ARTISTID", in: url), ["mbid"], ext)
            XCTAssertEqual(try values("PERFORMER:GUITAR", in: url), ["Guitarist"], ext)
            XCTAssertEqual(try values("COMMENT:C1", in: url), ["Comment one"], ext)
            XCTAssertEqual(try values("COMMENT:C2", in: url), ["Comment two"], ext)
            XCTAssertEqual(try values("LYRICS:D1", in: url), ["Lyric one"], ext)
            XCTAssertEqual(try values("LYRICS:D2", in: url), ["Lyric two"], ext)
        }
    }

    func testNULAndRoleQualifiedInputsFailBeforeMutation() throws {
        let url = try copyFixture("mp3")
        let before = try Data(contentsOf: url)

        var nul = BasicMetadata.empty
        nul.customFields = ["BAD": "abc\0def"]
        XCTAssertThrowsError(try TagLibMetadataManager.replaceBasicMetadata(nul, to: url)) { error in
            guard case MetadataValidationError.embeddedNull = error else {
                return XCTFail("Expected embeddedNull, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), before)

        var emptyKey = BasicMetadata.empty
        emptyKey.customFields = ["   ": "value"]
        XCTAssertThrowsError(try TagLibMetadataManager.replaceBasicMetadata(emptyKey, to: url)) { error in
            guard case MetadataValidationError.invalidCustomFieldKey = error else {
                return XCTFail("Expected invalidCustomFieldKey, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), before)

        var role = BasicMetadata.empty
        role.customFields = ["PERFORMER:GUITAR": "Guitarist"]
        XCTAssertThrowsError(try TagLibMetadataManager.replaceBasicMetadata(role, to: url)) { error in
            guard case MetadataValidationError.knownFieldRequiresRawAPI = error else {
                return XCTFail("Expected knownFieldRequiresRawAPI, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), before)

        XCTAssertThrowsError(try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.performer: .text("Guitarist")]),
            to: url
        )) { error in
            guard case MetadataPatchValidationError.roleQualifiedFieldRequiresRawAPI(.performer) = error else {
                return XCTFail("Expected roleQualifiedFieldRequiresRawAPI, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testBasicClearingPreservesUnmodeledQualifiedAndCustomFields() throws {
        for ext in ["flac", "ogg"] {
            let url = try copyFixture(ext)
            try TagLibMetadataManager.applyRawMetadataPatch(
                RawMetadataPatch(valuesToSet: [
                    "TITLE": ["Clear me"],
                    "PERFORMER:GUITAR": ["Guitarist"],
                    "CUSTOM_FIELD": ["Custom Value"],
                ]),
                to: url
            )

            try TagLibMetadataManager.replaceBasicMetadata(.empty, to: url)

            let basic = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(basic.title, "", ext)
            XCTAssertEqual(try values("PERFORMER:GUITAR", in: url), ["Guitarist"], ext)
            XCTAssertEqual(try values("CUSTOM_FIELD", in: url), ["Custom Value"], ext)
        }
    }

    func testPartialNumberPairRemovalIsRejectedAndGenericRemovalPreservesTotal() throws {
        for ext in ["mp3", "m4a"] {
            let url = try copyFixture(ext)
            var seed = BasicMetadata.empty
            seed.track = 3
            seed.trackTotal = 10
            try TagLibMetadataManager.replaceBasicMetadata(seed, to: url)
            let before = try Data(contentsOf: url)
            XCTAssertThrowsError(try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.track: .remove]),
                to: url
            )) { error in
                guard case MetadataPatchValidationError.unsupportedPartialPairRemoval(.track, _) = error else {
                    return XCTFail("Expected unsupportedPartialPairRemoval, got \(error)")
                }
            }
            XCTAssertEqual(try Data(contentsOf: url), before, ext)

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.track: .remove, .trackTotal: .remove]),
                to: url
            )
            let cleared = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(cleared.track, 0, ext)
            XCTAssertEqual(cleared.trackTotal, 0, ext)
        }

        let flac = try copyFixture("flac")
        try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
            ["TRACKNUMBER": ["3"], "TRACKTOTAL": ["10"]],
            to: flac
        )
        try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields: [.track: .remove]), to: flac)
        let flacBasic = try TagLibMetadataManager.readMetadataResult(from: flac)
        XCTAssertEqual(flacBasic.track, 0)
        XCTAssertEqual(flacBasic.trackTotal, 10)
    }

    func testNumberTextEmitsOnlyCanonicalTotalsAndPreservesWAVInfo() throws {
        for ext in ["flac", "ogg"] {
            let url = try copyFixture(ext)
            try TagLibMetadataManager.writeTrackNumberText("03/10", discNumberText: "01/02", to: url)
            let raw = try TagLibMetadataManager.rawMetadataResult(from: url)
            XCTAssertEqual(raw.properties.first { $0.key == "TRACKTOTAL" }?.values, ["10"], ext)
            XCTAssertEqual(raw.properties.first { $0.key == "DISCTOTAL" }?.values, ["2"], ext)
            XCTAssertFalse(raw.properties.contains { ["TOTALTRACKS", "TOTALDISCS"].contains($0.key) }, ext)
        }

        let wav = try makeWAVWithInfo()
        try TagLibMetadataManager.writeTrackNumberText("03/10", discNumberText: "01/02", to: wav)
        let chunks = try riffChunks(at: wav)
        XCTAssertTrue(chunks.contains { $0.id == "LIST" })
        let raw = try TagLibMetadataManager.rawMetadataResult(from: wav)
        XCTAssertEqual(raw.id3v2Frames.first { $0.frameID == "TRCK" }?.value, "03/10")
        XCTAssertFalse(raw.id3v2Frames.contains { $0.frameID == "TXXX" && $0.value.contains("TOTAL") })
    }

    func testRawMergePreservesM4AHiddenAtomsAndWAVInfoSurface() throws {
        let m4a = try copyFixture("m4a")
        var seed = BasicMetadata.empty
        seed.title = "T"
        seed.artist = "A"
        seed.track = 3
        seed.trackTotal = 10
        seed.customFields = ["HIDDEN_KEEP": "secret"]
        try TagLibMetadataManager.replaceBasicMetadata(seed, to: m4a)
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(numberText: .init(trackNumberText: "03/10")),
            to: m4a
        )
        let before = try TagLibMetadataManager.readSnapshot(from: m4a)
        XCTAssertTrue(before.structured.mp4Atoms.contains { $0.key.contains("TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT") })

        try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
            ["TITLE": ["T2"]],
            to: m4a,
            mode: .merge
        )
        let after = try TagLibMetadataManager.readSnapshot(from: m4a)
        XCTAssertEqual(after.basic.title, "T2")
        XCTAssertEqual(after.basic.artist, "A")
        XCTAssertEqual(after.basic.track, 3)
        XCTAssertEqual(after.basic.trackTotal, 10)
        XCTAssertEqual(after.basic.customFields["HIDDEN_KEEP"], "secret")
        XCTAssertTrue(after.structured.mp4Atoms.contains { $0.key.contains("TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT") })

        let wav = try makeWAVWithInfo()
        try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
            ["COMMENT": ["Updated comment"]],
            to: wav,
            mode: .merge
        )
        let chunks = try riffChunks(at: wav)
        XCTAssertTrue(chunks.contains { $0.id == "LIST" })
        XCTAssertFalse(chunks.contains { $0.id == "ID3 " })
        let raw = try TagLibMetadataManager.rawMetadataResult(from: wav)
        XCTAssertEqual(raw.properties.first { $0.key == "COMMENT" }?.values, ["Updated comment"])

        let replaceM4A = try copyFixture("m4a")
        try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
            ["TITLE": ["Replaced"]],
            to: replaceM4A
        )
        let replacedAtoms = try TagLibMetadataManager.readSnapshot(from: replaceM4A).structured.mp4Atoms
        XCTAssertFalse(replacedAtoms.contains {
            $0.key.localizedCaseInsensitiveContains("TAGLIBAUDIOMETADATA_")
        })
    }

    func testArtworkMIMECorrectionWithIdenticalBytes() throws {
        let url = try copyFixture("flac")
        let data = try artworkData()
        var first = BasicMetadata.empty
        first.artworkData = data
        first.artworkMIMEType = "image/jpeg"
        try TagLibMetadataManager.replaceBasicMetadata(first, to: url)
        XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: url).artworkMIMEType, "image/jpeg")

        var corrected = try TagLibMetadataManager.readMetadataResult(from: url)
        corrected.artworkMIMEType = "image/png"
        try TagLibMetadataManager.replaceBasicMetadata(corrected, to: url)
        XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: url).artworkMIMEType, "image/png")
        XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: url).artworkData, data)
    }

    func testExpectedVersionRejectsConcurrentChange() throws {
        let url = try copyFixture("mp3")
        let version = try TagLibMetadataManager.fileVersion(at: url)
        try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
            ["TITLE": ["Versioned"]],
            to: url,
            expectedVersion: version
        )
        try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
            ["ARTIST": ["External change"]],
            to: url,
            mode: .merge
        )
        let before = try Data(contentsOf: url)
        XCTAssertThrowsError(try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(properties: [.init(key: "TITLE", values: ["Stale"])]),
            to: url,
            includeProperties: true,
            expectedVersion: version
        )) { error in
            guard case TagLibManagerError.fileChanged = error else {
                return XCTFail("Expected fileChanged, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testRIFFPolicyPreservesOrRemovesINFO() throws {
        let preserve = try makeWAVWithInfo()
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(properties: [.init(key: "TITLE", values: ["Preserved"])]),
            to: preserve,
            riffPolicy: .preserveInfo,
            includeProperties: true
        )
        XCTAssertTrue(try riffChunks(at: preserve).contains { $0.id == "LIST" })
        XCTAssertTrue(try riffChunks(at: preserve).contains { $0.id == "ID3 " })

        let strip = try makeWAVWithInfo()
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(properties: [.init(key: "TITLE", values: ["ID3 only"])]),
            to: strip,
            riffPolicy: .id3v2Only,
            includeProperties: true
        )
        XCTAssertFalse(try riffChunks(at: strip).contains { $0.id == "LIST" })
        XCTAssertTrue(try riffChunks(at: strip).contains { $0.id == "ID3 " })
        XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: strip).title, "ID3 only")
    }

    func testGeneratedFormatArtworkAndASFAttributes() throws {
        for ext in ["aac", "wma", "tta", "wv", "m4a", "mp3"] {
            let url = try copyFixture(ext)
            let artwork = StructuredArtwork(
                container: "caller-supplied-container-is-informational",
                mimeType: "image/jpeg",
                data: try artworkData()
            )
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(artwork: .replace([artwork])),
                to: url
            )
            let basic = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(basic.artworkData, artwork.data, ext)
            XCTAssertEqual(basic.artworkMIMEType, "image/jpeg", ext)

            try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(artwork: .removeAll), to: url)
            XCTAssertNil(try TagLibMetadataManager.readMetadataResult(from: url).artworkData, ext)
        }

        let wma = try copyFixture("wma")
        let before = try TagLibMetadataManager.readStructuredMetadataResult(from: wma)
        XCTAssertTrue(before.asfAttributes.contains { $0.key == "WM/EncodingSettings" })
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(asfAttributes: [
                .init(key: "WM/AlbumTitle", type: "string", value: "First")
            ]),
            to: wma
        )
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(asfAttributes: [
                .init(key: "WM/AlbumTitle", type: "string", value: "Second")
            ]),
            to: wma
        )
        let after = try TagLibMetadataManager.readStructuredMetadataResult(from: wma)
        let albums = after.asfAttributes.filter { $0.key == "WM/AlbumTitle" }
        XCTAssertEqual(albums.count, 1)
        XCTAssertEqual(albums.first?.value, "Second")
        XCTAssertTrue(after.asfAttributes.contains { $0.key == "WM/EncodingSettings" })

        let asfBasic = try copyFixture("wma")
        var asfSeed = BasicMetadata.empty
        asfSeed.title = "ASF Basic"
        asfSeed.explicitAdvisory = .explicit
        asfSeed.customFields = ["CUSTOM_FIELD": "Custom Value"]
        try TagLibMetadataManager.replaceBasicMetadata(asfSeed, to: asfBasic)
        let asfRead = try TagLibMetadataManager.readMetadataResult(from: asfBasic)
        XCTAssertEqual(asfRead.explicitAdvisory, .explicit)
        XCTAssertEqual(asfRead.customFields["CUSTOM_FIELD"], "Custom Value")
    }

    func testCapabilityAndSchemaRemediation() throws {
        XCTAssertEqual(TagLibMetadataManager.capability(forExtension: "mp3")?.preservesMultiValueProperties, true)
        XCTAssertEqual(TagLibMetadataManager.capability(forExtension: "m4a")?.preservesMultiValueProperties, true)
        XCTAssertEqual(TagLibMetadataManager.capability(forExtension: "wav")?.preservesMultiValueProperties, true)
        XCTAssertEqual(TagLibMetadataManager.capability(forExtension: "aac")?.canWriteArtwork, true)

        let mp4 = try XCTUnwrap(TagLibMetadataManager.capability(forExtension: "m4a"))
        XCTAssertFalse(MetadataFieldRegistry.schemas(storableIn: mp4).contains { $0.key == .date })
        XCTAssertTrue(MetadataFieldRegistry.schemas(storableIn: mp4).contains { $0.key == .releaseDate })

        XCTAssertEqual(MetadataFieldRegistry.schema(forPropertyMapKey: "COMMENT:C1")?.key, .comment)
        XCTAssertEqual(MetadataFieldRegistry.schema(forPropertyMapKey: "PERFORMER:GUITAR")?.key, .performer)
        XCTAssertTrue(MetadataFieldRegistry.schema(forPropertyMapKey: "PERFORMER:GUITAR")?.isRoleQualified == true)

        let alac = try TagLibMetadataManager.readMetadataResult(
            from: try copyFixture("m4a", named: "testAudioFile-alac")
        )
        XCTAssertEqual(alac.format, "ALAC")
        XCTAssertEqual(alac.bitDepth, 16)
    }

    func testMissingFileFailuresUseTypedOperationError() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).mp3")
        XCTAssertThrowsError(try TagLibMetadataManager.replaceBasicMetadata(.empty, to: url)) { error in
            guard case TagLibManagerError.operationFailed = error else {
                return XCTFail("Expected operationFailed, got \(error)")
            }
        }
        let reads: [() throws -> Void] = [
            { _ = try TagLibMetadataManager.readMetadataResult(from: url) },
            { _ = try TagLibMetadataManager.rawMetadataResult(from: url) },
            { _ = try TagLibMetadataManager.readStructuredMetadataResult(from: url) },
            { _ = try TagLibMetadataManager.readSnapshot(from: url) },
        ]
        for read in reads {
            XCTAssertThrowsError(try read()) { error in
                guard case TagLibManagerError.invalidFile = error else {
                    return XCTFail("Expected invalidFile, got \(error)")
                }
            }
        }
    }

    // MARK: - Independent RIFF helpers

    private func makeWAVWithInfo() throws -> URL {
        let source = try copyFixture("wav")
        var data = try Data(contentsOf: source)
        guard data.count >= 12, String(data: data[0..<4], encoding: .ascii) == "RIFF" else {
            throw NSError(domain: "AuditRemediation", code: 1)
        }
        var infoPayload = Data("INFO".utf8)
        infoPayload.append(infoSubchunk(id: "ICMT", value: "Info Comment"))
        infoPayload.append(infoSubchunk(id: "INAM", value: "Info Title"))
        var listChunk = Data("LIST".utf8)
        listChunk.append(littleEndian(UInt32(infoPayload.count)))
        listChunk.append(infoPayload)
        if infoPayload.count % 2 == 1 { listChunk.append(0) }

        guard let dataOffset = findChunk("data", in: data) else {
            throw NSError(domain: "AuditRemediation", code: 2)
        }
        data.insert(contentsOf: listChunk, at: dataOffset)
        let newRIFFSize = UInt32(data.count - 8)
        data.replaceSubrange(4..<8, with: littleEndian(newRIFFSize))
        try data.write(to: source)
        return source
    }

    private func infoSubchunk(id: String, value: String) -> Data {
        let bytes = Data(value.utf8)
        var result = Data(id.utf8)
        result.append(littleEndian(UInt32(bytes.count)))
        result.append(bytes)
        if bytes.count % 2 == 1 { result.append(0) }
        return result
    }

    private func littleEndian(_ value: UInt32) -> Data {
        var value = value.littleEndian
        return Data(bytes: &value, count: 4)
    }

    private func findChunk(_ id: String, in data: Data) -> Int? {
        var offset = 12
        while offset + 8 <= data.count {
            guard let chunkID = String(data: data[offset..<offset + 4], encoding: .ascii) else { return nil }
            let size = Int(data[offset + 4]) | Int(data[offset + 5]) << 8
                | Int(data[offset + 6]) << 16 | Int(data[offset + 7]) << 24
            if chunkID == id { return offset }
            offset += 8 + size + (size & 1)
        }
        return nil
    }

    private func riffChunks(at url: URL) throws -> [(id: String, size: Int)] {
        let data = try Data(contentsOf: url)
        var result: [(String, Int)] = []
        var offset = 12
        while offset + 8 <= data.count {
            guard let id = String(data: data[offset..<offset + 4], encoding: .ascii) else { break }
            let size = Int(data[offset + 4]) | Int(data[offset + 5]) << 8
                | Int(data[offset + 6]) << 16 | Int(data[offset + 7]) << 24
            result.append((id, size))
            offset += 8 + size + (size & 1)
        }
        return result
    }
}
