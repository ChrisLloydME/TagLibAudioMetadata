import Foundation
import Testing
import TagLibAudioMetadata

struct IndependentAcceptanceProbes {
    func fixture(_ seed: [StructuredMP4Atom]) throws -> URL {
        let source = try #require(Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a", subdirectory: "Audio") ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "m4a"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        try FileManager.default.copyItem(at: source, to: url)
        try TagLibMetadataManager.writeStructuredMetadataWithVerification(StructuredMetadata(mp4Atoms: seed), to: url)
        return url
    }
    @Test func nativeAndAliasConflictMustBeAmbiguous() throws {
        let url = try fixture([.init(key:"trkn",type:"intPair",first:3,second:12), .init(key:"----:com.apple.iTunes:TRACKTOTAL",type:"stringList",values:["99"])])
        defer { try? FileManager.default.removeItem(at:url) }
        let inv = try TagLibMetadataManager.numberingInventory(at:url)
        #expect(inv.track.total.state == .ambiguous)
        let before = try Data(contentsOf:url)
        #expect(throws: (any Error).self) { try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields:[.track:.integer(5)]),to:url) }
        #expect(try Data(contentsOf:url) == before)
    }
    @Test func trackCleanupMustPreserveDiscAliases() throws {
        let url = try fixture([.init(key:"trkn",type:"intPair",first:3,second:0), .init(key:"----:com.apple.iTunes:TRACKTOTAL",type:"stringList",values:["12"]), .init(key:"disk",type:"intPair",first:1,second:2), .init(key:"----:com.apple.iTunes:DISCTOTAL",type:"stringList",values:["99"])])
        defer { try? FileManager.default.removeItem(at:url) }
        let plan = try TagLibMetadataManager.planNumberNormalization(at:url,policy:.useLegacy,groups:[.track])
        #expect(!plan.removals.contains("----:com.apple.iTunes:DISCTOTAL"))
        try TagLibMetadataManager.applyNumberNormalization(plan,to:url)
        let atoms = try TagLibMetadataManager.readStructuredMetadataResult(from:url).mp4Atoms
        #expect(atoms.first { $0.freeformDescription == "DISCTOTAL" }?.values == ["99"])
    }
    @Test func discReplacementMustReplaceDiscNotTrack() throws {
        let url = try fixture([.init(key:"trkn",type:"intPair",first:3,second:12), .init(key:"disk",type:"intPair",first:1,second:2)])
        defer { try? FileManager.default.removeItem(at:url) }
        let plan = try TagLibMetadataManager.planNumberNormalization(at:url,policy:.replace(number:4,total:7),groups:[.disc])
        try TagLibMetadataManager.applyNumberNormalization(plan,to:url)
        let result = try TagLibMetadataManager.readMetadataResult(from:url)
        #expect(result.disc == 4 && result.discTotal == 7)
        #expect(result.track == 3 && result.trackTotal == 12)
    }
    @Test func stalePlanMustNotBeRevalidatedByNewVersion() throws {
        let url = try fixture([.init(key:"trkn",type:"intPair",first:3,second:12)])
        defer { try? FileManager.default.removeItem(at:url) }
        let plan = try TagLibMetadataManager.planNumberNormalization(at:url,policy:.replace(number:4,total:15),groups:[.track])
        try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields:[.trackTotal:.integer(20)]),to:url)
        let version = try TagLibMetadataManager.fileVersion(at:url)
        let before = try Data(contentsOf:url)
        #expect(throws: (any Error).self) { try TagLibMetadataManager.applyNumberNormalization(plan,to:url,expectedVersion:version) }
        #expect(try Data(contentsOf:url) == before)
    }
    @Test func privateOnlyNumbersMustBeRecoverable() throws {
        let url = try fixture([.init(key:"trkn",type:"intPair",remove:true), .init(key:"----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT",type:"stringList",values:["03/12"])])
        defer { try? FileManager.default.removeItem(at:url) }
        let inv = try TagLibMetadataManager.numberingInventory(at:url)
        #expect(inv.track.privateTexts.count == 1)
        let plan = try TagLibMetadataManager.planNumberNormalization(at:url,policy:.useLegacy,groups:[.track])
        #expect(plan.trackNumber == 3 && plan.trackTotal == 12)
    }
    @Test func unresolvedDiscMustNotBlockTrackEdit() throws {
        let url = try fixture([.init(key:"trkn",type:"intPair",first:3,second:12), .init(key:"disk",type:"intPair",remove:true), .init(key:"----:com.apple.iTunes:DISCTOTAL",type:"stringList",values:["2"]), .init(key:"----:com.apple.iTunes:TOTALDISCS",type:"stringList",values:["9"])])
        defer { try? FileManager.default.removeItem(at:url) }
        #expect(try TagLibMetadataManager.numberingInventory(at:url).disc.total.state == .ambiguous)
        try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields:[.track:.integer(5)]),to:url)
        #expect(try TagLibMetadataManager.readMetadataResult(from:url).track == 5)
    }
    @Test func mp4RetainedTotalMustAllowNumberRemoval() throws {
        let url = try fixture([.init(key:"trkn",type:"intPair",first:3,second:12)])
        defer { try? FileManager.default.removeItem(at:url) }
        try TagLibMetadataManager.applyMetadataPatch(MetadataPatch(fields:[.track:.remove]),to:url)
        let atoms = try TagLibMetadataManager.readStructuredMetadataResult(from:url).mp4Atoms
        #expect(atoms.first { $0.key == "trkn" }?.first == 0)
        #expect(atoms.first { $0.key == "trkn" }?.second == 12)
    }

    @Test func xiphNativeCleanupMustNotEraseOrdinaryTotals() throws {
        let source = try #require(Bundle.module.url(forResource: "testAudioFile", withExtension: "flac", subdirectory: "Audio") ?? Bundle.module.url(forResource: "testAudioFile", withExtension: "flac"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("flac")
        try FileManager.default.copyItem(at: source, to: url)
        defer { try? FileManager.default.removeItem(at:url) }
        try TagLibMetadataManager.applyRawMetadataPatch(RawMetadataPatch(valuesToSet:["TRACKNUMBER":["3"],"TRACKTOTAL":["12"],"DISCNUMBER":["1"],"DISCTOTAL":["2"]]),to:url)
        let inv = try TagLibMetadataManager.numberingInventory(at:url)
        #expect(inv.track.number.state == .native)
        let plan = try TagLibMetadataManager.planNumberNormalization(at:url,policy:.useNative,groups:[.track])
        try TagLibMetadataManager.applyNumberNormalization(plan,to:url)
        let result = try TagLibMetadataManager.readMetadataResult(from:url)
        #expect(result.track == 3 && result.trackTotal == 12, Comment(rawValue: "Actual track pair: \(result.track)/\(result.trackTotal)"))
        #expect(result.disc == 1 && result.discTotal == 2, Comment(rawValue: "Actual disc pair: \(result.disc)/\(result.discTotal)"))
    }

}
