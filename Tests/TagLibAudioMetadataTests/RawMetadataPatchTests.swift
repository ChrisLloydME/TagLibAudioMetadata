import Foundation
import XCTest
@testable import TagLibAudioMetadata

final class RawMetadataPatchTests: XCTestCase {
    func testLyricsDeltaPreservesAdversarialFLACCommentsUsingStructuralOracle() throws {
        let url = try fixtureCopy()
        let adversarial = ["Symphony; Live Version", "duplicate", "duplicate", "  spaced  ", "e\u{301}"]
        try TagLibMetadataManager.applyRawMetadataPatch(
            RawMetadataPatch(valuesToSet: ["CUSTOM": adversarial, "ARTIST": ["First", "Second"]]), to: url
        )
        let before = try flacComments(url)
        XCTAssertEqual(before["CUSTOM"], adversarial)
        XCTAssertEqual(before["ARTIST"], ["First", "Second"])
        try TagLibMetadataManager.applyRawMetadataPatch(
            RawMetadataPatch(valuesToSet: ["LYRICS": ["[00:01.00] New lyrics"]]), to: url
        )
        var expected = before
        expected["LYRICS"] = ["[00:01.00] New lyrics"]
        XCTAssertEqual(try flacComments(url), expected)
        try TagLibMetadataManager.applyRawMetadataPatch(RawMetadataPatch(removingKeys: ["LYRICS"]), to: url)
        expected.removeValue(forKey: "LYRICS")
        XCTAssertEqual(try flacComments(url), expected)
    }

    func testEmptyValueThatTagLibDropsFailsBeforeCommit() throws {
        let url = try fixtureCopy()
        let original = try Data(contentsOf: url)
        XCTAssertThrowsError(try TagLibMetadataManager.applyRawMetadataPatch(
            RawMetadataPatch(valuesToSet: ["CUSTOM": ["kept", "", "kept"]]), to: url
        )) { error in
            guard case TagLibManagerError.verificationFailed = error else {
                return XCTFail("Expected exact-value verification failure, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testUnrepresentableKeyFailsWithoutCommittingOrLeavingTemporaryCopy() throws {
        let url = try fixtureCopy()
        let original = try Data(contentsOf: url)
        XCTAssertThrowsError(try TagLibMetadataManager.applyRawMetadataPatch(
            RawMetadataPatch(valuesToSet: ["INVALID=KEY": ["value"]]), to: url
        ))
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path), [url.lastPathComponent])
    }

    // Independent of TagLib and its projections: parse FLAC block lengths and
    // little-endian Vorbis-comment entries directly from the committed bytes.
    private func flacComments(_ url: URL) throws -> [String: [String]] {
        let bytes = [UInt8](try Data(contentsOf: url))
        XCTAssertEqual(Array(bytes.prefix(4)), Array("fLaC".utf8))
        var offset = 4
        while offset + 4 <= bytes.count {
            let kind = bytes[offset] & 0x7f
            let last = bytes[offset] & 0x80 != 0
            let length = Int(bytes[offset + 1]) << 16 | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
            offset += 4
            let end = offset + length
            guard end <= bytes.count else { throw OracleError.malformed }
            if kind == 4 {
                var cursor = offset
                func integer() throws -> Int {
                    guard cursor + 4 <= end else { throw OracleError.malformed }
                    defer { cursor += 4 }
                    return (0..<4).reduce(0) { $0 | Int(bytes[cursor + $1]) << ($1 * 8) }
                }
                func string() throws -> String {
                    let count = try integer()
                    guard count <= end - cursor else { throw OracleError.malformed }
                    defer { cursor += count }
                    guard let value = String(bytes: bytes[cursor..<(cursor + count)], encoding: .utf8) else { throw OracleError.malformed }
                    return value
                }
                _ = try string() // vendor
                let count = try integer()
                var result: [String: [String]] = [:]
                for _ in 0..<count {
                    let entry = try string()
                    guard let separator = entry.firstIndex(of: "=") else { throw OracleError.malformed }
                    result[String(entry[..<separator]).uppercased(), default: []].append(String(entry[entry.index(after: separator)...]))
                }
                return result
            }
            if last { break }
            offset = end
        }
        throw OracleError.malformed
    }

    private func fixtureCopy() throws -> URL {
        let source = try XCTUnwrap(Bundle.module.url(forResource: "testAudioFile", withExtension: "flac", subdirectory: "Audio")
            ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "flac"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("RawPatch-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("audio.flac")
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    private enum OracleError: Error { case malformed }
}
