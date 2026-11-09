import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

struct LegacyNumberingRecoveryTests {
    private func copy(_ ext: String) throws -> URL {
        let source = try #require(
            Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext)
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    @Test func id3OrphanTotalIsRecoveredAndMigratedBeforeRetirement() throws {
        let url = try copy("mp3")
        defer { try? FileManager.default.removeItem(at: url) }

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(id3v2Frames: [
                .init(frameID: "TRCK", type: "text", values: ["3"]),
                .init(frameID: "TXXX", type: "userText", values: ["12"], description: "TRACKTOTAL"),
            ]),
            to: url,
            verifyAfterWrite: false
        )

        let inventory = try TagLibMetadataManager.numberingInventory(at: url)
        #expect(inventory.track.number.state == .native)
        #expect(inventory.track.number.nativeValue == 3)
        #expect(inventory.track.total.state == .recoveredLegacy)
        #expect(inventory.track.total.recoveredValue == 12)

        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.track: .integer(5)]),
            to: url
        )
        let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
        let trck = snapshot.structured.id3v2Frames.first { $0.frameID == "TRCK" }?.values
        #expect(trck == ["5/12"])
        #expect(!snapshot.structured.id3v2Frames.contains {
            $0.frameID == "TXXX" && $0.description?.uppercased() == "TRACKTOTAL"
        })
        #expect(snapshot.basic.track == 5)
        #expect(snapshot.basic.trackTotal == 12)
    }

    @Test func unrelatedTitleEditPreservesOrphanTotalAndPrivateProvenance() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(mp4Atoms: [
                .init(key: "trkn", type: "intPair", first: 3, second: 0),
                .init(key: "----:com.apple.iTunes:TRACKTOTAL", type: "stringList", values: ["12"]),
                .init(key: "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT", type: "stringList", values: ["03/12"]),
            ]),
            to: url
        )
        let inventory = try TagLibMetadataManager.numberingInventory(at: url)
        #expect(inventory.track.total.state == .recoveredLegacy)
        #expect(inventory.track.total.recoveredValue == 12)
        #expect(inventory.track.privateTexts.map(\.description) == ["AUDIOMATOR_TRACKNUMBER_TEXT"])

        try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
        let atoms = try TagLibMetadataManager.readStructuredMetadataResult(from: url).mp4Atoms
        #expect(atoms.first { $0.key == "trkn" }?.first == 3)
        #expect(atoms.first { $0.key == "trkn" }?.second == 0)
        #expect(atoms.first { $0.freeformDescription == "TRACKTOTAL" }?.values == ["12"])
        #expect(atoms.first { $0.freeformDescription == "AUDIOMATOR_TRACKNUMBER_TEXT" }?.values == ["03/12"])
        #expect(atoms.first { $0.freeformDescription == "TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT" } == nil)
    }

    @Test func mp4OrphanTotalIsWrittenIntoNativePairBeforeAliasRetirement() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(mp4Atoms: [
                .init(key: "trkn", type: "intPair", first: 3, second: 0),
                .init(key: "----:com.apple.iTunes:TRACKTOTAL", type: "stringList", values: ["12"]),
            ]),
            to: url
        )
        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(fields: [.track: .integer(5)]),
            to: url
        )
        let atoms = try TagLibMetadataManager.readStructuredMetadataResult(from: url).mp4Atoms
        #expect(atoms.first { $0.key == "trkn" }?.first == 5)
        #expect(atoms.first { $0.key == "trkn" }?.second == 12)
        #expect(atoms.first { $0.freeformDescription == "TRACKTOTAL" } == nil)
        #expect(try TagLibMetadataManager.readMetadataResult(from: url).trackTotal == 12)
    }

    @Test func contradictoryOrphanTotalsBlockTypedPairEditWithoutMutation() throws {
        let url = try copy("mp3")
        defer { try? FileManager.default.removeItem(at: url) }

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(id3v2Frames: [
                .init(frameID: "TRCK", type: "text", values: ["3"]),
                .init(frameID: "TXXX", type: "userText", values: ["12"], description: "TRACKTOTAL"),
                .init(frameID: "TXXX", type: "userText", values: ["15"], description: "TOTALTRACKS"),
            ]),
            to: url,
            verifyAfterWrite: false
        )
        let original = try Data(contentsOf: url)
        let inventory = try TagLibMetadataManager.numberingInventory(at: url)
        #expect(inventory.track.total.state == .ambiguous)

        let patch = MetadataPatch(fields: [.track: .integer(5)])
        #expect(throws: (any Error).self) {
            try TagLibMetadataManager.applyMetadataPatch(patch, to: url)
        }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func explicitNormalizationPlanRetiresOnlySelectedPrivateText() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(mp4Atoms: [
                .init(key: "trkn", type: "intPair", first: 3, second: 12),
                .init(key: "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT", type: "stringList", values: ["03/12"]),
                .init(key: "----:com.apple.iTunes:TRACKTOTAL", type: "stringList", values: ["12"]),
            ]),
            to: url
        )
        let plan = try TagLibMetadataManager.planNumberNormalization(at: url, policy: .useNative)
        #expect(plan.trackNumber == 3)
        #expect(plan.trackTotal == 12)
        #expect(plan.privateRemovals.contains("----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"))
        try TagLibMetadataManager.applyNumberNormalization(plan, to: url)
        let atoms = try TagLibMetadataManager.readStructuredMetadataResult(from: url).mp4Atoms
        #expect(atoms.first { $0.key == "trkn" }?.first == 3)
        #expect(atoms.first { $0.key == "trkn" }?.second == 12)
        #expect(atoms.first { $0.freeformDescription == "AUDIOMATOR_TRACKNUMBER_TEXT" } == nil)
    }

    @Test func formattedNumberTextWritesOnlyNativePairsAndNeverPrivateAtoms() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        try TagLibMetadataManager.applyMetadataPatch(
            MetadataPatch(numberText: .init(trackNumberText: "05/15", discNumberText: "01/02")),
            to: url
        )
        let atoms = try TagLibMetadataManager.readStructuredMetadataResult(from: url).mp4Atoms
        #expect(atoms.first { $0.key == "trkn" }?.first == 5)
        #expect(atoms.first { $0.key == "trkn" }?.second == 15)
        #expect(atoms.first { $0.key == "disk" }?.first == 1)
        #expect(atoms.first { $0.key == "disk" }?.second == 2)
        #expect(!atoms.contains { $0.freeformDescription?.contains("TRACKNUMBER_TEXT") == true })
        #expect(!atoms.contains { $0.freeformDescription?.contains("DISCNUMBER_TEXT") == true })
    }

    @Test func planPreservesUntouchedDiscGroupAndRemovesBothPrivateNamespacesExplicitly() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            StructuredMetadata(mp4Atoms: [
                .init(key: "trkn", type: "intPair", first: 3, second: 12),
                .init(key: "disk", type: "intPair", first: 1, second: 2),
                .init(key: "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT", type: "stringList", values: ["03/12"]),
                .init(key: "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT", type: "stringList", values: ["03/12"]),
                .init(key: "----:com.apple.iTunes:AUDIOMATOR_DISCNUMBER_TEXT", type: "stringList", values: ["01/02"]),
                .init(key: "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT", type: "stringList", values: ["01/02"]),
            ]),
            to: url
        )
        let plan = try TagLibMetadataManager.planNumberNormalization(
            at: url,
            policy: .useNative,
            groups: [.track]
        )
        #expect(plan.discNumber == 1)
        #expect(plan.discTotal == 2)
        #expect(plan.privateRemovals.contains("----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"))
        #expect(plan.privateRemovals.contains("----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"))
        try TagLibMetadataManager.applyNumberNormalization(plan, to: url)
        let atoms = try TagLibMetadataManager.readStructuredMetadataResult(from: url).mp4Atoms
        #expect(atoms.first { $0.key == "disk" }?.first == 1)
        #expect(atoms.first { $0.key == "disk" }?.second == 2)
        #expect(atoms.first { $0.freeformDescription == "AUDIOMATOR_DISCNUMBER_TEXT" }?.values == ["01/02"])
        #expect(atoms.first { $0.freeformDescription == "TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT" }?.values == ["01/02"])
    }
}
