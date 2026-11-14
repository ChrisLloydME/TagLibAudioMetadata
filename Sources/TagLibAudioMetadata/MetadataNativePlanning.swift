//
//  MetadataNativePlanning.swift
//  TagLibAudioMetadata
//
//  Translation from a semantic patch value to the exact native write target.
//  The registry owns the location; this planner only validates and encodes.
//

import Foundation
import CTagLibBridge
import CTagLibBridgeInternalAPI

extension TagLibMetadataManager {
    enum SemanticWriteMechanism: Sendable {
        case mp4Atom(key: String, type: String)
        case id3Frame(StructuredID3v2Frame)
        case nativeTextKey(key: String)
        case propertyMap(key: String)
    }

    struct SemanticPropertyStorage: Sendable {
        var mechanism: SemanticWriteMechanism
        /// Engine-level keys whose old spellings must be retired for this edit.
        var keysToRemove: Set<String>
        /// Native freeform/atom identities that are read-compatible aliases and
        /// must disappear when this exact field is explicitly edited.
        var nativeAliasesToRemove: Set<String>
    }

    /// Legacy read aliases that must not resurrect an old value after an
    /// explicit edit. They are removal-only; new writes always use the target.
    nonisolated static func mp4ReadAliasDescriptions(for field: MetadataFieldKey) -> [String] {
        switch field {
        case .publisher: ["LABEL", "PUBLISHER"]
        case .conductor: ["CONDUCTOR"]
        case .work: ["WORK"]
        case .mediaType: ["MEDIATYPE", "MEDIA", "MEDIA TYPE"]
        case .encodedBy: ["ENCODEDBY"]
        case .encoderSettings: ["ENCODERSETTINGS", "ENCODING"]
        case .movementNumber: ["MOVEMENTNUMBER"]
        case .movementCount: ["MOVEMENTCOUNT"]
        case .releaseDate: ["RELEASEDATE"]
        case .originalReleaseDate: ["ORIGINALDATE", "ORIGINAL YEAR"]
        case .standaloneDate: ["DATE"]
        case .itunesAlbumID: ["ITUNESALBUMID"]
        case .itunesArtistID: ["ITUNESARTISTID"]
        case .itunesCatalogID: ["ITUNESCATALOGID"]
        case .itunesGenreID: ["ITUNESGENREID"]
        case .itunesComposerID: ["ITUNESCOMPOSERID"]
        case .itunesCountryID: ["ITUNESCOUNTRYID"]
        case .itunesMediaType: ["ITUNESMEDIATYPE"]
        case .itunesPurchaseDate: ["ITUNESPURCHASEDATE"]
        case .artistType: ["ARTISTTYPE", "MUSICBRAINZ ARTIST TYPE"]
        case .releaseType: ["RELEASETYPE"]
        case .releaseStatus: ["RELEASESTATUS"]
        case .releaseCountry: ["RELEASECOUNTRY"]
        case .contentGroup: ["CONTENTGROUP"]
        case .grouping: ["GROUPING"]
        default: []
        }
    }

    nonisolated static func semanticStorage(
        for field: MetadataFieldKey,
        formatIdentifier identifier: String,
        formats: Set<MetadataFieldFormat>
    ) throws -> SemanticPropertyStorage {
        guard let schema = MetadataFieldRegistry.schema(for: field) else {
            throw MetadataPatchValidationError.unsupportedField(field)
        }
        let engineKey = schema.propertyMapKeys.first

        // ID3 comments/lyrics are qualified collections. MP4 instead owns
        // ordinary ©cmt/©lyr atoms and must use its native planner below.
        if identifier != "mp4", field == .comment || field == .lyrics {
            let key = field == .comment ? "COMMENT" : "LYRICS"
            return SemanticPropertyStorage(
                mechanism: .propertyMap(key: key),
                keysToRemove: Set(schema.propertyMapKeys.map { $0.uppercased() }),
                nativeAliasesToRemove: []
            )
        }

        if identifier == "mp4" {
            guard let target = schema.writeTarget(for: .mp4) else {
                throw MetadataPatchValidationError.unsupportedFieldForFormat(
                    field: field,
                    format: identifier
                )
            }
            let type: String = switch target.shape {
            case .integer:
                switch field {
                case .bpm, .rate: "int"
                case .itunesMediaType: "byte"
                default: "uint"
                }
            case .boolean:
                "bool"
            case .advisory:
                "uint"
            case .intPair:
                "intPair"
            default:
                "stringList"
            }
            let key: String
            switch target.storage {
            case .mp4Freeform:
                key = "----:com.apple.iTunes:\(target.nativeIdentity)"
            default:
                key = target.nativeIdentity
            }
            var aliases: Set<String> = []
            for description in mp4ReadAliasDescriptions(for: field) {
                let candidate = "----:com.apple.iTunes:\(description)"
                if candidate != key { aliases.insert(candidate) }
            }
            // Same-semantic engine/freeform spellings are read aliases, never
            // parallel write targets. YEAR and the independent DATE identity
            // share engine aliases but must never remove each other.
            for description in schema.propertyMapKeys where field != .year {
                // Engine ENCODING projects Encoder Settings, not Encoded By.
                if field == .encodedBy && description.uppercased() == "ENCODING" { continue }
                let candidate = "----:com.apple.iTunes:\(description.uppercased())"
                if candidate != key { aliases.insert(candidate) }
            }
            return SemanticPropertyStorage(
                mechanism: .mp4Atom(key: key, type: type),
                keysToRemove: Set(schema.propertyMapKeys.map { $0.uppercased() }),
                nativeAliasesToRemove: aliases
            )
        }

        let isXiph = ["flac", "ogg-vorbis", "ogg-opus", "ogg-flac", "ogg-speex"].contains(identifier)
        let isAPE = ["ape", "wavpack", "musepack"].contains(identifier)
        if isXiph || isAPE {
            let nativeFamily: MetadataNativeFamily = isXiph ? .vorbisComment : .apev2
            guard let target = schema.writeTarget(for: nativeFamily) else {
                throw MetadataPatchValidationError.unsupportedFieldForFormat(
                    field: field,
                    format: identifier
                )
            }
            var removals = Set(schema.propertyMapKeys.map { $0.uppercased() })
            // DATE is an engine-level YEAR alias, but on Xiph/APE it owns
            // independent native storage. Never retire another semantic slot.
            if field == .year { removals.remove("DATE") }
            for candidate in schema.nativeTargets where candidate.family == nativeFamily {
                removals.insert(candidate.nativeIdentity.uppercased())
            }
            return SemanticPropertyStorage(
                mechanism: .nativeTextKey(key: target.nativeIdentity),
                keysToRemove: removals,
                nativeAliasesToRemove: []
            )
        }

        if identifier == "asf" {
            guard let target = schema.writeTarget(for: .asf) else {
                throw MetadataPatchValidationError.unsupportedFieldForFormat(
                    field: field,
                    format: identifier
                )
            }
            // ASF needs exact native writes for the independent date,
            // content-group, artists, and peak attributes. Common title/artist/
            // album fields use the engine PropertyMap so TagLib also retires
            // stale lower-case aliases.
            let nativeFields: Set<MetadataFieldKey> = [
                .year, .standaloneDate, .originalReleaseDate,
                .contentGroup, .artists, .encodedBy, .encoderSettings, .replayGainTrackPeak, .replayGainAlbumPeak,
            ]
            var removals = Set(schema.propertyMapKeys.map { $0.uppercased() })
            if nativeFields.contains(field) {
                if field == .year {
                    // YEAR and the independent DATE attribute share historical
                    // aliases but must not remove each other.
                    removals = ["YEAR"]
                }
                for candidate in schema.nativeTargets where candidate.family == .asf {
                    removals.insert(candidate.nativeIdentity.uppercased())
                }
                return SemanticPropertyStorage(
                    mechanism: .nativeTextKey(key: target.nativeIdentity),
                    keysToRemove: removals,
                    nativeAliasesToRemove: []
                )
            }
            let asfKey: String = switch field {
            case .mediaType: "MEDIA"
            default: engineKey ?? schema.propertyMapKeys.first ?? target.nativeIdentity
            }
            return SemanticPropertyStorage(
                mechanism: .propertyMap(key: asfKey),
                keysToRemove: removals,
                nativeAliasesToRemove: []
            )
        }

        if formats.contains(.id3v2) {
            // UFID's native identity is its owner, not a four-byte frame ID.
            // TagLib's canonical property codec owns that qualified identifier.
            if schema.writeTarget(for: .id3v24)?.storage == .identifierFrame,
               let engineKey {
                return SemanticPropertyStorage(
                    mechanism: .propertyMap(key: engineKey),
                    keysToRemove: Set(schema.propertyMapKeys.map { $0.uppercased() }),
                    nativeAliasesToRemove: []
                )
            }
            guard let frame = id3Frame(for: field, schema: schema) else {
                throw MetadataPatchValidationError.unsupportedFieldForFormat(
                    field: field,
                    format: identifier
                )
            }
            return SemanticPropertyStorage(
                mechanism: .id3Frame(frame),
                keysToRemove: Set(schema.propertyMapKeys.map { $0.uppercased() }),
                nativeAliasesToRemove: []
            )
        }

        guard let engineKey, let target = schema.writeTarget(for: family(for: formats)) else {
            throw MetadataPatchValidationError.unsupportedFieldForFormat(
                field: field,
                format: identifier
            )
        }
        var removals = Set(schema.propertyMapKeys.map { $0.uppercased() })
        // Xiph/APE read aliases are exact native text keys. Retire the same
        // semantic spellings on an explicit edit, never a lookalike.
        for candidate in schema.nativeTargets where candidate.family == target.family {
            removals.insert(candidate.nativeIdentity.uppercased())
        }
        return SemanticPropertyStorage(
            mechanism: .propertyMap(key: engineKey),
            keysToRemove: removals,
            nativeAliasesToRemove: []
        )
    }

    nonisolated static func family(for formats: Set<MetadataFieldFormat>) -> MetadataNativeFamily {
        if formats.contains(.xiph) { return .vorbisComment }
        if formats.contains(.ape) { return .apev2 }
        if formats.contains(.asf) { return .asf }
        if formats.contains(.riffInfo) { return .riffInfo }
        if formats.contains(.matroska) { return .matroska }
        return .id3v24
    }

    nonisolated static func id3Frame(
        for field: MetadataFieldKey,
        schema: MetadataFieldSchema
    ) -> StructuredID3v2Frame? {
        // Dates are version-specific and must never be smuggled across
        // versions. The bridge chooses the v2.3/v2.4 identity at write time.
        switch field {
        case .year:
            return StructuredID3v2Frame(
                frameID: "TDRC", type: "versionedText",
                v23ID: "TYER", v24ID: "TDRC"
            )
        case .standaloneDate:
            return StructuredID3v2Frame(
                frameID: "TDAT", type: "versionedText",
                v23ID: "TDAT", v24Description: "DATE"
            )
        case .originalReleaseDate:
            return StructuredID3v2Frame(
                frameID: "TDOR", type: "versionedText",
                v23ID: "TORY", v24ID: "TDOR"
            )
        case .releaseDate:
            return StructuredID3v2Frame(
                frameID: "TDRL", type: "versionedText",
                v23ID: "TDRL", v24ID: "TDRL"
            )
        default:
            break
        }
        guard let target = schema.writeTarget(for: .id3v24) ?? schema.writeTarget(for: .id3v23) else {
            return nil
        }
        switch target.storage {
        case .userTextFrame:
            return StructuredID3v2Frame(
                frameID: "TXXX", type: "userText",
                description: target.nativeIdentity
            )
        case .extensionFrame:
            return StructuredID3v2Frame(frameID: target.nativeIdentity, type: "text")
        default:
            return StructuredID3v2Frame(frameID: target.nativeIdentity, type: "text")
        }
    }

    nonisolated static func structuredMP4Atom(
        for mechanism: SemanticWriteMechanism,
        value: MetadataPatchValue
    ) -> StructuredMP4Atom? {
        guard case .mp4Atom(let key, let type) = mechanism else { return nil }
        let values = value.propertyMapValues
        switch type {
        case "uint":
            let integer = Int(values.first ?? "") ?? 0
            return StructuredMP4Atom(
                key: key,
                type: "uint",
                value: String(integer),
                remove: values.isEmpty
            )
        case "byte":
            let integer = Int(values.first ?? "") ?? 0
            return StructuredMP4Atom(
                key: key,
                type: "byte",
                value: String(integer),
                remove: values.isEmpty
            )
        case "int":
            let integer = Int(values.first ?? "") ?? 0
            return StructuredMP4Atom(
                key: key,
                type: "int",
                value: String(integer),
                remove: values.isEmpty
            )
        case "bool":
            let flag = values.first.map { $0 == "1" || $0.lowercased() == "true" } ?? false
            return StructuredMP4Atom(
                key: key,
                type: "bool",
                value: flag ? "1" : "0",
                remove: values.isEmpty
            )
        default:
            return StructuredMP4Atom(
                key: key,
                type: "stringList",
                values: values,
                remove: values.isEmpty
            )
        }
    }
}
