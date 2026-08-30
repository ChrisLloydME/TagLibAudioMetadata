//
//  TagLibMetadataManager.swift
//  TagLibAudioMetadata
//

import Foundation
import Darwin
@_exported import CTagLibBridge

public struct TagLibMetadataManager {

    nonisolated private static let errorDomain = "TagLibMetadataManager"

    nonisolated struct FileIdentity: Equatable {
        var device: dev_t
        var inode: ino_t
        var size: off_t
        var modificationTime: timespec
        var statusChangeTime: timespec

        static func == (lhs: FileIdentity, rhs: FileIdentity) -> Bool {
            lhs.device == rhs.device &&
                lhs.inode == rhs.inode &&
                lhs.size == rhs.size &&
                lhs.modificationTime.tv_sec == rhs.modificationTime.tv_sec &&
                lhs.modificationTime.tv_nsec == rhs.modificationTime.tv_nsec &&
                lhs.statusChangeTime.tv_sec == rhs.statusChangeTime.tv_sec &&
                lhs.statusChangeTime.tv_nsec == rhs.statusChangeTime.tv_nsec
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

    /// Runs the complete mutation and verification sequence on a sibling copy.
    /// The destination is replaced with a same-volume atomic rename only after
    /// every step succeeds, so thrown bridge or verification errors preserve it.
    nonisolated static func withAtomicFileMutation<Result>(
        at url: URL,
        _ operation: (URL) throws -> Result
    ) throws -> Result {
        guard url.isFileURL else {
            throw mutationError(code: 1001, description: "Metadata mutations require a file URL.")
        }

        guard let originalIdentity = regularFileIdentity(at: url) else {
            throw mutationError(
                code: 1003,
                description: "Metadata mutations require an existing regular file and do not follow symbolic links."
            )
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
            throw mutationError(
                code: 1005,
                description: "The metadata destination changed before the transaction could commit."
            )
        }

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
        return result
    }

    nonisolated static let hiddenInternalRawFieldKeys: Set<String> = [
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

    public struct MetadataWriteResult: Sendable {
        public var warnings: [String]

        public init(warnings: [String]) {
            self.warnings = warnings
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

    public enum VerificationFailurePolicy: Sendable {
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
