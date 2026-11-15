import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

/// Stable execution-adapter identities. Each case maps to exactly one named
/// public API in `invoke`; facade wrappers and direct exported-bridge calls are
/// deliberately separate adapters. There is no fallback, coercion or retry in
/// this layer.
enum PublicSurfaceAdapterID: String, CaseIterable {
    case facadeReadMetadataResult = "facade.readMetadataResult"
    case facadeReadSnapshot = "facade.readSnapshot"
    case facadeReadSnapshotWithAudio = "facade.readSnapshotWithAudio"
    case facadeReadBasicSnapshot = "facade.readBasicSnapshot"
    case facadeReadRawMetadata = "facade.readRawMetadata"
    case facadeBestEffortMetadata = "facade.bestEffortMetadata"
    case facadeBestEffortRawMetadata = "facade.bestEffortRawMetadata"
    case facadeBestEffortRawMetadataText = "facade.bestEffortRawMetadataText"
    case facadeReadStructured = "facade.readStructured"
    case facadeBestEffortStructured = "facade.bestEffortStructured"
    case facadeApplyPatch = "facade.applyPatch"
    case facadeApplyPatchGuarded = "facade.applyPatchGuarded"
    case facadeApplyRawPatch = "facade.applyRawPatch"
    case facadeApplyRawPatchGuarded = "facade.applyRawPatchGuarded"
    case facadeReplaceBasic = "facade.replaceBasic"
    case facadeUpdateBasic = "facade.updateBasic"
    case facadeWriteTagMetadata = "facade.writeTagMetadata"
    case facadeWriteTrackNumberText = "facade.writeTrackNumberText"
    case facadeWriteRawMapStrings = "facade.writeRawMapStrings"
    case facadeWriteRawMapValues = "facade.writeRawMapValues"
    case facadeWriteStructured = "facade.writeStructured"
    case facadeEraseAll = "facade.eraseAll"
    case facadeFileVersion = "facade.fileVersion"
    case facadeNumberingInventory = "facade.numberingInventory"
    case facadePlanNormalization = "facade.planNormalization"
    case facadeApplyNormalization = "facade.applyNormalization"
    case facadeCapability = "facade.capability"
    case facadeProbeFile = "facade.probeFile"
    case facadeFormatSupportLevel = "facade.formatSupportLevel"
    case facadeIsReadableExtension = "facade.isReadableExtension"
    case facadeIsWritableExtension = "facade.isWritableExtension"
    case facadeReadableExtensions = "facade.readableExtensions"
    case facadeWritableExtensions = "facade.writableExtensions"
    case facadeFormatCapabilities = "facade.formatCapabilities"
    case bridgeExtractMetadata = "bridge.extractMetadata"
    case bridgeMetadataProjections = "bridge.metadataProjections"
    case bridgeMetadataProjectionsOptions = "bridge.metadataProjectionsOptions"
    case bridgeWriteMetadata = "bridge.writeMetadata"
    case bridgeWriteTrackNumberText = "bridge.writeTrackNumberText"
    case bridgeWriteTrackNumber = "bridge.writeTrackNumber"
    case bridgeWriteRawPropertyMap = "bridge.writeRawPropertyMap"
    case bridgeWriteRawPropertyMapValues = "bridge.writeRawPropertyMapValues"
    case bridgeStructuredMetadata = "bridge.structuredMetadata"
    case bridgeWriteStructuredMetadata = "bridge.writeStructuredMetadata"
    case bridgeWipeMetadata = "bridge.wipeMetadata"
    case bridgeRawMetadata = "bridge.rawMetadata"
    case bridgeDumpMetadataText = "bridge.dumpMetadataText"
    case bridgeIsSupportedFormat = "bridge.isSupportedFormat"
    case bridgeIsWritableFormat = "bridge.isWritableFormat"
    case bridgeSupportedExtensions = "bridge.supportedExtensions"
    case bridgeWritableExtensions = "bridge.writableExtensions"
    case bridgeFormatCapability = "bridge.formatCapability"
    case bridgeFormatCapabilities = "bridge.formatCapabilities"
    case bridgeKnownMetadataPropertyKeys = "bridge.knownMetadataPropertyKeys"
    case bridgeMetadataFieldMappings = "bridge.metadataFieldMappings"
    case registrySchemaForKey = "registry.schemaForKey"
    case registrySchemaForPropertyMapKey = "registry.schemaForPropertyMapKey"
    case registryNormalizeKey = "registry.normalizeKey"
    case registrySchemas = "registry.schemas"
    case registryShouldDisplayMultiValue = "registry.shouldDisplayMultiValue"
    case registryProfile = "registry.profile"
    case registryMappingContract = "registry.mappingContract"
}

enum ContractAdapterError: Error, CustomStringConvertible {
    case missingInput(String)
    case bridgeReturnedFalse(String)

    var description: String {
        switch self {
        case .missingInput(let adapter): "adapter \(adapter) requires its declared input"
        case .bridgeReturnedFalse(let adapter): "exported bridge adapter \(adapter) returned false"
        }
    }
}

enum ContractAdapterInput {
    case none
    case patch(MetadataPatch)
    case patchGuarded(MetadataPatch, expectedVersion: MetadataFileVersion, audio: MetadataAudioContentIdentity)
    case rawPatch(RawMetadataPatch)
    case rawPatchGuarded(RawMetadataPatch, expectedVersion: MetadataFileVersion, audio: MetadataAudioContentIdentity)
    case basic(BasicMetadata)
    case updateBasic((inout BasicMetadata) throws -> Void)
    case model(TagLibAudioMetadata, TagLibMetadataManager.MetadataWriteVerificationContext)
    case trackText(track: String, disc: String?, verify: Bool)
    case trackNumber(track: Int, total: Int, padWidth: Int)
    case rawStrings([String: String], mode: TagLibMetadataManager.RawPropertyMapWriteMode, verify: Bool)
    case rawValues([String: [String]], mode: TagLibMetadataManager.RawPropertyMapWriteMode, verify: Bool)
    case structured(
        StructuredMetadata,
        includeProperties: Bool,
        replacing: Set<StructuredMetadataReplaceableCollection>,
        verify: Bool
    )
    case bridgeStructured([String: NSObject])
    case projections(mask: UInt)
    case extensionName(String)
    case schemaKey(MetadataFieldKey)
    case propertyKey(String)
    case normalization(MetadataNumberResolutionPolicy, Set<MetadataNumberGroup>)
    case applyPlan(MetadataNumberNormalizationPlan)
}

enum ContractAdapterOutput {
    case none
    case write(TagLibMetadataManager.MetadataWriteResult)
    case metadata(BasicMetadata)
    case snapshot(MetadataSnapshot)
    case basicSnapshot(BasicMetadataSnapshot)
    case raw(RawMetadataDump)
    case structured(StructuredMetadata)
    case text(String?)
    case version(MetadataFileVersion)
    case capability(FormatCapability?)
    case support(FormatSupportLevel)
    case boolean(Bool)
    case strings([String])
    case capabilities([FormatCapability])
    case inventory(MetadataNumberingInventory)
    case plan(MetadataNumberNormalizationPlan)
    case schema(MetadataFieldSchema?)
    case schemas([MetadataFieldSchema])
    case profile(MetadataTargetProfile?)
    case bridgeDictionary([String: NSObject])
    case bridgeOptionalDictionary([String: NSObject]?)
    case bridgeDictionaries([[String: NSObject]])
    case bridgeModel(TagLibAudioMetadata?)
    case metadataOptional(BasicMetadata?)
    case rawOptional(RawMetadataDump?)
    case structuredOptional(StructuredMetadata?)
}

enum PublicSurfaceAdapters {
    static func invoke(
        _ id: PublicSurfaceAdapterID,
        url: URL,
        input: ContractAdapterInput = .none
    ) throws -> ContractAdapterOutput {
        let result: Result<ContractAdapterOutput, Error>
        do { result = .success(try execute(id, url: url, input: input)) }
        catch { result = .failure(error) }
        let outcome: String
        switch result { case .success: outcome = "returned"; case .failure: outcome = "threw" }
        try ContractEvidence.recordInvocation(adapter: id.rawValue, outcome: outcome)
        return try result.get()
    }

    private static func execute(_ id: PublicSurfaceAdapterID, url: URL, input: ContractAdapterInput) throws -> ContractAdapterOutput {
        switch id {
        case .facadeReadMetadataResult:
            return .metadata(try TagLibMetadataManager.readMetadataResult(from: url))
        case .facadeReadSnapshot:
            return .snapshot(try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: false))
        case .facadeReadSnapshotWithAudio:
            return .snapshot(try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true))
        case .facadeReadBasicSnapshot:
            return .basicSnapshot(try TagLibMetadataManager.readBasicSnapshot(from: url))
        case .facadeReadRawMetadata:
            return .raw(try TagLibMetadataManager.rawMetadataResult(from: url))
        case .facadeBestEffortMetadata:
            return .metadataOptional(TagLibMetadataManager.bestEffortMetadata(from: url))
        case .facadeBestEffortRawMetadata:
            return .rawOptional(TagLibMetadataManager.bestEffortRawMetadata(from: url))
        case .facadeBestEffortRawMetadataText:
            return .text(TagLibMetadataManager.bestEffortRawMetadataText(from: url))
        case .facadeReadStructured:
            return .structured(try TagLibMetadataManager.readStructuredMetadataResult(from: url))
        case .facadeBestEffortStructured:
            return .structuredOptional(TagLibMetadataManager.bestEffortStructuredMetadata(from: url))
        case .facadeApplyPatch:
            guard case .patch(let patch) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.applyMetadataPatch(patch, to: url))
        case .facadeApplyPatchGuarded:
            guard case .patchGuarded(let patch, let version, let audio) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.applyMetadataPatch(
                patch, to: url, expectedVersion: version, expectedAudioContent: audio
            ))
        case .facadeApplyRawPatch:
            guard case .rawPatch(let patch) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.applyRawMetadataPatch(patch, to: url))
        case .facadeApplyRawPatchGuarded:
            guard case .rawPatchGuarded(let patch, let version, let audio) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.applyRawMetadataPatch(
                patch, to: url, expectedVersion: version, expectedAudioContent: audio
            ))
        case .facadeReplaceBasic:
            guard case .basic(let metadata) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.replaceBasicMetadata(metadata, to: url))
        case .facadeUpdateBasic:
            guard case .updateBasic(let update) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.updateBasicMetadata(at: url, update))
        case .facadeWriteTagMetadata:
            guard case .model(let metadata, let verification) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.writeTagMetadata(
                metadata, to: url, verification: verification
            ))
        case .facadeWriteTrackNumberText:
            guard case .trackText(let track, let disc, let verify) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.writeTrackNumberText(
                track, discNumberText: disc, to: url, verifyAfterWrite: verify
            ))
        case .facadeWriteRawMapStrings:
            guard case .rawStrings(let values, let mode, let verify) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                values, to: url, mode: mode, verifyAfterWrite: verify
            ))
        case .facadeWriteRawMapValues:
            guard case .rawValues(let values, let mode, let verify) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                values, to: url, mode: mode, verifyAfterWrite: verify
            ))
        case .facadeWriteStructured:
            guard case .structured(let metadata, let includeProperties, let replacing, let verify) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                metadata,
                to: url,
                riffPolicy: .preserveInfo,
                includeProperties: includeProperties,
                replacingCollections: replacing,
                verifyAfterWrite: verify
            ))
        case .facadeEraseAll:
            return .write(try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url))
        case .facadeFileVersion:
            return .version(try TagLibMetadataManager.fileVersion(at: url))
        case .facadeNumberingInventory:
            return .inventory(try TagLibMetadataManager.numberingInventory(at: url))
        case .facadePlanNormalization:
            guard case .normalization(let policy, let groups) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .plan(try TagLibMetadataManager.planNumberNormalization(
                at: url, policy: policy, groups: groups
            ))
        case .facadeApplyNormalization:
            guard case .applyPlan(let plan) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .write(try TagLibMetadataManager.applyNumberNormalization(plan, to: url))
        case .facadeCapability:
            guard case .extensionName(let fileExtension) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .capability(TagLibMetadataManager.capability(forExtension: fileExtension))
        case .facadeProbeFile:
            return .capability(try TagLibMetadataManager.probeFile(at: url))
        case .facadeFormatSupportLevel:
            guard case .extensionName(let fileExtension) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .support(TagLibMetadataManager.formatSupportLevel(for: fileExtension))
        case .facadeIsReadableExtension:
            guard case .extensionName(let fileExtension) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .boolean(TagLibMetadataManager.isReadableExtension(fileExtension))
        case .facadeIsWritableExtension:
            guard case .extensionName(let fileExtension) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .boolean(TagLibMetadataManager.isWritableExtension(fileExtension))
        case .facadeReadableExtensions:
            return .strings(TagLibMetadataManager.readableExtensions)
        case .facadeWritableExtensions:
            return .strings(TagLibMetadataManager.writableExtensions)
        case .facadeFormatCapabilities:
            return .capabilities(TagLibMetadataManager.formatCapabilities)
        case .bridgeExtractMetadata:
            return .bridgeModel(try TagLibMetadataExtractor.extractMetadata(from: url))
        case .bridgeMetadataProjections:
            return .bridgeDictionary(try TagLibMetadataExtractor.metadataProjections(for: url))
        case .bridgeMetadataProjectionsOptions:
            guard case .projections(let mask) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .bridgeDictionary(try TagLibMetadataExtractor.metadataProjections(
                for: url, options: .init(rawValue: mask)
            ))
        case .bridgeWriteMetadata:
            guard case .model(let metadata, _) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            try TagLibMetadataExtractor.writeMetadata(metadata, to: url)
            return .none
        case .bridgeWriteTrackNumberText:
            guard case .trackText(let track, let disc, _) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            try TagLibMetadataExtractor.writeTrackNumberText(track, discNumberText: disc, to: url)
            return .none
        case .bridgeWriteTrackNumber:
            guard case .trackNumber(let track, let total, let padWidth) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            try TagLibMetadataExtractor.writeTrackNumber(track, totalTracks: total, padWidth: padWidth, to: url)
            return .none
        case .bridgeWriteRawPropertyMap:
            guard case .rawStrings(let values, _, _) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            try TagLibMetadataExtractor.writeRawPropertyMap(values, to: url)
            return .none
        case .bridgeWriteRawPropertyMapValues:
            guard case .rawValues(let values, _, _) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            try TagLibMetadataExtractor.writeRawPropertyMapValues(values, to: url)
            return .none
        case .bridgeStructuredMetadata:
            return .bridgeDictionary(try TagLibMetadataExtractor.structuredMetadata(for: url))
        case .bridgeWriteStructuredMetadata:
            guard case .bridgeStructured(let payload) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            try TagLibMetadataExtractor.writeStructuredMetadata(payload, to: url)
            return .none
        case .bridgeWipeMetadata:
            try TagLibMetadataExtractor.wipeMetadata(from: url)
            return .none
        case .bridgeRawMetadata:
            return .bridgeDictionary(try TagLibMetadataExtractor.rawMetadata(for: url))
        case .bridgeDumpMetadataText:
            return .text(try TagLibMetadataExtractor.dumpMetadataText(from: url))
        case .bridgeIsSupportedFormat:
            guard case .extensionName(let fileExtension) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .boolean(TagLibMetadataExtractor.isSupportedFormat(fileExtension))
        case .bridgeIsWritableFormat:
            guard case .extensionName(let fileExtension) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .boolean(TagLibMetadataExtractor.isWritableFormat(fileExtension))
        case .bridgeSupportedExtensions:
            return .strings(TagLibMetadataExtractor.supportedExtensions())
        case .bridgeWritableExtensions:
            return .strings(TagLibMetadataExtractor.writableExtensions())
        case .bridgeFormatCapability:
            guard case .extensionName(let fileExtension) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .bridgeOptionalDictionary(TagLibMetadataExtractor.formatCapability(for: fileExtension))
        case .bridgeFormatCapabilities:
            return .bridgeDictionaries(TagLibMetadataExtractor.formatCapabilities())
        case .bridgeKnownMetadataPropertyKeys:
            return .strings(TagLibMetadataExtractor.knownMetadataPropertyKeys())
        case .bridgeMetadataFieldMappings:
            return .bridgeDictionaries(TagLibMetadataExtractor.metadataFieldMappings())
        case .registrySchemaForKey:
            guard case .schemaKey(let key) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .schema(MetadataFieldRegistry.schema(for: key))
        case .registrySchemaForPropertyMapKey:
            guard case .propertyKey(let key) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .schema(MetadataFieldRegistry.schema(forPropertyMapKey: key))
        case .registryNormalizeKey:
            guard case .propertyKey(let key) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .text(MetadataFieldRegistry.normalizePropertyMapKey(key))
        case .registrySchemas:
            return .schemas(MetadataFieldRegistry.schemas(withMappingsFor: .mp4))
        case .registryShouldDisplayMultiValue:
            guard case .propertyKey(let key) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .boolean(MetadataFieldRegistry.shouldDisplayRawPropertyAsMultiValue(key))
        case .registryProfile:
            guard case .propertyKey(let key) = input else {
                throw ContractAdapterError.missingInput(id.rawValue)
            }
            return .profile(MetadataMappingCatalog.profile(forSemanticKey: key))
        case .registryMappingContract:
            return .text("\(MetadataMappingCatalog.contractVersion)|\(MetadataMappingCatalog.decisionDate)")
        }
    }
}

