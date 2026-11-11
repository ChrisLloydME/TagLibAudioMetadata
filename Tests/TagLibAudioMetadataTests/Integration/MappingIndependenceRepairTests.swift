import Foundation
import Testing
import TagLibAudioMetadata

struct MappingIndependenceRepairTests {
    private func fixture(_ ext: String) throws -> URL {
        let name = ext == "ape" ? "hardening" : "testAudioFile"
        let source = try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Audio")
            ?? Bundle.module.url(forResource: name, withExtension: ext))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    @Test func dateEditsAndRemovalsNeverChangeSiblingFields() throws {
        for ext in ["mp3", "aac", "wav", "flac", "ogg", "ape", "wv", "m4a"] {
            let seed: [MetadataFieldKey: MetadataPatchValue] = [
                .year: .text("2004"), .standaloneDate: .text("2008-03-04"),
                .releaseDate: .text("2017-06-09"), .originalReleaseDate: .text("1999-11-12")
            ]
            for field in seed.keys {
                for value in [MetadataPatchValue.text("2020-02-03"), .remove] {
                    let url = try fixture(ext)
                    defer { try? FileManager.default.removeItem(at: url) }
                    do { try TagLibMetadataManager.applyMetadataPatch(.init(fields: seed), to: url) }
                    catch { Issue.record("Seed \(ext) / \(field): \(error)"); continue }
                    let before = try TagLibMetadataManager.readSnapshot(from: url).basic
                    do {
                        try TagLibMetadataManager.applyMetadataPatch(.init(fields: [field: value]), to: url)
                    } catch {
                        Issue.record("\(ext) / \(field) / \(value): \(error)")
                        continue
                    }
                    let after = try TagLibMetadataManager.readSnapshot(from: url).basic
                    if field != .year { #expect(after.year == before.year, Comment(rawValue: ext)) }
                    if field != .standaloneDate { #expect(after.date == before.date, Comment(rawValue: ext)) }
                    if field != .releaseDate { #expect(after.releaseDate == before.releaseDate, Comment(rawValue: ext)) }
                    if field != .originalReleaseDate { #expect(after.originalReleaseDate == before.originalReleaseDate, Comment(rawValue: ext)) }
                }
            }
        }
    }

    @Test func musicBrainzRecordingIdentifierSetReplaceAndRemoveUseQualifiedUFID() throws {
        for ext in ["mp3", "aac", "wav"] {
            let url = try fixture(ext)
            defer { try? FileManager.default.removeItem(at: url) }
            for text in ["11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222", ""] {
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [
                    .musicBrainzTrackID: text.isEmpty ? .remove : .text(text)
                ]), to: url)
                #expect(try TagLibMetadataManager.readSnapshot(from: url).basic.musicBrainzTrackID == text)
            }
        }
    }

    @Test func unrelatedEditsPreserveNativeDateArraysAndMalformedText() throws {
        for ext in ["flac", "ogg", "ape", "wv"] {
            let url = try fixture(ext)
            defer { try? FileManager.default.removeItem(at: url) }
            let values = ["YEAR": ["2004", "2005"], "DATE": ["2008-03-04", "not-a-date"],
                          "ORIGINALDATE": ["legacy", "1999-11-12"]]
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: values), to: url)
            let before = try TagLibMetadataManager.readSnapshot(from: url)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("Unrelated")]), to: url)
            let after = try TagLibMetadataManager.readSnapshot(from: url)
            for key in values.keys {
                #expect(after.raw.properties.first { $0.key == key }?.values == before.raw.properties.first { $0.key == key }?.values, Comment(rawValue: ext + " " + key))
                #expect(after.raw.properties.first { $0.key == key }?.values == values[key], Comment(rawValue: ext + " " + key))
            }
        }
    }

    @Test func flacCommentSetReplaceAndClearUseXiphVerification() throws {
        let url = try fixture("flac")
        defer { try? FileManager.default.removeItem(at: url) }
        for text in ["First", "Replacement", ""] {
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.comment: text.isEmpty ? .remove : .text(text)]), to: url)
            #expect(try TagLibMetadataManager.readSnapshot(from: url).basic.comment == text)
        }
    }
}
