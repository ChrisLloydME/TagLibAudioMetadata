import Foundation
import TagLibAudioMetadata

// These references intentionally cover both the Swift facade and the
// re-exported Objective-C bridge while importing only TagLibAudioMetadata.
let metadataManagerType = TagLibMetadataManager.self
let metadataExtractorType = TagLibMetadataExtractor.self
let bridgeMetadata = TagLibAudioMetadata()
bridgeMetadata.title = "Consumer smoke test"

precondition(TagLibMetadataManager.isReadableFormat("mp3"))
precondition(TagLibMetadataExtractor.isSupportedFormat("mp3"))
precondition(BasicMetadata.empty.title.isEmpty)
precondition(RawMetadataDump.empty.properties.isEmpty)

func compileTypicalFileCalls(_ url: URL) throws {
    let basic = try TagLibMetadataManager.readMetadataResult(from: url)
    let raw = try TagLibMetadataManager.rawMetadataResult(from: url)
    let structured = try TagLibMetadataManager.readStructuredMetadataResult(from: url)

    _ = try TagLibMetadataManager.writeMetadata(basic, to: url)
    _ = try TagLibMetadataManager.writeRawMetadataPropertyMap(
        Dictionary(uniqueKeysWithValues: raw.properties.map { ($0.key, $0.value) }),
        to: url
    )
    _ = try TagLibMetadataManager.writeStructuredMetadataWithVerification(
        structured,
        to: url,
        failurePolicy: .throw
    )
    _ = try TagLibMetadataManager.eraseAllMetadata(from: url)

    let lowLevel = try TagLibMetadataExtractor.extractMetadata(from: url)
    _ = try TagLibMetadataExtractor.rawMetadata(for: url)
    _ = try TagLibMetadataExtractor.structuredMetadata(for: url)
    _ = try TagLibMetadataExtractor.writeMetadata(lowLevel, to: url)
}

_ = metadataManagerType
_ = metadataExtractorType
_ = compileTypicalFileCalls
print("TagLibAudioMetadata consumer OK: \(TagLibMetadataManager.readableExtensions.count) readable extensions")
