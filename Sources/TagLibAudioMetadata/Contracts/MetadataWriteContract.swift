import Foundation

extension TagLibMetadataManager {
    public enum ArtworkVerificationExpectation: Sendable {
        /// Skip artwork verification. This is the default.
        case skip
        case present
        case absent
    }

    public struct MetadataWriteVerificationContext: Equatable, Sendable {
        public var expectedTrackNumber: Int?
        public var expectedTrackTotal: Int?
        public var expectedTrackNumberText: String?
        public var expectedDiscNumber: Int?
        public var expectedDiscTotal: Int?
        public var expectedDiscNumberText: String?
        /// `.unspecified` requires native absence unless an expected unknown
        /// raw code is also supplied below. Nil skips the semantic comparison.
        public var expectedExplicitAdvisory: ExplicitAdvisory?
        /// Exact unknown-code provenance. Together with `.unspecified`, this
        /// verifies preservation rather than absence. A non-nil value is also
        /// an independent verification request when the semantic state is nil.
        public var expectedExplicitAdvisoryRawValue: String? = nil
        public var artworkExpectation: ArtworkVerificationExpectation
        /// Optional exact artwork expectations, independent of the legacy presence check.
        public var expectedArtworkData: Data? = nil
        public var expectedArtworkMIMEType: String? = nil
        public var customFieldKeys: [String]
        /// Expected custom-field values keyed by custom field name. When
        /// present, verification compares the value instead of only checking
        /// that the key still exists.
        public var customFieldValues: [String: String]
        /// Supported keys are the camel-case names in `textFieldValue`, such as
        /// `title`, `artist`, `encodedBy`, and `encoderSettings`. Passing a raw
        /// PropertyMap key such as `TITLE` produces a false mismatch.
        public var expectedTextFields: [String: String]

        public init(
            expectedTrackNumber: Int?,
            expectedTrackTotal: Int?,
            expectedTrackNumberText: String?,
            expectedDiscNumber: Int?,
            expectedDiscTotal: Int?,
            expectedDiscNumberText: String?,
            artworkExpectation: ArtworkVerificationExpectation,
            customFieldKeys: [String],
            expectedTextFields: [String: String] = [:],
            expectedExplicitAdvisory: ExplicitAdvisory? = nil,
            customFieldValues: [String: String] = [:]
        ) {
            self.expectedTrackNumber = expectedTrackNumber
            self.expectedTrackTotal = expectedTrackTotal
            self.expectedTrackNumberText = expectedTrackNumberText
            self.expectedDiscNumber = expectedDiscNumber
            self.expectedDiscTotal = expectedDiscTotal
            self.expectedDiscNumberText = expectedDiscNumberText
            self.expectedExplicitAdvisory = expectedExplicitAdvisory
            self.artworkExpectation = artworkExpectation
            self.customFieldKeys = customFieldKeys
            self.customFieldValues = customFieldValues
            self.expectedTextFields = expectedTextFields
        }

        public nonisolated static let none = MetadataWriteVerificationContext(
            expectedTrackNumber: nil,
            expectedTrackTotal: nil,
            expectedTrackNumberText: nil,
            expectedDiscNumber: nil,
            expectedDiscTotal: nil,
            expectedDiscNumberText: nil,
            artworkExpectation: .skip,
            customFieldKeys: [],
            expectedTextFields: [:],
            customFieldValues: [:]
        )
    }

    public enum MetadataCommitStatus: Equatable, Sendable {
        /// Atomic replacement and a requested `F_FULLFSYNC` (or `fsync` fallback)
        /// of the staged file plus the parent-directory sync completed. This is
        /// an OS-level flush, not a hardware/power-loss guarantee.
        case durable

        /// Atomic replacement completed and the new metadata is visible, but the
        /// final parent-directory durability sync failed. Callers must not retry
        /// as though the mutation did not commit.
        case durabilityUncertain(String)
    }

    public struct MetadataWriteResult: Sendable {
        public var warnings: [String]
        public var commitStatus: MetadataCommitStatus

        public init(
            warnings: [String],
            commitStatus: MetadataCommitStatus = .durable
        ) {
            self.warnings = warnings
            self.commitStatus = commitStatus
        }
    }

    public enum RawPropertyMapWriteMode: Sendable {
        /// Replace the file's visible TagLib PropertyMap with the provided keys.
        /// Opaque native structures are not reconstructed by this operation. On
        /// WAV, RIFF INFO is a separate surface; omitted INFO fields can remain
        /// and cause verification to fail. Use `.merge` or a structured
        /// `.id3v2Only` write when preservation or INFO removal is intended.
        case replace

        /// Apply a delta to the current TagLib PropertyMap. Omitted keys and
        /// native structures are preserved. Empty values remove matching keys.
        case merge
    }

}
