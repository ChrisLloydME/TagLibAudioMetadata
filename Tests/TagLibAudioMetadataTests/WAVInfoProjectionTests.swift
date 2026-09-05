import Foundation
import XCTest
@testable import TagLibAudioMetadata

final class WAVInfoProjectionTests: XCTestCase {
    func testAddingID3TrackDoesNotHideOrRewriteExistingRIFFInfo() throws {
        let source = try XCTUnwrap(Bundle.module.url(forResource: "info-only", withExtension: "wav", subdirectory: "Audio")
            ?? Bundle.module.url(forResource: "info-only", withExtension: "wav"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WAVInfo-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("audio.wav")
        try FileManager.default.copyItem(at: source, to: url)
        let info = try infoChunks(Data(contentsOf: url))
        XCTAssertFalse(info.isEmpty)
        let before = try TagLibMetadataManager.readSnapshot(from: url)
        let encoding = try XCTUnwrap(before.raw.properties.first { $0.key == "ENCODING" }?.values)
        XCTAssertFalse(encoding.isEmpty)
        try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields: [.track: .integer(3)]), to: url)
        let after = try TagLibMetadataManager.readSnapshot(from: url)
        XCTAssertEqual(after.basic.track, 3)
        XCTAssertEqual(after.raw.properties.first { $0.key == "ENCODING" }?.values, encoding)
        XCTAssertEqual(try infoChunks(Data(contentsOf: url)), info, "Independent RIFF chunk bytes must remain unchanged.")
        try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields: [.title: .text("Title only")]), to: url)
        XCTAssertEqual(try infoChunks(Data(contentsOf: url)), info, "A text delta must not rebuild unrelated INFO metadata.")
    }

    private func infoChunks(_ data: Data) throws -> [Data] {
        guard data.count >= 12, data.prefix(4) == Data("RIFF".utf8), data[8..<12] == Data("WAVE".utf8) else {
            throw ParseError.invalidRIFF
        }
        var offset = 12
        var chunks: [Data] = []
        while offset + 8 <= data.count {
            let length = (0..<4).reduce(0) { $0 | Int(data[offset + 4 + $1]) << ($1 * 8) }
            let start = offset + 8
            guard length <= data.count - start else { throw ParseError.invalidRIFF }
            if data[offset..<(offset + 4)] == Data("LIST".utf8), length >= 4,
               data[start..<(start + 4)] == Data("INFO".utf8) {
                chunks.append(data[start..<(start + length)])
            }
            offset = start + length + (length % 2)
        }
        return chunks
    }
    private enum ParseError: Error { case invalidRIFF }
}
