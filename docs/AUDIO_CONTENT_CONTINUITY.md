# Audio-content continuity for conflict resolution

`MetadataAudioContentIdentity` is an optional guard that helps a consumer distinguish a metadata-only conflict from replaced audio. It is additive: existing reads and writes do not scan audio unless the caller explicitly requests the identity.

## Two different guards

`MetadataFileVersion` identifies an observed filesystem revision. It includes ctime, so restoring mtime does not ordinarily restore an old version. A consumer can nevertheless read a fresh version after different samples replace audio in place and then accidentally apply an old draft to that new recording.

`MetadataAudioContentIdentity` compares encoded audio and its interpretation parameters across supported metadata edits. It is an opaque, in-memory, `Hashable & Sendable` value. It uses SHA-256 over framed container-specific regions, not a stored checksum, a whole-file hash, or sampled bytes. It is not a perceptual fingerprint: re-encoding the same recording can change it.

Request `includingAudioContent: true` on `readSnapshot` or `readBasicSnapshot` when establishing an editing baseline. The metadata, token, and file version are bracketed by revision checks. The stream is opened without following a final symlink; descriptor and path versions are checked against the snapshot revision before returning it. Observed changes throw `TagLibManagerError.fileChanged`.

Default reads return a nil identity and do not hash audio. Unsupported or ambiguous layouts also return nil when explicitly requested; I/O failures still throw. **Two nil identities never establish continuity.** Require an explicit reload when either baseline or current identity is absent.

## Guarded write workflow

Keep the baseline token with the draft. Before automatically reconciling a metadata conflict, obtain a fresh coherent snapshot and compare non-nil tokens. Then reconcile fields using the consumer's policy and commit with both the fresh file version and the original audio identity:

```swift
let baseline = try TagLibMetadataManager.readSnapshot(
    from: url,
    includingAudioContent: true
)

// Later, when resolving a conflict for the draft created from baseline:
let current = try TagLibMetadataManager.readSnapshot(
    from: url,
    includingAudioContent: true
)

guard let originalAudio = baseline.audioContentIdentity,
      let currentAudio = current.audioContentIdentity,
      let currentVersion = current.fileVersion else {
    throw MetadataAudioContentError.unavailable // Explicit reload required.
}

guard originalAudio == currentAudio else {
    throw MetadataAudioContentError.changed // Audio changed; reload required.
}

// Example: the consumer's field-level reconciliation chose this title delta.
let patch = MetadataPatch(fields: [.title: .text("Reviewed title")])
let result = try TagLibMetadataManager.applyMetadataPatch(
    patch,
    to: url,
    expectedVersion: currentVersion,
    expectedAudioContent: originalAudio
)
```

For a raw delta, use the same baseline comparison with the guarded raw overload:

```swift
try TagLibMetadataManager.applyRawMetadataPatch(
    RawMetadataPatch(valuesToSet: ["TITLE": ["Reviewed title"]]),
    to: url,
    expectedVersion: currentVersion,
    expectedAudioContent: originalAudio
)
```

Both guarded overloads require non-optional guards. They hash the staged copy before mutating it, under the same-entry transaction coordinator. Mismatches throw `MetadataAudioContentError.changed`; unavailable layouts throw `MetadataAudioContentError.unavailable`. Neither failure publishes the staged copy. The original exact-version checks before staging and immediately before commit remain in force.

Empty patches remain no-ops and do not validate audio or version guards. Other write surfaces (Basic replacement, whole-map raw replacement, structured writes, and public bridge writes) have no audio guard; use the typed or raw delta overloads for rebasing. The deprecated typed `applyMetadataPatch(_:to:expectedVersion:failurePolicy:)` overload forwards to the unguarded path and cannot check `expectedAudioContent`.

Never retry a conflict by dropping a guard. An explicit reload discards or reviews the old draft and establishes a new baseline. Run synchronous reads and writes away from latency-sensitive UI work using the application's concurrency architecture.

## Availability and normalization

Detection uses container signatures rather than trusting the extension. TagLib must also accept the file for a public snapshot/write.

| Container | Included in the identity | Excluded |
| --- | --- | --- |
| RIFF WAVE | Form type; each non-excluded chunk's ID, payload length, and bytes, including `fmt ` and the complete `data` payload | Root size, chunk padding, `id3 `/`ID3 `, `LIST/INFO`, `JUNK`, `PAD `, `bext`, `iXML` |
| AIFF / AIFF-C | Form type; each non-excluded chunk's ID, payload length, and bytes, including `COMM`, complete `SSND`, and `FVER` when present | Root size, chunk padding, `ID3 `, `NAME`, `AUTH`, `(c) `, `ANNO` |
| Native FLAC | Complete `STREAMINFO`, application blocks, and every byte from the first audio frame to EOF | Last-block flags, padding, seek tables, Vorbis comments, cue sheets, pictures |

WAVE `bext` (Broadcast Wave) and `iXML` are treated as ancillary metadata because TagLib can relocate them from before `data` to after it during a metadata save. Their presence, contents, and position do not affect the identity, including BWF time references and production metadata. Continuity therefore does not establish equality of that metadata. Their chunk lengths and padding are still validated before skipping. Encoded samples and decode parameters such as `fmt ` remain fully hashed.

WAVE/AIFF require one format chunk and one nonempty sound-data chunk, exact root length, and valid bounded chunk lengths including padding. WAVE nested lists other than INFO are unavailable. FLAC requires the native marker at byte zero, a single initial 34-byte `STREAMINFO` block, recognized metadata block types 0–6, and an audio-frame sync after metadata. Unknown WAVE/AIFF chunks and FLAC application blocks are retained conservatively: ancillary edits there may change the token. The scanner validates region boundaries, not every codec frame or checksum.

MP3, MP4/M4A, raw AAC, Ogg/Opus, ASF, APE, WavPack, Musepack, TrueAudio, DSD, and tracker formats currently have no identity. RF64, RIFX, leading-ID3 FLAC, and unsupported layouts also have none. Formats can gain support only after container-specific normalization and positive/negative tests; no whole-file fallback is used.

## Source compatibility and function references

Adding overloads with the same base name means an untyped function reference can become ambiguous:

```swift
// Ambiguous with multiple readSnapshot overloads.
let reader = TagLibMetadataManager.readSnapshot

// Supported compatibility shape: an explicit function type.
let reader: (URL) throws -> MetadataSnapshot = TagLibMetadataManager.readSnapshot
```

Typed references and direct calls remain supported. The same caveat applies to `readBasicSnapshot`, `applyMetadataPatch`, `applyRawMetadataPatch`, and `BasicMetadataSnapshot.init`. This is a source-compatibility limitation, not a runtime defect. Give stored references an explicit type or call the overload directly.

## Cost and concurrency limits

Hashing reads the encoded audio, retained ancillary regions, and chunk headers with a maximum 64 KiB read buffer, plus small parser/hash state. It does not decode samples or hold the TagLib global mutex during streaming. Tag regions are skipped by seeking. A guarded commit adds another audio scan on its transactional copy.

Cost is O(audio size), so it is a deliberate trade-off: default reads remain cheap, while a caller that opts in pays for streaming I/O on every snapshot and guarded commit. Benchmark locally for the storage volume and file sizes in your application; cached local files are not representative of network or cold-cache volumes. The opt-in `SnapshotThroughputBenchmarkTests` is a general snapshot observation, not an audio-hashing benchmark; `AudioContentIdentityTests.streamingReadsCoverFullPayloadAndMeasureLocalCost` measures the audio scan specifically. Neither is a performance promise.

These are optimistic checks, not a filesystem snapshot or cross-process lock. An uncooperative external writer can still race the final check/rename interval, as under the transaction contract. Cryptographic equality is bounded by SHA-256 collision resistance. Tokens must not be persisted across package versions as stable recording identifiers.

## Evidence and verification

The feature was added on top of `1310e4f` in the `fix/audio-content-continuity` work. An independent audit at `873cb3e` found that WAVE `bext`/`iXML` relocation could invalidate a metadata-only identity; that finding was fixed in `bedd725` with focused regressions. The remaining findings are compatibility limitations or evidence gaps. See the [audio-identity audit](records/audits/AUD-2026-10-19-audio-content-identity.md) and [records index](records/README.md).

`AudioContentIdentityTests` covers opt-in identities across snapshot projections, metadata/artwork/erase edits, WAVE ancillary relocation, guarded typed/raw rebases, changed audio or interpretation parameters, stale versions, unavailable layouts, malformed/ambiguous layouts, AIFF-C and odd chunk padding, streaming boundary races, and a non-gating cost probe. Passing tests are evidence for those fixtures, not proof for every file or platform.

## Specification references

The scanner uses the [Microsoft RIFF chunk conventions](https://learn.microsoft.com/en-us/windows/win32/multimedia/resource-interchange-file-format-services), the [Apple AIFF/AIFF-C specification in Inside Macintosh: Sound](https://www.mmsp.ece.mcgill.ca/Documents/AudioFormats/AIFF/Docs/MacOS_Sound-extract.pdf), and [RFC 9639's native FLAC layout](https://www.rfc-editor.org/rfc/rfc9639.html).
