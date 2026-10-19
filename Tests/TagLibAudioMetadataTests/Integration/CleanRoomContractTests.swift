import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

struct CleanRoomContractTests {
    @Test func mp4DateEditsResolveSingleFieldIntentAndRejectContradictoryReplacement() throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.releaseDate = "2024-05-01"; $0.year = "2024" }
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.releaseDate = "2025-06-02" }
            var after = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(after.releaseDate == "2025-06-02" && after.year == "2025")
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.year = "2026" }
            after = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(after.releaseDate == "2026-06-02" && after.year == "2026")
            var conflicting = after
            conflicting.year = "1999"
            let original = try Data(contentsOf: url)
            #expect(throws: MetadataValidationError.conflictingMP4Date(year: "1999", releaseDate: "2026-06-02")) {
                try TagLibMetadataManager.replaceBasicMetadata(conflicting, to: url)
            }
            #expect(try Data(contentsOf: url) == original)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.releaseDate = "" }
            after = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(after.year.isEmpty && after.releaseDate.isEmpty)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.year = "2027" }
            after = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(after.year == "2027" && after.releaseDate == "2027")
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.year = "" }
            after = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(after.year.isEmpty && after.releaseDate.isEmpty)
        }
    }

    @Test func rawNativeKeysRejectBeforeMutationEvenWithoutVerification() throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            for key in ["----:com.apple.iTunes:CUSTOM_FIELD", "----:COM.APPLE.ITUNES:CUSTOM_FIELD"] {
                let original = try Data(contentsOf: url)
                for mode in [TagLibMetadataManager.RawPropertyMapWriteMode.merge, .replace] {
                    for verify in [false, true] {
                        #expect(throws: RawMetadataPatchError.nativeKeyRequiresStructuredAPI(key)) {
                            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                                [key: ["New"]], to: url, mode: mode, verifyAfterWrite: verify)
                        }
                        #expect(throws: RawMetadataPatchError.nativeKeyRequiresStructuredAPI(key)) {
                            try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                                [key: "New"], to: url, mode: mode, verifyAfterWrite: verify)
                        }
                    }
                }
                #expect(throws: RawMetadataPatchError.nativeKeyRequiresStructuredAPI(key)) {
                    try TagLibMetadataManager.applyRawMetadataPatch(RawMetadataPatch(removingKeys: [key]), to: url)
                }
                #expect(throws: (any Error).self) {
                    try TagLibMetadataExtractor.writeRawPropertyMap([key: "New"], to: url)
                }
                #expect(try Data(contentsOf: url) == original)
            }
            // The supported native alternative persists the exact spelling.
            let key = "----:com.apple.iTunes:MixedCase"
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(mp4Atoms: [.init(key: key, type: "stringList", values: ["Native"])]), to: url)
            #expect(try TagLibMetadataManager.readStructuredMetadataResult(from: url).mp4Atoms.contains {
                $0.key == key && $0.values == ["Native"]
            })
        }
    }
}
