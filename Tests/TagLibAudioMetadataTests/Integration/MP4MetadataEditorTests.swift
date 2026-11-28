import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
import CTagLibBridge
import TagLibAudioMetadata
import Testing

struct MP4MetadataEditorTests {
    @Test func editsProviderWrittenAtomsAndSeparateTextInOneTransaction() throws {
        try ContractFixture.withCopy("m4a") { url in
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [
                    .itunesAlbumID: .integer(6_829_122_413),
                    .itunesArtistID: .integer(479_756_766),
                    .itunesCatalogID: .integer(6_829_122_414),
                ], explicitAdvisory: .notExplicit),
                to: url
            )
            let legacy = "----:com.apple.iTunes:ITUNESALBUMID"
            try TagLibMetadataManager.applyRawMetadataPatch(
                RawMetadataPatch(valuesToSet: ["ITUNESALBUMID": ["42"], "EDITOR_NOTE": ["One", "Two"]]),
                to: url
            )
            let original = try ContractMP4Oracle.read(url)
            var evidence = ContractCase(
                scenario: "S-MP4-EDITOR-01",
                runtimeTest: "editsProviderWrittenAtomsAndSeparateTextInOneTransaction",
                adapter: "facade.applyMP4EditorPatch"
            )
            evidence.check("seed.album", try original.integer("plID") == 6_829_122_413)
            evidence.check("seed.catalog", try original.integer("cnID") == 6_829_122_414)
            evidence.check("seed.advisory", try original.integer("rtng") == 0)
            evidence.check("seed.albumAlias", try original.text(legacy) == "42")
            var snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            let rows = Dictionary(uniqueKeysWithValues: snapshot.editableMP4Fields.map { ($0.field, $0) })
            #expect(rows[.itunesAlbumID]?.atomKey == "plID")
            evidence.check("projection.album", rows[.itunesAlbumID]?.atom?.value == "6829122413")
            #expect(rows[.itunesArtistID]?.atom?.value == "479756766")
            #expect(rows[.itunesCatalogID]?.atom?.value == "6829122414")
            #expect(rows[.explicitContent]?.atom?.value == "0")
            #expect(snapshot.raw.properties.first { $0.key == "ITUNESALBUMID" }?.values == ["42"])
            #expect(!snapshot.raw.properties.contains { $0.key == "ITUNESCATALOGID" })

            let result = try PublicSurfaceAdapters.invoke(.facadeApplyMP4EditorPatch, url: url, input:
                .mp4EditorPatch([
                    .itunesAlbumID: .integer(6_829_122_415),
                    .itunesArtistID: .integer(Int(UInt32.max)),
                    .itunesCatalogID: .remove,
                ], RawMetadataPatch(valuesToSet: ["EDITOR_NOTE": ["New", "New"]]),
                    expectedVersion: try #require(snapshot.fileVersion)))
            if case .write = result { evidence.check("write.returned", true) }
            else { evidence.check("write.returned", false) }
            let edited = try ContractMP4Oracle.read(url)
            evidence.check("native.album", try edited.integer("plID") == 6_829_122_415)
            #expect(edited.values["plID"]?.first?.count == 8)
            #expect(try edited.integer("atID") == Int(UInt32.max))
            #expect(edited.values["atID"]?.first?.count == 4)
            evidence.check("native.catalog.absent", edited.items["cnID"] == nil)
            evidence.check("legacy.albumAlias.preserved", edited.items[legacy] == original.items[legacy])
            evidence.check("native.advisory.preserved", edited.items["rtng"] == original.items["rtng"])
            evidence.check("audio.unchanged", edited.audio == original.audio)
            #expect(edited.payloads("----:com.apple.iTunes:EDITOR_NOTE") == [Data("New".utf8), Data("New".utf8)])

            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            evidence.check("raw.note", snapshot.raw.properties.first { $0.key == "EDITOR_NOTE" }?.values == ["New", "New"])
            try evidence.finish()
            let catalog = try #require(snapshot.editableMP4Fields.first { $0.field == .itunesCatalogID })
            #expect(catalog.atomKey == "cnID")
            #expect(catalog.atom == nil)

            // Exercise rtng codes 1 and 2, Store ID boundary 0 and Int.max, and atID removal.
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [
                    .itunesAlbumID: .integer(0),
                    .itunesArtistID: .remove,
                    .itunesCatalogID: .integer(Int.max),
                    .explicitContent: .integer(1),
                ],
                to: url,
                expectedVersion: try #require(snapshot.fileVersion)
            )
            let boundaries = try ContractMP4Oracle.read(url)
            #expect(try boundaries.integer("plID") == 0)
            #expect(boundaries.items["atID"] == nil)
            #expect(try boundaries.integer("cnID") == Int.max)
            #expect(boundaries.values["cnID"]?.first?.count == 8)
            #expect(try boundaries.integer("rtng") == 1)
            #expect(boundaries.values["rtng"]?.first?.count == 1)

            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [.explicitContent: .integer(2)],
                to: url,
                expectedVersion: try #require(snapshot.fileVersion)
            )
            let cleanAdvisory = try ContractMP4Oracle.read(url)
            #expect(try cleanAdvisory.integer("rtng") == 2)
            #expect(cleanAdvisory.values["rtng"]?.first?.count == 1)

            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [.itunesAlbumID: .remove, .itunesCatalogID: .integer(6_829_122_414), .explicitContent: .remove],
                raw: RawMetadataPatch(removingKeys: ["EDITOR_NOTE"]),
                to: url,
                expectedVersion: try #require(snapshot.fileVersion)
            )
            let cleared = try ContractMP4Oracle.read(url)
            #expect(cleared.items["plID"] == nil)
            #expect(cleared.items["rtng"] == nil)
            #expect(try cleared.integer("cnID") == 6_829_122_414)
            #expect(cleared.values["cnID"]?.first?.count == 8)
            #expect(try cleared.text(legacy) == "42")
            #expect(cleared.items["----:com.apple.iTunes:EDITOR_NOTE"] == nil)
            #expect(cleared.items["----:com.apple.iTunes:ITUNESCATALOGID"] == nil)
        }
    }

    @Test func discoversAndEditsAllWritableNonPropertyMapMP4Fields() throws {
        let expectedFields: [(field: MetadataFieldKey, atomKey: String)] = [
            (.itunesAlbumID, "plID"),
            (.itunesArtistID, "atID"),
            (.itunesCatalogID, "cnID"),
            (.itunesGenreID, "geID"),
            (.itunesMediaType, "stik"),
            (.itunesPurchaseDate, "purd"),
            (.itunesAccount, "apID"),
            (.itunesComposerID, "cmID"),
            (.itunesCountryID, "sfID"),
            (.itunesHDVideo, "hdvd"),
            (.storeDescription, "sdes"),
            (.explicitContent, "rtng"),
            (.director, "©dir"),
            (.publisher, "©pub"),
            (.conductor, "©con"),
        ]
        try ContractFixture.withCopy("m4a") { url in
            let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01, 0x02, 0x03, 0x04])
            let customFreeform = "----:com.example.custom:TRACKER"
            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(
                    fields: [
                        .itunesAlbumID: .integer(6_829_122_413),
                        .itunesArtistID: .integer(479_756_766),
                        .itunesCatalogID: .integer(6_829_122_414),
                        .itunesGenreID: .integer(14),
                        .itunesMediaType: .integer(1),
                        .itunesPurchaseDate: .text("2025-01-02 03:04:05"),
                        .itunesAccount: .text("buyer@example.com"),
                        .itunesComposerID: .integer(98_765),
                        .itunesCountryID: .integer(143_441),
                        .itunesHDVideo: .boolean(false),
                        .storeDescription: .text("Initial store note"),
                        .director: .values(["Director One", "Director Two"]),
                        .publisher: .text("Initial Label"),
                        .conductor: .values(["Conductor One", "Conductor Two"]),
                    ],
                    explicitAdvisory: .notExplicit,
                    artwork: .replace([StructuredArtwork(mimeType: "image/png", data: png)])
                ),
                to: url
            )
            // Seed read-only `rate` and a non-iTunes freeform that must survive editor saves untouched.
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(mp4Atoms: [
                    StructuredMP4Atom(key: "rate", type: "stringList", values: ["80"]),
                    StructuredMP4Atom(key: customFreeform, type: "stringList", values: ["keep-me"]),
                ]),
                to: url
            )
            let seededOracle = try ContractMP4Oracle.read(url)
            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)

            // Every writable non-PropertyMap native MP4 field is surfaced; read-only `rate` is excluded.
            let rows = snapshot.editableMP4Fields
            #expect(rows.map(\.field) == expectedFields.map(\.field))
            #expect(rows.map(\.atomKey) == expectedFields.map(\.atomKey))
            #expect(!rows.contains { $0.field == .rate })

            let byField = Dictionary(uniqueKeysWithValues: rows.map { ($0.field, $0) })
            #expect(byField[.itunesGenreID]?.atom?.value == "14")
            #expect(byField[.itunesMediaType]?.atom?.value == "1")
            #expect(byField[.itunesPurchaseDate]?.atom?.values == ["2025-01-02 03:04:05"])
            #expect(byField[.itunesAccount]?.atom?.values == ["buyer@example.com"])
            #expect(byField[.itunesComposerID]?.atom?.value == "98765")
            #expect(byField[.itunesCountryID]?.atom?.value == "143441")
            #expect(byField[.itunesHDVideo]?.atom?.value == "0")
            #expect(byField[.storeDescription]?.atom?.values == ["Initial store note"])
            #expect(byField[.director]?.atom?.values == ["Director One", "Director Two"])
            #expect(byField[.publisher]?.atom?.values == ["Initial Label"])
            #expect(byField[.conductor]?.atom?.values == ["Conductor One", "Conductor Two"])

            // None of these 15 fields are projected into raw.properties.
            let rawKeys = Set(snapshot.raw.properties.map { $0.key.uppercased() })
            for key in [
                "ITUNESALBUMID", "ITUNESARTISTID", "ITUNESCATALOGID", "ITUNESGENREID",
                "ITUNESMEDIATYPE", "ITUNESPURCHASEDATE", "ITUNESACCOUNT", "ITUNESCOMPOSERID",
                "ITUNESCOUNTRYID", "ITUNESHDVIDEO", "STOREDESCRIPTION", "ITUNESADVISORY",
                "DIRECTOR", "LABEL", "PUBLISHER", "CONDUCTOR",
            ] {
                #expect(!rawKeys.contains(key), "Expected \(key) to be absent from raw.properties")
            }

            // Edit every newly supported field + raw delta in a single transaction.
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [
                    .itunesGenreID: .integer(Int(UInt32.max)),
                    .itunesMediaType: .integer(255),
                    .itunesPurchaseDate: .text("  2026-06-07 08:09:10  "),
                    .itunesAccount: .text("edited@example.com"),
                    .itunesComposerID: .integer(0),
                    .itunesCountryID: .integer(143_462),
                    .itunesHDVideo: .boolean(true),
                    .storeDescription: .text("Updated store description"),
                    .director: .values(["Alice; One", "Bob Two"]),
                    .publisher: .text("Updated Label"),
                    .conductor: .text("Solo Conductor"),
                ],
                raw: RawMetadataPatch(valuesToSet: ["TITLE": ["Editor Title"]]),
                to: url,
                expectedVersion: try #require(snapshot.fileVersion)
            )
            let editedOracle = try ContractMP4Oracle.read(url)
            #expect(try editedOracle.integer("geID") == Int(UInt32.max))
            #expect(editedOracle.values["geID"]?.first?.count == 4)
            #expect(try editedOracle.integer("stik") == 255)
            #expect(editedOracle.values["stik"]?.first?.count == 1)
            #expect(try editedOracle.text("purd") == "2026-06-07 08:09:10")
            #expect(try editedOracle.text("apID") == "edited@example.com")
            #expect(try editedOracle.integer("cmID") == 0)
            #expect(editedOracle.values["cmID"]?.first?.count == 4)
            #expect(try editedOracle.integer("sfID") == 143_462)
            #expect(try editedOracle.integer("hdvd") == 1)
            #expect(try editedOracle.text("sdes") == "Updated store description")
            #expect(editedOracle.payloads("©dir") == [Data("Alice; One".utf8), Data("Bob Two".utf8)])
            #expect(try editedOracle.text("©pub") == "Updated Label")
            #expect(editedOracle.payloads("©con") == [Data("Solo Conductor".utf8)])
            #expect(try editedOracle.text("©nam") == "Editor Title")

            // Untouched native atoms, artwork, non-iTunes freeform, rate, and audio remain intact.
            #expect(editedOracle.items["plID"] == seededOracle.items["plID"])
            #expect(editedOracle.items["atID"] == seededOracle.items["atID"])
            #expect(editedOracle.items["cnID"] == seededOracle.items["cnID"])
            #expect(editedOracle.items["rtng"] == seededOracle.items["rtng"])
            #expect(editedOracle.items["covr"] == seededOracle.items["covr"])
            #expect(editedOracle.items["rate"] == seededOracle.items["rate"])
            #expect(editedOracle.items[customFreeform] == seededOracle.items[customFreeform])
            #expect(editedOracle.audio == seededOracle.audio)

            // Zero duplicate iTunes freeforms were synthesized for any edited native atom.
            let freeformKeys = editedOracle.items.keys.filter { $0.lowercased().hasPrefix("----:com.apple.itunes:") }
            #expect(freeformKeys.isEmpty)

            // Remove all 15 editable fields in one native-only transaction.
            let afterEditSnapshot = try TagLibMetadataManager.readSnapshot(from: url)
            let removeAll = Dictionary(uniqueKeysWithValues: expectedFields.map { ($0.field, MetadataPatchValue.remove) })
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                removeAll,
                to: url,
                expectedVersion: try #require(afterEditSnapshot.fileVersion)
            )
            let clearedOracle = try ContractMP4Oracle.read(url)
            for (_, atomKey) in expectedFields {
                #expect(clearedOracle.items[atomKey] == nil, "Expected \(atomKey) to be removed")
            }
            #expect(clearedOracle.items["covr"] == seededOracle.items["covr"])
            #expect(clearedOracle.items["rate"] == seededOracle.items["rate"])
            #expect(clearedOracle.items[customFreeform] == seededOracle.items[customFreeform])
            #expect(try clearedOracle.text("©nam") == "Editor Title")
            #expect(clearedOracle.audio == seededOracle.audio)
        }
    }

    @Test func rawGroupingAndDatePreserveSingleOwnerWithoutDuplication() throws {
        let cases: [(rawKey: String, nativeAtom: String, freeformKey: String, initialNative: String, initialFreeform: String, updated: String)] = [
            ("GROUPING", "©grp", "----:com.apple.iTunes:GROUPING", "Native Group", "Freeform Group", "Edited Group"),
            ("DATE", "©day", "----:com.apple.iTunes:DATE", "2020", "2021-02-03", "2025-04-05"),
        ]
        for entry in cases {
            // 1. Only native atom present: raw edit updates native atom only; raw remove removes native atom only.
            for useEditor in [false, true] {
                try ContractFixture.withCopy("m4a") { url in
                    try ContractMP4Seed.seed([.init(key: entry.nativeAtom, value: .text(entry.initialNative))], to: url)
                    let before = try ContractMP4Oracle.read(url)
                    let version = try TagLibMetadataManager.fileVersion(at: url)
                    let setPatch = RawMetadataPatch(valuesToSet: [entry.rawKey: [entry.updated]])
                    if useEditor {
                        try TagLibMetadataManager.applyMP4MetadataEditorPatch([:], raw: setPatch, to: url, expectedVersion: version)
                    } else {
                        try TagLibMetadataManager.applyRawMetadataPatch(setPatch, to: url, expectedVersion: version)
                    }
                    let edited = try ContractMP4Oracle.read(url)
                    #expect(try edited.text(entry.nativeAtom) == entry.updated)
                    #expect(edited.items[entry.freeformKey] == nil)
                    #expect(edited.audio == before.audio)

                    let removeVersion = try TagLibMetadataManager.fileVersion(at: url)
                    let removePatch = RawMetadataPatch(removingKeys: [entry.rawKey])
                    if useEditor {
                        try TagLibMetadataManager.applyMP4MetadataEditorPatch([:], raw: removePatch, to: url, expectedVersion: removeVersion)
                    } else {
                        try TagLibMetadataManager.applyRawMetadataPatch(removePatch, to: url, expectedVersion: removeVersion)
                    }
                    let removed = try ContractMP4Oracle.read(url, allowingAbsentMetadata: true)
                    #expect(removed.items[entry.nativeAtom] == nil)
                    #expect(removed.items[entry.freeformKey] == nil)
                    #expect(removed.audio == before.audio)
                }
            }

            // 2. Neither present: raw set creates only native atom, never a second freeform copy.
            try ContractFixture.withCopy("m4a") { url in
                try ContractMP4Seed.seed([.init(key: "©nam", value: .text("Baseline"))], to: url)
                let version = try TagLibMetadataManager.fileVersion(at: url)
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [:],
                    raw: RawMetadataPatch(valuesToSet: [entry.rawKey: [entry.updated]]),
                    to: url,
                    expectedVersion: version
                )
                let created = try ContractMP4Oracle.read(url)
                #expect(try created.text(entry.nativeAtom) == entry.updated)
                #expect(created.items[entry.freeformKey] == nil)
            }

            // 3. Only freeform present: unrelated raw edit, targeted raw edit, and raw remove never synthesize native atom.
            for useEditor in [false, true] {
                try ContractFixture.withCopy("m4a") { url in
                    try ContractMP4Seed.seed([
                        .init(key: "©nam", value: .text("Baseline")),
                        .init(key: entry.freeformKey, value: .text(entry.initialFreeform)),
                    ], to: url)
                    let before = try ContractMP4Oracle.read(url)

                    // Unrelated raw edit must not synthesize native atom from projected freeform.
                    let unrelatedVersion = try TagLibMetadataManager.fileVersion(at: url)
                    let unrelatedPatch = RawMetadataPatch(valuesToSet: ["TITLE": ["Other Title"]])
                    if useEditor {
                        try TagLibMetadataManager.applyMP4MetadataEditorPatch([:], raw: unrelatedPatch, to: url, expectedVersion: unrelatedVersion)
                    } else {
                        try TagLibMetadataManager.applyRawMetadataPatch(unrelatedPatch, to: url, expectedVersion: unrelatedVersion)
                    }
                    let afterUnrelated = try ContractMP4Oracle.read(url)
                    #expect(afterUnrelated.items[entry.nativeAtom] == nil)
                    #expect(try afterUnrelated.text(entry.freeformKey) == entry.initialFreeform)
                    #expect(afterUnrelated.audio == before.audio)

                    // Targeted edit updates only the existing freeform without creating the native atom.
                    let editVersion = try TagLibMetadataManager.fileVersion(at: url)
                    let setPatch = RawMetadataPatch(valuesToSet: [entry.rawKey: [entry.updated]])
                    if useEditor {
                        try TagLibMetadataManager.applyMP4MetadataEditorPatch([:], raw: setPatch, to: url, expectedVersion: editVersion)
                    } else {
                        try TagLibMetadataManager.applyRawMetadataPatch(setPatch, to: url, expectedVersion: editVersion)
                    }
                    let edited = try ContractMP4Oracle.read(url)
                    #expect(edited.items[entry.nativeAtom] == nil)
                    #expect(try edited.text(entry.freeformKey) == entry.updated)
                    #expect(edited.audio == before.audio)

                    // Targeted removal removes only the existing freeform.
                    let removeVersion = try TagLibMetadataManager.fileVersion(at: url)
                    let removePatch = RawMetadataPatch(removingKeys: [entry.rawKey])
                    if useEditor {
                        try TagLibMetadataManager.applyMP4MetadataEditorPatch([:], raw: removePatch, to: url, expectedVersion: removeVersion)
                    } else {
                        try TagLibMetadataManager.applyRawMetadataPatch(removePatch, to: url, expectedVersion: removeVersion)
                    }
                    let removed = try ContractMP4Oracle.read(url)
                    #expect(removed.items[entry.nativeAtom] == nil)
                    #expect(removed.items[entry.freeformKey] == nil)
                    #expect(removed.audio == before.audio)
                }
            }

            // 4. Both native atom and shadowed freeform present:
            //    raw edit updates native atom and preserves shadowed freeform;
            //    raw remove fails closed without deleting the shadowed freeform.
            for useEditor in [false, true] {
                try ContractFixture.withCopy("m4a") { url in
                    try ContractMP4Seed.seed([
                        .init(key: entry.nativeAtom, value: .text(entry.initialNative)),
                        .init(key: entry.freeformKey, value: .text(entry.initialFreeform)),
                    ], to: url)
                    let before = try ContractMP4Oracle.read(url)
                    let editVersion = try TagLibMetadataManager.fileVersion(at: url)
                    let setPatch = RawMetadataPatch(valuesToSet: [entry.rawKey: [entry.updated]])
                    if useEditor {
                        try TagLibMetadataManager.applyMP4MetadataEditorPatch([:], raw: setPatch, to: url, expectedVersion: editVersion)
                    } else {
                        try TagLibMetadataManager.applyRawMetadataPatch(setPatch, to: url, expectedVersion: editVersion)
                    }
                    let edited = try ContractMP4Oracle.read(url)
                    #expect(try edited.text(entry.nativeAtom) == entry.updated)
                    #expect(try edited.text(entry.freeformKey) == entry.initialFreeform)
                    #expect(edited.audio == before.audio)

                    let bytesBeforeRemove = try ContractFixture.bytes(url)
                    let removeVersion = try TagLibMetadataManager.fileVersion(at: url)
                    let removePatch = RawMetadataPatch(removingKeys: [entry.rawKey])
                    do {
                        if useEditor {
                            try TagLibMetadataManager.applyMP4MetadataEditorPatch([:], raw: removePatch, to: url, expectedVersion: removeVersion)
                        } else {
                            try TagLibMetadataManager.applyRawMetadataPatch(removePatch, to: url, expectedVersion: removeVersion)
                        }
                        Issue.record("Removing \(entry.rawKey) when a shadowed freeform exists must fail closed.")
                    } catch TagLibManagerError.verificationFailed(let mismatches) {
                        #expect(mismatches.contains { $0.contains(entry.rawKey) })
                    }
                    #expect(try ContractFixture.bytes(url) == bytesBeforeRemove)
                }
            }
        }
    }

    @Test func rawEditsAndDeletesPreserveShadowedFreeformsAcrossNativeMP4Atoms() throws {
        struct AtomCase {
            let rawKey: String
            let nativeAtom: String
            let seedNative: ContractMP4Item.Value
            let updated: String
            let verifyNative: (ContractMP4Oracle) throws -> Bool
            let allowFreeformOnly: Bool
        }
        let cases: [AtomCase] = [
            .init(rawKey: "TITLE", nativeAtom: "©nam", seedNative: .text("Native Title"), updated: "Edited Title",
                  verifyNative: { try $0.text("©nam") == "Edited Title" }, allowFreeformOnly: true),
            .init(rawKey: "OWNER", nativeAtom: "ownr", seedNative: .text("Native Owner"), updated: "Edited Owner",
                  verifyNative: { try $0.text("ownr") == "Edited Owner" }, allowFreeformOnly: true),
            .init(rawKey: "ALBUM", nativeAtom: "©alb", seedNative: .text("Native Album"), updated: "Edited Album",
                  verifyNative: { try $0.text("©alb") == "Edited Album" }, allowFreeformOnly: true),
            .init(rawKey: "ARTIST", nativeAtom: "©ART", seedNative: .text("Native Artist"), updated: "Edited Artist",
                  verifyNative: { try $0.text("©ART") == "Edited Artist" }, allowFreeformOnly: true),
            .init(rawKey: "ALBUMARTIST", nativeAtom: "aART", seedNative: .text("Native AA"), updated: "Edited AA",
                  verifyNative: { try $0.text("aART") == "Edited AA" }, allowFreeformOnly: true),
            .init(rawKey: "COMMENT", nativeAtom: "©cmt", seedNative: .text("Native Comment"), updated: "Edited Comment",
                  verifyNative: { try $0.text("©cmt") == "Edited Comment" }, allowFreeformOnly: true),
            .init(rawKey: "GENRE", nativeAtom: "©gen", seedNative: .text("Jazz"), updated: "Rock",
                  verifyNative: { try $0.text("©gen") == "Rock" }, allowFreeformOnly: true),
            .init(rawKey: "COMPOSER", nativeAtom: "©wrt", seedNative: .text("Bach"), updated: "Mozart",
                  verifyNative: { try $0.text("©wrt") == "Mozart" }, allowFreeformOnly: true),
            .init(rawKey: "ENCODEDBY", nativeAtom: "©enc", seedNative: .text("Enc1"), updated: "Enc2",
                  verifyNative: { try $0.text("©enc") == "Enc2" }, allowFreeformOnly: true),
            .init(rawKey: "ENCODING", nativeAtom: "©too", seedNative: .text("Tool1"), updated: "Tool2",
                  verifyNative: { try $0.text("©too") == "Tool2" }, allowFreeformOnly: true),
            .init(rawKey: "WORK", nativeAtom: "©wrk", seedNative: .text("Work1"), updated: "Work2",
                  verifyNative: { try $0.text("©wrk") == "Work2" }, allowFreeformOnly: true),
            .init(rawKey: "MOVEMENTNAME", nativeAtom: "©mvn", seedNative: .text("Allegro"), updated: "Adagio",
                  verifyNative: { try $0.text("©mvn") == "Adagio" }, allowFreeformOnly: true),
            .init(rawKey: "COPYRIGHT", nativeAtom: "cprt", seedNative: .text("2020"), updated: "2025",
                  verifyNative: { try $0.text("cprt") == "2025" }, allowFreeformOnly: true),
            .init(rawKey: "TITLESORT", nativeAtom: "sonm", seedNative: .text("Sort1"), updated: "Sort2",
                  verifyNative: { try $0.text("sonm") == "Sort2" }, allowFreeformOnly: true),
            .init(rawKey: "SHOWSORT", nativeAtom: "sosn", seedNative: .text("ShowSort1"), updated: "ShowSort2",
                  verifyNative: { try $0.text("sosn") == "ShowSort2" }, allowFreeformOnly: true),
            .init(rawKey: "TVSHOW", nativeAtom: "tvsh", seedNative: .text("Show1"), updated: "Show2",
                  verifyNative: { try $0.text("tvsh") == "Show2" }, allowFreeformOnly: true),
            .init(rawKey: "GAPLESSPLAYBACK", nativeAtom: "pgap", seedNative: .integer(0, byteCount: 1), updated: "1",
                  verifyNative: { try $0.integer("pgap") == 1 }, allowFreeformOnly: false),
            .init(rawKey: "SHOWWORKMOVEMENT", nativeAtom: "shwm", seedNative: .integer(0, byteCount: 1), updated: "1",
                  verifyNative: { try $0.integer("shwm") == 1 }, allowFreeformOnly: false),
            .init(rawKey: "COMPILATION", nativeAtom: "cpil", seedNative: .integer(0, byteCount: 1), updated: "1",
                  verifyNative: { try $0.integer("cpil") == 1 }, allowFreeformOnly: false),
            .init(rawKey: "BPM", nativeAtom: "tmpo", seedNative: .integer(100, byteCount: 2), updated: "128",
                  verifyNative: { try $0.integer("tmpo") == 128 }, allowFreeformOnly: false),
            .init(rawKey: "TRACKNUMBER", nativeAtom: "trkn", seedNative: .intPair(first: 1, second: 10), updated: "2/10",
                  verifyNative: { try $0.intPair("trkn") == (2, 10) }, allowFreeformOnly: false),
        ]

        for entry in cases {
            let freeformKey = "----:com.apple.iTunes:\(entry.rawKey)"
            let shadowedValue = "Shadowed-\(entry.rawKey)"

            // Coexistence: raw edit updates ONLY the native atom and preserves the shadowed freeform;
            // raw delete FAILS CLOSED and leaves the file byte-for-byte unchanged.
            for useEditor in [true, false] {
                try ContractFixture.withCopy("m4a") { url in
                    try ContractMP4Seed.seed([
                        .init(key: entry.nativeAtom, value: entry.seedNative),
                        .init(key: freeformKey, value: .text(shadowedValue)),
                    ], to: url)
                    let before = try ContractMP4Oracle.read(url)
                    let version = try TagLibMetadataManager.fileVersion(at: url)
                    let editPatch = RawMetadataPatch(valuesToSet: [entry.rawKey: [entry.updated]])
                    if useEditor {
                        try TagLibMetadataManager.applyMP4MetadataEditorPatch([:], raw: editPatch, to: url, expectedVersion: version)
                    } else {
                        try TagLibMetadataManager.applyRawMetadataPatch(editPatch, to: url, expectedVersion: version)
                    }
                    let edited = try ContractMP4Oracle.read(url)
                    #expect(try entry.verifyNative(edited), "Expected native \(entry.nativeAtom) to update for \(entry.rawKey)")
                    #expect(try edited.text(freeformKey) == shadowedValue, "Shadowed \(freeformKey) must remain unchanged on edit")
                    #expect(edited.audio == before.audio)

                    let bytesBeforeDelete = try ContractFixture.bytes(url)
                    let deleteVersion = try TagLibMetadataManager.fileVersion(at: url)
                    let deletePatch = RawMetadataPatch(removingKeys: [entry.rawKey])
                    do {
                        if useEditor {
                            try TagLibMetadataManager.applyMP4MetadataEditorPatch([:], raw: deletePatch, to: url, expectedVersion: deleteVersion)
                        } else {
                            try TagLibMetadataManager.applyRawMetadataPatch(deletePatch, to: url, expectedVersion: deleteVersion)
                        }
                        Issue.record("Deleting \(entry.rawKey) while shadowed \(freeformKey) coexists must fail closed.")
                    } catch TagLibManagerError.verificationFailed(let mismatches) {
                        #expect(mismatches.contains { $0.contains(entry.rawKey) })
                    }
                    #expect(try ContractFixture.bytes(url) == bytesBeforeDelete)
                }
            }

            // Freeform-only (native atom absent): unrelated edit, targeted edit, and delete never synthesize native atom.
            if entry.allowFreeformOnly {
                try ContractFixture.withCopy("m4a") { url in
                    try ContractMP4Seed.seed([
                        .init(key: "----:com.apple.iTunes:ANCHOR", value: .text("anchor")),
                        .init(key: freeformKey, value: .text(shadowedValue)),
                    ], to: url)
                    let before = try ContractMP4Oracle.read(url)

                    let v1 = try TagLibMetadataManager.fileVersion(at: url)
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [:],
                        raw: RawMetadataPatch(valuesToSet: ["ANCHOR": ["changed"]]),
                        to: url,
                        expectedVersion: v1
                    )
                    let afterUnrelated = try ContractMP4Oracle.read(url)
                    #expect(afterUnrelated.items[entry.nativeAtom] == nil)
                    #expect(try afterUnrelated.text(freeformKey) == shadowedValue)

                    let v2 = try TagLibMetadataManager.fileVersion(at: url)
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [:],
                        raw: RawMetadataPatch(valuesToSet: [entry.rawKey: [entry.updated]]),
                        to: url,
                        expectedVersion: v2
                    )
                    let afterEdit = try ContractMP4Oracle.read(url)
                    #expect(afterEdit.items[entry.nativeAtom] == nil)
                    #expect(try afterEdit.text(freeformKey) == entry.updated)

                    let v3 = try TagLibMetadataManager.fileVersion(at: url)
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [:],
                        raw: RawMetadataPatch(removingKeys: [entry.rawKey]),
                        to: url,
                        expectedVersion: v3
                    )
                    let afterRemove = try ContractMP4Oracle.read(url)
                    #expect(afterRemove.items[entry.nativeAtom] == nil)
                    #expect(afterRemove.items[freeformKey] == nil)
                    #expect(afterRemove.audio == before.audio)
                }
            }
        }
    }

    @Test func rawNonCanonicalMP4AliasesRejectWithoutCreatingDuplicateFreeforms() throws {
        let aliasCases: [(alias: String, canonical: String, nativeAtom: String, value: String)] = [
            ("ITUNESGAPLESS", "GAPLESSPLAYBACK", "pgap", "1"),
            ("SHOWMOVEMENT", "SHOWWORKMOVEMENT", "shwm", "1"),
            ("ITUNESOWNER", "OWNER", "ownr", "Alice"),
            ("TVSHOWSORT", "SHOWSORT", "sosn", "Show Sort"),
            ("MOVEMENT", "MOVEMENTNAME", "©mvn", "Allegro"),
            ("ENCODERSETTINGS", "ENCODING", "©too", "AAC 256"),
            ("ALBUM ARTIST", "ALBUMARTIST", "aART", "Various"),
            ("CONTENTGROUP", "GROUPING", "©grp", "Baroque"),
            ("YEAR", "DATE", "©day", "2026"),
            ("TRACK", "TRACKNUMBER", "trkn", "3"),
            ("TRACKTOTAL", "TRACKNUMBER", "trkn", "12"),
            ("TOTALTRACKS", "TRACKNUMBER", "trkn", "12"),
            ("DISC", "DISCNUMBER", "disk", "2"),
            ("DISCTOTAL", "DISCNUMBER", "disk", "3"),
            ("TOTALDISCS", "DISCNUMBER", "disk", "3"),
        ]

        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seed([
                .init(key: "pgap", value: .integer(0, byteCount: 1)),
                .init(key: "shwm", value: .integer(0, byteCount: 1)),
                .init(key: "ownr", value: .text("Original Owner")),
                .init(key: "sosn", value: .text("Original Sort")),
                .init(key: "©mvn", value: .text("Original Movement")),
                .init(key: "©too", value: .text("Original Tool")),
                .init(key: "aART", value: .text("Original AA")),
                .init(key: "©grp", value: .text("Original Group")),
                .init(key: "©day", value: .text("2020")),
                .init(key: "trkn", value: .intPair(first: 1, second: 10)),
                .init(key: "disk", value: .intPair(first: 1, second: 2)),
            ], to: url)
            let beforeBytes = try ContractFixture.bytes(url)
            let version = try TagLibMetadataManager.fileVersion(at: url)

            // Every non-canonical alias must reject on set and remove across all raw write entrypoints,
            // leaving the file byte-for-byte unchanged and creating zero duplicate freeforms.
            for entry in aliasCases {
                do {
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [:],
                        raw: RawMetadataPatch(valuesToSet: [entry.alias: [entry.value]]),
                        to: url,
                        expectedVersion: version
                    )
                    Issue.record("Raw editor set of non-canonical MP4 alias \(entry.alias) must reject.")
                } catch TagLibManagerError.unsupportedWritePolicy(let message) {
                    #expect(message.contains(entry.canonical))
                }
                #expect(try ContractFixture.bytes(url) == beforeBytes)

                do {
                    try TagLibMetadataManager.applyRawMetadataPatch(
                        RawMetadataPatch(valuesToSet: [entry.alias: [entry.value]]),
                        to: url,
                        expectedVersion: version
                    )
                    Issue.record("Raw patch set of non-canonical MP4 alias \(entry.alias) must reject.")
                } catch TagLibManagerError.unsupportedWritePolicy(let message) {
                    #expect(message.contains(entry.canonical))
                }
                #expect(try ContractFixture.bytes(url) == beforeBytes)

                do {
                    try TagLibMetadataManager.applyRawMetadataPatch(
                        RawMetadataPatch(removingKeys: [entry.alias]),
                        to: url,
                        expectedVersion: version
                    )
                    Issue.record("Raw patch remove of absent non-canonical MP4 alias \(entry.alias) must reject.")
                } catch TagLibManagerError.unsupportedWritePolicy {}
                #expect(try ContractFixture.bytes(url) == beforeBytes)
            }

            // Whole-map replace must also reject creating non-canonical alias freeforms.
            do {
                try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                    ["ITUNESGAPLESS": "1", "SHOWMOVEMENT": "1"],
                    to: url,
                    mode: .replace,
                    expectedVersion: version
                )
                Issue.record("Whole-map replace with ITUNESGAPLESS/SHOWMOVEMENT must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                    ["ITUNESGAPLESS": ["1"], "SHOWMOVEMENT": ["1"]],
                    to: url,
                    mode: .replace,
                    expectedVersion: version
                )
                Issue.record("Whole-map multi-value replace with ITUNESGAPLESS/SHOWMOVEMENT must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            // Using the canonical PropertyMap keys updates pgap and shwm in place with zero freeforms.
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [:],
                raw: RawMetadataPatch(valuesToSet: [
                    "GAPLESSPLAYBACK": ["1"],
                    "SHOWWORKMOVEMENT": ["1"],
                ]),
                to: url,
                expectedVersion: version
            )
            let updated = try ContractMP4Oracle.read(url)
            #expect(try updated.integer("pgap") == 1)
            #expect(try updated.integer("shwm") == 1)
            #expect(updated.items["----:com.apple.iTunes:ITUNESGAPLESS"] == nil)
            #expect(updated.items["----:com.apple.iTunes:SHOWMOVEMENT"] == nil)
            #expect(updated.items["----:com.apple.iTunes:GAPLESSPLAYBACK"] == nil)
            #expect(updated.items["----:com.apple.iTunes:SHOWWORKMOVEMENT"] == nil)
        }

        // Pre-existing legacy alias freeforms can still be explicitly removed without touching the native atom.
        try ContractFixture.withCopy("m4a") { url in
            let legacyKey = "----:com.apple.iTunes:ITUNESGAPLESS"
            try ContractMP4Seed.seed([
                .init(key: "pgap", value: .integer(0, byteCount: 1)),
                .init(key: legacyKey, value: .text("1")),
            ], to: url)
            let version = try TagLibMetadataManager.fileVersion(at: url)
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [:],
                raw: RawMetadataPatch(removingKeys: ["ITUNESGAPLESS"]),
                to: url,
                expectedVersion: version
            )
            let afterCleanup = try ContractMP4Oracle.read(url)
            #expect(try afterCleanup.integer("pgap") == 0)
            #expect(afterCleanup.items[legacyKey] == nil)
        }
    }

    @Test func untouchedMP4FreeformsPreserveExactLocaleAndDataBytes() throws {
        func be32(_ value: UInt32) -> Data {
            Data([
                UInt8((value >> 24) & 0xFF),
                UInt8((value >> 16) & 0xFF),
                UInt8((value >> 8) & 0xFF),
                UInt8(value & 0xFF),
            ])
        }
        func makeAtom(_ fourCC: String, _ payload: Data) -> Data {
            let typeBytes = fourCC.data(using: .isoLatin1)!
            return be32(UInt32(payload.count + 8)) + typeBytes + payload
        }
        func makeDataAtom(type: UInt32, locale: UInt32, payload: Data) -> Data {
            makeAtom("data", be32(type) + be32(locale) + payload)
        }
        func makeFreeform(mean: String, name: String, dataAtoms: Data) -> Data {
            let body = makeAtom("mean", be32(0) + Data(mean.utf8))
                + makeAtom("name", be32(0) + Data(name.utf8))
                + dataAtoms
            return makeAtom("----", body)
        }
        func readDataHeaders(for key: String, from oracle: ContractMP4Oracle) throws -> [(type: UInt32, locale: UInt32, payload: Data)] {
            guard let rawAtoms = oracle.items[key], !rawAtoms.isEmpty else { return [] }
            var results: [(UInt32, UInt32, Data)] = []
            for rawAtom in rawAtoms {
                let outer = try ContractMP4Oracle.atoms(rawAtom, 0..<rawAtom.count)
                guard outer.count == 1 else { continue }
                let children = try ContractMP4Oracle.atoms(rawAtom, outer[0].payload)
                for child in children where child.type == "data" {
                    let bytes = Data(rawAtom[child.payload])
                    guard bytes.count >= 8 else { continue }
                    let typeFlags = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
                    let locale = (UInt32(bytes[4]) << 24) | (UInt32(bytes[5]) << 16) | (UInt32(bytes[6]) << 8) | UInt32(bytes[7])
                    results.append((typeFlags, locale, Data(bytes.dropFirst(8))))
                }
            }
            return results
        }

        let canadianFrench: UInt32 = 0x4341_1A41
        let titleFreeformKey = "----:com.apple.iTunes:TITLE"
        let baseILST =
            makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Native Title".utf8)))
            + makeFreeform(
                mean: "com.apple.iTunes",
                name: "TITLE",
                dataAtoms: makeDataAtom(type: 1, locale: canadianFrench, payload: Data("Titre Canadien".utf8))
            )

        // 1. Editing TITLE via applyRawMetadataPatch must preserve the untouched freeform's locale 0x43411A41.
        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seedRawILST(baseILST, to: url)
            let before = try ContractMP4Oracle.read(url)
            let beforeHeaders = try readDataHeaders(for: titleFreeformKey, from: before)
            try #require(beforeHeaders.count == 1)
            #expect(beforeHeaders[0].locale == canadianFrench)

            try TagLibMetadataManager.applyRawMetadataPatch(
                RawMetadataPatch(valuesToSet: ["TITLE": ["Updated Native Title"]]),
                to: url
            )
            let after = try ContractMP4Oracle.read(url)
            #expect(try after.text("©nam") == "Updated Native Title")
            #expect(after.items[titleFreeformKey] == before.items[titleFreeformKey])
            let afterHeaders = try readDataHeaders(for: titleFreeformKey, from: after)
            try #require(afterHeaders.count == 1)
            #expect(afterHeaders[0].type == 1)
            #expect(afterHeaders[0].locale == canadianFrench)
            #expect(afterHeaders[0].payload == Data("Titre Canadien".utf8))
            #expect(after.audio == before.audio)
        }

        // 2. Editing TITLE via applyMP4MetadataEditorPatch must preserve the untouched freeform's locale 0x43411A41.
        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seedRawILST(baseILST, to: url)
            let before = try ContractMP4Oracle.read(url)
            let version = try TagLibMetadataManager.fileVersion(at: url)

            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [:],
                raw: RawMetadataPatch(valuesToSet: ["TITLE": ["Editor Native Title"]]),
                to: url,
                expectedVersion: version
            )
            let after = try ContractMP4Oracle.read(url)
            #expect(try after.text("©nam") == "Editor Native Title")
            #expect(after.items[titleFreeformKey] == before.items[titleFreeformKey])
            #expect(try readDataHeaders(for: titleFreeformKey, from: after).first?.locale == canadianFrench)
            #expect(after.audio == before.audio)
        }

        // 3. Editing only unrelated plID via applyMP4MetadataEditorPatch must preserve locale 0x43411A41.
        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seedRawILST(baseILST, to: url)
            let before = try ContractMP4Oracle.read(url)
            let version = try TagLibMetadataManager.fileVersion(at: url)

            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [.itunesAlbumID: .integer(6_829_122_413)],
                to: url,
                expectedVersion: version
            )
            let after = try ContractMP4Oracle.read(url)
            #expect(try after.integer("plID") == 6_829_122_413)
            #expect(after.items["©nam"] == before.items["©nam"])
            #expect(after.items[titleFreeformKey] == before.items[titleFreeformKey])
            #expect(try readDataHeaders(for: titleFreeformKey, from: after).first?.locale == canadianFrench)
            #expect(after.audio == before.audio)
        }

        // 4. Broader scope: non-zero locales and non-UTF8 data flags across freeforms and 4-char atoms
        //    survive typed patch, structured write, Basic update, and track-number write.
        let utf16Payload = Data([0x00, 0x4F, 0x00, 0x4B]) // UTF-16BE "OK"
        let multiLocaleKey = "----:com.apple.iTunes:MULTILOC"
        let utf16Key = "----:com.apple.iTunes:UTF16TAG"
        let binaryKey = "----:com.apple.iTunes:BINTAG"
        let nonITunesKey = "----:com.example.custom:NOTE"
        let richILST = baseILST
            + makeFreeform(
                mean: "com.apple.iTunes",
                name: "MULTILOC",
                dataAtoms: makeDataAtom(type: 1, locale: 0, payload: Data("EN".utf8))
                    + makeDataAtom(type: 1, locale: canadianFrench, payload: Data("FR".utf8))
            )
            + makeFreeform(
                mean: "com.apple.iTunes",
                name: "UTF16TAG",
                dataAtoms: makeDataAtom(type: 2, locale: canadianFrench, payload: utf16Payload)
            )
            + makeFreeform(
                mean: "com.apple.iTunes",
                name: "BINTAG",
                dataAtoms: makeDataAtom(type: 0, locale: canadianFrench, payload: Data([0xDE, 0xAD, 0xBE, 0xEF]))
            )
            + makeFreeform(
                mean: "com.example.custom",
                name: "NOTE",
                dataAtoms: makeDataAtom(type: 1, locale: canadianFrench, payload: Data("Custom FR".utf8))
            )
            + makeAtom("©cmt", makeDataAtom(type: 1, locale: canadianFrench, payload: Data("Commentaire".utf8)))

        let preservedKeys = [titleFreeformKey, multiLocaleKey, utf16Key, binaryKey, nonITunesKey, "©cmt"]
        try ContractFixture.withCopy("m4a") { url in
            try ContractMP4Seed.seedRawILST(richILST, to: url)
            let before = try ContractMP4Oracle.read(url)

            try TagLibMetadataManager.applyMetadataPatch(
                MetadataPatch(fields: [.album: .text("Typed Album")]),
                to: url
            )
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(mp4Atoms: [.init(key: "cnID", type: "longLong", value: "6829122414")]),
                to: url
            )
            try TagLibMetadataManager.updateBasicMetadata(at: url) { $0.artist = "Basic Artist" }
            try TagLibMetadataManager.writeTrackNumberText("3/10", discNumberText: nil, to: url)

            let after = try ContractMP4Oracle.read(url)
            #expect(try after.text("©alb") == "Typed Album")
            #expect(try after.integer("cnID") == 6_829_122_414)
            #expect(try after.text("©ART") == "Basic Artist")
            #expect(try after.intPair("trkn") == (3, 10))
            for key in preservedKeys {
                #expect(after.items[key] == before.items[key], "Untouched MP4 atom \(key) changed on disk")
            }
            let multiHeaders = try readDataHeaders(for: multiLocaleKey, from: after)
            #expect(multiHeaders.map(\.locale) == [0, canadianFrench])
            let utf16Headers = try readDataHeaders(for: utf16Key, from: after)
            #expect(utf16Headers.first?.type == 2)
            #expect(utf16Headers.first?.locale == canadianFrench)
            let binHeaders = try readDataHeaders(for: binaryKey, from: after)
            #expect(binHeaders.first?.type == 0)
            #expect(binHeaders.first?.locale == canadianFrench)
            #expect(try readDataHeaders(for: nonITunesKey, from: after).first?.locale == canadianFrench)
            #expect(try readDataHeaders(for: "©cmt", from: after).first?.locale == canadianFrench)
            #expect(after.audio == before.audio)
        }

        // 5. If preservation is impossible (an unparseable freeform with no data atom that TagLib would drop),
        //    every write surface must reject the save and leave the original file byte-for-byte intact.
        try ContractFixture.withCopy("m4a") { url in
            let unpreservableILST =
                makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Native Title".utf8)))
                + makeFreeform(mean: "com.apple.iTunes", name: "NODATA", dataAtoms: Data())
            try ContractMP4Seed.seedRawILST(unpreservableILST, to: url)
            let beforeBytes = try ContractFixture.bytes(url)
            let version = try TagLibMetadataManager.fileVersion(at: url)

            do {
                try TagLibMetadataManager.applyRawMetadataPatch(
                    RawMetadataPatch(valuesToSet: ["TITLE": ["New Title"]]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Raw save must reject when an unpreservable MP4 freeform would be dropped.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.itunesAlbumID: .integer(123)],
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Editor save must reject when an unpreservable MP4 freeform would be dropped.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.album: .text("New Album")]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Typed patch must reject when an unpreservable MP4 freeform would be dropped.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)
        }
    }

    @Test func duplicateFreeformsAndUTF16AtomsSurviveMP4Saves() throws {
        func be32(_ value: UInt32) -> Data {
            Data([
                UInt8((value >> 24) & 0xFF),
                UInt8((value >> 16) & 0xFF),
                UInt8((value >> 8) & 0xFF),
                UInt8(value & 0xFF),
            ])
        }
        func makeAtom(_ fourCC: String, _ payload: Data) -> Data {
            let typeBytes = fourCC.data(using: .isoLatin1)!
            return be32(UInt32(payload.count + 8)) + typeBytes + payload
        }
        func makeDataAtom(type: UInt32, locale: UInt32, payload: Data) -> Data {
            makeAtom("data", be32(type) + be32(locale) + payload)
        }
        func makeFreeform(mean: String, name: String, dataAtoms: Data) -> Data {
            let body = makeAtom("mean", be32(0) + Data(mean.utf8))
                + makeAtom("name", be32(0) + Data(name.utf8))
                + dataAtoms
            return makeAtom("----", body)
        }
        func readDataHeaders(for key: String, from oracle: ContractMP4Oracle) throws -> [(type: UInt32, locale: UInt32, payload: Data)] {
            guard let rawAtoms = oracle.items[key], !rawAtoms.isEmpty else { return [] }
            var results: [(UInt32, UInt32, Data)] = []
            for rawAtom in rawAtoms {
                let outer = try ContractMP4Oracle.atoms(rawAtom, 0..<rawAtom.count)
                guard outer.count == 1 else { continue }
                let children = try ContractMP4Oracle.atoms(rawAtom, outer[0].payload)
                for child in children where child.type == "data" {
                    let bytes = Data(rawAtom[child.payload])
                    guard bytes.count >= 8 else { continue }
                    let typeFlags = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
                    let locale = (UInt32(bytes[4]) << 24) | (UInt32(bytes[5]) << 16) | (UInt32(bytes[6]) << 8) | UInt32(bytes[7])
                    results.append((typeFlags, locale, Data(bytes.dropFirst(8))))
                }
            }
            return results
        }

        let canadianFrench: UInt32 = 0x4341_1A41
        let titleFreeformKey = "----:com.apple.iTunes:TITLE"
        let utf16Comment = Data([0x00, 0x42, 0x00, 0x6F, 0x00, 0x6E, 0x00, 0x6A, 0x00, 0x6F, 0x00, 0x75, 0x00, 0x72]) // UTF-16BE "Bonjour"
        let utf16Artist = Data([0x00, 0x41, 0x00, 0x72, 0x00, 0x74]) // UTF-16BE "Art"

        enum EditRoute: CaseIterable {
            case editorPlID, rawTitle, editorTitle, typedAlbum
        }

        // 1. Duplicate ----:com.apple.iTunes:TITLE atoms (different values, first with locale 0x43411A41)
        //    plus duplicate 4-char ©grp atoms survive byte-for-byte across all 4 edit routes.
        let duplicateILST =
            makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Native Title".utf8)))
            + makeFreeform(
                mean: "com.apple.iTunes",
                name: "TITLE",
                dataAtoms: makeDataAtom(type: 1, locale: canadianFrench, payload: Data("Premier Titre".utf8))
            )
            + makeFreeform(
                mean: "com.apple.iTunes",
                name: "TITLE",
                dataAtoms: makeDataAtom(type: 1, locale: 0, payload: Data("Second Title".utf8))
            )
            + makeAtom("©grp", makeDataAtom(type: 1, locale: canadianFrench, payload: Data("Groupe Un".utf8)))
            + makeAtom("©grp", makeDataAtom(type: 1, locale: 0, payload: Data("Group Two".utf8)))

        for route in EditRoute.allCases {
            try ContractFixture.withCopy("m4a") { url in
                try ContractMP4Seed.seedRawILST(duplicateILST, to: url)
                let before = try ContractMP4Oracle.read(url)
                #expect(before.items[titleFreeformKey]?.count == 2)
                #expect(before.items["©grp"]?.count == 2)
                let version = try TagLibMetadataManager.fileVersion(at: url)

                switch route {
                case .editorPlID:
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [.itunesAlbumID: .integer(6_829_122_413)],
                        to: url,
                        expectedVersion: version
                    )
                case .rawTitle:
                    try TagLibMetadataManager.applyRawMetadataPatch(
                        RawMetadataPatch(valuesToSet: ["TITLE": ["Raw Updated Title"]]),
                        to: url,
                        expectedVersion: version
                    )
                case .editorTitle:
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [:],
                        raw: RawMetadataPatch(valuesToSet: ["TITLE": ["Editor Updated Title"]]),
                        to: url,
                        expectedVersion: version
                    )
                case .typedAlbum:
                    try TagLibMetadataManager.applyMetadataPatch(
                        MetadataPatch(fields: [.album: .text("Typed Album")]),
                        to: url,
                        expectedVersion: version
                    )
                }

                let after = try ContractMP4Oracle.read(url)
                #expect(after.items[titleFreeformKey] == before.items[titleFreeformKey])
                let titleHeaders = try readDataHeaders(for: titleFreeformKey, from: after)
                try #require(titleHeaders.count == 2)
                #expect(titleHeaders[0].locale == canadianFrench)
                #expect(titleHeaders[0].payload == Data("Premier Titre".utf8))
                #expect(titleHeaders[1].locale == 0)
                #expect(titleHeaders[1].payload == Data("Second Title".utf8))

                #expect(after.items["©grp"] == before.items["©grp"])
                let grpHeaders = try readDataHeaders(for: "©grp", from: after)
                try #require(grpHeaders.count == 2)
                #expect(grpHeaders[0].locale == canadianFrench)
                #expect(grpHeaders[1].payload == Data("Group Two".utf8))
                #expect(after.audio == before.audio)
            }
        }

        // 2. UTF-16BE ©cmt (data type 2), UTF-16BE ©ART (data type 2), and opaque binary 4-char XXXX
        //    survive byte-for-byte across all 4 edit routes.
        let utf16ILST =
            makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Native Title".utf8)))
            + makeAtom("©cmt", makeDataAtom(type: 2, locale: canadianFrench, payload: utf16Comment))
            + makeAtom("©ART", makeDataAtom(type: 2, locale: 0, payload: utf16Artist))
            + makeAtom("XXXX", makeDataAtom(type: 0, locale: canadianFrench, payload: Data([0xCA, 0xFE, 0xBA, 0xBE])))

        for route in EditRoute.allCases {
            try ContractFixture.withCopy("m4a") { url in
                try ContractMP4Seed.seedRawILST(utf16ILST, to: url)
                let before = try ContractMP4Oracle.read(url)
                let version = try TagLibMetadataManager.fileVersion(at: url)

                switch route {
                case .editorPlID:
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [.itunesAlbumID: .integer(6_829_122_413)],
                        to: url,
                        expectedVersion: version
                    )
                case .rawTitle:
                    try TagLibMetadataManager.applyRawMetadataPatch(
                        RawMetadataPatch(valuesToSet: ["TITLE": ["Raw Updated Title"]]),
                        to: url,
                        expectedVersion: version
                    )
                case .editorTitle:
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [:],
                        raw: RawMetadataPatch(valuesToSet: ["TITLE": ["Editor Updated Title"]]),
                        to: url,
                        expectedVersion: version
                    )
                case .typedAlbum:
                    try TagLibMetadataManager.applyMetadataPatch(
                        MetadataPatch(fields: [.album: .text("Typed Album")]),
                        to: url,
                        expectedVersion: version
                    )
                }

                let after = try ContractMP4Oracle.read(url)
                #expect(after.items["©cmt"] == before.items["©cmt"])
                let cmtHeaders = try readDataHeaders(for: "©cmt", from: after)
                try #require(cmtHeaders.count == 1)
                #expect(cmtHeaders[0].type == 2)
                #expect(cmtHeaders[0].locale == canadianFrench)
                #expect(cmtHeaders[0].payload == utf16Comment)
                #expect(after.items["©ART"] == before.items["©ART"])
                #expect(after.items["XXXX"] == before.items["XXXX"])
                #expect(after.audio == before.audio)
            }
        }

        // 3. Conflicting writes/deletes targeting an unparsed UTF-16BE ©cmt, or removing the last parsed atom
        //    so unparsed atoms cannot be preserved, must reject and leave the file byte-for-byte intact.
        try ContractFixture.withCopy("m4a") { url in
            let singleParsedPlusUTF16 =
                makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Only Parsed".utf8)))
                + makeAtom("©cmt", makeDataAtom(type: 2, locale: 0, payload: utf16Comment))
            try ContractMP4Seed.seedRawILST(singleParsedPlusUTF16, to: url)
            let beforeBytes = try ContractFixture.bytes(url)
            let version = try TagLibMetadataManager.fileVersion(at: url)

            do {
                try TagLibMetadataManager.applyRawMetadataPatch(
                    RawMetadataPatch(valuesToSet: ["COMMENT": ["Conflicting UTF-8"]]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Writing COMMENT when an unparsed UTF-16BE ©cmt exists must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.applyRawMetadataPatch(
                    RawMetadataPatch(removingKeys: ["COMMENT"]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Removing COMMENT when an unparsed UTF-16BE ©cmt exists must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.comment: .text("Conflicting Typed")]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Typed comment edit when an unparsed UTF-16BE ©cmt exists must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.applyRawMetadataPatch(
                    RawMetadataPatch(removingKeys: ["TITLE"]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Removing the last parsed atom when an unparsed UTF-16BE ©cmt exists must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)
        }
    }

    @Test func explicitDeletionOfUnparsedMP4AtomsRejectsAtomicallyAcrossAPIs() throws {
        func be32(_ value: UInt32) -> Data {
            Data([
                UInt8((value >> 24) & 0xFF),
                UInt8((value >> 16) & 0xFF),
                UInt8((value >> 8) & 0xFF),
                UInt8(value & 0xFF),
            ])
        }
        func makeAtom(_ fourCC: String, _ payload: Data) -> Data {
            let typeBytes = fourCC.data(using: .isoLatin1)!
            return be32(UInt32(payload.count + 8)) + typeBytes + payload
        }
        func makeDataAtom(type: UInt32, locale: UInt32, payload: Data) -> Data {
            makeAtom("data", be32(type) + be32(locale) + payload)
        }
        func makeFreeform(mean: String, name: String, dataAtoms: Data) -> Data {
            let body = makeAtom("mean", be32(0) + Data(mean.utf8))
                + makeAtom("name", be32(0) + Data(name.utf8))
                + dataAtoms
            return makeAtom("----", body)
        }

        let canadianFrench: UInt32 = 0x4341_1A41
        let utf16Bonjour = Data([0x00, 0x42, 0x00, 0x6F, 0x00, 0x6E, 0x00, 0x6A, 0x00, 0x6F, 0x00, 0x75, 0x00, 0x72])
        let utf16Label = Data([0x00, 0x4C, 0x00, 0x61, 0x00, 0x62, 0x00, 0x65, 0x00, 0x6C])

        // 1. UTF-16BE ©cmt: typed, structured (mp4Atoms & properties), raw replace, and low-level Basic writes
        //    must reject explicit deletion/replacement atomically without committing companion edits.
        try ContractFixture.withCopy("m4a") { url in
            let ilst =
                makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Original Title".utf8)))
                + makeAtom("©alb", makeDataAtom(type: 1, locale: 0, payload: Data("Original Album".utf8)))
                + makeAtom("©cmt", makeDataAtom(type: 2, locale: canadianFrench, payload: utf16Bonjour))
            try ContractMP4Seed.seedRawILST(ilst, to: url)
            let beforeBytes = try ContractFixture.bytes(url)
            let version = try TagLibMetadataManager.fileVersion(at: url)

            // Typed delete alone and combined with an album edit.
            do {
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.comment: .remove]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Typed deletion of UTF-16BE ©cmt must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.comment: .remove, .album: .text("Must Not Commit")]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Combined typed deletion of UTF-16BE ©cmt + album edit must reject atomically.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            // Structured mp4Atoms delete (both remove: true and empty values) combined with album edit.
            do {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(mp4Atoms: [
                        StructuredMP4Atom(key: "©cmt", type: "stringList", remove: true),
                        StructuredMP4Atom(key: "©alb", type: "stringList", values: ["Must Not Commit"]),
                    ]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Structured mp4Atoms deletion of UTF-16BE ©cmt must reject atomically.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(mp4Atoms: [
                        StructuredMP4Atom(key: "©cmt", type: "stringList", values: []),
                        StructuredMP4Atom(key: "©alb", type: "stringList", values: ["Must Not Commit"]),
                    ]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Structured empty-values removal of UTF-16BE ©cmt must reject atomically.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            // Structured properties delete with includeProperties: true combined with album edit.
            do {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                    StructuredMetadata(properties: [
                        StructuredPropertyEntry(key: "COMMENT", values: []),
                        StructuredPropertyEntry(key: "ALBUM", values: ["Must Not Commit"]),
                    ]),
                    to: url,
                    includeProperties: true,
                    expectedVersion: version
                )
                Issue.record("Structured properties deletion of UTF-16BE ©cmt must reject atomically.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            // Raw PropertyMap full replacement (.replace) implicitly deletes COMMENT and must reject.
            do {
                try TagLibMetadataManager.writeRawMetadataPropertyMapWithVerification(
                    ["TITLE": "Must Not Commit"],
                    to: url,
                    mode: .replace,
                    expectedVersion: version
                )
                Issue.record("Raw scalar .replace over UTF-16BE ©cmt must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.writeRawMetadataPropertyMapValuesWithVerification(
                    ["TITLE": ["Must Not Commit"]],
                    to: url,
                    mode: .replace,
                    expectedVersion: version
                )
                Issue.record("Raw multi-value .replace over UTF-16BE ©cmt must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            // Low-level Basic replacement clears comment and must reject without modifying the file.
            let model = try TagLibMetadataExtractor.extractMetadata(from: url)
            model.album = "Must Not Commit"
            do {
                _ = try TagLibMetadataManager.writeTagMetadata(model, to: url, expectedVersion: version)
                Issue.record("Low-level Basic write over UTF-16BE ©cmt must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            // Direct exported bridge raw replace & structured delete over UTF-16BE ©cmt must also reject without mutating bytes.
            do {
                try TagLibMetadataExtractor.writeRawPropertyMap(["TITLE": "Must Not Commit"], to: url)
                Issue.record("Direct bridge writeRawPropertyMap over UTF-16BE ©cmt must reject.")
            } catch let error as NSError {
                #expect(error.domain == "TagLibMetadataExtractor")
                #expect(error.code == 9286)
            }
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            // Full container erase strips ilst completely, removing UTF-16BE ©cmt as well as parsed atoms.
            try TagLibMetadataManager.eraseAllMetadataWithVerification(from: url, expectedVersion: version)
            let erased = try ContractMP4Oracle.read(url, allowingAbsentMetadata: true)
            #expect(erased.items["©cmt"] == nil)
            #expect(erased.items["©nam"] == nil)
            #expect(erased.items["©alb"] == nil)
        }

        // 2. UTF-16BE ©pub: MP4 editor deletion alone and combined with catalog ID / title edits must reject atomically.
        try ContractFixture.withCopy("m4a") { url in
            let ilst =
                makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Original Title".utf8)))
                + makeAtom("©pub", makeDataAtom(type: 2, locale: canadianFrench, payload: utf16Label))
            try ContractMP4Seed.seedRawILST(ilst, to: url)
            let beforeBytes = try ContractFixture.bytes(url)
            let version = try TagLibMetadataManager.fileVersion(at: url)

            do {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.publisher: .remove],
                    to: url,
                    expectedVersion: version
                )
                Issue.record("MP4 editor deletion of UTF-16BE ©pub must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [
                        .publisher: .remove,
                        .itunesCatalogID: .integer(6_829_122_414),
                    ],
                    raw: RawMetadataPatch(valuesToSet: ["TITLE": ["Must Not Commit"]]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Combined MP4 editor deletion of UTF-16BE ©pub + catalog ID + title must reject atomically.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.publisher: .remove, .album: .text("Must Not Commit")]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Combined typed deletion of UTF-16BE ©pub + album edit must reject atomically.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)
        }

        // 3. Mixed UTF-8 + UTF-16BE ©cmt: targeting comment (even with the same UTF-8 value or delete) must reject,
        //    leaving both atoms untouched.
        try ContractFixture.withCopy("m4a") { url in
            let ilst =
                makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Track".utf8)))
                + makeAtom("©cmt", makeDataAtom(type: 1, locale: 0, payload: Data("English".utf8)))
                + makeAtom("©cmt", makeDataAtom(type: 2, locale: 0, payload: utf16Bonjour))
            try ContractMP4Seed.seedRawILST(ilst, to: url)
            let beforeBytes = try ContractFixture.bytes(url)
            let version = try TagLibMetadataManager.fileVersion(at: url)

            do {
                try TagLibMetadataManager.applyMetadataPatch(
                    MetadataPatch(fields: [.comment: .text("English"), .album: .text("Must Not Commit")]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Same-value typed write targeting mixed UTF-8/UTF-16BE ©cmt must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.applyRawMetadataPatch(
                    RawMetadataPatch(valuesToSet: ["COMMENT": ["English"], "ALBUM": ["Must Not Commit"]]),
                    to: url,
                    expectedVersion: version
                )
                Issue.record("Same-value raw write targeting mixed UTF-8/UTF-16BE ©cmt must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)

            do {
                try TagLibMetadataManager.updateBasicMetadata(at: url) {
                    $0.comment = ""
                    $0.album = "Must Not Commit"
                }
                Issue.record("Basic update clearing mixed UTF-8/UTF-16BE ©cmt must reject.")
            } catch TagLibManagerError.unsupportedWritePolicy {}
            #expect(try ContractFixture.bytes(url) == beforeBytes)
        }

        // 4. Structured includeProperties: true editing TITLE must preserve a coexisting shadowed TITLE freeform.
        try ContractFixture.withCopy("m4a") { url in
            let titleFreeformKey = "----:com.apple.iTunes:TITLE"
            let ilst =
                makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Native Title".utf8)))
                + makeFreeform(
                    mean: "com.apple.iTunes",
                    name: "TITLE",
                    dataAtoms: makeDataAtom(type: 1, locale: canadianFrench, payload: Data("Titre Libre".utf8))
                )
            try ContractMP4Seed.seedRawILST(ilst, to: url)
            let before = try ContractMP4Oracle.read(url)
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                StructuredMetadata(properties: [
                    StructuredPropertyEntry(key: "TITLE", values: ["Structured Native Title"]),
                ]),
                to: url,
                includeProperties: true
            )
            let after = try ContractMP4Oracle.read(url)
            #expect(try after.text("©nam") == "Structured Native Title")
            #expect(after.items[titleFreeformKey] == before.items[titleFreeformKey])
            #expect(after.audio == before.audio)
        }
    }

    @Test func unrelatedEditsPreserveDuplicateMixedCommentOrderAndBytes() async throws {
        func be32(_ value: UInt32) -> Data {
            Data([
                UInt8((value >> 24) & 0xFF),
                UInt8((value >> 16) & 0xFF),
                UInt8((value >> 8) & 0xFF),
                UInt8(value & 0xFF),
            ])
        }
        func makeAtom(_ fourCC: String, _ payload: Data) -> Data {
            let typeBytes = fourCC.data(using: .isoLatin1)!
            return be32(UInt32(payload.count + 8)) + typeBytes + payload
        }
        func makeDataAtom(type: UInt32, locale: UInt32, payload: Data) -> Data {
            makeAtom("data", be32(type) + be32(locale) + payload)
        }
        func readDataHeaders(for key: String, from oracle: ContractMP4Oracle) throws -> [(type: UInt32, locale: UInt32, payload: Data)] {
            guard let rawAtoms = oracle.items[key], !rawAtoms.isEmpty else { return [] }
            var results: [(UInt32, UInt32, Data)] = []
            for rawAtom in rawAtoms {
                let outer = try ContractMP4Oracle.atoms(rawAtom, 0..<rawAtom.count)
                guard outer.count == 1 else { continue }
                let children = try ContractMP4Oracle.atoms(rawAtom, outer[0].payload)
                for child in children where child.type == "data" {
                    let bytes = Data(rawAtom[child.payload])
                    guard bytes.count >= 8 else { continue }
                    let typeFlags = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
                    let locale = (UInt32(bytes[4]) << 24) | (UInt32(bytes[5]) << 16) | (UInt32(bytes[6]) << 8) | UInt32(bytes[7])
                    results.append((typeFlags, locale, Data(bytes.dropFirst(8))))
                }
            }
            return results
        }
        #if canImport(AVFoundation)
        func loadAVFoundationComments(at url: URL) async throws -> [String] {
            let asset = AVURLAsset(url: url)
            let items = try await asset.loadMetadata(for: .iTunesMetadata)
            let comments = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .iTunesMetadataUserComment)
            var values: [String] = []
            for item in comments {
                if let text = try await item.load(.stringValue) {
                    values.append(text)
                }
            }
            return values
        }
        #endif

        let canadianFrench: UInt32 = 0x4341_1A41
        let usEnglish: UInt32 = 0x5553_0000
        let utf8English = Data("English".utf8)
        let utf16Bonjour = Data([0x00, 0x42, 0x00, 0x6F, 0x00, 0x6E, 0x00, 0x6A, 0x00, 0x6F, 0x00, 0x75, 0x00, 0x72])
        let utf8Third = Data("Third".utf8)

        enum UnrelatedEditRoute: CaseIterable {
            case editorPlID, rawTitle, typedAlbum, basicAlbum, structuredPublisher
        }

        func withAsyncM4ACopy(_ body: (URL) async throws -> Void) async throws {
            let source = try ContractFixture.url("m4a")
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("mp4-order-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let copy = directory.appendingPathComponent("fixture.m4a")
            try FileManager.default.copyItem(at: source, to: copy)
            try await body(copy)
        }

        // 1. UTF-8 ©cmt("English") followed by UTF-16BE ©cmt("Bonjour") must keep exact bytes and order
        //    (and AVFoundation must continue returning "English" first) across unrelated edits.
        let englishThenBonjour =
            makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Track".utf8)))
            + makeAtom("©cmt", makeDataAtom(type: 1, locale: usEnglish, payload: utf8English))
            + makeAtom("©cmt", makeDataAtom(type: 2, locale: canadianFrench, payload: utf16Bonjour))

        for route in UnrelatedEditRoute.allCases {
            try await withAsyncM4ACopy { url in
                try ContractMP4Seed.seedRawILST(englishThenBonjour, to: url)
                let before = try ContractMP4Oracle.read(url)
                #if canImport(AVFoundation)
                let beforeAV = try await loadAVFoundationComments(at: url)
                #expect(beforeAV == ["English", "Bonjour"])
                #endif
                let version = try TagLibMetadataManager.fileVersion(at: url)

                switch route {
                case .editorPlID:
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [.itunesAlbumID: .integer(6_829_122_413)],
                        to: url,
                        expectedVersion: version
                    )
                case .rawTitle:
                    try TagLibMetadataManager.applyRawMetadataPatch(
                        RawMetadataPatch(valuesToSet: ["TITLE": ["Raw Updated Title"]]),
                        to: url,
                        expectedVersion: version
                    )
                case .typedAlbum:
                    try TagLibMetadataManager.applyMetadataPatch(
                        MetadataPatch(fields: [.album: .text("Typed Album")]),
                        to: url,
                        expectedVersion: version
                    )
                case .basicAlbum:
                    try TagLibMetadataManager.updateBasicMetadata(at: url) {
                        $0.album = "Basic Album"
                    }
                case .structuredPublisher:
                    try TagLibMetadataManager.writeStructuredMetadataWithVerification(
                        StructuredMetadata(mp4Atoms: [
                            StructuredMP4Atom(key: "©pub", type: "stringList", values: ["Structured Label"]),
                        ]),
                        to: url,
                        expectedVersion: version
                    )
                }

                let after = try ContractMP4Oracle.read(url)
                #expect(after.items["©cmt"] == before.items["©cmt"])
                let headers = try readDataHeaders(for: "©cmt", from: after)
                try #require(headers.count == 2)
                #expect(headers[0].type == 1)
                #expect(headers[0].locale == usEnglish)
                #expect(headers[0].payload == utf8English)
                #expect(headers[1].type == 2)
                #expect(headers[1].locale == canadianFrench)
                #expect(headers[1].payload == utf16Bonjour)
                #expect(after.audio == before.audio)
                #if canImport(AVFoundation)
                let afterAV = try await loadAVFoundationComments(at: url)
                #expect(afterAV == ["English", "Bonjour"])
                #endif
            }
        }

        // 2. Reverse order: UTF-16BE ©cmt("Bonjour") followed by UTF-8 ©cmt("English") must stay reversed.
        let bonjourThenEnglish =
            makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Track".utf8)))
            + makeAtom("©cmt", makeDataAtom(type: 2, locale: canadianFrench, payload: utf16Bonjour))
            + makeAtom("©cmt", makeDataAtom(type: 1, locale: usEnglish, payload: utf8English))

        try await withAsyncM4ACopy { url in
            try ContractMP4Seed.seedRawILST(bonjourThenEnglish, to: url)
            let before = try ContractMP4Oracle.read(url)
            let version = try TagLibMetadataManager.fileVersion(at: url)
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [.itunesAlbumID: .integer(6_829_122_413)],
                to: url,
                expectedVersion: version
            )
            let after = try ContractMP4Oracle.read(url)
            #expect(after.items["©cmt"] == before.items["©cmt"])
            let headers = try readDataHeaders(for: "©cmt", from: after)
            try #require(headers.count == 2)
            #expect(headers[0].type == 2)
            #expect(headers[0].payload == utf16Bonjour)
            #expect(headers[1].type == 1)
            #expect(headers[1].payload == utf8English)
            #expect(after.audio == before.audio)
            #if canImport(AVFoundation)
            let afterAV = try await loadAVFoundationComments(at: url)
            #expect(afterAV == ["Bonjour", "English"])
            #endif
        }

        // 3. Interleaved triple: UTF-8, UTF-16BE, UTF-8 must preserve all three in exact relative order.
        let interleaved =
            makeAtom("©nam", makeDataAtom(type: 1, locale: 0, payload: Data("Track".utf8)))
            + makeAtom("©cmt", makeDataAtom(type: 1, locale: usEnglish, payload: utf8English))
            + makeAtom("©cmt", makeDataAtom(type: 2, locale: canadianFrench, payload: utf16Bonjour))
            + makeAtom("©cmt", makeDataAtom(type: 1, locale: 0, payload: utf8Third))

        try await withAsyncM4ACopy { url in
            try ContractMP4Seed.seedRawILST(interleaved, to: url)
            let before = try ContractMP4Oracle.read(url)
            let version = try TagLibMetadataManager.fileVersion(at: url)
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [.itunesAlbumID: .integer(6_829_122_413)],
                to: url,
                expectedVersion: version
            )
            let after = try ContractMP4Oracle.read(url)
            #expect(after.items["©cmt"] == before.items["©cmt"])
            let headers = try readDataHeaders(for: "©cmt", from: after)
            try #require(headers.count == 3)
            #expect(headers[0].payload == utf8English)
            #expect(headers[1].payload == utf16Bonjour)
            #expect(headers[2].payload == utf8Third)
            #expect(after.audio == before.audio)
            #if canImport(AVFoundation)
            let afterAV = try await loadAVFoundationComments(at: url)
            #expect(afterAV == ["English", "Bonjour", "Third"])
            #endif
        }
    }

    @Test func emptyEditorPatchEnforcesVersionAudioAndFileGuards() throws {
        try ContractFixture.withCopy("m4a") { url in
            let originalVersion = try TagLibMetadataManager.fileVersion(at: url)
            let originalBytes = try ContractFixture.bytes(url)

            // Valid empty patch succeeds without modifying bytes or file version.
            let result = try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [:],
                to: url,
                expectedVersion: originalVersion
            )
            #expect(result.warnings.isEmpty)
            #expect(try ContractFixture.bytes(url) == originalBytes)
            #expect(try TagLibMetadataManager.fileVersion(at: url) == originalVersion)

            // Empty patch must still enforce expectedAudioContent.
            try ContractFixture.withCopy("flac") { flacURL in
                let baseline = try TagLibMetadataManager.readSnapshot(from: flacURL, includingAudioContent: true)
                let audioIdentity = try #require(baseline.audioContentIdentity)
                #expect(throws: MetadataAudioContentError.unavailable) {
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [:],
                        to: url,
                        expectedVersion: originalVersion,
                        expectedAudioContent: audioIdentity
                    )
                }
            }

            // Empty patch must still reject a stale expectedVersion.
            try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields: [.title: .text("Updated")]), to: url)
            let updatedBytes = try ContractFixture.bytes(url)
            do {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [:],
                    to: url,
                    expectedVersion: originalVersion
                )
                Issue.record("An empty editor patch with a stale expectedVersion must be rejected.")
            } catch TagLibManagerError.fileChanged {}
            #expect(try ContractFixture.bytes(url) == updatedBytes)

            // Empty patch must reject a missing MP4 file.
            let missing = url.deletingLastPathComponent().appendingPathComponent("missing-editor-target.m4a")
            do {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [:],
                    to: missing,
                    expectedVersion: originalVersion
                )
                Issue.record("An empty editor patch for a missing file must be rejected.")
            } catch TagLibManagerError.invalidFile {}
        }
    }

    @Test func preservesLegacyAdvisoryUntilAnExactNativeEdit() throws {
        try ContractFixture.withCopy("m4a") { url in
            let legacy = "----:com.apple.iTunes:ITUNESADVISORY"
            try ContractMP4Seed.seed([
                .init(key: "rtng", value: .integer(4, byteCount: 1)),
                .init(key: legacy, value: .text("1")),
            ], to: url)
            let before = try ContractMP4Oracle.read(url)
            #expect(try before.integer("rtng") == 4)
            #expect(try before.text(legacy) == "1")
            var snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(snapshot.editableMP4Fields.first { $0.field == .explicitContent }?.atom?.value == "4")
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [:], raw: RawMetadataPatch(valuesToSet: ["ITUNESADVISORY": ["2"]]),
                to: url, expectedVersion: try #require(snapshot.fileVersion)
            )
            let rawOnly = try ContractMP4Oracle.read(url)
            #expect(rawOnly.items["rtng"] == before.items["rtng"])
            #expect(try rawOnly.text(legacy) == "2")
            snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                [.explicitContent: .integer(0)],
                raw: RawMetadataPatch(removingKeys: ["ITUNESADVISORY"]),
                to: url, expectedVersion: try #require(snapshot.fileVersion)
            )
            let edited = try ContractMP4Oracle.read(url)
            #expect(try edited.integer("rtng") == 0)
            #expect(edited.values["rtng"]?.first?.count == 1)
            #expect(edited.items[legacy] == nil)
        }
    }

    @Test func rejectsInvalidAndStaleChangesWithoutPartialWrites() throws {
        try ContractFixture.withCopy("m4a") { url in
            let version = try TagLibMetadataManager.fileVersion(at: url)
            let before = try ContractFixture.bytes(url)
            let raw = RawMetadataPatch(valuesToSet: ["TITLE": ["Must not save"]])
            let invalidEdits: [(MetadataFieldKey, Int, Int)] = [
                (.itunesAlbumID, -1, Int.max),
                (.itunesArtistID, Int(UInt32.max) + 1, Int(UInt32.max)),
                (.itunesGenreID, Int(UInt32.max) + 1, Int(UInt32.max)),
                (.itunesMediaType, 256, 255),
                (.itunesComposerID, -1, Int(UInt32.max)),
                (.itunesCountryID, Int(UInt32.max) + 1, Int(UInt32.max)),
                (.explicitContent, -1, 2),
                (.explicitContent, 4, 2),
            ]
            for (field, value, maximum) in invalidEdits {
                #expect(throws: MetadataPatchValidationError.integerOutOfRange(
                    field: field, minimum: 0, maximum: maximum, actual: value
                )) {
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [field: .integer(value)], raw: raw, to: url, expectedVersion: version
                    )
                }
                #expect(try ContractFixture.bytes(url) == before)
            }

            // Incompatible value kinds, unsupported fields, and empty text/values reject before staging.
            #expect(throws: MetadataPatchValidationError.incompatibleValue(
                field: .itunesAlbumID, expected: [.integer], actual: .text
            )) {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.itunesAlbumID: .text("123")], raw: raw, to: url, expectedVersion: version
                )
            }
            #expect(throws: MetadataPatchValidationError.incompatibleValue(
                field: .itunesHDVideo, expected: [.boolean], actual: .integer
            )) {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.itunesHDVideo: .integer(1)], raw: raw, to: url, expectedVersion: version
                )
            }
            #expect(throws: MetadataPatchValidationError.incompatibleValue(
                field: .publisher, expected: [.text], actual: .values
            )) {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.publisher: .values(["A", "B"])], raw: raw, to: url, expectedVersion: version
                )
            }
            #expect(throws: MetadataPatchValidationError.emptyText(location: MetadataFieldKey.publisher.rawValue)) {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.publisher: .text("   ")], raw: raw, to: url, expectedVersion: version
                )
            }
            #expect(throws: MetadataPatchValidationError.emptyValueList(location: MetadataFieldKey.director.rawValue)) {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.director: .values([])], raw: raw, to: url, expectedVersion: version
                )
            }
            for unsupportedField in [MetadataFieldKey.title, .rate] {
                #expect(throws: MetadataPatchValidationError.unsupportedFieldForFormat(
                    field: unsupportedField, format: "MP4 metadata editor"
                )) {
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [unsupportedField: .text("No")], raw: raw, to: url, expectedVersion: version
                    )
                }
            }
            #expect(try ContractFixture.bytes(url) == before)

            do {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.itunesAlbumID: .integer(6_829_122_413)],
                    raw: RawMetadataPatch(valuesToSet: ["TRACKNUMBER": ["01/02"]]),
                    to: url, expectedVersion: version
                )
                Issue.record("A normalized raw value must fail exact verification.")
            } catch TagLibManagerError.verificationFailed(let mismatches) {
                #expect(mismatches.contains { $0.contains("TRACKNUMBER") })
            }
            #expect(try ContractFixture.bytes(url) == before)

            try ContractFixture.withCopy("flac") { flacURL in
                let baseline = try TagLibMetadataManager.readSnapshot(from: flacURL, includingAudioContent: true)
                let audioIdentity = try #require(baseline.audioContentIdentity)
                #expect(throws: MetadataAudioContentError.unavailable) {
                    try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                        [.itunesAlbumID: .integer(1)], raw: raw, to: url,
                        expectedVersion: version, expectedAudioContent: audioIdentity
                    )
                }
            }
            #expect(try ContractFixture.bytes(url) == before)

            try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields: [.title: .text("New revision")]), to: url)
            let after = try ContractFixture.bytes(url)
            do {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.itunesAlbumID: .integer(1)], raw: raw, to: url, expectedVersion: version
                )
                Issue.record("A stale editor version must be rejected.")
            } catch TagLibManagerError.fileChanged {}
            #expect(try ContractFixture.bytes(url) == after)
        }
    }

    @Test func manualMP4SnapshotAndEditorFieldInitializer() throws {
        try ContractFixture.withCopy("m4a") { url in
            let basic = try TagLibMetadataManager.readMetadataResult(from: url)
            let albumAtom = StructuredMP4Atom(key: "plID", type: "longLong", value: "6829122413")
            let publisherAtom = StructuredMP4Atom(key: "©pub", type: "stringList", value: "Label", values: ["Label"])
            let row = MP4MetadataEditorField(field: .itunesAlbumID, atomKey: "plID", atom: albumAtom)
            #expect(row.field == .itunesAlbumID)
            #expect(row.atomKey == "plID")
            #expect(row.atom == albumAtom)

            let mp4Snapshot = MetadataSnapshot(
                basic: basic,
                raw: .empty,
                structured: StructuredMetadata(mp4Atoms: [albumAtom, publisherAtom])
            )
            let rows = Dictionary(uniqueKeysWithValues: mp4Snapshot.editableMP4Fields.map { ($0.field, $0) })
            #expect(rows.count == 15)
            #expect(rows[.itunesAlbumID] == row)
            #expect(rows[.publisher]?.atom == publisherAtom)
            #expect(rows[.itunesGenreID]?.atomKey == "geID")
            #expect(rows[.itunesGenreID]?.atom == nil)

            let emptySnapshot = MetadataSnapshot(
                basic: basic,
                raw: .empty,
                structured: StructuredMetadata()
            )
            #expect(emptySnapshot.editableMP4Fields.isEmpty)
        }
    }

    @Test func offersNativeRowsOnlyForMP4Files() throws {
        try ContractFixture.withCopy("flac") { url in
            let snapshot = try TagLibMetadataManager.readSnapshot(from: url)
            #expect(snapshot.editableMP4Fields.isEmpty)
            do {
                try TagLibMetadataManager.applyMP4MetadataEditorPatch(
                    [.itunesAlbumID: .integer(1)], to: url, expectedVersion: try #require(snapshot.fileVersion)
                )
                Issue.record("The MP4 editor operation requires an MP4 file.")
            } catch TagLibManagerError.unsupportedFormat {}
        }
    }
}
