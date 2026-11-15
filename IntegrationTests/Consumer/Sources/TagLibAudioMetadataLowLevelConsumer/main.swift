import Foundation
import Darwin
import CTagLibBridge

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("low-level consumer failed: \(message)\n".utf8))
    exit(1)
}

private func id3Audio(_ data: Data) -> Data? {
    guard data.count >= 10, data.prefix(3) == Data("ID3".utf8),
          data[6..<10].allSatisfy({ $0 < 0x80 }) else { return nil }
    let end = 10 + data[6..<10].reduce(0) { ($0 << 7) | Int($1) }
    guard end <= data.count else { return nil }
    return Data(data.dropFirst(end))
}

private func id3Title(_ data: Data) -> String? {
    guard data.count >= 10, data.prefix(3) == Data("ID3".utf8) else { return nil }
    let version = Int(data[3])
    guard version == 3 || version == 4, data[6..<10].allSatisfy({ $0 < 0x80 }) else { return nil }
    let end = 10 + data[6..<10].reduce(0) { ($0 << 7) | Int($1) }
    guard end <= data.count else { return nil }
    var offset = 10
    while offset < end, data[offset] != 0 {
        guard end - offset >= 10, let id = String(data: data[offset..<(offset + 4)], encoding: .ascii) else {
            return nil
        }
        let size = version == 4
            ? data[(offset + 4)..<(offset + 8)].reduce(0) { ($0 << 7) | Int($1) }
            : data[(offset + 4)..<(offset + 8)].reduce(0) { ($0 << 8) | Int($1) }
        let start = offset + 10
        guard size <= end - start else { return nil }
        if id == "TIT2" {
            let payload = data[start..<(start + size)]
            guard let encoding = payload.first else { return nil }
            let body = Data(payload.dropFirst())
            return String(data: body, encoding: encoding == 3 ? .utf8 : .isoLatin1)
        }
        offset = start + size
    }
    return nil
}

private let defaultFixture = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Tests/TagLibAudioMetadataTests/Audio/testAudioFile.mp3")

let fixture = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : defaultFixture.path)
guard FileManager.default.fileExists(atPath: fixture.path) else {
    fail("fixture not found: \(fixture.path)")
}
let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("LowLevelConsumer-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let url = directory.appendingPathComponent("fixture.mp3")
try FileManager.default.copyItem(at: fixture, to: url)

do {
    let before = try Data(contentsOf: url)
    guard let audioBefore = id3Audio(before) else { fail("missing seeded ID3/audio boundary") }
    let metadata = try TagLibMetadataExtractor.extractMetadata(from: url)
    metadata.title = "LowLevel Consumer Title"
    try TagLibMetadataExtractor.writeMetadata(metadata, to: url)
    let projections = try TagLibMetadataExtractor.metadataProjections(for: url)
    guard projections["basic"] is TagLibAudioMetadata else { fail("missing basic projection") }
    let after = try Data(contentsOf: url)
    guard id3Title(after) == "LowLevel Consumer Title" else { fail("native TIT2 frame missing") }
    guard id3Audio(after) == audioBefore else { fail("low-level write changed encoded audio") }
    guard !TagLibMetadataExtractor.isWritableFormat("mka") else { fail("unreachable Matroska route advertised") }
    print("TagLibAudioMetadata low-level consumer OK: real bridge write/native/audio checks")
} catch {
    fail(String(describing: error))
}
