import Foundation
import Testing
import TagLibAudioMetadata

struct FLACSemanticLifecycleTests {
    struct Case: Sendable {
        let field: MetadataFieldKey
        let key: String
        init(_ field: MetadataFieldKey, _ key: String) { self.field = field; self.key = key }
    }
    static let cases: [Case] = [
        .init(.title, "TITLE"), .init(.artist, "ARTIST"), .init(.album, "ALBUM"),
        .init(.albumArtist, "ALBUMARTIST"), .init(.composer, "COMPOSER"), .init(.genre, "GENRE"),
        .init(.comment, "COMMENT"), .init(.lyrics, "LYRICS"), .init(.year, "YEAR"),
        .init(.standaloneDate, "DATE"), .init(.releaseDate, "RELEASEDATE"), .init(.originalReleaseDate, "ORIGINALDATE"),
        .init(.grouping, "GROUPING"), .init(.contentGroup, "CONTENTGROUP"), .init(.work, "WORK"),
        .init(.publisher, "LABEL"), .init(.copyright, "COPYRIGHT"), .init(.isrc, "ISRC"),
        .init(.barcode, "BARCODE"), .init(.catalogNumber, "CATALOGNUMBER"), .init(.language, "LANGUAGE"),
        .init(.producer, "PRODUCER"), .init(.engineer, "ENGINEER"), .init(.lyricist, "LYRICIST"),
        .init(.remixer, "REMIXER"), .init(.conductor, "CONDUCTOR"),
        .init(.encodedBy, "ENCODEDBY"), .init(.encoderSettings, "ENCODING"),
        .init(.musicBrainzAlbumID, "MUSICBRAINZ_ALBUMID"), .init(.musicBrainzTrackID, "MUSICBRAINZ_TRACKID")
    ]

    @Test(arguments: cases, SemanticLifecycleMatrixTests.Operation.allCases)
    func independentCommentLifecycle(_ item: Case, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        try HardeningFixture.withCopy("flac", name: "testAudioFile") { url in
            let dates: Set<MetadataFieldKey> = [.year, .standaloneDate, .releaseDate, .originalReleaseDate]
            let old = dates.contains(item.field) ? "2004-03-04" : "Original"
            let value = dates.contains(item.field) ? "2017-06-09" : "Replacement"
            let initial: [String: [String]] = operation == .set ? [:] : [item.key: [old]]
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: initial.merging([
                "X-PRESERVE": ["A; B", "duplicate", "duplicate", "  padded  "]
            ]) { _, new in new }, removingKeys: operation == .set ? [item.key] : []), to: url)
            let before = try IndependentFLACProbe.read(url)
            let patch: MetadataPatchValue = operation == .remove ? .remove : .text(value)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: patch]), to: url)
            let after = try IndependentFLACProbe.read(url)
            #expect(after.comments[item.key] == (operation == .remove ? nil : [value]), "\(item.field) \(operation)")
            #expect(after.comments.filter { $0.key != item.key } == before.comments.filter { $0.key != item.key })
            #expect(after.otherBlocks == before.otherBlocks)
            #expect(after.audio == before.audio)
        }
    }
}
