import Dispatch
import Foundation
import XCTest
@testable import TagLibAudioMetadata

final class SnapshotThroughputBenchmarkTests: XCTestCase {
    func testOptInIndependentFileSnapshotThroughput() throws {
        guard ProcessInfo.processInfo.environment["TAGLIB_BENCHMARK"] == "1" else {
            throw XCTSkip("Set TAGLIB_BENCHMARK=1 for the non-gating throughput experiment.")
        }
        let source = try XCTUnwrap(Bundle.module.url(forResource: "testAudioFile", withExtension: "flac", subdirectory: "Audio")
            ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "flac"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SnapshotBenchmark-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = try (0..<8).map { index in
            let url = directory.appendingPathComponent("\(index).flac")
            try FileManager.default.copyItem(at: source, to: url)
            return url
        }
        for file in files { _ = try TagLibMetadataManager.readSnapshot(from: file) }
        let failures = BenchmarkFailures()
        for sample in 1...3 {
            let serial = ContinuousClock().measure {
                for iteration in 0..<256 {
                    do { _ = try TagLibMetadataManager.readSnapshot(from: files[iteration % files.count]) }
                    catch { failures.record(error) }
                }
            }
            let concurrent = ContinuousClock().measure {
                DispatchQueue.concurrentPerform(iterations: files.count) { index in
                    for _ in 0..<32 {
                        do { _ = try TagLibMetadataManager.readSnapshot(from: files[index]) }
                        catch { failures.record(error) }
                    }
                }
            }
            // Measurement output only; no threshold on shared CI hardware and
            // no inference that TagLib is safe with its global lock removed.
            print("SNAPSHOT_BENCHMARK sample=\(sample) reads=256 serial=\(serial) workers8=\(concurrent)")
        }
        XCTAssertTrue(failures.errors.isEmpty, "\(failures.errors)")
    }
}

private final class BenchmarkFailures: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var errors: [String] { lock.withLock { storage } }
    func record(_ error: Error) { lock.withLock { storage.append(String(describing: error)) } }
}
