import Dispatch
import Foundation
import Darwin
import CTagLibBridge
import XCTest
@testable import TagLibAudioMetadata

final class SnapshotThroughputBenchmarkTests: XCTestCase {
    func testOptInIndependentFileSnapshotThroughput() throws {
        guard ProcessInfo.processInfo.environment["TAGLIB_BENCHMARK"] == "1" else {
            throw XCTSkip("Set TAGLIB_BENCHMARK=1 for the non-gating throughput experiment.")
        }
        if ProcessInfo.processInfo.environment["TAGLIB_BENCHMARK_PROFILE"] == "projections" {
            try measureProjectionWork()
            return
        }
        if ProcessInfo.processInfo.environment["TAGLIB_BENCHMARK_PROFILE"] == "concurrency" {
            try measureConcurrentWrites()
            return
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
        try measureWriteAndFlushCosts(in: directory)
        try measureMetadataIOProfiles(in: directory)
    }

    private func measureProjectionWork() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ProjectionBenchmark-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func sample(_ api: String, ext: String, density: String, iterations: Int = 12, operation: () throws -> Void) rethrows {
            try operation()
            var samples: [Double] = []
            for _ in 0..<3 {
                let duration = try ContinuousClock().measure { for _ in 0..<iterations { try operation() } }.components
                samples.append((Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15) / Double(iterations))
            }
            samples.sort()
            print("PROJECTION_IO_BENCHMARK format=\(ext) density=\(density) api=\(api) iterations=\(iterations) samples=3 medianMs=\(samples[1])")
        }
        for ext in ["mp3", "m4a", "flac"] {
            for density in ["ordinary", "metadata-and-artwork"] {
                let source = try XCTUnwrap(Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                    ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext))
                let url = directory.appendingPathComponent("\(density).\(ext)")
                try FileManager.default.copyItem(at: source, to: url)
                if density == "metadata-and-artwork" {
                    let custom = Dictionary(uniqueKeysWithValues: (0..<64).map {
                        ("PROFILE_\($0)", [String(repeating: "Metadata ", count: 64), "duplicate", "duplicate", "  padded  "])
                    })
                    try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: custom), to: url)
                    let image = try XCTUnwrap(Bundle.module.url(forResource: "testCover", withExtension: "jpg", subdirectory: "Artwork")
                        ?? Bundle.module.url(forResource: "testCover", withExtension: "jpg"))
                    var cover = try Data(contentsOf: image)
                    cover.append(Data(repeating: 0, count: max(0, 1_048_576 - cover.count)))
                    try TagLibMetadataManager.applyMetadataPatch(.init(artwork: .replace([.init(mimeType: "image/jpeg", data: cover)])), to: url)
                }
                let before = try TagLibMetadataManager.readSnapshot(from: url)
                let bytes = try Data(contentsOf: url)
                for (name, options) in [("bridge-basic", TagLibMetadataExtractionOptions.basic),
                    ("bridge-raw", .raw), ("bridge-structured", .structured), ("bridge-validation", .init(rawValue: 0))] {
                    try sample(name, ext: ext, density: density) { _ = try TagLibMetadataExtractor.metadataProjections(for: url, options: options) }
                }
                try sample("facade-raw", ext: ext, density: density) { _ = try TagLibMetadataManager.rawMetadataResult(from: url) }
                try sample("facade-structured", ext: ext, density: density) { _ = try TagLibMetadataManager.readStructuredMetadataResult(from: url) }
                try sample("snapshot", ext: ext, density: density) { _ = try TagLibMetadataManager.readSnapshot(from: url) }
                XCTAssertEqual(try Data(contentsOf: url), bytes)
                var sequence = 0
                try sample("typed-title", ext: ext, density: density, iterations: 3) {
                    sequence += 1
                    try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("Profile \(sequence)")]), to: url)
                }
                let after = try TagLibMetadataManager.readSnapshot(from: url)
                var expected = Dictionary(uniqueKeysWithValues: before.raw.properties.map { ($0.key, $0.values) })
                expected["TITLE"] = ["Profile \(sequence)"]
                XCTAssertEqual(Dictionary(uniqueKeysWithValues: after.raw.properties.map { ($0.key, $0.values) }), expected)
                XCTAssertEqual(after.structured.artwork, before.structured.artwork)
            }
        }
    }

    private func measureConcurrentWrites() throws {
        func milliseconds(_ elapsed: Duration) -> Double {
            let value = elapsed.components
            return Double(value.seconds) * 1_000 + Double(value.attoseconds) / 1e15
        }
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("ConcurrentWriteBenchmark-\(UUID())")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let extensions = ["mp3", "m4a", "flac", "aac", "ogg", "wav"]
        for density in ["ordinary", "metadata-heavy"] {
            var timings: [Int: [Double]] = [:]
            // Counterbalance order rather than warming only the higher limits.
            for (round, workers) in [1, 2, 4, 8, 8, 4, 2, 1, 2, 4, 8, 1].enumerated() {
                let directory = parent.appendingPathComponent("\(density)-\(round)")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                var files: [URL] = []
                var baselines: [MetadataSnapshot] = []
                for index in 0..<24 {
                    let ext = extensions[index % extensions.count]
                    let source = try XCTUnwrap(Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                        ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext))
                    let url = directory.appendingPathComponent("\(index).\(ext)")
                    try FileManager.default.copyItem(at: source, to: url)
                    var custom = ["PERF_KEEP": ["one", "duplicate", "duplicate", "  padded  "]]
                    if density == "metadata-heavy" {
                        for field in 0..<64 {
                            custom["PERF_FIELD_\(field)"] = [String(repeating: "Metadata ", count: 64), "duplicate", "  padded  "]
                        }
                    }
                    try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: custom), to: url)
                    files.append(url)
                    baselines.append(try TagLibMetadataManager.readSnapshot(from: url))
                }
                // Preparation and correctness reads are outside the timed batch.
                let targets = files
                let versions = baselines.map(\.fileVersion)
                let errors = BenchmarkFailures()
                let elapsed = ContinuousClock().measure {
                    DispatchQueue.concurrentPerform(iterations: workers) { worker in
                        for index in stride(from: worker, to: targets.count, by: workers) {
                            autoreleasepool {
                                do {
                                    let result = try TagLibMetadataManager.applyMetadataPatch(
                                        .init(fields: [.title: .text("Concurrent \(round)-\(index)")]),
                                        to: targets[index], expectedVersion: versions[index])
                                    if result.commitStatus != .durable { errors.record(CocoaError(.fileWriteUnknown)) }
                                } catch { errors.record(error) }
                            }
                        }
                    }
                }
                XCTAssertTrue(errors.errors.isEmpty, "\(errors.errors)")
                for index in files.indices {
                    let after = try TagLibMetadataManager.readSnapshot(from: files[index])
                    XCTAssertEqual(after.basic.title, "Concurrent \(round)-\(index)")
                    var expected = Dictionary(uniqueKeysWithValues: baselines[index].raw.properties.map { ($0.key, $0.values) })
                    expected["TITLE"] = [after.basic.title]
                    XCTAssertEqual(Dictionary(uniqueKeysWithValues: after.raw.properties.map { ($0.key, $0.values) }), expected)
                    XCTAssertEqual(after.basic.artist, baselines[index].basic.artist)
                    XCTAssertEqual(after.basic.year, baselines[index].basic.year)
                    XCTAssertEqual(after.basic.releaseDate, baselines[index].basic.releaseDate)
                }
                timings[workers, default: []].append(milliseconds(elapsed))
            }
            for workers in [1, 2, 4, 8] {
                let samples = try XCTUnwrap(timings[workers]).sorted()
                print("CONCURRENT_WRITE_BENCHMARK density=\(density) files=24 workers=\(workers) samples=3 medianMs=\(samples[1]) batchSamplesMs=\(samples)")
            }
        }
    }

    private func measureMetadataIOProfiles(in directory: URL) throws {
        func milliseconds(_ elapsed: Duration) -> Double {
            let value = elapsed.components
            return Double(value.seconds) * 1_000 + Double(value.attoseconds) / 1e15
        }
        func sample(_ api: String, format: String, density: String, iterations: Int,
                    operation: () throws -> Void) rethrows {
            try operation() // Warm the parser and immutable registry outside timing.
            var timings: [Double] = []
            for _ in 0..<5 {
                let elapsed = try ContinuousClock().measure {
                    for _ in 0..<iterations { try operation() }
                }
                timings.append(milliseconds(elapsed) / Double(iterations))
            }
            timings.sort()
            print("METADATA_IO_BENCHMARK format=\(format) density=\(density) api=\(api) iterations=\(iterations) samples=5 medianMs=\(timings[2]) p95Ms=\(timings[4])")
        }
        for ext in ["mp3", "m4a", "flac"] {
            let source = try XCTUnwrap(Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext))
            for density in ["ordinary", "metadata-heavy"] {
                let url = directory.appendingPathComponent("profile-\(density).\(ext)")
                try FileManager.default.copyItem(at: source, to: url)
                if density == "metadata-heavy" {
                    let values = Dictionary(uniqueKeysWithValues: (0..<64).map { index in
                        ("PERF_FIELD_\(index)", [String(repeating: "Metadata ", count: 64), "duplicate", "duplicate", "  padded  "])
                    })
                    try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: values), to: url)
                }
                let original = try Data(contentsOf: url)
                try sample("basic", format: ext, density: density, iterations: 40) {
                    _ = try TagLibMetadataManager.readBasicSnapshot(from: url)
                }
                try sample("snapshot", format: ext, density: density, iterations: 40) {
                    _ = try TagLibMetadataManager.readSnapshot(from: url)
                }
                XCTAssertEqual(try Data(contentsOf: url), original, "Read benchmark mutated its fixture")
                var sequence = 0
                try sample("typed-title", format: ext, density: density, iterations: 4) {
                    sequence += 1
                    try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("Typed \(sequence)")]), to: url)
                }
                try sample("basic-title", format: ext, density: density, iterations: 4) {
                    sequence += 1
                    try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Basic \(sequence)" }
                }
                try sample("raw-title", format: ext, density: density, iterations: 4) {
                    sequence += 1
                    try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["TITLE": ["Raw \(sequence)"]]), to: url)
                }
                XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: url).title, "Raw \(sequence)")
            }
            sample("declared-capability", format: ext, density: "descriptor-only", iterations: 2_000) {
                _ = TagLibMetadataManager.capability(forExtension: ext)
            }
        }
    }

    private func measureWriteAndFlushCosts(in directory: URL) throws {
        let source = try XCTUnwrap(Bundle.module.url(forResource: "testAudioFile", withExtension: "mp3", subdirectory: "Audio")
            ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "mp3"))
        let basicURL = directory.appendingPathComponent("basic.mp3")
        let deltaURL = directory.appendingPathComponent("delta.mp3")
        try FileManager.default.copyItem(at: source, to: basicURL)
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            .init(lyrics: [.init(language: "fra", description: "Benchmark", text: "Preserved lyric")],
                  comments: [.init(language: "deu", description: "Benchmark", text: "Preserved comment")]), to: basicURL)
        try FileManager.default.copyItem(at: basicURL, to: deltaURL)
        // Setup/seeding is outside timing; both writers retain native data and
        // include their actual staging, verification, file and directory flushes.
        for sample in 1...3 {
            let delta = try ContinuousClock().measure {
                for index in 0..<12 {
                    try TagLibMetadataManager.applyRawMetadataPatch(
                        .init(valuesToSet: ["TITLE": ["Delta \(sample)-\(index)"]]), to: deltaURL)
                }
            }
            let basic = try ContinuousClock().measure {
                for index in 0..<12 {
                    try TagLibMetadataManager.updateBasicMetadata(at: basicURL) {
                        $0.title = "Basic \(sample)-\(index)"
                    }
                }
            }
            XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: basicURL).title, "Basic \(sample)-11")
            XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: deltaURL).title, "Delta \(sample)-11")
            print("WRITE_BENCHMARK sample=\(sample) writes=12 rawDelta=\(delta) basicNativePreservation=\(basic)")
        }

        let flushURL = directory.appendingPathComponent("flush-sample")
        try Data(repeating: 0, count: 4096).write(to: flushURL)
        let handle = try FileHandle(forWritingTo: flushURL)
        defer { try? handle.close() }
        for useFullSync in [false, true] {
            for sample in 1...12 {
                // Dirty the file before starting each flush measurement.
                try handle.seek(toOffset: 0)
                try handle.write(contentsOf: Data(repeating: UInt8(sample), count: 4096))
                var status: Int32 = 0
                let elapsed = ContinuousClock().measure {
                    status = useFullSync
                        ? MetadataFileTransaction.fullSync(handle.fileDescriptor)
                        : Darwin.fsync(handle.fileDescriptor)
                }
                XCTAssertEqual(status, 0)
                print("FLUSH_BENCHMARK fullSync=\(useFullSync) sample=\(sample) elapsed=\(elapsed)")
            }
        }
        // These are observational costs on one filesystem, not an A/B test of
        // hardware durability or a historical performance regression threshold.
    }
}

private final class BenchmarkFailures: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var errors: [String] { lock.withLock { storage } }
    func record(_ error: Error) { lock.withLock { storage.append(String(describing: error)) } }
}
