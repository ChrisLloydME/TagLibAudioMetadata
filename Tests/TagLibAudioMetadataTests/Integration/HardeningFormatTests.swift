import Foundation
import Testing
import TagLibAudioMetadata

struct HardeningFormatTests {
    @Test func dsdReadsNativeCollectionsAndRawDeltasPreservePayloads() throws {
        for ext in ["dsf", "dff"] {
            try HardeningFixture.withCopy(ext) { url in
                let cover = try Data(contentsOf: HardeningFixture.url("jpg", name: "testCover"))
                let title = HardeningFixture.frame("TIT2", Data([3]) + Data("DSD original".utf8))
                let comment = HardeningFixture.frame("COMM", Data([3]) + Data("deuNotes".utf8) + Data([0]) + Data("Native comment".utf8))
                let lyric = HardeningFixture.frame("USLT", Data([3]) + Data("fraWords".utf8) + Data([0]) + Data("Native lyric".utf8))
                let picture = HardeningFixture.frame("APIC", Data([3]) + Data("image/jpeg".utf8) + Data([0, 3]) + Data("DSD cover".utf8) + Data([0]) + cover)
                let opaque = HardeningFixture.frame("XZZZ", Data([1, 2, 3, 4]))
                try HardeningFixture.seedDSDTag(HardeningFixture.id3(title + comment + lyric + picture + opaque), at: url)
                let before = try HardeningFixture.dsdState(Data(contentsOf: url), ext: ext)
                let nativeBefore = try HardeningFixture.frames(before.tag)
                let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
                #expect(snapshot.basic.title == "DSD original")
                #expect(snapshot.basic.sampleRate == 2_822_400)
                #expect(snapshot.basic.channels == 2)
                #expect(snapshot.basic.duration > 0)
                #expect(snapshot.raw.properties.contains { $0.key == "TITLE" && $0.values == ["DSD original"] })
                #expect(snapshot.structured.comments.contains { $0.language == "deu" && $0.description == "Notes" && $0.text == "Native comment" })
                #expect(snapshot.structured.lyrics.contains { $0.language == "fra" && $0.text == "Native lyric" })
                #expect(snapshot.structured.artwork.first?.data == cover)
                try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["TITLE": ["DSD updated"]]), to: url)
                #expect(try TagLibMetadataManager.readBasicSnapshot(from: url).metadata.title == "DSD updated")
                let after = try HardeningFixture.dsdState(Data(contentsOf: url), ext: ext)
                let nativeAfter = try HardeningFixture.frames(after.tag)
                #expect(after.audio == before.audio)
                for id in ["COMM", "USLT", "APIC", "XZZZ"] { #expect(nativeAfter[id] == nativeBefore[id], "\(ext): \(id)") }
                let bytes = try Data(contentsOf: url)
                #expect(throws: (any Error).self) {
                    try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                        StructuredMetadata(comments: [.init(text: "Unsupported native replacement")]), to: url)
                }
                #expect(try Data(contentsOf: url) == bytes)
                // The Basic preservation path must not commit a lossy projection
                // when it cannot replay the native DSD comment/lyric collections.
                #expect(throws: (any Error).self) {
                    try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Requires native replay" }
                }
                #expect(try Data(contentsOf: url) == bytes)
            }
        }
    }

    @Test func dsdBasicAndArtworkWritesPreserveAudio() throws {
        for ext in ["dsf", "dff"] {
            try HardeningFixture.withCopy(ext) { url in
                let audio = try HardeningFixture.dsdState(Data(contentsOf: url), ext: ext).audio
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Basic DSD" }
                #expect(try TagLibMetadataManager.readMetadataResult(from: url).title == "Basic DSD")
                let cover = try Data(contentsOf: HardeningFixture.url("jpg", name: "testCover"))
                try TagLibMetadataManager.applyMetadataPatch(.init(artwork: .replace([
                    .init(pictureTypeCode: 3, mimeType: "image/jpeg", description: "Native DSD image", data: cover)
                ])), to: url)
                let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
                #expect(snapshot.structured.artwork.first?.data == cover)
                #expect(snapshot.structured.artwork.first?.description == "Native DSD image")
                #expect(try HardeningFixture.dsdState(Data(contentsOf: url), ext: ext).audio == audio)
                try TagLibMetadataManager.applyMetadataPatch(.init(artwork: .removeAll), to: url)
                #expect(try TagLibMetadataManager.readStructuredMetadataResult(from: url).artwork.isEmpty)
                #expect(try HardeningFixture.dsdState(Data(contentsOf: url), ext: ext).audio == audio)
            }
        }
    }

    @Test func apeAndMusepackPublicWritesPreserveNativeTagsAndAudio() throws {
        for ext in ["ape", "mpc"] {
            try HardeningFixture.withCopy(ext) { url in
                let initial = try TagLibMetadataManager.readSnapshot(from: url)
                #expect(initial.basic.sampleRate == 44_100)
                #expect(initial.basic.channels == 2)
                #expect(initial.basic.duration > 0)
                let audio = try HardeningFixture.apeState(Data(contentsOf: url)).audio
                let cover = try Data(contentsOf: HardeningFixture.url("jpg", name: "testCover"))
                try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: [
                    "TITLE": ["APE original"], "HARDEN_KEEP": ["one", "two"]
                ]), to: url)
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(artwork: [.init(pictureTypeCode: 3, mimeType: "image/jpeg", data: cover)]), to: url)
                // Multiple APE artwork writes are deliberately unsupported. Seed the
                // back cover independently to exercise preservation of existing data.
                let seeded = try HardeningFixture.apeState(Data(contentsOf: url))
                var nativeItems = seeded.items
                nativeItems["COVER ART (BACK)"] = .init(flags: 2, value: Data("back.jpg\0".utf8) + cover)
                try HardeningFixture.writeAPE(audio: seeded.audio, items: nativeItems, to: url)
                let before = try HardeningFixture.apeState(Data(contentsOf: url))
                #expect(before.items["HARDEN_KEEP"]?.value == Data("one\0two".utf8))
                #expect(before.items["COVER ART (FRONT)"]?.flags == 2)
                #expect(before.items["COVER ART (BACK)"]?.flags == 2)
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Basic edit" }
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.album: .text("Typed album")]), to: url)
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(properties: [.init(key: "TITLE", values: ["Structured edit"])]), to: url, includeProperties: true)
                let after = try HardeningFixture.apeState(Data(contentsOf: url))
                #expect(try TagLibMetadataManager.readSnapshot(from: url).basic.title == "Structured edit")
                #expect(after.items["TITLE"]?.value == Data("Structured edit".utf8))
                #expect(after.items["ALBUM"]?.value == Data("Typed album".utf8))
                for key in ["HARDEN_KEEP", "COVER ART (FRONT)", "COVER ART (BACK)"] { #expect(after.items[key] == before.items[key]) }
                #expect(after.audio == audio)
                #expect(Set(try TagLibMetadataManager.readStructuredMetadataResult(from: url).artwork.compactMap(\.pictureTypeCode)) == [3, 4])
                let version = try TagLibMetadataManager.fileVersion(at: url)
                try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: ["HARDEN_NEW": ["revision"]]), to: url)
                let bytes = try Data(contentsOf: url)
                #expect(throws: TagLibManagerError.self) {
                    try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("Stale")]), to: url, expectedVersion: version)
                }
                #expect(try Data(contentsOf: url) == bytes)
                #expect(throws: (any Error).self) {
                    try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                        StructuredMetadata(comments: [.init(text: "Unsupported")]), to: url)
                }
                #expect(try Data(contentsOf: url) == bytes)
                try TagLibMetadataManager.applyMetadataPatch(.init(artwork: .removeAll), to: url)
                let cleared = try HardeningFixture.apeState(Data(contentsOf: url))
                #expect(cleared.items.keys.allSatisfy { !$0.hasPrefix("COVER ART (") })
                #expect(cleared.audio == audio)
                #expect(cleared.items["HARDEN_KEEP"] == before.items["HARDEN_KEEP"])
            }
        }
    }
}
