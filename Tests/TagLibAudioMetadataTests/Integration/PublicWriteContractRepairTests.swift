import Foundation
import Testing
import CTagLibBridge
@testable import TagLibAudioMetadata

// Independent, byte-bounded readers for the seeds used by the public
// write-contract regressions. None of them call the bridge or package readers.
enum RepairNativeProbe {
    enum Invalid: Error { case container }

    static func fixture(_ ext: String, name: String = "testAudioFile") throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Audio")
            ?? Bundle.module.url(forResource: name, withExtension: ext))
    }

    static func copy(_ ext: String, name: String = "testAudioFile") throws -> URL {
        let source = try fixture(ext, name: name)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Repair-\(UUID()).\(ext)")
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    static func withCopy(
        _ ext: String,
        name: String = "testAudioFile",
        _ body: (URL) throws -> Void
    ) throws {
        let url = try copy(ext, name: name)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url)
    }

    static func integer(_ data: Data, _ offset: Int, _ count: Int, little: Bool = false) throws -> Int {
        guard offset >= 0, count > 0, count <= 8, offset <= data.count,
              count <= data.count - offset else { throw Invalid.container }
        let slice = data[offset..<(offset + count)]
        let ordered = little ? Array(slice.reversed()) : Array(slice)
        let value = ordered.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard value <= UInt64(Int.max) else { throw Invalid.container }
        return Int(value)
    }

    static func number(_ value: UInt64, bytes: Int, little: Bool = false) -> Data {
        Data((0..<bytes).map { UInt8(truncatingIfNeeded: value >> ((little ? $0 : bytes - 1 - $0) * 8)) })
    }

    static func ascii(_ text: String) -> Data { Data(text.utf8) }

    static func find(_ needle: Data, in data: Data) -> Range<Int>? {
        guard !needle.isEmpty, data.count >= needle.count else { return nil }
        for start in 0...(data.count - needle.count) where data[start..<(start + needle.count)] == needle {
            return start..<(start + needle.count)
        }
        return nil
    }
}

// Minimal legacy tag reader: version, frame flags and payloads only.
struct RepairID3v23Container {
    enum Invalid: Error { case tag }
    let version: Int
    let tagFlags: UInt8
    let frames: [String: [Data]]
    let audio: Data

    static func read(_ url: URL) throws -> Self {
        let bytes = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()
        var tag: Data
        var audio: Data
        if ["wav", "aiff"].contains(ext) {
            guard bytes.count >= 12 else { throw Invalid.tag }
            let little = ext == "wav"
            let expected = little ? Data("RIFF".utf8) : Data("FORM".utf8)
            guard bytes.prefix(4) == expected else { throw Invalid.tag }
            var position = 12
            var foundTag: Data?
            var foundAudio: Data?
            while position < bytes.count {
                guard bytes.count - position >= 8 else { throw Invalid.tag }
                let name = String(decoding: bytes[position..<(position + 4)], as: UTF8.self)
                let length = try RepairNativeProbe.integer(bytes, position + 4, 4, little: little)
                let start = position + 8
                guard length <= bytes.count - start else { throw Invalid.tag }
                let payload = Data(bytes[start..<(start + length)])
                if name.uppercased() == "ID3 " { foundTag = payload }
                if name == (little ? "data" : "SSND") { foundAudio = payload }
                position = start + length + length % 2
            }
            guard let nativeTag = foundTag, let nativeAudio = foundAudio else { throw Invalid.tag }
            (tag, audio) = (nativeTag, nativeAudio)
        } else if ext == "dff" {
            guard bytes.prefix(4) == Data("FRM8".utf8) else { throw Invalid.tag }
            var position = 16
            var foundTag: Data?
            var foundAudio: Data?
            while position + 12 <= bytes.count {
                let name = String(decoding: bytes[position..<(position + 4)], as: UTF8.self)
                let length = try RepairNativeProbe.integer(bytes, position + 4, 8)
                let start = position + 12
                guard length <= bytes.count - start else { throw Invalid.tag }
                let payload = Data(bytes[start..<(start + length)])
                if name == "DSD " { foundAudio = payload }
                if name == "PROP" {
                    var child = start + 4
                    let end = start + length
                    while child + 12 <= end {
                        let childName = String(decoding: bytes[child..<(child + 4)], as: UTF8.self)
                        let childLength = try RepairNativeProbe.integer(bytes, child + 4, 8)
                        let childStart = child + 12
                        guard childLength <= end - childStart else { throw Invalid.tag }
                        if childName == "ID3 " {
                            foundTag = Data(bytes[childStart..<(childStart + childLength)])
                        }
                        child = childStart + childLength + childLength % 2
                    }
                }
                position = start + length + length % 2
            }
            guard let nativeTag = foundTag, let nativeAudio = foundAudio else { throw Invalid.tag }
            (tag, audio) = (nativeTag, nativeAudio)
        } else {
            var leading = bytes
            if leading.prefix(3) == Data("ID3".utf8) {
                guard leading.count >= 10, leading[6..<10].allSatisfy({ $0 < 128 }) else { throw Invalid.tag }
                let end = 10 + leading[6..<10].reduce(0) { ($0 << 7) | Int($1) }
                guard end <= leading.count else { throw Invalid.tag }
                leading = Data(leading.dropFirst(end))
            }
            guard leading.count >= 10, leading.prefix(3) == Data("ID3".utf8),
                  leading[6..<10].allSatisfy({ $0 < 128 }) else { throw Invalid.tag }
            let end = 10 + leading[6..<10].reduce(0) { ($0 << 7) | Int($1) }
            guard end <= leading.count else { throw Invalid.tag }
            (tag, audio) = (Data(leading.prefix(end)), Data(leading.dropFirst(end)))
        }

        guard tag.count >= 10, tag.prefix(3) == Data("ID3".utf8) else { throw Invalid.tag }
        let version = Int(tag[3])
        let flags = tag[5]
        let size = tag[6..<10].reduce(0) { ($0 << 7) | Int($1) }
        guard 10 + size <= tag.count else { throw Invalid.tag }
        var frames: [String: [Data]] = [:]
        var offset = 10
        let end = 10 + size
        while offset + 10 <= end, tag[offset] != 0 {
            guard let id = String(data: tag[offset..<(offset + 4)], encoding: .ascii) else { throw Invalid.tag }
            let frameSize = try RepairNativeProbe.integer(tag, offset + 4, 4)
            _ = tag[offset + 8]
            let format = tag[offset + 9]
            let grouping = format & 0x20 != 0 ? 1 : 0
            let start = offset + 10 + grouping
            guard frameSize >= grouping, frameSize <= end - offset - 10, start + (frameSize - grouping) <= end else {
                throw Invalid.tag
            }
            frames[id, default: []].append(Data(tag[start..<(start + frameSize - grouping)]))
            offset = offset + 10 + frameSize
        }
        return .init(version: version, tagFlags: flags, frames: frames, audio: audio)
    }
}

// Seeds a valid v2.3 tag into a disposable copy. Frame flags are encoded in the
// public ID3v2.3 positions so the reader, not a display projection, is the oracle.
enum RepairV23Seed {
    static func textFrame(
        _ id: String,
        _ text: String,
        status: UInt8 = 0,
        format: UInt8 = 0,
        groupID: UInt8? = nil
    ) -> Data {
        var payload = Data([0]) + Data(text.utf8)
        if let groupID { payload = Data([groupID]) + payload }
        return Data(id.utf8) + RepairNativeProbe.number(UInt64(payload.count), bytes: 4)
            + Data([status, format]) + payload
    }

    static func tag(_ frames: Data, tagFlags: UInt8 = 0) -> Data {
        Data([73, 68, 51, 3, 0, tagFlags])
            + RepairNativeProbe.number(UInt64(frames.count), bytes: 4).map { $0 & 0x7f }
            + frames
    }

    static func seedMP3(_ url: URL, frames: Data) throws {
        var data = try Data(contentsOf: url)
        if data.prefix(3) == Data("ID3".utf8), data.count >= 10 {
            let end = 10 + data[6..<10].reduce(0) { ($0 << 7) | Int($1) }
            if end <= data.count { data = Data(data.dropFirst(end)) }
        }
        let newTag = tag(frames)
        try (newTag + data).write(to: url)
    }

    static func seedWAV(_ url: URL, frames: Data) throws {
        var data = try Data(contentsOf: url)
        let tagBytes = tag(frames)
        var chunk = Data("ID3 ".utf8) + RepairNativeProbe.number(UInt64(tagBytes.count), bytes: 4, little: true) + tagBytes
        if tagBytes.count % 2 != 0 { chunk.append(0) }
        data.insert(contentsOf: chunk, at: 12)
        let riffSize = data.count - 8
        data.replaceSubrange(4..<8, with: RepairNativeProbe.number(UInt64(riffSize), bytes: 4, little: true))
        try data.write(to: url)
    }

    static func seedAIFF(_ url: URL, frames: Data) throws {
        var data = try Data(contentsOf: url)
        let tagBytes = tag(frames)
        var chunk = Data("ID3 ".utf8) + RepairNativeProbe.number(UInt64(tagBytes.count), bytes: 4) + tagBytes
        if tagBytes.count % 2 != 0 { chunk.append(0) }
        data.insert(contentsOf: chunk, at: 12)
        let formSize = data.count - 8
        data.replaceSubrange(4..<8, with: RepairNativeProbe.number(UInt64(formSize), bytes: 4))
        try data.write(to: url)
    }

    /// Replaces the PROP contents of a valid DSDIFF layout with the existing
    /// sample-rate children plus an ID3 child. No byte scanning is used.
    static func seedDSDIFFPropertyChild(_ url: URL, frames: Data) throws {
        var data = try Data(contentsOf: url)
        guard data.count >= 16, data.prefix(4) == Data("FRM8".utf8) else { throw RepairNativeProbe.Invalid.container }
        var position = 16
        while position + 12 <= data.count {
            let name = String(decoding: data[position..<(position + 4)], as: UTF8.self)
            let length = try RepairNativeProbe.integer(data, position + 4, 8)
            let start = position + 12
            guard length <= data.count - start else { throw RepairNativeProbe.Invalid.container }
            if name == "PROP" {
                let tagBytes = tag(frames)
                var id3Chunk = Data("ID3 ".utf8) + RepairNativeProbe.number(UInt64(tagBytes.count), bytes: 8) + tagBytes
                if tagBytes.count % 2 != 0 { id3Chunk.append(0) }
                var content = Data(data[start..<(start + length)]) + id3Chunk
                if content.count % 2 != 0 { content.append(0) }
                let replacement = Data("PROP".utf8) + RepairNativeProbe.number(UInt64(content.count), bytes: 8) + content
                let oldEnd = start + length + length % 2
                data.replaceSubrange(position..<oldEnd, with: replacement)
                data.replaceSubrange(4..<12, with: RepairNativeProbe.number(UInt64(data.count - 12), bytes: 8))
                try data.write(to: url)
                return
            }
            position = start + length + length % 2
        }
        throw RepairNativeProbe.Invalid.container
    }
}

struct RepairXMHeader {
    let moduleName: String
    let trackerName: String
    let rawTrackerBytes: Data
    let suffix: Data

    static func read(_ url: URL) throws -> Self {
        let data = try Data(contentsOf: url)
        guard data.count >= 60, data.prefix(17) == Data("Extended Module: ".utf8), data[37] == 0x1a else {
            throw RepairNativeProbe.Invalid.container
        }
        func text(_ range: Range<Int>) -> String {
            let slice = data[range]
            let end = slice.firstIndex(of: 0) ?? slice.endIndex
            return String(decoding: slice[slice.startIndex..<end], as: UTF8.self)
        }
        let tracker = Data(data[38..<58])
        return .init(
            moduleName: text(17..<37),
            trackerName: text(38..<58),
            rawTrackerBytes: tracker,
            suffix: Data(data[60...])
        )
    }
}

struct PublicWriteContractRepairTests {
    // ------------------------------------------------------------------
    // F-05 — legal ID3v2.3 frame-status flags and bounded DSDIFF PROP child.
    // ------------------------------------------------------------------

    @Test(arguments: [UInt8(0x20), 0x40, 0x80, 0xe0])
    func legacyV23StatusFlagsReadLiteralDates(_ status: UInt8) throws {
        try RepairNativeProbe.withCopy("mp3") { url in
            let frames = RepairV23Seed.textFrame("TYER", "2004", status: status)
                + RepairV23Seed.textFrame("TDAT", "0906", status: status)
                + RepairV23Seed.textFrame("TORY", "1999", status: status)
            try RepairV23Seed.seedMP3(url, frames: frames)
            let before = try Data(contentsOf: url)
            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(snapshot.basic.year == "2004")
            #expect(snapshot.basic.date == "0906")
            #expect(snapshot.basic.originalReleaseDate == "1999")
            #expect(try Data(contentsOf: url) == before, "Reading must not mutate the file")
        }
    }

    @Test func legacyV23GroupingFlagSkipsBoundedIdentifier() throws {
        try RepairNativeProbe.withCopy("mp3") { url in
            let frames = RepairV23Seed.textFrame("TYER", "2004", format: 0x20, groupID: 0x7f)
                + RepairV23Seed.textFrame("TDAT", "0906", status: 0x20, format: 0x20, groupID: 0x01)
            try RepairV23Seed.seedMP3(url, frames: frames)
            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(snapshot.basic.year == "2004")
            #expect(snapshot.basic.date == "0906")
        }
    }

    @Test(arguments: [UInt8(0x80), 0x40])
    func undecodableV23FrameTransformsStillReject(_ format: UInt8) throws {
        try RepairNativeProbe.withCopy("mp3") { url in
            let frames = RepairV23Seed.textFrame("TYER", "2004", format: format)
            try RepairV23Seed.seedMP3(url, frames: frames)
            let before = try Data(contentsOf: url)
            #expect(throws: (any Error).self) {
                _ = try TagLibMetadataManager.readSnapshot(from: url)
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test func dsdiffPropertyChildID3UsesBoundedTraversal() throws {
        try RepairNativeProbe.withCopy("dff", name: "hardening") { url in
            let frames = RepairV23Seed.textFrame("TYER", "2004")
                + RepairV23Seed.textFrame("TDAT", "0906")
            try RepairV23Seed.seedDSDIFFPropertyChild(url, frames: frames)
            let native = try RepairID3v23Container.read(url)
            #expect(native.version == 3)
            #expect(native.frames["TYER"] != nil)
            let audioBefore = native.audio
            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(snapshot.basic.year == "2004")
            #expect(snapshot.basic.date == "0906")
            #expect(try RepairID3v23Container.read(url).audio == audioBefore)
        }
    }

    // ------------------------------------------------------------------
    // F-07 — structured bridge encoding/range/destination validation.
    // ------------------------------------------------------------------

    @Test func mp4IntPairOverflowRejectsWithoutMutation() throws {
        try RepairNativeProbe.withCopy("m4a") { url in
            try TagLibMetadataExtractor.writeStructuredMetadata(
                ["mp4Atoms": [[
                    "key": "trkn", "type": "intPair", "first": 3, "second": 12,
                ] as NSDictionary] as NSArray],
                to: url
            )
            let before = try Data(contentsOf: url)
            let nativeBefore = try IndependentMP4Probe.read(url)
            do {
                try TagLibMetadataExtractor.writeStructuredMetadata(
                    ["mp4Atoms": [[
                        "key": "trkn", "type": "intPair", "first": 70000, "second": 0,
                    ] as NSDictionary] as NSArray],
                    to: url
                )
                Issue.record("trkn 70000 must reject instead of truncating to 4464")
            } catch {
                // The validation error is expected; the byte assertion below is
                // the independent evidence that no save occurred.
            }
            #expect(try Data(contentsOf: url) == before)
            #expect(try IndependentMP4Probe.read(url).values["trkn"] == nativeBefore.values["trkn"])
            #expect(try TagLibMetadataManager.readSnapshot(from: url).basic.track == 3)
            #expect(try TagLibMetadataManager.readSnapshot(from: url).basic.trackTotal == 12)
        }
    }

    @Test func asfNoncanonicalTypeIsCanonicalTextOrRejected() throws {
        try RepairNativeProbe.withCopy("wma") { url in
            try TagLibMetadataExtractor.writeStructuredMetadata(
                ["asfAttributes": [[
                    "key": "WM/RepairType", "type": "String", "value": "hello",
                ] as NSDictionary] as NSArray],
                to: url
            )
            let attributes = try TagLibMetadataManager.readStructuredMetadataResult(from: url).asfAttributes
            let repaired = try #require(attributes.first { $0.key == "WM/RepairType" })
            #expect(repaired.type == "string")
            #expect(repaired.value == "hello")
            let before = try Data(contentsOf: url)
            do {
                try TagLibMetadataExtractor.writeStructuredMetadata(
                    ["asfAttributes": [[
                        "key": "WM/RepairType", "type": "Variant", "value": "hello",
                    ] as NSDictionary] as NSArray],
                    to: url
                )
                Issue.record("Unknown ASF types must reject")
            } catch {}
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test func crossFormatStructuredCollectionsRejectAtomically() throws {
        try RepairNativeProbe.withCopy("m4a") { url in
            let before = try Data(contentsOf: url)
            do {
                try TagLibMetadataExtractor.writeStructuredMetadata(
                    [
                        "mp4Atoms": [[
                            "key": "©nam", "type": "stringList", "values": ["Valid"],
                        ] as NSDictionary] as NSArray,
                        "asfAttributes": [[
                            "key": "WM/Unused", "type": "string", "value": "discarded",
                        ] as NSDictionary] as NSArray,
                    ],
                    to: url
                )
                Issue.record("M4A asfAttributes must reject instead of silently discarding")
            } catch {}
            #expect(try Data(contentsOf: url) == before)
            #expect(try IndependentMP4Probe.read(url).values["©nam"] == nil)
        }
    }

    @Test func mp4KnownAtomCannotChangeCodec() throws {
        try RepairNativeProbe.withCopy("m4a") { url in
            let before = try Data(contentsOf: url)
            do {
                try TagLibMetadataExtractor.writeStructuredMetadata(
                    ["mp4Atoms": [[
                        "key": "trkn", "type": "int", "value": 3,
                    ] as NSDictionary] as NSArray],
                    to: url
                )
                Issue.record("trkn with an int codec must reject")
            } catch {}
            #expect(try Data(contentsOf: url) == before)
        }
    }

    // ------------------------------------------------------------------
    // F-08 — generated padding bound.
    // ------------------------------------------------------------------

    @Test(arguments: [NSInteger(65), NSInteger(2_000_000_000), NSInteger(Int.max)])
    func generatedPaddingWidthRejectsBeforeFormatting(_ width: NSInteger) throws {
        try RepairNativeProbe.withCopy("mp3") { url in
            let before = try Data(contentsOf: url)
            do {
                try TagLibMetadataExtractor.writeTrackNumber(1, totalTracks: 0, padWidth: width, to: url)
                Issue.record("padWidth \(width) must reject")
            } catch {}
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test func maximumGeneratedPaddingStillWrites() throws {
        try RepairNativeProbe.withCopy("mp3") { url in
            try TagLibMetadataExtractor.writeTrackNumber(1, totalTracks: 0, padWidth: 64, to: url)
            let probe = try IndependentID3Probe.read(url)
            let track = try #require(probe.texts["TRCK"]?.first)
            #expect(track.count == 64)
            #expect(track.hasSuffix("1"))
            #expect(track.allSatisfy { $0 == "0" || $0 == "1" })
        }
    }

    // ------------------------------------------------------------------
    // F-15 — numberText preflight before staging.
    // ------------------------------------------------------------------

    @Test func numberTextPreflightRunsBeforeStaging() throws {
        try RepairNativeProbe.withCopy("m4a") { url in
            let before = try Data(contentsOf: url)
            final class StageFlag: @unchecked Sendable {
                private let lock = NSLock()
                private var value = false
                func set() { lock.lock(); value = true; lock.unlock() }
                var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
            }
            let staged = StageFlag()
            let previous = MetadataFileTransaction.willStageForTesting
            MetadataFileTransaction.willStageForTesting = { stagedURL in
                if stagedURL == url { staged.set() }
            }
            defer { MetadataFileTransaction.willStageForTesting = previous }
            do {
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(numberText: .init(trackNumberText: "70000")),
                    to: url
                )
                Issue.record("MP4 numberText 70000 must reject")
            } catch let error as MetadataPatchValidationError {
                guard case .integerOutOfRange = error else {
                    Issue.record("Expected integerOutOfRange, got \(error)")
                    return
                }
            }
            #expect(!staged.isSet, "Preflight must reject before the transaction stages a copy")
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test func asfZeroNumberTextPairRejectsBeforeStaging() throws {
        try RepairNativeProbe.withCopy("wma") { url in
            let before = try Data(contentsOf: url)
            do {
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(numberText: .init(trackNumberText: "0/5")),
                    to: url
                )
                Issue.record("ASF 0/5 must reject")
            } catch let error as MetadataPatchValidationError {
                guard case .unsupportedPartialPairRemoval = error else {
                    Issue.record("Expected unsupportedPartialPairRemoval, got \(error)")
                    return
                }
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    // ------------------------------------------------------------------
    // F-06 — full-model ownership.
    // ------------------------------------------------------------------

    @Test func fullModelPreservesUnmodeledOwners() throws {
        try RepairNativeProbe.withCopy("flac") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                .init(properties: [
                    .init(key: "PERFORMER", values: ["Alice"]),
                    .init(key: "TITLE", values: ["Old"]),
                ]),
                to: url,
                includeProperties: true
            )
            let model = TagLibAudioMetadata()
            model.title = "Changed"
            _ = try TagLibMetadataManager.writeTagMetadata(model, to: url, verification: .none)
            let flac = try IndependentFLACProbe.read(url)
            #expect(flac.comments["PERFORMER"] == ["Alice"])
            #expect(flac.comments["TITLE"] == ["Changed"])
        }

        try RepairNativeProbe.withCopy("m4a") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                .init(mp4Atoms: [
                    .init(key: "©dir", type: "stringList", values: ["Director"]),
                    .init(key: "©alb", type: "stringList", values: ["Old Album"]),
                ]),
                to: url
            )
            let model = TagLibAudioMetadata()
            model.title = "Changed"
            _ = try TagLibMetadataManager.writeTagMetadata(model, to: url, verification: .none)
            let native = try IndependentMP4Probe.read(url)
            #expect(native.values["©dir"] == [Data("Director".utf8)])
            // Modeled nil still means replacement removal.
            #expect(native.values["©alb"] == nil)
        }
    }

    @Test func privateProvenanceSurvivesOrdinaryWrites() throws {
        try RepairNativeProbe.withCopy("m4a") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                .init(mp4Atoms: [
                    .init(key: "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT",
                          type: "stringList", values: ["03/12"]),
                    .init(key: "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT",
                          type: "stringList", values: ["03/12"]),
                ]),
                to: url
            )
            let model = TagLibAudioMetadata()
            model.title = "Ordinary"
            _ = try TagLibMetadataManager.writeTagMetadata(model, to: url, verification: .none)
            let native = try IndependentMP4Probe.read(url)
            #expect(native.values["----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"]
                == [Data("03/12".utf8)])
            #expect(native.values["----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"]
                == [Data("03/12".utf8)])
        }
    }

    @Test func ordinaryAliasRetiresOnlyForEditedPair() throws {
        try RepairNativeProbe.withCopy("m4a") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                .init(mp4Atoms: [
                    .init(key: "trkn", type: "intPair", first: 3, second: 0),
                    .init(key: "disk", type: "intPair", first: 1, second: 2),
                    .init(key: "----:com.apple.iTunes:TRACKTOTAL",
                          type: "stringList", values: ["12"]),
                    .init(key: "----:com.apple.iTunes:DISCTOTAL",
                          type: "stringList", values: ["9"]),
                ]),
                to: url
            )
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.track: .integer(5)]),
                to: url
            )
            let native = try IndependentMP4Probe.read(url)
            #expect(native.values["trkn"] != nil)
            #expect(native.values["----:com.apple.iTunes:TRACKTOTAL"] == nil)
            // Untouched disc group keeps its exact legacy alias.
            #expect(native.values["----:com.apple.iTunes:DISCTOTAL"] == [Data("9".utf8)])
        }
    }

    // ------------------------------------------------------------------
    // F-09 — case-normalized MusicBrainz alias cleanup.
    // ------------------------------------------------------------------

    @Test func musicBrainzAliasCleanupUsesCaseInsensitiveIdentity() throws {
        try RepairNativeProbe.withCopy("mp3") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                .init(id3v2Frames: [
                    .init(frameID: "TXXX", type: "userText",
                          values: ["old-id"],
                          description: "MusicBrainz Track Id"),
                ]),
                to: url
            )
            let model = TagLibAudioMetadata()
            model.musicBrainzTrackId = "new-id"
            _ = try TagLibMetadataManager.writeTagMetadata(model, to: url, verification: .none)
            let native = try IndependentID3Probe.read(url)
            #expect(native.texts["TXXX:MusicBrainz Track Id"] == nil)
            let ufid = try #require(native.frames["UFID"])
            let payload = try #require(ufid.first)
            #expect(payload.range(of: Data("http://musicbrainz.org".utf8)) != nil)
            #expect(payload.range(of: Data("new-id".utf8)) != nil)
            #expect(payload.range(of: Data("old-id".utf8)) == nil)
        }
    }

    // ------------------------------------------------------------------
    // F-11 — canonical MP4 raw freeform set/remove.
    // ------------------------------------------------------------------

    @Test(arguments: ["RELEASETYPE", "MUSICBRAINZ_TRACKID"])
    func mp4RawCanonicalFreeformSetAndRemove(_ key: String) throws {
        let description = key == "RELEASETYPE" ? "MusicBrainz Album Type" : "MusicBrainz Track Id"
        let nativeKey = "----:com.apple.iTunes:\(description)"
        try RepairNativeProbe.withCopy("m4a") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                .init(mp4Atoms: [
                    .init(key: nativeKey, type: "stringList", values: ["Old"]),
                    .init(key: "----:com.apple.iTunes:UNRELATED", type: "stringList", values: ["Keep"]),
                ]),
                to: url
            )
            try TagLibMetadataManager.applyRawMetadataPatch(
                .init(valuesToSet: [key: ["New"]]),
                to: url
            )
            let afterSet = try IndependentMP4Probe.read(url)
            #expect(afterSet.values[nativeKey] == [Data("New".utf8)])
            #expect(afterSet.values["----:com.apple.iTunes:UNRELATED"] == [Data("Keep".utf8)])
            #expect(try TagLibMetadataManager.readSnapshot(from: url).raw.properties
                .first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.values == ["New"])

            try TagLibMetadataManager.applyRawMetadataPatch(
                .init(removingKeys: [key]),
                to: url
            )
            let afterRemove = try IndependentMP4Probe.read(url)
            #expect(afterRemove.values[nativeKey] == nil)
            #expect(afterRemove.values["----:com.apple.iTunes:UNRELATED"] == [Data("Keep".utf8)])
        }
    }

    @Test func rawAPIsStillRejectNativeMP4Keys() throws {
        try RepairNativeProbe.withCopy("m4a") { url in
            let before = try Data(contentsOf: url)
            do {
                try TagLibMetadataManager.applyRawMetadataPatch(
                    .init(valuesToSet: ["----:com.apple.iTunes:X": ["value"]]),
                    to: url
                )
                Issue.record("Raw APIs must reject native MP4 keys")
            } catch let error as RawMetadataPatchError {
                guard case .nativeKeyRequiresStructuredAPI = error else {
                    Issue.record("Unexpected raw error: \(error)")
                    return
                }
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    // ------------------------------------------------------------------
    // F-10 — WAV/AIFF v2.3 save-version preservation.
    // ------------------------------------------------------------------

    enum ContainerEditSurface: String, CaseIterable, Sendable {
        case patch
        case raw
        case structured
    }

    @Test(arguments: ["wav", "aiff"], ContainerEditSurface.allCases)
    func v23ContainersPreserveVersionDatesAndAudio(_ ext: String, _ surface: ContainerEditSurface) throws {
        let fixtureName = ext == "aiff" ? "clean-room" : "testAudioFile"
        try RepairNativeProbe.withCopy(ext, name: fixtureName) { url in
            let frames = RepairV23Seed.textFrame("TIT2", "Before")
                + RepairV23Seed.textFrame("TYER", "2004")
                + RepairV23Seed.textFrame("TDAT", "0906")
                + RepairV23Seed.textFrame("TORY", "1999")
            if ext == "wav" {
                try RepairV23Seed.seedWAV(url, frames: frames)
            } else {
                try RepairV23Seed.seedAIFF(url, frames: frames)
            }
            let before = try RepairID3v23Container.read(url)
            #expect(before.version == 3)
            let audioBefore = before.audio

            switch surface {
            case .patch:
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.title: .text("After")]),
                    to: url
                )
            case .raw:
                try TagLibMetadataManager.applyRawMetadataPatch(
                    .init(valuesToSet: ["TITLE": ["After"]]),
                    to: url
                )
            case .structured:
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    .init(id3v2Frames: [
                        .init(frameID: "TIT2", type: "text", values: ["After"]),
                    ]),
                    to: url
                )
            }

            let after = try RepairID3v23Container.read(url)
            #expect(after.version == 3, "An unrelated edit must not convert v2.3 to v2.4")
            #expect(after.frames["TYER"] != nil)
            #expect(after.frames["TDAT"] != nil)
            #expect(after.frames["TORY"] != nil)
            #expect(after.audio == audioBefore)
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "After")
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).year == "2004")
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).date == "0906")
        }
    }

    // ------------------------------------------------------------------
    // F-13 / F-14 — XM policy and registry projections.
    // ------------------------------------------------------------------

    @Test func xmTrackerNameTypedRouteWritesNativeBytes() throws {
        try RepairNativeProbe.withCopy("xm") { url in
            let before = try RepairXMHeader.read(url)
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.trackerName: .text("RepairTracker")]),
                to: url
            )
            let after = try RepairXMHeader.read(url)
            #expect(after.trackerName.trimmingCharacters(in: .whitespaces) == "RepairTracker")
            #expect(after.rawTrackerBytes.prefix(13) == Data("RepairTracker".utf8))
            #expect(after.rawTrackerBytes.count == 20)
            #expect(after.rawTrackerBytes.dropFirst(13).allSatisfy { $0 == 0 })
            #expect(after.moduleName == before.moduleName)
            #expect(after.suffix == before.suffix)
            #expect(try TagLibMetadataManager.readSnapshot(from: url).raw.properties
                .first { $0.key.caseInsensitiveCompare("TRACKERNAME") == .orderedSame }?
                .values.map { $0.trimmingCharacters(in: .whitespaces) } == ["RepairTracker"])
        }
    }

    @Test func registrySemanticAndTotalProjectionsAreConsistent() throws {
        // Engine DATE alias and semantic standalone DATE stay distinct.
        #expect(MetadataFieldRegistry.schema(forPropertyMapKey: "DATE")?.key == .year)
        #expect(MetadataFieldRegistry.canonicalSchema(forSemanticKey: "DATE")?.key == .standaloneDate)

        // Custom placeholder construction/lookup normalizes identically and
        // retains the registered template targets.
        let custom = try #require(MetadataFieldRegistry.canonicalSchema(forSemanticKey: "<explicit key>"))
        #expect(custom.key == .custom)
        #expect(!custom.nativeTargets.isEmpty)
        #expect(custom.nativeTargets.contains { $0.nativeIdentity == "<description>" })
        for schema in MetadataFieldRegistry.allSchemas {
            #expect(MetadataFieldRegistry.canonicalSchema(forSemanticKey: schema.semanticKey)?.key == schema.key)
        }

        // MP4 pair totals use the second intPair component, not a scalar atom.
        for key in [MetadataFieldKey.trackTotal, .discTotal] {
            let schema = try #require(MetadataFieldRegistry.schema(for: key))
            let target = try #require(schema.targets(for: .mp4).first)
            #expect(target.storage == .intPair)
            #expect(target.shape == .intPair)
            #expect(target.numberComponent == .total)
        }

        // Role-qualified fields advertise no typed value kinds.
        for key in [MetadataFieldKey.performer, .involvedPeople, .musicianCredits] {
            #expect(MetadataFieldRegistry.schema(for: key)?.acceptedPatchValueKinds.isEmpty == true)
        }

        // XM storable enumeration follows executable write support.
        let xm = try #require(TagLibMetadataManager.capability(forExtension: "xm"))
        let storable = MetadataFieldRegistry.schemas(storableIn: xm).map(\.key)
        #expect(storable.contains(.title))
        #expect(storable.contains(.comment))
        #expect(storable.contains(.trackerName))
        #expect(!storable.contains(.performer))

        // Native MP4 freeform keys are not PropertyMap-key namespace entries.
        #expect(MetadataFieldRegistry.schema(forPropertyMapKey: "----:com.apple.iTunes:PRODUCER") == nil)

        // Registration versus capability: engine projection present, native
        // capability not implied.
        let producer = try #require(MetadataFieldRegistry.schema(for: .producer))
        #expect(producer.mappings.contains { $0.format == .tagLibPropertyMap })
        #expect(!MetadataFieldRegistry.schema(.producer, hasMappingFor: .tagLibPropertyMap))

        // Matroska registrations remain target-only and write-unsupported.
        let episode = try #require(MetadataFieldRegistry.schema(for: .tvEpisode))
        #expect(!episode.targets(for: MetadataNativeFamily.matroska).isEmpty)
        #expect(episode.capability(for: MetadataNativeFamily.matroska) == .unsupported)
        #expect(TagLibMetadataManager.capability(forExtension: "mkv") == nil)

        // Best-available aggregate, not the lowest capability.
        #expect(MetadataFieldRegistry.schema(for: .title)?.aggregateCapability == .native)
    }

    @Test func roleQualifiedTypedPatchStillRejects() throws {
        try RepairNativeProbe.withCopy("flac") { url in
            let before = try Data(contentsOf: url)
            do {
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.performer: .values(["Alice:violin"])]),
                    to: url
                )
                Issue.record("Role-qualified typed patches remain unsupported")
            } catch let error as MetadataPatchValidationError {
                guard case .roleQualifiedFieldRequiresRawAPI = error else {
                    Issue.record("Unexpected role error: \(error)")
                    return
                }
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    // ------------------------------------------------------------------
    // F-01/F-03/F-12 retained policy boundaries.
    // ------------------------------------------------------------------

    @Test func yearPrefixFilterRemainsBasicSpecific() throws {
        try RepairNativeProbe.withCopy("flac") { url in
            let before = try Data(contentsOf: url)
            var rejected = BasicMetadata.empty
            rejected.title = "Title"
            rejected.year = "2021x"
            do {
                try TagLibMetadataManager.replaceBasicMetadata(rejected, to: url)
                Issue.record("Expected invalidYearText for a non-year-prefix value")
            } catch let error as MetadataValidationError {
                guard case .invalidYearText = error else {
                    Issue.record("Unexpected Basic year error: \(error)")
                    return
                }
            }
            #expect(try Data(contentsOf: url) == before)

            // The frozen Basic policy is a four-digit prefix/separator filter,
            // not a complete calendar grammar. A prefix-shaped value is stored
            // literally without deriving or normalizing another date field.
            var accepted = BasicMetadata.empty
            accepted.title = "Title"
            accepted.year = "2021-"
            try TagLibMetadataManager.replaceBasicMetadata(accepted, to: url)
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).year == "2021-")
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).date == "")
        }
    }
}
