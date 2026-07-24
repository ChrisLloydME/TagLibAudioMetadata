import XCTest
import TagLibAudioMetadata

final class ReliabilityFailureTests: XCTestCase {
    func testReadAndInspectRejectInvalidSupportedExtensionFiles() throws {
        let directory = try temporaryDirectory()
        let missing = directory.appendingPathComponent("missing.mp3")
        let empty = directory.appendingPathComponent("empty.mp3")
        let corrupt = directory.appendingPathComponent("corrupt.mp3")
        let truncated = directory.appendingPathComponent("truncated.mp3")
        let disguised = directory.appendingPathComponent("disguised.flac")

        try Data().write(to: empty)
        try Data("not audio".utf8).write(to: corrupt)

        let mp3 = try fixtureURL("mp3")
        let mp3Bytes = try Data(contentsOf: mp3)
        try mp3Bytes.prefix(min(32, mp3Bytes.count)).write(to: truncated)
        try FileManager.default.copyItem(at: try fixtureURL("wav"), to: disguised)

        for url in [missing, empty, corrupt, truncated, disguised] {
            XCTAssertThrowsError(try TagLibMetadataManager.readMetadataResult(from: url), url.lastPathComponent)
            XCTAssertThrowsError(try TagLibMetadataManager.rawMetadataResult(from: url), url.lastPathComponent)
            XCTAssertThrowsError(try TagLibMetadataManager.readStructuredMetadataResult(from: url), url.lastPathComponent)
        }
    }

    func testFailedWriteAndErasePreserveCorruptFileBytes() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("corrupt.mp3")
        let originalBytes = Data("not an MPEG stream".utf8)
        try originalBytes.write(to: url)

        XCTAssertThrowsError(
            try TagLibMetadataManager.writeMetadataWithVerification(.empty, to: url, failurePolicy: .throw)
        )
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)

        XCTAssertThrowsError(
            try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url, failurePolicy: .throw)
        )
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
    }

    func testUnwritableDirectoryFailurePreservesOriginalBytes() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("testAudioFile.mp3")
        try FileManager.default.copyItem(at: try fixtureURL("mp3"), to: url)
        let originalBytes = try Data(contentsOf: url)

        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }

        var metadata = BasicMetadata.empty
        metadata.title = "Must not persist"
        XCTAssertThrowsError(
            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)
        )
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
    }

    func testSymbolicLinkMutationIsRejectedWithoutChangingTarget() throws {
        let directory = try temporaryDirectory()
        let target = directory.appendingPathComponent("target.mp3")
        let link = directory.appendingPathComponent("link.mp3")
        try FileManager.default.copyItem(at: try fixtureURL("mp3"), to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let originalBytes = try Data(contentsOf: target)

        var metadata = BasicMetadata.empty
        metadata.title = "Must not persist"
        XCTAssertThrowsError(
            try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: link, failurePolicy: .throw)
        )
        XCTAssertEqual(try Data(contentsOf: target), originalBytes)

        let bridgeMetadata = TagLibAudioMetadata()
        bridgeMetadata.title = "Must not persist through the bridge"
        XCTAssertThrowsError(try TagLibMetadataExtractor.writeMetadata(bridgeMetadata, to: link))
        XCTAssertEqual(try Data(contentsOf: target), originalBytes)
    }

    func testRepeatedReadsUnicodeLongUnknownAndMultiValueRoundTrip() throws {
        let longValue = String(repeating: "長い値🙂", count: 1_024)

        for ext in ["flac", "ogg"] {
            let url = try copyFixture(ext)
            let firstRead = try TagLibMetadataManager.readMetadataResult(from: url)
            let secondRead = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(firstRead.duration, secondRead.duration, ext)
            XCTAssertEqual(firstRead.format, secondRead.format, ext)

            try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                [
                    "TITLE": ["标题 🎵"],
                    "COMMENT": [longValue],
                    "UNKNOWN_RELEASE_FIELD": ["alpha", "beta"],
                    "ARTIST": ["一", "Two"],
                ],
                to: url,
                failurePolicy: .throw
            )

            let raw = try TagLibMetadataManager.rawMetadataResult(from: url)
            XCTAssertEqual(raw.values(for: "TITLE"), ["标题 🎵"], ext)
            XCTAssertEqual(raw.values(for: "COMMENT"), [longValue], ext)
            XCTAssertEqual(raw.values(for: "UNKNOWN_RELEASE_FIELD"), ["alpha", "beta"], ext)
            XCTAssertEqual(raw.values(for: "ARTIST"), ["一", "Two"], ext)
        }
    }

    func testBinaryAPEItemUsingKnownTextKeyDoesNotCrashExtraction() throws {
        let url = try copyFixture("mp3")
        try appendBinaryAPEv2Item(key: "TRACK", value: Data([0x01, 0x02]), to: url)

        let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
        XCTAssertEqual(metadata.track, 0)
        XCTAssertEqual(metadata.trackNumberText, "")
    }

    func testRepeatedEraseAndWAVAudioPayloadPreservation() throws {
        let url = try copyFixture("wav")
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: url.path)
        let originalPayload = try XCTUnwrap(wavAudioPayload(try Data(contentsOf: url)))
        let originalPermissions = try posixPermissions(at: url)

        var metadata = BasicMetadata.empty
        metadata.title = "Payload-safe title"
        metadata.comment = "Metadata only"
        try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)
        XCTAssertEqual(try wavAudioPayload(Data(contentsOf: url)), originalPayload)
        XCTAssertEqual(try posixPermissions(at: url), originalPermissions)

        try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url, failurePolicy: .throw)
        try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url, failurePolicy: .throw)
        XCTAssertEqual(try wavAudioPayload(Data(contentsOf: url)), originalPayload)
        XCTAssertEqual(try posixPermissions(at: url), originalPermissions)
    }

    func testBridgeRejectsMalformedStructuredPayloadsWithoutChangingFile() throws {
        let malformedPayloads: [[String: NSObject]] = [
            ["id3v2Frames": [NSNull()] as NSArray],
            [
                "id3v2Frames": [
                    ["id": "T", "type": "text", "value": "short frame ID"] as NSDictionary,
                ] as NSArray,
            ],
            [
                "properties": [
                    ["key": "TITLE", "values": [NSNumber(value: 1)]] as NSDictionary,
                ] as NSArray,
            ],
        ]

        for payload in malformedPayloads {
            let url = try copyFixture("mp3")
            let originalBytes = try Data(contentsOf: url)
            XCTAssertThrowsError(try TagLibMetadataExtractor.writeStructuredMetadata(payload, to: url))
            XCTAssertEqual(try Data(contentsOf: url), originalBytes)
        }
    }

    func testDirectBridgeFailuresPreserveCorruptFileBytes() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("corrupt.mp3")
        let originalBytes = Data("not an MPEG stream".utf8)
        try originalBytes.write(to: url)

        XCTAssertThrowsError(try TagLibMetadataExtractor.writeMetadata(TagLibAudioMetadata(), to: url))
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)

        XCTAssertThrowsError(try TagLibMetadataExtractor.wipeMetadata(from: url))
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
    }

    private func fixtureURL(_ ext: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext)
        )
    }

    private func copyFixture(_ ext: String) throws -> URL {
        let directory = try temporaryDirectory()
        let destination = directory.appendingPathComponent("testAudioFile.\(ext)")
        try FileManager.default.copyItem(at: try fixtureURL(ext), to: destination)
        return destination
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TagLibAudioMetadataReliability-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }

    private func posixPermissions(at url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.posixPermissions] as? NSNumber).intValue
    }

    private func wavAudioPayload(_ data: Data) -> Data? {
        guard data.count >= 12,
              String(decoding: data[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: data[8..<12], as: UTF8.self) == "WAVE" else {
            return nil
        }

        var offset = 12
        while offset + 8 <= data.count {
            let identifier = String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
            let lengthBytes = data[(offset + 4)..<(offset + 8)]
            let length = lengthBytes.enumerated().reduce(0) { partial, entry in
                partial | (Int(entry.element) << (entry.offset * 8))
            }
            let start = offset + 8
            let end = start + length
            guard end <= data.count else { return nil }
            if identifier == "data" {
                return data.subdata(in: start..<end)
            }
            offset = end + (length % 2)
        }
        return nil
    }

    private func appendBinaryAPEv2Item(key: String, value: Data, to url: URL) throws {
        var fileData = try Data(contentsOf: url)
        let keyBytes = Array(key.utf8)

        var item = Data()
        item.append(contentsOf: littleEndianBytes(UInt32(value.count)))
        item.append(contentsOf: littleEndianBytes(2)) // APEv2 Binary item type.
        item.append(contentsOf: keyBytes)
        item.append(0)
        item.append(value)

        var footer = Data("APETAGEX".utf8)
        footer.append(contentsOf: littleEndianBytes(2_000))
        footer.append(contentsOf: littleEndianBytes(UInt32(item.count + 32)))
        footer.append(contentsOf: littleEndianBytes(1))
        footer.append(contentsOf: littleEndianBytes(0))
        footer.append(contentsOf: repeatElement(0, count: 8))

        fileData.append(item)
        fileData.append(footer)
        try fileData.write(to: url)
    }

    private func littleEndianBytes(_ value: UInt32) -> [UInt8] {
        [
            UInt8(truncatingIfNeeded: value),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 24),
        ]
    }
}

private extension RawMetadataDump {
    func values(for key: String) -> [String]? {
        properties.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.values
    }
}
