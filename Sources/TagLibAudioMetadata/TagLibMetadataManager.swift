import Foundation
import CTagLibBridge

/// Public namespace for metadata operations. Storage and native projection
/// mechanics are owned by the internal services, not this facade.
public struct TagLibMetadataManager {
    nonisolated static let hiddenInternalRawFieldKeys: Set<String> = [
        "TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT",
        "TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:TAGLIBAUDIOMETADATA_DISCNUMBER_TEXT",
        "AUDIOMATOR_TRACKNUMBER_TEXT",
        "AUDIOMATOR_DISCNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:AUDIOMATOR_TRACKNUMBER_TEXT",
        "----:COM.APPLE.ITUNES:AUDIOMATOR_DISCNUMBER_TEXT",
    ]

    public nonisolated static func isReadableExtension(_ fileExtension: String) -> Bool {
        TagLibMetadataExtractor.isSupportedFormat(fileExtension)
    }

    public nonisolated static func isWritableExtension(_ fileExtension: String) -> Bool {
        TagLibMetadataExtractor.isWritableFormat(fileExtension)
    }

    public nonisolated static var readableExtensions: [String] {
        TagLibMetadataExtractor.supportedExtensions()
    }

    public nonisolated static var writableExtensions: [String] {
        TagLibMetadataExtractor.writableExtensions()
    }

}
