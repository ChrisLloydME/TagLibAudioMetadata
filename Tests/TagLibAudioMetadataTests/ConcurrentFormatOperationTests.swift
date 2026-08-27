import XCTest
import TagLibAudioMetadata

final class ConcurrentFormatOperationTests: XCTestCase {
    private struct ReadObservation: Sendable, Equatable {
        let fileExtension: String
        let title: String
        let artist: String
        let format: String
        let duration: TimeInterval
        let sampleRate: Double
        let channels: Int

        init(fileExtension: String, metadata: BasicMetadata) {
            self.fileExtension = fileExtension
            title = metadata.title
            artist = metadata.artist
            format = metadata.format
            duration = metadata.duration
            sampleRate = metadata.sampleRate
            channels = metadata.channels
        }
    }

    func testConcurrentReadsAcrossNonMP4FormatsRemainStable() async throws {
        let extensions = ["mp3", "flac", "aac", "ogg", "wav"]
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let urls = try Dictionary(uniqueKeysWithValues: extensions.map { ext in
            let destination = directory.appendingPathComponent("concurrent.\(ext)")
            try FileManager.default.copyItem(at: try fixtureURL(ext), to: destination)
            return (ext, destination)
        })

        let observations = try await withThrowingTaskGroup(of: [ReadObservation].self) { group in
            for worker in 0..<10 {
                group.addTask {
                    var results: [ReadObservation] = []
                    results.reserveCapacity(20)
                    for iteration in 0..<20 {
                        let ext = extensions[(worker + iteration) % extensions.count]
                        let metadata = try TagLibMetadataManager.readMetadataResult(from: urls[ext]!)
                        results.append(ReadObservation(fileExtension: ext, metadata: metadata))
                    }
                    return results
                }
            }

            var results: [ReadObservation] = []
            for try await workerResults in group {
                results.append(contentsOf: workerResults)
            }
            return results
        }

        XCTAssertEqual(observations.count, 200)
        for ext in extensions {
            let formatResults = observations.filter { $0.fileExtension == ext }
            let expected = try XCTUnwrap(formatResults.first)
            XCTAssertTrue(
                formatResults.allSatisfy { $0 == expected },
                "All concurrent \(ext) reads must return identical metadata."
            )
        }
    }

    func testConcurrentWritesToIndependentFilesAcrossFormatsRemainStable() async throws {
        let extensions = ["mp3", "m4a", "flac", "aac", "ogg", "wav"]
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let jobs = try (0..<12).map { index -> (url: URL, title: String) in
            let ext = extensions[index % extensions.count]
            let destination = directory.appendingPathComponent("write-\(index).\(ext)")
            try FileManager.default.copyItem(at: try fixtureURL(ext), to: destination)
            return (destination, "Concurrent write \(index)")
        }

        let results = try await withThrowingTaskGroup(of: (String, String).self) { group in
            for job in jobs {
                group.addTask {
                    var metadata = BasicMetadata.empty
                    metadata.title = job.title
                    _ = try TagLibMetadataManager.writeMetadataWithVerification(
                        metadata,
                        to: job.url,
                        failurePolicy: .throw
                    )
                    let readBack = try TagLibMetadataManager.readMetadataResult(from: job.url)
                    return (job.title, readBack.title)
                }
            }

            var results: [(String, String)] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        XCTAssertEqual(results.count, jobs.count)
        for (expected, actual) in results {
            XCTAssertEqual(actual, expected)
        }
    }

    private func fixtureURL(_ ext: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext)
        )
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TagLibConcurrentFormats-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
