import Foundation
import Darwin
import Testing
import TagLibAudioMetadata
import CTagLibBridge

struct CleanRoomPrivilegeTests {
    @Test func privilegedFilesRejectBeforeCloneInBothTransactionEngines() throws {
        for permissions: mode_t in [0o4644, 0o2644, 0o6644] {
            try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
                let original = try Data(contentsOf: url)
                try #require(chown(url.path, getuid(), getgid()) == 0)
                try #require(chmod(url.path, permissions) == 0)
                var before = stat()
                try #require(lstat(url.path, &before) == 0)
                try #require(before.st_mode & 0o7777 == permissions)
                #expect(throws: TagLibManagerError.self) {
                    try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Must not commit" }
                }
                #expect(throws: (any Error).self) {
                    try TagLibMetadataExtractor.writeTrackNumber(7, totalTracks: 12, padWidth: 2, to: url)
                }
                var after = stat()
                try #require(lstat(url.path, &after) == 0)
                #expect(after.st_ino == before.st_ino)
                #expect(after.st_mode == before.st_mode)
                #expect(try Data(contentsOf: url) == original)
            }
        }
    }
}
