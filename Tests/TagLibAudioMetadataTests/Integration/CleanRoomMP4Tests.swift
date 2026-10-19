import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

struct CleanRoomMP4Tests {
    // Independent bounded atom walker, including native freeform names and data.
    private func state(_ url: URL) throws -> (items: [String: [Data]], audio: [Data]) {
        let data = try Data(contentsOf: url)
        func atoms(_ range: Range<Int>) throws -> [(String, Range<Int>)] {
            var offset = range.lowerBound
            var result: [(String, Range<Int>)] = []
            while offset < range.upperBound {
                try #require(range.upperBound - offset >= 8)
                var length = try HardeningFixture.integer(data, offset, 4)
                var header = 8
                if length == 1 { length = try HardeningFixture.integer(data, offset + 8, 8); header = 16 }
                if length == 0 { length = range.upperBound - offset }
                try #require(length >= header && length <= range.upperBound - offset)
                let type = try #require(String(data: data[(offset + 4)..<(offset + 8)], encoding: .isoLatin1))
                result.append((type, (offset + header)..<(offset + length)))
                offset += length
            }
            return result
        }
        var children = try atoms(0..<data.count)
        let audio = children.filter { $0.0 == "mdat" }.map { Data(data[$0.1]) }
        for name in ["moov", "udta", "meta", "ilst"] {
            let container = try #require(children.first { $0.0 == name })
            children = try atoms((container.1.lowerBound + (name == "meta" ? 4 : 0))..<container.1.upperBound)
        }
        var items: [String: [Data]] = [:]
        for (type, range) in children {
            if type != "----" { items[type, default: []].append(Data(data[range])); continue }
            let inner = try atoms(range)
            let mean = try #require(inner.first { $0.0 == "mean" })
            let name = try #require(inner.first { $0.0 == "name" })
            let key = "----:" + String(decoding: data[mean.1].dropFirst(4), as: UTF8.self)
                + ":" + String(decoding: data[name.1].dropFirst(4), as: UTF8.self)
            items[key, default: []].append(Data(data[range]))
        }
        return (items, audio)
    }

    private let fields: [(MetadataFieldKey, WritableKeyPath<BasicMetadata, String>, String)] = [
        (.work, \.work, "WORK"), (.acoustID, \.acoustID, "Acoustid Id"),
        (.acoustIDFingerprint, \.acoustIDFingerprint, "Acoustid Fingerprint"),
        (.originalReleaseDate, \.originalReleaseDate, "ORIGINAL YEAR"),
        (.artistType, \.artistType, "ARTISTTYPE"), (.musicIPPUID, \.musicIPPUID, "MusicIP PUID")
    ]

    @Test func freeformFieldsRoundTripAcrossBasicAndPatchWithoutStaleAliases() throws {
        for (field, path, description) in fields {
            for basicSeed in [false, true] {
                try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
                    let key = "----:com.apple.iTunes:" + description
                    if basicSeed {
                        try TagLibMetadataManager.updateBasicMetadata(at: url) { $0[keyPath: path] = "OLD" }
                    } else {
                        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                            StructuredMetadata(mp4Atoms: [.init(key: key, type: "stringList", values: ["OLD"])]), to: url)
                    }
                    let before = try state(url)
                    try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields: [field: .text("NEW")]), to: url)
                    #expect(try TagLibMetadataManager.readMetadataResult(from: url)[keyPath: path] == "NEW")
                    let after = try state(url)
                    #expect(after.audio == before.audio)
                    #expect(after.items[key]?.count == 1)
                    #expect(after.items[key]?.first?.range(of: Data("NEW".utf8)) != nil)
                    let schema = try #require(MetadataFieldRegistry.schema(for: field))
                    let aliasKeys = Set(schema.propertyMapKeys.map { "----:com.apple.iTunes:" + $0 })
                        .union([key, field == .work ? "©wrk" : key])
                    for (native, payloads) in before.items where !aliasKeys.contains(native) {
                        #expect(after.items[native] == payloads, "Unrelated native item changed: \(native)")
                    }
                    try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
                    #expect(try state(url).items[key] == after.items[key])
                    try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields: [field: .remove]), to: url)
                    #expect(try TagLibMetadataManager.readMetadataResult(from: url)[keyPath: path].isEmpty)
                    #expect(try state(url).items[key] == nil)
                }
            }
        }
    }

    @Test func freeformPatchRemovesCompetingRepresentations() throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(StructuredMetadata(mp4Atoms: [
                .init(key: "----:com.apple.iTunes:Acoustid Id", type: "stringList", values: ["Old A"]),
                .init(key: "----:com.apple.iTunes:ACOUSTID_ID", type: "stringList", values: ["Old B"]),
                .init(key: "----:com.apple.iTunes:WORK", type: "stringList", values: ["Old A"]),
                .init(key: "©wrk", type: "stringList", values: ["Old B"])
            ]), to: url)
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.acoustID: .text("New ID"), .work: .text("New work")]), to: url)
            let after = try state(url)
            #expect(after.items["©wrk"] == nil)
            #expect(after.items["----:com.apple.iTunes:ACOUSTID_ID"] == nil)
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).work == "New work")
        }
    }

    @Test func unrelatedBasicAndTrackOnlyWritesPreserveNumberAliases() throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            let names = ["TRACKNUMBER", "TRACKTOTAL", "TRACK", "TOTALTRACKS", "DISCNUMBER", "DISCTOTAL", "DISC", "TOTALDISCS"]
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(StructuredMetadata(mp4Atoms:
                names.map { .init(key: "----:com.apple.iTunes:" + $0, type: "stringList", values: ["CUSTOM-" + $0]) }
                + [.init(key: "trkn", type: "intPair", first: 3, second: 12),
                   .init(key: "disk", type: "intPair", first: 1, second: 2)]), to: url)
            let before = try state(url)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Title only" }
            for name in names { #expect(try state(url).items["----:com.apple.iTunes:" + name] == before.items["----:com.apple.iTunes:" + name]) }
            try TagLibMetadataExtractor.writeTrackNumber(7, totalTracks: 20, padWidth: 2, to: url)
            let after = try state(url)
            for name in names.filter({ $0.contains("DISC") }) {
                #expect(after.items["----:com.apple.iTunes:" + name] == before.items["----:com.apple.iTunes:" + name])
            }
            #expect(after.audio == before.audio)
        }
    }

    @Test func customCaseProjectionHasOneIdentityAndPreservesNativeSpelling() throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            let key = "----:com.apple.iTunes:MyField"
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(mp4Atoms: [.init(key: key, type: "stringList", values: ["Old"])]), to: url)
            let basic = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(basic.customFields.keys.filter { $0.uppercased() == "MYFIELD" }.count == 1)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.customFields["MYFIELD"] = "New" }
            let after = try state(url)
            #expect(after.items[key]?.count == 1)
            #expect(after.items["----:com.apple.iTunes:MYFIELD"] == nil)
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).customFields["MYFIELD"] == "New")
        }
    }
}
