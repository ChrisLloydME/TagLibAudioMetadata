import Foundation
import ObjectiveC
import XCTest
import CTagLibBridge
@testable import TagLibAudioMetadata

final class SelectiveExtractionTests: XCTestCase {
    private let fixtures: [(String, String)] = [
        ("testAudioFile", "mp3"), ("testAudioFile", "m4a"), ("testAudioFile-alac", "m4a"),
        ("testAudioFile", "flac"), ("testAudioFile", "aac"), ("testAudioFile", "ogg"),
        ("testAudioFile", "oga"), ("synthetic", "opus"), ("testAudioFile", "wav"),
        ("info-only", "wav"), ("clean-room", "aiff"), ("testAudioFile", "wma"),
        ("testAudioFile", "tta"), ("testAudioFile", "wv"), ("hardening", "ape"),
        ("hardening", "mpc"), ("hardening", "dsf"), ("hardening", "dff"), ("testAudioFile", "xm")
    ]

    private func fixture(_ name: String, _ ext: String) throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Audio")
            ?? Bundle.module.url(forResource: name, withExtension: ext))
    }

    /// Enumerate every declared carrier property so a new Basic field cannot
    /// silently escape the selective/full comparison. NSObject state is excluded.
    private func basicValues(_ metadata: TagLibAudioMetadata) throws -> NSDictionary {
        var count: UInt32 = 0
        let properties = try XCTUnwrap(class_copyPropertyList(TagLibAudioMetadata.self, &count))
        defer { free(properties) }
        XCTAssertGreaterThan(count, 70)
        var result: [String: Any] = [:]
        for index in 0..<Int(count) {
            let key = String(cString: property_getName(properties[index]))
            result[key] = metadata.value(forKey: key) ?? NSNull()
        }
        return result as NSDictionary
    }

    private func checkAllOptions(_ url: URL) throws {
        let bytes = try Data(contentsOf: url)
        let full = try TagLibMetadataExtractor.metadataProjections(for: url)
        let basic = try basicValues(XCTUnwrap(full["basic"] as? TagLibAudioMetadata))
        let raw = try XCTUnwrap(full["raw"] as? NSDictionary)
        let structured = try XCTUnwrap(full["structured"] as? NSDictionary)
        for mask in UInt(0)..<32 {
            let views = try TagLibMetadataExtractor.metadataProjections(for: url, options: .init(rawValue: mask))
            let context = "\(url.lastPathComponent), option mask \(mask)"
            let wantsBasic = mask & 1 != 0
            let wantsRaw = mask & 2 != 0
            let wantsStructured = mask & 4 != 0
            let wantsMap = wantsRaw || wantsStructured || mask & 8 != 0
            let wantsFrames = wantsRaw || mask & 16 != 0
            var keys: Set<String> = []
            if wantsBasic {
                keys.insert("basic")
                XCTAssertEqual(try basicValues(XCTUnwrap(views["basic"] as? TagLibAudioMetadata)), basic, context)
            }
            if wantsRaw || mask & (8 | 16) != 0 {
                keys.insert("raw")
                let selectedRaw = try XCTUnwrap(views["raw"] as? NSDictionary)
                XCTAssertEqual(selectedRaw, ["properties": wantsMap ? raw["properties"]! : [],
                                             "id3v2Frames": wantsFrames ? raw["id3v2Frames"]! : []] as NSDictionary, context)
            }
            if wantsStructured {
                keys.insert("structured")
                XCTAssertEqual(views["structured"] as? NSDictionary, structured, context)
            }
            XCTAssertEqual(Set(views.keys), keys, context)
        }
        XCTAssertEqual(try basicValues(TagLibMetadataExtractor.extractMetadata(from: url)), basic)
        XCTAssertEqual(try TagLibMetadataExtractor.rawMetadata(for: url) as NSDictionary, raw)
        XCTAssertEqual(try TagLibMetadataExtractor.structuredMetadata(for: url) as NSDictionary, structured)
        XCTAssertEqual(try Data(contentsOf: url), bytes, "Every read must leave the entire file untouched")
    }

    func testSelectiveViewsMatchFullExtractionAcrossNativeFixtures() throws {
        for (name, ext) in fixtures { try checkAllOptions(fixture(name, ext)) }
    }

    func testRichSelectiveViewsPreserveNativeValuesAndArtwork() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SelectiveExtraction-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cover = try XCTUnwrap(Bundle.module.url(forResource: "testCover", withExtension: "jpg", subdirectory: "Artwork")
            ?? Bundle.module.url(forResource: "testCover", withExtension: "jpg"))
        var artwork = try Data(contentsOf: cover)
        artwork.append(Data(repeating: 0, count: 512 * 1024))
        for ext in ["mp3", "m4a", "flac"] {
            let url = directory.appendingPathComponent("rich.\(ext)")
            try FileManager.default.copyItem(at: fixture("testAudioFile", ext), to: url)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [
                .title: .text("Selective title"), .artist: .text("Artist"), .year: .text("2004"),
                .standaloneDate: .text("2008-03-04"), .releaseDate: .text("2017-06-09"),
                .originalReleaseDate: .text("1999"), .encodedBy: .text("Person"), .encoderSettings: .text("Encoder"),
                .contentGroup: .text("Content"), .grouping: .text("Grouping"), .work: .text("Work")
            ], customFields: ["PROJECTION_KEEP": .values([" padded ", "duplicate", "duplicate"])],
               explicitAdvisory: .notExplicit,
               artwork: .replace([.init(mimeType: "image/jpeg", data: artwork)])), to: url)
            let full = try TagLibMetadataExtractor.extractMetadata(from: url)
            XCTAssertEqual(full.year, "2004")
            XCTAssertEqual(full.standaloneDate, "2008-03-04")
            XCTAssertEqual(full.artworkData, artwork)
            try checkAllOptions(url)
        }
    }

    func testValidationOnlyRejectsInvalidInputsWithoutMutation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ValidationOnly-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cases = [("empty.mp3", Data()), ("corrupt.flac", Data("not a FLAC".utf8)),
                     ("wrong.mp3", try Data(contentsOf: fixture("testAudioFile", "m4a"))),
                     ("unsupported.txt", Data("audio".utf8))]
        for (name, data) in cases {
            let url = directory.appendingPathComponent(name)
            try data.write(to: url)
            XCTAssertThrowsError(try TagLibMetadataExtractor.metadataProjections(for: url, options: .init(rawValue: 0)), name)
            XCTAssertThrowsError(try MetadataProjectionReader.validateReadableAudioFile(at: url), name)
            let metadata = TagLibAudioMetadata()
            metadata.title = "Must not commit"
            XCTAssertThrowsError(try TagLibMetadataExtractor.writeMetadata(metadata, to: url), name)
            XCTAssertEqual(try Data(contentsOf: url), data, name)
        }
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)), Set(cases.map(\.0)))
    }
}
