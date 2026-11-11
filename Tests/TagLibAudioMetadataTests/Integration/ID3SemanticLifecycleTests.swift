import Foundation
import Testing
import TagLibAudioMetadata

struct ID3SemanticLifecycleTests {
    struct Case: Sendable {
        let field: MetadataFieldKey
        let frame: String
        init(_ field: MetadataFieldKey, _ frame: String) { self.field = field; self.frame = frame }
    }
    static let cases: [Case] = [
        .init(.title, "TIT2"), .init(.artist, "TPE1"), .init(.album, "TALB"),
        .init(.albumArtist, "TPE2"), .init(.composer, "TCOM"), .init(.genre, "TCON"),
        .init(.year, "TDRC"), .init(.standaloneDate, "TXXX:DATE"),
        .init(.releaseDate, "TDRL"), .init(.originalReleaseDate, "TDOR"),
        .init(.grouping, "GRP1"), .init(.contentGroup, "TIT1"), .init(.work, "TXXX:WORK"),
        .init(.subtitle, "TIT3"), .init(.discSubtitle, "TSST"), .init(.conductor, "TPE3"),
        .init(.remixer, "TPE4"), .init(.publisher, "TPUB"), .init(.copyright, "TCOP"), .init(.isrc, "TSRC")
    ]

    @Test(arguments: cases, SemanticLifecycleMatrixTests.Operation.allCases)
    func nativeFrameLifecyclePreservesOtherFramesAndAudio(_ item: Case, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
            let original = try IndependentID3Probe.read(url)
            let date: Set<MetadataFieldKey> = [.year, .standaloneDate, .releaseDate, .originalReleaseDate]
            let old = date.contains(item.field) ? "2004-03-04" : "Original"
            let value = date.contains(item.field) ? "2017-06-09" : "Replacement"
            var frames = HardeningFixture.frame("TXXX", Data([3]) + Data("X-KEEP\0Untouched".utf8))
            if operation != .set {
                let parts = item.frame.split(separator: ":", maxSplits: 1).map(String.init)
                let payload = parts.count == 2 ? parts[1] + "\0" + old : old
                frames += HardeningFixture.frame(parts[0], Data([3]) + Data(payload.utf8))
            }
            try (HardeningFixture.id3(frames) + original.audio).write(to: url)
            let before = try IndependentID3Probe.read(url)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [
                item.field: operation == .remove ? .remove : .text(value)
            ]), to: url)
            let after = try IndependentID3Probe.read(url)
            #expect(after.texts[item.frame] == (operation == .remove ? nil : [value]), "\(item.field) \(operation)")
            #expect(after.frames.filter { $0.key != item.frame } == before.frames.filter { $0.key != item.frame })
            #expect(after.audio == before.audio)
        }
    }
}
