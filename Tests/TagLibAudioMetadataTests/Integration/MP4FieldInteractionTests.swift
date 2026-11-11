import Foundation
import Testing
import TagLibAudioMetadata

/// Complements isolated lifecycle tests with state on sibling owners. These
/// expectations deliberately use the literal test manifest, never the registry.
struct MP4FieldInteractionTests {
    struct Entry: Sendable {
        let field: SemanticLifecycleMatrixTests.Case
        let state: MP4DateStateFixture.State
    }
    static let dateCases = SemanticLifecycleMatrixTests.cases.flatMap { field in
        MP4DateStateFixture.states.filter { state in
            guard let index = MP4DateStateFixture.owners.firstIndex(of: field.atom) else { return true }
            // The lifecycle operation supplies the target's before-state.
            // Enumerate every other date bit once rather than duplicate cases.
            return state.mask & (1 << index) == 0
        }.map { Entry(field: field, state: $0) }
    }

    @Test func interactionManifestIncludesEveryNativeField() {
        #expect(SemanticLifecycleMatrixTests.cases.count == 88)
        #expect(Self.dateCases.count == 1376)
        #expect(Set(Self.dateCases.map { $0.field.field }) == Set(SemanticLifecycleMatrixTests.cases.map(\.field)))
        for field in SemanticLifecycleMatrixTests.cases {
            let rows = Self.dateCases.filter { $0.field.field == field.field }
            #expect(rows.count == (MP4DateStateFixture.owners.contains(field.atom) ? 8 : 16))
        }
    }

    static func atom(_ item: SemanticLifecycleMatrixTests.Case, remove: Bool = false) throws -> StructuredMP4Atom {
        switch item.value(false) {
        case .text(let value): return .init(key: item.atom, type: "stringList", values: [value], remove: remove)
        case .integer(let value): return .init(key: item.atom, type: "uint", value: String(value), remove: remove)
        case .boolean(let value): return .init(key: item.atom, type: "bool", value: value ? "1" : "0", remove: remove)
        default: throw CocoaError(.coderInvalidValue)
        }
    }

    @Test(.serialized, arguments: dateCases, SemanticLifecycleMatrixTests.Operation.allCases)
    func everyFieldPreservesAllSiblingDateStates(_ entry: Entry, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            try MP4DateStateFixture.seed(entry.state, at: url, extra: [try Self.atom(entry.field, remove: operation == .set)])
            let before = try IndependentMP4Probe.read(url)
            try before.expectValue(operation == .set ? .remove : entry.field.value(false), at: entry.field.atom)
            let expected: MetadataPatchValue = operation == .remove ? .remove : entry.field.value(true)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [entry.field.field: expected]), to: url)
            let after = try IndependentMP4Probe.read(url)
            try after.expectValue(expected, at: entry.field.atom)
            #expect(after.items.filter { $0.key != entry.field.atom } == before.items.filter { $0.key != entry.field.atom }, "\(entry.field.field), \(entry.state.label), \(operation)")
            MP4DateStateFixture.expectDatesAndPayload(before, after, excluding: entry.field.atom)
        }
    }

    @Test(.serialized, arguments: SemanticLifecycleMatrixTests.cases, SemanticLifecycleMatrixTests.Operation.allCases)
    func everyFieldPreservesAllOtherPresentOwners(_ item: SemanticLifecycleMatrixTests.Case, _ operation: SemanticLifecycleMatrixTests.Operation) throws {
        try HardeningFixture.withCopy("m4a", name: "testAudioFile") { url in
            let seeds = try SemanticLifecycleMatrixTests.cases.map { try Self.atom($0, remove: $0.field == item.field && operation == .set) }
            try TagLibMetadataManager.writeStructuredMetadataWithVerification(.init(mp4Atoms: seeds), to: url)
            let before = try IndependentMP4Probe.read(url)
            for seed in SemanticLifecycleMatrixTests.cases {
                try before.expectValue(seed.field == item.field && operation == .set ? .remove : seed.value(false), at: seed.atom)
            }
            let expected: MetadataPatchValue = operation == .remove ? .remove : item.value(true)
            try TagLibMetadataManager.applyMetadataPatch(.init(fields: [item.field: expected]), to: url)
            let after = try IndependentMP4Probe.read(url)
            try after.expectValue(expected, at: item.atom)
            #expect(after.items.filter { $0.key != item.atom } == before.items.filter { $0.key != item.atom }, "\(item.field) / \(operation)")
            #expect(after.audio == before.audio)
        }
    }
}
