import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

struct ReviewMetadataIntegrityTests {
    private func withFixture(_ ext: String, _ body: (URL) throws -> Void) throws {
        let source = try #require(
            Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext)
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IndependentReview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.\(ext)")
        try FileManager.default.copyItem(at: source, to: url)
        try body(url)
    }

    private func coverData() throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "testCover", withExtension: "jpg", subdirectory: "Artwork")
                ?? Bundle.module.url(forResource: "testCover", withExtension: "jpg")
        )
        return try Data(contentsOf: url)
    }

    // This deliberately parses frame boundaries without using any bridge output.
    private func id3FramePayloads(at url: URL, frameID: String) throws -> [Data] {
        let data = try Data(contentsOf: url)
        let header = try #require(
            data.range(of: Data([0x49, 0x44, 0x33, 4, 0]))
                ?? data.range(of: Data([0x49, 0x44, 0x33, 3, 0]))
        ).lowerBound
        #expect(data[header + 5] == 0) // Generated test tags have no extended header/unsynchronisation.
        let version = data[header + 3]
        #expect(version == 3 || version == 4)
        func size(_ offset: Int, syncSafe: Bool) -> Int {
            data[offset..<(offset + 4)].reduce(0) { ($0 << (syncSafe ? 7 : 8)) | Int($1) }
        }
        let end = header + 10 + size(header + 6, syncSafe: true)
        try #require(end <= data.count)
        var offset = header + 10
        var payloads: [Data] = []
        while offset + 10 <= end, data[offset] != 0 {
            let length = size(offset + 4, syncSafe: version == 4)
            try #require(length > 0 && length <= end - offset - 10)
            if Data(data[offset..<(offset + 4)]) == Data(frameID.utf8) {
                payloads.append(Data(data[(offset + 10)..<(offset + 10 + length)]))
            }
            offset += 10 + length
        }
        return payloads
    }

    @Test func basicTitleEditPreservesNativeCommentAndLyricLanguages() throws {
        for ext in ["mp3", "wav", "tta"] {
            try withFixture(ext) { url in
                let comments = [
                    StructuredComment(language: "deu", description: "review", text: "Kommentar"),
                    StructuredComment(language: "fra", description: "notes", text: "Commentaire")
                ]
                let lyrics = [
                    StructuredLyrics(language: "deu", description: "review", text: "Liedtext"),
                    StructuredLyrics(language: "fra", description: "notes", text: "Paroles")
                ]
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(lyrics: lyrics, comments: comments), to: url
                )
                let before = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
                #expect(Set(before.comments) == Set(comments))
                #expect(Set(before.lyrics) == Set(lyrics))
                let nativeComments = try id3FramePayloads(at: url, frameID: "COMM")
                let nativeLyrics = try id3FramePayloads(at: url, frameID: "USLT")
                #expect(nativeComments.count == 2)
                #expect(nativeLyrics.count == 2)
                #expect(nativeLyrics.map { String(decoding: $0[1..<4], as: UTF8.self) } == ["deu", "fra"])
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated title" }
                let after = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
                #expect(Set(after.comments) == Set(comments))
                #expect(Set(after.lyrics) == Set(lyrics))
                #expect(try id3FramePayloads(at: url, frameID: "COMM") == nativeComments)
                #expect(try id3FramePayloads(at: url, frameID: "USLT") == nativeLyrics)

                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.lyrics = "Replacement" }
                let replaced = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
                #expect(replaced.lyrics.count == 1)
                #expect(replaced.lyrics.first?.text == "Replacement")
                #expect(Set(replaced.comments) == Set(comments))
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.lyrics = "" }
                #expect(try id3FramePayloads(at: url, frameID: "USLT").isEmpty)
            }
        }
    }

    @Test func basicUnrelatedEditPreservesDateArraysAndYearAlias() throws {
        for dateFields in [
            ["DATE": ["2021-07-15", "2022-08-16"]],
            ["DATE": ["2021-07-15"], "YEAR": ["2021"]]
        ] {
            for ext in ["mp3", "flac", "ogg"] {
                try withFixture(ext) { url in
                    try TagLibMetadataManager.applyRawMetadataPatch(RawMetadataPatch(valuesToSet: dateFields), to: url)
                    try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
                    let raw = try TagLibMetadataManager.rawMetadataResult(from: url)
                    for (key, expected) in dateFields {
                        #expect(raw.properties.first { $0.key == key }?.values == expected)
                    }
                    try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.year = "" }
                    #expect(try TagLibMetadataManager.readMetadataResult(from: url).year.isEmpty)
                }
            }
        }
    }

    @Test func basicCustomEmptyValueExplicitlyDeletesField() throws {
        for ext in ["mp3", "m4a", "flac", "ogg", "wma", "wv", "tta", "aac"] {
            try withFixture(ext) { url in
                var seed = BasicMetadata.empty
                seed.customFields = ["REVIEW_CUSTOM": "Delete me", "KEEP_CUSTOM": "Keep me"]
                try TagLibMetadataManager.replaceBasicMetadata(seed, to: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).customFields["REVIEW_CUSTOM"] == "Delete me")
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.customFields["REVIEW_CUSTOM"] = "" }
                let after = try TagLibMetadataManager.readMetadataResult(from: url)
                #expect(after.customFields["REVIEW_CUSTOM"] == nil)
                #expect(after.customFields["KEEP_CUSTOM"] == "Keep me")
            }
        }
    }

    @Test func rawMergeAcceptsCaseInsensitiveKeys() throws {
        try withFixture("flac") { url in
            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                ["TITLE": ["Old"], "ARTIST": ["Keep"]], to: url
            )
            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                ["title": ["New"]], to: url, mode: .merge
            )
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "New")
            try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                ["title": ""], to: url, mode: .merge
            )
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).title.isEmpty)
            let before = try Data(contentsOf: url)
            #expect(throws: RawMetadataPatchError.self) {
                try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                    ["TITLE": ["One"], "title": ["Two"]], to: url, mode: .merge
                )
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test func nativeFailureRetainsStructuredCauseAndRollsBack() throws {
        try withFixture("mp3") { url in
            let before = try Data(contentsOf: url)
            do {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(id3v2Frames: [
                        .init(frameID: "BAD", type: "text", value: "Invalid")
                    ]), to: url
                )
                Issue.record("Expected native payload validation failure")
            } catch let error as TagLibManagerError {
                let underlying = try #require(error.underlyingError)
                #expect(underlying.domain == "TagLibMetadataExtractor")
                #expect(underlying.code == 243)
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test func opaqueID3FramesCannotReportSuccessfulPayloadEdits() throws {
        try withFixture("mp3") { url in
            try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url)
            let audio = try Data(contentsOf: url)
            // Independently construct one valid v2.4 opaque frame.
            let header = Data([0x49, 0x44, 0x33, 4, 0, 0, 0, 0, 0, 13])
            let frame = Data("XZZZ".utf8) + Data([0, 0, 0, 3, 0, 0, 1, 2, 3])
            try (header + frame + audio).write(to: url)
            #expect(try id3FramePayloads(at: url, frameID: "XZZZ") == [Data([1, 2, 3])])
            let before = try Data(contentsOf: url)
            var opaque = try #require(
                TagLibMetadataManager.readStructuredMetadataResult(from: url).id3v2Frames.first { $0.frameID == "XZZZ" }
            )
            #expect(opaque.type == "unknown")
            opaque.data = Data([4, 5, 6])
            #expect(throws: MetadataValidationError.self) {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(id3v2Frames: [opaque]), to: url
                )
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test func bridgeModelWritesRejectEmbeddedNullsWithoutVerification() throws {
        for configure in [
            { (metadata: TagLibAudioMetadata) in metadata.title = "Before\0After" },
            { (metadata: TagLibAudioMetadata) in metadata.musicBrainzArtistId = "Before\0After" },
            { (metadata: TagLibAudioMetadata) in metadata.customFields = ["REVIEW": "Before\0After"] }
        ] {
            try withFixture("mp3") { url in
                let before = try Data(contentsOf: url)
                let metadata = TagLibAudioMetadata()
                configure(metadata)
                do {
                    try TagLibMetadataManager.writeTagMetadata(metadata, to: url)
                    Issue.record("Expected null validation failure")
                } catch let error as TagLibManagerError {
                    #expect(error.underlyingError?.domain == "TagLibMetadataExtractor")
                    #expect(error.underlyingError?.code == 245)
                }
                #expect(try Data(contentsOf: url) == before)
                #expect(throws: NSError.self) {
                    try TagLibMetadataExtractor.writeMetadata(metadata, to: url)
                }
                #expect(try Data(contentsOf: url) == before)
            }
        }
    }

    @Test func basicMIMECorrectionPreservesPictureDescription() throws {
        try withFixture("flac") { url in
            let data = try coverData()
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(artwork: [
                    StructuredArtwork(container: "", pictureType: "Front Cover", pictureTypeCode: 3,
                                      mimeType: "image/png", description: "Original cover caption", data: data)
                ]), to: url
            )
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.artworkMIMEType = "image/jpeg" }
            let after = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
            #expect(after.artwork.first?.description == "Original cover caption")
            #expect(after.artwork.first?.mimeType == "image/jpeg")
            #expect(after.artwork.first?.data == data)
        }
    }

    @Test func structuredPropertyEditsPreserveOmittedArtwork() throws {
        let data = try coverData()
        for ext in ["wv", "wma"] {
            try withFixture(ext) { url in
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(artwork: [
                        StructuredArtwork(container: "", mimeType: "image/jpeg", data: data)
                    ]),
                    to: url
                )
                // Inspect the persisted picture bytes independently of the package reader.
                #expect(try Data(contentsOf: url).range(of: data) != nil)
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(properties: [.init(key: "TITLE", values: ["Property edit"])]),
                    to: url,
                    includeProperties: true
                )
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "Property edit")
                #expect(try Data(contentsOf: url).range(of: data) != nil, "\(ext) lost omitted artwork")
                #expect(try TagLibMetadataManager.readStructuredMetadataResult(from: url).artwork.first?.data == data)
            }
        }
    }

    @Test func emptyStructuredWritePreservesArtworkButExplicitRemovalClearsIt() throws {
        let data = try coverData()
        for ext in ["wv", "wma"] {
            try withFixture(ext) { url in
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(artwork: .replace([
                        StructuredArtwork(container: "", mimeType: "image/jpeg", data: data)
                    ])),
                    to: url
                )
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(StructuredMetadata(), to: url)
                #expect(try Data(contentsOf: url).range(of: data) != nil, "\(ext) lost omitted artwork")
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(), to: url, replacingCollections: [.artwork]
                )
                #expect(try Data(contentsOf: url).range(of: data) == nil)
                #expect(try TagLibMetadataManager.readStructuredMetadataResult(from: url).artwork.isEmpty)
            }
        }
    }
}
