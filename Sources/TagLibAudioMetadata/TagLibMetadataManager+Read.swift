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

extension TagLibMetadataManager {
    // MARK: - Bridge Dump API

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

    public nonisolated static func readMetadataResult(from url: URL) throws -> BasicMetadata {
        // 1. Quickly filter by file extension.
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { throw TagLibManagerError.unsupportedFormat }

        if !TagLibMetadataExtractor.isSupportedFormat(ext) {
            throw TagLibManagerError.unsupportedFormat
        }

        do {
            let identityBeforeRead = regularFileIdentity(at: url)
            // ObjC++ bridge API imported into Swift as `throws`.
            let meta = try TagLibMetadataExtractor.extractMetadata(from: url)
            let trackNumberText = meta.trackNumberText ?? ""
            let discNumberText = meta.discNumberText ?? ""
            let needsTrackTextFallback =
                trackNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                meta.trackNumber > 0
            let needsDiscTextFallback =
                discNumberText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                meta.discNumber > 0

            var rawDump: RawMetadataDump?
            let rawNumberText: (track: String, disc: String)
            if needsTrackTextFallback || needsDiscTextFallback {
                rawDump = rawMetadata(from: url)
                rawNumberText = rawDump.map(rawNumberTexts(from:)) ?? (track: "", disc: "")
            } else {
                rawNumberText = (track: "", disc: "")
            }

            if case nil = rawDump {
                rawDump = rawMetadata(from: url)
            }

            guard identityBeforeRead == regularFileIdentity(at: url) else {
                throw TagLibManagerError.failedToReadWithUnderlying(
                    "The audio file changed while metadata was being read."
                )
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

            let explicitSource = rawDump.map {
                explicitValueSource(from: $0, fallback: meta.explicitAdvisory != .unspecified)
            } ?? (meta.explicitAdvisory == .unspecified ? .none : .nativeTag)
            let artworkSource: MetadataValueSource = (meta.artworkData as Data?) == nil ? .none : .nativeTag
            let explicitAdvisory: ExplicitAdvisory = switch meta.explicitAdvisory {
            case .clean: .clean
            case .explicit: .explicit
            default: .unspecified
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
                customFields: meta.customFields ?? [:],
                provenance: MetadataFieldProvenance(
                    trackNumberText: trackSource,
                    discNumberText: discSource,
                    explicitContent: explicitSource,
                    artwork: artworkSource
                )
            )
        } catch {
            if let managerError = error as? TagLibManagerError {
                throw managerError
            }
            throw TagLibManagerError.failedToReadWithUnderlying(String(describing: error))
        }
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
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else {
            throw TagLibManagerError.unsupportedFormat
        }

        guard TagLibMetadataExtractor.isSupportedFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        // ObjC++ returns a Foundation dictionary for display; normalize it into Swift models.
        let dict: [String: NSObject]
        do {
            dict = try TagLibMetadataExtractor.rawMetadata(for: url)
        } catch {
            throw TagLibManagerError.failedToReadWithUnderlying(String(describing: error))
        }

        let propsAny = dict["properties"] as? [Any] ?? []
        let framesAny = dict["id3v2Frames"] as? [Any] ?? []

        let properties: [RawPropertyEntry] = propsAny.compactMap { item in
            guard let d = item as? NSDictionary else { return nil }

            let key = d["key"] as? String ?? ""
            let value = d["value"] as? String ?? ""

            let values: [String]
            if let arr = d["values"] as? [String] {
                values = arr
            } else if let arr = d["values"] as? [Any] {
                values = arr.compactMap { $0 as? String }
            } else {
                values = []
            }

            let count: Int
            if let n = d["count"] as? Int {
                count = n
            } else if let n = d["count"] as? NSNumber {
                count = n.intValue
            } else {
                count = values.count
            }

            guard !isHiddenInternalRawFieldKey(key) else { return nil }

            return RawPropertyEntry(key: key, value: value, values: values, count: count)
        }
        .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }

        let id3v2Frames: [RawID3v2FrameEntry] = framesAny.compactMap { item in
            guard let d = item as? NSDictionary else { return nil }

            let frameID = d["id"] as? String ?? ""
            let value = d["value"] as? String ?? ""
            let desc = d["description"] as? String
            let lang = d["language"] as? String

            return RawID3v2FrameEntry(frameID: frameID, value: value, description: desc, language: lang)
        }

        if !properties.isEmpty {
            return RawMetadataDump(properties: properties, id3v2Frames: id3v2Frames)
        }

        if let dumpText = try? TagLibMetadataExtractor.dumpMetadataText(from: url) {
            let fallbackProperties = parsedPropertyEntries(fromDumpText: dumpText)
            if !fallbackProperties.isEmpty {
                return RawMetadataDump(properties: fallbackProperties, id3v2Frames: id3v2Frames)
            }
        }

        return RawMetadataDump(properties: properties, id3v2Frames: id3v2Frames)
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
