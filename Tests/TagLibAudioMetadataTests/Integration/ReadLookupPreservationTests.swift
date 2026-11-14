import Foundation
import XCTest
import CTagLibBridge
@testable import TagLibAudioMetadata

final class ReadLookupPreservationTests: XCTestCase {
    func testTransactionReadabilityMatchesFullReaderAcrossFixtures() throws {
        for ext in ["mp3", "m4a", "flac", "aac", "ogg", "oga", "wav", "wma", "xm", "tta", "wv"] {
            let url = try XCTUnwrap(Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext))
            let before = try Data(contentsOf: url)
            let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertFalse(metadata.format.isEmpty, ext)
            XCTAssertNoThrow(try MetadataProjectionReader.validateReadableAudioFile(at: url), ext)
            XCTAssertEqual(try Data(contentsOf: url), before, ext)
        }
    }

    func testTransactionReadabilityRejectsInvalidFilesBeforeMutation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReadabilityPreflight-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let mp4 = try XCTUnwrap(Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a", subdirectory: "Audio")
            ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a"))
        for (name, data) in [("empty.mp3", Data()), ("corrupt.flac", Data("not FLAC audio".utf8)),
                             ("wrong-parser.mp3", try Data(contentsOf: mp4))] {
            let url = directory.appendingPathComponent(name)
            try data.write(to: url)
            XCTAssertThrowsError(try TagLibMetadataManager.readMetadataResult(from: url), name)
            XCTAssertThrowsError(try MetadataProjectionReader.validateReadableAudioFile(at: url), name)
            var entered = false
            XCTAssertThrowsError(try MetadataFileTransaction.withAtomicFileMutation(at: url) { _ in entered = true }, name)
            XCTAssertFalse(entered, name)
            XCTAssertEqual(try Data(contentsOf: url), data, name)
            XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.contains(".taglib-") })
        }
    }

    private func entry(_ key: String, _ values: [String]) -> RawPropertyEntry {
        .init(key: key, value: values.joined(separator: "; "), values: values, count: values.count)
    }

    func testRawLookupPreservesFirstIdentityEmptyArraysAndText() {
        let raw = RawMetadataDump(properties: [
            entry("year", []), entry("YEAR", ["must not replace the first owner"]),
            entry("date", [" 2008-03-04 ", "not-a-date", "not-a-date"]),
            entry("releasedate", ["2017-06-09"]), entry("RELEASEDATE", ["must not win"]),
            entry("ORIGINALDATE", ["  original text  "]),
            entry("custom-keep", [" A ", "B", "B"]), entry("CUSTOM-KEEP", ["must not win"]),
            entry("custom-empty", [])
        ], id3v2Frames: [])
        let bridge = TagLibAudioMetadata()
        bridge.customFields = ["CUSTOM-KEEP": " A ; B; B", "CUSTOM-EMPTY": "scalar fallback"]
        let metadata = TagLibMetadataManager.basicMetadata(fromBridgeMetadata: bridge, rawDump: raw, fileExtension: "flac")
        XCTAssertEqual(metadata.customFieldValues["CUSTOM-KEEP"], [" A ", "B", "B"])
        XCTAssertEqual(metadata.customFieldValues["CUSTOM-EMPTY"], ["scalar fallback"])
        XCTAssertEqual(metadata.year, "")
        XCTAssertEqual(metadata.date, " 2008-03-04 ")
        XCTAssertEqual(metadata.releaseDate, "2017-06-09")
        XCTAssertEqual(metadata.originalReleaseDate, "  original text  ")
        XCTAssertEqual(raw.properties[2].values, [" 2008-03-04 ", "not-a-date", "not-a-date"])
    }

    func testUnicodeLookupRetainsFoundationCaseComparison() {
        let raw = RawMetadataDump(properties: [
            entry("releaſedate", ["Unicode owner"]), entry("releasedate", ["ASCII owner"]),
            entry("custom-歌曲", [" unchanged ", "duplicate", "duplicate"])
        ], id3v2Frames: [])
        let bridge = TagLibAudioMetadata()
        bridge.customFields = ["CUSTOM-歌曲": "scalar"]
        let expected = raw.properties.first { $0.key.caseInsensitiveCompare("RELEASEDATE") == .orderedSame }?.values.first
        let metadata = TagLibMetadataManager.basicMetadata(fromBridgeMetadata: TagLibAudioMetadata(), rawDump: raw, fileExtension: "flac")
        let custom = TagLibMetadataManager.basicMetadata(fromBridgeMetadata: bridge, rawDump: raw, fileExtension: "flac")
        XCTAssertEqual(custom.customFieldValues["CUSTOM-歌曲"], [" unchanged ", "duplicate", "duplicate"])
        XCTAssertEqual(metadata.releaseDate, expected)
    }

    func testMP4LookupKeepsExactKeysFirstArraysAndFreshReadState() {
        var structured = StructuredMetadata(mp4Atoms: [
            .init(key: "©DAY", type: "stringList", values: ["case is significant"]),
            .init(key: "©day", type: "stringList", values: [" 2004 ", "2005", "2005"]),
            .init(key: "©day", type: "stringList", values: ["must not win"])
        ])
        let before = TagLibMetadataManager.basicMetadata(fromBridgeMetadata: TagLibAudioMetadata(), rawDump: .empty, fileExtension: "m4a", structured: structured)
        XCTAssertEqual(before.year, " 2004 ; 2005; 2005")
        structured.mp4Atoms[1].values = ["2017"]
        let after = TagLibMetadataManager.basicMetadata(fromBridgeMetadata: TagLibAudioMetadata(), rawDump: .empty, fileExtension: "m4a", structured: structured)
        XCTAssertEqual(after.year, "2017")
        XCTAssertEqual(before.year, " 2004 ; 2005; 2005")
    }
}
