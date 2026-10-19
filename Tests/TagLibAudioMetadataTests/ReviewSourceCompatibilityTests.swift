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

    @Test func readerEraseAndVersionAwareFunctionTypesStillCompile() {
        let _: (URL) throws -> BasicMetadata = TagLibMetadataManager.readMetadataResult
        let _: (URL) -> BasicMetadata? = TagLibMetadataManager.readMetadata
        let _: (URL) throws -> RawMetadataDump = TagLibMetadataManager.rawMetadataResult
        let _: (URL) -> RawMetadataDump? = TagLibMetadataManager.rawMetadata
        let _: (URL) -> String? = TagLibMetadataManager.rawMetadataText
        let _: (URL) -> StructuredMetadata? = TagLibMetadataManager.readStructuredMetadata
        let _: (URL) throws -> StructuredMetadata = TagLibMetadataManager.readStructuredMetadataResult
        let _: (URL) throws -> MetadataSnapshot = TagLibMetadataManager.readSnapshot
        let _: (URL) throws -> BasicMetadataSnapshot = TagLibMetadataManager.readBasicSnapshot
        let _: (BasicMetadata, RawMetadataDump, StructuredMetadata, MetadataFileVersion?) -> MetadataSnapshot = MetadataSnapshot.init
        let _: (BasicMetadata, MetadataFileVersion) -> BasicMetadataSnapshot = BasicMetadataSnapshot.init
        let _: (MetadataPatch, URL, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.applyMetadataPatch
        let _: (RawMetadataPatch, URL, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.applyRawMetadataPatch
        let _: (MetadataPatch, URL, MetadataFileVersion, MetadataAudioContentIdentity) throws -> Result = TagLibMetadataManager.applyMetadataPatch
        let _: (RawMetadataPatch, URL, MetadataFileVersion, MetadataAudioContentIdentity) throws -> Result = TagLibMetadataManager.applyRawMetadataPatch
        let _: (URL) throws -> Bool = TagLibMetadataManager.eraseAllMetadata
        let _: (URL, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.eraseAllMetadataWithVerification
        let _: (BasicMetadata, URL, Policy) throws -> Result = TagLibMetadataManager.writeMetadataWithVerification
        let _: (BasicMetadata, URL, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.replaceBasicMetadata
        let _: (String, String?, URL, Bool, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeTrackNumberText
        let _: ([String: String], URL, Mode, Bool, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification
        let _: (StructuredMetadata, URL, RIFFMetadataWritePolicy, Bool, Collections, Bool, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeStructuredMetadataWithVerification
        let _: (TagLibAudioMetadata, URL, Verification, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeTagMetadata
        let _: TagLibManagerError = .operationFailed("Legacy constructor")
        let cause = NSError(domain: "Consumer", code: 42)
        let error: TagLibManagerError = .operationFailedWithUnderlying(cause)
        #expect(error.underlyingError?.domain == "Consumer")
        #expect(error.underlyingError?.code == 42)
    }

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
