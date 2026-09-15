import Dispatch
import Foundation
import XCTest
@testable import TagLibAudioMetadata
import CTagLibBridge

final class SameFileTransactionTests: XCTestCase {
    func testHardLinkCreatedDuringMutationPreventsCommit() throws {
        let url = try copyFixture("flac")
        let linkedURL = url.deletingLastPathComponent().appendingPathComponent("linked.flac")
        let originalBytes = try Data(contentsOf: url)

        XCTAssertThrowsError(
            try TagLibMetadataManager.withAtomicFileMutation(at: url) { mutationURL in
                try TagLibMetadataExtractor.applyPropertyMapValuesInPlace(
                    ["TITLE": ["Must not commit"]],
                    removingKeys: ["TITLE"],
                    to: mutationURL
                )
                try FileManager.default.linkItem(at: url, to: linkedURL)
            }
        ) { error in
            guard case TagLibManagerError.fileChanged = error else {
                return XCTFail("Expected fileChanged, got \(error)")
            }
        }

        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
        XCTAssertEqual(try Data(contentsOf: linkedURL), originalBytes)
    }

    func testReplacementDoesNotChangeCoordinationLockThroughDirectoryAlias() throws {
        let url = try copyFixture("flac")
        let alias = url.deletingLastPathComponent().appendingPathComponent("directory-alias")
        try FileManager.default.createSymbolicLink(
            at: alias, withDestinationURL: url.deletingLastPathComponent()
        )
        let aliasedURL = alias.appendingPathComponent(url.lastPathComponent)
        let committed = DispatchSemaphore(value: 0)
        let releaseCommit = DispatchSemaphore(value: 0)
        let nextEntered = DispatchSemaphore(value: 0)
        let group = DispatchGroup()
        let errors = LockedTransactionErrors()
        let queue = DispatchQueue(label: "TagLibAudioMetadata.after-rename", attributes: .concurrent)

        group.enter()
        queue.async {
            defer { group.leave() }
            do {
                try TagLibMetadataManager.withAtomicFileMutation(at: url, directorySync: { _ in
                    // The destination inode has already changed, but the
                    // transaction still owns the entry through durability work.
                    committed.signal()
                    return releaseCommit.wait(timeout: .now() + 5) == .success ? 0 : -1
                }) { temporary in
                    try TagLibMetadataExtractor.applyPropertyMapValuesInPlace(
                        ["TITLE": ["Before replacement"]], removingKeys: ["TITLE"], to: temporary
                    )
                }
            } catch { errors.append(error) }
        }
        XCTAssertEqual(committed.wait(timeout: .now() + 5), .success)
        group.enter()
        queue.async {
            defer { group.leave() }
            do {
                try TagLibMetadataManager.withAtomicFileMutation(at: aliasedURL) { temporary in
                    nextEntered.signal()
                    try TagLibMetadataExtractor.applyPropertyMapValuesInPlace(
                        ["COMMENT": ["After replacement"]], removingKeys: ["COMMENT"], to: temporary
                    )
                }
            } catch { errors.append(error) }
        }
        XCTAssertEqual(nextEntered.wait(timeout: .now() + 0.5), .timedOut)
        releaseCommit.signal()
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertTrue(errors.values.isEmpty, "Unexpected errors: \(errors.values)")
        let raw = try TagLibMetadataManager.rawMetadataResult(from: url)
        XCTAssertEqual(values(for: "TITLE", in: raw), ["Before replacement"])
        XCTAssertEqual(values(for: "COMMENT", in: raw), ["After replacement"])
    }

    func testSameFileTransactionsSerializeTheWholeMutation() throws {
        let url = try copyFixture("flac")
        let firstEntered = DispatchSemaphore(value: 0)
        let allowFirstToFinish = DispatchSemaphore(value: 0)
        let secondAttempting = DispatchSemaphore(value: 0)
        let secondEntered = DispatchSemaphore(value: 0)
        let group = DispatchGroup()
        let errors = LockedTransactionErrors()
        let queue = DispatchQueue(label: "TagLibAudioMetadata.same-file-transactions", attributes: .concurrent)

        group.enter()
        queue.async {
            defer { group.leave() }
            do {
                try TagLibMetadataManager.withAtomicFileMutation(at: url, afterFinalValidation: {
                    firstEntered.signal()
                    guard allowFirstToFinish.wait(timeout: .now() + 5) == .success else {
                        throw TestTransactionError.timedOut
                    }
                }) { mutationURL in
                    try TagLibMetadataExtractor.applyPropertyMapValuesInPlace(
                        ["TITLE": ["First transaction"]],
                        removingKeys: ["TITLE"],
                        to: mutationURL
                    )
                }
            } catch {
                errors.append(error)
            }
        }

        XCTAssertEqual(firstEntered.wait(timeout: .now() + 5), .success)

        group.enter()
        queue.async {
            defer { group.leave() }
            secondAttempting.signal()
            do {
                try TagLibMetadataManager.withAtomicFileMutation(at: url) { mutationURL in
                    secondEntered.signal()
                    try TagLibMetadataExtractor.applyPropertyMapValuesInPlace(
                        ["COMMENT": ["Second transaction"]],
                        removingKeys: ["COMMENT"],
                        to: mutationURL
                    )
                }
            } catch {
                errors.append(error)
            }
        }

        XCTAssertEqual(secondAttempting.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(
            secondEntered.wait(timeout: .now() + 0.25),
            .timedOut,
            "A second transaction must not enter while the first is paused after final identity validation and before rename."
        )

        allowFirstToFinish.signal()
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertTrue(errors.values.isEmpty, "Unexpected transaction errors: \(errors.values)")

        let raw = try TagLibMetadataManager.rawMetadataResult(from: url)
        XCTAssertEqual(values(for: "TITLE", in: raw), ["First transaction"])
        XCTAssertEqual(values(for: "COMMENT", in: raw), ["Second transaction"])
    }

    private func fixtureURL(_ ext: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext)
        )
    }

    private func copyFixture(_ ext: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TagLibAudioMetadataTransactions-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("testAudioFile.\(ext)")
        try FileManager.default.copyItem(at: try fixtureURL(ext), to: destination)
        return destination
    }

    private func values(for key: String, in raw: RawMetadataDump) -> [String] {
        raw.properties.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.values ?? []
    }
}

private enum TestTransactionError: Error {
    case timedOut
}

private final class LockedTransactionErrors: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Error] = []

    var values: [Error] {
        lock.withLock { storage }
    }

    func append(_ error: Error) {
        lock.withLock { storage.append(error) }
    }
}
