//
//  TagLibMetadataManager.swift
//  TagLibAudioMetadata
//

import Foundation
import Darwin
import CTagLibBridge
import CTagLibBridgeInternalAPI

public struct TagLibMetadataManager {

    nonisolated private static let errorDomain = "TagLibMetadataManager"

    nonisolated struct FileIdentity: Equatable {
        var device: dev_t
        var inode: ino_t
        var size: off_t
        var linkCount: nlink_t
        var modificationTime: timespec
        var statusChangeTime: timespec

        static func == (lhs: FileIdentity, rhs: FileIdentity) -> Bool {
            lhs.device == rhs.device &&
                lhs.inode == rhs.inode &&
                lhs.size == rhs.size &&
                lhs.linkCount == rhs.linkCount &&
                lhs.modificationTime.tv_sec == rhs.modificationTime.tv_sec &&
                lhs.modificationTime.tv_nsec == rhs.modificationTime.tv_nsec &&
                lhs.statusChangeTime.tv_sec == rhs.statusChangeTime.tv_sec &&
                lhs.statusChangeTime.tv_nsec == rhs.statusChangeTime.tv_nsec
        }

        func hasSameReadableContents(as other: FileIdentity?) -> Bool {
            guard let other else { return false }
            return device == other.device &&
                inode == other.inode &&
                size == other.size &&
                modificationTime.tv_sec == other.modificationTime.tv_sec &&
                modificationTime.tv_nsec == other.modificationTime.tv_nsec
        }
    }

    nonisolated static func regularFileIdentity(at url: URL) -> FileIdentity? {
        var information = stat()
        let status = url.path.withCString { path in
            Darwin.lstat(path, &information)
        }
        let fileType = information.st_mode & mode_t(S_IFMT)
        guard status == 0, fileType == mode_t(S_IFREG) else { return nil }
        return FileIdentity(
            device: information.st_dev,
            inode: information.st_ino,
            size: information.st_size,
            linkCount: information.st_nlink,
            modificationTime: information.st_mtimespec,
            statusChangeTime: information.st_ctimespec
        )
    }

    nonisolated private static func mutationError(
        code: Int,
        description: String,
        underlying: Error? = nil
    ) -> NSError {
        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: description]
        if let underlying {
            userInfo[NSUnderlyingErrorKey] = underlying
        }
        return NSError(domain: errorDomain, code: code, userInfo: userInfo)
    }

    enum FileMutationDurability: Sendable {
        case durable
        case uncertain(String)
    }

    struct FileMutationOutcome<Result> {
        let result: Result
        let durability: FileMutationDurability
    }

    /// Runs the complete mutation and verification sequence on a sibling copy.
    /// The destination is replaced with a same-volume atomic rename only after
    /// every pre-commit step succeeds. The file is synced before rename and the
    /// parent directory is synced afterward for stronger durability.
    nonisolated static func withAtomicFileMutation<Result>(
        at url: URL,
        expectedVersion: MetadataFileVersion? = nil,
        directorySync: @escaping (Int32) -> Int32 = Darwin.fsync,
        afterFinalValidation: @escaping () throws -> Void = {},
        _ operation: @escaping (URL) throws -> Result
    ) throws -> Result {
        let outcome = try withAtomicFileMutationOutcome(
            at: url,
            expectedVersion: expectedVersion,
            directorySync: directorySync,
            afterFinalValidation: afterFinalValidation,
            operation
        )
        switch outcome.durability {
        case .durable:
            return outcome.result
        case .uncertain(let detail):
            throw TagLibManagerError.committedButDurabilityUncertain(detail)
        }
    }

    /// Variant used by high-level writes, where post-rename durability uncertainty
    /// is a committed result rather than an exception that invites blind retry.
    nonisolated static func withAtomicMetadataWriteMutation(
        at url: URL,
        expectedVersion: MetadataFileVersion? = nil,
        directorySync: @escaping (Int32) -> Int32 = Darwin.fsync,
        _ operation: @escaping (URL) throws -> MetadataWriteResult
    ) throws -> MetadataWriteResult {
        let outcome = try withAtomicFileMutationOutcome(
            at: url,
            expectedVersion: expectedVersion,
            directorySync: directorySync,
            operation
        )
        var result = outcome.result
        switch outcome.durability {
        case .durable:
            result.commitStatus = .durable
        case .uncertain(let detail):
            result.commitStatus = .durabilityUncertain(detail)
        }
        return result
    }

    nonisolated private static func withAtomicFileMutationOutcome<Result>(
        at url: URL,
        expectedVersion: MetadataFileVersion?,
        directorySync: @escaping (Int32) -> Int32,
        afterFinalValidation: @escaping () throws -> Void = {},
        _ operation: @escaping (URL) throws -> Result
    ) throws -> FileMutationOutcome<Result> {
        var outcome: FileMutationOutcome<Result>?
        var operationError: Error?
        do {
            try TagLibMetadataExtractor.coordinateMutation(at: url) { errorPointer in
                do {
                    outcome = try performAtomicFileMutation(
                        at: url,
                        expectedVersion: expectedVersion,
                        directorySync: directorySync,
                        afterFinalValidation: afterFinalValidation,
                        operation
                    )
                    return true
                } catch {
                    operationError = error
                    errorPointer?.pointee = error as NSError
                    return false
                }
            }
        } catch {
            throw operationError ?? error
        }

        guard let outcome else {
            throw operationError ?? mutationError(
                code: 1010,
                description: "Metadata transaction coordination failed."
            )
        }
        return outcome
    }

    nonisolated private static func performAtomicFileMutation<Result>(
        at url: URL,
        expectedVersion: MetadataFileVersion?,
        directorySync: (Int32) -> Int32,
        afterFinalValidation: () throws -> Void,
        _ operation: (URL) throws -> Result
    ) throws -> FileMutationOutcome<Result> {
        guard url.isFileURL else {
            throw mutationError(code: 1001, description: "Metadata mutations require a file URL.")
        }

        guard let originalIdentity = regularFileIdentity(at: url) else {
            throw mutationError(
                code: 1003,
                description: "Metadata mutations require an existing regular file and do not follow symbolic links."
            )
        }
        guard originalIdentity.linkCount == 1 else {
            throw TagLibManagerError.hardLinkedFile
        }
        if let expectedVersion, expectedVersion != MetadataFileVersion(originalIdentity) {
            throw TagLibManagerError.fileChanged
        }

        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        } catch {
            throw mutationError(
                code: 1002,
                description: "Could not inspect the metadata destination.",
                underlying: error
            )
        }

        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw mutationError(
                code: 1003,
                description: "Metadata mutations require an existing regular file and do not follow symbolic links."
            )
        }

        do {
            _ = try readMetadataResult(from: url)
        } catch {
            throw mutationError(
                code: 1006,
                description: "The metadata destination is not a readable, valid audio file.",
                underlying: error
            )
        }

        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let baseName = url.deletingPathExtension().lastPathComponent
        let temporaryName = ext.isEmpty
            ? ".\(baseName).taglib-\(UUID().uuidString)"
            : ".\(baseName).taglib-\(UUID().uuidString).\(ext)"
        let temporaryURL = directory.appendingPathComponent(temporaryName)
        var shouldRemoveTemporaryFile = true

        defer {
            if shouldRemoveTemporaryFile {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }

        do {
            try fileManager.copyItem(at: url, to: temporaryURL)
        } catch {
            throw mutationError(
                code: 1004,
                description: "Could not create a transactional copy of the metadata destination.",
                underlying: error
            )
        }

        guard regularFileIdentity(at: temporaryURL) != nil else {
            throw mutationError(
                code: 1004,
                description: "The transactional metadata copy is not a regular file."
            )
        }

        let result = try operation(temporaryURL)
        let temporaryDescriptor = temporaryURL.path.withCString { temporaryPath in
            Darwin.open(temporaryPath, O_RDONLY)
        }
        guard temporaryDescriptor >= 0 else {
            let openErrorCode = errno
            throw mutationError(
                code: 1005,
                description: "Could not open the verified metadata mutation for flushing.",
                underlying: NSError(domain: NSPOSIXErrorDomain, code: Int(openErrorCode))
            )
        }

        guard Darwin.fsync(temporaryDescriptor) == 0 else {
            let syncErrorCode = errno
            Darwin.close(temporaryDescriptor)
            throw mutationError(
                code: 1005,
                description: "Could not flush the verified metadata mutation before commit.",
                underlying: NSError(domain: NSPOSIXErrorDomain, code: Int(syncErrorCode))
            )
        }
        Darwin.close(temporaryDescriptor)

        guard regularFileIdentity(at: url) == originalIdentity else {
            throw TagLibManagerError.fileChanged
        }

        // Internal test seam for the check/rename interval. Production callers
        // never supply work here; same-entry coordination still owns the lock.
        try afterFinalValidation()

        let directoryDescriptor = directory.path.withCString { directoryPath in
            Darwin.open(directoryPath, O_RDONLY | O_DIRECTORY)
        }
        guard directoryDescriptor >= 0 else {
            let openErrorCode = errno
            throw mutationError(
                code: 1005,
                description: "Could not open the metadata destination directory for flushing.",
                underlying: NSError(domain: NSPOSIXErrorDomain, code: Int(openErrorCode))
            )
        }
        defer { Darwin.close(directoryDescriptor) }

        let renameResult = temporaryURL.path.withCString { temporaryPath in
            url.path.withCString { destinationPath in
                Darwin.rename(temporaryPath, destinationPath)
            }
        }
        let renameErrorCode = errno

        guard renameResult == 0 else {
            let underlying = NSError(domain: NSPOSIXErrorDomain, code: Int(renameErrorCode))
            throw mutationError(
                code: 1005,
                description: "Could not atomically commit the metadata mutation.",
                underlying: underlying
            )
        }

        shouldRemoveTemporaryFile = false
        guard directorySync(directoryDescriptor) == 0 else {
            let syncErrorCode = errno
            return FileMutationOutcome(
                result: result,
                durability: .uncertain(
                    "Directory fsync failed with POSIX error \(syncErrorCode). The metadata mutation is already committed; retrying may repeat it."
                )
            )
        }
        return FileMutationOutcome(result: result, durability: .durable)
    }

    nonisolated static let hiddenInternalRawFieldKeys: Set<String> = [
        "TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT",
        "TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT",
        "AUDIOMATOR_TRACKNUMBER_TEXT",
        "AUDIOMATOR_DISCNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:AUDIOMATOR_TRACKNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:AUDIOMATOR_DISCNUMBER_TEXT",
    ]

    public enum ArtworkVerificationExpectation: Sendable {
        case unchanged
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
        public var expectedExplicitContent: Bool?
        public var expectedExplicitAdvisory: ExplicitAdvisory?
        public var artworkExpectation: ArtworkVerificationExpectation
        public var customFieldKeys: [String]
        public var expectedTextFields: [String: String]

        public init(
            expectedTrackNumber: Int?,
            expectedTrackTotal: Int?,
            expectedTrackNumberText: String?,
            expectedDiscNumber: Int?,
            expectedDiscTotal: Int?,
            expectedDiscNumberText: String?,
            expectedExplicitContent: Bool?,
            artworkExpectation: ArtworkVerificationExpectation,
            customFieldKeys: [String],
            expectedTextFields: [String: String] = [:],
            expectedExplicitAdvisory: ExplicitAdvisory? = nil
        ) {
            self.expectedTrackNumber = expectedTrackNumber
            self.expectedTrackTotal = expectedTrackTotal
            self.expectedTrackNumberText = expectedTrackNumberText
            self.expectedDiscNumber = expectedDiscNumber
            self.expectedDiscTotal = expectedDiscTotal
            self.expectedDiscNumberText = expectedDiscNumberText
            self.expectedExplicitContent = expectedExplicitContent
            self.expectedExplicitAdvisory = expectedExplicitAdvisory
            self.artworkExpectation = artworkExpectation
            self.customFieldKeys = customFieldKeys
            self.expectedTextFields = expectedTextFields
        }

        public nonisolated static let none = MetadataWriteVerificationContext(
            expectedTrackNumber: nil,
            expectedTrackTotal: nil,
            expectedTrackNumberText: nil,
            expectedDiscNumber: nil,
            expectedDiscTotal: nil,
            expectedDiscNumberText: nil,
            expectedExplicitContent: nil,
            artworkExpectation: .unchanged,
            customFieldKeys: [],
            expectedTextFields: [:]
        )
    }

    public enum MetadataCommitStatus: Equatable, Sendable {
        /// Atomic replacement and the parent-directory durability sync completed.
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
        /// Replace the file's TagLib PropertyMap with exactly the provided key/value pairs.
        case replace

        /// Merge the provided key/value pairs into the current TagLib PropertyMap.
        ///
        /// Empty values remove matching keys, mirroring the bridge's existing trimming behavior.
        case merge
    }

    @available(*, deprecated, message: "Verification mismatches always abort the transaction. Omit the obsolete failurePolicy parameter.")
    public enum VerificationFailurePolicy: Sendable {
        @available(*, unavailable, message: "Verification mismatches invalidate the transaction and always throw. Use .throw.")
        case warn
        case `throw`
    }

    public nonisolated static func isReadableFormat(_ fileExtension: String) -> Bool {
        TagLibMetadataExtractor.isSupportedFormat(fileExtension)
    }

    public nonisolated static func isWritableFormat(_ fileExtension: String) -> Bool {
        TagLibMetadataExtractor.isWritableFormat(fileExtension)
    }

    public nonisolated static var readableExtensions: [String] {
        TagLibMetadataExtractor.supportedExtensions()
    }

    public nonisolated static var writableExtensions: [String] {
        TagLibMetadataExtractor.writableExtensions()
    }

}
