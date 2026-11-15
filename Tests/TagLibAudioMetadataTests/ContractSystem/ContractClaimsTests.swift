import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

enum ContractClaimsPaths {
    static var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ContractSystem
            .deletingLastPathComponent() // TagLibAudioMetadataTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repository root
    }

    static var fieldClaims: URL {
        root.appendingPathComponent("scripts/package-test-system/field-schema-claims.json")
    }

    static var formatClaims: URL {
        root.appendingPathComponent("scripts/package-test-system/format-capability-claims.json")
    }
}

/// Enumerates production claims for review. These snapshots are not golden
/// behavior targets: the catalog's expected native owners remain test-owned
/// literals. A changed field, target, capability or support level makes this
/// test fail until the snapshot and coverage decisions are reviewed together.
struct ContractClaimsTests {
    @Test func fieldSchemaMatchesReviewedClaims() throws {
        let snapshot = Self.fieldSnapshot()
        let path = ContractClaimsPaths.fieldClaims
        if ProcessInfo.processInfo.environment["TAGLIB_WRITE_CLAIMS"] == "1" {
            try Self.write(snapshot, to: path)
            return
        }
        let expected = try Self.load(path)
        #expect(NSDictionary(dictionary: snapshot).isEqual(to: expected),
                "field schema claims drifted from \(path.path)")
    }

    @Test func formatCapabilitiesMatchReviewedClaims() throws {
        let snapshot = Self.formatSnapshot()
        let path = ContractClaimsPaths.formatClaims
        if ProcessInfo.processInfo.environment["TAGLIB_WRITE_CLAIMS"] == "1" {
            try Self.write(snapshot, to: path)
            return
        }
        let expected = try Self.load(path)
        #expect(NSDictionary(dictionary: snapshot).isEqual(to: expected),
                "format capability claims drifted from \(path.path)")
    }

    private static func write(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
        try data.write(to: url, options: .atomic)
    }

    private static func load(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ContractOracleError.malformed("claims file is not an object: \(url.path)")
        }
        return object
    }

    private static func fieldSnapshot() -> [String: Any] {
        let fields: [[String: Any]] = MetadataFieldKey.allCases
            .sorted { $0.rawValue < $1.rawValue }
            .compactMap { key in
                guard let schema = MetadataFieldRegistry.schema(for: key) else { return nil }
                var entry: [String: Any] = [
                    "key": key.rawValue,
                    "displayName": schema.displayName,
                    "category": schema.category.rawValue,
                    "semanticKey": schema.semanticKey,
                    "propertyMapKeys": schema.propertyMapKeys.sorted(),
                    "isMultiValue": schema.isMultiValue,
                    "isPeopleField": schema.isPeopleField,
                    "isRoleQualified": schema.isRoleQualified,
                    "isArtworkField": schema.isArtworkField,
                    "acceptedPatchValueKinds": schema.acceptedPatchValueKinds.map(\.rawValue).sorted(),
                    "targets": schema.nativeTargets.map { target in
                        [
                            "family": target.family.rawValue,
                            "storage": target.storage.rawValue,
                            "nativeIdentity": target.nativeIdentity,
                            "shape": target.shape.rawValue,
                            "preferredWrite": target.preferredWrite,
                            "numberComponent": target.numberComponent?.rawValue ?? NSNull(),
                        ] as [String: Any]
                    },
                ]
                entry["writeUnsupportedReason"] = schema.writeUnsupportedReason ?? NSNull()
                if let constraint = schema.integerConstraint {
                    entry["integerConstraint"] = ["minimum": constraint.minimum, "maximum": constraint.maximum]
                }
                return entry
            }
        return [
            "schema_version": 1,
            "mapping_contract_version": MetadataMappingCatalog.contractVersion,
            "field_count": fields.count,
            "fields": fields,
        ]
    }

    private static func formatSnapshot() -> [String: Any] {
        let capabilities: [[String: Any]] = TagLibMetadataManager.formatCapabilities
            .sorted { $0.identifier < $1.identifier }
            .map { capability in
                var entry: [String: Any] = [
                    "identifier": capability.identifier,
                    "displayName": capability.displayName,
                    "codecName": capability.codecName,
                    "primaryExtension": capability.primaryExtension,
                    "extensions": capability.extensions.sorted(),
                    "containers": capability.containers.sorted(),
                    "isReadable": capability.isReadable,
                    "isWritable": capability.isWritable,
                    "canReadArtwork": capability.canReadArtwork,
                    "canWriteArtwork": capability.canWriteArtwork,
                    "preservesMultiValueProperties": capability.preservesMultiValueProperties,
                    "structuredReadSupport": capability.structuredReadSupport.rawValue,
                    "structuredWriteSupport": capability.structuredWriteSupport.rawValue,
                    "supportLevel": capability.supportLevel.rawValue,
                    "extensionSupportLevels": capability.extensionSupportLevels
                        .mapValues(\.rawValue)
                        .sortedDictionary(),
                ]
                entry["readOnlyReason"] = capability.readOnlyReason ?? NSNull()
                entry["notes"] = capability.notes ?? NSNull()
                entry["readableFields"] = capability.readableFields.map { $0.map(\.rawValue).sorted() } ?? NSNull()
                entry["writableFields"] = capability.writableFields.map { $0.map(\.rawValue).sorted() } ?? NSNull()
                return entry
            }
        let extensions = TagLibMetadataManager.formatCapabilities.flatMap(\.extensions).sorted()
        return [
            "schema_version": 1,
            "capability_count": capabilities.count,
            "extensions": extensions,
            "capabilities": capabilities,
        ]
    }
}

private extension Dictionary where Key == String, Value == String {
    func sortedDictionary() -> [String: String] {
        Dictionary(uniqueKeysWithValues: sorted { $0.key < $1.key })
    }
}
