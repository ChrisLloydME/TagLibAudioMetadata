import Foundation
import Testing
@testable import TagLibAudioMetadata
import CTagLibBridge

/// Every argument starts with a fresh fixture. Basic replacement is exercised
/// separately from the semantic patch matrices: it is a different write path.
struct BasicIntegrityMatrixTests {
    @Test(arguments: ["mp3", "aac", "wav", "aiff", "tta", "dsf", "dff"], [false, true])
    func basicID3DatesPreserveNativeArrays(_ ext: String, _ replace: Bool) throws {
        let name = ["dsf", "dff"].contains(ext) ? "hardening" : ext == "aiff" ? "clean-room" : "testAudioFile"
        try HardeningFixture.withCopy(ext, name: name) { url in
            let frames: [StructuredID3v2Frame] = [
                .init(frameID: "TDRC", type: "text", values: ["2004", "2005"]),
                .init(frameID: "TXXX", type: "userText", values: ["not-a-date", "  padded  ", "duplicate", "duplicate"], description: "DATE"),
                .init(frameID: "TDRL", type: "text", values: ["2017-06-09", "2018"]),
                .init(frameID: "TDOR", type: "text", values: ["1999-11-12", "2000"])
            ]
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: frames), to: url)
            let before = try nativeID3(url)
            try editTitle(url, replace: replace)
            let after = try nativeID3(url)
            for key in ["TDRC", "TXXX", "TDRL", "TDOR"] {
                #expect(before[key] != nil)
                #expect(after[key] == before[key], "\(ext) / \(key) / replace=\(replace)")
            }
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "Unrelated Basic title")
        }
    }

    @Test(arguments: ["ape", "wv", "mpc"], [false, true])
    func basicAPEDatesPreserveExactBytesAndAudio(_ ext: String, _ replace: Bool) throws {
        try HardeningFixture.withCopy(ext, name: ext == "wv" ? "testAudioFile" : "hardening") { url in
            let initial = try HardeningFixture.apeState(Data(contentsOf: url))
            var items = initial.items
            for key in ["YEAR", "DATE", "RELEASEDATE", "ORIGINALDATE"] {
                items[key] = .init(flags: 0, value: Data("2004\0not-a-date\0  padded  \0duplicate\0duplicate".utf8))
            }
            try HardeningFixture.writeAPE(audio: initial.audio, items: items, to: url)
            let before = try HardeningFixture.apeState(Data(contentsOf: url))
            try editTitle(url, replace: replace)
            let after = try HardeningFixture.apeState(Data(contentsOf: url))
            for key in ["YEAR", "DATE", "RELEASEDATE", "ORIGINALDATE"] { #expect(after.items[key] == before.items[key]) }
            #expect(after.audio == before.audio)
        }
    }

    @Test(arguments: [false, true])
    func basicFLACDatesKeepDuplicatesAndWhitespace(_ replace: Bool) throws {
        try HardeningFixture.withCopy("flac", name: "testAudioFile") { url in
            let values = Dictionary(uniqueKeysWithValues: ["YEAR", "DATE", "RELEASEDATE", "ORIGINALDATE"].map {
                ($0, ["2004", "not-a-date", "  padded  ", "duplicate", "duplicate"])
            })
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: values), to: url)
            let before = try IndependentFLACProbe.read(url)
            try editTitle(url, replace: replace)
            let after = try IndependentFLACProbe.read(url)
            for key in values.keys { #expect(after.comments[key] == before.comments[key]) }
            #expect(after.audio == before.audio)
        }
    }

    @Test func unrelatedMP4BasicEditKeepsLegacyOwnersAndArrays() throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            let keys = ["ENCODEDBY", "ENCODING", "LABEL", "CONDUCTOR", "WORK", "ITUNESALBUMID"]
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: keys.map {
                .init(key: "----:com.apple.iTunes:" + $0, type: "stringList", values: $0 == "ITUNESALBUMID" ? ["12345"] : ["First", "Second"])
            }), to: url)
            let before = try IndependentMP4Probe.read(url)
            try editTitle(url, replace: false)
            let after = try IndependentMP4Probe.read(url)
            for key in keys { #expect(after.items["----:com.apple.iTunes:" + key] == before.items["----:com.apple.iTunes:" + key]) }
            #expect(after.audio == before.audio)
        }
    }

    @Test(arguments: ["date", "contentGroup"])
    func basicVerificationRejectsIncorrectDateAndContentGroup(_ field: String) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.date = "2017-06-09"; $0.contentGroup = "Actual group" }
            var verification = TagLibMetadataManager.MetadataWriteVerificationContext.none
            verification.expectedTextFields = [field: field == "date" ? "2017-06-09" : "Actual group"]
            #expect(TagLibMetadataManager.metadataWriteWarnings(for: url, verification: verification).isEmpty)
            verification.expectedTextFields = [field: "Incorrect expected value"]
            #expect(!TagLibMetadataManager.metadataWriteWarnings(for: url, verification: verification).isEmpty)
        }
    }

    @Test(arguments: [32767, 32768, 65535], ["semantic", "basic", "structured", "lowLevel"])
    func unsignedMP4PairsAcrossWriteSurfaces(_ value: Int, _ surface: String) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            switch surface {
            case "semantic":
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(value), .trackTotal: .integer(value), .disc: .integer(value), .discTotal: .integer(value)]), to: url)
            case "basic":
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.track = value; $0.trackTotal = value; $0.disc = value; $0.discTotal = value }
            case "structured":
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                    .init(key: "trkn", type: "intPair", first: value, second: value),
                    .init(key: "disk", type: "intPair", first: value, second: value)
                ]), to: url)
            default:
                let model = try TagLibMetadataExtractor.extractMetadata(from: url)
                model.trackNumber = value; model.totalTracks = value; model.discNumber = value; model.totalDiscs = value
                _ = try TagLibMetadataManager.writeTagMetadata(model, to: url)
            }
            let basic = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(basic.track == value && basic.trackTotal == value && basic.disc == value && basic.discTotal == value)
            let probe = try IndependentMP4Probe.read(url)
            for key in ["trkn", "disk"] {
                let payload = try #require(probe.values[key]?.first)
                #expect(try HardeningFixture.integer(payload, 2, 2) == value)
                #expect(try HardeningFixture.integer(payload, 4, 2) == value)
            }
        }
    }

    private func editTitle(_ url: URL, replace: Bool) throws {
        if replace {
            var basic = try TagLibMetadataManager.readMetadataResult(from: url)
            basic.title = "Unrelated Basic title"
            try TagLibMetadataManager.replaceBasicMetadata(basic, to: url)
        } else {
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated Basic title" }
        }
    }

    private func nativeID3(_ url: URL) throws -> [String: [Data]] {
        let data = try Data(contentsOf: url)
        if ["dsf", "dff"].contains(url.pathExtension) {
            return try HardeningFixture.frames(HardeningFixture.dsdState(data, ext: url.pathExtension).tag)
        }
        // These fixtures contain one primary ID3 tag, including WAV/AIFF's
        // native ID3 chunk. The frame reader independently checks its bounds.
        let start = try #require(data.range(of: Data([73, 68, 51, 4, 0, 0]))?.lowerBound)
        return try HardeningFixture.frames(Data(data[start...]))
    }
}
