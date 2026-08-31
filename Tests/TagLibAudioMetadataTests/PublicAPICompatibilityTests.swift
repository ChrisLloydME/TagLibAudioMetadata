import Foundation
import XCTest
import TagLibAudioMetadata

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
}
