import Foundation
import Testing
@testable import TagLibAudioMetadata

struct AdvisoryEraseRegressionTests {
    static let aliases = [
        ["ITUNESADVISORY"], ["ADVISORY"], ["EXPLICITCONTENT"], ["EXPLICIT"],
        ["Advisory"], ["ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT"]
    ]
    static let formats = ["mp3", "aac", "wav", "aiff", "tta", "dsf", "dff", "flac", "ogg", "oga", "opus", "ape", "wv", "mpc", "m4a", "wma"]

    private func withFixture(_ ext: String, _ body: (URL) throws -> Void) throws {
        let name = ["ape", "mpc", "dsf", "dff"].contains(ext) ? "hardening"
            : ext == "aiff" ? "clean-room" : ext == "opus" ? "synthetic" : "testAudioFile"
        try HardeningFixture.withCopy(ext, name: name, body)
    }

    private func seed(_ code: String, at url: URL) throws {
        switch url.pathExtension {
        case "wma":
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                .init(key: "ITUNESADVISORY", type: "string", value: code)
            ]), to: url)
        case "m4a":
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "rtng", type: "int", value: code)
            ]), to: url)
        case "mp3", "aac", "wav", "aiff", "tta", "dsf", "dff":
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: [
                .init(frameID: "TXXX", type: "userText", values: [code], description: "ITUNESADVISORY")
            ]), to: url)
        default:
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["ITUNESADVISORY": [code]]), to: url)
        }
    }

    @Test(.serialized, arguments: aliases, ["0", "1", "2", "9"])
    func asfAdvisoryAliasEraseVerifiesFinalNativeState(_ aliases: [String], _ code: String) throws {
        try withFixture("wma") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: aliases.map {
                .init(key: $0, type: "string", value: code)
            }), to: url)
            let before = try Data(contentsOf: url)
            let attributes = try IndependentASF.attributes(before)
            #expect(aliases.allSatisfy { alias in attributes.contains { $0.name == alias } })
            let result = try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url,
                expectedVersion: TagLibMetadataManager.fileVersion(at: url))
            #expect(result.commitStatus == .durable)
            let after = try Data(contentsOf: url)
            #expect(try IndependentASF.attributes(after).isEmpty)
            #expect(try IndependentASF.headerState(after).tail == IndependentASF.headerState(before).tail)
            let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(metadata.explicitAdvisory == .unspecified)
            #expect(metadata.explicitAdvisoryRawValue == nil)
        }
    }

    @Test(.serialized, arguments: ["mp3", "m4a", "flac", "wma"])
    func unknownAdvisoryDoesNotSatisfyExactAbsence(_ ext: String) throws {
        try withFixture(ext) { url in
            try seed("9", at: url)
            let before = try Data(contentsOf: url)
            let metadata = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(metadata.explicitAdvisory == .unspecified)
            #expect(metadata.explicitAdvisoryRawValue == "9")
            var expectation = TagLibMetadataManager.MetadataWriteVerificationContext.none
            expectation.expectedExplicitAdvisory = .unspecified
            #expect(!TagLibMetadataManager.metadataWriteWarnings(for: url, verification: expectation).isEmpty)
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test(.serialized, arguments: formats)
    func unrelatedBasicEditPreservesUnknownAdvisory(_ ext: String) throws {
        try withFixture(ext) { url in
            try seed("9", at: url)
            let before = try TagLibMetadataManager.readSnapshot(from: url)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated title" }
            let after = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(after.basic.explicitAdvisory == .unspecified)
            #expect(after.basic.explicitAdvisoryRawValue == "9")
            if ext == "wma" {
                #expect(after.structured.asfAttributes.filter { $0.key == "ITUNESADVISORY" }
                    == before.structured.asfAttributes.filter { $0.key == "ITUNESADVISORY" })
            }
        }
    }

    @Test(.serialized, arguments: aliases)
    func unrelatedBasicEditPreservesUnknownASFAliasOwners(_ aliases: [String]) throws {
        try withFixture("wma") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: aliases.map {
                .init(key: $0, type: "string", value: "9")
            }), to: url)
            let before = try Data(contentsOf: url)
            let owners = Set(aliases)
            let expected = try IndependentASF.attributes(before).filter { owners.contains($0.name) }
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated title" }
            let after = try Data(contentsOf: url)
            #expect(try IndependentASF.attributes(after).filter { owners.contains($0.name) } == expected)
            #expect(try IndependentASF.headerState(after).tail == IndependentASF.headerState(before).tail)
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).explicitAdvisoryRawValue == "9")
        }
    }

    @Test(.serialized, arguments: ["mp3", "m4a", "flac", "wma"])
    func exactUnknownAdvisoryVerificationRequiresMatchingRawCode(_ ext: String) throws {
        try withFixture(ext) { url in
            try seed("9", at: url)
            let before = try Data(contentsOf: url)
            var expectation = TagLibMetadataManager.MetadataWriteVerificationContext.none
            expectation.expectedExplicitAdvisoryRawValue = "9"
            #expect(TagLibMetadataManager.hasVerificationExpectations(expectation))
            #expect(TagLibMetadataManager.metadataWriteWarnings(for: url, verification: expectation).isEmpty)
            expectation.expectedExplicitAdvisory = .unspecified
            #expect(TagLibMetadataManager.metadataWriteWarnings(for: url, verification: expectation).isEmpty)
            expectation.expectedExplicitAdvisoryRawValue = "8"
            #expect(!TagLibMetadataManager.metadataWriteWarnings(for: url, verification: expectation).isEmpty)
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test(.serialized, arguments: formats, ["0", "1", "2", "9"])
    func advisoryBearingEraseClearsKnownAndUnknownCodes(_ ext: String, _ code: String) throws {
        try withFixture(ext) { url in
            try seed(code, at: url)
            let before = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(code == "9" ? before.explicitAdvisoryRawValue == "9" : before.explicitAdvisory != .unspecified)
            try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url)
            let after = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(after.explicitAdvisory == .unspecified)
            #expect(after.explicitAdvisoryRawValue == nil)
            if ext == "m4a" { #expect(try IndependentMP4Probe.read(url, allowingAbsentMetadata: true).items["rtng"] == nil) }
            if ext == "wma" { #expect(try IndependentASF.attributes(Data(contentsOf: url)).isEmpty) }
        }
    }
}
