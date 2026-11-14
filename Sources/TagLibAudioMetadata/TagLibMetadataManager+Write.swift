//
//  TagLibMetadataManager+Write.swift
//  TagLibAudioMetadata
//

import Foundation
import CTagLibBridge
import CTagLibBridgeInternalAPI

extension TagLibMetadataManager {
    nonisolated static let basicDateFields: [MetadataFieldKey] = [.year, .standaloneDate, .releaseDate, .originalReleaseDate]

    nonisolated static func isRepresentableYearText(_ text: String) -> Bool {
        let trimmed = normalizedTrimmed(text)
        guard !trimmed.isEmpty else { return true }
        if trimmed.allSatisfy(\.isNumber) {
            return UInt32(trimmed).map { _ in true } ?? false
        }
        // Complete date text such as 2021-07-15 or 2021/07/15 is valid; the
        // stored value is not truncated to its first four characters.
        let scalars = Array(trimmed.unicodeScalars)
        guard scalars.count >= 5,
              scalars.prefix(4).allSatisfy({ CharacterSet.decimalDigits.contains($0) }),
              scalars[4] == "-" || scalars[4] == "/" || scalars[4] == "." else {
            return false
        }
        return true
    }

    nonisolated static func validateBasicMetadataForWrite(_ metadata: BasicMetadata) throws {
        guard isRepresentableYearText(metadata.year) else {
            throw MetadataValidationError.invalidYearText(metadata.year)
        }
        for field in BasicMetadata.editableFieldKeys {
            if basicProjectionValue(for: field, metadata: metadata)?.contains("\0") == true {
                throw MetadataValidationError.embeddedNull(location: field.rawValue)
            }
        }
        for value in [metadata.trackNumberText, metadata.discNumberText, metadata.artworkMIMEType ?? ""] {
            if value.contains("\0") {
                throw MetadataValidationError.embeddedNull(location: "number text or artwork MIME type")
            }
        }
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
                // Native containers can expose an unmapped attribute with a
                // schema-known spelling. Preserve a read projection unchanged;
                // new or edited values still require the raw/structured API.
                let original = metadata.originalCustomFieldProjection.first {
                    $0.key.caseInsensitiveCompare(key) == .orderedSame
                }?.value
                if original != value {
                    throw MetadataValidationError.knownFieldRequiresRawAPI(key)
                }
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
        case .year: metadata.year
        case .standaloneDate: metadata.date
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
        case .contentGroup: metadata.contentGroup
        case .artists: metadata.artists
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
        case .replayGainTrackPeak: metadata.replayGainTrackPeak
        case .replayGainAlbumPeak: metadata.replayGainAlbumPeak
        case .itunesAlbumID: metadata.itunesAlbumID
        case .itunesArtistID: metadata.itunesArtistID
        case .itunesCatalogID: metadata.itunesCatalogID
        case .itunesGenreID: metadata.itunesGenreID
        case .itunesMediaType: metadata.itunesMediaType
        case .itunesPurchaseDate: metadata.itunesPurchaseDate
        case .itunesNorm: metadata.itunesNorm
        case .itunesSMPB: metadata.itunesSMPB
        case .director: metadata.director
        case .itunesAccount: metadata.itunesAccount
        case .itunesComposerID: metadata.itunesComposerID
        case .itunesCountryID: metadata.itunesCountryID
        case .itunesGapless: metadata.itunesGapless ? "1" : "0"
        case .itunesHDVideo: metadata.itunesHDVideo ? "1" : "0"
        case .itunesOwner: metadata.itunesOwner
        case .rate: String(metadata.rate)
        case .showMovement: metadata.showMovement ? "1" : "0"
        case .storeDescription: metadata.storeDescription
        case .tvEpisode: String(metadata.tvEpisode)
        case .tvEpisodeID: metadata.tvEpisodeID
        case .tvNetwork: metadata.tvNetwork
        case .tvSeason: String(metadata.tvSeason)
        case .tvShow: metadata.tvShow
        case .tvShowSort: metadata.tvShowSort
        case .originalAlbum: metadata.originalAlbum
        case .originalArtist: metadata.originalArtist
        case .artistType: metadata.artistType
        case .artwork, .performer, .involvedPeople, .musicianCredits,
             .explicitContent, .trackerName, .custom:
            nil
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

        return try MetadataFileTransaction.withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
            let before = try readSnapshot(from: mutationURL)
            if before.structured.id3v2MajorVersion == 3 {
                for (field, value) in [(MetadataFieldKey.year, metadata.year ?? ""), (.standaloneDate, metadata.standaloneDate ?? ""),
                    (.releaseDate, metadata.releaseDate ?? ""), (.originalReleaseDate, metadata.originalReleaseDate ?? "")] {
                    if value != basicProjectionValue(for: field, metadata: before.basic) {
                        throw MetadataPatchValidationError.unsupportedFieldForFormat(field: field, format: "ID3v2.3 independent dates (read-only)")
                    }
                }
                throw TagLibManagerError.unsupportedWritePolicy("Use version-checked Basic updates or typed patches to preserve ID3v2.3 dates.")
            }
            try TagLibMetadataExtractor.writeMetadataInPlace(metadata, to: mutationURL)
            let warnings = metadataWriteWarnings(for: mutationURL, verification: verification)
            try throwOnVerificationFailures(warnings)
            return MetadataWriteResult(warnings: warnings)
        }
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

        return try MetadataFileTransaction.withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
            let inventory = try numberingInventory(at: mutationURL)
            for (selected, group, name) in [
                (true, inventory.track, "track"),
                (discNumberText != nil, inventory.disc, "disc"),
            ] where selected && group.hasUnresolvedComponents {
                throw MetadataPatchValidationError.ambiguousNumberRecovery(
                    field: name, identities: group.number.identities + group.total.identities
                )
            }
            let trackInput = parseNumberPair(trackNumberText)
            let discInput = discNumberText.map(parseNumberPair)
            let recoverTrack = !trackNumberText.isEmpty && trackInput.total == 0
                && inventory.track.total.state == .recoveredLegacy
            let recoverDisc = discNumberText?.isEmpty == false && discInput?.total == 0
                && inventory.disc.total.state == .recoveredLegacy
            if recoverTrack || recoverDisc {
                try TagLibMetadataExtractor.writeNumberPairsInPlace(
                    trackNumber: trackInput.number,
                    totalTracks: inventory.track.total.recoveredValue ?? 0,
                    updateTrackPair: recoverTrack,
                    discNumber: discInput?.number ?? 0,
                    totalDiscs: inventory.disc.total.recoveredValue ?? 0,
                    updateDiscPair: recoverDisc,
                    to: mutationURL
                )
            }
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
                    artworkExpectation: .skip,
                    customFieldKeys: []
                )
            )
            try throwOnVerificationFailures(warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMapWithVerification(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode = .replace,
        verifyAfterWrite: Bool = true,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        try validateRawPropertyMapKeyNames(Array(properties.keys))
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try MetadataFileTransaction.withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
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
                    guard replacements[normalized] == nil, !removals.contains(normalized) else {
                        throw RawMetadataPatchError.conflictingKey(rawKey)
                    }
                    guard !hiddenInternalRawFieldKeys.contains(normalized) else {
                        throw RawMetadataPatchError.invalidKey(rawKey)
                    }
                    guard !key.contains("\0"), !rawValue.contains("\0") else {
                        throw RawMetadataPatchError.embeddedNull(rawKey)
                    }
                    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if value.isEmpty {
                        removals.insert(normalized)
                    } else {
                        replacements[normalized] = [value]
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
        try validateRawPropertyMapKeyNames(Array(properties.keys))
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try MetadataFileTransaction.withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
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
                    guard replacements[normalized] == nil, !removals.contains(normalized) else {
                        throw RawMetadataPatchError.conflictingKey(rawKey)
                    }
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
                        removals.insert(normalized)
                    } else {
                        replacements[normalized] = values
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

        return try MetadataFileTransaction.withAtomicMetadataWriteMutation(at: url, expectedVersion: expectedVersion) { mutationURL in
            try eraseAllMetadataInPlaceWithVerification(from: mutationURL)
        }
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
        meta.explicitAdvisory = .unspecified
        meta.removeArtwork = true
        meta.customFields = nil

        var warnings: [String] = []
        if try readSnapshot(from: url).structured.id3v2MajorVersion != 3 {
            try TagLibMetadataExtractor.writeMetadataInPlace(meta, to: url)
        }


        try TagLibMetadataExtractor.writeRawPropertyMapInPlace([:], to: url)

        if shouldWipeNativeMetadataContainer(for: url) {
            try TagLibMetadataExtractor.wipeMetadataInPlace(from: url)
        }

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
                    artworkExpectation: .absent,
                    customFieldKeys: [],
                    expectedExplicitAdvisory: .unspecified
                )
            )
        )

        if capability(forExtension: url.pathExtension)?.identifier == "asf",
           !(try readStructuredMetadataResult(from: url)).asfAttributes.isEmpty {
            warnings.append("Native ASF attributes remain after erase.")
        }
        warnings.append(contentsOf: residualWarningsAfterErase(for: url))
        try throwOnVerificationFailures(warnings)
        return MetadataWriteResult(warnings: warnings)
    }

    nonisolated private static func shouldWipeNativeMetadataContainer(for url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "mp3", "m4a", "m4r", "m4b", "m4p", "mp4", "m4v", "3g2",
             "flac", "ape", "wv", "mpc", "wav", "tta", "dff", "dsdiff", "wma", "asf":
            return true
        default:
            return false
        }
    }

    /// Diff the normalized model against a versioned snapshot, then use the
    /// same native planner and verification as typed field edits.
    @discardableResult
    public nonisolated static func replaceBasicMetadata(
        _ meta: BasicMetadata,
        to url: URL,
        expectedVersion: MetadataFileVersion? = nil
    ) throws -> MetadataWriteResult {
        guard isWritableExtension(url.pathExtension) else { throw TagLibManagerError.unsupportedFormat }
        guard url.isFileURL, MetadataFileIdentity.read(at: url) != nil else {
            throw TagLibManagerError.operationFailedWithUnderlying(NSError(domain: "TagLibMetadataManager", code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Metadata mutations require an existing regular file and do not follow symbolic links."]))
        }
        let before = try readSnapshot(from: url)
        if let expectedVersion, expectedVersion != before.fileVersion { throw TagLibManagerError.fileChanged }
        var validation = meta
        if meta.year == before.basic.year { validation.year = "" }
        try validateBasicMetadataForWrite(validation)
        var fields: [MetadataFieldKey: MetadataPatchValue] = [:]
        let scalarNumbers: Set<MetadataFieldKey> = [.track, .trackTotal, .disc, .discTotal, .movementNumber, .movementCount, .bpm, .tvEpisode, .tvSeason, .rate]
        for field in BasicMetadata.editableFieldKeys.subtracting([.artwork, .explicitContent]) {
            guard let value = basicProjectionValue(for: field, metadata: meta),
                  value != basicProjectionValue(for: field, metadata: before.basic),
                  let schema = MetadataFieldRegistry.schema(for: field) else { continue }
            if before.structured.id3v2MajorVersion == 3, basicDateFields.contains(field) {
                throw MetadataPatchValidationError.unsupportedFieldForFormat(field: field, format: "ID3v2.3 independent dates (read-only)")
            }
            if value.isEmpty || value == "0" && scalarNumbers.contains(field) { fields[field] = .remove }
            else if schema.acceptedPatchValueKinds.contains(.boolean) { fields[field] = .boolean(value == "1") }
            else if schema.acceptedPatchValueKinds.contains(.integer), let integer = Int(value) { fields[field] = .integer(integer) }
            else { fields[field] = .text(value) }
        }
        var custom: [String: MetadataPatchValue] = [:]
        for (key, value) in meta.customFields where value != before.basic.customFields[key] {
            custom[key] = value.isEmpty ? .remove : .text(value)
        }
        for (key, values) in meta.customFieldValues where values != before.basic.customFieldValues[key] && custom[key] == nil {
            custom[key] = values.isEmpty ? .remove : .values(values)
        }
        let mime = normalizedArtworkMIMEType(meta.artworkMIMEType, data: meta.artworkData)
        var artwork: MetadataArtworkPatch = meta.artworkData == before.basic.artworkData && mime == before.basic.artworkMIMEType ? .unchanged
            : meta.artworkData.map { .replace([.init(mimeType: mime ?? "image/jpeg", data: $0)]) } ?? .removeAll
        if let data = meta.artworkData, data == before.basic.artworkData, mime != before.basic.artworkMIMEType,
           let index = before.structured.artwork.firstIndex(where: { $0.data == data }) {
            var retained = before.structured.artwork
            retained[index].mimeType = mime ?? retained[index].mimeType
            artwork = .replace(retained)
        }
        if meta.explicitAdvisoryRawValue != before.basic.explicitAdvisoryRawValue, meta.explicitAdvisoryRawValue != nil {
            throw TagLibManagerError.unsupportedWritePolicy("Unknown advisory provenance is read-only; use a raw native edit.")
        }
        let advisory = meta.explicitAdvisory != before.basic.explicitAdvisory || meta.explicitAdvisoryRawValue != before.basic.explicitAdvisoryRawValue
            ? meta.explicitAdvisory : nil
        let isMP4 = capability(forExtension: url.pathExtension)?.identifier == "mp4"
        var trackText: String?
        var discText: String?
        if meta.trackNumberText != before.basic.trackNumberText,
           !meta.trackNumberText.isEmpty {
            let pair = parseNumberPair(meta.trackNumberText)
            guard pair.number == meta.track, pair.total == meta.trackTotal else {
                throw MetadataPatchValidationError.numberTextMismatch(
                    field: "trackNumberText", text: meta.trackNumberText
                )
            }
            if !isMP4 {
                trackText = meta.trackNumberText
                fields.removeValue(forKey: .track)
                fields.removeValue(forKey: .trackTotal)
            }
        }
        if meta.discNumberText != before.basic.discNumberText,
           !meta.discNumberText.isEmpty {
            let pair = parseNumberPair(meta.discNumberText)
            guard pair.number == meta.disc, pair.total == meta.discTotal else {
                throw MetadataPatchValidationError.numberTextMismatch(
                    field: "discNumberText", text: meta.discNumberText
                )
            }
            if !isMP4 {
                discText = meta.discNumberText
                fields.removeValue(forKey: .disc)
                fields.removeValue(forKey: .discTotal)
            }
        }
        let patch = MetadataPatch(fields: fields, customFields: custom, explicitAdvisory: advisory, artwork: artwork,
            numberText: trackText == nil && discText == nil ? nil : .init(trackNumberText: trackText, discNumberText: discText))
        return try applyMetadataPatch(patch, to: url, expectedVersion: expectedVersion ?? before.fileVersion)
    }

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


}
