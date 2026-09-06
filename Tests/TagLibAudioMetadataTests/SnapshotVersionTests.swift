import Foundation
import XCTest
@testable import TagLibAudioMetadata

final class SnapshotVersionTests: XCTestCase {
    func testStaleSnapshotRejectsPatchWithoutChangingNewerBytes() throws {
        let url = try fixtureCopy()
        let original = try TagLibMetadataManager.readSnapshot(from: url)
        let version = try XCTUnwrap(original.fileVersion)
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.title: .text("Newer edit")]), to: url, expectedVersion: version
        )
        let newerBytes = try Data(contentsOf: url)
        XCTAssertThrowsError(try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.artist: .text("Stale edit")]), to: url, expectedVersion: version
        )) { error in
            guard case TagLibManagerError.fileChanged = error else {
                return XCTFail("Expected a typed conflict, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), newerBytes)
        XCTAssertThrowsError(try TagLibMetadataManager.applyRawMetadataPatch(
            RawMetadataPatch(valuesToSet: ["LYRICS": ["Stale lyrics"]]), to: url, expectedVersion: version
        ))
        XCTAssertThrowsError(try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url, expectedVersion: version))
        XCTAssertEqual(try Data(contentsOf: url), newerBytes)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path), [url.lastPathComponent])
    }

    func testSnapshotRejectsFinalSymlinkInsteadOfComparingTwoMissingIdentities() throws {
        let url = try fixtureCopy()
        let alias = url.deletingLastPathComponent().appendingPathComponent("alias.flac")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: url)
        XCTAssertThrowsError(try TagLibMetadataManager.readSnapshot(from: alias)) { error in
            guard case TagLibManagerError.invalidFile = error else {
                return XCTFail("Expected invalidFile, got \(error)")
            }
        }
    }

    private func fixtureCopy() throws -> URL {
        let source = try XCTUnwrap(Bundle.module.url(forResource: "testAudioFile", withExtension: "flac", subdirectory: "Audio")
            ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "flac"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SnapshotVersion-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("audio.flac")
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }
}
