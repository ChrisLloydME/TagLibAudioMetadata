import Foundation
import Testing
@testable import TagLibAudioMetadata
import CTagLibBridge

struct CleanRoomArtworkTests {
    @Test func exactArtworkExpectationsRejectSwappedBytesAndMIMEAndRollback() throws {
        let coverURL = try #require(Bundle.module.url(forResource: "testCover", withExtension: "jpg"))
        let cover = try Data(contentsOf: coverURL)
        var swapped = cover
        swapped[swapped.count - 1] ^= 1
        #expect(swapped.count == cover.count && swapped != cover)
        for ext in ["mp3", "m4a", "flac"] {
            try HardeningFixture.withCopy(ext, name: "testAudioFile") { url in
                try TagLibMetadataManager.updateBasicMetadata(at: url) {
                    $0.artworkData = cover
                    $0.artworkMIMEType = "image/jpeg"
                }
                let original = try Data(contentsOf: url)
                var expected = TagLibMetadataManager.MetadataWriteVerificationContext.none
                expected.expectedArtworkData = cover
                expected.expectedArtworkMIMEType = "image/jpeg"
                #expect(TagLibMetadataManager.metadataWriteWarnings(for: url, verification: expected).isEmpty)
                for wrongMIME in [false, true] {
                    var mismatch = expected
                    if wrongMIME { mismatch.expectedArtworkMIMEType = "image/png" }
                    else { mismatch.expectedArtworkData = swapped }
                    let metadata = TagLibAudioMetadata()
                    metadata.title = "Must not commit"
                    metadata.artworkData = cover
                    metadata.artworkMimeType = "image/jpeg"
                    #expect(throws: TagLibManagerError.self) {
                        try TagLibMetadataManager.writeTagMetadata(metadata, to: url, verification: mismatch)
                    }
                    #expect(try Data(contentsOf: url) == original)
                }
            }
        }
    }
}
