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
}
