//
//  TagLibMetadataManager+Read.swift
//  TagLibAudioMetadata
//

import Foundation
import CTagLibBridge

nonisolated private func preferredRawNumberText(_ currentValue: String, _ candidateValue: String) -> String {
    func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func score(_ value: String) -> Int {
        let trimmed = normalized(value)
        guard !trimmed.isEmpty else { return .min }

        let leftPart = trimmed.split(separator: "/", maxSplits: 1).first.map(String.init) ?? trimmed
        let hasLeadingZeros = leftPart.count > 1 && leftPart.hasPrefix("0")
        let hasExplicitTotal = trimmed.contains("/")
        return (hasLeadingZeros ? 1000 : 0) + (hasExplicitTotal ? 100 : 0) + trimmed.count
    }

    let trimmedCurrent = normalized(currentValue)
    let trimmedCandidate = normalized(candidateValue)

    guard !trimmedCandidate.isEmpty else { return trimmedCurrent }
    guard !trimmedCurrent.isEmpty else { return trimmedCandidate }
    return score(trimmedCandidate) > score(trimmedCurrent) ? trimmedCandidate : trimmedCurrent
}

nonisolated private func rawNumberTexts(from dump: RawMetadataDump) -> (track: String, disc: String) {
    let trackFromProperties = dump.properties
        .filter { ["TRACKNUMBER", "TRACK"].contains($0.key.uppercased()) }
        .reduce(into: "") { bestValue, entry in
            for value in entry.values {
                bestValue = preferredRawNumberText(bestValue, value)
            }
            bestValue = preferredRawNumberText(bestValue, entry.value)
        }

    let discFromProperties = dump.properties
        .filter { ["DISCNUMBER", "DISC"].contains($0.key.uppercased()) }
        .reduce(into: "") { bestValue, entry in
            for value in entry.values {
                bestValue = preferredRawNumberText(bestValue, value)
            }
            bestValue = preferredRawNumberText(bestValue, entry.value)
        }

    let trackFromFrames = dump.id3v2Frames
        .filter { $0.frameID.uppercased() == "TRCK" }
        .reduce(into: "") { bestValue, entry in
            bestValue = preferredRawNumberText(bestValue, entry.value)
        }

    let discFromFrames = dump.id3v2Frames
        .filter { $0.frameID.uppercased() == "TPOS" }
        .reduce(into: "") { bestValue, entry in
            bestValue = preferredRawNumberText(bestValue, entry.value)
        }

    return (
        track: preferredRawNumberText(trackFromProperties, trackFromFrames),
        disc: preferredRawNumberText(discFromProperties, discFromFrames)
    )
}

nonisolated private func bridgeProjectionValue(
    for field: MetadataFieldKey,
    metadata: TagLibAudioMetadata
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

extension TagLibMetadataManager {
    // MARK: - Bridge Dump API

    nonisolated static func rawMetadataDump(fromBridgeDictionary dict: [String: NSObject]) -> RawMetadataDump {
        let propsAny = dict["properties"] as? [Any] ?? []
        let framesAny = dict["id3v2Frames"] as? [Any] ?? []

        let properties: [RawPropertyEntry] = propsAny.compactMap { item in
            guard let d = item as? NSDictionary else { return nil }
            let key = d["key"] as? String ?? ""
            let value = d["value"] as? String ?? ""
            let values = (d["values"] as? [String])
                ?? (d["values"] as? [Any])?.compactMap { $0 as? String }
                ?? []
            let count = (d["count"] as? NSNumber)?.intValue ?? values.count
            guard !isHiddenInternalRawFieldKey(key) else { return nil }
            return RawPropertyEntry(key: key, value: value, values: values, count: count)
        }
        .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }

        let id3v2Frames = framesAny.compactMap { item -> RawID3v2FrameEntry? in
            guard let d = item as? NSDictionary else { return nil }
            return RawID3v2FrameEntry(
                frameID: d["id"] as? String ?? "",
                value: d["value"] as? String ?? "",
                description: d["description"] as? String,
                language: d["language"] as? String
            )
        }
        return RawMetadataDump(properties: properties, id3v2Frames: id3v2Frames)
    }

    /// The facade and bundled bridge use one compile-time API contract.
    nonisolated static func bridgeTextDumpIfAvailable(for url: URL) -> String? {
        guard let text = try? TagLibMetadataExtractor.dumpMetadataText(from: url) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated static func basicMetadata(
        fromBridgeMetadata meta: TagLibAudioMetadata,
        rawDump: RawMetadataDump,
        fileExtension: String? = nil,
        structured: StructuredMetadata = StructuredMetadata()
    ) -> BasicMetadata {
        // Most native keys are ASCII. Index that common case once per read
        // rather than repeatedly performing Foundation comparisons over every
        // custom field. Keep the original comparison for Unicode keys, whose
        // case-insensitive equivalence is broader than uppercased equality.
        let rawKeysAreASCII = rawDump.properties.allSatisfy { $0.key.utf8.allSatisfy { $0 < 128 } }
        let rawByKey: [String: RawPropertyEntry] = rawKeysAreASCII
            ? Dictionary(rawDump.properties.map { ($0.key.uppercased(), $0) }, uniquingKeysWith: { first, _ in first })
            : [:]
        let mp4ByKey = Dictionary(structured.mp4Atoms.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        func rawEntry(for key: String) -> RawPropertyEntry? {
            if rawKeysAreASCII && key.utf8.allSatisfy({ $0 < 128 }) {
                return rawByKey[key.uppercased()]
            }
            return rawDump.properties.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }
        }
        func firstRawValue(for keys: [String]) -> String? {
            for key in keys {
                if let value = rawEntry(for: key)?.values.first { return value }
            }
            return nil
        }

        let formatCapability: FormatCapability? = fileExtension.flatMap {
            Self.capability(forExtension: $0)
        }
        let isMP4 = formatCapability?.metadataFieldFormats.contains(MetadataFieldFormat.mp4) == true
        let isASF = formatCapability?.identifier == "asf"
        let isNativeText = ["flac", "ogg-vorbis", "ogg-opus", "ogg-flac", "ogg-speex", "ape", "wavpack", "musepack"]
            .contains(formatCapability?.identifier ?? "")
        func asfText(_ key: String) -> String? {
            structured.asfAttributes.first {
                $0.key.caseInsensitiveCompare(key) == .orderedSame
            }?.value
        }
        // FLAC, WAV and AIFF can carry an optional ID3 tag, but their primary
        // rich surface is Xiph/INFO. Only formats whose primary model is ID3
        // read YEAR/DATE from ID3 frames.
        let primaryID3Identifiers: Set<String> = [
            "mpeg-id3", "mpeg-aac", "wav", "aiff", "trueaudio", "dsf", "dsdiff"
        ]
        let isID3 = primaryID3Identifiers.contains(formatCapability?.identifier ?? "")

        func nonEmpty(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : value
        }

        func frameValue(_ frameID: String, description: String? = nil) -> String? {
            // Prefer the structured projection: raw frame summaries render a
            // TXXX frame as "[description] payload" rather than separate fields.
            if let structuredFrame = structured.id3v2Frames.first(where: { frame in
                guard frame.frameID.caseInsensitiveCompare(frameID) == .orderedSame else { return false }
                guard let description else { return true }
                return frame.description?.caseInsensitiveCompare(description) == .orderedSame
            }) {
                return nonEmpty(structuredFrame.values.first ?? structuredFrame.value)
            }
            return nonEmpty(rawDump.id3v2Frames.first { frame in
                guard frame.frameID.caseInsensitiveCompare(frameID) == .orderedSame else { return false }
                guard let description else { return true }
                return frame.description?.caseInsensitiveCompare(description) == .orderedSame
            }?.value)
        }

        func mp4Text(_ key: String) -> String? {
            guard let atom = mp4ByKey[key] else { return nil }
            if !atom.values.isEmpty {
                return nonEmpty(atom.values.joined(separator: "; "))
            }
            return nonEmpty(atom.value)
        }

        func mp4TextList(_ key: String) -> [String] {
            mp4ByKey[key]?.values ?? []
        }

        func mp4Integer(_ key: String) -> Int? {
            guard let atom = mp4ByKey[key] else { return nil }
            if let first = atom.first, atom.type == "intPair" { return first }
            return Int(atom.value)
        }

        func mp4Bool(_ key: String) -> Bool? {
            guard let atom = mp4ByKey[key] else { return nil }
            switch atom.value.lowercased() {
            case "1", "true": return true
            case "0", "false": return false
            default: return nil
            }
        }

        func freeformText(_ description: String) -> String? {
            if let atom = structured.mp4Atoms.first(where: {
                $0.freeformDescription?.caseInsensitiveCompare(description) == .orderedSame
            }) {
                return nonEmpty(atom.values.first ?? atom.value)
            }
            let expected = "----:COM.APPLE.ITUNES:\(description)".uppercased()
            return rawDump.properties.first {
                $0.key.uppercased() == expected
            }?.values.first
        }

        // YEAR is read from its declared native slot with the complete stored
        // value. It is never derived from, truncated by, or reconciled with any
        // date field.
        let storedYear: String?
        if isMP4 {
            // ©day is the YEAR slot. The engine's DATE projection may also
            // carry an independent freeform DATE, so it must not be used as a
            // YEAR fallback.
            storedYear = mp4Text("\u{00A9}day")
        } else if isID3 {
            // TDRC/TYER are the YEAR slots; the engine DATE projection is
            // ambiguous across TDAT/TXXX(DATE) and is not a fallback.
            storedYear = frameValue("TDRC") ?? frameValue("TYER")
        } else if isASF {
            storedYear = asfText("WM/Year")
        } else {
            storedYear = firstRawValue(for: ["YEAR"])
        }
        let year = storedYear ?? ""

        // Standalone DATE is a different registered location from YEAR. It is
        // never synthesized from the Year text or from another date field.
        let standaloneDate: String?
        if isMP4 {
            standaloneDate = freeformText("DATE")
        } else if isID3 {
            standaloneDate = frameValue("TDAT") ?? frameValue("TXXX", description: "DATE")
                ?? firstRawValue(for: ["STANDALONEDATE"])
        } else if isASF {
            standaloneDate = asfText("DATE")
        } else {
            standaloneDate = firstRawValue(for: ["DATE"])
        }

        let releaseDate: String?
        if isMP4 {
            releaseDate = freeformText("RELEASEDATE")
        } else if isID3 {
            releaseDate = frameValue("TDRL") ?? firstRawValue(for: ["RELEASEDATE"])
        } else if isASF {
            releaseDate = nil
        } else {
            releaseDate = firstRawValue(for: ["RELEASEDATE"])
        }

        let originalReleaseDate: String?
        if isMP4 {
            originalReleaseDate = freeformText("ORIGINALDATE") ?? freeformText("ORIGINAL YEAR")
                ?? firstRawValue(for: ["ORIGINALDATE", "ORIGINAL YEAR"])
        } else if isID3 {
            originalReleaseDate = frameValue("TDOR") ?? frameValue("TORY")
                ?? firstRawValue(for: ["ORIGINALDATE", "ORIGINAL YEAR"])
        } else if isASF {
            originalReleaseDate = asfText("WM/OriginalReleaseYear")
        } else {
            originalReleaseDate = firstRawValue(for: ["ORIGINALDATE", "ORIGINAL YEAR"])
        }

        // Exact MP4 target atoms take precedence over the engine PropertyMap
        // projection for the fields whose native slots changed in 2.2.
        let conductor = mp4Text("\u{00A9}con") ?? meta.conductor
        let publisher = mp4Text("\u{00A9}pub") ?? meta.label
        let contentGroup: String?
        let grouping: String?
        let work: String?
        if isMP4 {
            contentGroup = mp4Text("\u{00A9}grp")
            grouping = mp4Text("----:com.apple.iTunes:GROUPING")
            work = mp4Text("\u{00A9}wrk") ?? mp4Text("----:com.apple.iTunes:WORK")
        } else if isID3 {
            contentGroup = frameValue("TIT1")
            grouping = frameValue("GRP1")
            work = frameValue("TXXX", description: "WORK")
        } else if isNativeText {
            contentGroup = firstRawValue(for: ["CONTENTGROUP"])
            grouping = firstRawValue(for: ["GROUPING"])
            work = firstRawValue(for: ["WORK"])
        } else {
            contentGroup = isASF ? asfText("WM/ContentGroupDescription") : meta.grouping
            grouping = isASF ? nil : meta.grouping
            work = isASF ? nil : meta.work
        }
        let asfArtists = isASF ? asfText("WM/ARTISTS") : nil
        let encodedBy = isMP4
            ? (mp4Text("\u{00A9}enc") ?? mp4Text("----:com.apple.iTunes:ENCODEDBY"))
            : (isID3 ? frameValue("TENC") : (isASF ? asfText("WM/EncodedBy") : (isNativeText ? firstRawValue(for: ["ENCODEDBY"]) : meta.encodedBy)))
        let encoderSettings = isMP4
            ? (mp4Text("\u{00A9}too") ?? mp4Text("----:com.apple.iTunes:ENCODERSETTINGS") ?? mp4Text("----:com.apple.iTunes:ENCODING"))
            : (isID3 ? frameValue("TSSE") : (isASF ? asfText("WM/EncodingSettings") : (isNativeText ? firstRawValue(for: ["ENCODING", "ENCODERSETTINGS"]) : meta.encoderSettings)))
        let mediaType = mp4Text("----:com.apple.iTunes:MEDIA") ?? meta.mediaType
        let itunesAlbumID = mp4Integer("plID").map(String.init) ?? meta.itunesAlbumId
        let itunesArtistID = mp4Integer("atID").map(String.init) ?? meta.itunesArtistId
        let itunesCatalogID = mp4Integer("cnID").map(String.init) ?? meta.itunesCatalogId
        let itunesGenreID = mp4Integer("geID").map(String.init) ?? meta.itunesGenreId
        let itunesComposerID = mp4Integer("cmID").map(String.init) ?? ""
        let itunesCountryID = mp4Integer("sfID").map(String.init) ?? ""
        let itunesMediaType = mp4Integer("stik").map(String.init) ?? meta.itunesMediaType
        let explicitAdvisoryRawValue = nonEmpty(meta.explicitAdvisoryRawValue as String?)
        let itunesGapless = mp4Bool("pgap") ?? false
        let itunesHDVideo = mp4Bool("hdvd") ?? false
        let itunesOwner = mp4Text("ownr") ?? ""
        let rateValue = mp4Integer("rate") ?? 0
        let showMovement = mp4Bool("shwm") ?? false
        let storeDescription = mp4Text("sdes") ?? ""
        let director = mp4TextList("\u{00A9}dir").joined(separator: "; ")
        let tvEpisode = mp4Integer("tves") ?? 0
        let tvEpisodeID = mp4Text("tven") ?? ""
        let tvNetwork = mp4Text("tvnn") ?? ""
        let tvSeason = mp4Integer("tvsn") ?? 0
        let tvShow = mp4Text("tvsh") ?? ""
        let tvShowSort = mp4Text("sosn") ?? ""
        let replayGainTrackPeak = firstRawValue(for: ["REPLAYGAIN_TRACK_PEAK"]) ?? ""
        let replayGainAlbumPeak = firstRawValue(for: ["REPLAYGAIN_ALBUM_PEAK"]) ?? ""
        let trackNumberText = meta.trackNumberText ?? ""
        let discNumberText = meta.discNumberText ?? ""
        let needsTrackTextFallback =
            trackNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            meta.trackNumber > 0
        let needsDiscTextFallback =
            discNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            meta.discNumber > 0

        let rawNumberText: (track: String, disc: String)
        if needsTrackTextFallback || needsDiscTextFallback {
            rawNumberText = rawNumberTexts(from: rawDump)
        } else {
            rawNumberText = (track: "", disc: "")
        }

        var trackSource: MetadataValueSource =
            trackNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (meta.trackNumber > 0 ? .derivedNumeric : .none)
            : .nativeTag

        var discSource: MetadataValueSource =
            discNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (meta.discNumber > 0 ? .derivedNumeric : .none)
            : .nativeTag

        if needsTrackTextFallback,
           !rawNumberText.track.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            trackSource = .rawFallback
        }

        if needsDiscTextFallback,
           !rawNumberText.disc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            discSource = .rawFallback
        }

        let explicitSource = explicitValueSource(
            from: rawDump,
            fallback: meta.explicitAdvisory != .unspecified
        )
        let artworkSource: MetadataValueSource = (meta.artworkData as Data?) == nil ? .none : .nativeTag
        let explicitAdvisory: ExplicitAdvisory = switch meta.explicitAdvisory {
        case .notExplicit: .notExplicit
        case .clean: .clean
        case .explicit: .explicit
        default: .unspecified
        }
        let customFields = meta.customFields ?? [:]
        let customFieldValues = customFields.reduce(into: [String: [String]]()) { result, field in
            let rawValues = rawEntry(for: field.key)?.values ?? []
            result[field.key] = rawValues.isEmpty ? [field.value] : rawValues
        }
        var originalStandardFieldValues: [String: [String]] = [:]
        var originalStandardFieldProjection: [String: String] = [:]
        for entry in rawDump.properties where !entry.values.isEmpty {
            guard let schema = MetadataFieldRegistry.schema(forPropertyMapKey: entry.key),
                  schema.key != .custom,
                  schema.isMultiValue || !BasicMetadata.editableFieldKeys.contains(schema.key) else {
                continue
            }

            originalStandardFieldValues[entry.key] = entry.values
            if BasicMetadata.editableFieldKeys.contains(schema.key),
               let projection = bridgeProjectionValue(for: schema.key, metadata: meta) {
                originalStandardFieldProjection[entry.key] = projection
            }
        }

        return BasicMetadata(
            title: meta.title ?? "",
            artist: meta.artist ?? "",
            album: meta.album ?? "",
            composer: meta.composer ?? "",
            genre: meta.genre ?? "",
            comment: meta.comment ?? "",
            lyrics: meta.lyrics ?? "",
            track: Int(meta.trackNumber),
            trackTotal: Int(meta.totalTracks),
            disc: Int(meta.discNumber),
            discTotal: Int(meta.totalDiscs),
            trackNumberText: needsTrackTextFallback
                ? preferredRawNumberText(trackNumberText, rawNumberText.track)
                : trackNumberText,
            discNumberText: needsDiscTextFallback
                ? preferredRawNumberText(discNumberText, rawNumberText.disc)
                : discNumberText,
            year: year,
            date: standaloneDate ?? "",
            albumArtist: meta.albumArtist ?? "",
            releaseDate: releaseDate ?? "",
            originalReleaseDate: originalReleaseDate ?? (meta.originalReleaseDate ?? ""),
            isrc: meta.isrc ?? "",
            barcode: meta.barcode ?? "",
            musicBrainzArtistID: meta.musicBrainzArtistId ?? "",
            musicBrainzAlbumID: meta.musicBrainzAlbumId ?? "",
            musicBrainzAlbumArtistID: meta.musicBrainzAlbumArtistId ?? "",
            musicBrainzTrackID: meta.musicBrainzTrackId ?? "",
            musicBrainzReleaseGroupID: meta.musicBrainzReleaseGroupId ?? "",
            musicBrainzReleaseTrackID: meta.musicBrainzReleaseTrackId ?? "",
            musicBrainzWorkID: meta.musicBrainzWorkId ?? "",
            acoustID: meta.acoustId ?? "",
            acoustIDFingerprint: meta.acoustIdFingerprint ?? "",
            musicIPPUID: meta.musicIpPuid ?? "",
            publisher: publisher ?? "",
            copyright: meta.copyright ?? "",
            encodedBy: encodedBy ?? "",
            encoderSettings: encoderSettings ?? "",
            sortTitle: meta.sortTitle ?? "",
            sortArtist: meta.sortArtist ?? "",
            sortAlbum: meta.sortAlbum ?? "",
            sortAlbumArtist: meta.sortAlbumArtist ?? "",
            sortComposer: meta.sortComposer ?? "",
            conductor: conductor ?? "",
            remixer: meta.remixer ?? "",
            producer: meta.producer ?? "",
            engineer: meta.engineer ?? "",
            lyricist: meta.lyricist ?? "",
            subtitle: meta.subtitle ?? "",
            grouping: grouping ?? "",
            contentGroup: contentGroup ?? "",
            artists: asfArtists ?? rawEntry(for: "ARTISTS")?.values.joined(separator: "; ") ?? "",
            movement: meta.movement ?? "",
            mood: meta.mood ?? "",
            language: meta.language ?? "",
            musicalKey: meta.musicalKey ?? "",
            replayGainTrack: meta.replayGainTrack ?? "",
            replayGainAlbum: meta.replayGainAlbum ?? "",
            replayGainTrackPeak: replayGainTrackPeak,
            replayGainAlbumPeak: replayGainAlbumPeak,
            mediaType: mediaType ?? "",
            itunesAlbumID: itunesAlbumID ?? "",
            itunesArtistID: itunesArtistID ?? "",
            itunesCatalogID: itunesCatalogID ?? "",
            itunesGenreID: itunesGenreID ?? "",
            itunesMediaType: itunesMediaType ?? "",
            itunesPurchaseDate: mp4Text("purd") ?? meta.itunesPurchaseDate ?? "",
            itunesNorm: meta.itunesNorm ?? "",
            itunesSMPB: meta.itunesSmpb ?? "",
            releaseType: meta.releaseType ?? "",
            releaseStatus: meta.releaseStatus ?? "",
            catalogNumber: meta.catalogNumber ?? "",
            releaseCountry: meta.releaseCountry ?? "",
            artistType: meta.artistType ?? "",
            asin: meta.asin ?? "",
            originalAlbum: meta.originalAlbum ?? "",
            originalArtist: meta.originalArtist ?? "",
            discSubtitle: meta.discSubtitle ?? "",
            work: work ?? "",
            movementNumber: isMP4 ? (mp4Integer("\u{00A9}mvi") ?? Int(meta.movementNumber)) : Int(meta.movementNumber),
            movementCount: isMP4 ? (mp4Integer("\u{00A9}mvc") ?? Int(meta.movementCount)) : Int(meta.movementCount),
            bpm: Int(meta.bpm),
            isCompilation: meta.compilation,
            explicitAdvisory: explicitAdvisory,
            explicitAdvisoryRawValue: explicitAdvisoryRawValue,
            director: director,
            itunesAccount: mp4Text("apID") ?? "",
            itunesComposerID: itunesComposerID,
            itunesCountryID: itunesCountryID,
            itunesGapless: itunesGapless,
            itunesHDVideo: itunesHDVideo,
            itunesOwner: itunesOwner,
            rate: rateValue,
            showMovement: showMovement,
            storeDescription: storeDescription,
            tvEpisode: tvEpisode,
            tvEpisodeID: tvEpisodeID,
            tvNetwork: tvNetwork,
            tvSeason: tvSeason,
            tvShow: tvShow,
            tvShowSort: tvShowSort,
            duration: meta.duration,
            bitrate: Int(meta.bitrate),
            sampleRate: Double(meta.sampleRate),
            channels: Int(meta.channels),
            bitDepth: Int(meta.bitDepth),
            format: meta.codec ?? "",
            artworkData: meta.artworkData as Data?,
            artworkMIMEType: normalizedArtworkMIMEType(
                meta.artworkMimeType,
                data: meta.artworkData as Data?
            ),
            customFields: customFields,
            customFieldValues: customFieldValues,
            originalCustomFieldProjection: customFields,
            originalStandardFieldValues: originalStandardFieldValues,
            originalStandardFieldProjection: originalStandardFieldProjection,
            provenance: MetadataFieldProvenance(
                trackNumberText: trackSource,
                discNumberText: discSource,
                explicitContent: explicitSource,
                artwork: artworkSource
            )
        )
    }

    nonisolated static func readBasicMetadataRawAndStructured(
        from url: URL
    ) throws -> (metadata: BasicMetadata, raw: RawMetadataDump, structured: StructuredMetadata) {
        guard let identityBeforeRead = MetadataFileIdentity.read(at: url) else {
            throw TagLibManagerError.invalidFile
        }
        let projections = try MetadataProjectionReader.complete(from: url)
        guard identityBeforeRead.hasSameReadableContents(as: MetadataFileIdentity.read(at: url)) == true else {
            throw TagLibManagerError.failedToReadWithUnderlying(
                "The audio file changed while metadata was being read."
            )
        }
        let raw = rawMetadataDump(fromBridgeDictionary: projections.raw)
        let structured = structuredMetadata(fromBridgeDictionary: projections.structured)
        return (
            basicMetadata(
                fromBridgeMetadata: projections.basic,
                rawDump: raw,
                fileExtension: url.pathExtension,
                structured: structured
            ),
            raw,
            structured
        )
    }

    public nonisolated static func readMetadataResult(from url: URL) throws -> BasicMetadata {
        try readBasicMetadataRawAndStructured(from: url).metadata
    }

    /// Reads normalized Basic metadata and the exact file version captured with it.
    /// Streams encoded audio for continuity checks as part of the same observed
    /// revision. This adds O(audio size) I/O and returns nil for unsupported layouts.
    public nonisolated static func readBasicSnapshot(
        from url: URL, includingAudioContent: Bool = false
    ) throws -> BasicMetadataSnapshot {
        try readBasicSnapshot(from: url, includingAudioContent: includingAudioContent, afterExtraction: {})
    }

    // Shares the public implementation while allowing a test to mutate the file
    // after the real native extraction and before the final version validation.
    nonisolated static func readBasicSnapshot(
        from url: URL, includingAudioContent: Bool = false, afterExtraction: () throws -> Void
    ) throws -> BasicMetadataSnapshot {
        let version = try fileVersion(at: url)
        let projections = try MetadataProjectionReader.complete(from: url)
        try afterExtraction()
        let audioIdentity = includingAudioContent ? try audioContentIdentity(at: url, version: version) : nil
        guard version == (try? fileVersion(at: url)) else {
            throw TagLibManagerError.fileChanged
        }
        let structured = structuredMetadata(fromBridgeDictionary: projections.structured)
        let metadata = basicMetadata(
            fromBridgeMetadata: projections.basic,
            rawDump: rawMetadataDump(fromBridgeDictionary: projections.raw),
            fileExtension: url.pathExtension,
            structured: structured
        )
        return BasicMetadataSnapshot(metadata: metadata, fileVersion: version, audioContentIdentity: audioIdentity)
    }

    public nonisolated static func bestEffortMetadata(from url: URL) -> BasicMetadata? {
        try? readMetadataResult(from: url)
    }

    // MARK: - Write / Erase

    @discardableResult
    public nonisolated static func bestEffortRawMetadata(from url: URL) -> RawMetadataDump? {
        try? rawMetadataResult(from: url)
    }

    public nonisolated static func rawMetadataResult(from url: URL) throws -> RawMetadataDump {
        guard let identityBeforeRead = MetadataFileIdentity.read(at: url) else {
            throw TagLibManagerError.invalidFile
        }
        let projections = try MetadataProjectionReader.extract(from: url, options: .raw)
        guard let bridgeRaw = projections["raw"] as? [String: NSObject] else {
            throw TagLibManagerError.failedToReadWithUnderlying(
                "The bridge returned an incomplete raw metadata projection set."
            )
        }
        guard identityBeforeRead.hasSameReadableContents(as: MetadataFileIdentity.read(at: url)) == true else {
            throw TagLibManagerError.failedToReadWithUnderlying(
                "The audio file changed while raw metadata was being read."
            )
        }
        return rawMetadataDump(fromBridgeDictionary: bridgeRaw)
    }

    /// Formats *raw* metadata (as seen by TagLib) into a single text blob for GUI display.
    ///
    /// This is intentionally **not** the same as the structured fields shown in the right inspector.
    /// It surfaces:
    /// - TagLib `PropertyMap` entries (including multi-value fields)
    /// - ID3v2 frames (MP3 only), including TXXX/COMM details when available
    public nonisolated static func bestEffortRawMetadataText(from url: URL) -> String? {
        // Prefer a direct text dump from the bridge if available.
        if let text = bridgeTextDumpIfAvailable(for: url) {
            return text
        }

        // Otherwise, build a readable text representation from the normalized dump models.
        guard let dump = bestEffortRawMetadata(from: url) else { return nil }

        var lines: [String] = []
        lines.append("File: \(url.lastPathComponent)")
        lines.append("Path: \(url.path)")
        lines.append("")

        lines.append("[TagLib Properties]")
        if dump.properties.isEmpty {
            lines.append("(none)")
        } else {
            for p in dump.properties {
                // Prefer showing the full values array when present.
                if !p.values.isEmpty {
                    if p.values.count == 1 {
                        lines.append("\(p.key): \(p.values[0])")
                    } else {
                        lines.append("\(p.key):")
                        for v in p.values {
                            lines.append("  - \(v)")
                        }
                    }
                } else if !p.value.isEmpty {
                    lines.append("\(p.key): \(p.value)")
                } else {
                    lines.append("\(p.key):")
                }
            }
        }

        lines.append("")
        lines.append("[ID3v2 Frames]")
        if dump.id3v2Frames.isEmpty {
            lines.append("(none)")
        } else {
            for f in dump.id3v2Frames {
                let trimmedValue = f.value.trimmingCharacters(in: .whitespacesAndNewlines)

                // Provide richer labeling for common “multi-field” frames.
                if let desc = f.description, !desc.isEmpty {
                    // Typically TXXX / COMM
                    if let lang = f.language, !lang.isEmpty {
                        lines.append("\(f.frameID) [\(lang)] (\(desc)): \(trimmedValue)")
                    } else {
                        lines.append("\(f.frameID) (\(desc)): \(trimmedValue)")
                    }
                } else {
                    lines.append("\(f.frameID): \(trimmedValue)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }


}
