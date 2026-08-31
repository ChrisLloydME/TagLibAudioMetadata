//
//  TagLibMetadataManager+Read.swift
//  TagLibAudioMetadata
//

import Foundation
import CTagLibBridge

public struct MetadataExtractionOptions: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let basic = MetadataExtractionOptions(rawValue: 1 << 0)
    public static let raw = MetadataExtractionOptions(rawValue: 1 << 1)
    public static let structured = MetadataExtractionOptions(rawValue: 1 << 2)
    public static let all: MetadataExtractionOptions = [.basic, .raw, .structured]
}

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

    nonisolated static func bridgeMetadataProjectionDictionary(
        from url: URL,
        options: MetadataExtractionOptions
    ) throws -> [String: NSObject] {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isSupportedFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        do {
            return try TagLibMetadataExtractor.metadataProjections(
                for: url,
                options: TagLibMetadataExtractionOptions(rawValue: options.rawValue)
            )
        } catch {
            throw TagLibManagerError.failedToReadWithUnderlying(String(describing: error))
        }
    }

    nonisolated static func bridgeMetadataProjections(
        from url: URL
    ) throws -> (basic: TagLibAudioMetadata, raw: [String: NSObject], structured: [String: NSObject]) {
        do {
            let projections = try bridgeMetadataProjectionDictionary(from: url, options: .all)
            guard let basic = projections["basic"] as? TagLibAudioMetadata,
                  let raw = projections["raw"] as? [String: NSObject],
                  let structured = projections["structured"] as? [String: NSObject] else {
                throw TagLibManagerError.failedToReadWithUnderlying(
                    "The bridge returned an incomplete metadata projection set."
                )
            }
            return (basic, raw, structured)
        } catch let managerError as TagLibManagerError {
            throw managerError
        } catch {
            throw TagLibManagerError.failedToReadWithUnderlying(String(describing: error))
        }
    }

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

    /// Return a single plain-text dump of metadata as TagLib sees it.
    ///
    /// Preferred path: call the ObjC++ bridge API directly (Swift `throws`).
    /// Fallback path: attempt older single-argument selector names via `perform` for compatibility.
    nonisolated static func bridgeTextDumpIfAvailable(for url: URL) -> String? {
        // Newer bridge (preferred): `dumpMetadataText(from:)` is exposed as a Swift-throwing method.
        if let text = try? TagLibMetadataExtractor.dumpMetadataText(from: url) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }

        // Older bridge variants: try a small set of single-argument selector names at runtime.
        let candidates = [
            "rawMetadataTextFor:",
            "rawMetadataTextForURL:",
            "dumpMetadataTextFor:",
            "dumpMetadataTextFrom:",
            "dumpMetadataTextFromURL:",
            "dumpMetadataTextForURL:"
        ]

        for name in candidates {
            let sel = NSSelectorFromString(name)
            guard TagLibMetadataExtractor.responds(to: sel) else { continue }

            // perform(_:with:) only supports single-argument selectors.
            if let unmanaged = TagLibMetadataExtractor.perform(sel, with: url) {
                let any = unmanaged.takeUnretainedValue()
                if let s = any as? String {
                    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
                if let s = any as? NSString {
                    let trimmed = (s as String).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
        }

        return nil
    }

    nonisolated static func basicMetadata(
        fromBridgeMetadata meta: TagLibAudioMetadata,
        rawDump: RawMetadataDump
    ) -> BasicMetadata {
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
        case .clean: .clean
        case .explicit: .explicit
        default: .unspecified
        }
        let customFields = meta.customFields ?? [:]
        let customFieldValues = customFields.reduce(into: [String: [String]]()) { result, field in
            let rawValues = rawDump.properties.first {
                $0.key.caseInsensitiveCompare(field.key) == .orderedSame
            }?.values ?? []
            result[field.key] = rawValues.isEmpty ? [field.value] : rawValues
        }
        var originalStandardFieldValues: [String: [String]] = [:]
        var originalStandardFieldProjection: [String: String] = [:]
        for schema in MetadataFieldRegistry.allSchemas where schema.isMultiValue {
            guard let entry = rawDump.properties.first(where: { entry in
                schema.propertyMapKeys.contains {
                    $0.caseInsensitiveCompare(entry.key) == .orderedSame
                }
            }), !entry.values.isEmpty,
            let projection = bridgeProjectionValue(for: schema.key, metadata: meta) else {
                continue
            }
            originalStandardFieldValues[entry.key] = entry.values
            originalStandardFieldProjection[entry.key] = projection
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
            year: meta.year ?? "",
            albumArtist: meta.albumArtist ?? "",
            releaseDate: meta.releaseDate ?? "",
            originalReleaseDate: meta.originalReleaseDate ?? "",
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
            publisher: meta.label ?? "",
            copyright: meta.copyright ?? "",
            encodedBy: meta.encodedBy ?? "",
            encoderSettings: meta.encoderSettings ?? "",
            sortTitle: meta.sortTitle ?? "",
            sortArtist: meta.sortArtist ?? "",
            sortAlbum: meta.sortAlbum ?? "",
            sortAlbumArtist: meta.sortAlbumArtist ?? "",
            sortComposer: meta.sortComposer ?? "",
            conductor: meta.conductor ?? "",
            remixer: meta.remixer ?? "",
            producer: meta.producer ?? "",
            engineer: meta.engineer ?? "",
            lyricist: meta.lyricist ?? "",
            subtitle: meta.subtitle ?? "",
            grouping: meta.grouping ?? "",
            movement: meta.movement ?? "",
            mood: meta.mood ?? "",
            language: meta.language ?? "",
            musicalKey: meta.musicalKey ?? "",
            replayGainTrack: meta.replayGainTrack ?? "",
            replayGainAlbum: meta.replayGainAlbum ?? "",
            mediaType: meta.mediaType ?? "",
            itunesAlbumID: meta.itunesAlbumId ?? "",
            itunesArtistID: meta.itunesArtistId ?? "",
            itunesCatalogID: meta.itunesCatalogId ?? "",
            itunesGenreID: meta.itunesGenreId ?? "",
            itunesMediaType: meta.itunesMediaType ?? "",
            itunesPurchaseDate: meta.itunesPurchaseDate ?? "",
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
            work: meta.work ?? "",
            movementNumber: Int(meta.movementNumber),
            movementCount: Int(meta.movementCount),
            bpm: Int(meta.bpm),
            isCompilation: meta.compilation,
            explicitAdvisory: explicitAdvisory,
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

    public nonisolated static func readMetadataResult(from url: URL) throws -> BasicMetadata {
        let identityBeforeRead = regularFileIdentity(at: url)
        let projections = try bridgeMetadataProjectionDictionary(from: url, options: [.basic, .raw])
        guard let bridgeBasic = projections["basic"] as? TagLibAudioMetadata,
              let bridgeRaw = projections["raw"] as? [String: NSObject] else {
            throw TagLibManagerError.failedToReadWithUnderlying(
                "The bridge returned an incomplete Basic metadata projection set."
            )
        }
        guard identityBeforeRead == regularFileIdentity(at: url) else {
            throw TagLibManagerError.failedToReadWithUnderlying(
                "The audio file changed while metadata was being read."
            )
        }
        return basicMetadata(
            fromBridgeMetadata: bridgeBasic,
            rawDump: rawMetadataDump(fromBridgeDictionary: bridgeRaw)
        )
    }

    public nonisolated static func readMetadata(from url: URL) -> BasicMetadata? {
        do {
            return try readMetadataResult(from: url)
        } catch {
            print("TagLib read error for \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    // MARK: - Write / Erase

    @discardableResult
    public nonisolated static func rawMetadata(from url: URL) -> RawMetadataDump? {
        try? rawMetadataResult(from: url)
    }

    public nonisolated static func rawMetadataResult(from url: URL) throws -> RawMetadataDump {
        let identityBeforeRead = regularFileIdentity(at: url)
        let projections = try bridgeMetadataProjectionDictionary(from: url, options: .raw)
        guard let bridgeRaw = projections["raw"] as? [String: NSObject] else {
            throw TagLibManagerError.failedToReadWithUnderlying(
                "The bridge returned an incomplete raw metadata projection set."
            )
        }
        guard identityBeforeRead == regularFileIdentity(at: url) else {
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
    public nonisolated static func rawMetadataText(from url: URL) -> String? {
        // Prefer a direct text dump from the bridge if available.
        if let text = bridgeTextDumpIfAvailable(for: url) {
            return text
        }

        // Otherwise, build a readable text representation from the normalized dump models.
        guard let dump = rawMetadata(from: url) else { return nil }

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
