//
//  TagLibMetadataManager+Structured.swift
//  TagLibAudioMetadata
//

import Foundation
import CTagLibBridge

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension TagLibMetadataManager {
    nonisolated static func stringValue(_ dict: [String: Any], _ key: String) -> String {
        if let value = dict[key] as? String { return value }
        if let value = dict[key] as? NSNumber { return value.stringValue }
        return ""
    }

    nonisolated static func intValue(_ dict: [String: Any], _ key: String) -> Int? {
        if let value = dict[key] as? Int { return value }
        if let value = dict[key] as? NSNumber { return value.intValue }
        if let value = dict[key] as? String { return Int(value) }
        return nil
    }

    nonisolated static func boolValue(_ dict: [String: Any], _ key: String) -> Bool? {
        if let value = dict[key] as? Bool { return value }
        if let value = dict[key] as? NSNumber { return value.boolValue }
        if let value = dict[key] as? String { return structuredBoolean(value) }
        return nil
    }

    nonisolated static func stringArrayValue(_ dict: [String: Any], _ key: String) -> [String] {
        (dict[key] as? [String]) ?? []
    }

    nonisolated static func dictionaryArray(_ dict: [String: NSObject], _ key: String) -> [[String: Any]] {
        (dict[key] as? [[String: Any]]) ?? []
    }

    nonisolated static func bridgePayload(
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
                dict["elementID"] = frame.elementID
                dict["startTimeMilliseconds"] = frame.startTimeMilliseconds
                dict["endTimeMilliseconds"] = frame.endTimeMilliseconds
                dict["startOffset"] = frame.startOffset
                dict["endOffset"] = frame.endOffset
                dict["isTopLevel"] = frame.isTopLevel
                dict["isOrdered"] = frame.isOrdered
                dict["children"] = frame.children
                dict["embeddedFrameCount"] = frame.embeddedFrameCount
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

    nonisolated static func structuredBoolean(_ value: String) -> Bool? {
        let normalized = normalizedTrimmed(value).lowercased()
        return switch normalized {
        case "1", "true", "yes", "on": true
        case "0", "false", "no", "off": false
        default: Int(normalized).map { $0 != 0 }
        }
    }

    nonisolated static func unorderedCollectionMatches<Expected, Actual>(
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

    nonisolated static func structuredID3v2FrameMatches(
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

    nonisolated static func structuredASFAttributeMatches(
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

    nonisolated static func structuredWriteVerification(
        expected: StructuredMetadata,
        replacingCollections: Set<StructuredMetadataReplaceableCollection>,
        for url: URL
    ) -> (failures: [String], advisories: [String]) {
        guard let after = try? readStructuredMetadataResult(from: url) else {
            return (["Could not verify structured metadata after save."], [])
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
        return (warnings, after.warnings)
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
            var verificationFailures: [String] = []
            if ["wav", "aiff", "aif", "aifc", "afc"].contains(ext) {
                switch riffPolicy {
                case .id3v2Only, .preserveInfo:
                    break
                case .syncBasicFieldsToInfo:
                    let warning = "syncBasicFieldsToInfo is documented but not yet applied by the structured bridge; existing INFO fields are preserved."
                    warnings.append(warning)
                    verificationFailures.append(warning)
                }
            }

            let payload = bridgePayload(
                from: metadata,
                includeProperties: includeProperties,
                replacingCollections: replacingCollections
            )
            try TagLibMetadataExtractor.writeStructuredMetadata(payload, to: mutationURL)

            if verifyAfterWrite {
                let verification = structuredWriteVerification(
                    expected: metadata,
                    replacingCollections: replacingCollections,
                    for: mutationURL
                )
                verificationFailures.append(contentsOf: verification.failures)
                warnings.append(contentsOf: verification.failures)
                warnings.append(contentsOf: verification.advisories)
            }
            try applyVerificationFailurePolicy(failurePolicy, warnings: verificationFailures)
            return MetadataWriteResult(warnings: warnings)
        }
    }

}
