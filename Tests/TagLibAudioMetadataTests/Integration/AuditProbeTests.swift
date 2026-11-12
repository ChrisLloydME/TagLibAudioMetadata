import Foundation
import Testing
import TagLibAudioMetadata
import CTagLibBridge

/// Independent audit probes for findings in AUD-2026-11-11-package-audit.
/// Each probe is a permanent regression candidate for a reproduced defect.
/// The semantic-path controls at the end document which related behavior still
/// works and keep the failure attributable to the Basic/legacy write surface.
struct AuditProbeTests {
    private func withM4A(_ body: (URL) throws -> Void) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile", body)
    }

    @Test func basicClearOfLegacyBackedMP4FieldsMustCommit() throws {
        let cases: [(MetadataFieldKey, String, [String], (inout BasicMetadata) -> Void, (BasicMetadata) -> String)] = [
            (.encodedBy, "----:com.apple.iTunes:ENCODEDBY", ["Legacy Encoder"],
             { $0.encodedBy = "" }, { $0.encodedBy }),
            (.encoderSettings, "----:com.apple.iTunes:ENCODING", ["Legacy Settings"],
             { $0.encoderSettings = "" }, { $0.encoderSettings }),
            (.publisher, "----:com.apple.iTunes:LABEL", ["Legacy Label"],
             { $0.publisher = "" }, { $0.publisher }),
            (.conductor, "----:com.apple.iTunes:CONDUCTOR", ["Legacy Conductor"],
             { $0.conductor = "" }, { $0.conductor }),
            (.itunesAlbumID, "----:com.apple.iTunes:ITUNESALBUMID", ["12345"],
             { $0.itunesAlbumID = "" }, { $0.itunesAlbumID })
        ]
        for (field, key, values, clear, read) in cases {
            try withM4A { url in
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                    .init(key: key, type: "stringList", values: values)
                ]), to: url)
                var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
                #expect(!read(metadata).isEmpty)
                clear(&metadata)
                do {
                    try TagLibMetadataManager.replaceBasicMetadata(metadata, to: url)
                } catch {
                    Issue.record("Clearing \(field.rawValue) failed: \(error)")
                    return
                }
                #expect(read(try TagLibMetadataManager.readMetadataResult(from: url)).isEmpty,
                        "\(field.rawValue) was not cleared")
                #expect(try IndependentMP4Probe.read(url).items[key] == nil,
                        "Legacy native alias for \(field.rawValue) remains")
            }
        }
    }

    @Test func lowLevelClearMustNotResurrectOldMP4Values() throws {
        try withM4A { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "----:com.apple.iTunes:ENCODEDBY", type: "stringList", values: ["Legacy Encoder"]),
                .init(key: "----:com.apple.iTunes:ENCODING", type: "stringList", values: ["Legacy Settings"]),
                .init(key: "----:com.apple.iTunes:ITUNESALBUMID", type: "stringList", values: ["12345"]),
                .init(key: "----:com.apple.iTunes:WORK", type: "stringList", values: ["Legacy Work"])
            ]), to: url)
            let extracted = try TagLibMetadataExtractor.extractMetadata(from: url)
            let model = extracted
            model.encodedBy = nil
            model.encoderSettings = nil
            model.itunesAlbumId = nil
            model.work = nil
            _ = try TagLibMetadataManager.writeTagMetadata(model, to: url, verification: .none)
            let after = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(after.encodedBy.isEmpty, "Encoded By resurrected: \(after.encodedBy)")
            #expect(after.encoderSettings.isEmpty, "Encoder Settings resurrected: \(after.encoderSettings)")
            #expect(after.itunesAlbumID.isEmpty, "iTunes Album ID resurrected: \(after.itunesAlbumID)")
            #expect(after.work.isEmpty, "Work resurrected: \(after.work)")
        }
    }

    @Test func basicSetMustRetireEditedMP4CompatibilityAliases() throws {
        try withM4A { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "----:com.apple.iTunes:ENCODEDBY", type: "stringList", values: ["Legacy Encoder"]),
                .init(key: "----:com.apple.iTunes:ENCODING", type: "stringList", values: ["Legacy Settings"])
            ]), to: url)
            try TagLibMetadataManager.updateBasicMetadata(at: url) {
                $0.encodedBy = "New Encoder"
                $0.encoderSettings = "New Settings"
            }
            let probe = try IndependentMP4Probe.read(url)
            #expect(probe.items["\u{00A9}enc"] != nil)
            #expect(probe.items["\u{00A9}too"] != nil)
            #expect(probe.items["----:com.apple.iTunes:ENCODEDBY"] == nil,
                    "Legacy ENCODEDBY freeform still duplicates the edited encodedBy")
            #expect(probe.items["----:com.apple.iTunes:ENCODING"] == nil,
                    "Legacy ENCODING freeform still duplicates the edited encoderSettings")
        }
    }

    @Test func basicWorkMustKeepCanonicalOwnerAndRetireLegacyFreeform() throws {
        try withM4A { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "\u{00A9}wrk", type: "stringList", values: ["Old Work"]),
                .init(key: "----:com.apple.iTunes:WORK", type: "stringList", values: ["Old Freeform Work"])
            ]), to: url)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.work = "New Work" }
            let probe = try IndependentMP4Probe.read(url)
            #expect(probe.items["\u{00A9}wrk"] != nil, "Canonical ©wrk was replaced by a freeform")
            #expect(probe.items["----:com.apple.iTunes:WORK"] == nil, "Legacy WORK freeform remains")
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).work == "New Work")
        }
    }

    @Test func basicUnrelatedEditMustPreserveMultivalueDatesOnFLAC() throws {
        try HardeningFixture.withCopy("flac", name: "testAudioFile") { url in
            let values = [
                "YEAR": ["2004", "2005"],
                "DATE": ["2008-03-04", "not-a-date"],
                "RELEASEDATE": ["2017", "2018"],
                "ORIGINALDATE": ["1999", "2000"]
            ]
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: values), to: url)
            let before = try IndependentFLACProbe.read(url)
            for (key, expected) in values { #expect(before.comments[key] == expected) }
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
            let after = try IndependentFLACProbe.read(url)
            for (key, expected) in values {
                #expect(after.comments[key] == expected,
                        "\(key) changed to \(String(describing: after.comments[key]))")
            }
            #expect(after.audio == before.audio)
        }
    }

    @Test func basicUnrelatedEditMustPreserveMultivalueDatesOnAPE() throws {
        try HardeningFixture.withCopy("ape", name: "hardening") { url in
            let values = ["YEAR": ["2004", "2005"], "DATE": ["2008-03-04", "not-a-date"]]
            try TagLibMetadataManager.applyRawMetadataPatch(.init(valuesToSet: values), to: url)
            let before = try HardeningFixture.apeState(try Data(contentsOf: url))
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
            let after = try HardeningFixture.apeState(try Data(contentsOf: url))
            #expect(after.items["YEAR"]?.value == before.items["YEAR"]?.value,
                    "APE YEAR changed: \(String(describing: after.items["YEAR"]?.value))")
            #expect(after.items["DATE"]?.value == before.items["DATE"]?.value,
                    "APE DATE changed: \(String(describing: after.items["DATE"]?.value))")
            #expect(after.audio == before.audio)
        }
    }

    @Test func basicUnrelatedEditMustPreserveMultivalueYearOnID3() throws {
        try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
            let audio = try IndependentID3Probe.read(url).audio
            let frames = HardeningFixture.frame("TDRC", Data([3]) + Data("2004\02005".utf8))
            try (HardeningFixture.id3(frames) + audio).write(to: url)
            let before = try IndependentID3Probe.read(url)
            #expect(before.texts["TDRC"] == ["2004", "2005"])
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
            let after = try IndependentID3Probe.read(url)
            #expect(after.texts["TDRC"] == ["2004", "2005"],
                    "ID3 TDRC values changed to \(String(describing: after.texts["TDRC"]))")
            #expect(after.audio == before.audio)
        }
    }

    @Test func basicUnrelatedEditMustPreserveMP4DateFreeformArrays() throws {
        try withM4A { url in
            let seed: [(String, [String])] = [
                ("\u{00A9}day", ["2004"]),
                ("----:com.apple.iTunes:DATE", ["2008-03-04", "2009-01-01"]),
                ("----:com.apple.iTunes:RELEASEDATE", ["2017", "2018"]),
                ("----:com.apple.iTunes:ORIGINALDATE", ["1999", "2000"])
            ]
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: seed.map { key, values in
                .init(key: key, type: "stringList", values: values)
            }), to: url)
            let before = try IndependentMP4Probe.read(url)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
            let after = try IndependentMP4Probe.read(url)
            for (key, _) in seed {
                #expect(after.items[key] == before.items[key], "MP4 date atom changed or collapsed: \(key)")
            }
            #expect(after.audio == before.audio)
        }
    }

    @Test func basicUnrelatedEditMustAcceptValidMultivalueMP4Year() throws {
        try withM4A { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "\u{00A9}day", type: "stringList", values: ["2004", "2005"])
            ]), to: url)
            let before = try IndependentMP4Probe.read(url)
            do {
                try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
            } catch {
                Issue.record("Basic update rejected an untouched valid multi-value ©day: \(error)")
                return
            }
            #expect(try IndependentMP4Probe.read(url).items["\u{00A9}day"] == before.items["\u{00A9}day"])
        }
    }

    @Test func semanticEncoderRemovalRetiresOnlyOwnedCompatibilityAlias() throws {
        try withM4A { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "----:com.apple.iTunes:ENCODEDBY", type: "stringList", values: ["Legacy Encoder"]),
                .init(key: "\u{00A9}too", type: "stringList", values: ["Settings"]),
                .init(key: "----:com.apple.iTunes:ENCODING", type: "stringList", values: ["Legacy Settings"])
            ]), to: url)
            let before = try IndependentMP4Probe.read(url)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.encodedBy: .remove]), to: url)
            let after = try IndependentMP4Probe.read(url)
            #expect(after.items["----:com.apple.iTunes:ENCODEDBY"] == nil)
            #expect(after.items["\u{00A9}too"] == before.items["\u{00A9}too"])
            #expect(after.items["----:com.apple.iTunes:ENCODING"] == before.items["----:com.apple.iTunes:ENCODING"])
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).encodedBy.isEmpty)
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).encoderSettings == "Settings")
        }
    }

    @Test func basicUnrelatedEditPreservesUnknownAdvisoryOnMP4() throws {
        try withM4A { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "rtng", type: "uint", value: "9")
            ]), to: url)
            let before = try IndependentMP4Probe.read(url)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
            let after = try IndependentMP4Probe.read(url)
            #expect(after.items["rtng"] == before.items["rtng"], "Unknown advisory raw code changed")
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).explicitAdvisoryRawValue == "9")
        }
    }


    @Test func mp4MovementUpperBoundWorksAcrossFacadeEntryPoints() throws {
        let value = Int(Int16.max)
        // Semantic patch
        try withM4A { url in
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [
                .movementNumber: .integer(value), .movementCount: .integer(value)
            ]), to: url)
            let probe = try IndependentMP4Probe.read(url)
            try probe.expectValue(.integer(value), at: "\u{00A9}mvi")
            try probe.expectValue(.integer(value), at: "\u{00A9}mvc")
        }
        // Basic replacement
        try withM4A { url in
            try TagLibMetadataManager.updateBasicMetadata(at: url) {
                $0.movementNumber = value
                $0.movementCount = value
            }
            let probe = try IndependentMP4Probe.read(url)
            try probe.expectValue(.integer(value), at: "\u{00A9}mvi")
            try probe.expectValue(.integer(value), at: "\u{00A9}mvc")
        }
        // Structured write
        try withM4A { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "\u{00A9}mvi", type: "uint", value: String(value)),
                .init(key: "\u{00A9}mvc", type: "uint", value: String(value))
            ]), to: url)
            let probe = try IndependentMP4Probe.read(url)
            try probe.expectValue(.integer(value), at: "\u{00A9}mvi")
            try probe.expectValue(.integer(value), at: "\u{00A9}mvc")
        }
        // Low-level bridge model
        try withM4A { url in
            let extracted = try TagLibMetadataExtractor.extractMetadata(from: url)
            let model = extracted
            model.movementNumber = value
            model.movementCount = value
            _ = try TagLibMetadataManager.writeTagMetadata(model, to: url, verification: .none)
            let probe = try IndependentMP4Probe.read(url)
            try probe.expectValue(.integer(value), at: "\u{00A9}mvi")
            try probe.expectValue(.integer(value), at: "\u{00A9}mvc")
        }
    }

    @Test func mp4MovementOverflowRejectsAcrossFacadeEntryPointsWithoutMutation() throws {
        let value = Int(Int16.max) + 1
        // Basic replacement
        try withM4A { url in
            let before = try Data(contentsOf: url)
            do {
                try TagLibMetadataManager.updateBasicMetadata(at: url) {
                    $0.movementNumber = value
                    $0.movementCount = value
                }
                Issue.record("Basic movement overflow unexpectedly succeeded")
            } catch {
                // Expected.
            }
            #expect(try Data(contentsOf: url) == before)
        }
        // Structured write
        try withM4A { url in
            let before = try Data(contentsOf: url)
            do {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                    .init(key: "\u{00A9}mvi", type: "uint", value: String(value))
                ]), to: url)
                Issue.record("Structured movement overflow unexpectedly succeeded")
            } catch {
                // Expected.
            }
            #expect(try Data(contentsOf: url) == before)
        }
        // Low-level bridge model
        try withM4A { url in
            let before = try Data(contentsOf: url)
            let extracted = try TagLibMetadataExtractor.extractMetadata(from: url)
            let model = extracted
            model.movementNumber = value
            model.movementCount = value
            do {
                _ = try TagLibMetadataManager.writeTagMetadata(model, to: url, verification: .none)
                Issue.record("Low-level movement overflow unexpectedly succeeded")
            } catch {
                // Expected.
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }

    @Test func mp4PairUpperBound65535RoundTrips() throws {
        try withM4A { url in
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [
                .track: .integer(1), .trackTotal: .integer(65535),
                .disc: .integer(1), .discTotal: .integer(65535)
            ]), to: url)
            let basic = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(basic.track == 1 && basic.trackTotal == 65535)
            #expect(basic.disc == 1 && basic.discTotal == 65535)
            let probe = try IndependentMP4Probe.read(url)
            #expect(probe.items["trkn"] != nil)
            #expect(probe.items["disk"] != nil)
        }
    }

    @Test func id3EncodedByEditPreservesEncoderSettings() throws {
        try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: [
                .init(frameID: "TENC", type: "text", values: ["Original Encoded By"]),
                .init(frameID: "TSSE", type: "text", values: ["Original Settings"])
            ]), to: url)
            let before = try IndependentID3Probe.read(url)
            #expect(before.texts["TENC"] == ["Original Encoded By"])
            #expect(before.texts["TSSE"] == ["Original Settings"])
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.encodedBy: .text("New Encoded By")]), to: url)
            let after = try IndependentID3Probe.read(url)
            #expect(after.texts["TENC"] == ["New Encoded By"])
            #expect(after.frames["TSSE"] == before.frames["TSSE"])
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.encodedBy: .remove]), to: url)
            let removed = try IndependentID3Probe.read(url)
            #expect(removed.frames["TENC"] == nil)
            #expect(removed.texts["TSSE"] == ["Original Settings"])
        }
    }

    @Test func id3EncoderSettingsEditMustSucceedAndPreserveEncodedBy() throws {
        try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: [
                .init(frameID: "TENC", type: "text", values: ["Original Encoded By"]),
                .init(frameID: "TSSE", type: "text", values: ["Original Settings"])
            ]), to: url)
            let before = try IndependentID3Probe.read(url)
            do {
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.encoderSettings: .text("New Settings")]), to: url)
            } catch {
                Issue.record("Encoder Settings edit failed: \(error)")
                return
            }
            let after = try IndependentID3Probe.read(url)
            #expect(after.texts["TSSE"] == ["New Settings"])
            #expect(after.frames["TENC"] == before.frames["TENC"])
            do {
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.encoderSettings: .remove]), to: url)
            } catch {
                Issue.record("Encoder Settings removal failed: \(error)")
                return
            }
            let removed = try IndependentID3Probe.read(url)
            #expect(removed.frames["TSSE"] == nil)
            #expect(removed.texts["TENC"] == ["Original Encoded By"])
        }
    }


    @Test func id3EncoderSettingsMustNotPopulateEncodedBy() throws {
        try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: [
                .init(frameID: "TSSE", type: "text", values: ["Encoder X"])
            ]), to: url)
            let basic = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(basic.encoderSettings == "Encoder X")
            #expect(basic.encodedBy.isEmpty, "Encoder Settings populated Encoded By: \(basic.encodedBy)")
            let before = try IndependentID3Probe.read(url)
            #expect(before.frames["TENC"] == nil)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
            let after = try IndependentID3Probe.read(url)
            #expect(after.frames["TENC"] == nil, "Unrelated Basic edit created a TENC frame")
            #expect(after.frames["TSSE"] == before.frames["TSSE"])
        }
    }

    @Test func id3EncodedByRemovalWithEncoderSettingsMustSucceed() throws {
        try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(id3v2Frames: [
                .init(frameID: "TENC", type: "text", values: ["Encoded By"]),
                .init(frameID: "TSSE", type: "text", values: ["Settings"])
            ]), to: url)
            let before = try IndependentID3Probe.read(url)
            do {
                try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.encodedBy: .remove]), to: url)
            } catch {
                Issue.record("Encoded By removal failed: \(error)")
                return
            }
            let after = try IndependentID3Probe.read(url)
            #expect(after.frames["TENC"] == nil)
            #expect(after.frames["TSSE"] == before.frames["TSSE"])
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).encodedBy.isEmpty)
        }
    }


    @Test func asfEncoderOwnersRemainIndependent() throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                .init(key: "WM/EncodedBy", type: "string", value: "Encoded By"),
                .init(key: "WM/EncodingSettings", type: "string", value: "Settings")
            ]), to: url)
            let basic = try TagLibMetadataManager.readMetadataResult(from: url)
            #expect(basic.encodedBy == "Encoded By", "encodedBy = \(basic.encodedBy.debugDescription)")
            #expect(basic.encoderSettings == "Settings", "encoderSettings = \(basic.encoderSettings.debugDescription)")
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.encoderSettings: .text("New Settings")]), to: url)
            let attributes = try IndependentASF.attributes(Data(contentsOf: url))
            #expect(attributes.contains { $0.name == "WM/EncodingSettings" && $0.value == IndependentASF.text("New Settings") },
                    "WM/EncodingSettings was not written natively")
            #expect(!attributes.contains { $0.name == "ENCODERSETTINGS" },
                    "A non-native ENCODERSETTINGS attribute was created")
            #expect(try TagLibMetadataManager.readMetadataResult(from: url).encoderSettings == "New Settings")
        }
    }


    @Test func explicitYearWritesOnlyTheYearSlot() throws {
        // MP4
        try withM4A { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "\u{00A9}day", type: "stringList", values: ["2004"]),
                .init(key: "----:com.apple.iTunes:DATE", type: "stringList", values: ["2003-02-01"])
            ]), to: url)
            let before = try IndependentMP4Probe.read(url)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.year: .text("2005")]), to: url)
            let after = try IndependentMP4Probe.read(url)
            try after.expectValue(.text("2005"), at: "\u{00A9}day")
            #expect(after.items["----:com.apple.iTunes:DATE"] == before.items["----:com.apple.iTunes:DATE"])
        }
        // ID3v2.4
        try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
            let audio = try IndependentID3Probe.read(url).audio
            let frames = HardeningFixture.frame("TDRC", Data([3]) + Data("2004".utf8))
                + HardeningFixture.frame("TXXX", Data([3]) + Data("DATE\02003-02-01".utf8))
            try (HardeningFixture.id3(frames) + audio).write(to: url)
            let before = try IndependentID3Probe.read(url)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.year: .text("2005")]), to: url)
            let after = try IndependentID3Probe.read(url)
            #expect(after.texts["TDRC"] == ["2005"])
            #expect(after.frames["TXXX:DATE"] == before.frames["TXXX:DATE"])
        }
    }


    @Test func basicContentGroupGroupingAndWorkStayIndependent() throws {
        try withM4A { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
                .init(key: "\u{00A9}grp", type: "stringList", values: ["Content Group"]),
                .init(key: "----:com.apple.iTunes:GROUPING", type: "stringList", values: ["Grouping"]),
                .init(key: "\u{00A9}wrk", type: "stringList", values: ["Work"])
            ]), to: url)
            let before = try IndependentMP4Probe.read(url)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.contentGroup = "New Content Group" }
            var after = try IndependentMP4Probe.read(url)
            try after.expectValue(.text("New Content Group"), at: "\u{00A9}grp")
            #expect(after.items["----:com.apple.iTunes:GROUPING"] == before.items["----:com.apple.iTunes:GROUPING"])
            #expect(after.items["\u{00A9}wrk"] == before.items["\u{00A9}wrk"])
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.grouping = "New Grouping" }
            after = try IndependentMP4Probe.read(url)
            try after.expectValue(.text("New Grouping"), at: "----:com.apple.iTunes:GROUPING")
            #expect(after.items["\u{00A9}grp"] != nil)
            #expect(after.items["\u{00A9}wrk"] != nil)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.work = "New Work" }
            after = try IndependentMP4Probe.read(url)
            try after.expectValue(.text("New Work"), at: "\u{00A9}wrk")
            #expect(after.items["\u{00A9}grp"] != nil)
            #expect(after.items["----:com.apple.iTunes:GROUPING"] != nil)
        }
    }


    @Test func asfUnrelatedBasicEditPreservesNativeEncodingSettings() throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                .init(key: "WM/EncodingSettings", type: "string", value: "Settings"),
                .init(key: "HARDEN_KEEP", type: "string", value: "Keep me")
            ]), to: url)
            let beforeBytes = try Data(contentsOf: url)
            let before = try IndependentASF.attributes(beforeBytes)
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.title = "Unrelated" }
            let afterBytes = try Data(contentsOf: url)
            let after = try IndependentASF.attributes(afterBytes)
            #expect(try IndependentASF.headerState(afterBytes).tail == IndependentASF.headerState(beforeBytes).tail,
                    "Audio packets changed")
            #expect(after.contains { $0.name == "WM/EncodingSettings" && $0.value == IndependentASF.text("Settings") },
                    "Unrelated Basic edit removed WM/EncodingSettings")
            #expect(!after.contains { $0.name == "WM/EncodedBy" },
                    "Encoder Settings was rewritten as Encoded By")
            #expect(after.contains { $0.name == "HARDEN_KEEP" && $0.value == IndependentASF.text("Keep me") },
                    "Unrelated Basic edit removed a custom ASF attribute")
            #expect(after == before)
        }
    }


    @Test func asfUnrelatedSemanticPatchPreservesNativeEncodingSettings() throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                .init(key: "WM/EncodingSettings", type: "string", value: "Settings")
            ]), to: url)
            let before = try IndependentASF.attributes(Data(contentsOf: url))
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("Unrelated")]), to: url)
            let after = try IndependentASF.attributes(Data(contentsOf: url))
            #expect(after == before, "Semantic title patch changed native ASF attributes")
        }
    }

    @Test func id3v23DateWritesRejectBeforeMutation() throws {
        try HardeningFixture.withCopy("mp3", name: "testAudioFile") { url in
            var data = try Data(contentsOf: url)
            #expect(data.count > 4 && data[0...2] == Data("ID3".utf8))
            data[3] = 3
            try data.write(to: url)
            #expect(try TagLibMetadataManager.readSnapshot(from: url).structured.id3v2MajorVersion == 3)
            for field in [MetadataFieldKey.year, .standaloneDate, .releaseDate, .originalReleaseDate] {
                let before = try Data(contentsOf: url)
                do {
                    try TagLibMetadataManager.applyMetadataPatch(.init(fields: [field: .text("2017-06-09")]), to: url)
                    Issue.record("ID3v2.3 date patch \(field.rawValue) unexpectedly succeeded")
                } catch is MetadataPatchValidationError {
                    // Expected read-only rejection.
                } catch {
                    Issue.record("Unexpected error for \(field.rawValue): \(error)")
                }
                #expect(try Data(contentsOf: url) == before, Comment(rawValue: field.rawValue))
            }
            var metadata = try TagLibMetadataManager.readMetadataResult(from: url)
            let before = try Data(contentsOf: url)
            metadata.year = "2017-06-09"
            do {
                try TagLibMetadataManager.replaceBasicMetadata(metadata, to: url)
                Issue.record("ID3v2.3 Basic year edit unexpectedly succeeded")
            } catch is MetadataPatchValidationError {
                // Expected read-only rejection.
            } catch {
                Issue.record("Unexpected Basic error: \(error)")
            }
            #expect(try Data(contentsOf: url) == before)
        }
    }
}
