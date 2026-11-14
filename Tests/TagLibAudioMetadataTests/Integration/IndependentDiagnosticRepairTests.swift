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
            let before = try LegacyID3DateEvidence.frames(at: url).sorted { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") } as NSArray
            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(snapshot.basic.year == "2004")
            #expect(snapshot.basic.date == "0906")
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Edited" }
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "Edited")
            let after = try LegacyID3DateEvidence.frames(at: url).sorted { ($0["id"] as? String ?? "") < ($1["id"] as? String ?? "") } as NSArray
            #expect(after == before, "before=\(before) after=\(after)")
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
        }
    }
    @Test func typedASFAdvisoryPersistsNativeAttribute() throws {
        try Self.withCopy("wma") { url in
            for state in [ExplicitAdvisory.explicit, .clean, .notExplicit, .unspecified] {
                try TagLibMetadataManager.applyMetadataPatch(.init(explicitAdvisory: state), to: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).explicitAdvisory == state)
            }
        }
    }
    @Test func versionedTextWritesAndRemovalsVerify() throws {
        for v3 in [false, true] {
            try Self.withCopy("mp3") { url in
                if v3 { try Self.legacy(url) }
                let frame = StructuredID3v2Frame(frameID: "TDRC", type: "versionedText", values: ["2011"], v23ID: "TYER", v24ID: "TDRC")
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: [frame]), to: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).year == "2011")
            }
        }
    }
}
