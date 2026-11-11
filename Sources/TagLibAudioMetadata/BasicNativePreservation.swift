import Foundation
import CTagLibBridge
import CTagLibBridgeInternalAPI

extension TagLibMetadataManager {
    nonisolated static let basicDateFields: [MetadataFieldKey] = [.year, .standaloneDate, .releaseDate, .originalReleaseDate]

    /// Basic is a scalar projection. Equal scalar intent cannot authorize loss
    /// of native arrays, malformed text, duplicates or absent owners.
    nonisolated static func restoreUneditedBasicNativeValues(
        requested: BasicMetadata, before: MetadataSnapshot, at url: URL
    ) throws {
        let identifier = capability(forExtension: url.pathExtension)?.identifier ?? ""
        let textFamily: MetadataNativeFamily? = ["flac", "ogg-vorbis", "ogg-opus", "ogg-flac", "ogg-speex"].contains(identifier)
            ? .vorbisComment : (["ape", "wavpack", "musepack"].contains(identifier) ? .apev2 : nil)
        var atoms: [StructuredMP4Atom] = []
        var frames: [StructuredID3v2Frame] = []
        var absentFrames: [StructuredID3v2Frame] = []
        var textValues: [String: [String]] = [:]
        var textRemovals = Set<String>()
        // The low-level MP4 replacement writer canonicalizes aliases. An
        // unrelated Basic edit does not authorize that migration.
        let pairFields: Set<MetadataFieldKey> = [.track, .trackTotal, .disc, .discTotal]
        let fields = identifier == "mp4"
            ? BasicMetadata.editableFieldKeys.filter { $0 != .date && !pairFields.contains($0) }
            : basicDateFields
        for field in fields where basicProjectionValue(for: field, metadata: requested) == basicProjectionValue(for: field, metadata: before.basic) {
            guard basicProjectionValue(for: field, metadata: requested) != nil,
                  let schema = MetadataFieldRegistry.schema(for: field) else { continue }
            if identifier == "mp4" {
                var keys = Set(schema.targets(for: .mp4).map { $0.storage == .mp4Freeform ? "----:com.apple.iTunes:" + $0.nativeIdentity : $0.nativeIdentity })
                    .union(mp4ReadAliasDescriptions(for: field).map { "----:com.apple.iTunes:" + $0 })
                let originalKeys = before.structured.mp4Atoms.compactMap { atom in
                    keys.contains(where: { $0.caseInsensitiveCompare(atom.key) == .orderedSame }) ? atom.key : nil
                }
                keys.formUnion(originalKeys)
                for key in keys {
                    let originals = before.structured.mp4Atoms.filter { $0.key == key }
                    atoms += originals.isEmpty ? [.init(key: key, type: "stringList", remove: true)] : originals
                }
            } else if let family = textFamily, let target = schema.writeTarget(for: family) {
                var keys: Set<String> = [target.nativeIdentity.uppercased()]
                if field == .originalReleaseDate { keys.insert("ORIGINAL YEAR") }
                let originals = before.structured.properties.filter { keys.contains($0.key.uppercased()) }
                textRemovals.formUnion(keys)
                for entry in originals { textValues[entry.key] = entry.values }
            } else if capability(forExtension: url.pathExtension)?.metadataFieldFormats.contains(.id3v2) == true {
                let targets = schema.targets(for: .id3v23) + schema.targets(for: .id3v24)
                let originals = before.structured.id3v2Frames.filter { frame in
                    targets.contains { $0.storage == .userTextFrame ? frame.frameID == "TXXX" && frame.description == $0.nativeIdentity : frame.frameID == $0.nativeIdentity }
                }
                for target in Set(targets) {
                    let id = target.storage == .userTextFrame ? "TXXX" : target.nativeIdentity
                    let description = target.storage == .userTextFrame ? target.nativeIdentity : nil
                    if !originals.contains(where: { $0.frameID == id && $0.description == description }) {
                        let removal = StructuredID3v2Frame(frameID: id, type: description == nil ? "text" : "userText", description: description)
                        frames.append(removal)
                        absentFrames.append(removal)
                    }
                }
                frames += originals
            }
        }
        if !textRemovals.isEmpty {
            try TagLibMetadataExtractor.applyNativeTextKeyValuesInPlace(textValues, removingKeys: Array(textRemovals), to: url)
        }
        if !atoms.isEmpty || !frames.isEmpty {
            let preservation = StructuredMetadata(id3v2Frames: frames, mp4Atoms: atoms)
            try TagLibMetadataExtractor.writeStructuredMetadataInPlace(bridgePayload(from: preservation, includeProperties: false, replacingCollections: [], riffPolicy: .preserveInfo), to: url)
            let expected = StructuredMetadata(id3v2Frames: frames.filter { frame in !absentFrames.contains(frame) }, mp4Atoms: atoms)
            let verification = structuredWriteVerification(expected: expected, includeProperties: false, replacingCollections: [], for: url)
            try throwOnVerificationFailures(verification.failures)
            let after = try readStructuredMetadataResult(from: url)
            for removal in absentFrames where after.id3v2Frames.contains(where: { $0.frameID == removal.frameID && $0.description == removal.description }) {
                throw TagLibManagerError.verificationFailed(["Unexpected native date frame \(removal.frameID) after Basic preservation."])
            }
        }
        if !textRemovals.isEmpty {
            let after = try readStructuredMetadataResult(from: url)
            for key in textRemovals {
                let expected = textValues.filter { $0.key.caseInsensitiveCompare(key) == .orderedSame }.flatMap(\.value)
                let actual = after.properties.filter { $0.key.caseInsensitiveCompare(key) == .orderedSame }.flatMap(\.values)
                guard actual == expected else {
                    throw TagLibManagerError.verificationFailed(["Native field \(key) changed during Basic preservation."])
                }
            }
        }
    }
}
