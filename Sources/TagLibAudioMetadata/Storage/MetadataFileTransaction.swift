import Foundation
import Darwin
import CTagLibBridge
import CTagLibBridgeInternalAPI

/// Owns coordinated staging, validation, atomic replacement and durability.
internal enum MetadataFileTransaction {
    nonisolated private static let errorDomain = "TagLibMetadataManager"

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
        directorySync: @escaping (Int32) -> Int32 = MetadataFileTransaction.fullSync,
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
        directorySync: @escaping (Int32) -> Int32 = MetadataFileTransaction.fullSync,
        _ operation: @escaping (URL) throws -> TagLibMetadataManager.MetadataWriteResult
    ) throws -> TagLibMetadataManager.MetadataWriteResult {
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

    /// Prefer macOS `F_FULLFSYNC` so `.durable` reflects a requested hardware
    /// cache flush. Filesystems that reject the request fall back to `fsync`;
    /// the commit status documentation still describes that weaker guarantee.
    nonisolated static func fullSync(_ descriptor: Int32) -> Int32 {
        guard descriptor >= 0 else { return -1 }
        if fcntl(descriptor, F_FULLFSYNC) == 0 {
            return 0
        }
        if errno == EINVAL || errno == ENOTSUP || errno == ENOTTY {
            return Darwin.fsync(descriptor)
        }
        return -1
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
            let underlying = operationError ?? error
            if let typed = underlying as? TagLibManagerError {
                throw typed
            }
            let nsError = underlying as NSError
            if nsError.domain == "TagLibMetadataExtractor" || nsError.domain == "TagLibMetadataManager" {
                throw TagLibManagerError.operationFailedWithUnderlying(nsError)
            }
            throw underlying
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

        guard let originalIdentity = MetadataFileIdentity.read(at: url) else {
            throw mutationError(
                code: 1003,
                description: "Metadata mutations require an existing regular file and do not follow symbolic links."
            )
        }
        guard originalIdentity.mode & mode_t(S_ISUID | S_ISGID) == 0 else {
            throw mutationError(code: 1012, description: "Metadata mutations reject files with setuid or setgid permissions; clear privilege bits explicitly before editing.")
        }
        guard originalIdentity.linkCount == 1 else {
            throw TagLibManagerError.hardLinkedFile
        }
        if let expectedVersion, expectedVersion != originalIdentity.version {
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
            try MetadataProjectionReader.validateReadableAudioFile(at: url)
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

        let copyResult = url.path.withCString { sourcePath in
            temporaryURL.path.withCString { destinationPath in
                copyfile(
                    sourcePath,
                    destinationPath,
                    nil,
                    copyfile_flags_t(COPYFILE_CLONE | COPYFILE_ACL)
                )
            }
        }
        guard copyResult == 0 else {
            let copyErrorCode = errno
            throw mutationError(
                code: 1004,
                description: "Could not create a transactional copy of the metadata destination.",
                underlying: NSError(domain: NSPOSIXErrorDomain, code: Int(copyErrorCode))
            )
        }

        guard MetadataFileIdentity.read(at: temporaryURL) != nil else {
            throw mutationError(
                code: 1004,
                description: "The transactional metadata copy is not a regular file."
            )
        }

        let result = try operation(temporaryURL)
        try MetadataProjectionReader.validateReadableAudioFile(at: temporaryURL)
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

        guard fullSync(temporaryDescriptor) == 0 else {
            let syncErrorCode = errno
            Darwin.close(temporaryDescriptor)
            throw mutationError(
                code: 1005,
                description: "Could not flush the verified metadata mutation before commit.",
                underlying: NSError(domain: NSPOSIXErrorDomain, code: Int(syncErrorCode))
            )
        }
        Darwin.close(temporaryDescriptor)

        guard MetadataFileIdentity.read(at: url) == originalIdentity else {
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

}
