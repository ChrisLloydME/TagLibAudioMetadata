import Foundation
import Testing

struct NativeProbeContractTests {
    private func withBytes(_ data: Data, _ check: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        try check(url)
    }

    private func atom(_ type: String, _ payload: Data, extended: Bool = false, toEnd: Bool = false) -> Data {
        let header = extended
            ? HardeningFixture.number(1, bytes: 4) + Data(type.utf8) + HardeningFixture.number(UInt64(payload.count + 16), bytes: 8)
            : HardeningFixture.number(toEnd ? 0 : UInt64(payload.count + 8), bytes: 4) + Data(type.utf8)
        return header + payload
    }

    @Test func mp4ExtendedAndZeroSizeAtomsKeepValuesAndAudio() throws {
        let audio = Data([0x11, 0x22, 0x33, 0x44])
        let value = atom("data", Data(repeating: 0, count: 8) + Data("Hello".utf8), extended: true)
        let mean = atom("mean", Data(repeating: 0, count: 4) + Data("com.apple.iTunes".utf8))
        let name = atom("name", Data(repeating: 0, count: 4) + Data("DATE".utf8))
        let item = atom("----", mean + name + value)
        let metadata = atom("moov", atom("udta", atom("meta", Data(repeating: 0, count: 4) + atom("ilst", item))), extended: true)
        try withBytes(metadata + atom("mdat", audio, toEnd: true)) { url in
            let parsed = try IndependentMP4Probe.read(url)
            #expect(parsed.values["----:com.apple.iTunes:DATE"] == [Data("Hello".utf8)])
            #expect(parsed.audio == [audio])
        }
    }

    @Test func malformedMP4LengthsAndFreeformsThrowRatherThanGuess() throws {
        let audio = atom("mdat", Data([1]))
        let malformed = [Data(), Data([0, 0, 0]),
            HardeningFixture.number(4, bytes: 4) + Data("moov".utf8),
            HardeningFixture.number(1, bytes: 4) + Data("moov".utf8),
            HardeningFixture.number(1, bytes: 4) + Data("moov".utf8) + Data(repeating: 0xff, count: 8),
            atom("moov", atom("udta", atom("meta", Data([0])))),
            atom("moov", atom("udta", atom("meta", Data(repeating: 0, count: 4) + atom("ilst", atom("----", Data())))))
        ]
        for bytes in malformed {
            try withBytes(audio + bytes) { url in
                #expect(throws: IndependentMP4Probe.Invalid.self) { try IndependentMP4Probe.read(url) }
            }
        }
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
    @Test func asfContentDescriptionVectorAndMalformedBounds() throws {
        func container(_ payload: Data) -> Data {
            let object = IndependentASF.Object(id: IndependentASF.hex("3326b2758e66cf11a6d900aa0062ce6c"), payload: payload).bytes
            return IndependentASF.header + HardeningFixture.number(UInt64(30 + object.count), bytes: 8, little: true)
                + Data([1, 0, 0, 0, 1, 2]) + object
        }
        // Literal wire vector: five byte lengths then UTF-16LE strings.
        let payload = Data([4, 0, 2, 0, 2, 0, 4, 0, 2, 0, 84, 0, 0, 0, 0, 0, 0, 0, 67, 0, 0, 0, 0, 0])
        #expect(try IndependentASF.contentFields(container(payload)) == ["T", "", "", "C", ""])
        for malformed in [Data(), Data(payload.dropLast()), payload + Data([0]), Data([3]) + payload.dropFirst()] {
            #expect(throws: HardeningFixture.Invalid.self) { try IndependentASF.contentFields(container(malformed)) }
        }
    }

}
