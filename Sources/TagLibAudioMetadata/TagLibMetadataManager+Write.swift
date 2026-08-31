//
//  TagLibMetadataManager+Write.swift
//  TagLibAudioMetadata
//

import Foundation
import CTagLibBridge

extension TagLibMetadataManager {
    nonisolated private static func basicProjectionValue(
        for field: MetadataFieldKey,
        metadata: BasicMetadata
    ) -> String? {
        switch field {
        case .artist: metadata.artist
        case .albumArtist: metadata.albumArtist
        case .genre: metadata.genre
        case .composer: metadata.composer
        case .conductor: metadata.conductor
        case .remixer: metadata.remixer
        case .producer: metadata.producer
        case .engineer: metadata.engineer
        case .lyricist: metadata.lyricist
        case .grouping: metadata.grouping
        case .mood: metadata.mood
        case .language: metadata.language
        case .originalArtist: metadata.originalArtist
        default: nil
        }
    }

    public nonisolated static func writeTagMetadata(
        _ metadata: TagLibAudioMetadata,
        to url: URL,
        verification: MetadataWriteVerificationContext = .none,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicFileMutation(at: url) { mutationURL in
            try TagLibMetadataExtractor.writeMetadataInPlace(metadata, to: mutationURL)
            let warnings = metadataWriteWarnings(for: mutationURL, verification: verification)
            try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }

    @discardableResult
    public nonisolated static func writeTrackNumberText(
        _ trackNumberText: String,
        discNumberText: String?,
        to url: URL,
        verifyAfterWrite: Bool = true,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicFileMutation(at: url) { mutationURL in
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

            let warnings = metadataWriteWarnings(
                for: mutationURL,
                verification: MetadataWriteVerificationContext(
                    expectedTrackNumber: expectedTrackPair.number > 0 ? expectedTrackPair.number : nil,
                    expectedTrackTotal: expectedTrackPair.total > 0 ? expectedTrackPair.total : nil,
                    expectedTrackNumberText: trackNumberText,
                    expectedDiscNumber: expectedDiscPair.number > 0 ? expectedDiscPair.number : nil,
                    expectedDiscTotal: expectedDiscPair.total > 0 ? expectedDiscPair.total : nil,
                    expectedDiscNumberText: discNumberText,
                    expectedExplicitContent: nil,
                    artworkExpectation: .unchanged,
                    customFieldKeys: []
                )
            )
            try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMapWithVerification(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode = .replace,
        verifyAfterWrite: Bool = true,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicFileMutation(at: url) { mutationURL in
            switch mode {
            case .replace:
                try TagLibMetadataExtractor.writeRawPropertyMapInPlace(properties, to: mutationURL)
            case .merge:
                let resolvedProperties = try resolvedRawPropertyMapValuesForMerge(properties, to: mutationURL)
                try TagLibMetadataExtractor.writeRawPropertyMapValuesInPlace(resolvedProperties, to: mutationURL)
            }

            let warnings = verifyAfterWrite
                ? rawPropertyMapWriteWarnings(requestedProperties: properties, for: mutationURL)
                : []
            try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMapValuesWithVerification(
        _ properties: [String: [String]],
        to url: URL,
        verifyAfterWrite: Bool = true,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicFileMutation(at: url) { mutationURL in
            try TagLibMetadataExtractor.writeRawPropertyMapValuesInPlace(properties, to: mutationURL)

            let warnings: [String]
            if verifyAfterWrite {
                let after = try rawMetadataResult(from: mutationURL)
                let lookup = after.properties.reduce(into: [String: [String]]()) { result, entry in
                    result[entry.key.uppercased()] = entry.values
                }
                warnings = properties.flatMap { key, values -> [String] in
                    let persisted = lookup[key.uppercased()] ?? []
                    return persisted == values ? [] : ["Raw multi-value key \"\(key)\" differs after save."]
                }
            } else {
                warnings = []
            }

            try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }

    nonisolated private static func residualWarningsAfterErase(for url: URL) -> [String] {
        var warnings: [String] = []

        if let metadata = readMetadata(from: url) {
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

        if let rawDump = rawMetadata(from: url) {
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
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicFileMutation(at: url) { mutationURL in
            try eraseAllMetadataInPlaceWithVerification(
                from: mutationURL,
                failurePolicy: failurePolicy
            )
        }
    }

    nonisolated private static func eraseAllMetadataInPlaceWithVerification(
        from url: URL,
        failurePolicy: VerificationFailurePolicy
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
        try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
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
    public nonisolated static func writeMetadataWithVerification(
        _ meta: BasicMetadata,
        to url: URL,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

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

        var preservedStandardValues: [String: [String]] = [:]
        var preservedStandardAliases: Set<String> = []
        for (rawKey, values) in meta.originalStandardFieldValues {
            guard let schema = MetadataFieldRegistry.schema(forPropertyMapKey: rawKey) else {
                continue
            }

            if BasicMetadata.editableFieldKeys.contains(schema.key) {
                guard let originalProjection = meta.originalStandardFieldProjection.first(where: {
                    $0.key.caseInsensitiveCompare(rawKey) == .orderedSame
                })?.value,
                basicProjectionValue(for: schema.key, metadata: meta) == originalProjection else {
                    continue
                }
            }

            preservedStandardValues[rawKey] = values
            preservedStandardAliases.formUnion(schema.propertyMapKeys)
        }

        let verification = MetadataWriteVerificationContext(
                expectedTrackNumber: meta.track,
                expectedTrackTotal: meta.trackTotal,
                expectedTrackNumberText: meta.trackNumberText,
                expectedDiscNumber: meta.disc,
                expectedDiscTotal: meta.discTotal,
                expectedDiscNumberText: meta.discNumberText,
                expectedExplicitContent: meta.explicitAdvisory == .unspecified ? nil : meta.isExplicit,
                artworkExpectation: meta.artworkData == nil ? .unchanged : .present,
                customFieldKeys: Array(meta.customFields.keys),
                expectedTextFields: [
                    "title": meta.title,
                    "artist": meta.artist,
                    "album": meta.album,
                    "composer": meta.composer,
                    "genre": meta.genre,
                    "comment": meta.comment,
                    "lyrics": meta.lyrics,
                    "year": meta.year,
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
                expectedExplicitAdvisory: meta.explicitAdvisory
            )

        return try withAtomicFileMutation(at: url) { mutationURL in
            try TagLibMetadataExtractor.writeMetadataInPlace(m, to: mutationURL)
            if !preservedStandardValues.isEmpty {
                try TagLibMetadataExtractor.applyPropertyMapValuesInPlace(
                    preservedStandardValues,
                    removingKeys: Array(preservedStandardAliases),
                    to: mutationURL
                )
            }
            let warnings = metadataWriteWarnings(for: mutationURL, verification: verification)
            try applyVerificationFailurePolicy(failurePolicy, warnings: warnings)
            return MetadataWriteResult(warnings: warnings)
        }
    }

    /// Write `BasicMetadata` back to the file using TagLib.
    ///
    /// Notes:
    /// - This is intended for formats supported by our TagLib bridge's write paths.
    /// - Fields that are empty strings are written as `nil` (i.e. removed/cleared).
    /// - `publisher` is mapped to TagLib's `label` field.
    @discardableResult
    public nonisolated static func writeMetadata(_ meta: BasicMetadata, to url: URL) throws -> Bool {
        let result = try writeMetadataWithVerification(meta, to: url)
        if !result.warnings.isEmpty {
            print("[AudioMator] Metadata write warnings for \(url.lastPathComponent): \(result.warnings.joined(separator: " | "))")
        }
        return true
    }

    @discardableResult
    public nonisolated static func writeRawMetadataPropertyMap(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode = .replace
    ) throws -> Bool {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        let result = try writeRawMetadataPropertyMapWithVerification(properties, to: url, mode: mode)
        if !result.warnings.isEmpty {
            print("[AudioMator] Raw metadata write warnings for \(url.lastPathComponent): \(result.warnings.joined(separator: " | "))")
        }
        return true
    }

    /// Remove (as much as TagLib allows) all metadata from a file.
    ///
    /// Implementation strategy: write an empty `TagLibAudioMetadata` object.
    /// This should clear the common tag fields and reset numeric fields to 0.
    @discardableResult
    public nonisolated static func eraseAllMetadata(from url: URL) throws -> Bool {
        let result = try eraseAllMetadataWithVerification(from: url)
        if !result.warnings.isEmpty {
            print("[AudioMator] Erase warnings for \(url.lastPathComponent): \(result.warnings.joined(separator: " | "))")
        }
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
