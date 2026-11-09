import Foundation
import Testing
import TagLibAudioMetadata

struct NumberingRepairRegressionTests {
    private func withFixture(_ ext: String, _ action: (URL) throws -> Void) throws {
        let name = ext == "ape" ? "hardening" : "testAudioFile"
        let source = try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Audio")
            ?? Bundle.module.url(forResource: name, withExtension: ext))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        try action(url)
    }

    @Test func ordinaryNativeCleanupPreservesBothGroupsAcrossFormats() throws {
        for ext in ["flac", "ogg", "ape", "wv", "wma"] {
            try withFixture(ext) { url in
                try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields: [
                    .track: .integer(3), .trackTotal: .integer(12), .disc: .integer(1), .discTotal: .integer(2)
                ]), to: url)
                let inventory = try TagLibMetadataManager.numberingInventory(at: url)
                #expect(inventory.track.number.state == .native, Comment(rawValue: ext))
                #expect(inventory.track.total.state == .native, Comment(rawValue: ext))
                let beforeDisc = inventory.disc
                let plan = try TagLibMetadataManager.planNumberNormalization(at: url, policy: .useNative, groups: [.track])
                try TagLibMetadataManager.applyNumberNormalization(plan, to: url)
                let after = try TagLibMetadataManager.numberingInventory(at: url)
                #expect(after.track.number.nativeValue == 3 && after.track.total.nativeValue == 12)
                #expect(after.disc == beforeDisc, Comment(rawValue: ext))
            }
        }
    }

    @Test func privateOnlyRecoveryPersistsAndRetiresExactSource() throws {
        for description in ["AUDIOMATOR_TRACKNUMBER_TEXT", "TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"] {
            for text in ["03/12", "/12"] {
                try withFixture("m4a") { url in
                    let key = "----:com.apple.iTunes:\(description)"
                    try TagLibMetadataManager.writeStructuredMetadataWithVerification(StructuredMetadata(mp4Atoms: [
                        .init(key: "trkn", type: "intPair", remove: true),
                        .init(key: key, type: "stringList", values: [text]),
                        .init(key: "----:org.example:\(description)", type: "stringList", values: ["99/99"])
                    ]), to: url)
                    let plan = try TagLibMetadataManager.planNumberNormalization(at: url, policy: .useLegacy, groups: [.track])
                    try TagLibMetadataManager.applyNumberNormalization(plan, to: url)
                    let atoms = try TagLibMetadataManager.readSnapshot(from: url).structured.mp4Atoms
                    #expect(atoms.first { $0.key == "trkn" }?.first == (text == "/12" ? 0 : 3))
                    #expect(atoms.first { $0.key == "trkn" }?.second == 12)
                    #expect(!atoms.contains { $0.key == key })
                    #expect(atoms.first { $0.key == "----:org.example:\(description)" }?.values == ["99/99"])
                }
            }
        }
    }

    @Test func explicitLegacyResolutionAndFullRemovalVerifyNativeAbsence() throws {
        try withFixture("m4a") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(StructuredMetadata(mp4Atoms: [
                .init(key: "trkn", type: "intPair", first: 3, second: 12),
                .init(key: "----:com.apple.iTunes:TRACKTOTAL", type: "stringList", values: ["99"])
            ]), to: url)
            let resolution = try TagLibMetadataManager.planNumberNormalization(at: url, policy: .useLegacy, groups: [.track])
            try TagLibMetadataManager.applyNumberNormalization(resolution, to: url)
            #expect(try TagLibMetadataManager.readSnapshot(from: url).structured.mp4Atoms.first { $0.key == "trkn" }?.second == 99)
            let removal = try TagLibMetadataManager.planNumberNormalization(at: url, policy: .replace(number: nil, total: nil), groups: [.track])
            try TagLibMetadataManager.applyNumberNormalization(removal, to: url)
            #expect(try !TagLibMetadataManager.readSnapshot(from: url).structured.mp4Atoms.contains { $0.key == "trkn" })
        }
    }

    @Test func multipleNativeValuesAreNotSilentlyDiscardedByUseNative() throws {
        try withFixture("flac") { url in
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["TRACKNUMBER": ["3", "4"]]), to: url)
            let before = try Data(contentsOf: url)
            #expect(throws: MetadataPatchValidationError.self) {
                try TagLibMetadataManager.planNumberNormalization(at: url, policy: .useNative, groups: [.track])
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test func emptyGroupPlanIsBytePreserving() throws {
        try withFixture("m4a") { url in
            let plan = try TagLibMetadataManager.planNumberNormalization(at: url, policy: .replace(number: 5, total: 10), groups: [])
            let before = try Data(contentsOf: url)
            try TagLibMetadataManager.applyNumberNormalization(plan, to: url)
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test func mp4PairOverflowRejectsWithoutMutation() throws {
        try withFixture("m4a") { url in
            let before = try Data(contentsOf: url)
            #expect(throws: MetadataPatchValidationError.self) {
                try TagLibMetadataManager.planNumberNormalization(at: url, policy: .replace(number: 1, total: 65536), groups: [.track])
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }
    @Test func formattedConveniencePreservesRecoveredTotal() throws {
        try withFixture("m4a") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(StructuredMetadata(mp4Atoms: [
                .init(key: "trkn", type: "intPair", first: 3, second: 0),
                .init(key: "----:com.apple.iTunes:TRACKTOTAL", type: "stringList", values: ["12"])
            ]), to: url)
            try TagLibMetadataManager.writeTrackNumberText("5", discNumberText: nil, to: url)
            let atoms = try TagLibMetadataManager.readSnapshot(from: url).structured.mp4Atoms
            #expect(atoms.first { $0.key == "trkn" }?.first == 5)
            #expect(atoms.first { $0.key == "trkn" }?.second == 12)
        }
    }

}
