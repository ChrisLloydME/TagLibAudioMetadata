import Foundation
import Testing
import TagLibAudioMetadata

struct CleanRoomAudioPropertiesTests {
    @Test func availableBitDepthIsProjectedForAdditionalContainers() throws {
        // APE, Ogg FLAC, WavPack: independently confirmed by ffprobe's
        // bits_per_raw_sample=16 for these fixtures during remediation.
        for (ext, name) in [("ape", "hardening"), ("oga", "testAudioFile"), ("wv", "testAudioFile"), ("wma", "testAudioFile")] {
            let url = try HardeningFixture.url(ext, name: name)
            let basic = try TagLibMetadataManager.readMetadataResult(from: url)
            if ext == "wma" {
                // ASF Stream Properties embeds WAVEFORMATEX after 54 bytes;
                // its wBitsPerSample is at offset 14 within that structure.
                let streamID = IndependentASF.hex("9107dcb7b7a9cf118ee600c00c205365")
                let stream = try #require(IndependentASF.headerState(Data(contentsOf: url)).children.first { $0.id == streamID })
                let nativeBits = try HardeningFixture.integer(stream.payload, 68, 2, little: true)
                #expect(nativeBits == 16)
                #expect(basic.bitDepth == nativeBits)
            } else {
                #expect(basic.bitDepth == 16)
            }
        }
    }
}
