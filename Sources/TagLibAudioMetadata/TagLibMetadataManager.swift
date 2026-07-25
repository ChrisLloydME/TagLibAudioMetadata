//
//  TagLibMetadataManager.swift
//  AudioMator
//

import Foundation
import Darwin
@_exported import CTagLibBridge

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
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
public struct TagLibMetadataManager {

    nonisolated private static let errorDomain = "TagLibMetadataManager"

    nonisolated private struct FileIdentity: Equatable {
        var device: dev_t
        var inode: ino_t
    }

    nonisolated private static func regularFileIdentity(at url: URL) -> FileIdentity? {
        var information = stat()
        let status = url.path.withCString { path in
            Darwin.lstat(path, &information)
        }
        let fileType = information.st_mode & mode_t(S_IFMT)
        guard status == 0, fileType == mode_t(S_IFREG) else { return nil }
        return FileIdentity(device: information.st_dev, inode: information.st_ino)
    }

    nonisolated private static func mutationError(
        code: Int,
        description: String,
        underlying: Error? = nil
    ) -> NSError {
        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: description]
        if let underlying {
            userInfo[NSUnderlyingErrorKey] = underlying
        }
        return NSError(domain: errorDomain, code: code, userInfo: userInfo)
    }

    /// Runs the complete mutation and verification sequence on a sibling copy.
    /// The destination is replaced with a same-volume atomic rename only after
    /// every step succeeds, so thrown bridge or verification errors preserve it.
    nonisolated private static func withAtomicFileMutation<Result>(
        at url: URL,
        _ operation: (URL) throws -> Result
    ) throws -> Result {
        guard url.isFileURL else {
            throw mutationError(code: 1001, description: "Metadata mutations require a file URL.")
        }

        guard let originalIdentity = regularFileIdentity(at: url) else {
            throw mutationError(
                code: 1003,
                description: "Metadata mutations require an existing regular file and do not follow symbolic links."
            )
        }

        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        } catch {
            throw mutationError(
                code: 1002,
                description: "Could not inspect the metadata destination.",
                underlying: error
            )
        }

        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw mutationError(
                code: 1003,
                description: "Metadata mutations require an existing regular file and do not follow symbolic links."
            )
        }

        do {
            _ = try readMetadataResult(from: url)
        } catch {
            throw mutationError(
                code: 1006,
                description: "The metadata destination is not a readable, valid audio file.",
                underlying: error
            )
        }

        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let baseName = url.deletingPathExtension().lastPathComponent
        let temporaryName = ext.isEmpty
            ? ".\(baseName).taglib-\(UUID().uuidString)"
            : ".\(baseName).taglib-\(UUID().uuidString).\(ext)"
        let temporaryURL = directory.appendingPathComponent(temporaryName)
        var shouldRemoveTemporaryFile = true

        defer {
            if shouldRemoveTemporaryFile {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }

        do {
            try fileManager.copyItem(at: url, to: temporaryURL)
        } catch {
            throw mutationError(
                code: 1004,
                description: "Could not create a transactional copy of the metadata destination.",
                underlying: error
            )
        }

        guard regularFileIdentity(at: temporaryURL) != nil else {
            throw mutationError(
                code: 1004,
                description: "The transactional metadata copy is not a regular file."
            )
        }

        let result = try operation(temporaryURL)
        let temporaryDescriptor = temporaryURL.path.withCString { temporaryPath in
            Darwin.open(temporaryPath, O_RDONLY)
        }
        guard temporaryDescriptor >= 0 else {
            let openErrorCode = errno
            throw mutationError(
                code: 1005,
                description: "Could not open the verified metadata mutation for flushing.",
                underlying: NSError(domain: NSPOSIXErrorDomain, code: Int(openErrorCode))
            )
        }

        guard Darwin.fsync(temporaryDescriptor) == 0 else {
            let syncErrorCode = errno
            Darwin.close(temporaryDescriptor)
            throw mutationError(
                code: 1005,
                description: "Could not flush the verified metadata mutation before commit.",
                underlying: NSError(domain: NSPOSIXErrorDomain, code: Int(syncErrorCode))
            )
        }
        Darwin.close(temporaryDescriptor)

        guard regularFileIdentity(at: url) == originalIdentity else {
            throw mutationError(
                code: 1005,
                description: "The metadata destination changed before the transaction could commit."
            )
        }

        let renameResult = temporaryURL.path.withCString { temporaryPath in
            url.path.withCString { destinationPath in
                Darwin.rename(temporaryPath, destinationPath)
            }
        }
        let renameErrorCode = errno

        guard renameResult == 0 else {
            let underlying = NSError(domain: NSPOSIXErrorDomain, code: Int(renameErrorCode))
            throw mutationError(
                code: 1005,
                description: "Could not atomically commit the metadata mutation.",
                underlying: underlying
            )
        }

        shouldRemoveTemporaryFile = false
        return result
    }

    nonisolated private static let hiddenInternalRawFieldKeys: Set<String> = [
        "AUDIOMATOR_TRACKNUMBER_TEXT",
        "AUDIOMATOR_DISCNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:AUDIOMATOR_TRACKNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:AUDIOMATOR_DISCNUMBER_TEXT",
    ]

    public enum ArtworkVerificationExpectation: Sendable {
        case unchanged
        case present
        case absent
    }

    public struct MetadataWriteVerificationContext: Equatable, Sendable {
        public var expectedTrackNumber: Int?
        public var expectedTrackTotal: Int?
        public var expectedTrackNumberText: String?
        public var expectedDiscNumber: Int?
        public var expectedDiscTotal: Int?
        public var expectedDiscNumberText: String?
        public var expectedExplicitContent: Bool?
        public var artworkExpectation: ArtworkVerificationExpectation
        public var customFieldKeys: [String]
        public var expectedTextFields: [String: String]

        public init(
            expectedTrackNumber: Int?,
            expectedTrackTotal: Int?,
            expectedTrackNumberText: String?,
            expectedDiscNumber: Int?,
            expectedDiscTotal: Int?,
            expectedDiscNumberText: String?,
            expectedExplicitContent: Bool?,
            artworkExpectation: ArtworkVerificationExpectation,
            customFieldKeys: [String],
            expectedTextFields: [String: String] = [:]
        ) {
            self.expectedTrackNumber = expectedTrackNumber
            self.expectedTrackTotal = expectedTrackTotal
            self.expectedTrackNumberText = expectedTrackNumberText
            self.expectedDiscNumber = expectedDiscNumber
            self.expectedDiscTotal = expectedDiscTotal
            self.expectedDiscNumberText = expectedDiscNumberText
            self.expectedExplicitContent = expectedExplicitContent
            self.artworkExpectation = artworkExpectation
            self.customFieldKeys = customFieldKeys
            self.expectedTextFields = expectedTextFields
        }

        public nonisolated static let none = MetadataWriteVerificationContext(
            expectedTrackNumber: nil,
            expectedTrackTotal: nil,
            expectedTrackNumberText: nil,
            expectedDiscNumber: nil,
            expectedDiscTotal: nil,
            expectedDiscNumberText: nil,
            expectedExplicitContent: nil,
            artworkExpectation: .unchanged,
            customFieldKeys: [],
            expectedTextFields: [:]
        )
    }

    public struct MetadataWriteResult: Sendable {
        public var warnings: [String]

        public init(warnings: [String]) {
            self.warnings = warnings
        }
    }

    public enum RawPropertyMapWriteMode: Sendable {
        /// Replace the file's TagLib PropertyMap with exactly the provided key/value pairs.
        case replace

        /// Merge the provided key/value pairs into the current TagLib PropertyMap.
        ///
        /// Empty values remove matching keys, mirroring the bridge's existing trimming behavior.
        case merge
    }

    public enum VerificationFailurePolicy: Sendable {
        case warn
        case `throw`
    }

    public nonisolated static func isReadableFormat(_ fileExtension: String) -> Bool {
        TagLibMetadataExtractor.isSupportedFormat(fileExtension)
    }

    public nonisolated static func isWritableFormat(_ fileExtension: String) -> Bool {
        TagLibMetadataExtractor.isWritableFormat(fileExtension)
    }

    public nonisolated static var readableExtensions: [String] {
        TagLibMetadataExtractor.supportedExtensions()
    }

    public nonisolated static var writableExtensions: [String] {
        TagLibMetadataExtractor.writableExtensions()
    }

    nonisolated private static func isHiddenInternalRawFieldKey(_ key: String) -> Bool {
        hiddenInternalRawFieldKeys.contains(
            key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        )
    }

    nonisolated private static func normalizedTrimmed(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func parseNumberPair(_ value: String) -> (number: Int, total: Int) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (0, 0) }

        let parts = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let number = parts.first.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
        let total = parts.count > 1
            ? Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            : 0
        return (max(0, number), max(0, total))
    }

    nonisolated private static func numberPairEquivalent(_ lhs: String?, _ rhs: String?) -> Bool {
        parseNumberPair(normalizedTrimmed(lhs)) == parseNumberPair(normalizedTrimmed(rhs))
    }

    nonisolated private static func rawPropertiesLookup(_ dump: RawMetadataDump) -> [String: [String]] {
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

    nonisolated private static func rawContainsCustomKey(_ key: String, dump: RawMetadataDump) -> Bool {
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

    nonisolated private static func normalizedRawKeyAliases(for key: String) -> Set<String> {
        var aliases: Set<String> = [key]

        let mp4FreeformPrefix = "----:COM.APPLE.ITUNES:"
        if key.hasPrefix(mp4FreeformPrefix) {
            aliases.insert(String(key.dropFirst(mp4FreeformPrefix.count)))
        } else {
            aliases.insert("\(mp4FreeformPrefix)\(key)")
        }

        return aliases
    }

    nonisolated private static func applyVerificationFailurePolicy(
        _ policy: VerificationFailurePolicy,
        warnings: [String]
    ) throws {
        guard policy == .throw, !warnings.isEmpty else { return }
        throw TagLibManagerError.verificationFailed(warnings)
    }

    nonisolated private static func explicitValueSource(from dump: RawMetadataDump, fallback: Bool) -> MetadataValueSource {
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

    nonisolated private static func hasVerificationExpectations(_ verification: MetadataWriteVerificationContext) -> Bool {
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

    nonisolated private static func metadataWriteWarnings(
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

    nonisolated private static func textFieldValue(_ field: String, from metadata: BasicMetadata) -> String {
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

    nonisolated private static func rawPropertyMapWriteWarnings(
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

    nonisolated private static func resolvedRawPropertyMapForWrite(
        _ properties: [String: String],
        to url: URL,
        mode: RawPropertyMapWriteMode
    ) throws -> [String: String] {
        switch mode {
        case .replace:
            return properties

        case .merge:
            var merged = try rawMetadataResult(from: url).properties.reduce(into: [String: String]()) { result, entry in
                let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
                let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty, !value.isEmpty else { return }
                result[key] = value
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
                    merged[key] = value
                }
            }

            return merged
        }
    }

    nonisolated private static func parsedPropertyEntries(fromDumpText text: String) -> [RawPropertyEntry] {
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

    nonisolated private static func stringValue(_ dict: [String: Any], _ key: String) -> String {
        if let value = dict[key] as? String { return value }
        if let value = dict[key] as? NSNumber { return value.stringValue }
        return ""
    }

    nonisolated private static func intValue(_ dict: [String: Any], _ key: String) -> Int? {
        if let value = dict[key] as? Int { return value }
        if let value = dict[key] as? NSNumber { return value.intValue }
        if let value = dict[key] as? String { return Int(value) }
        return nil
    }

    nonisolated private static func boolValue(_ dict: [String: Any], _ key: String) -> Bool? {
        if let value = dict[key] as? Bool { return value }
        if let value = dict[key] as? NSNumber { return value.boolValue }
        if let value = dict[key] as? String { return structuredBoolean(value) }
        return nil
    }

    nonisolated private static func stringArrayValue(_ dict: [String: Any], _ key: String) -> [String] {
        (dict[key] as? [String]) ?? []
    }

    nonisolated private static func dictionaryArray(_ dict: [String: NSObject], _ key: String) -> [[String: Any]] {
        (dict[key] as? [[String: Any]]) ?? []
    }

    nonisolated private static func bridgePayload(
        from metadata: StructuredMetadata,
        includeProperties: Bool,
        replacingCollections: Set<StructuredMetadataReplaceableCollection>
    ) -> [String: NSObject] {
        var payload: [String: NSObject] = [:]

        if includeProperties {
            payload["properties"] = metadata.properties.map { entry in
                ["key": entry.key, "values": entry.values] as NSDictionary
            } as NSArray
        }

        if !metadata.id3v2Frames.isEmpty {
            payload["id3v2Frames"] = metadata.id3v2Frames.map { frame in
                var dict: [String: Any] = [
                    "id": frame.frameID,
                    "type": frame.type,
                    "value": frame.value,
                    "values": frame.values
                ]
                dict["description"] = frame.description
                dict["language"] = frame.language
                dict["url"] = frame.url
                dict["owner"] = frame.owner
                dict["data"] = frame.data
                for (key, value) in frame.fields { dict[key] = value }
                return dict as NSDictionary
            } as NSArray
        }

        if !metadata.mp4Atoms.isEmpty {
            payload["mp4Atoms"] = metadata.mp4Atoms.map { atom in
                var dict: [String: Any] = [
                    "key": atom.key,
                    "type": atom.type,
                    "value": atom.value,
                    "values": atom.values
                ]
                dict["first"] = atom.first
                dict["second"] = atom.second
                dict["freeformDescription"] = atom.freeformDescription
                return dict as NSDictionary
            } as NSArray
        }

        if !metadata.asfAttributes.isEmpty {
            payload["asfAttributes"] = metadata.asfAttributes.map { attribute in
                var dict: [String: Any] = [
                    "key": attribute.key,
                    "type": attribute.type,
                    "value": attribute.value,
                    "language": attribute.language,
                    "stream": attribute.stream
                ]
                dict["data"] = attribute.data
                dict["pictureType"] = attribute.pictureType
                dict["mimeType"] = attribute.mimeType
                dict["description"] = attribute.description
                return dict as NSDictionary
            } as NSArray
        }

        if !metadata.artwork.isEmpty || replacingCollections.contains(.artwork) {
            payload["artwork"] = metadata.artwork.map { artwork in
                var dict: [String: Any] = [
                    "container": artwork.container,
                    "mimeType": artwork.mimeType,
                    "data": artwork.data
                ]
                dict["pictureType"] = artwork.pictureType
                dict["pictureTypeCode"] = artwork.pictureTypeCode
                dict["description"] = artwork.description
                return dict as NSDictionary
            } as NSArray
        }

        if !metadata.lyrics.isEmpty || replacingCollections.contains(.lyrics) {
            payload["lyrics"] = metadata.lyrics.map {
                ["language": $0.language, "description": $0.description, "text": $0.text] as NSDictionary
            } as NSArray
        }

        if !metadata.comments.isEmpty || replacingCollections.contains(.comments) {
            payload["comments"] = metadata.comments.map {
                ["language": $0.language, "description": $0.description, "text": $0.text] as NSDictionary
            } as NSArray
        }

        return payload
    }

    nonisolated private static func structuredBoolean(_ value: String) -> Bool? {
        let normalized = normalizedTrimmed(value).lowercased()
        return switch normalized {
        case "1", "true", "yes", "on": true
        case "0", "false", "no", "off": false
        default: Int(normalized).map { $0 != 0 }
        }
    }

    nonisolated private static func unorderedCollectionMatches<Expected, Actual>(
        _ expected: [Expected],
        _ actual: [Actual],
        requireEqualCount: Bool = true,
        matching: (Expected, Actual) -> Bool
    ) -> Bool {
        if requireEqualCount, expected.count != actual.count { return false }
        if expected.count > actual.count { return false }

        var remaining = actual
        for expectedValue in expected {
            guard let index = remaining.firstIndex(where: { matching(expectedValue, $0) }) else {
                return false
            }
            remaining.remove(at: index)
        }
        return true
    }

    nonisolated private static func structuredID3v2FrameMatches(
        _ expected: StructuredID3v2Frame,
        _ actual: StructuredID3v2Frame
    ) -> Bool {
        guard expected.frameID == actual.frameID, expected.type == actual.type else { return false }

        let expectedText = normalizedTrimmed(
            expected.values.isEmpty ? expected.value : expected.values.joined(separator: "; ")
        )
        let actualText = normalizedTrimmed(actual.value)

        switch expected.type {
        case "ufid":
            return expected.owner == actual.owner && expected.data == actual.data
        case "url":
            return expected.url == actual.url &&
                (expected.frameID != "WXXX" || expected.description == actual.description)
        case "userText":
            let actualValues = actual.values.dropFirst(
                actual.values.first == actual.description ? 1 : 0
            )
            let actualJoined = normalizedTrimmed(actualValues.joined(separator: "; "))
            return expected.description == actual.description &&
                (expectedText == actualText || expectedText == actualJoined)
        case "text":
            let actualJoined = normalizedTrimmed(actual.values.joined(separator: "; "))
            return expectedText == actualText || expectedText == actualJoined
        case "chapter":
            return expected.elementID == actual.elementID &&
                expected.startTimeMilliseconds == actual.startTimeMilliseconds &&
                expected.endTimeMilliseconds == actual.endTimeMilliseconds &&
                expected.startOffset == actual.startOffset &&
                expected.endOffset == actual.endOffset
        case "tableOfContents":
            return expected.elementID == actual.elementID &&
                expected.isTopLevel == actual.isTopLevel &&
                expected.isOrdered == actual.isOrdered &&
                expected.children == actual.children
        default:
            return expectedText.isEmpty || expectedText == actualText
        }
    }

    nonisolated private static func structuredASFAttributeMatches(
        _ expected: StructuredASFAttribute,
        _ actual: StructuredASFAttribute
    ) -> Bool {
        guard expected.key == actual.key,
              expected.type == actual.type,
              expected.language == actual.language,
              expected.stream == actual.stream else {
            return false
        }

        switch expected.type {
        case "bool":
            return structuredBoolean(expected.value) == structuredBoolean(actual.value)
        case "binary", "guid":
            return expected.data == actual.data
        default:
            return normalizedTrimmed(expected.value) == normalizedTrimmed(actual.value)
        }
    }

    nonisolated private static func structuredWriteWarnings(
        expected: StructuredMetadata,
        replacingCollections: Set<StructuredMetadataReplaceableCollection>,
        for url: URL
    ) -> [String] {
        guard let after = try? readStructuredMetadataResult(from: url) else {
            return ["Could not verify structured metadata after save."]
        }

        var warnings: [String] = []
        var unmatchedFrames = after.id3v2Frames
        for frame in expected.id3v2Frames {
            if let index = unmatchedFrames.firstIndex(where: { structuredID3v2FrameMatches(frame, $0) }) {
                unmatchedFrames.remove(at: index)
            } else {
                warnings.append("ID3v2 frame \(frame.frameID) could not be confirmed after save.")
            }
        }

        let commentsWereWritten = !expected.comments.isEmpty || replacingCollections.contains(.comments)
        if commentsWereWritten, !unorderedCollectionMatches(expected.comments, after.comments, matching: {
            $0.language == $1.language && $0.description == $1.description && $0.text == $1.text
        }) {
            warnings.append("Not all structured comments could be confirmed after save.")
        }

        let lyricsWereWritten = !expected.lyrics.isEmpty || replacingCollections.contains(.lyrics)
        if lyricsWereWritten, !unorderedCollectionMatches(expected.lyrics, after.lyrics, matching: {
            $0.language == $1.language && $0.description == $1.description && $0.text == $1.text
        }) {
            warnings.append("Not all structured lyrics could be confirmed after save.")
        }

        let artworkWasWritten = !expected.artwork.isEmpty || replacingCollections.contains(.artwork)
        if artworkWasWritten, !unorderedCollectionMatches(expected.artwork, after.artwork, matching: {
            $0.data == $1.data
        }) {
            warnings.append("Not all artwork entries could be confirmed after save.")
        }
        for atom in expected.mp4Atoms {
            guard let actual = after.mp4Atoms.first(where: { $0.key == atom.key && $0.type == atom.type }) else {
                warnings.append("MP4 atom \(atom.key) could not be confirmed after save.")
                continue
            }
            if atom.type == "bool" {
                if structuredBoolean(atom.value) != structuredBoolean(actual.value) {
                    warnings.append("MP4 atom \(atom.key) value differs after save.")
                }
            } else if atom.type == "intPair" {
                if atom.first != actual.first || atom.second != actual.second {
                    warnings.append("MP4 atom \(atom.key) value differs after save.")
                }
            } else if atom.type == "stringList" {
                if atom.values != actual.values {
                    warnings.append("MP4 atom \(atom.key) values differ after save.")
                }
            } else if normalizedTrimmed(atom.value) != normalizedTrimmed(actual.value) {
                warnings.append("MP4 atom \(atom.key) value differs after save.")
            }
        }
        for key in Set(expected.asfAttributes.map(\.key)) {
            let expectedForKey = expected.asfAttributes.filter { $0.key == key }
            let actualForKey = after.asfAttributes.filter { $0.key == key }
            if !unorderedCollectionMatches(expectedForKey, actualForKey, matching: structuredASFAttributeMatches) {
                warnings.append("ASF attribute \(key) could not be confirmed after save.")
            }
        }
        return warnings + after.warnings
    }

    // MARK: - Bridge Dump API

    /// Return a single plain-text dump of metadata as TagLib sees it.
    ///
    /// Preferred path: call the ObjC++ bridge API directly (Swift `throws`).
    /// Fallback path: attempt older single-argument selector names via `perform` for compatibility.
    nonisolated private static func bridgeTextDumpIfAvailable(for url: URL) -> String? {
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
                explicitValueSource(from: $0, fallback: meta.explicitContent)
            } ?? (meta.explicitContent ? .nativeTag : .none)
            let artworkSource: MetadataValueSource = (meta.artworkData as Data?) == nil ? .none : .nativeTag

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
                isExplicit: meta.explicitContent,
                duration: meta.duration,
                bitrate: Int(meta.bitrate),
                sampleRate: Double(meta.sampleRate),
                channels: Int(meta.channels),
                bitDepth: Int(meta.bitDepth),
                format: meta.codec ?? "",
                artworkData: meta.artworkData as Data?,
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
            try TagLibMetadataExtractor.writeMetadata(metadata, to: mutationURL)
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
            try TagLibMetadataExtractor.writeTrackNumberText(
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
            let resolvedProperties = try resolvedRawPropertyMapForWrite(properties, to: mutationURL, mode: mode)
            try TagLibMetadataExtractor.writeRawPropertyMap(resolvedProperties, to: mutationURL)

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
            try TagLibMetadataExtractor.writeRawPropertyMapValues(properties, to: mutationURL)

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

    public nonisolated static func readStructuredMetadata(from url: URL) -> StructuredMetadata? {
        try? readStructuredMetadataResult(from: url)
    }

    public nonisolated static func readStructuredMetadataResult(from url: URL) throws -> StructuredMetadata {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isSupportedFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        let dict: [String: NSObject]
        do {
            dict = try TagLibMetadataExtractor.structuredMetadata(for: url)
        } catch {
            throw TagLibManagerError.failedToReadWithUnderlying(String(describing: error))
        }

        let properties = dictionaryArray(dict, "properties").map {
            StructuredPropertyEntry(key: stringValue($0, "key"), values: stringArrayValue($0, "values"))
        }

        let frames = dictionaryArray(dict, "id3v2Frames").map {
            StructuredID3v2Frame(
                frameID: stringValue($0, "id"),
                type: stringValue($0, "type"),
                value: stringValue($0, "value"),
                values: stringArrayValue($0, "values"),
                description: stringValue($0, "description").nilIfEmpty,
                language: stringValue($0, "language").nilIfEmpty,
                url: stringValue($0, "url").nilIfEmpty,
                owner: stringValue($0, "owner").nilIfEmpty,
                data: $0["data"] as? Data,
                fields: $0.compactMapValues { $0 as? String },
                elementID: stringValue($0, "elementID").nilIfEmpty,
                startTimeMilliseconds: intValue($0, "startTimeMilliseconds"),
                endTimeMilliseconds: intValue($0, "endTimeMilliseconds"),
                startOffset: intValue($0, "startOffset"),
                endOffset: intValue($0, "endOffset"),
                isTopLevel: boolValue($0, "isTopLevel"),
                isOrdered: boolValue($0, "isOrdered"),
                children: stringArrayValue($0, "children"),
                embeddedFrameCount: intValue($0, "embeddedFrameCount")
            )
        }

        let atoms = dictionaryArray(dict, "mp4Atoms").map {
            StructuredMP4Atom(
                key: stringValue($0, "key"),
                type: stringValue($0, "type"),
                value: stringValue($0, "value"),
                values: stringArrayValue($0, "values"),
                first: intValue($0, "first"),
                second: intValue($0, "second"),
                freeformDescription: stringValue($0, "freeformDescription").nilIfEmpty
            )
        }

        let attributes = dictionaryArray(dict, "asfAttributes").map {
            StructuredASFAttribute(
                key: stringValue($0, "key"),
                type: stringValue($0, "type"),
                value: stringValue($0, "value"),
                data: $0["data"] as? Data,
                pictureType: stringValue($0, "pictureType").nilIfEmpty,
                mimeType: stringValue($0, "mimeType").nilIfEmpty,
                description: stringValue($0, "description").nilIfEmpty,
                language: intValue($0, "language") ?? 0,
                stream: intValue($0, "stream") ?? 0
            )
        }

        let artwork = dictionaryArray(dict, "artwork").compactMap { entry -> StructuredArtwork? in
            guard let data = entry["data"] as? Data else { return nil }
            return StructuredArtwork(
                container: stringValue(entry, "container"),
                pictureType: stringValue(entry, "pictureType").nilIfEmpty,
                pictureTypeCode: intValue(entry, "pictureTypeCode"),
                mimeType: stringValue(entry, "mimeType").nilIfEmpty ?? "application/octet-stream",
                description: stringValue(entry, "description").nilIfEmpty,
                data: data
            )
        }

        let lyrics = dictionaryArray(dict, "lyrics").map {
            StructuredLyrics(
                language: stringValue($0, "language").nilIfEmpty ?? "eng",
                description: stringValue($0, "description"),
                text: stringValue($0, "text")
            )
        }

        let comments = dictionaryArray(dict, "comments").map {
            StructuredComment(
                language: stringValue($0, "language").nilIfEmpty ?? "eng",
                description: stringValue($0, "description"),
                text: stringValue($0, "text")
            )
        }

        let warnings = (dict["warnings"] as? [String]) ?? []

        return StructuredMetadata(
            properties: properties,
            id3v2Frames: frames,
            mp4Atoms: atoms,
            asfAttributes: attributes,
            artwork: artwork,
            lyrics: lyrics,
            comments: comments,
            warnings: warnings
        )
    }

    @discardableResult
    public nonisolated static func writeStructuredMetadataWithVerification(
        _ metadata: StructuredMetadata,
        to url: URL,
        riffPolicy: RIFFMetadataWritePolicy = .preserveInfo,
        includeProperties: Bool = false,
        replacingCollections: Set<StructuredMetadataReplaceableCollection> = [],
        verifyAfterWrite: Bool = true,
        failurePolicy: VerificationFailurePolicy = .warn
    ) throws -> MetadataWriteResult {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isWritableFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        return try withAtomicFileMutation(at: url) { mutationURL in
            var warnings: [String] = []
            if ["wav", "aiff", "aif", "aifc", "afc"].contains(ext) {
                switch riffPolicy {
                case .id3v2Only, .preserveInfo:
                    break
                case .syncBasicFieldsToInfo:
                    warnings.append("syncBasicFieldsToInfo is documented but not yet applied by the structured bridge; existing INFO fields are preserved.")
                }
            }

            let payload = bridgePayload(
                from: metadata,
                includeProperties: includeProperties,
                replacingCollections: replacingCollections
            )
            try TagLibMetadataExtractor.writeStructuredMetadata(payload, to: mutationURL)

            if verifyAfterWrite {
                warnings.append(
                    contentsOf: structuredWriteWarnings(
                        expected: metadata,
                        replacingCollections: replacingCollections,
                        for: mutationURL
                    )
                )
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
        try withAtomicFileMutation(at: url) { mutationURL in
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
        warnings.append(
            contentsOf: try writeTagMetadata(
                meta,
                to: url,
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
                ),
                failurePolicy: .warn
            ).warnings
        )

        warnings.append(
            contentsOf: try writeRawMetadataPropertyMapWithVerification(
                [:],
                to: url,
                mode: .replace,
                verifyAfterWrite: false
            ).warnings
        )

        if shouldWipeNativeMetadataContainer(for: url) {
            try TagLibMetadataExtractor.wipeMetadata(from: url)
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
        m.explicitContent = meta.isExplicit
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
        m.customFields = meta.customFields.isEmpty ? nil : meta.customFields
        m.artworkData = meta.artworkData

        // Persist through the write coordinator so all metadata entry points
        // share post-write verification policy.
        let result = try writeTagMetadata(
            m,
            to: url,
            verification: MetadataWriteVerificationContext(
                expectedTrackNumber: meta.track,
                expectedTrackTotal: meta.trackTotal,
                expectedTrackNumberText: meta.trackNumberText,
                expectedDiscNumber: meta.disc,
                expectedDiscTotal: meta.discTotal,
                expectedDiscNumberText: meta.discNumberText,
                expectedExplicitContent: meta.isExplicit,
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
                ]
            ),
            failurePolicy: failurePolicy
        )
        return result
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
