import Foundation
import Testing
@testable import TagLibAudioMetadata
import CTagLibBridge

struct CleanRoomArtworkTests {
    @Test(arguments: [0, 1, 2])
    func mp4TextDumpReportsCoverCountAndSizes(coverCount: Int) throws {
        let coverURL = try #require(Bundle.module.url(forResource: "testCover", withExtension: "jpg"))
        let cover = try Data(contentsOf: coverURL)
        let covers = Array([cover, cover + Data([0])].prefix(coverCount))

        try ContractFixture.withCopy("m4a") { url in
            var items: [ContractMP4Item] = [
                .init(key: "©nam", value: .text("Cover diagnostic")),
                .init(key: "trkn", value: .intPair(first: 3, second: 12)),
                .init(key: "cpil", value: .boolean(true)),
                .init(key: "tmpo", value: .integer(123, byteCount: 2)),
                .init(key: "cnID", value: .integer(4_294_967_297, byteCount: 8)),
            ]
            if !covers.isEmpty {
                items.append(.init(key: "covr", value: .jpegCovers(covers)))
            }
            try ContractMP4Seed.seed(items, to: url)
            #expect(try ContractMP4Oracle.read(url).payloads("covr") == covers)

            let text = try #require(TagLibMetadataManager.bestEffortRawMetadataText(from: url))
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            let header = try #require(lines.firstIndex(of: "[MP4 ItemMap]"))
            let itemMap = lines.dropFirst(header + 1).prefix { !$0.isEmpty }
            #expect(itemMap.contains("©nam = Cover diagnostic"))
            #expect(itemMap.contains("trkn = 3/12"))
            #expect(itemMap.contains("cpil = true"))
            #expect(itemMap.contains("tmpo = 123"))
            #expect(itemMap.contains("cnID = 4294967297"))

            let coverLines = itemMap.filter { $0.hasPrefix("covr =") }
            switch coverCount {
            case 1:
                #expect(coverLines == ["covr = <CoverArt: 1 image, \(cover.count) bytes>"])
            case 2:
                #expect(coverLines == ["covr = <CoverArt: 2 images, \(cover.count) bytes, \(cover.count + 1) bytes>"])
            default:
                #expect(coverLines.isEmpty)
            }
        }
    }

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
