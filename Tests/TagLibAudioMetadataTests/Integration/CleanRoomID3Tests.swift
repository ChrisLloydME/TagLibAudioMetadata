import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

struct CleanRoomID3Tests {
    private func withFixture(_ ext: String, _ body: (URL) throws -> Void) throws {
        let name = ["dsf", "dff"].contains(ext) ? "hardening" : ext == "aiff" ? "clean-room" : "testAudioFile"
        try HardeningFixture.withCopy(ext, name: name, body)
    }

    private func frames(_ url: URL) throws -> [String: [Data]] {
        let data = try Data(contentsOf: url)
        // Saving an empty ID3 tag may remove the container entirely.
        guard let header = data.range(of: Data([73, 68, 51, 4, 0]))?.lowerBound else { return [:] }
        return try HardeningFixture.frames(Data(data[header...]))
    }

    private func text(_ frames: [String: [Data]], _ id: String) throws -> String {
        let payloads = try #require(frames[id])
        #expect(payloads.count == 1)
        let payload = try #require(payloads.first)
        let encoding = try #require(payload.first)
        #expect(encoding == 0 || encoding == 3)
        return try #require(String(data: payload.dropFirst(), encoding: encoding == 0 ? .isoLatin1 : .utf8))
    }

    @Test func nativeNumberPairsAcrossID3ContainersAndPublicWriters() throws {
        for ext in ["mp3", "aac", "wav", "aiff", "tta", "dsf", "dff"] {
            for operation in 0..<5 {
                try withFixture(ext) { url in
                    try TagLibMetadataManager.applyRawMetadataPatch(
                        RawMetadataPatch(valuesToSet: ["KEEP_CUSTOM": ["Untouched"]]), to: url)
                    switch operation {
                    case 0:
                        try TagLibMetadataManager.updateBasicMetadata(at: url) {
                            $0.track = 3; $0.trackTotal = 12; $0.disc = 1; $0.discTotal = 2
                            $0.movementNumber = 2; $0.movementCount = 4
                        }
                    case 1:
                        try TagLibMetadataManager.applyMetadataPatch(
                            MetadataPatch(fields: [.track: .integer(3), .trackTotal: .integer(12),
                                .disc: .integer(1), .discTotal: .integer(2),
                                .movementNumber: .integer(2), .movementCount: .integer(4)]), to: url)
                    case 2:
                        try TagLibMetadataManager.applyMetadataPatch(
                            MetadataPatch(numberText: .init(trackNumberText: "03/12", discNumberText: "01/02")), to: url)
                    case 3:
                        try TagLibMetadataManager.writeTrackNumberText("03/12", discNumberText: "01/02", to: url)
                    default:
                        try TagLibMetadataExtractor.writeTrackNumber(3, totalTracks: 12, padWidth: 2, to: url)
                    }
                    let native = try frames(url)
                    #expect(try text(native, "TRCK") == (operation < 2 ? "3/12" : "03/12"))
                    if operation != 4 {
                        #expect(try text(native, "TPOS") == (operation < 2 ? "1/2" : "01/02"))
                    }
                    if operation < 2 { #expect(try text(native, "MVIN") == "2/4") }
                    for payload in native["TXXX"] ?? [] {
                        let value = String(decoding: payload.dropFirst(), as: UTF8.self)
                        #expect(!value.hasPrefix("TRACKTOTAL\0"))
                        #expect(!value.hasPrefix("DISCTOTAL\0"))
                        #expect(!value.hasPrefix("MOVEMENTCOUNT\0"))
                    }
                    #expect(try TagLibMetadataManager.readMetadataResult(from: url).customFields["KEEP_CUSTOM"] == "Untouched")
                    let original = try Data(contentsOf: url)
                    #expect(throws: MetadataPatchValidationError.self) {
                        try TagLibMetadataManager.applyMetadataPatch(
                            MetadataPatch(fields: [.track: .remove]), to: url)
                    }
                    #expect(try Data(contentsOf: url) == original)
                }
            }
        }
    }

    @Test func qualifiedCommentAndLyricScalarPatchesOwnCompleteCollections() throws {
        for ext in ["mp3", "aac", "wav", "aiff", "tta", "dsf", "dff"] {
            try withFixture(ext) { url in
                let payload = HardeningFixture.id3(
                    HardeningFixture.frame("COMM", Data([3]) + Data("engNotes\0Old comment".utf8))
                    + HardeningFixture.frame("COMM", Data([3]) + Data("deuOther\0Second comment".utf8))
                    + HardeningFixture.frame("USLT", Data([3]) + Data("fraParoles\0Old lyrics".utf8)))
                if ["dsf", "dff"].contains(ext) {
                    try HardeningFixture.seedDSDTag(payload, at: url)
                } else {
                    try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                        StructuredMetadata(lyrics: [.init(language: "fra", description: "Paroles", text: "Old lyrics")],
                            comments: [.init(language: "eng", description: "Notes", text: "Old comment"),
                                       .init(language: "deu", description: "Other", text: "Second comment")]),
                        to: url, replacingCollections: [.comments, .lyrics])
                }
                let before = try TagLibMetadataManager.readMetadataResult(from: url)
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.comment: .text("New comment"), .lyrics: .text("New lyrics")]), to: url)
                let replaced = try frames(url)
                #expect(replaced["COMM"]?.count == 1)
                #expect(replaced["USLT"]?.count == 1)
                let basic = try TagLibMetadataManager.readMetadataResult(from: url)
                #expect(basic.comment == "New comment")
                #expect(basic.lyrics == "New lyrics")
                #expect(basic.title == before.title)
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.comment: .remove, .lyrics: .remove]), to: url)
                let removed = try frames(url)
                #expect(removed["COMM"] == nil)
                #expect(removed["USLT"] == nil)
                let after = try TagLibMetadataManager.readMetadataResult(from: url)
                #expect(after.comment.isEmpty && after.lyrics.isEmpty)
            }
        }
    }

    @Test func aacBasicEditPreservesNativeLanguagesAndDescriptions() throws {
        try withFixture("aac") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(lyrics: [.init(language: "fra", description: "Paroles", text: "Native lyrics")],
                    comments: [.init(language: "eng", description: "Notes", text: "Native comment")]),
                to: url, replacingCollections: [.comments, .lyrics])
            let before = try frames(url)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated title" }
            let after = try frames(url)
            #expect(after["COMM"] == before["COMM"])
            #expect(after["USLT"] == before["USLT"])
            #expect(TagLibMetadataManager.capability(forExtension: "aac")?.metadataFieldFormats.contains(.id3v2) == true)
        }
    }
}
