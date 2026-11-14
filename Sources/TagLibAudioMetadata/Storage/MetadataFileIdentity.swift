import Foundation
import Darwin

nonisolated struct MetadataFileIdentity: Equatable {
    var device: dev_t
    var mode: mode_t
    var inode: ino_t
    var size: off_t
    var linkCount: nlink_t
    var modificationTime: timespec
    var statusChangeTime: timespec

    static func == (lhs: MetadataFileIdentity, rhs: MetadataFileIdentity) -> Bool {
        lhs.device == rhs.device &&
            lhs.inode == rhs.inode &&
            lhs.size == rhs.size &&
            lhs.linkCount == rhs.linkCount &&
            lhs.modificationTime.tv_sec == rhs.modificationTime.tv_sec &&
            lhs.modificationTime.tv_nsec == rhs.modificationTime.tv_nsec &&
            lhs.statusChangeTime.tv_sec == rhs.statusChangeTime.tv_sec &&
            lhs.statusChangeTime.tv_nsec == rhs.statusChangeTime.tv_nsec
    }

    func hasSameReadableContents(as other: MetadataFileIdentity?) -> Bool {
        guard let other else { return false }
        return device == other.device &&
            inode == other.inode &&
            size == other.size &&
            modificationTime.tv_sec == other.modificationTime.tv_sec &&
            modificationTime.tv_nsec == other.modificationTime.tv_nsec
    }

    nonisolated static func read(at url: URL) -> MetadataFileIdentity? {
        var information = stat()
        let status = url.path.withCString { path in
            Darwin.lstat(path, &information)
        }
        let fileType = information.st_mode & mode_t(S_IFMT)
        guard status == 0, fileType == mode_t(S_IFREG) else { return nil }
        return MetadataFileIdentity(
            device: information.st_dev,
            mode: information.st_mode,
            inode: information.st_ino,
            size: information.st_size,
            linkCount: information.st_nlink,
            modificationTime: information.st_mtimespec,
            statusChangeTime: information.st_ctimespec
        )
    }

    var version: MetadataFileVersion {
        MetadataFileVersion(
            device: Int64(device), inode: UInt64(inode), size: Int64(size), links: UInt64(linkCount),
            modifiedSeconds: Int64(modificationTime.tv_sec), modifiedNanoseconds: Int64(modificationTime.tv_nsec),
            changedSeconds: Int64(statusChangeTime.tv_sec), changedNanoseconds: Int64(statusChangeTime.tv_nsec)
        )
    }
}
