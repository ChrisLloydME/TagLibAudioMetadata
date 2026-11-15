import Foundation
import TagLibAudioMetadata

enum PreservationProbe {
    static func checks(for url: URL, audioBefore: Data) throws -> [String] {
        let after = try ProbeMP4.read(url)
        var checks: [String] = []
        if try after.text("©nam") == "Assertion Title" {
            checks.append("title")
        }
        if try after.text("----:com.apple.iTunes:CONTRACT_UNKNOWN") == "keep" {
            checks.append("unknown-owner")
        }
        if after.audio == audioBefore {
            checks.append("audio")
        }
        return checks
    }
}
