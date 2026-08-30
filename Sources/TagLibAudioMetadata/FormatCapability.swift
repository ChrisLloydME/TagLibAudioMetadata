//
//  FormatCapability.swift
//  TagLibAudioMetadata
//

import Foundation

public enum StructuredMetadataSupport: String, Hashable, Sendable {
    case none
    case propertyMap
    case container
}

/// Describes how confidently this package can promise support for a format.
public enum FormatSupportLevel: String, Hashable, Sendable {
    /// Covered by package fixtures and read/write regression tests.
    case verified
    /// Available for evaluation, but container-specific field behavior is incomplete.
    case experimental
    /// TagLib exposes the operation, but this package has no round-trip fixture for it.
    case upstreamSupported
    /// Readable by the package, with no supported save path.
    case readOnly
    /// No supported parser or field mapping exists.
    case unsupported
}

public struct FormatCapability: Hashable, Sendable, Identifiable {
    public var id: String { identifier }

    public var identifier: String
    public var displayName: String
    public var codecName: String
    public var primaryExtension: String
    public var extensions: [String]
    public var containers: [String]
    public var isReadable: Bool
    public var isWritable: Bool
    public var canReadArtwork: Bool
    public var canWriteArtwork: Bool
    public var preservesMultiValueProperties: Bool
    public var structuredReadSupport: StructuredMetadataSupport
    public var structuredWriteSupport: StructuredMetadataSupport
    public var readOnlyReason: String?
    public var notes: String?
    public var supportLevel: FormatSupportLevel
    public var extensionSupportLevels: [String: FormatSupportLevel]

    public var metadataFieldFormats: Set<MetadataFieldFormat> {
        var formats: Set<MetadataFieldFormat> = [.tagLibPropertyMap]
        let normalizedContainers = Set(containers.map { $0.lowercased() })

        if normalizedContainers.contains("id3v2") { formats.insert(.id3v2) }
        if normalizedContainers.contains("mp4") { formats.insert(.mp4) }
        if normalizedContainers.contains("xiph") { formats.insert(.xiph) }
        if normalizedContainers.contains("ape") { formats.insert(.ape) }
        if normalizedContainers.contains("asf") { formats.insert(.asf) }
        if identifier == "flac" { formats.insert(.flac) }

        return formats
    }

    public func supportLevel(forExtension fileExtension: String) -> FormatSupportLevel {
        extensionSupportLevels[fileExtension.lowercased()] ?? .unsupported
    }

    public func readSupport(for field: MetadataFieldKey) -> FormatSupportLevel {
        guard isReadable,
              let schema = MetadataFieldRegistry.schema(for: field),
              schema.mappings.contains(where: { metadataFieldFormats.contains($0.format) }),
              !schema.isArtworkField || canReadArtwork
        else { return .unsupported }
        return supportLevel
    }

    public func writeSupport(for field: MetadataFieldKey) -> FormatSupportLevel {
        guard isWritable,
              let schema = MetadataFieldRegistry.schema(for: field),
              schema.mappings.contains(where: { metadataFieldFormats.contains($0.format) }),
              !schema.isArtworkField || canWriteArtwork
        else { return .unsupported }
        return supportLevel
    }

    public init(
        identifier: String,
        displayName: String,
        codecName: String,
        primaryExtension: String,
        extensions: [String],
        containers: [String],
        isReadable: Bool,
        isWritable: Bool,
        canReadArtwork: Bool,
        canWriteArtwork: Bool,
        preservesMultiValueProperties: Bool,
        structuredReadSupport: StructuredMetadataSupport,
        structuredWriteSupport: StructuredMetadataSupport,
        readOnlyReason: String? = nil,
        notes: String? = nil,
        supportLevel: FormatSupportLevel = .upstreamSupported,
        extensionSupportLevels: [String: FormatSupportLevel] = [:]
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.codecName = codecName
        self.primaryExtension = primaryExtension
        self.extensions = extensions
        self.containers = containers
        self.isReadable = isReadable
        self.isWritable = isWritable
        self.canReadArtwork = canReadArtwork
        self.canWriteArtwork = canWriteArtwork
        self.preservesMultiValueProperties = preservesMultiValueProperties
        self.structuredReadSupport = structuredReadSupport
        self.structuredWriteSupport = structuredWriteSupport
        self.readOnlyReason = readOnlyReason
        self.notes = notes
        self.supportLevel = supportLevel
        self.extensionSupportLevels = extensionSupportLevels
    }
}

public extension TagLibMetadataManager {
    nonisolated static var formatCapabilities: [FormatCapability] {
        TagLibMetadataExtractor.formatCapabilities().compactMap(FormatCapability.init(bridgeDictionary:))
    }

    nonisolated static func formatCapability(for fileExtension: String) -> FormatCapability? {
        guard let dictionary = TagLibMetadataExtractor.formatCapability(for: fileExtension) else {
            return nil
        }
        return FormatCapability(bridgeDictionary: dictionary)
    }

    nonisolated static func formatSupportLevel(for fileExtension: String) -> FormatSupportLevel {
        formatCapability(for: fileExtension)?.supportLevel ?? .unsupported
    }
}

private extension FormatCapability {
    init?(bridgeDictionary: [String: NSObject]) {
        guard
            let identifier = bridgeDictionary["identifier"] as? String,
            let displayName = bridgeDictionary["displayName"] as? String,
            let codecName = bridgeDictionary["codecName"] as? String,
            let primaryExtension = bridgeDictionary["primaryExtension"] as? String,
            let extensions = bridgeDictionary["extensions"] as? [String],
            let containers = bridgeDictionary["containers"] as? [String]
        else {
            return nil
        }

        let structuredRead = (bridgeDictionary["structuredReadSupport"] as? String)
            .flatMap(StructuredMetadataSupport.init(rawValue:)) ?? .none
        let structuredWrite = (bridgeDictionary["structuredWriteSupport"] as? String)
            .flatMap(StructuredMetadataSupport.init(rawValue:)) ?? .none
        let supportLevel = (bridgeDictionary["supportLevel"] as? String)
            .flatMap(FormatSupportLevel.init(rawValue:)) ?? .upstreamSupported
        let rawExtensionLevels = bridgeDictionary["extensionSupportLevels"] as? [String: String] ?? [:]
        let extensionSupportLevels = rawExtensionLevels.reduce(into: [String: FormatSupportLevel]()) { result, entry in
            if let level = FormatSupportLevel(rawValue: entry.value) {
                result[entry.key.lowercased()] = level
            }
        }

        self.init(
            identifier: identifier,
            displayName: displayName,
            codecName: codecName,
            primaryExtension: primaryExtension,
            extensions: extensions,
            containers: containers,
            isReadable: (bridgeDictionary["isReadable"] as? NSNumber)?.boolValue ?? false,
            isWritable: (bridgeDictionary["isWritable"] as? NSNumber)?.boolValue ?? false,
            canReadArtwork: (bridgeDictionary["canReadArtwork"] as? NSNumber)?.boolValue ?? false,
            canWriteArtwork: (bridgeDictionary["canWriteArtwork"] as? NSNumber)?.boolValue ?? false,
            preservesMultiValueProperties: (bridgeDictionary["preservesMultiValueProperties"] as? NSNumber)?.boolValue ?? false,
            structuredReadSupport: structuredRead,
            structuredWriteSupport: structuredWrite,
            readOnlyReason: bridgeDictionary["readOnlyReason"] as? String,
            notes: bridgeDictionary["notes"] as? String,
            supportLevel: supportLevel,
            extensionSupportLevels: extensionSupportLevels
        )
    }
}
