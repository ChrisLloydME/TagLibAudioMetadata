import XCTest
import TagLibAudioMetadata

final class ConcurrentM4AReadTests: XCTestCase {
    private struct Observation: Sendable, Equatable {
        let title: String
        let artist: String
        let format: String
        let duration: TimeInterval
        let bitrate: Int
        let sampleRate: Double
        let channels: Int

        init(_ metadata: BasicMetadata) {
            title = metadata.title
            artist = metadata.artist
            format = metadata.format
            duration = metadata.duration
            bitrate = metadata.bitrate
            sampleRate = metadata.sampleRate
            channels = metadata.channels
        }
    }

    /// Reproduces AudioMator's import shape: 12 concurrent facade calls spread
    /// over six independent M4A files. Each facade call performs both the basic
    /// extraction and raw-property inspection paths through the ObjC++ bridge.
    func testConcurrentReadsOfMultipleM4AFilesRemainStable() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TagLibConcurrentM4A-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = try XCTUnwrap(
            Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a", subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a")
        )
        let urls = try (0..<6).map { index in
            let destination = directory.appendingPathComponent("concurrent-\(index).m4a")
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        }

        let observations = try await withThrowingTaskGroup(of: [Observation].self) { group in
            for worker in 0..<12 {
                group.addTask {
                    var workerResults: [Observation] = []
                    workerResults.reserveCapacity(25)
                    for iteration in 0..<25 {
                        let url = urls[(worker + iteration) % urls.count]
                        let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
                        workerResults.append(Observation(metadata))
                    }
                    return workerResults
                }
            }

            var results: [Observation] = []
            for try await workerResults in group {
                results.append(contentsOf: workerResults)
            }
            return results
        }

        XCTAssertEqual(observations.count, 300)
        let expected = try XCTUnwrap(observations.first)
        XCTAssertTrue(
            observations.allSatisfy { $0 == expected },
            "All concurrent M4A reads must return identical metadata."
        )
    }
}
