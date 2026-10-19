import Foundation
import Testing
import TagLibAudioMetadata

struct ReviewNativeContainerTests {
    private struct Atom {
        let type: String
        let payload: Range<Int>
    }

    private func withFixture(_ ext: String, _ body: (URL) throws -> Void) throws {
        let source = try #require(
            Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext)
        )
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NativeReview-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.\(ext)")
        try FileManager.default.copyItem(at: source, to: url)
        try body(url)
    }

    // A bounds-checked ISO BMFF atom walker, independent of TagLib and its projections.
    private func atoms(in data: Data, range: Range<Int>) throws -> [Atom] {
        var result: [Atom] = []
        var offset = range.lowerBound
        while offset < range.upperBound {
            try #require(range.upperBound - offset >= 8)
            let size32 = data[offset..<(offset + 4)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            let type = try #require(String(data: data[(offset + 4)..<(offset + 8)], encoding: .isoLatin1))
            var headerSize = 8
            var size = size32
            if size32 == 1 {
                try #require(range.upperBound - offset >= 16)
                size = data[(offset + 8)..<(offset + 16)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
                headerSize = 16
            } else if size32 == 0 {
                size = UInt64(range.upperBound - offset)
            }
            try #require(size >= headerSize && size <= UInt64(range.upperBound - offset))
            let end = offset + Int(size)
            result.append(Atom(type: type, payload: (offset + headerSize)..<end))
            offset = end
        }
        return result
    }

    private func mp4State(at url: URL) throws -> (items: [String: [Data]], audio: [Data]) {
        let data = try Data(contentsOf: url)
        let top = try atoms(in: data, range: 0..<data.count)
        let audio = top.filter { $0.type == "mdat" }.map { Data(data[$0.payload]) }
        var children = top
        for component in ["moov", "udta", "meta", "ilst"] {
            let container = try #require(children.first { $0.type == component })
            let start = container.payload.lowerBound + (component == "meta" ? 4 : 0)
            try #require(start <= container.payload.upperBound)
            children = try atoms(in: data, range: start..<container.payload.upperBound)
        }
        var items: [String: [Data]] = [:]
        for atom in children { items[atom.type, default: []].append(Data(data[atom.payload])) }
        return (items, audio)
    }

    @Test func mp4DeltasPreserveNativeAtomsAndAudioPayload() throws {
        try withFixture("m4a") { url in
            var seed = BasicMetadata.empty
            seed.title = "Original"
            seed.artist = "Independent Artist"
            seed.album = "Independent Album"
            seed.track = 3
            seed.trackTotal = 10
            seed.disc = 1
            seed.discTotal = 2
            seed.customFields = ["REVIEW_KEEP": "Independent custom value"]
            let coverURL = try #require(
                Bundle.module.url(forResource: "testCover", withExtension: "jpg", subdirectory: "Artwork")
                    ?? Bundle.module.url(forResource: "testCover", withExtension: "jpg")
            )
            seed.artworkData = try Data(contentsOf: coverURL)
            seed.artworkMIMEType = "image/jpeg"
            try TagLibMetadataManager.replaceBasicMetadata(seed, to: url)
            try TagLibMetadataManager.writeTrackNumberText("03/10", discNumberText: "01/02", to: url)
            let before = try mp4State(at: url)
            #expect(before.items["trkn"]?.count == 1)
            #expect(before.items["disk"]?.count == 1)
            #expect(before.items["covr"]?.first?.range(of: try #require(seed.artworkData)) != nil)
            #expect(before.items["----"]?.contains { $0.range(of: Data("TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT".utf8)) != nil } == true)
            #expect(!before.audio.isEmpty)

            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(properties: [.init(key: "TITLE", values: ["Structured edit"])]),
                to: url, includeProperties: true
            )
            try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                ["TITLE": "Raw merge edit"], to: url, mode: .merge
            )
            let after = try mp4State(at: url)
            #expect(after.items["©nam"]?.first?.range(of: Data("Raw merge edit".utf8)) != nil)
            for (key, payloads) in before.items where key != "©nam" {
                #expect(after.items[key] == payloads, "Unrelated MP4 atom changed: \(key)")
            }
            #expect(after.audio == before.audio)
        }
    }

    @Test func nativeASFCustomNamesDoNotBlockUnrelatedBasicEdits() throws {
        try withFixture("wma") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(asfAttributes: [
                    .init(key: "PUBLISHER", type: "string", value: "Native custom publisher")
                ]), to: url
            )
            let before = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(before.customFields["PUBLISHER"] == "Native custom publisher")
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated edit" }
            let after = try TagLibMetadataManager.readStructuredMetadataResult(from: url)
            #expect(after.asfAttributes.contains { $0.key == "PUBLISHER" && $0.value == "Native custom publisher" })
            let bytes = try Data(contentsOf: url)
            var edit = try TagLibMetadataManager.readMetadataResult(from: url)
            edit.customFields["PUBLISHER"] = "Ambiguous edit"
            #expect(throws: MetadataValidationError.self) {
                try TagLibMetadataManager.replaceBasicMetadata(edit, to: url)
            }
            #expect(try Data(contentsOf: url) == bytes)
        }
    }

    @Test func apeArtworkReaderDistinguishesNativeCoverRoles() throws {
        try withFixture("wv") { url in
            try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url)
            let audio = try Data(contentsOf: url)
            let coverURL = try #require(
                Bundle.module.url(forResource: "testCover", withExtension: "jpg", subdirectory: "Artwork")
                    ?? Bundle.module.url(forResource: "testCover", withExtension: "jpg")
            )
            let picture = try Data(contentsOf: coverURL)
            func littleEndian(_ value: Int) -> Data {
                Data((0..<4).map { UInt8((value >> ($0 * 8)) & 0xff) })
            }
            var items = Data()
            for role in ["Front", "Back"] {
                let value = Data("cover.jpg".utf8) + Data([0]) + picture
                items += littleEndian(value.count) + littleEndian(2)
                items += Data("Cover Art (\(role))".utf8) + Data([0]) + value
            }
            let footer = Data("APETAGEX".utf8) + littleEndian(2000)
                + littleEndian(items.count + 32) + littleEndian(2)
                + littleEndian(0) + Data(repeating: 0, count: 8)
            try (audio + items + footer).write(to: url)
            let pictures = try TagLibMetadataManager.readStructuredMetadataResult(from: url).artwork
            #expect(pictures.count == 2)
            #expect(Set(pictures.compactMap(\.pictureTypeCode)) == [3, 4])
            #expect(pictures.allSatisfy { $0.data == picture })
        }
    }

    @Test func asfUpsertPreservesSiblingAttributePayloads() throws {
        try withFixture("wma") { url in
            let left = "Review left original 641903"
            let right = "Review right untouched 258167"
            let updated = "Review left updated 903416"
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(asfAttributes: [
                    .init(key: "REVIEW_SIBLINGS", type: "string", value: left, language: 0, stream: 0),
                    .init(key: "REVIEW_SIBLINGS", type: "string", value: right, language: 0, stream: 1)
                ]), to: url
            )
            let seeded = try TagLibMetadataManager.readStructuredMetadataResult(from: url).asfAttributes
                .filter { $0.key == "REVIEW_SIBLINGS" }
            #expect(seeded.count == 2)
            let before = try Data(contentsOf: url)
            #expect(before.range(of: try #require(left.data(using: .utf16LittleEndian))) != nil)
            #expect(before.range(of: try #require(right.data(using: .utf16LittleEndian))) != nil)
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(asfAttributes: [
                    .init(key: "REVIEW_SIBLINGS", type: "string", value: updated, language: 0, stream: 0)
                ]), to: url
            )
            let after = try Data(contentsOf: url)
            #expect(after.range(of: try #require(left.data(using: .utf16LittleEndian))) == nil)
            #expect(after.range(of: try #require(updated.data(using: .utf16LittleEndian))) != nil)
            #expect(after.range(of: try #require(right.data(using: .utf16LittleEndian))) != nil)
            let attributes = try TagLibMetadataManager.readStructuredMetadataResult(from: url).asfAttributes
                .filter { $0.key == "REVIEW_SIBLINGS" }
            #expect(attributes.count == 2)
            #expect(attributes.first { $0.stream == 1 }?.value == right)
        }
    }
}
