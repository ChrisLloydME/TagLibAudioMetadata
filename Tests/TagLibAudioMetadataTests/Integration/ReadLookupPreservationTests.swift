import Foundation
import XCTest
import CTagLibBridge
@testable import TagLibAudioMetadata

final class ReadLookupPreservationTests: XCTestCase {
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
