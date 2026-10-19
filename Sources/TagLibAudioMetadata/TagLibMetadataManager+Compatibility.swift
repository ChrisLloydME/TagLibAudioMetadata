import Foundation
import CTagLibBridge

// Preserve the original function-reference types after adding expectedVersion.
// Parameters are explicit here; convenience defaults remain on version-aware overloads.
extension TagLibMetadataManager {

    @discardableResult
    @available(*, deprecated, message: "Use replaceBasicMetadata or updateBasicMetadata.")
    public nonisolated static func writeMetadata(
        _ metadata: BasicMetadata,
        to url: URL
    ) throws -> Bool {
        try writeMetadata(
            metadata, to: url, expectedVersion: nil
        )
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMap(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode
    ) throws -> Bool {
        try writeRawMetadataPropertyMap(
            properties, to: url, mode: mode, expectedVersion: nil
        )
    }

    @discardableResult
    public nonisolated static func writeTagMetadata(
        _ metadata: TagLibAudioMetadata,
        to url: URL,
        verification: MetadataWriteVerificationContext
    ) throws -> MetadataWriteResult {
        try writeTagMetadata(
            metadata, to: url, verification: verification, expectedVersion: nil
        )
    }

    @discardableResult
    @available(*, deprecated, message: "Verification mismatches always abort. Omit failurePolicy.")
    public nonisolated static func writeTagMetadata(
        _ metadata: TagLibAudioMetadata,
        to url: URL,
        verification: MetadataWriteVerificationContext,
        failurePolicy: VerificationFailurePolicy
    ) throws -> MetadataWriteResult {
        try writeTagMetadata(
            metadata, to: url, verification: verification, expectedVersion: nil, failurePolicy: failurePolicy
        )
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMapWithVerification(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode,
        verifyAfterWrite: Bool
    ) throws -> MetadataWriteResult {
        try writeRawMetadataPropertyMapWithVerification(
            properties, to: url, mode: mode, verifyAfterWrite: verifyAfterWrite, expectedVersion: nil
        )
    }

    @discardableResult
    @available(*, deprecated, message: "Verification mismatches always abort. Omit failurePolicy.")
    public nonisolated static func writeRawMetadataPropertyMapWithVerification(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode,
        verifyAfterWrite: Bool,
        failurePolicy: VerificationFailurePolicy
    ) throws -> MetadataWriteResult {
        try writeRawMetadataPropertyMapWithVerification(
            properties, to: url, mode: mode, verifyAfterWrite: verifyAfterWrite, expectedVersion: nil, failurePolicy: failurePolicy
        )
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMapValuesWithVerification(
        _ properties: [String: [String]],
        to url: URL,
        mode: RawPropertyMapWriteMode,
        verifyAfterWrite: Bool
    ) throws -> MetadataWriteResult {
        try writeRawMetadataPropertyMapValuesWithVerification(
            properties, to: url, mode: mode, verifyAfterWrite: verifyAfterWrite, expectedVersion: nil
        )
    }

    @discardableResult
    @available(*, deprecated, message: "Verification mismatches always abort. Omit failurePolicy.")
    public nonisolated static func writeRawMetadataPropertyMapValuesWithVerification(
        _ properties: [String: [String]],
        to url: URL,
        mode: RawPropertyMapWriteMode,
        verifyAfterWrite: Bool,
        failurePolicy: VerificationFailurePolicy
    ) throws -> MetadataWriteResult {
        try writeRawMetadataPropertyMapValuesWithVerification(
            properties, to: url, mode: mode, verifyAfterWrite: verifyAfterWrite, expectedVersion: nil, failurePolicy: failurePolicy
        )
    }

    @discardableResult
    public nonisolated static func writeStructuredMetadataWithVerification(
        _ metadata: StructuredMetadata,
        to url: URL,
        riffPolicy: RIFFMetadataWritePolicy,
        includeProperties: Bool,
        replacingCollections: Set<StructuredMetadataReplaceableCollection>,
        verifyAfterWrite: Bool
    ) throws -> MetadataWriteResult {
        try writeStructuredMetadataWithVerification(
            metadata, to: url, riffPolicy: riffPolicy, includeProperties: includeProperties,
            replacingCollections: replacingCollections, verifyAfterWrite: verifyAfterWrite, expectedVersion: nil
        )
    }

    @discardableResult
    @available(*, deprecated, message: "Verification mismatches always abort. Omit failurePolicy.")
    public nonisolated static func writeStructuredMetadataWithVerification(
        _ metadata: StructuredMetadata,
        to url: URL,
        riffPolicy: RIFFMetadataWritePolicy,
        includeProperties: Bool,
        replacingCollections: Set<StructuredMetadataReplaceableCollection>,
        verifyAfterWrite: Bool,
        failurePolicy: VerificationFailurePolicy
    ) throws -> MetadataWriteResult {
        try writeStructuredMetadataWithVerification(
            metadata, to: url, riffPolicy: riffPolicy, includeProperties: includeProperties,
            replacingCollections: replacingCollections, verifyAfterWrite: verifyAfterWrite, expectedVersion: nil, failurePolicy: failurePolicy
        )
    }
}
