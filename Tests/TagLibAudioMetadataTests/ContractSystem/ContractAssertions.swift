import Foundation
import Testing

enum ContractCatalog {
    static func load() throws -> [String: Any] {
        let url = ContractClaimsPaths.root.appendingPathComponent("scripts/package-test-system/contract-catalog.json")
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ContractOracleError.malformed("contract catalog is not an object")
        }
        return object
    }

    static func contracts() throws -> [[String: Any]] {
        guard let rows = try load()["contracts"] as? [[String: Any]] else {
            throw ContractOracleError.malformed("contract catalog has no contracts array")
        }
        return rows
    }
}

enum ContractAssertions {
    static func artwork() throws -> Data {
        guard let url = Bundle.module.url(forResource: "testCover", withExtension: "jpg", subdirectory: "Artwork")
            ?? Bundle.module.url(forResource: "testCover", withExtension: "jpg") else {
            throw ContractOracleError.missing("artwork fixture")
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty, data.prefix(2) == Data([0xFF, 0xD8]) else {
            throw ContractOracleError.malformed("artwork fixture is not JPEG")
        }
        return data
    }

    /// Runs a public call that the contract requires to reject, and verifies the
    /// file did not change. A thrown error is expected; a nil/false return is not
    /// treated as a deletion or a rejection.
    static func expectRejection(
        _ case: inout ContractCase,
        name: String,
        file url: URL,
        _ body: () throws -> Void
    ) throws {
        let before = try Data(contentsOf: url)
        var threw = false
        do {
            try body()
        } catch {
            threw = true
        }
        let after = try Data(contentsOf: url)
        `case`.check(name, threw, "expected an explicit rejection")
        `case`.check("\(name).unchanged-bytes", before == after, "rejected operation must not mutate the file")
    }

    static func verifyMP4Seed(
        _ url: URL,
        expectedItems: [String: Data],
        _ case: inout ContractCase
    ) throws -> Data {
        let oracle = try ContractMP4Oracle.read(url)
        `case`.check("seed.container", oracle.topLevelTypes.contains("moov") && oracle.topLevelTypes.contains("mdat"))
        for (key, payload) in expectedItems.sorted(by: { $0.key < $1.key }) {
            `case`.check("seed.\(key)", oracle.payloads(key).first == payload, "independent seed verification")
        }
        `case`.check("seed.audio", !oracle.audio.isEmpty)
        return oracle.audio
    }

    static func verifyID3Seed(
        _ url: URL,
        version: Int,
        frameIDs: [String],
        _ case: inout ContractCase
    ) throws -> Data {
        let oracle = try ContractID3Oracle.read(url)
        `case`.check("seed.version", oracle.version == version, "expected ID3v2.\(version)")
        for frameID in frameIDs {
            `case`.check("seed.frame.\(frameID)", oracle.frame(frameID) != nil, "independent seed verification")
        }
        `case`.check("seed.audio", !oracle.audio.isEmpty)
        return oracle.audio
    }

    static func verifyFLACSeed(
        _ url: URL,
        expected: [String: [String]],
        _ case: inout ContractCase
    ) throws -> Data {
        let oracle = try ContractFLACOracle.read(url)
        for (key, values) in expected.sorted(by: { $0.key < $1.key }) {
            `case`.check("seed.comment.\(key)", oracle.values(key) == values, "independent seed verification")
        }
        `case`.check("seed.audio", !oracle.audio.isEmpty)
        return oracle.audio
    }

    /// Case-insensitive Vorbis lookup that still returns the exact duplicate
    /// sequence and whitespace.
    static func vorbisValues(_ oracle: ContractFLACOracle, _ key: String) -> [String] {
        oracle.comments.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value ?? []
    }

    /// Minimal bounded parser for ID3 user-text frames, used to preserve both
    /// private provenance namespaces and their exact payloads.
    static func id3UserText(_ frame: ContractID3FrameEvidence) throws -> (description: String, values: [String]) {
        guard frame.id == "TXXX", let encoding = frame.payload.first else {
            throw ContractOracleError.malformed("not a TXXX frame")
        }
        let body = Data(frame.payload.dropFirst())
        let separator: UInt8 = 0
        guard let end = body.firstIndex(of: separator) else {
            throw ContractOracleError.malformed("TXXX frame has no description terminator")
        }
        let descriptionData = body[..<end]
        let valueData = body[(end + 1)...]
        let stringEncoding: String.Encoding = encoding == 3 ? .utf8 : .isoLatin1
        guard let description = String(data: descriptionData, encoding: stringEncoding),
              let value = String(data: valueData, encoding: stringEncoding) else {
            throw ContractOracleError.malformed("TXXX frame text is not decodable")
        }
        return (description, [value])
    }

    static func id3Comment(_ frame: ContractID3FrameEvidence) throws -> (language: String, description: String, text: String) {
        guard frame.id == "COMM", let encoding = frame.payload.first else {
            throw ContractOracleError.malformed("not a COMM frame")
        }
        let body = frame.payload.dropFirst()
        guard body.count >= 4 else { throw ContractOracleError.malformed("COMM frame shorter than language") }
        let language = String(decoding: body.prefix(3), as: UTF8.self)
        let rest = body.dropFirst(3)
        let stringEncoding: String.Encoding = encoding == 3 ? .utf8 : .isoLatin1
        guard let end = rest.firstIndex(of: 0),
              let description = String(data: rest[..<end], encoding: stringEncoding),
              let text = String(data: rest[(end + 1)...], encoding: stringEncoding) else {
            throw ContractOracleError.malformed("COMM frame is not decodable")
        }
        return (language, description, text)
    }

    static func writeTemporary(_ data: Data, extension ext: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Contract-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("fixture.\(ext)")
        try data.write(to: url)
        return url
    }
}
