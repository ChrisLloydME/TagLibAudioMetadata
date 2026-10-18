//
//  TagLibMetadataManager+Write.swift
//  TagLibAudioMetadata
//

import Foundation
import CTagLibBridge
import CTagLibBridgeInternalAPI

extension TagLibMetadataManager {
    nonisolated private static func validateDateStorageCompatibility(
        year: String?,
        releaseDate: String?,
        for url: URL
    ) throws {
        guard Self.capability(forExtension: url.pathExtension)?
            .metadataFieldFormats.contains(MetadataFieldFormat.mp4) == true else {
            return
        }

        let normalizedYear = normalizedTrimmed(year)
        guard !normalizedYear.isEmpty else { return }
        let normalizedReleaseDate = normalizedTrimmed(releaseDate)
        let projectedReleaseYear = String(normalizedReleaseDate.prefix(4))
        guard !normalizedReleaseDate.isEmpty, normalizedYear == projectedReleaseYear else {
            throw MetadataPatchValidationError.unsupportedFieldForFormat(field: .date, format: "mp4")
        }
    }

    nonisolated static func validateBasicMetadataForWrite(_ metadata: BasicMetadata) throws {
        for (key, value) in metadata.customFields {
            if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw MetadataValidationError.invalidCustomFieldKey(key)
            }
            if key.contains("\0") {
                throw MetadataValidationError.embeddedNull(location: "customFields key")
            }
            if value.contains("\0") {
                throw MetadataValidationError.embeddedNull(location: "customFields[\(key)]")
            }
            if MetadataFieldRegistry.schema(forHighLevelCustomKey: key) != nil {
                throw MetadataValidationError.knownFieldRequiresRawAPI(key)
            }
        }
    }

    nonisolated static func basicProjectionValue(
        for field: MetadataFieldKey,
        metadata: BasicMetadata
    ) -> String? {
        switch field {
        case .title: metadata.title
        case .artist: metadata.artist
        case .album: metadata.album
        case .albumArtist: metadata.albumArtist
        case .date: metadata.year
        case .releaseDate: metadata.releaseDate
        case .originalReleaseDate: metadata.originalReleaseDate
        case .track: String(metadata.track)
        case .trackTotal: String(metadata.trackTotal)
        case .disc: String(metadata.disc)
        case .discTotal: String(metadata.discTotal)
        case .lyrics: metadata.lyrics
        case .comment: metadata.comment
        case .genre: metadata.genre
        case .composer: metadata.composer
        case .conductor: metadata.conductor
        case .remixer: metadata.remixer
        case .producer: metadata.producer
        case .engineer: metadata.engineer
        case .lyricist: metadata.lyricist
        case .publisher: metadata.publisher
        case .copyright: metadata.copyright
        case .encodedBy: metadata.encodedBy
        case .encoderSettings: metadata.encoderSettings
        case .isrc: metadata.isrc
        case .barcode: metadata.barcode
        case .catalogNumber: metadata.catalogNumber
        case .asin: metadata.asin
        case .releaseType: metadata.releaseType
        case .releaseStatus: metadata.releaseStatus
        case .releaseCountry: metadata.releaseCountry
        case .mediaType: metadata.mediaType
        case .work: metadata.work
        case .movement: metadata.movement
        case .movementNumber: String(metadata.movementNumber)
        case .movementCount: String(metadata.movementCount)
        case .discSubtitle: metadata.discSubtitle
        case .subtitle: metadata.subtitle
        case .grouping: metadata.grouping
        case .mood: metadata.mood
        case .language: metadata.language
        case .musicalKey: metadata.musicalKey
        case .bpm: String(metadata.bpm)
        case .compilation: metadata.isCompilation ? "1" : "0"
        case .sortTitle: metadata.sortTitle
        case .sortArtist: metadata.sortArtist
        case .sortAlbum: metadata.sortAlbum
        case .sortAlbumArtist: metadata.sortAlbumArtist
        case .sortComposer: metadata.sortComposer
        case .musicBrainzArtistID: metadata.musicBrainzArtistID
        case .musicBrainzAlbumID: metadata.musicBrainzAlbumID
        case .musicBrainzAlbumArtistID: metadata.musicBrainzAlbumArtistID
        case .musicBrainzTrackID: metadata.musicBrainzTrackID
        case .musicBrainzReleaseGroupID: metadata.musicBrainzReleaseGroupID
        case .musicBrainzReleaseTrackID: metadata.musicBrainzReleaseTrackID
        case .musicBrainzWorkID: metadata.musicBrainzWorkID
        case .acoustID: metadata.acoustID
        case .acoustIDFingerprint: metadata.acoustIDFingerprint
        case .musicIPPUID: metadata.musicIPPUID
        case .replayGainTrackGain: metadata.replayGainTrack
        case .replayGainAlbumGain: metadata.replayGainAlbum
        case .itunesAlbumID: metadata.itunesAlbumID
        case .itunesArtistID: metadata.itunesArtistID
        case .itunesCatalogID: metadata.itunesCatalogID
        case .itunesGenreID: metadata.itunesGenreID
        case .itunesMediaType: metadata.itunesMediaType
        case .itunesPurchaseDate: metadata.itunesPurchaseDate
        case .itunesNorm: metadata.itunesNorm
        case .itunesSMPB: metadata.itunesSMPB
        case .originalAlbum: metadata.originalAlbum
        case .originalArtist: metadata.originalArtist
        case .artistType: metadata.artistType
        case .artwork, .performer, .involvedPeople, .musicianCredits,
             .explicitContent, .trackerName, .custom:
            nil
        }
    }

    /// Raw PropertyMap entries that should be restored after a Basic write
    /// because the corresponding Basic projection was not intentionally edited.
    nonisolated static func preservedStandardValues(
        desired: BasicMetadata,
        current: BasicMetadata,
        rawDump: RawMetadataDump
    ) -> (values: [String: [String]], aliases: Set<String>) {
        var values: [String: [String]] = [:]
        var aliases: Set<String> = []
        let fieldsHandledByTypedWriters: Set<MetadataFieldKey> = [
            .track, .trackTotal, .disc, .discTotal,
            .movementNumber, .movementCount, .bpm, .compilation,
        ]

        for entry in rawDump.properties where !entry.values.isEmpty {
            guard let schema = MetadataFieldRegistry.schema(forPropertyMapKey: entry.key) else {
                continue
            }
            guard schema.key != .artwork && schema.key != .custom && schema.key != .explicitContent else {
                continue
            }

            let shouldPreserve: Bool
            if !BasicMetadata.editableFieldKeys.contains(schema.key) {
                shouldPreserve = true
            } else if fieldsHandledByTypedWriters.contains(schema.key) {
                shouldPreserve = false
            } else if schema.key == .date {
                // The full recording date is carried through the Basic writer
                // above; reapplying the raw DATE would be redundant and can be
                // overridden by a lower-fidelity surface such as ID3v1.
                shouldPreserve = false
            } else if let desiredValue = basicProjectionValue(for: schema.key, metadata: desired),
                      let currentValue = basicProjectionValue(for: schema.key, metadata: current) {
                shouldPreserve = desiredValue == currentValue
            } else {
                shouldPreserve = false
            }

            guard shouldPreserve else { continue }
            values[entry.key] = entry.values
            aliases.formUnion(schema.propertyMapKeys)
        }

        return (values, aliases)
    }

    nonisolated static func preservedRawValueWarnings(
        _ preservedValues: [String: [String]],
        for url: URL
    ) -> [String] {
        guard !preservedValues.isEmpty,
              let dump = try? rawMetadataResult(from: url) else {
            return []
        }
        let actual = rawPropertiesLookup(dump)
        return preservedValues.keys.sorted().compactMap { key in
            let expected = preservedValues[key] ?? []
            let observed = actual[key.uppercased()] ?? []
            return observed == expected
                ? nil
                : "Preserved metadata field \(key) differs after save (expected \(expected), got \(observed))."
        }
    }

    /// Low-level bridge entry point. Its parameter type comes from the
    /// `CTagLibBridge` module, so clients must import that module (or use the
    /// `TagLibAudioMetadataLowLevel` product) to name it. Prefer
    /// `replaceBasicMetadata` or `updateBasicMetadata` in facade-only clients.
    public nonisolated static func writeTagMetadata(
        _ metadata: TagLibAudioMetadata,
        to url: URL,
        verification: MetadataWriteVerificationContext = .none,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }
        try validateDateStorageCompatibility(
            year: metadata.year,
            releaseDate: metadata.releaseDate,
            for: url
        )

        return try withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
            try TagLibMetadataExtractor.writeMetadataInPlace(metadata, to: mutationURL)
            let warnings = metadataWriteWarnings(for: mutationURL, verification: verification)
            try throwOnVerificationFailures(warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }

    @available(*, deprecated, message: "Verification mismatches always throw. Omit failurePolicy.")
    public nonisolated static func writeTagMetadata(
        _ metadata: TagLibAudioMetadata,
        to url: URL,
        verification: MetadataWriteVerificationContext = .none,
        expectedVersion: MetadataFileVersion? = nil,
        failurePolicy: VerificationFailurePolicy
    ) throws -> MetadataWriteResult {
        try writeTagMetadata(
            metadata,
            to: url,
            verification: verification,
            expectedVersion: expectedVersion
        )
    }

    /// Intentionally writes formatted track/disc number text. Unlike an ordinary
    /// Basic numeric edit, the supplied text is the authoritative input.
    @discardableResult
    public nonisolated static func writeTrackNumberText(
        _ trackNumberText: String,
        discNumberText: String?,
        to url: URL,
        verifyAfterWrite: Bool = true,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
            let beforeWrite = verifyAfterWrite ? try readMetadataResult(from: mutationURL) : nil
            try TagLibMetadataExtractor.writeTrackNumberTextInPlace(
                trackNumberText,
                discNumberText: discNumberText,
                to: mutationURL
            )

            if !verifyAfterWrite {
                return MetadataWriteResult(warnings: [])
            }

            let expectedTrackPair = parseNumberPair(trackNumberText)
            let expectedDiscPair = parseNumberPair(normalizedTrimmed(discNumberText))
            let verifiesExactTrackText = expectedTrackPair.total > 0 || (beforeWrite?.trackTotal ?? 0) == 0
            let verifiesExactDiscText = expectedDiscPair.total > 0 || (beforeWrite?.discTotal ?? 0) == 0

            let warnings = metadataWriteWarnings(
                for: mutationURL,
                verification: MetadataWriteVerificationContext(
                    expectedTrackNumber: expectedTrackPair.number > 0 ? expectedTrackPair.number : nil,
                    expectedTrackTotal: expectedTrackPair.total > 0 ? expectedTrackPair.total : nil,
                    expectedTrackNumberText: verifiesExactTrackText ? trackNumberText : nil,
                    expectedDiscNumber: expectedDiscPair.number > 0 ? expectedDiscPair.number : nil,
                    expectedDiscTotal: expectedDiscPair.total > 0 ? expectedDiscPair.total : nil,
                    expectedDiscNumberText: verifiesExactDiscText ? discNumberText : nil,
                    expectedExplicitContent: nil,
                    artworkExpectation: .skip,
                    customFieldKeys: []
                )
            )
            try throwOnVerificationFailures(warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }

    @available(*, deprecated, message: "Verification mismatches always throw. Omit failurePolicy.")
    @discardableResult
    public nonisolated static func writeTrackNumberText(
        _ trackNumberText: String,
        discNumberText: String?,
        to url: URL,
        verifyAfterWrite: Bool = true,
        failurePolicy: VerificationFailurePolicy,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        try writeTrackNumberText(
            trackNumberText,
            discNumberText: discNumberText,
            to: url,
            verifyAfterWrite: verifyAfterWrite,
            expectedVersion: expectedVersion
        )
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMapWithVerification(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode = .replace,
        verifyAfterWrite: Bool = true,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
            switch mode {
            case .replace:
                try TagLibMetadataExtractor.writeRawPropertyMapInPlace(properties, to: mutationURL)
                let warnings = verifyAfterWrite
                    ? rawPropertyMapReplacementWarnings(
                        expectedProperties: properties.mapValues { [$0] },
                        for: mutationURL
                    )
                    : []
                try throwOnVerificationFailures(warnings)
                return MetadataWriteResult(warnings: warnings)
            case .merge:
                var replacements: [String: [String]] = [:]
                var removals: Set<String> = []
                for (rawKey, rawValue) in properties {
                    let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !key.isEmpty else { continue }
                    let normalized = key.uppercased()
                    guard !hiddenInternalRawFieldKeys.contains(normalized) else {
                        throw RawMetadataPatchError.invalidKey(rawKey)
                    }
                    guard !key.contains("\0"), !rawValue.contains("\0") else {
                        throw RawMetadataPatchError.embeddedNull(rawKey)
                    }
                    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if value.isEmpty {
                        removals.insert(key)
                    } else {
                        replacements[key] = [value]
                    }
                }
                try applyRawMetadataDeltaInPlace(
                    replacements,
                    removingKeys: removals,
                    verify: verifyAfterWrite,
                    to: mutationURL
                )
                return MetadataWriteResult(warnings: [])
            }
        }
    }

    @available(*, deprecated, message: "Verification mismatches always throw. Omit failurePolicy.")
    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMapWithVerification(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode = .replace,
        verifyAfterWrite: Bool = true,
        expectedVersion: MetadataFileVersion? = nil,
        failurePolicy: VerificationFailurePolicy
    ) throws -> MetadataWriteResult {
        try writeRawMetadataPropertyMapWithVerification(
            properties,
            to: url,
            mode: mode,
            verifyAfterWrite: verifyAfterWrite,
            expectedVersion: expectedVersion
        )
    }

    @discardableResult
    /// Writes a complete multi-value PropertyMap replacement by default.
    /// Pass `.merge` to preserve unspecified keys.
    public nonisolated static func writeRawMetadataPropertyMapValuesWithVerification(
        _ properties: [String: [String]],
        to url: URL,
        mode: RawPropertyMapWriteMode = .replace,
        verifyAfterWrite: Bool = true,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
            switch mode {
            case .replace:
                try TagLibMetadataExtractor.writeRawPropertyMapValuesInPlace(properties, to: mutationURL)
                let warnings = verifyAfterWrite
                    ? rawPropertyMapReplacementWarnings(
                        expectedProperties: properties,
                        for: mutationURL
                    )
                    : []
                try throwOnVerificationFailures(warnings)
                return MetadataWriteResult(warnings: warnings)
            case .merge:
                var replacements: [String: [String]] = [:]
                var removals: Set<String> = []
                for (rawKey, rawValues) in properties {
                    let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !key.isEmpty else { continue }
                    let normalized = key.uppercased()
                    guard !hiddenInternalRawFieldKeys.contains(normalized) else {
                        throw RawMetadataPatchError.invalidKey(rawKey)
                    }
                    guard !key.contains("\0"),
                          rawValues.allSatisfy({ !$0.contains("\0") }) else {
                        throw RawMetadataPatchError.embeddedNull(rawKey)
                    }
                    let values = rawValues
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    if values.isEmpty {
                        removals.insert(key)
                    } else {
                        replacements[key] = values
                    }
                }
                try applyRawMetadataDeltaInPlace(
                    replacements,
                    removingKeys: removals,
                    verify: verifyAfterWrite,
                    to: mutationURL
                )
                return MetadataWriteResult(warnings: [])
            }
        }
    }

    @available(*, deprecated, message: "Verification mismatches always throw. Omit failurePolicy.")
    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMapValuesWithVerification(
        _ properties: [String: [String]],
        to url: URL,
        mode: RawPropertyMapWriteMode = .replace,
        verifyAfterWrite: Bool = true,
        expectedVersion: MetadataFileVersion? = nil,
        failurePolicy: VerificationFailurePolicy
    ) throws -> MetadataWriteResult {
        try writeRawMetadataPropertyMapValuesWithVerification(
            properties,
            to: url,
            mode: mode,
            verifyAfterWrite: verifyAfterWrite,
            expectedVersion: expectedVersion
        )
    }

    nonisolated private static func residualWarningsAfterErase(for url: URL) -> [String] {
        var warnings: [String] = []

        if let metadata = bestEffortMetadata(from: url) {
            var residualFields: [String] = []
            if !metadata.title.isEmpty { residualFields.append("TITLE") }
            if !metadata.artist.isEmpty { residualFields.append("ARTIST") }
            if !metadata.album.isEmpty { residualFields.append("ALBUM") }
            if !metadata.comment.isEmpty { residualFields.append("COMMENT") }
            if !metadata.genre.isEmpty { residualFields.append("GENRE") }
            if !metadata.isrc.isEmpty { residualFields.append("ISRC") }
            if !metadata.barcode.isEmpty { residualFields.append("BARCODE") }
            if !metadata.asin.isEmpty { residualFields.append("ASIN") }
            if !metadata.releaseType.isEmpty { residualFields.append("RELEASETYPE") }
            if !metadata.releaseStatus.isEmpty { residualFields.append("RELEASESTATUS") }
            if !metadata.musicBrainzTrackID.isEmpty { residualFields.append("MUSICBRAINZ_TRACKID") }
            if !metadata.musicBrainzAlbumID.isEmpty { residualFields.append("MUSICBRAINZ_ALBUMID") }
            if !metadata.acoustID.isEmpty { residualFields.append("ACOUSTID_ID") }
            if metadata.track > 0 || metadata.trackTotal > 0 { residualFields.append("TRACK") }
            if metadata.disc > 0 || metadata.discTotal > 0 { residualFields.append("DISC") }
            if !metadata.work.isEmpty || !metadata.movement.isEmpty { residualFields.append("WORK/MOVEMENT") }
            if metadata.artworkData != nil { residualFields.append("ARTWORK") }
            if !metadata.customFields.isEmpty { residualFields.append("CUSTOM") }

            if !residualFields.isEmpty {
                warnings.append(
                    "Some metadata fields still remain after erase: \(residualFields.joined(separator: ", "))."
                )
            }
        } else {
            warnings.append("Could not verify erase result by re-reading metadata.")
        }

        if let rawDump = bestEffortRawMetadata(from: url) {
            let remainingKeys = rawDump.properties
                .map(\.key)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !isHiddenInternalRawFieldKey($0) && !$0.isEmpty }
                .sorted()

            if !remainingKeys.isEmpty {
                let preview = remainingKeys.prefix(8).joined(separator: ", ")
                warnings.append(
                    "Raw metadata still contains \(remainingKeys.count) key(s) after erase (\(preview)\(remainingKeys.count > 8 ? ", ..." : ""))."
                )
            }
        }

        return warnings
    }

    @discardableResult
    public nonisolated static func eraseAllMetadataWithVerification(
        from url: URL,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
            try eraseAllMetadataInPlaceWithVerification(from: mutationURL)
        }
    }

    @available(*, deprecated, message: "Verification mismatches always throw. Omit failurePolicy.")
    @discardableResult
    public nonisolated static func eraseAllMetadataWithVerification(
        from url: URL,
        expectedVersion: MetadataFileVersion? = nil,
        failurePolicy: VerificationFailurePolicy
    ) throws -> MetadataWriteResult {
        try eraseAllMetadataWithVerification(from: url, expectedVersion: expectedVersion)
    }

    nonisolated private static func eraseAllMetadataInPlaceWithVerification(
        from url: URL
    ) throws -> MetadataWriteResult {
        let meta = TagLibAudioMetadata()
        meta.title = ""
        meta.artist = ""
        meta.album = ""
        meta.composer = ""
        meta.genre = ""
        meta.comment = ""
        meta.albumArtist = ""
        meta.year = ""
        meta.releaseDate = ""
        meta.originalReleaseDate = ""
        meta.label = ""
        meta.isrc = ""
        meta.barcode = ""
        meta.musicBrainzArtistId = ""
        meta.musicBrainzAlbumId = ""
        meta.musicBrainzAlbumArtistId = ""
        meta.musicBrainzTrackId = ""
        meta.musicBrainzReleaseGroupId = ""
        meta.musicBrainzReleaseTrackId = ""
        meta.musicBrainzWorkId = ""
        meta.acoustId = ""
        meta.acoustIdFingerprint = ""
        meta.musicIpPuid = ""
        meta.lyricist = ""
        meta.remixer = ""
        meta.producer = ""
        meta.engineer = ""
        meta.language = ""
        meta.mediaType = ""
        meta.releaseType = ""
        meta.releaseStatus = ""
        meta.catalogNumber = ""
        meta.releaseCountry = ""
        meta.asin = ""
        meta.originalAlbum = ""
        meta.originalArtist = ""
        meta.discSubtitle = ""
        meta.work = ""
        meta.movementNumber = 0
        meta.movementCount = 0
        meta.copyright = ""
        meta.trackNumber = 0
        meta.totalTracks = 0
        meta.discNumber = 0
        meta.totalDiscs = 0
        meta.trackNumberText = nil
        meta.discNumberText = nil
        meta.explicitContent = false
        meta.removeArtwork = true
        meta.customFields = nil

        var warnings: [String] = []
        try TagLibMetadataExtractor.writeMetadataInPlace(meta, to: url)
        warnings.append(
            contentsOf: metadataWriteWarnings(
                for: url,
                verification: MetadataWriteVerificationContext(
                    expectedTrackNumber: nil,
                    expectedTrackTotal: nil,
                    expectedTrackNumberText: nil,
                    expectedDiscNumber: nil,
                    expectedDiscTotal: nil,
                    expectedDiscNumberText: nil,
                    expectedExplicitContent: false,
                    artworkExpectation: .absent,
                    customFieldKeys: []
                )
            )
        )

        try TagLibMetadataExtractor.writeRawPropertyMapInPlace([:], to: url)

        if shouldWipeNativeMetadataContainer(for: url) {
            try TagLibMetadataExtractor.wipeMetadataInPlace(from: url)
        }

        warnings.append(contentsOf: residualWarningsAfterErase(for: url))
        try throwOnVerificationFailures(warnings)
        return MetadataWriteResult(warnings: warnings)
    }

    nonisolated private static func shouldWipeNativeMetadataContainer(for url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "mp3", "m4a", "m4r", "m4b", "m4p", "mp4", "m4v", "3g2",
             "flac", "ape", "wv", "mpc", "wav", "tta", "dff", "dsdiff":
            return true
        default:
            return false
        }
    }

    @discardableResult
    public nonisolated static func replaceBasicMetadata(
        _ meta: BasicMetadata,
        to url: URL,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }
        try validateBasicMetadataForWrite(meta)
        try validateDateStorageCompatibility(
            year: meta.year,
            releaseDate: meta.releaseDate,
            for: url
        )

        let m = TagLibAudioMetadata()

        func nilIfEmpty(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }

        // Core tags
        m.title = nilIfEmpty(meta.title)
        m.artist = nilIfEmpty(meta.artist)
        m.album = nilIfEmpty(meta.album)
        m.albumArtist = nilIfEmpty(meta.albumArtist)
        m.composer = nilIfEmpty(meta.composer)
        m.genre = nilIfEmpty(meta.genre)
        m.comment = nilIfEmpty(meta.comment)

        // Numbers
        // TagLib bridge uses `Int` for these fields; use 0 to represent “not set/clear”.
        m.trackNumber = meta.track
        m.totalTracks = meta.trackTotal
        m.discNumber = meta.disc
        m.totalDiscs = meta.discTotal
        m.trackNumberText = nilIfEmpty(meta.trackNumberText)
        m.discNumberText = nilIfEmpty(meta.discNumberText)

        // Dates
        m.year = nilIfEmpty(meta.year)
        m.releaseDate = nilIfEmpty(meta.releaseDate)
        m.originalReleaseDate = nilIfEmpty(meta.originalReleaseDate)

        // Legal / publisher
        m.label = nilIfEmpty(meta.publisher)
        m.copyright = nilIfEmpty(meta.copyright)
        m.lyrics = nilIfEmpty(meta.lyrics)
        m.encodedBy = nilIfEmpty(meta.encodedBy)
        m.encoderSettings = nilIfEmpty(meta.encoderSettings)
        m.sortTitle = nilIfEmpty(meta.sortTitle)
        m.sortArtist = nilIfEmpty(meta.sortArtist)
        m.sortAlbum = nilIfEmpty(meta.sortAlbum)
        m.sortAlbumArtist = nilIfEmpty(meta.sortAlbumArtist)
        m.sortComposer = nilIfEmpty(meta.sortComposer)
        m.conductor = nilIfEmpty(meta.conductor)
        m.remixer = nilIfEmpty(meta.remixer)
        m.producer = nilIfEmpty(meta.producer)
        m.engineer = nilIfEmpty(meta.engineer)
        m.lyricist = nilIfEmpty(meta.lyricist)
        m.subtitle = nilIfEmpty(meta.subtitle)
        m.grouping = nilIfEmpty(meta.grouping)
        m.movement = nilIfEmpty(meta.movement)
        m.mood = nilIfEmpty(meta.mood)
        m.language = nilIfEmpty(meta.language)
        m.musicalKey = nilIfEmpty(meta.musicalKey)
        m.replayGainTrack = nilIfEmpty(meta.replayGainTrack)
        m.replayGainAlbum = nilIfEmpty(meta.replayGainAlbum)
        m.mediaType = nilIfEmpty(meta.mediaType)
        m.itunesAlbumId = nilIfEmpty(meta.itunesAlbumID)
        m.itunesArtistId = nilIfEmpty(meta.itunesArtistID)
        m.itunesCatalogId = nilIfEmpty(meta.itunesCatalogID)
        m.itunesGenreId = nilIfEmpty(meta.itunesGenreID)
        m.itunesMediaType = nilIfEmpty(meta.itunesMediaType)
        m.itunesPurchaseDate = nilIfEmpty(meta.itunesPurchaseDate)
        m.itunesNorm = nilIfEmpty(meta.itunesNorm)
        m.itunesSmpb = nilIfEmpty(meta.itunesSMPB)
        m.releaseType = nilIfEmpty(meta.releaseType)
        m.releaseStatus = nilIfEmpty(meta.releaseStatus)
        m.catalogNumber = nilIfEmpty(meta.catalogNumber)
        m.releaseCountry = nilIfEmpty(meta.releaseCountry)
        m.artistType = nilIfEmpty(meta.artistType)
        m.asin = nilIfEmpty(meta.asin)
        m.originalAlbum = nilIfEmpty(meta.originalAlbum)
        m.originalArtist = nilIfEmpty(meta.originalArtist)
        m.discSubtitle = nilIfEmpty(meta.discSubtitle)
        m.work = nilIfEmpty(meta.work)
        m.movementNumber = meta.movementNumber
        m.movementCount = meta.movementCount

        // Explicit
        m.bpm = meta.bpm
        m.compilation = meta.isCompilation
        m.explicitAdvisory = switch meta.explicitAdvisory {
        case .unspecified: .unspecified
        case .notExplicit: .notExplicit
        case .clean: .clean
        case .explicit: .explicit
        }
        m.isrc = nilIfEmpty(meta.isrc)
        m.barcode = nilIfEmpty(meta.barcode)
        m.musicBrainzArtistId = nilIfEmpty(meta.musicBrainzArtistID)
        m.musicBrainzAlbumId = nilIfEmpty(meta.musicBrainzAlbumID)
        m.musicBrainzAlbumArtistId = nilIfEmpty(meta.musicBrainzAlbumArtistID)
        m.musicBrainzTrackId = nilIfEmpty(meta.musicBrainzTrackID)
        m.musicBrainzReleaseGroupId = nilIfEmpty(meta.musicBrainzReleaseGroupID)
        m.musicBrainzReleaseTrackId = nilIfEmpty(meta.musicBrainzReleaseTrackID)
        m.musicBrainzWorkId = nilIfEmpty(meta.musicBrainzWorkID)
        m.acoustId = nilIfEmpty(meta.acoustID)
        m.acoustIdFingerprint = nilIfEmpty(meta.acoustIDFingerprint)
        m.musicIpPuid = nilIfEmpty(meta.musicIPPUID)
        let explicitlyChangedCustomFields = meta.customFields.filter { key, value in
            guard let originalProjection = meta.originalCustomFieldProjection.first(where: {
                $0.key.caseInsensitiveCompare(key) == .orderedSame
            })?.value else {
                return true
            }
            return originalProjection != value
        }
        m.customFields = explicitlyChangedCustomFields.isEmpty ? nil : explicitlyChangedCustomFields
        m.artworkData = meta.artworkData
        m.artworkMimeType = normalizedArtworkMIMEType(meta.artworkMIMEType, data: meta.artworkData)

        let isMP4Family = capability(forExtension: ext)?.identifier == "mp4"
        let expectedTrackNumberText = isMP4Family
            ? numberTextPreservingFormatting(
                meta.trackNumberText,
                number: meta.track,
                total: meta.trackTotal
            )
            : meta.trackNumberText
        let expectedDiscNumberText = isMP4Family
            ? numberTextPreservingFormatting(
                meta.discNumberText,
                number: meta.disc,
                total: meta.discTotal
            )
            : meta.discNumberText
        let expectedYear: String
        if isMP4Family && normalizedTrimmed(meta.year).isEmpty && !normalizedTrimmed(meta.releaseDate).isEmpty {
            expectedYear = String(normalizedTrimmed(meta.releaseDate).prefix(4))
        } else {
            expectedYear = meta.year
        }

        let verification = MetadataWriteVerificationContext(
                expectedTrackNumber: meta.track,
                expectedTrackTotal: meta.trackTotal,
                expectedTrackNumberText: expectedTrackNumberText,
                expectedDiscNumber: meta.disc,
                expectedDiscTotal: meta.discTotal,
                expectedDiscNumberText: expectedDiscNumberText,
                expectedExplicitContent: meta.explicitAdvisory == .unspecified ? nil : meta.isExplicit,
                artworkExpectation: meta.artworkData == nil ? .skip : .present,
                customFieldKeys: Array(meta.customFields.keys),
                expectedTextFields: [
                    "title": meta.title,
                    "artist": meta.artist,
                    "album": meta.album,
                    "composer": meta.composer,
                    "genre": meta.genre,
                    "comment": meta.comment,
                    "lyrics": meta.lyrics,
                    "year": expectedYear,
                    "albumArtist": meta.albumArtist,
                    "releaseDate": meta.releaseDate,
                    "originalReleaseDate": meta.originalReleaseDate,
                    "publisher": meta.publisher,
                    "copyright": meta.copyright,
                    "encodedBy": meta.encodedBy,
                    "encoderSettings": meta.encoderSettings,
                    "isrc": meta.isrc,
                    "barcode": meta.barcode,
                    "sortTitle": meta.sortTitle,
                    "sortArtist": meta.sortArtist,
                    "sortAlbum": meta.sortAlbum,
                    "sortAlbumArtist": meta.sortAlbumArtist,
                    "sortComposer": meta.sortComposer,
                    "conductor": meta.conductor,
                    "remixer": meta.remixer,
                    "producer": meta.producer,
                    "engineer": meta.engineer,
                    "lyricist": meta.lyricist,
                    "subtitle": meta.subtitle,
                    "grouping": meta.grouping,
                    "movement": meta.movement,
                    "mood": meta.mood,
                    "language": meta.language,
                    "musicalKey": meta.musicalKey,
                    "replayGainTrack": meta.replayGainTrack,
                    "replayGainAlbum": meta.replayGainAlbum,
                    "mediaType": meta.mediaType,
                    "itunesAlbumID": meta.itunesAlbumID,
                    "itunesArtistID": meta.itunesArtistID,
                    "itunesCatalogID": meta.itunesCatalogID,
                    "itunesGenreID": meta.itunesGenreID,
                    "itunesMediaType": meta.itunesMediaType,
                    "itunesPurchaseDate": meta.itunesPurchaseDate,
                    "itunesNorm": meta.itunesNorm,
                    "itunesSMPB": meta.itunesSMPB,
                    "releaseType": meta.releaseType,
                    "releaseStatus": meta.releaseStatus,
                    "catalogNumber": meta.catalogNumber,
                    "releaseCountry": meta.releaseCountry,
                    "artistType": meta.artistType,
                    "asin": meta.asin,
                    "originalAlbum": meta.originalAlbum,
                    "originalArtist": meta.originalArtist,
                    "discSubtitle": meta.discSubtitle,
                    "work": meta.work,
                    "musicBrainzArtistID": meta.musicBrainzArtistID,
                    "musicBrainzAlbumID": meta.musicBrainzAlbumID,
                    "musicBrainzAlbumArtistID": meta.musicBrainzAlbumArtistID,
                    "musicBrainzTrackID": meta.musicBrainzTrackID,
                    "musicBrainzReleaseGroupID": meta.musicBrainzReleaseGroupID,
                    "musicBrainzReleaseTrackID": meta.musicBrainzReleaseTrackID,
                    "musicBrainzWorkID": meta.musicBrainzWorkID,
                    "acoustID": meta.acoustID,
                    "acoustIDFingerprint": meta.acoustIDFingerprint,
                    "musicIPPUID": meta.musicIPPUID,
                    "movementNumber": String(meta.movementNumber),
                    "movementCount": String(meta.movementCount),
                    "bpm": String(meta.bpm),
                    "isCompilation": String(meta.isCompilation),
                ],
                expectedExplicitAdvisory: meta.explicitAdvisory,
                customFieldValues: meta.customFields.filter { !$0.value.isEmpty }
            )

        return try withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
            let current = try readBasicMetadataAndRaw(from: mutationURL)
            // A PropertyMap cannot carry ID3 comment/lyric languages or the
            // original description spelling. Preserve the native collections
            // when their scalar Basic projection was not edited.
            var nativeCollections = StructuredMetadata()
            var preservedCollections: Set<StructuredMetadataReplaceableCollection> = []
            if capability(forExtension: ext)?.metadataFieldFormats.contains(.id3v2) == true {
                let native = try readStructuredMetadataResult(from: mutationURL)
                if meta.comment == current.metadata.comment, !native.comments.isEmpty {
                    nativeCollections.comments = native.comments
                    preservedCollections.insert(.comments)
                }
                if meta.lyrics == current.metadata.lyrics, !native.lyrics.isEmpty {
                    nativeCollections.lyrics = native.lyrics
                    preservedCollections.insert(.lyrics)
                }
            }
            let preservation = preservedStandardValues(
                desired: meta,
                current: current.metadata,
                rawDump: current.raw
            )
            // Keep a full recording date when the caller did not change the
            // Basic year projection. The Basic model exposes only the year,
            // but the underlying tag can carry a complete ISO date.
            if normalizedTrimmed(meta.year) == normalizedTrimmed(current.metadata.year),
               let fullDate = current.raw.properties.first(where: {
                   $0.key.caseInsensitiveCompare("DATE") == .orderedSame
               })?.values.first,
               !normalizedTrimmed(fullDate).isEmpty {
                m.year = fullDate
            }

            try TagLibMetadataExtractor.writeMetadataInPlace(m, to: mutationURL)
            if !preservation.values.isEmpty {
                if ext == "wav" {
                    try TagLibMetadataExtractor.applyPropertyMapValuesPreservingInfoSurfaceInPlace(
                        preservation.values,
                        removingKeys: Array(preservation.aliases),
                        to: mutationURL
                    )
                } else {
                    try TagLibMetadataExtractor.applyPropertyMapValuesInPlace(
                        preservation.values,
                        removingKeys: Array(preservation.aliases),
                        to: mutationURL
                    )
                }
            }
            if !preservedCollections.isEmpty {
                let payload = bridgePayload(
                    from: nativeCollections,
                    includeProperties: false,
                    replacingCollections: preservedCollections,
                    riffPolicy: .preserveInfo
                )
                try TagLibMetadataExtractor.writeStructuredMetadataInPlace(payload, to: mutationURL)
                let nativeVerification = structuredWriteVerification(
                    expected: nativeCollections,
                    includeProperties: false,
                    replacingCollections: preservedCollections,
                    for: mutationURL
                )
                try throwOnVerificationFailures(nativeVerification.failures)
            }
            var warnings = metadataWriteWarnings(for: mutationURL, verification: verification)
            warnings.append(contentsOf: preservedRawValueWarnings(preservation.values, for: mutationURL))
            try throwOnVerificationFailures(warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }

    /// Reads the current Basic projection, applies an in-memory edit, and replaces
    /// it only if the file still matches the captured version.
    @discardableResult
    public nonisolated static func updateBasicMetadata(
        at url: URL,
        _ update: (inout BasicMetadata) throws -> Void
    ) throws -> MetadataWriteResult {
        let snapshot = try readBasicSnapshot(from: url)
        var metadata = snapshot.metadata
        try update(&metadata)
        return try replaceBasicMetadata(
            metadata,
            to: url,
            expectedVersion: snapshot.fileVersion
        )
    }

    @available(*, deprecated, renamed: "replaceBasicMetadata(_:to:expectedVersion:)")
    @discardableResult
    public nonisolated static func writeMetadataWithVerification(
        _ meta: BasicMetadata,
        to url: URL,
        failurePolicy: VerificationFailurePolicy = .throw
    ) throws -> MetadataWriteResult {
        try replaceBasicMetadata(meta, to: url)
    }

    /// Write `BasicMetadata` back to the file using TagLib.
    ///
    /// Notes:
    /// - This is intended for formats supported by our TagLib bridge's write paths.
    /// - Fields that are empty strings are written as `nil` (i.e. removed/cleared).
    /// - `publisher` is mapped to TagLib's `label` field.
    @discardableResult
    @available(*, deprecated, message: "This replaces the complete Basic projection. Use replaceBasicMetadata(_:to:expectedVersion:) or updateBasicMetadata(at:_:).")
    public nonisolated static func writeMetadata(
        _ meta: BasicMetadata,
        to url: URL,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> Bool {
        _ = try replaceBasicMetadata(meta, to: url, expectedVersion: expectedVersion)
        return true
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMap(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode = .replace,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> Bool {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        _ = try writeRawMetadataPropertyMapWithVerification(
            properties,
            to: url,
            mode: mode,
            expectedVersion: expectedVersion
        )
        return true
    }

    /// Remove (as much as TagLib allows) all metadata from a file.
    ///
    /// Implementation strategy: write an empty `TagLibAudioMetadata` object.
    /// This should clear the common tag fields and reset numeric fields to 0.
    @discardableResult
    public nonisolated static func eraseAllMetadata(from url: URL) throws -> Bool {
        _ = try eraseAllMetadataWithVerification(from: url)
        return true
    }

    /// Raw metadata dump for GUI inspection ("show me everything TagLib sees").
    ///
    /// The extractor returns a dictionary with stable keys:
    /// - "properties": unified TagLib PropertyMap entries
    /// - "id3v2Frames": ID3v2 frames (MP3 only)
    ///
    /// Returns `nil` if format is not supported by TagLib in this app.
}
