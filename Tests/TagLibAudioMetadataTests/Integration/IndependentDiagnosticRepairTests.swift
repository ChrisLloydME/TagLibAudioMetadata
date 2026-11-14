import Foundation
import Testing
import CTagLibBridge
@testable import TagLibAudioMetadata

struct IndependentDiagnosticRepairTests {
    static func withCopy(_ ext: String, _ body: (URL) throws -> Void) throws {
        let source = try #require(Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
            ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DiagnosticRepair-\(UUID()).\(ext)")
        defer { try? FileManager.default.removeItem(at: url) }
        try FileManager.default.copyItem(at: source, to: url)
        try body(url)
    }
    static func legacy(_ url: URL) throws {
        var audio = try Data(contentsOf: url)
        if audio.starts(with: Data("ID3".utf8)) {
            let n = audio[6..<10].reduce(0) { ($0 << 7) | Int($1) }
            audio = Data(audio.dropFirst(10 + n))
        }
        func frame(_ id: String, _ value: String) -> Data {
            let payload = Data([0]) + Data(value.utf8)
            return Data(id.utf8) + HardeningFixture.number(UInt64(payload.count), bytes: 4) + Data([0,0]) + payload
        }
        let frames = frame("TYER", "2004") + frame("TDAT", "0906") + frame("TORY", "1999")
        let size = frames.count
        let header = Data([73,68,51,3,0,0,UInt8((size >> 21)&127),UInt8((size >> 14)&127),UInt8((size >> 7)&127),UInt8(size&127)])
        try (header + frames + audio).write(to: url)
    }
    @Test func legacyDatesAreIndependentAndBasicEditsPreserveThem() throws {
        try Self.withCopy("mp3") { url in
            try Self.legacy(url)
            let before = try IndependentLegacyID3DateProbe.frames(at: url).sorted { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") } as NSArray
            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(snapshot.basic.year == "2004")
            #expect(snapshot.basic.date == "0906")
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Edited" }
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "Edited")
            let after = try IndependentLegacyID3DateProbe.frames(at: url).sorted { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") } as NSArray
            #expect(after == before, "before=\(before) after=\(after)")
        }
    }
    @Test(arguments: [UInt8(0x20), 0x40, 0x80, 0xc0])
    func legacyDateFlagsRetainLiteralOwners(_ flags: UInt8) throws {
        try Self.withCopy("mp3") { url in
            try Self.legacy(url)
            let original = try Data(contentsOf: url)
            let length = original[6..<10].reduce(0) { ($0 << 7) | Int($1) }
            var body = Data(original[10..<(10 + length)])
            if flags & 0x80 != 0 {
                body = Data("XZZZ".utf8) + Data([0,0,0,2,0,0,0xff,0,0xe0]) + body
            }
            if flags & 0x40 != 0 { body = Data([0,0,0,6,0,0,0,0,0,0]) + body }
            let n = body.count
            let header = Data([73,68,51,3,0,flags,UInt8((n >> 21)&127),UInt8((n >> 14)&127),UInt8((n >> 7)&127),UInt8(n&127)])
            let bytes = header + body + original.dropFirst(10 + length)
            try bytes.write(to: url)
            let metadata = try TagLibMetadataManager.readSnapshot(from: url).basic
            #expect(metadata.year == "2004")
            #expect(metadata.date == "0906")
            #expect(try Data(contentsOf: url) == bytes)
        }
    }
    @Test func basicClearArtworkRemovesNativeCollections() throws {
        let image = try #require(Bundle.module.url(forResource: "testCover", withExtension: "jpg", subdirectory: "Artwork")
            ?? Bundle.module.url(forResource: "testCover", withExtension: "jpg"))
        for ext in ["mp3", "m4a", "flac", "wma"] {
            try Self.withCopy(ext) { url in
                try TagLibMetadataManager.applyMetadataPatch(.init(artwork: .replace([.init(mimeType: "image/jpeg", data: Data(contentsOf: image))])), to: url)
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.artworkData = nil; $0.artworkMIMEType = nil }
                #expect(try TagLibMetadataManager.readSnapshot(from: url).structured.artwork.isEmpty)
            }
        }
    }
    @Test func movementAndReleaseOwnersAgreeAcrossEntrypoints() throws {
        try Self.withCopy("m4a") { url in
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.movement: .text("Typed")]), to: url)
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "----:com.apple.iTunes:MOVEMENT", type: "stringList", values: ["Legacy"])
            ]), to: url)
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).movement == "Typed")
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.movement = "Basic" }
            let atoms = try TagLibMetadataManager.readSnapshot(from: url).structured.mp4Atoms
            #expect(atoms.contains { $0.key == "©mvn" && $0.values == ["Basic"] })
            #expect(!atoms.contains { $0.key == "----:com.apple.iTunes:MOVEMENT" })
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.movement = "" }
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).movement.isEmpty)
        }
        try Self.withCopy("flac") { url in
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.releaseType: .text("album"), .releaseStatus: .text("official")]), to: url)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.releaseType = "single"; $0.releaseStatus = "promotion" }
            let bytes = try Data(contentsOf: url)
            #expect(bytes.range(of: Data("RELEASETYPE=single".utf8)) != nil)
            #expect(bytes.range(of: Data("RELEASESTATUS=promotion".utf8)) != nil)
            let metadata = TagLibAudioMetadata()
            metadata.releaseType = "album"
            metadata.releaseStatus = "official"
            metadata.movement = "Native movement"
            _ = try TagLibMetadataManager.writeTagMetadata(metadata, to: url)
            let native = try IndependentFLACProbe.read(url)
            #expect(native.comments["RELEASETYPE"] == ["album"])
            #expect(native.comments["RELEASESTATUS"] == ["official"])
            #expect(native.comments["MOVEMENTNAME"] == ["Native movement"])
            #expect(native.comments["MOVEMENT"] == nil)

        }
    }
    @Test func typedASFAdvisoryPersistsNativeAttribute() throws {
        try Self.withCopy("wma") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                .init(key: "AdViSoRy", type: "string", value: "1")
            ]), to: url)
            for state in [ExplicitAdvisory.explicit, .clean, .notExplicit, .unspecified] {
                try TagLibMetadataManager.applyMetadataPatch(.init(explicitAdvisory: state), to: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).explicitAdvisory == state)
            }
        }
    }
    @Test(arguments: ["mp3", "m4a", "flac", "aac", "ogg", "oga", "wav"])
    func basicMixedNumbersAndText(_ ext: String) throws {
        try Self.withCopy(ext) { url in
            var metadata = BasicMetadata.empty
            metadata.title = "Joint edit"
            metadata.track = 1; metadata.trackTotal = 10
            metadata.disc = 1; metadata.discTotal = 2
            metadata.trackNumberText = "01/10"; metadata.discNumberText = "01/02"
            try TagLibMetadataManager.replaceBasicMetadata(metadata, to: url)
            let after = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(after.basic.trackTotal == 10)
            #expect(after.basic.discTotal == 2)
            var cleared = BasicMetadata.empty
            cleared.trackNumberText = ""; cleared.discNumberText = ""
            try TagLibMetadataManager.replaceBasicMetadata(cleared, to: url)
            #expect(try TagLibMetadataManager.readSnapshot(from: url).basic.trackTotal == 0)
            #expect(try TagLibMetadataManager.readSnapshot(from: url).basic.discTotal == 0)
        }
    }
    @Test func lowLevelLegacyReplacementRejectsWithoutMutation() throws {
        try Self.withCopy("mp3") { url in
            try Self.legacy(url)
            let bytes = try Data(contentsOf: url)
            let metadata = TagLibAudioMetadata()
            metadata.title = "Unsafe replacement"
            metadata.year = "2004-11-22"
            #expect(throws: (any Error).self) { try TagLibMetadataManager.writeTagMetadata(metadata, to: url) }
            #expect(throws: (any Error).self) { try TagLibMetadataExtractor.writeMetadata(metadata, to: url) }
            #expect(try Data(contentsOf: url) == bytes)
        }
    }
    @Test func basicMusicBrainzUsesCanonicalUFIDAndClearsIt() throws {
        try Self.withCopy("mp3") { url in
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.musicBrainzTrackID: .text("11111111-1111-1111-1111-111111111111")]), to: url)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.musicBrainzTrackID = "22222222-2222-2222-2222-222222222222" }
            let bytes = try Data(contentsOf: url)
            #expect(bytes.range(of: Data("http://musicbrainz.org".utf8)) != nil)
            #expect(bytes.range(of: Data("MusicBrainz Track Id".utf8)) == nil)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.musicBrainzTrackID = "" }
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).musicBrainzTrackID.isEmpty)
        }
    }
    @Test func emptyStructuredWritesAndUnsupportedCollectionsDoNotCommit() throws {
        for ext in ["mp3", "m4a", "flac", "wma"] {
            try Self.withCopy(ext) { url in
                let bytes = try Data(contentsOf: url)
                let version = try TagLibMetadataManager.fileVersion(at: url)
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(), to: url, expectedVersion: version)
                #expect(try Data(contentsOf: url) == bytes)
                #expect(try TagLibMetadataManager.fileVersion(at: url) == version)
                if ["m4a", "wma"].contains(ext) {
                    #expect(throws: TagLibManagerError.self) {
                        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(), to: url, replacingCollections: [.comments])
                    }
                    #expect(try TagLibMetadataManager.fileVersion(at: url) == version)
                }
            }
        }
    }
    @Test func everyTransactionRejectsUnreadableStagedOutput() throws {
        try Self.withCopy("mp3") { url in
            let bytes = try Data(contentsOf: url)
            #expect(throws: (any Error).self) {
                try MetadataFileTransaction.withAtomicMetadataWriteMutation(at: url) { temporary in
                    try Data("corrupt output".utf8).write(to: temporary)
                    return .init(warnings: [])
                }
            }
            #expect(try Data(contentsOf: url) == bytes)
        }
    }
    struct MP4TextOwner: Sendable {
        let field: MetadataFieldKey
        let property: String
    }
    static let mp4TextOwners: [MP4TextOwner] = [
        .init(field: .albumArtist, property: "albumArtist"),
        .init(field: .composer, property: "composer"),
        .init(field: .sortTitle, property: "sortTitle"),
        .init(field: .sortArtist, property: "sortArtist"),
        .init(field: .sortAlbum, property: "sortAlbum"),
        .init(field: .sortAlbumArtist, property: "sortAlbumArtist"),
        .init(field: .sortComposer, property: "sortComposer"),
        .init(field: .conductor, property: "conductor"),
        .init(field: .encodedBy, property: "encodedBy"),
        .init(field: .encoderSettings, property: "encoderSettings"),
        .init(field: .copyright, property: "copyright"),
        .init(field: .contentGroup, property: "contentGroup"),
        .init(field: .movement, property: "movement"),
        .init(field: .publisher, property: "label"),
        .init(field: .work, property: "work"),
    ]
    @Test(arguments: Self.mp4TextOwners)
    func lowLevelMP4WritableTextOwnersMatchCatalog(_ entry: MP4TextOwner) throws {
        let field = entry.field, property = entry.property
        try Self.withCopy("m4a") { url in
            let before = try IndependentMP4Probe.read(url)
            let target = try #require(MetadataFieldRegistry.schema(for: field)?.writeTarget(for: .mp4))
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [field: .text("Typed")]), to: url)
            let metadata = TagLibAudioMetadata()
            metadata.setValue("Lowlevel", forKey: property)
            _ = try TagLibMetadataManager.writeTagMetadata(metadata, to: url)
            let native = try IndependentMP4Probe.read(url)
            #expect(native.values[target.nativeIdentity] == [Data("Lowlevel".utf8)], "\(field)")
            #expect(native.audio == before.audio)
        }
    }
    @Test func versionedTextWritesAndRemovalsVerify() throws {
        for v3 in [false, true] {
            try Self.withCopy("mp3") { url in
                if v3 { try Self.legacy(url) }
                var frame = StructuredID3v2Frame(frameID: "TDRC", type: "versionedText", values: ["2011"], v23ID: "TYER", v24ID: "TDRC")
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: [frame]), to: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).year == "2011")
                frame.values = []
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: [frame]), to: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).year.isEmpty)
                if !v3 {
                    let date = StructuredID3v2Frame(frameID: "TDAT", type: "versionedText", values: ["2017-06-09"], v23ID: "TDAT", v24Description: "DATE")
                    try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: [date]), to: url)
                    #expect(try TagLibMetadataManager.readMetadataResult(from: url).date == "2017-06-09")
                }
            }
        }
    }
}
