import Foundation
import Darwin
import Testing
@testable import TagLibAudioMetadata

struct AudioContentIdentityTests {
    private func withFixture(_ ext: String, _ body: (URL) throws -> Void) throws {
        try HardeningFixture.withCopy(ext, name: ext == "aiff" ? "clean-room" : "testAudioFile", body)
    }

    @Test func optInIdentitiesMatchAcrossSnapshotProjections() throws {
        for ext in ["wav", "aiff", "flac"] {
            try withFixture(ext) { url in
                #expect(try TagLibMetadataManager.readSnapshot(from: url).audioContentIdentity == nil)
                #expect(try TagLibMetadataManager.readBasicSnapshot(from: url).audioContentIdentity == nil)
                let full = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true)
                let basic = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
                let identity = try #require(full.audioContentIdentity, "\(ext)")
                #expect(basic.audioContentIdentity == identity)
                #expect(full.fileVersion == basic.fileVersion)
                #expect(full.basic.title == basic.metadata.title)
            }
        }
    }

    @Test func metadataEditsArtworkAndErasureRetainIdentity() throws {
        for ext in ["wav", "aiff", "flac"] {
            try withFixture(ext) { url in
                let baseline = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true)
                let identity = try #require(baseline.audioContentIdentity)
                func check() throws {
                    let fresh = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true)
                    #expect(fresh.audioContentIdentity == identity, "\(ext)")
                    #expect(fresh.fileVersion != baseline.fileVersion)
                }
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("Continuity title")]), to: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "Continuity title")
                try check()
                try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["ALBUM": ["Continuity album"]]), to: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).album == "Continuity album")
                try check()
                let cover = try Data(contentsOf: HardeningFixture.url("jpg", name: "testCover"))
                try TagLibMetadataManager.applyMetadataPatch(
                    .init(artwork: .replace([.init(mimeType: "image/jpeg", data: cover)])), to: url)
                #expect(try TagLibMetadataManager.readStructuredMetadataResult(from: url).artwork.contains { $0.data == cover })
                try check()
                try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url)
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).title.isEmpty)
                try check()
            }
        }
    }

    /// Changes actual data bytes, retaining path, inode, length and nanosecond mtime.
    private func replacePayload(at url: URL, ext: String) throws {
        let bytes = try Data(contentsOf: url)
        let offset: Int
        if ext == "flac" {
            var position = 4
            while true {
                let last = bytes[position] & 128 != 0
                position += 4 + (try HardeningFixture.integer(bytes, position + 1, 3))
                if last { break }
            }
            offset = bytes.count - 1
            #expect(offset >= position)
        } else {
            var position = 12
            let target = Data((ext == "wav" ? "data" : "SSND").utf8)
            while Data(bytes[position..<(position + 4)]) != target {
                let count = try HardeningFixture.integer(bytes, position + 4, 4, little: ext == "wav")
                position += 8 + count + count % 2
            }
            let count = try HardeningFixture.integer(bytes, position + 4, 4, little: ext == "wav")
            offset = position + 8 + count - 1
            #expect(count > 8)
        }
        var info = stat()
        #expect(lstat(url.path, &info) == 0)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset))
        try handle.write(contentsOf: Data([bytes[offset] ^ 0x55]))
        var times = [info.st_atimespec, info.st_mtimespec]
        #expect(futimens(handle.fileDescriptor, &times) == 0)
        var after = stat()
        #expect(lstat(url.path, &after) == 0)
        #expect(info.st_dev == after.st_dev && info.st_ino == after.st_ino && info.st_size == after.st_size)
        #expect(info.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec)
        #expect(info.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec)
    }

    @Test func sameInodePayloadReplacementChangesIdentity() throws {
        for ext in ["wav", "aiff", "flac"] {
            try withFixture(ext) { url in
                let baseline = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
                let identity = try #require(baseline.audioContentIdentity)
                try replacePayload(at: url, ext: ext)
                let current = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true)
                #expect(try #require(current.audioContentIdentity) != identity, "\(ext)")
            }
        }
    }

    @Test func unsupportedFormatsDoNotGrantContinuity() throws {
        for ext in ["mp3", "m4a", "ogg", "wv"] {
            try withFixture(ext) { url in
                let snapshot = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true)
                #expect(snapshot.audioContentIdentity == nil, "\(ext)")
            }
        }
    }

    @Test func malformedAndAmbiguousLayoutsAreUnavailable() throws {
        try withFixture("wav") { url in
            let original = try Data(contentsOf: url)
            func check(_ bytes: Data) throws {
                try bytes.write(to: url)
                let version = try TagLibMetadataManager.fileVersion(at: url)
                #expect(try TagLibMetadataManager.audioContentIdentity(at: url, version: version) == nil)
            }
            try check(Data())
            try check(Data("RIFF".utf8))
            var oversized = original
            oversized.replaceSubrange(4..<8, with: Data(repeating: 0xff, count: 4))
            try check(oversized)
            var truncated = original
            truncated.removeLast()
            try check(truncated)
            var duplicate = original + Data("data".utf8) + Data([2, 0, 0, 0, 0, 0])
            duplicate.replaceSubrange(4..<8, with: HardeningFixture.number(UInt64(duplicate.count - 8), bytes: 4, little: true))
            try check(duplicate)
        }
        try withFixture("flac") { url in
            var bytes = try Data(contentsOf: url)
            bytes[4] = (bytes[4] & 128) | 127
            try bytes.write(to: url)
            #expect(try TagLibMetadataManager.audioContentIdentity(at: url, version: TagLibMetadataManager.fileVersion(at: url)) == nil)
        }
    }

    @Test func interpretationParametersAlsoChangeIdentity() throws {
        for ext in ["wav", "aiff", "flac"] {
            try withFixture(ext) { url in
                let version = try TagLibMetadataManager.fileVersion(at: url)
                let baseline = try #require(try TagLibMetadataManager.audioContentIdentity(at: url, version: version))
                var bytes = try Data(contentsOf: url)
                let offset: Int
                if ext == "flac" {
                    offset = 18 // STREAMINFO sample-rate/channel/bit-depth area.
                } else {
                    var position = 12
                    let target = Data((ext == "wav" ? "fmt " : "COMM").utf8)
                    while Data(bytes[position..<(position + 4)]) != target {
                        let count = try HardeningFixture.integer(bytes, position + 4, 4, little: ext == "wav")
                        position += 8 + count + count % 2
                    }
                    offset = position + 8 + (ext == "wav" ? 4 : 8)
                }
                bytes[offset] ^= 1
                try bytes.write(to: url)
                let current = try TagLibMetadataManager.fileVersion(at: url)
                #expect(try TagLibMetadataManager.audioContentIdentity(at: url, version: current) != baseline)
            }
        }
    }

    @Test func audioSnapshotsRejectChangesBetweenExtractionAndReturn() throws {
        for basicOnly in [false, true] {
            try withFixture("wav") { url in
                let mutate = { try replacePayload(at: url, ext: "wav") }
                do {
                    if basicOnly {
                        _ = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true, afterExtraction: mutate)
                    } else {
                        _ = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true, afterExtraction: mutate)
                    }
                    Issue.record("A mixed-revision snapshot must not escape")
                } catch TagLibManagerError.fileChanged {}
            }
        }
    }
}
