import Foundation
import XCTest
@testable import TagLibAudioMetadata

final class ExternalCorpusPreservationTests: XCTestCase {
    func testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus() throws {
        guard let path = ProcessInfo.processInfo.environment["TAGLIB_PRESERVATION_CORPUS"] else {
            throw XCTSkip("Set TAGLIB_PRESERVATION_CORPUS to run additional application/corpus fixtures.")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TagLibCorpus-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sources = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: nil)
        let audioSources = sources.filter { TagLibMetadataManager.isWritableExtension($0.pathExtension) }
        guard !audioSources.isEmpty else {
            XCTFail("The corpus directory contains no writable audio fixtures: \(path)")
            return
        }
        print("PRESERVATION_CORPUS files=\(audioSources.count)")
        for source in audioSources {
            print("PRESERVATION_CORPUS file=\(source.lastPathComponent)")
            let url = directory.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: url)
            var before = TagLibMetadataManager.exactPropertyValues(try TagLibMetadataManager.rawMetadataResult(from: url))
            let old = try TagLibMetadataManager.readBasicSnapshot(from: url)
            let requestedTrack = old.metadata.track == 3 ? 4 : 3
            try TagLibMetadataManager.applyMetadataPatch(
                .init(fields: [.track: .integer(requestedTrack), .trackTotal: .integer(12)]),
                to: url, expectedVersion: old.fileVersion
            )
            let persisted = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(persisted.track, requestedTrack, source.lastPathComponent)
            XCTAssertEqual(persisted.trackTotal, 12, source.lastPathComponent)
            var after = TagLibMetadataManager.exactPropertyValues(try TagLibMetadataManager.rawMetadataResult(from: url))
            for key in ["TRACKNUMBER", "TRACKTOTAL", "TOTALTRACKS", "TRACK"] {
                before.removeValue(forKey: key)
                after.removeValue(forKey: key)
            }
            XCTAssertFalse(before.isEmpty, "Seed unrelated metadata in \(source.lastPathComponent)")
            XCTAssertEqual(after, before, source.lastPathComponent)
        }
    }
}
