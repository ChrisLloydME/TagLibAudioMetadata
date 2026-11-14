import Foundation
import XCTest
@testable import TagLibAudioMetadata
import CTagLibBridge

final class RemediationPreservationTests: XCTestCase {
    private func copyFixture(_ ext: String, name: String = "testAudioFile") throws -> URL {
        let source = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: name, withExtension: ext)
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RemediationPreservation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("\(name).\(ext)")
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    private func supports(_ field: MetadataFieldKey, _ ext: String) -> Bool {
        TagLibMetadataManager.capability(forExtension: ext)?.writeSupport(for: field) != .unsupported
    }


    private func makeV23Tag(_ frames: [(String, String)]) throws -> URL {
        let source = try XCTUnwrap(
            Bundle.module.url(forResource: "testAudioFile", withExtension: "mp3", subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "mp3")
        )
        var audio = try Data(contentsOf: source)
        if audio.starts(with: Data("ID3".utf8)) {
            let size = audio[6..<10].reduce(0) { ($0 << 7) | Int($1) }
            audio = Data(audio.dropFirst(10 + size))
        }
        var body = Data()
        for (id, value) in frames {
            let payload = Data([0]) + Data(value.utf8)
            body.append(Data(id.utf8))
            body.append(Data([
                UInt8((payload.count >> 24) & 0xFF),
                UInt8((payload.count >> 16) & 0xFF),
                UInt8((payload.count >> 8) & 0xFF),
                UInt8(payload.count & 0xFF),
                0, 0,
            ]))
            body.append(payload)
        }
        let header = Data([0x49, 0x44, 0x33, 3, 0, 0])
            + Data([
                UInt8((body.count >> 21) & 0x7F),
                UInt8((body.count >> 14) & 0x7F),
                UInt8((body.count >> 7) & 0x7F),
                UInt8(body.count & 0x7F),
            ])
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RemediationV23-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("fixture.mp3")
        try (header + body + audio).write(to: url)
        return url
    }

    private func v23Frames(_ url: URL) throws -> [String: [String]] {
        let data = try Data(contentsOf: url)
        let size = data[6..<10].reduce(0) { ($0 << 7) | Int($1) }
        var offset = 10
        let end = 10 + size
        var result: [String: [String]] = [:]
        while offset + 10 <= end, data[offset] != 0 {
            let id = String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
            let frameSize = data[(offset + 4)..<(offset + 8)].reduce(0) { ($0 << 8) | Int($1) }
            let payloadStart = offset + 10
            let payloadEnd = payloadStart + frameSize
            if payloadEnd <= data.count, frameSize >= 2 {
                let encoding = data[payloadStart]
                let textData = Data(data[(payloadStart + 1)..<payloadEnd])
                let textEncoding: String.Encoding? = switch encoding {
                case 0: .isoLatin1
                case 1: .utf16
                case 3: .utf8
                default: nil
                }
                if let textEncoding,
                   let text = String(data: textData, encoding: textEncoding)?
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) {
                    result[id, default: []].append(text)
                }
            }
            offset = payloadEnd
        }
        return result
    }

    func testLowLevelModelReadsAndPreservesContentGroupArtistsAndPeaks() throws {
        let cases: [(ext: String, name: String)] = [
            ("mp3", "testAudioFile"),
            ("m4a", "testAudioFile"),
            ("flac", "testAudioFile"),
            ("ogg", "testAudioFile"),
            ("wv", "testAudioFile"),
            ("wma", "testAudioFile"),
        ]
        for (ext, name) in cases {
            let url = try copyFixture(ext, name: name)
            let fields: [(MetadataFieldKey, String)] = [
                (.contentGroup, "Keep Group"),
                (.artists, "Keep Artist"),
                (.replayGainTrackPeak, "0.987"),
            ]
            for (field, value) in fields {
                guard supports(field, ext) else { continue }
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [field: .text(value)]), to: url)

                let low = try XCTUnwrap(TagLibMetadataExtractor.extractMetadata(from: url))
                switch field {
                case .contentGroup:
                    XCTAssertEqual(low.contentGroup, value, "\(ext) low contentGroup")
                case .artists:
                    XCTAssertEqual(low.artists, value, "\(ext) low artists")
                case .replayGainTrackPeak:
                    XCTAssertEqual(low.replayGainTrackPeak, value, "\(ext) low track peak")
                default:
                    XCTFail("unexpected field")
                }
            }

            let low = try XCTUnwrap(TagLibMetadataExtractor.extractMetadata(from: url))
            low.title = "Low-level title"
            _ = try TagLibMetadataManager.writeTagMetadata(low, to: url, verification: .none)
            let after = try TagLibMetadataManager.readMetadataResult(from: url)
            if supports(.contentGroup, ext) {
                XCTAssertEqual(after.contentGroup, "Keep Group", "\(ext) contentGroup after low-level write")
            }
            if supports(.artists, ext) {
                XCTAssertEqual(after.artists, "Keep Artist", "\(ext) artists after low-level write")
            }
            if supports(.replayGainTrackPeak, ext) {
                XCTAssertEqual(after.replayGainTrackPeak, "0.987", "\(ext) peak after low-level write")
            }
        }
    }

    func testASFLowLevelWritesUpdateExistingCanonicalAttributes() throws {
        struct Case {
            let field: MetadataFieldKey
            let first: String
            let second: String
            let set: (TagLibAudioMetadata, String?) -> Void
            let basic: (BasicMetadata) -> String
        }
        let cases: [Case] = [
            .init(field: .releaseType, first: "first-type", second: "second-type",
                  set: { $0.releaseType = $1 }, basic: { $0.releaseType }),
            .init(field: .releaseStatus, first: "first-status", second: "second-status",
                  set: { $0.releaseStatus = $1 }, basic: { $0.releaseStatus }),
            .init(field: .releaseCountry, first: "US", second: "GB",
                  set: { $0.releaseCountry = $1 }, basic: { $0.releaseCountry }),
            .init(field: .musicBrainzTrackID, first: "11111111-1111-1111-1111-111111111111",
                  second: "22222222-2222-2222-2222-222222222222",
                  set: { $0.musicBrainzTrackId = $1 }, basic: { $0.musicBrainzTrackID }),
            .init(field: .musicBrainzAlbumID, first: "33333333-3333-3333-3333-333333333333",
                  second: "44444444-4444-4444-4444-444444444444",
                  set: { $0.musicBrainzAlbumId = $1 }, basic: { $0.musicBrainzAlbumID }),
        ]
        for item in cases {
            let url = try copyFixture("wma")
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: .text(item.first)]), to: url)
            XCTAssertEqual(item.basic(try TagLibMetadataManager.readMetadataResult(from: url)), item.first)

            let low = try XCTUnwrap(TagLibMetadataExtractor.extractMetadata(from: url))
            XCTAssertEqual(item.basic(try TagLibMetadataManager.readMetadataResult(from: url)), item.first)
            item.set(low, item.second)
            _ = try TagLibMetadataManager.writeTagMetadata(low, to: url, verification: .none)
            XCTAssertEqual(
                item.basic(try TagLibMetadataManager.readMetadataResult(from: url)),
                item.second,
                "ASF low-level update for \(item.field.rawValue)"
            )
        }
    }

    func testLowLevelWritesPreserveUnknownAdvisoryRawCode() throws {
        for ext in ["flac", "ogg", "wv", "wma"] {
            let url = try copyFixture(ext)
            if ext == "wma" {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    .init(asfAttributes: [.init(key: "ITUNESADVISORY", type: "string", value: "4")]),
                    to: url
                )
            } else {
                try TagLibMetadataManager.applyRawMetadataPatch(
                    .init(valuesToSet: ["ITUNESADVISORY": ["4"]]),
                    to: url
                )
            }
            let before = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(before.explicitAdvisoryRawValue, "4", ext)

            let low = try XCTUnwrap(TagLibMetadataExtractor.extractMetadata(from: url))
            XCTAssertEqual(low.explicitAdvisoryRawValue, "4", "\(ext) low raw")
            low.title = "Unrelated low-level edit"
            _ = try TagLibMetadataManager.writeTagMetadata(low, to: url, verification: .none)

            let after = try TagLibMetadataManager.readMetadataResult(from: url)
            XCTAssertEqual(after.explicitAdvisory, .unspecified, ext)
            XCTAssertEqual(after.explicitAdvisoryRawValue, "4", "\(ext) raw advisory")
        }
    }


    func testAPEReleaseTypeAndStatusAreWritableThroughTypedAndBasic() throws {
        for (ext, name) in [("ape", "hardening"), ("wv", "testAudioFile"), ("mpc", "hardening")] {
            let typedURL = try copyFixture(ext, name: name)
            try TagLibMetadataManager.applyMetadataPatch(
                .init(fields: [.releaseType: .text("type"), .releaseStatus: .text("status")]),
                to: typedURL
            )
            var after = try TagLibMetadataManager.readMetadataResult(from: typedURL)
            XCTAssertEqual(after.releaseType, "type", "\(ext) typed release type")
            XCTAssertEqual(after.releaseStatus, "status", "\(ext) typed release status")

            try TagLibMetadataManager.updateBasicMetadata(at: typedURL) {
                $0.releaseType = "basic-type"
                $0.releaseStatus = "basic-status"
            }
            after = try TagLibMetadataManager.readMetadataResult(from: typedURL)
            XCTAssertEqual(after.releaseType, "basic-type", "\(ext) Basic release type")
            XCTAssertEqual(after.releaseStatus, "basic-status", "\(ext) Basic release status")
        }
    }

    func testBasicNumberTextMismatchRejectsAndMixedPairsCommit() throws {
        let url = try copyFixture("mp3")
        var seed = try TagLibMetadataManager.readMetadataResult(from: url)
        seed.track = 1
        seed.trackTotal = 10
        seed.trackNumberText = "1/10"
        seed.disc = 1
        seed.discTotal = 2
        seed.discNumberText = "1/2"
        try TagLibMetadataManager.replaceBasicMetadata(seed, to: url)

        let before = try Data(contentsOf: url)
        var mismatch = try TagLibMetadataManager.readMetadataResult(from: url)
        mismatch.trackNumberText = "2/10"
        XCTAssertThrowsError(try TagLibMetadataManager.replaceBasicMetadata(mismatch, to: url)) { error in
            guard case MetadataPatchValidationError.numberTextMismatch = error else {
                return XCTFail("Expected numberTextMismatch, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), before)

        var mixed = try TagLibMetadataManager.readMetadataResult(from: url)
        mixed.track = 2
        mixed.disc = 2
        mixed.discNumberText = "2/2"
        try TagLibMetadataManager.replaceBasicMetadata(mixed, to: url)
        let after = try TagLibMetadataManager.readMetadataResult(from: url)
        XCTAssertEqual(after.track, 2)
        XCTAssertEqual(after.trackTotal, 10)
        XCTAssertEqual(after.trackNumberText, "2/10")
        XCTAssertEqual(after.disc, 2)
        XCTAssertEqual(after.discTotal, 2)
        XCTAssertEqual(after.discNumberText, "2/2")
    }

    func testASFLowLevelAdvisoryEditRemovesAliases() throws {
        let url = try copyFixture("wma")
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            .init(asfAttributes: [.init(key: "AdViSoRy", type: "string", value: "2")]),
            to: url
        )
        let low = try XCTUnwrap(TagLibMetadataExtractor.extractMetadata(from: url))
        low.explicitAdvisory = .notExplicit
        _ = try TagLibMetadataManager.writeTagMetadata(low, to: url, verification: .none)

        let structured = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
        XCTAssertFalse(
            structured.asfAttributes.contains { $0.key.uppercased() == "ADVISORY" },
            "ASF low-level advisory edit must retire the case-variant alias"
        )
        XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: url).explicitAdvisory, .notExplicit)
    }

    func testV23StandaloneTDATSurvivesBasicAndStructuredUnrelatedWrites() throws {
        for surface in ["basic", "structured"] {
            let url = try makeV23Tag([("TDAT", "0304")])
            if surface == "basic" {
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Edited" }
            } else {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    .init(id3v2Frames: [.init(frameID: "TIT2", type: "text", values: ["Edited"])]),
                    to: url
                )
            }
            let frames = try v23Frames(url)
            XCTAssertEqual(frames["TDAT"], ["0304"], surface)
            XCTAssertEqual(try TagLibMetadataManager.readMetadataResult(from: url).date, "0304", surface)
        }
    }

    func testV23DateWritesRejectBeforeMutation() throws {
        let url = try makeV23Tag([("TYER", "2004"), ("TDAT", "0304")])
        let before = try Data(contentsOf: url)
        let yearWrite = StructuredMetadata(id3v2Frames: [
            .init(frameID: "TDRC", type: "versionedText", values: ["2011"], v23ID: "TYER", v24ID: "TDRC"),
        ])
        XCTAssertThrowsError(try TagLibMetadataManager.writeStructuredMetadataWithVerification(yearWrite, to: url)) { error in
            guard case TagLibManagerError.unsupportedWritePolicy = error else {
                return XCTFail("Expected unsupportedWritePolicy, got \(error)")
            }
        }
        let tdatWrite = StructuredMetadata(id3v2Frames: [
            .init(frameID: "TDAT", type: "versionedText", values: ["0506"], v23ID: "TDAT", v24Description: "DATE"),
        ])
        XCTAssertThrowsError(try TagLibMetadataManager.writeStructuredMetadataWithVerification(tdatWrite, to: url)) { error in
            guard case TagLibManagerError.unsupportedWritePolicy = error else {
                return XCTFail("Expected unsupportedWritePolicy, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: url), before)
        let frames = try v23Frames(url)
        XCTAssertEqual(frames["TYER"], ["2004"])
        XCTAssertEqual(frames["TDAT"], ["0304"])
    }

    func testV23RawDeltaPreservesCanonicalDatesAndRejectsStandaloneLoss() throws {
        let canonical = try makeV23Tag([("TYER", "2004"), ("TDAT", "0304"), ("TORY", "1999")])
        try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["TITLE": ["Raw"]]), to: canonical)
        let canonicalFrames = try v23Frames(canonical)
        XCTAssertEqual(canonicalFrames["TYER"], ["2004"])
        XCTAssertEqual(canonicalFrames["TDAT"], ["0304"])
        XCTAssertEqual(canonicalFrames["TORY"], ["1999"])

        let standalone = try makeV23Tag([("TDAT", "0304")])
        let before = try Data(contentsOf: standalone)
        XCTAssertThrowsError(
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["TITLE": ["Raw"]]), to: standalone)
        )
        XCTAssertEqual(try Data(contentsOf: standalone), before)
        XCTAssertEqual(try v23Frames(standalone)["TDAT"], ["0304"])
    }

    func testV23ConflictingTORYAndTDORRejectWithoutMutation() throws {
        let url = try makeV23Tag([("TYER", "2004"), ("TDAT", "0304"), ("TORY", "1999"), ("TDOR", "2000")])
        let before = try Data(contentsOf: url)
        XCTAssertThrowsError(try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Edited" }) { error in
            guard case TagLibManagerError.unsupportedWritePolicy = error else {
                return XCTFail("Expected unsupportedWritePolicy, got \(error)")
            }
        }
        XCTAssertThrowsError(try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            .init(id3v2Frames: [.init(frameID: "TIT2", type: "text", values: ["Edited"])]),
            to: url
        ))
        XCTAssertEqual(try Data(contentsOf: url), before)
        let frames = try v23Frames(url)
        XCTAssertEqual(frames["TORY"], ["1999"])
        XCTAssertEqual(frames["TDOR"], ["2000"])
    }
}
