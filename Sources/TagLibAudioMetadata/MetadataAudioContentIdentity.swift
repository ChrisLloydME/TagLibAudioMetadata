import Foundation
import CryptoKit
import Darwin

/// An opaque SHA-256 identity of encoded audio and its interpretation parameters,
/// independent of supported metadata edits. It is not a perceptual fingerprint,
/// a filesystem revision, or a cross-format recording identifier.
///
/// Request it with `readSnapshot(from:includingAudioContent:)` or
/// `readBasicSnapshot(from:includingAudioContent:)`. Availability is deliberately
/// limited to native FLAC and single-data-chunk RIFF WAVE / AIFF / AIFF-C layouts.
/// Do not infer continuity from two missing identities. Tokens are for in-memory
/// comparison within this package version, not persistent identifiers.
public struct MetadataAudioContentIdentity: Hashable, Sendable {
    private let digest: Data

    nonisolated fileprivate init(digest: Data) {
        self.digest = digest
    }
}

public enum MetadataAudioContentError: Error, Equatable, Sendable, LocalizedError {
    /// No supported, unambiguous audio layout was available. Require explicit reload.
    case unavailable
    /// The encoded audio or its interpretation parameters differ from the baseline.
    case changed

    public var errorDescription: String? {
        switch self {
        case .unavailable: "Audio-content continuity is unavailable; explicitly reload before editing."
        case .changed: "The audio content changed; explicitly reload before editing."
        }
    }
}

/// A bounded-memory reader. Chunk payloads are streamed; tag payloads are skipped.
/// Unknown WAVE/AIFF chunks are retained conservatively, so some ancillary edits
/// can require reload rather than accidentally granting continuity.
nonisolated private struct AudioContentReader {
    let handle: FileHandle
    let size: UInt64
    var hash = SHA256()

    private func bytes(at offset: UInt64, count: Int) throws -> Data {
        guard count >= 0, count <= 65_536, offset <= size,
              UInt64(count) <= size - offset else { throw MetadataAudioContentError.unavailable }
        try handle.seek(toOffset: offset)
        var data = Data()
        while data.count < count {
            let part = try handle.read(upToCount: count - data.count) ?? Data()
            guard !part.isEmpty else { throw MetadataAudioContentError.unavailable }
            data.append(part)
        }
        return data
    }

    private func integer(_ bytes: Data, littleEndian: Bool) -> UInt64 {
        (littleEndian ? Array(bytes.reversed()) : Array(bytes)).reduce(0) { ($0 << 8) | UInt64($1) }
    }

    /// Length framing and a domain marker prevent ambiguous concatenations.
    private mutating func appendRange(_ offset: UInt64, _ count: UInt64, kind: Data) throws {
        guard offset <= size, count <= size - offset else { throw MetadataAudioContentError.unavailable }
        hash.update(data: kind)
        var length = count.bigEndian
        withUnsafeBytes(of: &length) { hash.update(bufferPointer: $0) }
        var position = offset
        var remaining = count
        while remaining > 0 {
            let part = try bytes(at: position, count: Int(min(remaining, 65_536)))
            hash.update(data: part)
            position += UInt64(part.count)
            remaining -= UInt64(part.count)
        }
    }

    mutating func identity() throws -> MetadataAudioContentIdentity {
        hash.update(data: Data("TagLibAudioMetadata.audio.v1".utf8))
        let magic = try bytes(at: 0, count: 4)
        switch String(decoding: magic, as: UTF8.self) {
        case "fLaC":
            try flac()
        case "RIFF", "FORM":
            try chunked(littleEndian: magic == Data("RIFF".utf8))
        default:
            throw MetadataAudioContentError.unavailable
        }
        return MetadataAudioContentIdentity(digest: Data(hash.finalize()))
    }

    private mutating func chunked(littleEndian: Bool) throws {
        let header = try bytes(at: 0, count: 12)
        let form = String(decoding: header[8..<12], as: UTF8.self)
        guard (littleEndian && form == "WAVE") || (!littleEndian && ["AIFF", "AIFC"].contains(form)),
              integer(Data(header[4..<8]), littleEndian: littleEndian) == size - 8 else {
            throw MetadataAudioContentError.unavailable
        }
        hash.update(data: Data(form.utf8))
        var offset: UInt64 = 12
        var formatCount = 0
        var audioCount = 0
        while offset < size {
            let chunk = try bytes(at: offset, count: 8)
            let name = String(decoding: chunk.prefix(4), as: UTF8.self)
            let length = integer(Data(chunk[4..<8]), littleEndian: littleEndian)
            let start = offset + 8
            guard length <= size - start, length % 2 <= size - start - length else {
                throw MetadataAudioContentError.unavailable
            }
            if name == (littleEndian ? "fmt " : "COMM") {
                formatCount += 1
                guard length >= (littleEndian ? 16 : (form == "AIFC" ? 22 : 18)) else {
                    throw MetadataAudioContentError.unavailable
                }
            }
            if name == (littleEndian ? "data" : "SSND") {
                audioCount += 1
                guard length > (littleEndian ? 0 : 8) else { throw MetadataAudioContentError.unavailable }
                if !littleEndian {
                    let soundHeader = try bytes(at: start, count: 8)
                    guard integer(Data(soundHeader.prefix(4)), littleEndian: false) < length - 8 else {
                        throw MetadataAudioContentError.unavailable
                    }
                }
            }
            var isMetadata: Bool
            if littleEndian {
                isMetadata = ["id3 ", "ID3 ", "JUNK", "PAD "].contains(name)
                if name == "LIST" {
                    guard length >= 4 else { throw MetadataAudioContentError.unavailable }
                    isMetadata = try bytes(at: start, count: 4) == Data("INFO".utf8)
                }
                // Nested wave-data lists and alternate data layouts are not supported.
                if name == "LIST", !isMetadata { throw MetadataAudioContentError.unavailable }
            } else {
                isMetadata = ["ID3 ", "NAME", "AUTH", "(c) ", "ANNO"].contains(name)
            }
            if !isMetadata {
                try appendRange(start, length, kind: Data(chunk.prefix(4)))
            }
            offset = start + length + length % 2
        }
        guard offset == size, formatCount == 1, audioCount == 1 else {
            throw MetadataAudioContentError.unavailable
        }
    }

    private mutating func flac() throws {
        hash.update(data: Data("fLaC".utf8))
        var offset: UInt64 = 4
        var first = true
        while true {
            let header = try bytes(at: offset, count: 4)
            let kind = header[0] & 0x7f
            let length = integer(Data(header[1..<4]), littleEndian: false)
            let start = offset + 4
            guard kind <= 6, length <= size - start,
                  first ? (kind == 0 && length == 34) : kind != 0 else {
                throw MetadataAudioContentError.unavailable
            }
            // STREAMINFO is interpretation data, not proof of unchanged samples:
            // hash every encoded frame too, never trust the stored MD5 alone.
            if kind == 0 || kind == 2 {
                try appendRange(start, length, kind: Data([kind]))
            }
            first = false
            offset = start + length
            if header[0] & 0x80 != 0 { break }
        }
        guard size - offset >= 2 else { throw MetadataAudioContentError.unavailable }
        let sync = try bytes(at: offset, count: 2)
        guard sync[0] == 0xff, sync[1] & 0xfe == 0xf8 else {
            throw MetadataAudioContentError.unavailable
        }
        try appendRange(offset, size - offset, kind: Data("frames".utf8))
    }
}

extension TagLibMetadataManager {
    /// Called inside the snapshot's outer exact-version checks. Descriptor and path
    /// checks also bind the streamed bytes to that same observed file revision.
    nonisolated static func audioContentIdentity(
        at url: URL, version: MetadataFileVersion, afterAudioRead: () throws -> Void = {}
    ) throws -> MetadataAudioContentIdentity? {
        let descriptor = url.path.withCString { Darwin.open($0, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) }
        guard descriptor >= 0 else { throw TagLibManagerError.invalidFile }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }

        func descriptorVersion() throws -> MetadataFileVersion {
            var info = stat()
            guard fstat(descriptor, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
                throw TagLibManagerError.invalidFile
            }
            return MetadataFileVersion(FileIdentity(
                device: info.st_dev, mode: info.st_mode, inode: info.st_ino, size: info.st_size,
                linkCount: info.st_nlink, modificationTime: info.st_mtimespec, statusChangeTime: info.st_ctimespec
            ))
        }

        guard try descriptorVersion() == version else { throw TagLibManagerError.fileChanged }
        let size = try handle.seekToEnd()
        var reader = AudioContentReader(handle: handle, size: size)
        let identity: MetadataAudioContentIdentity?
        do {
            identity = try reader.identity()
        } catch MetadataAudioContentError.unavailable {
            identity = nil
        }
        // Per-call seam used to exercise a replacement during the streaming interval.
        try afterAudioRead()
        guard try descriptorVersion() == version, version == (try? fileVersion(at: url)) else {
            throw TagLibManagerError.fileChanged
        }
        return identity
    }

    nonisolated static func requireAudioContent(
        at url: URL, matching expected: MetadataAudioContentIdentity
    ) throws {
        let version = try fileVersion(at: url)
        guard let actual = try audioContentIdentity(at: url, version: version) else {
            throw MetadataAudioContentError.unavailable
        }
        guard actual == expected else { throw MetadataAudioContentError.changed }
    }
}
