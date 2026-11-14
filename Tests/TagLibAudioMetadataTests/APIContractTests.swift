import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

struct APIContractTests {
    private typealias Result = TagLibMetadataManager.MetadataWriteResult
    private typealias Mode = TagLibMetadataManager.RawPropertyMapWriteMode
    private typealias Verification = TagLibMetadataManager.MetadataWriteVerificationContext
    private typealias Collections = Set<StructuredMetadataReplaceableCollection>

    @Test func readerEraseAndVersionAwareFunctionTypesStillCompile() {
        let _: (URL) throws -> BasicMetadata = TagLibMetadataManager.readMetadataResult
        let _: (URL) -> BasicMetadata? = TagLibMetadataManager.bestEffortMetadata
        let _: (URL) throws -> RawMetadataDump = TagLibMetadataManager.rawMetadataResult
        let _: (URL) -> RawMetadataDump? = TagLibMetadataManager.bestEffortRawMetadata
        let _: (URL) -> String? = TagLibMetadataManager.bestEffortRawMetadataText
        let _: (URL) -> StructuredMetadata? = TagLibMetadataManager.bestEffortStructuredMetadata
        let _: (URL) throws -> StructuredMetadata = TagLibMetadataManager.readStructuredMetadataResult
        let _: (URL, Bool) throws -> MetadataSnapshot = TagLibMetadataManager.readSnapshot
        let _: (URL, Bool) throws -> BasicMetadataSnapshot = TagLibMetadataManager.readBasicSnapshot
        let _: (BasicMetadata, RawMetadataDump, StructuredMetadata, MetadataFileVersion?, MetadataAudioContentIdentity?) -> MetadataSnapshot = MetadataSnapshot.init
        let _: (BasicMetadata, MetadataFileVersion, MetadataAudioContentIdentity?) -> BasicMetadataSnapshot = BasicMetadataSnapshot.init
        let _: (MetadataPatch, URL, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.applyMetadataPatch
        let _: (RawMetadataPatch, URL, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.applyRawMetadataPatch
        let _: (MetadataPatch, URL, MetadataFileVersion, MetadataAudioContentIdentity) throws -> Result = TagLibMetadataManager.applyMetadataPatch
        let _: (RawMetadataPatch, URL, MetadataFileVersion, MetadataAudioContentIdentity) throws -> Result = TagLibMetadataManager.applyRawMetadataPatch
        let _: (URL, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.eraseAllMetadataWithVerification
        let _: (BasicMetadata, URL, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.replaceBasicMetadata
        let _: (String, String?, URL, Bool, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeTrackNumberText
        let _: ([String: String], URL, Mode, Bool, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification
        let _: (StructuredMetadata, URL, RIFFMetadataWritePolicy, Bool, Collections, Bool, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeStructuredMetadataWithVerification
        let _: (TagLibAudioMetadata, URL, Verification, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeTagMetadata
        let _: TagLibManagerError = .operationFailed("Caller explanation")
        let cause = NSError(domain: "Consumer", code: 42)
        let error: TagLibManagerError = .operationFailedWithUnderlying(cause)
        #expect(error.underlyingError?.domain == "Consumer")
        #expect(error.underlyingError?.code == 42)
    }

    @Test func currentWriterFunctionReferencesCarryVersionGuards() {
        let _: (BasicMetadata, URL, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.replaceBasicMetadata
        let _: (TagLibAudioMetadata, URL, Verification, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeTagMetadata
        let _: ([String: String], URL, Mode, Bool, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification
        let _: ([String: [String]], URL, Mode, Bool, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification
        let _: (StructuredMetadata, URL, RIFFMetadataWritePolicy, Bool, Collections, Bool, MetadataFileVersion?) throws -> Result = TagLibMetadataManager.writeStructuredMetadataWithVerification
        let _: TagLibMetadataManager.ArtworkVerificationExpectation = .skip
    }
}
