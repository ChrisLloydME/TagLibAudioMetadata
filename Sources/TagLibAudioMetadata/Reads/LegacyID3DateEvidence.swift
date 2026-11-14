import Foundation

/// Read literal v2.3 date owners before TagLib's timestamp normalization.
internal enum LegacyID3DateEvidence {
    static let owners: Set<String> = ["TYER", "TDAT", "TDRC", "TDRL", "TORY", "TDOR"]

    static func frames(at url: URL) throws -> [[String: NSObject]] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        func number(_ offset: Int, _ length: Int, little: Bool = false) -> Int {
            let bytes = data[offset..<(offset + length)]
            let value = (little ? Array(bytes.reversed()) : Array(bytes)).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            return value > UInt64(Int.max) ? Int.max : Int(value)
        }
        var offset = 0
        if data.starts(with: Data("RIFF".utf8)) || data.starts(with: Data("FORM".utf8)) {
            let little = data.starts(with: Data("RIFF".utf8))
            offset = 12
            while offset + 8 <= data.count {
                let id = String(decoding: data[offset..<(offset + 4)], as: UTF8.self).uppercased()
                let size = number(offset + 4, 4, little: little)
                if id == "ID3 " { offset += 8; break }
                guard size <= data.count - offset - 8 else { throw TagLibManagerError.invalidFile }
                offset += 8 + size + size % 2
            }
        } else if data.starts(with: Data("DSD ".utf8)), data.count >= 28 {
            offset = number(20, 8, little: true)
        } else if data.starts(with: Data("FRM8".utf8)) {
            offset = 16
            while offset + 12 <= data.count {
                let id = String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
                let size = number(offset + 4, 8)
                if id == "ID3 " { offset += 12; break }
                guard size <= data.count - offset - 12 else { throw TagLibManagerError.invalidFile }
                offset += 12 + size + size % 2
            }
        }
        guard offset >= 0, offset <= data.count - 10,
              data[offset..<(offset + 3)] == Data("ID3".utf8), data[offset + 3] == 3 else {
            throw TagLibManagerError.invalidFile
        }
        guard data[offset + 5] == 0, data[(offset + 6)..<(offset + 10)].allSatisfy({ $0 < 128 }) else {
            throw TagLibManagerError.unsupportedWritePolicy("Flagged ID3v2.3 date evidence cannot be interpreted losslessly.")
        }
        let size = data[(offset + 6)..<(offset + 10)].reduce(0) { ($0 << 7) | Int($1) }
        let end = offset + 10 + size
        guard end <= data.count else { throw TagLibManagerError.invalidFile }
        offset += 10
        var result: [[String: NSObject]] = []
        while offset + 10 <= end, data[offset] != 0 {
            let id = String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
            let size = number(offset + 4, 4)
            guard size <= end - offset - 10 else { throw TagLibManagerError.invalidFile }
            if owners.contains(id) {
                guard size > 0, data[offset + 8] == 0, data[offset + 9] == 0 else { throw TagLibManagerError.invalidFile }
                let encoding: String.Encoding
                switch data[offset + 10] {
                case 0: encoding = .isoLatin1
                case 1: encoding = .utf16
                default: throw TagLibManagerError.invalidFile
                }
                guard let value = String(data: data[(offset + 11)..<(offset + 10 + size)], encoding: encoding) else {
                    throw TagLibManagerError.invalidFile
                }
                let values = value.components(separatedBy: "\0")
                result.append(["id": id as NSString, "type": "text" as NSString,
                               "values": values as NSArray, "value": values.joined(separator: "; ") as NSString])
            }
            offset += 10 + size
        }
        return result
    }

    static func correcting(_ projections: [String: NSObject], at url: URL) throws -> [String: NSObject] {
        guard let structured = projections["structured"] as? [String: NSObject],
              (structured["id3v2MajorVersion"] as? NSNumber)?.intValue == 3 else { return projections }
        let dates = try frames(at: url)
        var result = projections
        for key in ["structured", "raw"] {
            guard var view = result[key] as? [String: NSObject] else { continue }
            let frames = (view["id3v2Frames"] as? [[String: NSObject]] ?? []).filter {
                !owners.contains(($0["id"] as? String) ?? "")
            }
            view["id3v2Frames"] = (frames + dates) as NSArray
            result[key] = view as NSDictionary
        }
        return result
    }
}
