import Foundation
import XCTest
import TagLibAudioMetadata
import CTagLibBridge

final class PublicAPICompatibilityTests: XCTestCase {
    func testObjectiveCBridgeClassSelectorsRemainAvailable() {
        let selectors = [
            "extractMetadataFromURL:error:",
            "metadataProjectionsForURL:error:",
            "writeMetadata:toURL:error:",
            "writeTrackNumberText:discNumberText:toURL:error:",
            "writeTrackNumber:totalTracks:padWidth:toURL:error:",
            "writeRawPropertyMap:toURL:error:",
            "writeRawPropertyMapValues:toURL:error:",
            "structuredMetadataForURL:error:",
            "writeStructuredMetadata:toURL:error:",
            "wipeMetadataFromURL:error:",
            "rawMetadataForURL:error:",
            "dumpMetadataTextFromURL:error:",
            "isSupportedFormat:",
            "isWritableFormat:",
            "supportedExtensions",
            "writableExtensions",
            "formatCapabilityForExtension:",
            "formatCapabilities",
            "knownMetadataPropertyKeys",
            "metadataFieldMappings",
        ]

        for name in selectors {
            XCTAssertTrue(
                TagLibMetadataExtractor.responds(to: NSSelectorFromString(name)),
                "Missing Objective-C class selector \(name)"
            )
        }
    }

    func testSwiftFacadeNestedTypesRemainSourceCompatible() {
        let verification: TagLibMetadataManager.MetadataWriteVerificationContext = .none
        let result = TagLibMetadataManager.MetadataWriteResult(warnings: [])
        let mode: TagLibMetadataManager.RawPropertyMapWriteMode = .merge
        let artwork: TagLibMetadataManager.ArtworkVerificationExpectation = .unchanged

        XCTAssertEqual(verification, .none)
        XCTAssertTrue(result.warnings.isEmpty)
        if case .merge = mode {} else { XCTFail("Expected merge mode") }
        if case .unchanged = artwork {} else { XCTFail("Expected unchanged artwork expectation") }
    }

    func testBestEffortReadNamesExplicitlyCollapseFailures() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        try Data("not audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNil(TagLibMetadataManager.bestEffortMetadata(from: url))
        XCTAssertNil(TagLibMetadataManager.bestEffortRawMetadata(from: url))
        XCTAssertNil(TagLibMetadataManager.bestEffortStructuredMetadata(from: url))
        XCTAssertThrowsError(try TagLibMetadataManager.readMetadataResult(from: url))
        XCTAssertThrowsError(try TagLibMetadataManager.rawMetadataResult(from: url))
        XCTAssertThrowsError(try TagLibMetadataManager.readStructuredMetadataResult(from: url))
    }

    func testLowLevelCommittedDurabilityOutcomeIsPubliclyTyped() {
        XCTAssertEqual(TagLibMetadataErrorDomain, "TagLibMetadataExtractor")
        XCTAssertEqual(TagLibMetadataTransactionErrorCode.committedButDurabilityUncertain.rawValue, 9_110)
    }

    func testPublicLowLevelHeaderExcludesTransactionBypassPrimitives() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let header = try String(
            contentsOf: packageRoot
                .appendingPathComponent("Sources/CTagLibBridge/include/TagLibMetadataExtractor.h"),
            encoding: .utf8
        )

        XCTAssertFalse(header.contains("InPlace"))
        XCTAssertFalse(header.contains("coordinateMutationAtURL"))
        XCTAssertFalse(header.contains("TagLibFileMutationCoordinationBlock"))
    }

    func testSwiftFacadeDoesNotEmitUnsolicitedConsoleDiagnostics() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = packageRoot.appendingPathComponent("Sources/TagLibAudioMetadata")
        let sourceURLs = try XCTUnwrap(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: nil
            )?.allObjects as? [URL]
        ).filter { $0.pathExtension == "swift" }
        let forbiddenCall = try NSRegularExpression(
            pattern: #"\b(?:print|debugPrint|NSLog)\s*\("#
        )

        for sourceURL in sourceURLs {
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            XCTAssertNil(
                forbiddenCall.firstMatch(in: source, range: range),
                "Unsolicited console output in \(sourceURL.lastPathComponent)"
            )
        }
    }
}
