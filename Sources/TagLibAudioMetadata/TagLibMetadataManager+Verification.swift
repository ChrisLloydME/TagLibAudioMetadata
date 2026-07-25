//
//  TagLibMetadataManager+Verification.swift
//  TagLibAudioMetadata
//

import Foundation

extension TagLibMetadataManager {
    nonisolated static func isHiddenInternalRawFieldKey(_ key: String) -> Bool {
        hiddenInternalRawFieldKeys.contains(
            key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        )
    }

    nonisolated static func normalizedTrimmed(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func parseNumberPair(_ value: String) -> (number: Int, total: Int) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (0, 0) }

        let parts = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let number = parts.first.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
        let total = parts.count > 1
            ? Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            : 0
        return (max(0, number), max(0, total))
    }

    nonisolated static func numberPairEquivalent(_ lhs: String?, _ rhs: String?) -> Bool {
        parseNumberPair(normalizedTrimmed(lhs)) == parseNumberPair(normalizedTrimmed(rhs))
    }

    nonisolated static func rawPropertiesLookup(_ dump: RawMetadataDump) -> [String: [String]] {
        dump.properties.reduce(into: [:]) { result, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !key.isEmpty else { return }

            let mergedValues = (entry.values + [entry.value])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !mergedValues.isEmpty else { return }

            var existing = result[key] ?? []
            existing.append(contentsOf: mergedValues)
            result[key] = Array(Set(existing))
        }
    }

    nonisolated static func rawContainsCustomKey(_ key: String, dump: RawMetadataDump) -> Bool {
        let expected = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !expected.isEmpty else { return true }

        let acceptedKeys = normalizedRawKeyAliases(for: expected)
        for property in dump.properties {
            let candidate = property.key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if acceptedKeys.contains(candidate) {
                return true
            }
        }

        return false
    }

    nonisolated static func normalizedRawKeyAliases(for key: String) -> Set<String> {
        var aliases: Set<String> = [key]

        let mp4FreeformPrefix = "----:COM.APPLE.ITUNES:"
        if key.hasPrefix(mp4FreeformPrefix) {
            aliases.insert(String(key.dropFirst(mp4FreeformPrefix.count)))
        } else {
            aliases.insert("\(mp4FreeformPrefix)\(key)")
        }

        return aliases
    }

    nonisolated static func applyVerificationFailurePolicy(
        _ policy: VerificationFailurePolicy,
        warnings: [String]
    ) throws {
        guard policy == .throw, !warnings.isEmpty else { return }
        throw TagLibManagerError.verificationFailed(warnings)
    }

    nonisolated static func explicitValueSource(from dump: RawMetadataDump, fallback: Bool) -> MetadataValueSource {
        let explicitKeys = Set(["ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT", "RTNG"])
        if dump.properties.contains(where: { entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return explicitKeys.contains(key) || key.hasSuffix(":ITUNESADVISORY")
        }) {
            return .propertyMap
        }

        if dump.id3v2Frames.contains(where: { frame in
            if frame.frameID.uppercased() == "TXXX" {
                let description = frame.description?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
                return description == "ITUNESADVISORY" || description == "EXPLICIT"
            }
            return false
        }) {
            return .id3v2Frame
        }

        return fallback ? .nativeTag : .none
    }

    nonisolated static func hasVerificationExpectations(_ verification: MetadataWriteVerificationContext) -> Bool {
        if verification.expectedTrackNumber != nil || verification.expectedTrackTotal != nil {
            return true
        }

        if let expectedTrack = verification.expectedTrackNumberText,
           !normalizedTrimmed(expectedTrack).isEmpty {
            return true
        }

        if verification.expectedDiscNumber != nil || verification.expectedDiscTotal != nil {
            return true
        }

        if let expectedDisc = verification.expectedDiscNumberText,
           !normalizedTrimmed(expectedDisc).isEmpty {
            return true
        }

        if verification.expectedExplicitContent != nil {
            return true
        }

        if !verification.expectedTextFields.isEmpty {
            return true
        }

        switch verification.artworkExpectation {
        case .unchanged:
            break
        case .present, .absent:
            return true
        }

        return !verification.customFieldKeys.isEmpty
    }

    nonisolated static func metadataWriteWarnings(
        for url: URL,
        verification: MetadataWriteVerificationContext
    ) -> [String] {
        guard hasVerificationExpectations(verification) else { return [] }

        var warnings: [String] = []
        let afterWrite = readMetadata(from: url)
        let rawDump = rawMetadata(from: url)

        if afterWrite == nil {
            warnings.append("Could not verify metadata after save because the file could not be re-read.")
        }

        if let afterWrite {
            for (field, expectedValue) in verification.expectedTextFields {
                let expected = normalizedTrimmed(expectedValue)
                let actual = normalizedTrimmed(textFieldValue(field, from: afterWrite))
                if expected != actual {
                    warnings.append(
                        "\(field) differs after save (expected \"\(expected)\", got \"\(actual)\")."
                    )
                }
            }

            if let expectedTrackNumber = verification.expectedTrackNumber,
               afterWrite.track != expectedTrackNumber {
                warnings.append(
                    "Track number differs after save (expected \(expectedTrackNumber), got \(afterWrite.track))."
                )
            }

            if let expectedTrackTotal = verification.expectedTrackTotal,
               afterWrite.trackTotal != expectedTrackTotal {
                warnings.append(
                    "Total tracks differs after save (expected \(expectedTrackTotal), got \(afterWrite.trackTotal))."
                )
            }
        }

        if let expectedTrack = verification.expectedTrackNumberText,
           !normalizedTrimmed(expectedTrack).isEmpty,
           let afterWrite {
            let expectedPair = parseNumberPair(expectedTrack)
            let pairStoredAcrossFields =
                afterWrite.track == expectedPair.number && afterWrite.trackTotal == expectedPair.total
            if !numberPairEquivalent(expectedTrack, afterWrite.trackNumberText) && !pairStoredAcrossFields {
                warnings.append(
                    "Track number text differs after save (expected \(expectedTrack), got \(afterWrite.trackNumberText))."
                )
            } else if normalizedTrimmed(expectedTrack) != normalizedTrimmed(afterWrite.trackNumberText) {
                warnings.append(
                    "Track number formatting was normalized by the container (\(expectedTrack) -> \(afterWrite.trackNumberText))."
                )
            }
        }

        if let afterWrite {
            if let expectedDiscNumber = verification.expectedDiscNumber,
               afterWrite.disc != expectedDiscNumber {
                warnings.append(
                    "Disc number differs after save (expected \(expectedDiscNumber), got \(afterWrite.disc))."
                )
            }

            if let expectedDiscTotal = verification.expectedDiscTotal,
               afterWrite.discTotal != expectedDiscTotal {
                warnings.append(
                    "Total discs differs after save (expected \(expectedDiscTotal), got \(afterWrite.discTotal))."
                )
            }
        }

        if let expectedDisc = verification.expectedDiscNumberText,
           !normalizedTrimmed(expectedDisc).isEmpty,
           let afterWrite {
            let expectedPair = parseNumberPair(expectedDisc)
            let pairStoredAcrossFields =
                afterWrite.disc == expectedPair.number && afterWrite.discTotal == expectedPair.total
            if !numberPairEquivalent(expectedDisc, afterWrite.discNumberText) && !pairStoredAcrossFields {
                warnings.append(
                    "Disc number text differs after save (expected \(expectedDisc), got \(afterWrite.discNumberText))."
                )
            } else if normalizedTrimmed(expectedDisc) != normalizedTrimmed(afterWrite.discNumberText) {
                warnings.append(
                    "Disc number formatting was normalized by the container (\(expectedDisc) -> \(afterWrite.discNumberText))."
                )
            }
        }

        if let expectedExplicit = verification.expectedExplicitContent, let afterWrite {
            if expectedExplicit != afterWrite.isExplicit {
                warnings.append(
                    "Explicit flag differs after save (expected \(expectedExplicit ? "explicit" : "clean"), got \(afterWrite.isExplicit ? "explicit" : "clean"))."
                )
            }
        }

        if let afterWrite {
            switch verification.artworkExpectation {
            case .unchanged:
                break
            case .present:
                if afterWrite.artworkData == nil {
                    warnings.append("Artwork was expected to be present after save but no embedded artwork was found.")
                }
            case .absent:
                if afterWrite.artworkData != nil {
                    warnings.append("Artwork was expected to be removed but embedded artwork is still present.")
                }
            }
        }

        if !verification.customFieldKeys.isEmpty {
            guard let rawDump else {
                warnings.append("Could not verify custom field preservation after save.")
                return warnings
            }

            for key in verification.customFieldKeys where !rawContainsCustomKey(key, dump: rawDump) {
                warnings.append("Custom field \"\(key)\" could not be confirmed after save.")
            }
        }

        return warnings
    }

    nonisolated static func textFieldValue(_ field: String, from metadata: BasicMetadata) -> String {
        switch field {
        case "title": metadata.title
        case "artist": metadata.artist
        case "album": metadata.album
        case "composer": metadata.composer
        case "genre": metadata.genre
        case "comment": metadata.comment
        case "lyrics": metadata.lyrics
        case "year": metadata.year
        case "albumArtist": metadata.albumArtist
        case "releaseDate": metadata.releaseDate
        case "originalReleaseDate": metadata.originalReleaseDate
        case "publisher": metadata.publisher
        case "copyright": metadata.copyright
        case "encodedBy": metadata.encodedBy
        case "encoderSettings": metadata.encoderSettings
        case "isrc": metadata.isrc
        case "barcode": metadata.barcode
        case "sortTitle": metadata.sortTitle
        case "sortArtist": metadata.sortArtist
        case "sortAlbum": metadata.sortAlbum
        case "sortAlbumArtist": metadata.sortAlbumArtist
        case "sortComposer": metadata.sortComposer
        case "conductor": metadata.conductor
        case "remixer": metadata.remixer
        case "producer": metadata.producer
        case "engineer": metadata.engineer
        case "lyricist": metadata.lyricist
        case "subtitle": metadata.subtitle
        case "grouping": metadata.grouping
        case "movement": metadata.movement
        case "mood": metadata.mood
        case "language": metadata.language
        case "musicalKey": metadata.musicalKey
        case "replayGainTrack": metadata.replayGainTrack
        case "replayGainAlbum": metadata.replayGainAlbum
        case "mediaType": metadata.mediaType
        case "itunesAlbumID": metadata.itunesAlbumID
        case "itunesArtistID": metadata.itunesArtistID
        case "itunesCatalogID": metadata.itunesCatalogID
        case "itunesGenreID": metadata.itunesGenreID
        case "itunesMediaType": metadata.itunesMediaType
        case "itunesPurchaseDate": metadata.itunesPurchaseDate
        case "itunesNorm": metadata.itunesNorm
        case "itunesSMPB": metadata.itunesSMPB
        case "releaseType": metadata.releaseType
        case "releaseStatus": metadata.releaseStatus
        case "catalogNumber": metadata.catalogNumber
        case "releaseCountry": metadata.releaseCountry
        case "artistType": metadata.artistType
        case "asin": metadata.asin
        case "originalAlbum": metadata.originalAlbum
        case "originalArtist": metadata.originalArtist
        case "discSubtitle": metadata.discSubtitle
        case "work": metadata.work
        case "musicBrainzArtistID": metadata.musicBrainzArtistID
        case "musicBrainzAlbumID": metadata.musicBrainzAlbumID
        case "musicBrainzAlbumArtistID": metadata.musicBrainzAlbumArtistID
        case "musicBrainzTrackID": metadata.musicBrainzTrackID
        case "musicBrainzReleaseGroupID": metadata.musicBrainzReleaseGroupID
        case "musicBrainzReleaseTrackID": metadata.musicBrainzReleaseTrackID
        case "musicBrainzWorkID": metadata.musicBrainzWorkID
        case "acoustID": metadata.acoustID
        case "acoustIDFingerprint": metadata.acoustIDFingerprint
        case "musicIPPUID": metadata.musicIPPUID
        case "movementNumber": String(metadata.movementNumber)
        case "movementCount": String(metadata.movementCount)
        case "bpm": String(metadata.bpm)
        case "isCompilation": String(metadata.isCompilation)
        default: ""
        }
    }

    nonisolated static func rawPropertyMapWriteWarnings(
        requestedProperties: [String: String],
        for url: URL
    ) -> [String] {
        guard !requestedProperties.isEmpty else { return [] }
        guard let rawDump = rawMetadata(from: url) else {
            return ["Could not verify raw metadata write after save."]
        }

        var warnings: [String] = []
        let lookup = rawPropertiesLookup(rawDump)
        let riskyNumberKeys = Set([
            "TRACKNUMBER", "TRACK", "TRACKTOTAL", "TOTALTRACKS",
            "DISCNUMBER", "DISC", "DISCTOTAL", "TOTALDISCS"
        ])
        let riskyExplicitKeys = Set(["ITUNESADVISORY", "ADVISORY", "EXPLICITCONTENT", "EXPLICIT"])

        for (rawKey, rawValue) in requestedProperties {
            let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }

            if value.isEmpty {
                if lookup.keys.contains(where: { normalizedRawKeyAliases(for: key).contains($0) }) {
                    warnings.append("Raw key \"\(rawKey)\" was expected to be removed after save.")
                }
                continue
            }

            let aliasKeys = normalizedRawKeyAliases(for: key)
            let persistedValues = aliasKeys
                .compactMap { lookup[$0] }
                .flatMap { $0 }

            guard !persistedValues.isEmpty else {
                warnings.append("Raw key \"\(rawKey)\" was not found after save.")
                continue
            }

            if riskyNumberKeys.contains(key) {
                let expectedPair = parseNumberPair(value)
                let pairMatched = persistedValues.contains { parseNumberPair($0) == expectedPair }
                if !pairMatched {
                    warnings.append("Raw number key \"\(rawKey)\" differs after save.")
                }
                continue
            }

            if riskyExplicitKeys.contains(key) {
                let normalizedPersisted = persistedValues.map { $0.uppercased() }
                if !normalizedPersisted.contains(value.uppercased()) {
                    warnings.append("Raw explicit key \"\(rawKey)\" differs after save.")
                }
                continue
            }

            if !persistedValues.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                warnings.append("Raw key \"\(rawKey)\" value changed after save.")
            }
        }

        return warnings
    }

    nonisolated static func resolvedRawPropertyMapValuesForMerge(
        _ properties: [String: String],
        to url: URL
    ) throws -> [String: [String]] {
        var merged = try rawMetadataResult(from: url).properties.reduce(into: [String: [String]]()) { result, entry in
                let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { return }

                let sourceValues = entry.values.isEmpty ? [entry.value] : entry.values
                let values = sourceValues
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                guard !values.isEmpty else { return }
                result[key, default: []].append(contentsOf: values)
        }

        for (rawKey, rawValue) in properties {
            let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }

            let normalizedAliases = normalizedRawKeyAliases(for: key.uppercased())
            for existingKey in Array(merged.keys) where normalizedAliases.contains(existingKey.uppercased()) {
                merged.removeValue(forKey: existingKey)
            }

            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                merged[key] = [value]
            }
        }

        return merged
    }

    nonisolated static func parsedPropertyEntries(fromDumpText text: String) -> [RawPropertyEntry] {
        var isInPropertiesSection = false
        var properties: [RawPropertyEntry] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") {
                if isInPropertiesSection {
                    break
                }

                isInPropertiesSection = (trimmedLine == "[TagLib Properties]")
                continue
            }

            guard isInPropertiesSection else { continue }
            guard !trimmedLine.isEmpty else { continue }

            if trimmedLine == "(none)" || trimmedLine.hasPrefix("(unable to open") {
                break
            }

            guard let separatorRange = trimmedLine.range(of: " = ") else { continue }

            let key = String(trimmedLine[..<separatorRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmedLine[separatorRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !isHiddenInternalRawFieldKey(key) else { continue }
            guard !key.isEmpty, !value.isEmpty else { continue }

            let values = value
                .components(separatedBy: "; ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            properties.append(
                RawPropertyEntry(
                    key: key,
                    value: value,
                    values: values,
                    count: values.count
                )
            )
        }

        return properties.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

}
