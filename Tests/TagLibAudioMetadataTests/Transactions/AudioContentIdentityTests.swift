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

    @Test func guardedTypedAndRawRebasesRejectReplacementAudio() throws {
        for raw in [false, true] {
            for ext in ["wav", "aiff", "flac"] {
                try withFixture(ext) { url in
                    let baseline = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true)
                    let identity = try #require(baseline.audioContentIdentity)
                    try replacePayload(at: url, ext: ext)
                    let current = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
                    #expect(try #require(current.audioContentIdentity) != identity)
                    let replacedBytes = try Data(contentsOf: url)
                    do {
                        if raw {
                            try TagLibMetadataManager.applyRawMetadataPatch(
                                .init(valuesToSet: ["TITLE": ["Stale draft"]]), to: url,
                                expectedVersion: current.fileVersion, expectedAudioContent: identity)
                        } else {
                            try TagLibMetadataManager.applyMetadataPatch(
                                .init(fields: [.title: .text("Stale draft")]), to: url,
                                expectedVersion: current.fileVersion, expectedAudioContent: identity)
                        }
                        Issue.record("Fresh file version must not authorize a draft for different audio")
                    } catch MetadataAudioContentError.changed {}
                    #expect(try Data(contentsOf: url) == replacedBytes)
                    #expect(try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path) == [url.lastPathComponent])
                }
            }
        }
    }

    @Test func guardedRebasesAcceptMetadataOnlyChangesAndKeepVersionGuard() throws {
        for raw in [false, true] {
            for ext in ["wav", "aiff", "flac"] {
                try withFixture(ext) { url in
                    let baseline = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
                    let identity = try #require(baseline.audioContentIdentity)
                    // Force tag growth so an identity cannot accidentally depend on
                    // total size, tag padding, audio offset, or destination inode.
                    let album = String(repeating: "External album ", count: 1_000)
                    try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.album: .text(album)]), to: url)
                    let current = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true)
                    let version = try #require(current.fileVersion)
                    #expect(current.audioContentIdentity == identity)
                    #expect(current.basic.album == album.trimmingCharacters(in: .whitespaces))
                    let before = try Data(contentsOf: url)
                    do {
                        if raw {
                            try TagLibMetadataManager.applyRawMetadataPatch(
                                .init(valuesToSet: ["TITLE": ["Rebased draft"]]), to: url,
                                expectedVersion: baseline.fileVersion, expectedAudioContent: identity)
                        } else {
                            try TagLibMetadataManager.applyMetadataPatch(
                                .init(fields: [.title: .text("Rebased draft")]), to: url,
                                expectedVersion: baseline.fileVersion, expectedAudioContent: identity)
                        }
                        Issue.record("Matching audio must not bypass a stale expected version")
                    } catch TagLibManagerError.fileChanged {}
                    #expect(try Data(contentsOf: url) == before)
                    if raw {
                        try TagLibMetadataManager.applyRawMetadataPatch(
                            .init(valuesToSet: ["TITLE": ["Rebased draft"]]), to: url,
                            expectedVersion: version, expectedAudioContent: identity)
                    } else {
                        try TagLibMetadataManager.applyMetadataPatch(
                            .init(fields: [.title: .text("Rebased draft")]), to: url,
                            expectedVersion: version, expectedAudioContent: identity)
                    }
                    let final = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true)
                    #expect(final.basic.title == "Rebased draft")
                    #expect(final.basic.album == current.basic.album)
                    #expect(final.audioContentIdentity == identity)
                }
            }
        }
    }

    @Test func guardedRebasesFailClosedWhenCurrentLayoutIsUnavailable() throws {
        let baselineURL = try HardeningFixture.url("wav", name: "testAudioFile")
        let snapshot = try TagLibMetadataManager.readBasicSnapshot(from: baselineURL, includingAudioContent: true)
        let identity = try #require(snapshot.audioContentIdentity)
        for raw in [false, true] {
            try withFixture("mp3") { url in
                let current = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
                #expect(current.audioContentIdentity == nil)
                let before = try Data(contentsOf: url)
                do {
                    if raw {
                        try TagLibMetadataManager.applyRawMetadataPatch(
                            .init(valuesToSet: ["TITLE": ["Unsupported rebase"]]), to: url,
                            expectedVersion: current.fileVersion, expectedAudioContent: identity)
                    } else {
                        try TagLibMetadataManager.applyMetadataPatch(
                            .init(fields: [.title: .text("Unsupported rebase")]), to: url,
                            expectedVersion: current.fileVersion, expectedAudioContent: identity)
                    }
                    Issue.record("Unsupported layout must not grant continuity")
                } catch MetadataAudioContentError.unavailable {}
                #expect(try Data(contentsOf: url) == before)
            }
        }
    }

    @Test func finalTransactionGuardStillRejectsChangesAfterAudioValidation() throws {
        try withFixture("wav") { url in
            let snapshot = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
            let identity = try #require(snapshot.audioContentIdentity)
            var replacedBytes = Data()
            do {
                _ = try TagLibMetadataManager.withAtomicMetadataWriteMutation(
                    at: url, expectedVersion: snapshot.fileVersion
                ) { temporary in
                    try TagLibMetadataManager.requireAudioContent(at: temporary, matching: identity)
                    // External writer does not participate in our entry coordinator.
                    try replacePayload(at: url, ext: "wav")
                    replacedBytes = try Data(contentsOf: url)
                    try TagLibMetadataManager.applyMetadataPatch(
                        .init(fields: [.title: .text("Must not commit")]), to: temporary)
                    return .init(warnings: [])
                }
                Issue.record("Final version guard must reject external replacement")
            } catch TagLibManagerError.fileChanged {}
            #expect(!replacedBytes.isEmpty)
            #expect(try Data(contentsOf: url) == replacedBytes)
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

    @Test func audioReaderRejectsChangesAfterStreamingBeforeFinalVersionCheck() throws {
        for replacement in [false, true] {
            try withFixture("wav") { url in
                let version = try TagLibMetadataManager.fileVersion(at: url)
                do {
                    _ = try TagLibMetadataManager.audioContentIdentity(at: url, version: version, afterAudioRead: {
                        if replacement {
                            let other = url.deletingLastPathComponent().appendingPathComponent("other.wav")
                            try FileManager.default.copyItem(at: url, to: other)
                            #expect(rename(other.path, url.path) == 0)
                        } else {
                            try replacePayload(at: url, ext: "wav")
                        }
                    })
                    Issue.record("Changed descriptor or path revision must invalidate the streamed token")
                } catch TagLibManagerError.fileChanged {}
            }
        }
    }

    @Test func aifcAndOddChunkPaddingRetainMetadataIndependence() throws {
        try withFixture("aiff") { url in
            let original = try Data(contentsOf: url)
            var converted = Data("FORM".utf8) + Data(repeating: 0, count: 4) + Data("AIFC".utf8)
            converted += Data("FVER".utf8) + HardeningFixture.number(4, bytes: 4) + Data([0xa2, 0x80, 0x51, 0x40])
            var position = 12
            while position < original.count {
                let count = try HardeningFixture.integer(original, position + 4, 4)
                let name = Data(original[position..<(position + 4)])
                if name == Data("COMM".utf8) {
                    let payload = original[(position + 8)..<(position + 8 + count)] + Data("NONE".utf8) + Data([0])
                    converted += name + HardeningFixture.number(UInt64(payload.count), bytes: 4) + payload
                    if payload.count % 2 != 0 { converted.append(0) }
                } else {
                    converted += original[position..<(position + 8 + count + count % 2)]
                }
                position += 8 + count + count % 2
            }
            // Odd, unknown chunks are hashed conservatively and padding is excluded.
            converted += Data("XTRA".utf8) + HardeningFixture.number(3, bytes: 4) + Data([1, 2, 3, 0])
            converted.replaceSubrange(4..<8, with: HardeningFixture.number(UInt64(converted.count - 8), bytes: 4))
            try converted.write(to: url)
            let baseline = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true)
            let identity = try #require(baseline.audioContentIdentity)
            var metadataOnly = converted + Data("NAME".utf8) + HardeningFixture.number(3, bytes: 4) + Data([65, 66, 67, 0])
            metadataOnly.replaceSubrange(4..<8, with: HardeningFixture.number(UInt64(metadataOnly.count - 8), bytes: 4))
            try metadataOnly.write(to: url)
            #expect(try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true).audioContentIdentity == identity)
            try TagLibMetadataManager.applyMetadataPatch(
                .init(fields: [.title: .text("AIFC title")]), to: url,
                expectedVersion: TagLibMetadataManager.fileVersion(at: url), expectedAudioContent: identity)
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "AIFC title")
            #expect(try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true).audioContentIdentity == identity)
            try replacePayload(at: url, ext: "aiff")
            let changed = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: true)
            #expect(try #require(changed.audioContentIdentity) != identity)
        }
    }

    /// A local cost probe, with no timing threshold. Files are generated by streaming
    /// a fixed 64 KiB buffer; the final-byte mutation also checks the entire payload
    /// is hashed rather than a prefix, a stored checksum, or sampled regions.
    @Test func streamingReadsCoverFullPayloadAndMeasureLocalCost() throws {
        try withFixture("wav") { url in
            let block = Data(repeating: 0x55, count: 65_536)
            for mebibytes in [1, 16, 64] {
                let payloadSize = UInt64(mebibytes) * 1_048_576
                var header = Data("RIFF".utf8) + HardeningFixture.number(payloadSize + 36, bytes: 4, little: true)
                header += Data("WAVEfmt ".utf8) + HardeningFixture.number(16, bytes: 4, little: true)
                header += Data([1, 0, 2, 0, 0x44, 0xac, 0, 0, 0x10, 0xb1, 2, 0, 4, 0, 16, 0])
                header += Data("data".utf8) + HardeningFixture.number(payloadSize, bytes: 4, little: true)
                let output = try FileHandle(forWritingTo: url)
                try output.truncate(atOffset: 0)
                try output.write(contentsOf: header)
                for _ in 0..<(mebibytes * 16) { try output.write(contentsOf: block) }
                try output.close()
                var identity: MetadataAudioContentIdentity?
                for sample in 1...3 {
                    let defaultCost = try ContinuousClock().measure {
                        let snapshot = try TagLibMetadataManager.readBasicSnapshot(from: url)
                        #expect(snapshot.audioContentIdentity == nil)
                    }
                    let audioCost = try ContinuousClock().measure {
                        let snapshot = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
                        let current = try #require(snapshot.audioContentIdentity)
                        if let identity { #expect(current == identity) }
                        identity = current
                    }
                    print("AUDIO_IDENTITY_COST audioMiB=\(mebibytes) sample=\(sample) default=\(defaultCost) withAudio=\(audioCost)")
                }
                let baseline = try #require(identity)
                try replacePayload(at: url, ext: "wav")
                let changed = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
                #expect(try #require(changed.audioContentIdentity) != baseline)
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
