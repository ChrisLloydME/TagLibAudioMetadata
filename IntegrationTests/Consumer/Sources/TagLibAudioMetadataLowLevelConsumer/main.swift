import CTagLibBridge
import Foundation

let metadataExtractorType = TagLibMetadataExtractor.self
let bridgeMetadata = TagLibAudioMetadata()
bridgeMetadata.title = "Low-level consumer smoke test"

precondition(TagLibMetadataExtractor.isSupportedFormat("mp3"))

func compileLowLevelFileCalls(_ url: URL) throws {
    let metadata = try TagLibMetadataExtractor.extractMetadata(from: url)
    _ = try TagLibMetadataExtractor.metadataProjections(for: url)
    _ = try TagLibMetadataExtractor.rawMetadata(for: url)
    _ = try TagLibMetadataExtractor.structuredMetadata(for: url)
    _ = try TagLibMetadataExtractor.writeMetadata(metadata, to: url)
}

_ = metadataExtractorType
_ = compileLowLevelFileCalls
print("TagLibAudioMetadata low-level consumer OK")
