import Foundation
import Darwin
import TagLibAudioMetadata

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("facade consumer failed: \(message)\n".utf8))
    exit(1)
}

private func mp4Atoms(_ data: Data, _ range: Range<Int>) -> [(type: String, range: Range<Int>, payload: Range<Int>)] {
    var result: [(String, Range<Int>, Range<Int>)] = []
    var offset = range.lowerBound
    while offset < range.upperBound {
        guard range.upperBound - offset >= 8 else { fail("truncated MP4 atom") }
        guard let type = String(data: data[(offset + 4)..<(offset + 8)], encoding: .isoLatin1) else {
            fail("invalid MP4 atom type")
        }
        var size = data[offset..<(offset + 4)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        var header = 8
        if size == 1 {
            guard range.upperBound - offset >= 16 else { fail("truncated extended atom") }
            size = data[(offset + 8)..<(offset + 16)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            header = 16
        } else if size == 0 {
            size = UInt64(range.upperBound - offset)
        }
        guard size >= UInt64(header), size <= UInt64(range.upperBound - offset) else {
            fail("MP4 atom exceeds parent")
        }
        let end = offset + Int(size)
        result.append((type, offset..<end, (offset + header)..<end))
        offset = end
    }
    return result
}

private func mp4Text(_ data: Data, key: String) -> String? {
    let top = mp4Atoms(data, 0..<data.count)
    guard let moov = top.first(where: { $0.type == "moov" }) else { return nil }
    guard let udta = mp4Atoms(data, moov.payload).first(where: { $0.type == "udta" }) else { return nil }
    guard let meta = mp4Atoms(data, udta.payload).first(where: { $0.type == "meta" }),
          meta.payload.count >= 4 else { return nil }
    guard let ilst = mp4Atoms(data, (meta.payload.lowerBound + 4)..<meta.payload.upperBound)
        .first(where: { $0.type == "ilst" }) else { return nil }
    for item in mp4Atoms(data, ilst.payload) where item.type == key {
        for field in mp4Atoms(data, item.payload) where field.type == "data" && field.payload.count >= 8 {
            return String(data: data[(field.payload.lowerBound + 8)..<field.payload.upperBound], encoding: .utf8)
        }
    }
    return nil
}

private func mp4Audio(_ data: Data) -> Data {
    mp4Atoms(data, 0..<data.count)
        .filter { $0.type == "mdat" }
        .reduce(Data()) { $0 + Data(data[$1.payload]) }
}

private let defaultFixture = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // Sources/TagLibAudioMetadataConsumer
    .deletingLastPathComponent() // Sources
    .deletingLastPathComponent() // Consumer
    .deletingLastPathComponent() // IntegrationTests
    .deletingLastPathComponent() // repository root
    .appendingPathComponent("Tests/TagLibAudioMetadataTests/Audio/testAudioFile.m4a")

let fixture = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : defaultFixture.path)
guard FileManager.default.fileExists(atPath: fixture.path) else {
    fail("fixture not found: \(fixture.path)")
}
let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("FacadeConsumer-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let url = directory.appendingPathComponent("fixture.m4a")
try FileManager.default.copyItem(at: fixture, to: url)

do {
    let before = try Data(contentsOf: url)
    let audioBefore = mp4Audio(before)
    let snapshot = try TagLibMetadataManager.readSnapshot(from: url, includingAudioContent: false)
    _ = try TagLibMetadataManager.applyMetadataPatch(
        MetadataPatch(fields: [.title: .text("Facade Consumer Title")]),
        to: url,
        expectedVersion: snapshot.fileVersion
    )
    let reopened = try TagLibMetadataManager.readMetadataResult(from: url)
    guard reopened.title == "Facade Consumer Title" else { fail("facade reader did not observe the write") }
    let after = try Data(contentsOf: url)
    guard mp4Text(after, key: "©nam") == "Facade Consumer Title" else {
        fail("native ©nam atom missing after facade write")
    }
    guard mp4Audio(after) == audioBefore else { fail("facade write changed encoded audio") }

    let stable = try Data(contentsOf: url)
    do {
        _ = try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.title: .text("Stale Consumer Title")]),
            to: url,
            expectedVersion: snapshot.fileVersion
        )
        fail("stale expected version was accepted")
    } catch {}
    guard try Data(contentsOf: url) == stable else { fail("stale rejection mutated the file") }
    print("TagLibAudioMetadata consumer OK: real facade write/native/audio/stale checks")
} catch {
    fail(String(describing: error))
}
