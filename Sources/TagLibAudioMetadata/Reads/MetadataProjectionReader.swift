import Foundation
import CTagLibBridge

/// Single internal boundary for native extraction and transaction readability.
internal enum MetadataProjectionReader {
    nonisolated static func extract(
        from url: URL,
        options: TagLibMetadataExtractionOptions
    ) throws -> [String: NSObject] {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty, TagLibMetadataExtractor.isSupportedFormat(ext) else {
            throw TagLibManagerError.unsupportedFormat
        }

        do {
            return try TagLibMetadataExtractor.metadataProjections(
                for: url,
                options: options
            )
        } catch {
            throw TagLibManagerError.failedToReadWithUnderlying(String(describing: error))
        }
    }

    /// A transaction validity check needs the same parser/audio credibility
    /// result, not the raw/frame/Swift projections used for semantic reads.
    nonisolated static func validateReadableAudioFile(at url: URL) throws {
        guard let identity = MetadataFileIdentity.read(at: url) else {
            throw TagLibManagerError.invalidFile
        }
        // A successful zero-mask extraction already establishes the concrete
        // parser and Accurate audio credibility; no discarded tag view is needed.
        _ = try extract(from: url, options: .init(rawValue: 0))
        guard identity.hasSameReadableContents(as: MetadataFileIdentity.read(at: url)) else {
            throw TagLibManagerError.failedToReadWithUnderlying("The audio file changed while readability was being checked.")
        }
    }

}
