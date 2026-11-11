import Foundation
import Testing
import TagLibAudioMetadata

struct ASFNativeLifecycleTests {
    struct Entry: Sendable { let field: MetadataFieldKey; let native: String }
    static let cases: [Entry] = [
        .init(field: .year, native: "WM/Year"), .init(field: .standaloneDate, native: "DATE"),
        .init(field: .originalReleaseDate, native: "WM/OriginalReleaseYear"),
        .init(field: .contentGroup, native: "WM/ContentGroupDescription"),
        .init(field: .encodedBy, native: "WM/EncodedBy"), .init(field: .encoderSettings, native: "WM/EncodingSettings"),
        .init(field: .artists, native: "WM/ARTISTS")
    ]

    static func expectDateSeed(_ attributes: [IndependentASF.Attribute], mask: Int, target: String? = nil, targetExists: Bool = false) {
        for (index, key) in ["WM/Year", "DATE", "WM/OriginalReleaseYear"].enumerated() {
            let present = target == key ? targetExists : mask & (1 << index) != 0
            let value = target == key ? "2004" : MP4DateStateFixture.dates[index]
            #expect(attributes.filter { $0.name == key }.map(\.value) == (present ? [IndependentASF.text(value)] : []), "Seed mask=\(mask), \(key)")
        }
    }

    @Test(arguments: cases, SemanticLifecycleMatrixTests.Operation.allCases)
    func nativeAttributeLifecycle(_ item: Entry, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: .remove]), to: url)
            #expect(try IndependentASF.attributes(Data(contentsOf: url)).filter { $0.name == item.native }.isEmpty)
            if operation != .set {
                try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                    .init(key: item.native, type: "string", value: "2004")
                ]), to: url)
            }
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: [
                .init(key: "X-KEEP", type: "string", value: "  padded  ", language: 0, stream: 0)
            ]), to: url)
            let beforeBytes = try Data(contentsOf: url)
            let before = try IndependentASF.attributes(beforeBytes)
            let replacement = [MetadataFieldKey.year, .standaloneDate, .originalReleaseDate].contains(item.field) ? "2017-06-09" : "Replacement"
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: operation == .remove ? .remove : .text(replacement)]), to: url)
            let afterBytes = try Data(contentsOf: url)
            let after = try IndependentASF.attributes(afterBytes)
            #expect(after.filter { $0.name == item.native }.map(\.value) == (operation == .remove ? [] : [IndependentASF.text(replacement)]))
            #expect(after.filter { $0.name != item.native } == before.filter { $0.name != item.native })
            #expect(try IndependentASF.headerState(afterBytes).tail == IndependentASF.headerState(beforeBytes).tail)
        }
    }
    struct State: Sendable { let item: Entry; let mask: Int }
    static let states = cases.flatMap { item in (0..<8).map { State(item: item, mask: $0) } }

    @Test(.serialized, arguments: states, SemanticLifecycleMatrixTests.Operation.allCases)
    func allAttributeOwnersAcrossDatePresenceStates(_ state: State, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            let item = state.item
            let nativeDates = ["WM/Year", "DATE", "WM/OriginalReleaseYear"]
            let keys: Set<MetadataFieldKey> = [.year, .standaloneDate, .originalReleaseDate, item.field]
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: Dictionary(uniqueKeysWithValues: keys.map { ($0, MetadataPatchValue.remove) })), to: url)
            var attributes = nativeDates.enumerated().compactMap { index, key -> StructuredASFAttribute? in
                guard state.mask & (1 << index) != 0 else { return nil }
                return .init(key: key, type: "string", value: MP4DateStateFixture.dates[index])
            }
            attributes.append(.init(key: "X-KEEP", type: "string", value: "  untouched  "))
            // Target presence belongs to the lifecycle operation, independent
            // of the sibling date-state seed.
            attributes.removeAll { $0.key == item.native }
            if operation != .set { attributes.append(.init(key: item.native, type: "string", value: "2004")) }
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: attributes), to: url)
            let beforeBytes = try Data(contentsOf: url)
            let before = try IndependentASF.attributes(beforeBytes)
            Self.expectDateSeed(before, mask: state.mask, target: item.native, targetExists: operation != .set)
            let value = nativeDates.contains(item.native) ? "2017-06-09" : "Replacement"
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: operation == .remove ? .remove : .text(value)]), to: url)
            let afterBytes = try Data(contentsOf: url)
            let after = try IndependentASF.attributes(afterBytes)
            #expect(after.filter { $0.name == item.native }.map(\.value) == (operation == .remove ? [] : [IndependentASF.text(value)]))
            #expect(after.filter { $0.name != item.native } == before.filter { $0.name != item.native })
            #expect(try IndependentASF.headerState(afterBytes).tail == IndependentASF.headerState(beforeBytes).tail)
        }
    }

    @Test(.serialized, arguments: Array(0..<8), CrossContainerWriteSurfaceTests.surfaces)
    func asfPublicWriteSurfacesPreserveSparseDateOwners(_ mask: Int, _ surface: MP4WriteSurfaceStateTests.Surface) throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.year: .remove, .standaloneDate: .remove, .originalReleaseDate: .remove]), to: url)
            var attributes = [StructuredASFAttribute(key: "X-KEEP", type: "string", value: "Untouched")]
            for (index, key) in ["WM/Year", "DATE", "WM/OriginalReleaseYear"].enumerated() where mask & (1 << index) != 0 {
                attributes.append(.init(key: key, type: "string", value: MP4DateStateFixture.dates[index]))
            }
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: attributes), to: url)
            let beforeBytes = try Data(contentsOf: url)
            let before = try IndependentASF.attributes(beforeBytes)
            Self.expectDateSeed(before, mask: mask)
            let beforeContent = try IndependentASF.contentFields(beforeBytes)
            try CrossContainerWriteSurfaceTests.write(surface, at: url)
            let afterBytes = try Data(contentsOf: url)
            let after = try IndependentASF.attributes(afterBytes)
            let content = try IndependentASF.contentFields(afterBytes)
            #expect(after.filter { $0.name != "X-NEW" } == before.filter { $0.name != "X-NEW" }, "mask=\(mask), \(surface)")
            if surface == .customDelta {
                #expect(after.filter { $0.name == "X-NEW" }.map(\.value) == [IndependentASF.text("Changed")])
                #expect(content == beforeContent)
            } else {
                #expect(content[3] == "Changed")
                #expect(content.enumerated().filter { $0.offset != 3 }.map(\.element) == beforeContent.enumerated().filter { $0.offset != 3 }.map(\.element))
            }
            #expect(try IndependentASF.headerState(afterBytes).tail == IndependentASF.headerState(beforeBytes).tail)
        }
    }

    @Test(.serialized, arguments: Array(0..<8), SemanticLifecycleMatrixTests.Operation.allCases)
    func asfCustomFieldLifecycleOwnsOnlyItsCaseAliases(_ mask: Int, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        try HardeningFixture.withCopy("wma", name: "testAudioFile") { url in
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [.year: .remove, .standaloneDate: .remove, .originalReleaseDate: .remove]), to: url)
            var attributes = [StructuredASFAttribute(key: "X-KEEP", type: "string", value: "Untouched")]
            for (index, key) in ["WM/Year", "DATE", "WM/OriginalReleaseYear"].enumerated() where mask & (1 << index) != 0 {
                attributes.append(.init(key: key, type: "string", value: MP4DateStateFixture.dates[index]))
            }
            if operation != .set {
                attributes += [.init(key: "X-State", type: "string", value: "First"), .init(key: "x-state", type: "string", value: "Second")]
            }
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(asfAttributes: attributes), to: url)
            let beforeBytes = try Data(contentsOf: url)
            let before = try IndependentASF.attributes(beforeBytes)
            Self.expectDateSeed(before, mask: mask)
            try TagLibMetadataManager.applyMetadataPatch(.init(customFields: ["x-state": operation == .remove ? .remove : .text("Changed")]), to: url)
            let afterBytes = try Data(contentsOf: url)
            let after = try IndependentASF.attributes(afterBytes)
            #expect(after.filter { $0.name.uppercased() == "X-STATE" }.map(\.value) == (operation == .remove ? [] : [IndependentASF.text("Changed")]))
            #expect(after.filter { $0.name.uppercased() != "X-STATE" } == before.filter { $0.name.uppercased() != "X-STATE" })
            #expect(try IndependentASF.contentFields(afterBytes) == IndependentASF.contentFields(beforeBytes))
            #expect(try IndependentASF.headerState(afterBytes).tail == IndependentASF.headerState(beforeBytes).tail)
        }
    }

}
