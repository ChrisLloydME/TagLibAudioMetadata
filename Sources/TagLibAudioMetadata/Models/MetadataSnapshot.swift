import Foundation

/// An opaque local-file version, for optimistic edits based on a snapshot.
/// This detects observed filesystem changes; it is not a cross-process lock or
/// a content digest. Uncooperative external writers can still race a commit.
public struct MetadataFileVersion: Hashable, Sendable {
    private let device: Int64
    private let inode: UInt64
    private let size: Int64
    private let links: UInt64
    private let modifiedSeconds: Int64
    private let modifiedNanoseconds: Int64
    private let changedSeconds: Int64
    private let changedNanoseconds: Int64

    nonisolated init(
        device: Int64,
        inode: UInt64,
        size: Int64,
        links: UInt64,
        modifiedSeconds: Int64,
        modifiedNanoseconds: Int64,
        changedSeconds: Int64,
        changedNanoseconds: Int64
    ) {
        self.device = device
        self.inode = inode
        self.size = size
        self.links = links
        self.modifiedSeconds = modifiedSeconds
        self.modifiedNanoseconds = modifiedNanoseconds
        self.changedSeconds = changedSeconds
        self.changedNanoseconds = changedNanoseconds
    }
}

/// A comprehensive semantic metadata snapshot for professional editing.
///
/// `BasicMetadata` is a normalized convenience projection. The raw and structured
/// representations retain value cardinality and supported container-specific entries.
/// Unsupported or opaque native frames/items may be summarized rather than copied as
/// reconstructable payloads, so this is not a lossless native serialization.
public struct MetadataSnapshot: Sendable {
    public var basic: BasicMetadata
    public var raw: RawMetadataDump
    public var structured: StructuredMetadata
    public let fileVersion: MetadataFileVersion?
    /// Nil unless explicitly requested and supported. Two nil values do not prove continuity.
    public let audioContentIdentity: MetadataAudioContentIdentity?
    var supportsMP4EditorFields = false

    /// Writable native non-PropertyMap MP4 fields (iTunes Store/account atoms,
    /// Explicit advisory, and native text atoms) for a snapshot read from an
    /// MP4-family file or constructed with MP4 atoms, including rows with absent
    /// atoms. Text aliases remain in `raw.properties` with their own storage identity.
    public nonisolated var editableMP4Fields: [MP4MetadataEditorField] {
        guard supportsMP4EditorFields || !structured.mp4Atoms.isEmpty else { return [] }
        return TagLibMetadataManager.mp4EditorFieldKeys.compactMap { field in
            guard let target = MetadataFieldRegistry.schema(for: field)?.writeTarget(for: .mp4) else {
                return nil
            }
            return MP4MetadataEditorField(
                field: field,
                atomKey: target.nativeIdentity,
                atom: structured.mp4Atoms.first { $0.key == target.nativeIdentity }
            )
        }
    }

    public init(
        basic: BasicMetadata,
        raw: RawMetadataDump,
        structured: StructuredMetadata,
        fileVersion: MetadataFileVersion? = nil,
        audioContentIdentity: MetadataAudioContentIdentity? = nil
    ) {
        self.basic = basic
        self.raw = raw
        self.structured = structured
        self.fileVersion = fileVersion
        self.audioContentIdentity = audioContentIdentity
    }
}

/// A focused read for list/editor loading that needs normalized Basic metadata
/// and an optimistic-concurrency token, but not structured inspector models.
public struct BasicMetadataSnapshot: Sendable {
    public var metadata: BasicMetadata
    public let fileVersion: MetadataFileVersion
    /// Nil unless explicitly requested and supported. Two nil values do not prove continuity.
    public let audioContentIdentity: MetadataAudioContentIdentity?

    public init(
        metadata: BasicMetadata,
        fileVersion: MetadataFileVersion,
        audioContentIdentity: MetadataAudioContentIdentity? = nil
    ) {
        self.metadata = metadata
        self.fileVersion = fileVersion
        self.audioContentIdentity = audioContentIdentity
    }
}

