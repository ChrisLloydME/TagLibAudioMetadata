import Foundation
import CTagLibBridge
import Testing
@testable import TagLibAudioMetadata

/// Permanent matrix and control coverage for the numbering-contract repairs.
/// Native expectations are literal and read with the independent test probes.
struct NumberingContractRepairTests {
    enum Surface: String, CaseIterable, Sendable { case facade, bridge }
    enum Group: String, CaseIterable, Sendable { case track, disc }
    enum Request: String, CaseIterable, Sendable { case omitTotal, explicitZero, positiveTotal }

    private struct NativeNumber {
        var trackNumber: Int?
        var trackTotal: Int?
        var discNumber: Int?
        var discTotal: Int?
        var trackText: String?
        var discText: String?
        var audio: Data
    }

    struct MatrixCell: Sendable {
        let ext: String
        let surface: Surface
        let group: Group
        let request: Request
    }
    struct VerificationCell: Sendable {
        let ext: String
        let group: Group
        let request: Request
    }
    static let matrixFormats = ["m4a", "mp3", "flac", "ogg", "wv"]
    static let matrixCells: [MatrixCell] = matrixFormats.flatMap { ext in
        Surface.allCases.flatMap { surface in
            Group.allCases.flatMap { group in
                Request.allCases.map { request in
                    MatrixCell(ext: ext, surface: surface, group: group, request: request)
                }
            }
        }
    }
    static let verificationCells: [VerificationCell] = matrixFormats.flatMap { ext in
        Group.allCases.flatMap { group in
            Request.allCases.map { request in
                VerificationCell(ext: ext, group: group, request: request)
            }
        }
    }

    private func copy(_ ext: String) throws -> URL {
        let source = try #require(
            Bundle.module.url(forResource: "testAudioFile", withExtension: ext, subdirectory: "Audio")
                ?? Bundle.module.url(forResource: "testAudioFile", withExtension: ext)
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    private func mp4Pair(_ probe: IndependentMP4Probe, _ key: String) -> (Int, Int)? {
        guard let bytes = probe.values[key]?.first else { return nil }
        guard bytes.count == 6 || bytes.count == 8 else { return nil }
        return (Int(bytes[2]) << 8 | Int(bytes[3]), Int(bytes[4]) << 8 | Int(bytes[5]))
    }

    private func textPair(_ text: String?) -> (number: Int?, total: Int?)? {
        guard let text else { return nil }
        let parts = text.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2 else { return nil }
        func value(_ part: Substring) -> Int? {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? 0 : Int(trimmed)
        }
        let number = value(parts[0]).flatMap { $0 > 0 ? $0 : nil }
        let total = parts.count == 2 ? value(parts[1]).flatMap { $0 > 0 ? $0 : nil } : nil
        return (number, total)
    }

    private func native(_ url: URL, _ ext: String) throws -> NativeNumber {
        switch ext {
        case "m4a":
            let probe = try IndependentMP4Probe.read(url)
            let track = mp4Pair(probe, "trkn")
            let disc = mp4Pair(probe, "disk")
            return NativeNumber(
                trackNumber: track.flatMap { $0.0 > 0 ? $0.0 : nil },
                trackTotal: track.flatMap { $0.1 > 0 ? $0.1 : nil },
                discNumber: disc.flatMap { $0.0 > 0 ? $0.0 : nil },
                discTotal: disc.flatMap { $0.1 > 0 ? $0.1 : nil },
                trackText: nil, discText: nil, audio: probe.audio.reduce(Data(), +)
            )
        case "mp3":
            let probe = try IndependentID3Probe.read(url)
            let trackText = probe.texts["TRCK"]?.first
            let discText = probe.texts["TPOS"]?.first
            let track = textPair(trackText)
            let disc = textPair(discText)
            return NativeNumber(
                trackNumber: track?.number, trackTotal: track?.total,
                discNumber: disc?.number, discTotal: disc?.total,
                trackText: trackText, discText: discText, audio: probe.audio
            )
        case "flac":
            let probe = try IndependentFLACProbe.read(url)
            return NativeNumber(
                trackNumber: probe.comments["TRACKNUMBER"]?.first.flatMap(Int.init),
                trackTotal: probe.comments["TRACKTOTAL"]?.first.flatMap(Int.init),
                discNumber: probe.comments["DISCNUMBER"]?.first.flatMap(Int.init),
                discTotal: probe.comments["DISCTOTAL"]?.first.flatMap(Int.init),
                trackText: nil, discText: nil, audio: probe.audio
            )
        case "ogg":
            let probe = try IndependentOggProbe.read(url)
            return NativeNumber(
                trackNumber: probe.comments["TRACKNUMBER"]?.first.flatMap(Int.init),
                trackTotal: probe.comments["TRACKTOTAL"]?.first.flatMap(Int.init),
                discNumber: probe.comments["DISCNUMBER"]?.first.flatMap(Int.init),
                discTotal: probe.comments["DISCTOTAL"]?.first.flatMap(Int.init),
                trackText: nil, discText: nil, audio: probe.audio.reduce(Data(), +)
            )
        case "wv":
            let state = try HardeningFixture.apeState(Data(contentsOf: url))
            func int(_ key: String) -> Int? {
                state.items[key].flatMap { String(data: $0.value, encoding: .utf8).flatMap(Int.init) }
            }
            return NativeNumber(
                trackNumber: int("TRACK"), trackTotal: int("TRACKTOTAL"),
                discNumber: int("DISC"), discTotal: int("DISCTOTAL"),
                trackText: nil, discText: nil, audio: state.audio
            )
        default:
            throw CocoaError(.fileReadUnknown)
        }
    }

    private func seed(_ url: URL) throws {
        _ = try TagLibMetadataManager.applyMetadataPatch(
            .init(fields: [
                .track: .integer(3), .trackTotal: .integer(12),
                .disc: .integer(1), .discTotal: .integer(12),
            ]),
            to: url
        )
    }

    private func requestText(_ request: Request, number: Int) -> String {
        switch request {
        case .omitTotal: return "\(number)"
        case .explicitZero: return "\(number)/0"
        case .positiveTotal: return "\(number)/15"
        }
    }

    private func expectedTotal(_ request: Request) -> Int? {
        switch request {
        case .omitTotal: return 12
        case .explicitZero: return nil
        case .positiveTotal: return 15
        }
    }

    @Test(arguments: matrixCells)
    func explicitIntentMatrix(_ cell: MatrixCell) throws {
        let (ext, surface, group, request) = (cell.ext, cell.surface, cell.group, cell.request)
        let url = try copy(ext)
        defer { try? FileManager.default.removeItem(at: url) }
        try seed(url)
        let before = try native(url, ext)
        #expect(before.trackNumber == 3 && before.trackTotal == 12, "seed track \(ext)")
        #expect(before.discNumber == 1 && before.discTotal == 12, "seed disc \(ext)")

        let trackText = group == .track ? requestText(request, number: 5) : "3/12"
        let discText: String? = group == .disc ? requestText(request, number: 1) : nil
        switch surface {
        case .facade:
            _ = try TagLibMetadataManager.writeTrackNumberText(
                trackText, discNumberText: discText, to: url)
        case .bridge:
            try TagLibMetadataExtractor.writeTrackNumberText(
                trackText, discNumberText: discText, to: url)
        }

        let after = try native(url, ext)
        if group == .track {
            #expect(after.trackNumber == 5, "\(ext) \(surface) track number")
            #expect(after.trackTotal == expectedTotal(request), "\(ext) \(surface) track total")
            #expect(after.discNumber == 1 && after.discTotal == 12, "\(ext) \(surface) untouched disc")
        } else {
            #expect(after.discNumber == 1, "\(ext) \(surface) disc number")
            #expect(after.discTotal == expectedTotal(request), "\(ext) \(surface) disc total")
            #expect(after.trackNumber == 3 && after.trackTotal == 12, "\(ext) \(surface) untouched track")
        }
        #expect(after.audio == before.audio, "\(ext) \(surface) audio")
    }

    @Test(arguments: verificationCells)
    func explicitIntentFacadeVerificationDisabled(_ cell: VerificationCell) throws {
        let (ext, group, request) = (cell.ext, cell.group, cell.request)
        let url = try copy(ext)
        defer { try? FileManager.default.removeItem(at: url) }
        try seed(url)
        let before = try native(url, ext)
        let trackText = group == .track ? requestText(request, number: 5) : "3/12"
        let discText: String? = group == .disc ? requestText(request, number: 1) : nil
        _ = try TagLibMetadataManager.writeTrackNumberText(
            trackText, discNumberText: discText, to: url, verifyAfterWrite: false)
        let after = try native(url, ext)
        if group == .track {
            #expect(after.trackNumber == 5 && after.trackTotal == expectedTotal(request))
            #expect(after.discNumber == 1 && after.discTotal == 12)
        } else {
            #expect(after.discNumber == 1 && after.discTotal == expectedTotal(request))
            #expect(after.trackNumber == 3 && after.trackTotal == 12)
        }
        #expect(after.audio == before.audio)
    }

    // MARK: - Opaque evidence

    @Test(arguments: [["03/12", "garbage"], ["03/12", "A1/13"]])
    func opaquePrivateEvidenceIsNotRecovered(_ values: [String]) throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 0),
            .init(key: "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT",
                  type: "stringList", values: values),
        ]), to: url)
        let before = try Data(contentsOf: url)
        let inventory = try TagLibMetadataManager.numberingInventory(at: url)
        #expect(inventory.track.total.state == .ambiguous)
        #expect(inventory.track.total.recoveredValue == nil)
        do {
            _ = try TagLibMetadataManager.applyMetadataPatch(
                .init(numberText: .init(trackNumberText: "5")), to: url)
            Issue.record("opaque private evidence must not supply the missing total")
        } catch let error as MetadataPatchValidationError {
            guard case .ambiguousNumberRecovery(let field, _) = error else {
                Issue.record("expected ambiguousNumberRecovery, got \(error)")
                return
            }
            #expect(field == "trackTotal")
        }
        #expect(try Data(contentsOf: url) == before)
    }

    @Test func canonicalNativeTotalBeatsOpaquePrivateEvidence() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let key = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 6),
            .init(key: key, type: "stringList", values: ["03/12", "garbage"]),
        ]), to: url)
        _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(5)]), to: url)
        let after = try native(url, "m4a")
        #expect(after.trackNumber == 5 && after.trackTotal == 6)
        #expect(try IndependentMP4Probe.read(url).values[key] == nil)
    }

    @Test(arguments: [true, false])
    func strictSinglePrivateEvidenceStillRecoversMissingSibling(_ track: Bool) throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let atom: StructuredMP4Atom = track
            ? .init(key: "trkn", type: "intPair", first: 3, second: 0)
            : .init(key: "disk", type: "intPair", first: 1, second: 0)
        let key = track
            ? "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
            : "----:com.apple.iTunes:AUDIOMATOR_DISCNUMBER_TEXT"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(
            .init(mp4Atoms: [atom, .init(key: key, type: "stringList", values: [track ? "03/12" : "01/12"])]),
            to: url)
        if track {
            _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(5)]), to: url)
            let after = try native(url, "m4a")
            #expect(after.trackNumber == 5 && after.trackTotal == 12)
        } else {
            _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.disc: .integer(2)]), to: url)
            let after = try native(url, "m4a")
            #expect(after.discNumber == 2 && after.discTotal == 12)
        }
        #expect(try IndependentMP4Probe.read(url).values[key] == nil)
    }

    @Test func matchingStrictNamespacesRecoverAndBothRetire() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let a = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        let b = "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 0),
            .init(key: a, type: "stringList", values: ["03/12"]),
            .init(key: b, type: "stringList", values: ["03/12"]),
        ]), to: url)
        _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(5)]), to: url)
        let after = try native(url, "m4a")
        #expect(after.trackNumber == 5 && after.trackTotal == 12)
        #expect(try IndependentMP4Probe.read(url).values[a] == nil)
        #expect(try IndependentMP4Probe.read(url).values[b] == nil)
    }

    @Test func conflictingStrictNamespacesRejectWithoutMutation() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 0),
            .init(key: "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT", type: "stringList", values: ["03/12"]),
            .init(key: "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT", type: "stringList", values: ["04/14"]),
        ]), to: url)
        let before = try Data(contentsOf: url)
        do {
            _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.track: .integer(5)]), to: url)
            Issue.record("conflicting strict evidence must reject")
        } catch let error as MetadataPatchValidationError {
            guard case .ambiguousNumberRecovery(let field, _) = error else {
                Issue.record("expected ambiguousNumberRecovery, got \(error)")
                return
            }
            #expect(field == "trackTotal")
        }
        #expect(try Data(contentsOf: url) == before)
        _ = try TagLibMetadataManager.applyMetadataPatch(
            .init(fields: [.track: .integer(5), .trackTotal: .integer(16)]), to: url)
        let after = try native(url, "m4a")
        #expect(after.trackNumber == 5 && after.trackTotal == 16)
    }

    // MARK: - ID3 explicit zero and follow-up

    @Test(arguments: [true, false])
    func id3ExplicitZeroReopensAndAllowsTotalOnlyEdit(_ track: Bool) throws {
        let url = try copy("mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        let text = track ? "5/0" : "1/0"
        let frame = track ? "TRCK" : "TPOS"
        let number = track ? 5 : 1
        _ = try TagLibMetadataManager.applyMetadataPatch(
            .init(numberText: .init(trackNumberText: track ? text : nil,
                                    discNumberText: track ? nil : text)),
            to: url)
        #expect(try IndependentID3Probe.read(url).texts[frame] == [text])
        let inventory = try TagLibMetadataManager.numberingInventory(at: url)
        let group = track ? inventory.track : inventory.disc
        #expect(group.number.nativeValue == number)
        #expect(group.number.state == .native)
        #expect(group.total.state == .absent)
        #expect(group.total.nativeValue == nil)

        // An unrelated write preserves the stored explicit-zero text.
        _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.title: .text("Keep zero text")]), to: url)
        #expect(try IndependentID3Probe.read(url).texts[frame] == [text])
        let preserved = try TagLibMetadataManager.numberingInventory(at: url)
        #expect((track ? preserved.track : preserved.disc).number.nativeValue == number)

        // A total-only edit retains the number and writes the new total.
        if track {
            _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.trackTotal: .integer(15)]), to: url)
        } else {
            _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.discTotal: .integer(15)]), to: url)
        }
        let expected = track ? "5/15" : "1/15"
        #expect(try IndependentID3Probe.read(url).texts[frame] == [expected])
        let edited = try TagLibMetadataManager.numberingInventory(at: url)
        let editedGroup = track ? edited.track : edited.disc
        #expect(editedGroup.number.nativeValue == number && editedGroup.total.nativeValue == 15)
    }

    @Test func id3ZeroPaddedExplicitZeroRoundTrips() throws {
        let url = try copy("mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try TagLibMetadataManager.applyMetadataPatch(
            .init(numberText: .init(trackNumberText: "05/00")), to: url)
        #expect(try IndependentID3Probe.read(url).texts["TRCK"] == ["05/00"])
        let inventory = try TagLibMetadataManager.numberingInventory(at: url)
        #expect(inventory.track.number.nativeValue == 5)
        #expect(inventory.track.total.state == .absent)
        _ = try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.trackTotal: .integer(15)]), to: url)
        #expect(try IndependentID3Probe.read(url).texts["TRCK"] == ["5/15"])
    }

    // MARK: - Facade retirement and transaction controls

    @Test func convenienceRetiresBothSelectedGroupsAndPreservesOthers() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let trackA = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        let trackB = "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT"
        let discA = "----:com.apple.iTunes:AUDIOMATOR_DISCNUMBER_TEXT"
        let discB = "----:com.apple.iTunes:TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT"
        let foreign = "----:org.example:AUDIOMATOR_TRACKNUMBER_TEXT"
        let lower = "----:com.apple.iTunes:audiomator_tracknumber_text"
        let unknown = "----:com.apple.iTunes:UNKNOWN_MULTI"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 12),
            .init(key: "disk", type: "intPair", first: 1, second: 12),
            .init(key: trackA, type: "stringList", values: ["03/12"]),
            .init(key: trackB, type: "stringList", values: ["03/12"]),
            .init(key: discA, type: "stringList", values: ["01/12"]),
            .init(key: discB, type: "stringList", values: ["01/12"]),
            .init(key: foreign, type: "stringList", values: ["77/77"]),
            .init(key: lower, type: "stringList", values: ["03/12"]),
            .init(key: unknown, type: "stringList", values: ["one", "two"]),
        ]), to: url)
        let before = try native(url, "m4a")
        let result = try TagLibMetadataManager.writeTrackNumberText(
            "5/0", discNumberText: "1/0", to: url)
        let after = try native(url, "m4a")
        #expect(result.warnings.isEmpty)
        #expect(after.trackNumber == 5 && after.trackTotal == nil)
        #expect(after.discNumber == 1 && after.discTotal == nil)
        for identity in [trackA, trackB, discA, discB] {
            #expect(try IndependentMP4Probe.read(url).values[identity] == nil, Comment(rawValue: identity))
        }
        #expect(try IndependentMP4Probe.read(url).values[foreign] == [Data("77/77".utf8)])
        #expect(try IndependentMP4Probe.read(url).values[lower] == [Data("03/12".utf8)])
        #expect(try IndependentMP4Probe.read(url).values[unknown] == [Data("one".utf8), Data("two".utf8)])
        #expect(after.audio == before.audio)
    }

    @Test func convenienceTrackSelectionRetiresEvenWhenValueUnchanged() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let trackKey = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        let discKey = "----:com.apple.iTunes:AUDIOMATOR_DISCNUMBER_TEXT"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 12),
            .init(key: "disk", type: "intPair", first: 1, second: 12),
            .init(key: trackKey, type: "stringList", values: ["03/12"]),
            .init(key: discKey, type: "stringList", values: ["01/12"]),
        ]), to: url)
        _ = try TagLibMetadataManager.writeTrackNumberText("3/12", discNumberText: nil, to: url)
        let probe = try IndependentMP4Probe.read(url)
        #expect(probe.values[trackKey] == nil)
        #expect(probe.values[discKey] == [Data("01/12".utf8)])
        let after = try native(url, "m4a")
        #expect(after.trackNumber == 3 && after.trackTotal == 12)
        #expect(after.discNumber == 1 && after.discTotal == 12)
    }

    @Test func facadeAndPatchUseOneStage() throws {
        final class Stages: @unchecked Sendable {
            let lock = NSLock()
            var value = 0
            func add() { lock.lock(); value += 1; lock.unlock() }
        }
        for useFacade in [true, false] {
            let url = try copy("m4a")
            defer { try? FileManager.default.removeItem(at: url) }
            let stages = Stages()
            try MetadataFileTransaction.$willStageForTesting.withValue({ _ in stages.add() }) {
                if useFacade {
                    _ = try TagLibMetadataManager.writeTrackNumberText("5/12", discNumberText: nil, to: url)
                } else {
                    _ = try TagLibMetadataManager.applyMetadataPatch(
                        .init(numberText: .init(trackNumberText: "5/12")), to: url)
                }
            }
            #expect(stages.value == 1, Comment(rawValue: useFacade ? "facade" : "patch"))
        }
    }

    @Test func lowLevelBridgePreservesUnmodeledPrivateOwners() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let key = "----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT"
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: [
            .init(key: "trkn", type: "intPair", first: 3, second: 12),
            .init(key: key, type: "stringList", values: ["03/12"]),
        ]), to: url)
        try TagLibMetadataExtractor.writeTrackNumberText("5/12", discNumberText: nil, to: url)
        let after = try native(url, "m4a")
        #expect(after.trackNumber == 5 && after.trackTotal == 12)
        #expect(try IndependentMP4Probe.read(url).values[key] == [Data("03/12".utf8)])
    }

    @Test func facadeDoesNotCreatePrivateAtoms() throws {
        let url = try copy("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        _ = try TagLibMetadataManager.writeTrackNumberText("5/12", discNumberText: nil, to: url)
        let keys = try IndependentMP4Probe.read(url).values.keys
        #expect(!keys.contains { $0.uppercased().contains("AUDIOMATOR_") || $0.uppercased().contains("TAGLIBAUDIOMETADATA_") })
    }
}
