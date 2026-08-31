import XCTest
@testable import TagLibAudioMetadata
#if os(macOS)
import Darwin
#endif

final class ReliabilityFailureTests: XCTestCase {
    func testDirectorySyncFailureReportsCommittedButDurabilityUncertain() throws {
        let url = try copyFixture("flac")
        let metadata = TagLibAudioMetadata()
        metadata.title = "Committed despite directory sync failure"

        XCTAssertThrowsError(
            try TagLibMetadataManager.withAtomicFileMutation(
                at: url,
                directorySync: { _ in -1 }
            ) { mutationURL in
                try TagLibMetadataExtractor.writeMetadataInPlace(metadata, to: mutationURL)
            }
        ) { error in
            guard case TagLibManagerError.committedButDurabilityUncertain(let detail) = error else {
                return XCTFail("Expected committedButDurabilityUncertain, got \(error)")
            }
            XCTAssertTrue(detail.contains("already committed"))
        }

        XCTAssertEqual(
            try TagLibMetadataManager.readMetadataResult(from: url).title,
            "Committed despite directory sync failure"
        )
    }

    func testReadAndInspectRejectInvalidSupportedExtensionFiles() throws {
        let directory = try temporaryDirectory()
        let missing = directory.appendingPathComponent("missing.mp3")
        let empty = directory.appendingPathComponent("empty.mp3")
        let corrupt = directory.appendingPathComponent("corrupt.mp3")
        let truncated = directory.appendingPathComponent("truncated.mp3")

        try Data().write(to: empty)
        try Data("not audio".utf8).write(to: corrupt)

        let mp3 = try fixtureURL("mp3")
        let mp3Bytes = try Data(contentsOf: mp3)
        try mp3Bytes.prefix(min(32, mp3Bytes.count)).write(to: truncated)
        for url in [missing, empty, corrupt, truncated] {
            XCTAssertThrowsError(try TagLibMetadataManager.readMetadataResult(from: url), url.lastPathComponent)
            XCTAssertThrowsError(try TagLibMetadataManager.rawMetadataResult(from: url), url.lastPathComponent)
            XCTAssertThrowsError(try TagLibMetadataManager.readStructuredMetadataResult(from: url), url.lastPathComponent)
        }
    }

    func testBasicReadRejectsExtensionDisguisedAudioWithoutGenericFallback() throws {
        let directory = try temporaryDirectory()
        let disguised = directory.appendingPathComponent("disguised.flac")
        try FileManager.default.copyItem(at: try fixtureURL("wav"), to: disguised)

        XCTAssertThrowsError(try TagLibMetadataManager.readMetadataResult(from: disguised))
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

    func testEraseRejectsUnsupportedFormatsWithStableManagerError() throws {
        let directory = try temporaryDirectory()
        let unsupported = directory.appendingPathComponent("notes.txt")
        let noExtension = directory.appendingPathComponent("notes")
        try Data("not audio".utf8).write(to: unsupported)
        try Data("not audio".utf8).write(to: noExtension)

        for url in [unsupported, noExtension] {
            XCTAssertThrowsError(
                try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url, failurePolicy: .throw)
            ) { error in
                guard case TagLibManagerError.unsupportedFormat = error else {
                    return XCTFail("Expected unsupportedFormat for \(url.lastPathComponent), got \(error)")
                }
            }
        }
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

#if os(macOS)
    func testAtomicReplacementPreservesExtendedAttributesACLsAndFileFlags() throws {
        let url = try copyFixture("mp3")
        let ordinaryAttribute = "com.audiomator.metadata-test"
        let ordinaryValue = Data("preserve-me".utf8)
        let quarantineAttribute = "com.apple.quarantine"
        let quarantineValue = Data("0081;00000000;TagLibAudioMetadataTests;".utf8)
        try setExtendedAttribute(ordinaryAttribute, value: ordinaryValue, at: url)
        try setExtendedAttribute(quarantineAttribute, value: quarantineValue, at: url)

        XCTAssertEqual(url.path.withCString { Darwin.chflags($0, UInt32(UF_NODUMP)) }, 0)
        try addReadACL(at: url)
        let originalACL = try aclEntries(at: url)
        XCTAssertFalse(originalACL.isEmpty)

        var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
        metadata.title = "Preserve filesystem metadata"
        try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)

        XCTAssertEqual(try extendedAttribute(ordinaryAttribute, at: url), ordinaryValue)
        XCTAssertEqual(try extendedAttribute(quarantineAttribute, at: url), quarantineValue)
        XCTAssertNotEqual(try fileFlags(at: url) & UInt32(UF_NODUMP), 0)
        XCTAssertEqual(try aclEntries(at: url), originalACL)
    }

    func testAtomicReplacementChangesInodeAndDoesNotRetargetHardLinks() throws {
        let url = try copyFixture("mp3")
        let linkedURL = url.deletingLastPathComponent().appendingPathComponent("linked.mp3")
        try FileManager.default.linkItem(at: url, to: linkedURL)
        let originalInode = try inode(at: url)
        XCTAssertEqual(try inode(at: linkedURL), originalInode)
        let linkedTitleBeforeWrite = try TagLibMetadataManager.readMetadataResult(from: linkedURL).title

        var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
        metadata.title = "Replacement inode"
        try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw)

        XCTAssertNotEqual(try inode(at: url), originalInode)
        XCTAssertEqual(try inode(at: linkedURL), originalInode)
        XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: linkedURL).title, linkedTitleBeforeWrite)
        XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: url).title, "Replacement inode")
    }
#endif

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

    func testBridgeRejectsOutOfRangeStructuredNumbersWithoutChangingFile() throws {
        let url = try copyFixture("mp3")
        let originalBytes = try Data(contentsOf: url)
        let payload: [String: NSObject] = [
            "asfAttributes": [[
                "key": "UnsignedValue",
                "type": "int64",
                "value": "18446744073709551616",
                "language": 0,
                "stream": 0,
            ]] as NSArray,
        ]

        XCTAssertThrowsError(try TagLibMetadataExtractor.writeStructuredMetadata(payload, to: url))
        XCTAssertEqual(try Data(contentsOf: url), originalBytes)
    }

    func testBasicWritesRejectNegativeAndNarrowingNumericValuesWithoutChangingFile() throws {
        let invalidMutations: [(String, (inout BasicMetadata) -> Void)] = [
            ("negative track", { $0.track = -1 }),
            ("overflowing track total", { $0.trackTotal = Int.max }),
            ("negative disc", { $0.disc = -1 }),
            ("overflowing disc total", { $0.discTotal = Int.max }),
            ("negative year", { $0.year = "-1" }),
            ("overflowing year", { $0.year = "4294967296" }),
            ("negative BPM", { $0.bpm = -1 }),
            ("overflowing BPM", { $0.bpm = Int.max }),
            ("negative movement", { $0.movementNumber = -1 }),
            ("overflowing movement count", { $0.movementCount = Int.max }),
        ]

        for ext in ["mp3", "m4a"] {
            for (label, mutation) in invalidMutations {
                let url = try copyFixture(ext)
                let originalBytes = try Data(contentsOf: url)
                var metadata = BasicMetadata.empty
                mutation(&metadata)

                XCTAssertThrowsError(
                    try TagLibMetadataManager.writeMetadataWithVerification(metadata, to: url, failurePolicy: .throw),
                    "\(ext): \(label)"
                )
                XCTAssertEqual(try Data(contentsOf: url), originalBytes, "\(ext): \(label)")
            }
        }
    }

    func testLowLevelNumericWritesRejectInvalidValuesWithoutChangingFile() throws {
        let invalidStructuredPayloads: [[String: NSObject]] = [
            ["mp4Atoms": [["key": "uint", "type": "uint", "value": -1] as NSDictionary] as NSArray],
            ["mp4Atoms": [["key": "byte", "type": "byte", "value": 256] as NSDictionary] as NSArray],
            ["mp4Atoms": [["key": "int", "type": "int", "value": Int.max] as NSDictionary] as NSArray],
            ["mp4Atoms": [["key": "pair", "type": "intPair", "first": Int.max, "second": 1] as NSDictionary] as NSArray],
            ["mp4Atoms": [["key": "long", "type": "longLong", "value": "9223372036854775808"] as NSDictionary] as NSArray],
            ["asfAttributes": [["key": "UnsignedValue", "type": "int", "value": -1, "language": 0, "stream": 0] as NSDictionary] as NSArray],
        ]

        for (index, payload) in invalidStructuredPayloads.enumerated() {
            let url = try copyFixture("m4a")
            let originalBytes = try Data(contentsOf: url)
            XCTAssertThrowsError(try TagLibMetadataExtractor.writeStructuredMetadata(payload, to: url), "payload \(index)")
            XCTAssertEqual(try Data(contentsOf: url), originalBytes, "payload \(index)")
        }

        let trackURL = try copyFixture("mp3")
        let originalTrackBytes = try Data(contentsOf: trackURL)
        XCTAssertThrowsError(try TagLibMetadataExtractor.writeTrackNumber(-1, totalTracks: 10, padWidth: 2, to: trackURL))
        XCTAssertThrowsError(try TagLibMetadataExtractor.writeTrackNumberText("1/2147483648", discNumberText: nil, to: trackURL))
        XCTAssertEqual(try Data(contentsOf: trackURL), originalTrackBytes)

        let ratingURL = try copyFixture("m4a")
        let originalRatingBytes = try Data(contentsOf: ratingURL)
        let bridgeMetadata = TagLibAudioMetadata()
        bridgeMetadata.explicitAdvisory = TagLibExplicitAdvisory(rawValue: 99)!
        XCTAssertThrowsError(try TagLibMetadataExtractor.writeMetadata(bridgeMetadata, to: ratingURL))
        XCTAssertEqual(try Data(contentsOf: ratingURL), originalRatingBytes)
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

#if os(macOS)
    private func setExtendedAttribute(_ name: String, value: Data, at url: URL) throws {
        let result = url.path.withCString { path in
            name.withCString { attributeName in
                value.withUnsafeBytes { bytes in
                    Darwin.setxattr(path, attributeName, bytes.baseAddress, bytes.count, 0, 0)
                }
            }
        }
        guard result == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    }

    private func extendedAttribute(_ name: String, at url: URL) throws -> Data {
        let length = url.path.withCString { path in
            name.withCString { attributeName in
                Darwin.getxattr(path, attributeName, nil, 0, 0, 0)
            }
        }
        guard length >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            url.path.withCString { path in
                name.withCString { attributeName in
                    Darwin.getxattr(path, attributeName, bytes.baseAddress, bytes.count, 0, 0)
                }
            }
        }
        guard result == length else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        return data
    }

    private func fileFlags(at url: URL) throws -> UInt32 {
        var information = stat()
        let result = url.path.withCString { Darwin.lstat($0, &information) }
        guard result == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        return information.st_flags
    }

    private func inode(at url: URL) throws -> ino_t {
        var information = stat()
        let result = url.path.withCString { Darwin.lstat($0, &information) }
        guard result == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        return information.st_ino
    }

    private func addReadACL(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+a", "everyone allow read", url.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(process.terminationStatus))
        }
    }

    private func aclEntries(at url: URL) throws -> [String] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ls")
        process.arguments = ["-lde", url.path]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(process.terminationStatus))
        }
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
#endif

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
