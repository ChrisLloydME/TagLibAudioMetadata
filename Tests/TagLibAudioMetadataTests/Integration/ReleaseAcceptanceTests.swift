import Foundation
import Testing
import CTagLibBridge
@testable import TagLibAudioMetadata

struct ReleaseAcceptanceTests {
    @Test func structuredMP4RejectsEncodingAndRangeBypasses() throws {
        let invalid: [[String: NSObject]] = [
            ["key": " trkn " as NSString, "type": "intPair" as NSString, "first": NSNumber(value: 70000), "second": NSNumber(value: 0)],
            ["key": "tmpo" as NSString, "type": "int" as NSString, "value": NSNumber(value: 70000)],
            ["key": "rtng" as NSString, "type": "int" as NSString, "value": NSNumber(value: 256)],
            ["key": "stik" as NSString, "type": "int" as NSString, "value": NSNumber(value: 256)],
            ["key": "pgap" as NSString, "type": "stringList" as NSString, "values": ["yes"] as NSArray],
            ["key": "tvsn" as NSString, "type": "stringList" as NSString, "values": ["5"] as NSArray],
            ["key": "----:com.apple.iTunes:AUDIT" as NSString, "type": "int" as NSString, "value": NSNumber(value: 5)],
        ]
        for atom in invalid {
            try RepairNativeProbe.withCopy("m4a") { url in
                let bytes = try Data(contentsOf: url)
                #expect(throws: (any Error).self) {
                    try TagLibMetadataExtractor.writeStructuredMetadata(["mp4Atoms": [atom as NSDictionary] as NSArray], to: url)
                }
                #expect(try Data(contentsOf: url) == bytes)
            }
        }
    }

    @Test func malformedNumberTextCannotEraseExistingPairs() throws {
        for text in ["garbage", "-1", "1/no", "1/2/3", "99999999999999999999999999999999", "1\0/2"] {
            try RepairNativeProbe.withCopy("m4a") { url in
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(3)]), to: url)
                let bytes = try Data(contentsOf: url)
                MetadataFileTransaction.$willStageForTesting.withValue({ _ in
                    Issue.record("Malformed numberText must reject before staging")
                }) {
                    #expect(throws: (any Error).self) {
                        try TagLibMetadataManager.applyMetadataPatch(.init(numberText: .init(trackNumberText: text)), to: url)
                    }
                }
                #expect(try Data(contentsOf: url) == bytes)
            }
        }
    }

    @Test func excessiveInheritedPaddingDoesNotRemoveTrack() throws {
        try RepairNativeProbe.withCopy("mp3") { url in
            try TagLibMetadataExtractor.writeStructuredMetadata(["id3v2Frames": [["id": "TRCK", "type": "text", "values": [String(repeating: "0", count: 64) + "3/12"]] as NSDictionary] as NSArray], to: url)
            let model = try TagLibMetadataExtractor.extractMetadata(from: url)
            #expect(model.trackNumber == 3 && model.totalTracks == 12)
            let bytes = try Data(contentsOf: url)
            model.title = "Unrelated title"
            do {
                try TagLibMetadataExtractor.writeMetadata(model, to: url)
                let after = try IndependentID3Probe.read(url)
                #expect(after.texts["TRCK"]?.first == String(repeating: "0", count: 64) + "3/12")
            } catch {
                #expect(try Data(contentsOf: url) == bytes)
            }
        }
    }
    @Test func protectedDateFlagsSurviveOrRejectUnrelatedMutation() throws {
        for (status, format, group) in [(UInt8(0x20), UInt8(0), UInt8?.none), (UInt8(0), UInt8(0x20), UInt8?(7))] {
            try RepairNativeProbe.withCopy("mp3") { url in
                let frames = RepairV23Seed.textFrame("TYER", "2004", status: status, format: format, groupID: group)
                    + RepairV23Seed.textFrame("TDAT", "0906", status: status, format: format, groupID: group)
                try RepairV23Seed.seedMP3(url, frames: frames)
                let original = try Data(contentsOf: url)
                do {
                    try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("Unrelated")]), to: url)
                    let saved = try Data(contentsOf: url)
                    for owner in ["TYER", "TDAT"] {
                        let range = try #require(saved.range(of: Data(owner.utf8)))
                        #expect(saved[range.lowerBound + 8] == status)
                        #expect(saved[range.lowerBound + 9] == format)
                    }
                } catch {
                    #expect(try Data(contentsOf: url) == original)
                }
            }
        }
    }

    @Test func structuredPayloadsRequireExplicitValues() throws {
        for ext in ["m4a", "wma"] {
            let entries: [[String: NSObject]] = ext == "m4a"
                ? [["key": "©nam" as NSString, "type": "stringList" as NSString],
                   ["key": "pgap" as NSString, "type": "bool" as NSString, "value": "garbage" as NSString]]
                : [["key": "KEEP" as NSString, "type": "int" as NSString],
                   ["key": "KEEP" as NSString, "type": "string" as NSString],
                   ["key": "KEEP" as NSString, "type": "bool" as NSString, "value": "garbage" as NSString]]
            for entry in entries {
                try RepairNativeProbe.withCopy(ext) { url in
                    let bytes = try Data(contentsOf: url)
                    #expect(throws: (any Error).self) {
                        try TagLibMetadataExtractor.writeStructuredMetadata(
                            [ext == "m4a" ? "mp4Atoms" : "asfAttributes": [entry as NSDictionary] as NSArray], to: url)
                    }
                    #expect(try Data(contentsOf: url) == bytes)
                }
            }
        }
    }

    @Test func nativeMP4EncodersRetainValidBoundaryValues() throws {
        try RepairNativeProbe.withCopy("m4a") { url in
            let atoms: [[String: NSObject]] = [
                ["key": " trkn " as NSString, "type": "intPair" as NSString, "first": NSNumber(value: 65535), "second": NSNumber(value: 32768)],
                ["key": "rtng" as NSString, "type": "longLong" as NSString, "value": NSNumber(value: 255)],
                ["key": "cnID" as NSString, "type": "longLong" as NSString, "value": NSNumber(value: 4_294_967_295)],
                ["key": "pgap" as NSString, "type": "bool" as NSString, "value": NSNumber(value: false)],
                ["key": "©mvi" as NSString, "type": "uint" as NSString, "value": NSNumber(value: 32767)],
            ]
            try TagLibMetadataExtractor.writeStructuredMetadata(["mp4Atoms": atoms.map { $0 as NSDictionary } as NSArray], to: url)
            let native = try IndependentMP4Probe.read(url)
            #expect(native.values["trkn"] == [Data([0,0,255,255,128,0,0,0])])
            #expect(native.values["rtng"] == [Data([255])])
            #expect(native.values["cnID"] == [Data([0,0,0,0,255,255,255,255])])
            #expect(native.values["pgap"] == [Data([0])])
            #expect(native.values["©mvi"] == [Data([127,255])])
        }
    }

    @Test func legacyID3MustFitItsDeclaredContainerChunk() throws {
        try RepairNativeProbe.withCopy("wav") { url in
            try RepairV23Seed.seedWAV(url, frames: RepairV23Seed.textFrame("TYER", "2004"))
            var data = try Data(contentsOf: url)
            #expect(data[12..<16] == Data("ID3 ".utf8))
            // The tag header promises a body that extends beyond this declared
            // ID3 chunk, even though enough bytes remain in the outer file.
            data.replaceSubrange(16..<20, with: RepairNativeProbe.number(10, bytes: 4, little: true))
            try data.write(to: url)
            #expect(throws: (any Error).self) { _ = try TagLibMetadataManager.readSnapshot(from: url) }
        }
    }

    @Test func directStructuredValidationPrecedesFileAccess() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Missing-\(UUID()).m4a")
        do {
            try TagLibMetadataExtractor.writeStructuredMetadata(["mp4Atoms": [[
                "key": "trkn", "type": "intPair", "first": 70000, "second": 0,
            ] as NSDictionary] as NSArray], to: url)
            Issue.record("Invalid native encoding must reject")
        } catch {
            #expect((error as NSError).domain == "TagLibMetadataExtractor")
            #expect((error as NSError).code == 243)
        }
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

}
