import Foundation
import Testing
import TagLibAudioMetadata

struct ID3ContainerLifecycleTests {
    struct Entry: Sendable { let item: ID3SemanticLifecycleTests.Case; let ext: String }
    static let cases = ["aac", "wav", "aiff", "tta", "dsf", "dff"].flatMap { ext in
        ID3SemanticLifecycleTests.cases.map { Entry(item: $0, ext: ext) }
    }

    @Test(arguments: cases, SemanticLifecycleMatrixTests.Operation.allCases)
    func nativeContainerFrameLifecycle(_ entry: Entry, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        let (item, ext) = (entry.item, entry.ext)
        let name = ["dsf", "dff"].contains(ext) ? "hardening" : ext == "aiff" ? "clean-room" : "testAudioFile"
        try HardeningFixture.withCopy(ext, name: name) { url in
            let parts = item.frame.split(separator: ":", maxSplits: 1).map(String.init)
            let frame = StructuredID3v2Frame(frameID: parts[0], type: parts.count == 2 ? "userText" : "text",
                values: operation == .set ? [] : ["2004"], description: parts.count == 2 ? parts[1] : nil)
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: [frame,
                .init(frameID: "TXXX", type: "userText", values: ["duplicate", "duplicate", "  padded  "], description: "X-KEEP")
            ]), to: url)
            let before = try IndependentID3ContainerProbe.read(url)
            #expect((before.frames[item.frame] == nil) == (operation == .set))
            let isDate = [MetadataFieldKey.year, .standaloneDate, .releaseDate, .originalReleaseDate].contains(item.field)
            let text = isDate ? "2017-06-09" : "Replacement"
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: operation == .remove ? .remove : .text(text)]), to: url)
            let after = try IndependentID3ContainerProbe.read(url)
            if operation == .remove {
                #expect(after.frames[item.frame] == nil)
            } else {
                let payload = try #require(after.frames[item.frame]?.first)
                let expected = parts.count == 2 ? parts[1] + "\0" + text : text
                #expect(payload == Data([3]) + Data(expected.utf8))
                #expect(after.frames[item.frame]?.count == 1)
            }
            #expect(after.frames.filter { $0.key != item.frame } == before.frames.filter { $0.key != item.frame })
            #expect(after.audio == before.audio)
        }
    }
}
