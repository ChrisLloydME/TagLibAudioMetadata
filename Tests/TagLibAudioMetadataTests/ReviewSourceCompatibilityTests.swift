import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

struct ReviewSourceCompatibilityTests {
    private typealias Result = TagLibMetadataManager.MetadataWriteResult
    private typealias Mode = TagLibMetadataManager.RawPropertyMapWriteMode
    private typealias Verification = TagLibMetadataManager.MetadataWriteVerificationContext
    private typealias Policy = TagLibMetadataManager.VerificationFailurePolicy
    private typealias Collections = Set<StructuredMetadataReplaceableCollection>

    @Test func originalWriterFunctionReferencesStillCompile() {
        let _: (BasicMetadata, URL) throws -> Bool = TagLibMetadataManager.writeMetadata
        let _: ([String: String], URL, Mode) throws -> Bool = TagLibMetadataManager.writeRawMetadataPropertyMap
        let _: (TagLibAudioMetadata, URL, Verification) throws -> Result = TagLibMetadataManager.writeTagMetadata
        let _: (TagLibAudioMetadata, URL, Verification, Policy) throws -> Result = TagLibMetadataManager.writeTagMetadata
        let _: ([String: String], URL, Mode, Bool) throws -> Result = TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification
        let _: ([String: String], URL, Mode, Bool, Policy) throws -> Result = TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification
        let _: ([String: [String]], URL, Mode, Bool) throws -> Result = TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification
        let _: ([String: [String]], URL, Mode, Bool, Policy) throws -> Result = TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification
        let _: (StructuredMetadata, URL, RIFFMetadataWritePolicy, Bool, Collections, Bool) throws -> Result = TagLibMetadataManager.writeStructuredMetadataWithVerification
        let _: (StructuredMetadata, URL, RIFFMetadataWritePolicy, Bool, Collections, Bool, Policy) throws -> Result = TagLibMetadataManager.writeStructuredMetadataWithVerification
        let _: Policy = .warn
        let _: TagLibMetadataManager.ArtworkVerificationExpectation = .unchanged
    }
}
