import Foundation
import CTagLibBridge
import CTagLibBridgeInternalAPI

/// A delta over TagLib's PropertyMap, not a replacement or a native-tag archive.
/// Keys omitted from both collections must remain unchanged. Array boundaries,
/// duplicate values, empty strings, and whitespace are significant. An empty
/// array is invalid: use `removingKeys` for deletion.
public struct RawMetadataPatch: Sendable {
    public var valuesToSet: [String: [String]]
    public var removingKeys: Set<String>

    public init(valuesToSet: [String: [String]] = [:], removingKeys: Set<String> = []) {
        self.valuesToSet = valuesToSet
        self.removingKeys = removingKeys
    }
}

public enum RawMetadataPatchError: Error, Sendable, LocalizedError {
    case invalidKey(String)
    case emptyArray(String)
    case conflictingKey(String)
    case embeddedNull(String)

    public var errorDescription: String? {
        switch self {
        case .invalidKey(let key): "Invalid or reserved PropertyMap key: \(key)"
        case .emptyArray(let key): "Use explicit removal to delete \(key); an empty value array is ambiguous."
        case .conflictingKey(let key): "Multiple changes target PropertyMap key \(key)."
        case .embeddedNull(let key): "PropertyMap field \(key) contains an unsupported null character."
        }
    }
}

extension TagLibMetadataManager {
    nonisolated static func exactPropertyValues(_ dump: RawMetadataDump) -> [String: [String]] {
        dump.properties.reduce(into: [:]) { result, entry in
            result[entry.key.uppercased(), default: []].append(contentsOf: entry.values)
        }
    }

    /// Applies one raw delta and verifies the complete visible PropertyMap before
    /// committing. Formats that cannot represent a requested value exactly fail
    /// without modifying the destination. Opaque native metadata is not exposed
    /// by PropertyMap and is not claimed to be verified by this comparison.
    @discardableResult
    public nonisolated static func applyRawMetadataPatch(
        _ patch: RawMetadataPatch,
        to url: URL,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        func validatedKey(_ key: String) throws -> String {
            let normalized = key.uppercased()
            guard !key.isEmpty,
                  key == key.trimmingCharacters(in: .whitespacesAndNewlines),
                  !key.contains("\0"),
                  !hiddenInternalRawFieldKeys.contains(normalized) else {
                throw RawMetadataPatchError.invalidKey(key)
            }
            return normalized
        }
        var values: [String: [String]] = [:]
        var removed: Set<String> = []
        for key in patch.removingKeys {
            let normalized = try validatedKey(key)
            guard removed.insert(normalized).inserted else { throw RawMetadataPatchError.conflictingKey(key) }
        }
        for (key, entries) in patch.valuesToSet {
            let normalized = try validatedKey(key)
            guard values[normalized] == nil, !removed.contains(normalized) else {
                throw RawMetadataPatchError.conflictingKey(key)
            }
            guard !entries.isEmpty else { throw RawMetadataPatchError.emptyArray(key) }
            guard entries.allSatisfy({ !$0.contains("\0") }) else { throw RawMetadataPatchError.embeddedNull(key) }
            values[normalized] = entries
        }
        guard !values.isEmpty || !removed.isEmpty else { return MetadataWriteResult(warnings: []) }
        guard isWritableFormat(url.pathExtension) else { throw TagLibManagerError.unsupportedFormat }
        let replacements = values
        let removals = removed
        return try withAtomicFileMutation(at: url, expectedVersion: expectedVersion) { temporary in
            var expected = exactPropertyValues(try rawMetadataResult(from: temporary))
            for key in removals { expected.removeValue(forKey: key) }
            for (key, entries) in replacements { expected[key] = entries }
            try TagLibMetadataExtractor.applyPropertyMapValuesInPlace(
                replacements, removingKeys: Array(removals), to: temporary
            )
            let actual = exactPropertyValues(try rawMetadataResult(from: temporary))
            let mismatches = Set(expected.keys).union(actual.keys).sorted().filter { expected[$0] != actual[$0] }
            guard mismatches.isEmpty else {
                throw TagLibManagerError.verificationFailed(mismatches.map { "PropertyMap field \($0) differs from the requested delta." })
            }
            return MetadataWriteResult(warnings: [])
        }
    }
}
