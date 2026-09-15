import Foundation
import XCTest
@testable import TagLibAudioMetadata
import CTagLibBridge

final class ExternalCorpusPreservationTests: XCTestCase {
    func testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus() throws {
        guard let path = ProcessInfo.processInfo.environment["TAGLIB_PRESERVATION_CORPUS"] else {
            throw XCTSkip("Set TAGLIB_PRESERVATION_CORPUS to run additional application/corpus fixtures.")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TagLibCorpus-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sources = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: nil)
        let audioSources = sources.filter { TagLibMetadataManager.isWritableFormat($0.pathExtension) }
        guard !audioSources.isEmpty else {
            XCTFail("The corpus directory contains no writable audio fixtures: \(path)")
            return
        }
        for source in audioSources {
            let url = directory.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: url)
            var before = TagLibMetadataManager.exactPropertyValues(try TagLibMetadataManager.rawMetadataResult(from: url))
            try TagLibMetadataExtractor.writeNumberPairsInPlace(
                trackNumber: 3, totalTracks: 12, updateTrackPair: true,
                discNumber: 0, totalDiscs: 0, updateDiscPair: false, to: url
            )
            var after = TagLibMetadataManager.exactPropertyValues(try TagLibMetadataManager.rawMetadataResult(from: url))
            for key in ["TRACKNUMBER", "TRACKTOTAL", "TOTALTRACKS", "TRACK"] {
                before.removeValue(forKey: key)
                after.removeValue(forKey: key)
            }
            XCTAssertEqual(after, before, source.lastPathComponent)
        }
    }
}
