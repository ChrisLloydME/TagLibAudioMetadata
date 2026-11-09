//
//  MetadataMapping.swift
//  TagLibAudioMetadata
//

import Foundation

/// A concrete tag surface. ID3v2.3 and ID3v2.4 are separate families because
/// their native frame sets are not interchangeable.
public enum MetadataNativeFamily: String, CaseIterable, Hashable, Sendable {
    case id3v23
    case id3v24
    case mp4
    case vorbisComment
    case apev2
    case asf
    case riffInfo
    case matroska
}

/// How a native target is represented. The kind is descriptive; the exact
/// native identity and declared shape remain authoritative.
public enum MetadataNativeStorageKind: String, Hashable, Sendable {
    case textFrame
    case userTextFrame
    case extensionFrame
    case engineTextKey
    case extensionTextKey
    case qualifiedTextFrame
    case roleFrame
    case identifierFrame
    case binaryFrame
    case mp4Atom
    case mp4Freeform
    case mp4Integer
    case intPair
    case textKey
    case asfAttribute
    case riffInfoKey
    case complexProperty
    case matroskaSimpleTag
    case unsupported

    /// Extension or freeform storage is a declared convention, not a native
    /// standard slot for the family.
    public var isExtension: Bool {
        switch self {
        case .userTextFrame, .extensionFrame, .extensionTextKey, .mp4Freeform:
            true
        default:
            false
        }
    }
}

/// The value shape declared by the registry. The patch and native codecs must
/// agree with this shape before a write is staged.
public enum MetadataValueShape: String, CaseIterable, Hashable, Sendable {
    case text
    case textArray
    case integer
    case boolean
    case advisory
    case intPair
    case pictureCollection
    case roleText
    case opaque
}

public enum MetadataNumberComponent: String, CaseIterable, Hashable, Sendable {
    case number
    case total
}

/// One exact native read/write target for a semantic field.
public struct MetadataNativeTarget: Hashable, Sendable {
    public var family: MetadataNativeFamily
    public var storage: MetadataNativeStorageKind
    /// Exact native identity: frame ID, MP4 atom, freeform description, text
    /// key, ASF attribute name, Matroska tag name with its target level.
    public var nativeIdentity: String
    public var shape: MetadataValueShape
    /// Exactly one preferred write target is allowed per field/family, except
    /// for the two components of a shared numeric pair.
    public var preferredWrite: Bool
    public var numberComponent: MetadataNumberComponent?
    public var note: String?

    public init(
        family: MetadataNativeFamily,
        storage: MetadataNativeStorageKind,
        nativeIdentity: String,
        shape: MetadataValueShape,
        preferredWrite: Bool,
        numberComponent: MetadataNumberComponent? = nil,
        note: String? = nil
    ) {
        self.family = family
        self.storage = storage
        self.nativeIdentity = nativeIdentity
        self.shape = shape
        self.preferredWrite = preferredWrite
        self.numberComponent = numberComponent
        self.note = note
    }
}

/// The explicit target profile for one canonical semantic key.
public struct MetadataTargetProfile: Hashable, Sendable {
    public var semanticKey: String
    public var shape: MetadataValueShape
    public var targets: [MetadataNativeTarget]
    /// A concrete reason typed writes are withheld even though the field can be
    /// read and preserved.
    public var writeUnsupportedReason: String?

    public init(
        semanticKey: String,
        shape: MetadataValueShape,
        targets: [MetadataNativeTarget],
        writeUnsupportedReason: String? = nil
    ) {
        self.semanticKey = semanticKey
        self.shape = shape
        self.targets = targets
        self.writeUnsupportedReason = writeUnsupportedReason
    }

    public func targets(for family: MetadataNativeFamily) -> [MetadataNativeTarget] {
        targets.filter { $0.family == family }
    }

    public func writeTarget(for family: MetadataNativeFamily) -> MetadataNativeTarget? {
        targets.first { $0.family == family && $0.preferredWrite }
    }

    /// Capability state for a family. A location alone never establishes write
    /// support: a non-preferred registration is read-only, and an explicit
    /// profile reason withholds typed writes.
    public func capability(for family: MetadataNativeFamily) -> MetadataMappingCapability {
        let familyTargets = targets(for: family)
        guard !familyTargets.isEmpty else { return .unsupported }
        if family == .matroska {
            // Both MKV registrations are deliberate target-only gates: no typed
            // write capability is advertised until a verified native codec and
            // fixture coverage exist.
            return .unsupported
        }
        guard familyTargets.contains(where: \.preferredWrite) else { return .readOnly }
        if writeUnsupportedReason != nil { return .readOnly }
        if familyTargets.contains(where: { $0.preferredWrite && !$0.storage.isExtension }) {
            return .native
        }
        return .conventionalExtension
    }

    /// Lowest capability across the entire profile, used by capability views
    /// that cannot know the destination family.
    public var aggregateCapability: MetadataMappingCapability {
        let states = MetadataNativeFamily.allCases.map(capability(for:))
        if states.contains(.native) { return .native }
        if states.contains(.conventionalExtension) { return .conventionalExtension }
        if states.contains(.readOnly) { return .readOnly }
        return .unsupported
    }
}

/// Capability vocabulary required by the mapping contract.
public enum MetadataMappingCapability: String, CaseIterable, Hashable, Sendable {
    case native
    case conventionalExtension
    case readOnly
    case unsupported
    case ambiguous

    public var isWritable: Bool {
        self == .native || self == .conventionalExtension
    }
}

/// Round-trip and evidence details that remain separate from the capability
/// state. An extension-only lookup is advisory even when it round-trips.
public struct MetadataTargetCapability: Hashable, Sendable {
    public var family: MetadataNativeFamily
    public var capability: MetadataMappingCapability
    public var canRoundTrip: Bool
    public var normalizesText: Bool
    public var fixtureCovered: Bool
    public var reason: String?

    public init(
        family: MetadataNativeFamily,
        capability: MetadataMappingCapability,
        canRoundTrip: Bool,
        normalizesText: Bool,
        fixtureCovered: Bool,
        reason: String? = nil
    ) {
        self.family = family
        self.capability = capability
        self.canRoundTrip = canRoundTrip
        self.normalizesText = normalizesText
        self.fixtureCovered = fixtureCovered
        self.reason = reason
    }
}
