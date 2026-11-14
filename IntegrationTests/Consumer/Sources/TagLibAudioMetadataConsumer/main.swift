import Foundation
import TagLibAudioMetadata

let metadataManagerType = TagLibMetadataManager.self

precondition(TagLibMetadataManager.isReadableExtension("mp3"))
precondition(BasicMetadata.empty.title.isEmpty)
precondition(RawMetadataDump.empty.properties.isEmpty)

func compileTypicalFileCalls(_ url: URL) throws {
    let basic = try TagLibMetadataManager.readMetadataResult(from: url)
    let raw = try TagLibMetadataManager.rawMetadataResult(from: url)
    let structured = try TagLibMetadataManager.readStructuredMetadataResult(from: url)

    _ = try TagLibMetadataManager.replaceBasicMetadata(basic, to: url)
    _ = try TagLibMetadataManager.writeRawMetadataPropertyMap(
        Dictionary(uniqueKeysWithValues: raw.properties.map { ($0.key, $0.value) }),
        to: url
    )
    _ = try TagLibMetadataManager.writeStructuredMetadataWithVerification(
        structured,
        to: url
    )
    _ = try TagLibMetadataManager.eraseAllMetadata(from: url)

}

_ = metadataManagerType
_ = compileTypicalFileCalls
print("TagLibAudioMetadata consumer OK: \(TagLibMetadataManager.readableExtensions.count) readable extensions")
