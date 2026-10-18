import Foundation
import Darwin
import Testing
@testable import TagLibAudioMetadata

struct HardeningReadConsistencyTests {
    @Test func snapshotsRejectDeterministicChangesDuringConstruction() throws {
        for basicOnly in [false, true] {
            for replaceEntry in [false, true] {
                try HardeningFixture.withCopy("flac", name: "testAudioFile") { url in
                    let initial = try TagLibMetadataManager.readSnapshot(from: url)
                    #expect(initial.fileVersion == (try TagLibMetadataManager.fileVersion(at: url)))
                    var extracted = false
                    let mutate = {
                        extracted = true
                        if replaceEntry {
                            let replacement = url.deletingLastPathComponent().appendingPathComponent("replacement.flac")
                            try FileManager.default.copyItem(at: url, to: replacement)
                            // Keep the bytes and size identical: inode identity must
                            // detect this replacement even without content changes.
                            guard rename(replacement.path, url.path) == 0 else {
                                throw POSIXError(.EIO)
                            }
                        } else {
                            let handle = try FileHandle(forWritingTo: url)
                            defer { try? handle.close() }
                            try handle.seekToEnd()
                            try handle.write(contentsOf: Data([0]))
                        }
                    }
                    do {
                        if basicOnly {
                            _ = try TagLibMetadataManager.readBasicSnapshot(from: url, afterExtraction: mutate)
                        } else {
                            _ = try TagLibMetadataManager.readSnapshot(from: url, afterExtraction: mutate)
                        }
                        Issue.record("A changed file must not return the extracted snapshot")
                    } catch TagLibManagerError.fileChanged {
                        #expect(extracted)
                    }
                    let changed = try Data(contentsOf: url)
                    do {
                        try TagLibMetadataManager.applyMetadataPatch(
                            .init(fields: [.title: .text("Stale snapshot")]), to: url,
                            expectedVersion: initial.fileVersion)
                        Issue.record("A stale token must not commit")
                    } catch TagLibManagerError.fileChanged {}
                    #expect(try Data(contentsOf: url) == changed)
                    let fresh = try TagLibMetadataManager.readBasicSnapshot(from: url)
                    #expect(fresh.fileVersion == (try TagLibMetadataManager.fileVersion(at: url)))
                }
            }
        }
    }

    @Test func snapshotRejectsMetadataEditAfterExtractionAndNormalReadSucceeds() throws {
        try HardeningFixture.withCopy("flac", name: "testAudioFile") { url in
            do {
                _ = try TagLibMetadataManager.readSnapshot(from: url, afterExtraction: {
                    try TagLibMetadataManager.applyRawMetadataPatch(
                        .init(valuesToSet: ["TITLE": ["Externally changed metadata"]]), to: url)
                })
                Issue.record("Do not return old metadata with a new version")
            } catch TagLibManagerError.fileChanged {}
            let fresh = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(fresh.basic.title == "Externally changed metadata")
            #expect(fresh.fileVersion == (try TagLibMetadataManager.fileVersion(at: url)))
        }
    }
}
