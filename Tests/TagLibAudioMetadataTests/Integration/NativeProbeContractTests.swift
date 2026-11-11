import Foundation
import Testing

struct NativeProbeContractTests {
    private func withBytes(_ data: Data, _ check: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        try check(url)
    }

    @Test func flacKnownVectorKeepsDuplicateCommentEntriesAndAudio() throws {
        var comments = Data([0, 0, 0, 0, 3, 0, 0, 0]) // Empty vendor, three entries.
        for text in ["TITLE=Hello", "X-KEEP=A", "X-KEEP=A"] {
            comments += Data([UInt8(text.utf8.count), 0, 0, 0]) + Data(text.utf8)
        }
        let audio = Data([0xff, 0xf8, 0x12, 0x34])
        let bytes = Data("fLaC".utf8) + Data([0x84, 0, 0, UInt8(comments.count)]) + comments + audio
        try withBytes(bytes) { url in
            let state = try IndependentFLACProbe.read(url)
            #expect(state.comments == ["TITLE": ["Hello"], "X-KEEP": ["A", "A"]])
            #expect(state.audio == audio)
        }
    }

    @Test func malformedFLACCommentLengthsThrowRatherThanGuess() throws {
        for bytes in [Data(), Data("fLaC".utf8), Data("fLaC".utf8) + Data([0x84, 0xff, 0xff, 0xff]),
                      Data("fLaC".utf8) + Data([0x84, 0, 0, 8, 0xff, 0xff, 0xff, 0x7f, 0, 0, 0, 0, 1])] {
            try withBytes(bytes) { url in
                #expect(throws: IndependentFLACProbe.Invalid.self) { try IndependentFLACProbe.read(url) }
            }
        }
    }

    @Test func id3KnownVectorAndUnsupportedHeaderBounds() throws {
        let frame = Data([84, 73, 84, 50, 0, 0, 0, 6, 0, 0, 3]) + Data("Hello".utf8)
        let header = Data([73, 68, 51, 4, 0, 0, 0, 0, 0, 16])
        let audio = Data([0xff, 0xfb, 0x12, 0x34])
        try withBytes(header + frame + audio) { url in
            let state = try IndependentID3Probe.read(url)
            #expect(state.texts == ["TIT2": ["Hello"]])
            #expect(state.audio == audio)
            #expect(state.frames["TIT2"] == [frame])
        }
        var wrongVersion = header + frame + audio
        wrongVersion[3] = 3
        for bytes in [Data(), wrongVersion, header + frame.prefix(4)] {
            try withBytes(bytes) { url in
                #expect(throws: IndependentID3Probe.Invalid.self) { try IndependentID3Probe.read(url) }
            }
        }
    }
}
