import Foundation

/// Rules for preserving ID3v2.3 date frames across structured/raw writes.
///
/// TagLib 2.3.1 normalizes a v2.3 tag on save: standalone TDAT can disappear,
/// TDRL/TDOR/TDRC can be dropped or rewritten, and conflicting TORY/TDOR
/// owners can be collapsed. These paths are intentionally conservative: they
/// replay a standalone TDAT when doing so is known to preserve it, and reject
/// layouts whose date owners cannot be preserved byte-for-byte.
enum ID3v23DateSafety {
    static let owners: Set<String> = ["TYER", "TDAT", "TORY", "TDRL", "TDOR", "TDRC"]
    static let dateDescriptions: Set<String> = ["DATE", "YEAR", "RELEASEDATE", "ORIGINALDATE", "ORIGINALYEAR", "ORIGINAL YEAR"]
    static let datePropertyKeys: Set<String> = [
        "YEAR", "DATE", "RELEASEDATE", "ORIGINALDATE", "ORIGINAL YEAR", "ORIGINALYEAR",
        "TYER", "TDAT", "TORY", "TDRL", "TDOR", "TDRC",
    ]

    static func isDateFrame(_ frame: StructuredID3v2Frame) -> Bool {
        if owners.contains(frame.frameID.uppercased()) { return true }
        if frame.frameID.uppercased() == "TXXX",
           let description = frame.description?.uppercased(),
           dateDescriptions.contains(description) { return true }
        let versionedIDs = [frame.v23ID, frame.v24ID].compactMap { $0?.uppercased() }
        if versionedIDs.contains(where: owners.contains) { return true }
        let versionedDescriptions = [frame.v23Description, frame.v24Description]
            .compactMap { $0?.uppercased() }
        return versionedDescriptions.contains(where: dateDescriptions.contains)
    }

    static func dateFrames(in structured: StructuredMetadata) -> [StructuredID3v2Frame] {
        structured.id3v2Frames.filter(isDateFrame)
    }

    static func dateFrames(in frames: [StructuredID3v2Frame]) -> [StructuredID3v2Frame] {
        frames.filter(isDateFrame)
    }

    static func isDateEdit(_ metadata: StructuredMetadata, includeProperties: Bool) -> Bool {
        if dateFrames(in: metadata).isEmpty == false { return true }
        guard includeProperties else { return false }
        return metadata.properties.contains {
            datePropertyKeys.contains($0.key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
        }
    }

    /// Returns a reason when TagLib's v2.3 save cannot be trusted to retain the
    /// tag's existing date owners exactly.
    static func unpreservableReason(in frames: [StructuredID3v2Frame]) -> String? {
        let dates = dateFrames(in: frames)
        guard dates.isEmpty == false else { return nil }
        let ids = dates.map { $0.frameID.uppercased() }
        if ids.contains(where: { ["TDRL", "TDOR", "TDRC"].contains($0) }) {
            return "ID3v2.3 contains a date owner (TDRL/TDOR/TDRC) that TagLib cannot preserve on save."
        }
        for id in Set(ids) where ids.filter({ $0 == id }).count > 1 {
            return "ID3v2.3 contains duplicate \(id) date owners."
        }
        if ids.contains("TORY") && ids.contains("TDOR") {
            return "ID3v2.3 contains conflicting TORY and TDOR owners."
        }
        return nil
    }

    /// Frames that must be replayed so an unrelated v2.3 write does not lose a
    /// standalone DATE. Canonical TYER+TDAT layouts already survive TagLib.
    static func preservationFrames(
        in frames: [StructuredID3v2Frame]
    ) -> [StructuredID3v2Frame] {
        let dates = dateFrames(in: frames)
        let hasTYER = dates.contains { $0.frameID.uppercased() == "TYER" }
        guard !hasTYER else { return [] }
        guard let tdat = dates.first(where: { $0.frameID.uppercased() == "TDAT" }) else {
            return []
        }
        let values = tdat.values.isEmpty && !tdat.value.isEmpty ? [tdat.value] : tdat.values
        guard !values.isEmpty else { return [] }
        return [StructuredID3v2Frame(frameID: "TDAT", type: "text", values: values)]
    }

    static func signature(of frames: [StructuredID3v2Frame]) -> [String] {
        dateFrames(in: frames).map { frame -> String in
            let values = frame.values.isEmpty && !frame.value.isEmpty ? [frame.value] : frame.values
            return [
                frame.frameID.uppercased(),
                frame.description?.uppercased() ?? "",
                values.joined(separator: "\u{1f}"),
            ].joined(separator: "\u{1e}")
        }.sorted()
    }

    static func unexpectedChanges(
        before: [StructuredID3v2Frame],
        after: [StructuredID3v2Frame]
    ) -> [String] {
        let old = signature(of: before)
        let new = signature(of: after)
        guard old != new else { return [] }
        return ["ID3v2.3 date frames changed during a write that did not request a date edit."]
    }
}
