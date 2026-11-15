import Foundation

enum ProbeError: Error, CustomStringConvertible {
    case cleanFailure(String)
    case malformed(String)

    var description: String {
        switch self {
        case .cleanFailure(let message): "clean package behavior failed: \(message)"
        case .malformed(let message): "malformed fixture evidence: \(message)"
        }
    }
}

enum ProbeFixture {
    static var directory: URL {
        if let value = ProcessInfo.processInfo.environment["CALIBRATION_FIXTURES"] {
            return URL(fileURLWithPath: value, isDirectory: true)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("fixtures", isDirectory: true)
    }

    static func copy(_ name: String, _ ext: String) throws -> URL {
        let source = directory.appendingPathComponent("\(name).\(ext)")
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw ProbeError.malformed("missing fixture \(source.path)")
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Calibration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("fixture.\(ext)")
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    static func withCopy(_ name: String, _ ext: String, _ body: (URL) throws -> Void) throws {
        let url = try copy(name, ext)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try body(url)
    }

    static func number(_ value: UInt64, bytes: Int, little: Bool = false) -> Data {
        Data((0..<bytes).map {
            UInt8(truncatingIfNeeded: value >> UInt64((little ? $0 : bytes - 1 - $0) * 8))
        })
    }

    static func integer(_ data: Data, _ offset: Int, _ count: Int, little: Bool = false) throws -> Int {
        guard offset >= 0, count > 0, count <= 8, offset <= data.count, count <= data.count - offset else {
            throw ProbeError.malformed("integer read outside bounds")
        }
        let slice = data[offset..<(offset + count)]
        let ordered = little ? Array(slice.reversed()) : Array(slice)
        let value = ordered.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard value <= UInt64(Int.max) else { throw ProbeError.malformed("integer exceeds Int") }
        return Int(value)
    }
}

func requireRejection(
    _ label: String,
    _ url: URL,
    _ body: () throws -> Void
) throws {
    let before = try Data(contentsOf: url)
    var threw = false
    do { try body() } catch { threw = true }
    if !threw {
        print("ACTIVATION \(label): operation was accepted instead of rejected")
        throw ProbeError.cleanFailure("expected rejection")
    }
    if try Data(contentsOf: url) != before {
        print("ACTIVATION \(label): rejected operation still mutated the file")
        throw ProbeError.cleanFailure("rejected operation mutated bytes")
    }
}

func require(_ condition: Bool, _ label: String) throws {
    if !condition {
        print("ACTIVATION \(label): clean behavior assertion failed")
        throw ProbeError.cleanFailure(label)
    }
}
