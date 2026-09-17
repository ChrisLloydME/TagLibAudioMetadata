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
        let policy: TagLibMetadataManager.VerificationFailurePolicy = .throw
        let artwork: TagLibMetadataManager.ArtworkVerificationExpectation = .unchanged

        XCTAssertEqual(verification, .none)
        XCTAssertTrue(result.warnings.isEmpty)
        if case .merge = mode {} else { XCTFail("Expected merge mode") }
        if case .throw = policy {} else { XCTFail("Expected throw policy") }
        if case .unchanged = artwork {} else { XCTFail("Expected unchanged artwork expectation") }
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
}
