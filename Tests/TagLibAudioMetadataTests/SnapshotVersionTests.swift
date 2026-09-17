import Foundation
import XCTest
@testable import TagLibAudioMetadata

final class SnapshotVersionTests: XCTestCase {
    func testReadIdentityIgnoresStatusOnlyChanges() throws {
        let url = try fixtureCopy()
        let before = try XCTUnwrap(TagLibMetadataManager.regularFileIdentity(at: url))

        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: url.path
        )

        let after = try XCTUnwrap(TagLibMetadataManager.regularFileIdentity(at: url))
        XCTAssertNotEqual(before, after, "Changing permissions should update file status identity.")
        XCTAssertTrue(before.hasSameReadableContents(as: after))
    }

    func testReadIdentityRejectsContentChanges() throws {
        let url = try fixtureCopy()
        let before = try XCTUnwrap(TagLibMetadataManager.regularFileIdentity(at: url))

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data([0]))

        let after = try XCTUnwrap(TagLibMetadataManager.regularFileIdentity(at: url))
        XCTAssertFalse(before.hasSameReadableContents(as: after))
    }

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
        XCTAssertThrowsError(try TagLibMetadataManager.writeTrackNumberText(
            "02/09",
            discNumberText: nil,
            to: url,
            expectedVersion: version
        ))
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
