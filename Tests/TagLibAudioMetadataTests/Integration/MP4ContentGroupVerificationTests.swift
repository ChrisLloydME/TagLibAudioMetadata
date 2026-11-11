import Foundation
import Testing
import TagLibAudioMetadata

struct MP4ContentGroupVerificationTests {
    private func fixture() throws -> URL {
        let source = try #require(Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a", subdirectory: "Audio")
            ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    @Test func singleFieldLifecyclePreservesIndependentNativeSiblings() throws {
        let identities: [(MetadataFieldKey, String)] = [
            (.contentGroup, "©grp"), (.grouping, "----:com.apple.iTunes:GROUPING"), (.work, "©wrk")
        ]
        for siblingsPresent in [false, true] {
            for (field, nativeKey) in identities {
                for value in [MetadataPatchValue.text("First"), .text("Replacement"), .remove] {
                    let url = try fixture()
                    defer { try? FileManager.default.removeItem(at: url) }
                    // Set up native atoms directly so semantic verification cannot
                    // prevent construction of the regression's original state.
                    try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: identities.map { key, atom in
                        .init(key: atom, type: "stringList", values: siblingsPresent ? ["Keep \(key.rawValue)", "Second \(key.rawValue)"] : [], remove: !siblingsPresent)
                    }), to: url)
                    let before = try TagLibMetadataManager.readSnapshot(from: url)
                    do {
                        try TagLibMetadataManager.applyMetadataPatch(.init(fields: [field: value]), to: url)
                    } catch {
                        Issue.record("\(field), siblingsPresent=\(siblingsPresent), value=\(value): \(error)")
                        continue
                    }
                    let after = try TagLibMetadataManager.readSnapshot(from: url)
                    let expected: [String] = switch value { case .text(let text): [text]; default: [] }
                    let semantic = switch field {
                    case .contentGroup: after.basic.contentGroup
                    case .grouping: after.basic.grouping
                    default: after.basic.work
                    }
                    #expect(semantic == expected.first ?? "")
                    #expect(after.structured.mp4Atoms.first { $0.key == nativeKey }?.values ?? [] == expected)
                    for (sibling, atom) in identities where sibling != field {
                        #expect(before.structured.mp4Atoms.filter { $0.key == atom } == after.structured.mp4Atoms.filter { $0.key == atom })
                    }
                }
            }
        }
    }
}
