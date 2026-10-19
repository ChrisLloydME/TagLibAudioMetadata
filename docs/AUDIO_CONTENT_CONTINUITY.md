# Audio-content continuity for conflict resolution

Added in the development checkout on 2026-10-19 in response to AudioMator N-05.
This is an additive integration contract. Existing consumer applications must
adopt it; updating the dependency alone does not change their conflict policies.

## Two different guards

`MetadataFileVersion` identifies an observed filesystem revision. It includes
ctime, so restoring mtime does not ordinarily restore an old version. A consumer
can nevertheless read a fresh version after different samples replace audio in
place and accidentally apply an old draft to that new recording.

`MetadataAudioContentIdentity` compares encoded audio and its interpretation
parameters across supported metadata edits. It is an opaque, in-memory,
`Hashable & Sendable` value. It uses SHA-256 over framed container-specific
regions, not a stored checksum, a whole-file hash, or sampled bytes. It is not
a perceptual fingerprint: re-encoding the same recording can change it.

Request `includingAudioContent: true` on `readSnapshot` or `readBasicSnapshot`
when establishing the editing baseline. The metadata, token and file version
are bracketed by exact revision checks. The stream is opened without following
a final symlink; descriptor and path versions are checked against the snapshot
revision before returning it. Observed changes throw `TagLibManagerError.fileChanged`.

The original read APIs keep their original signatures and avoid hashing audio.
Their snapshots have a nil identity. Unsupported or ambiguous layouts also
produce nil when explicitly requested; I/O failures still throw. **Two nil
identities never establish continuity.** Explicit reload is required when
either baseline or current identity is absent.

## Consumer migration

Keep the baseline token with the draft. Before automatically reconciling a
metadata conflict, obtain a fresh coherent snapshot and compare non-nil tokens.
Then reconcile fields using the consumer's existing policy and commit with both
the fresh file version and the original audio identity:

```swift
let baseline = try TagLibMetadataManager.readSnapshot(
    from: url, includingAudioContent: true
)

// Later, when resolving a conflict for the draft created from baseline:
let current = try TagLibMetadataManager.readSnapshot(
    from: url, includingAudioContent: true
)
guard let originalAudio = baseline.audioContentIdentity,
      let currentAudio = current.audioContentIdentity,
      let currentVersion = current.fileVersion else {
    throw MetadataAudioContentError.unavailable // Require explicit reload.
}
guard originalAudio == currentAudio else {
    throw MetadataAudioContentError.changed // Require explicit reload.
}

// Example: the consumer's field-level reconciliation chose this title delta.
let patch = MetadataPatch(fields: [.title: .text("Reviewed title")])
let result = try TagLibMetadataManager.applyMetadataPatch(
    patch, to: url,
    expectedVersion: currentVersion,
    expectedAudioContent: originalAudio
)
```

For a raw delta, use the same baseline comparison and revision with:

```swift
let result = try TagLibMetadataManager.applyRawMetadataPatch(
    RawMetadataPatch(valuesToSet: ["TITLE": ["Reviewed title"]]),
    to: url,
    expectedVersion: currentVersion,
    expectedAudioContent: originalAudio
)
```

Both overloads require non-optional guards. They hash the staged copy before
mutating it, under the existing same-entry transaction coordinator. Mismatches
throw `MetadataAudioContentError.changed`; unavailable layouts throw
`MetadataAudioContentError.unavailable`. Neither failure publishes the staged
copy. The original exact-version checks before staging and immediately before
commit remain in force. Empty patches remain no-ops and do not validate guards.

The staged comparison protects the write even if the consumer accidentally
adopts a fresh version for changed audio. It does not choose a field-level merge
policy. Existing unguarded overloads retain their behavior. Other write surfaces
(Basic replacement, whole-map raw replacement, structured and bridge APIs) have
no new audio guard: use the typed or raw delta overloads above for rebasing.

Never retry a conflict by dropping a guard. An explicit reload discards/reviews
the old draft and establishes a new baseline. Run these synchronous reads and
writes away from latency-sensitive UI work using the consumer's concurrency
architecture.

## Availability and normalization

Detection uses container signatures rather than trusting the extension.
TagLib must also accept the file for a public snapshot/write.

| Container | Included in the identity | Excluded |
| --- | --- | --- |
| RIFF WAVE | Form type; each non-excluded chunk's ID, payload length and bytes, including `fmt ` and the complete `data` payload | Root size, chunk padding, `id3 `/`ID3 `, `LIST/INFO`, `JUNK`, `PAD ` |
| AIFF / AIFF-C | Form type; each non-excluded chunk's ID, payload length and bytes, including `COMM`, complete `SSND` and `FVER` when present | Root size, chunk padding, `ID3 `, `NAME`, `AUTH`, `(c) `, `ANNO` |
| Native FLAC | Complete `STREAMINFO`, application blocks, and every byte from the first audio frame to EOF | Last-block flags, padding, seek tables, Vorbis comments, cue sheets, pictures |

WAVE/AIFF require one format chunk and one nonempty sound-data chunk, exact root
length, and valid bounded chunk lengths including padding. WAVE nested lists
other than INFO are unavailable. FLAC requires the native marker at byte zero,
a single initial 34-byte STREAMINFO block, recognized metadata types 0–6, and an
audio-frame sync after metadata. Unknown WAVE/AIFF chunks and FLAC application
blocks are retained conservatively: ancillary edits there may change the token.
This scanner validates region boundaries, not every codec frame or checksum.

MP3, MP4/M4A, raw AAC, Ogg/Opus, ASF, APE, WavPack, Musepack, TTA, DSD and tracker
formats currently have no identity. RF64, RIFX, leading-ID3 FLAC and unsupported
layouts also have none. Formats can gain support only after container-specific
normalization and positive/negative tests; no whole-file fallback is used.

## Cost and concurrency limits

Hashing reads the encoded audio, retained ancillary regions and chunk headers
with a maximum 64 KiB read buffer, plus small parser/hash state. It does not decode samples or hold the TagLib global
mutex during streaming. Tag regions are skipped by seeking. A guarded commit
adds another audio scan on its transactional copy.

A deterministic local probe generates 1, 16 and 64 MiB PCM WAVE files and reads
each three times. On this machine's cached local filesystem, Debug Basic reads
with audio hashing took 1.26–2.53 ms, 16.05–16.64 ms and 66.08–85.36 ms,
respectively; default Basic reads took 0.25–1.56 ms. These are observations,
not throughput promises, cold-cache results, or measurements of cloud/network
volumes. See `AudioContentIdentityTests.streamingReadsCoverFullPayloadAndMeasureLocalCost`.

These are optimistic checks, not a filesystem snapshot or cross-process lock.
An uncooperative external writer can still race the final check/rename interval,
as under the existing transaction contract. Cryptographic equality is bounded
by SHA-256 collision resistance. Tokens must not be persisted across package
versions as stable recording IDs.

## Verification — 2026-10-19

The supplied AudioMator integration decision and independent reassessment
describe N-05 against their 0.5.3 dependency. This work starts from package
`main` at `1310e4f` and supplies the missing contract without changing the
consumer repository, dependency pin, conflict policy, release tag or binary.

| Check | Result |
| --- | --- |
| Xcode build including tests | Passed |
| iOS 16 arm64 Release compilation | Passed with Swift warnings-as-errors and Clang Werror; compilation only, no device execution |
| Full Xcode Debug suite after implementation and compatibility forwarding | 222 discovered; 220 passed, 2 existing opt-in skips, zero failures |
| Full SwiftPM Release suite after compatibility forwarding | 153 XCTest (151 passed, 2 opt-in skips) plus 69 Swift Testing passed; zero failures |
| New identity regression functions | 14 passed, with typed/raw positive and negative checks across WAVE, AIFF and FLAC |
| Additional AIFF-C assertions after full suites | Focused Xcode rerun passed; all 14 identity tests then passed again in Release, including identity preservation after a guarded title write and rejection of replacement payload |
| Public function-reference compatibility | Existing snapshot initializers, readers and typed/raw patch references compile; guarded overloads also compile |
| Local I/O cost | 1/16/64 MiB generated PCM files, three samples each; no timing threshold |

The two existing opt-in skips are the external preservation corpus and unrelated
snapshot throughput benchmark. The new continuity regressions and their cost
probe run by default, with no skips or expected-failure annotations. Tests also
check that rejected transactions leave replacement bytes intact and remove
their staged copies.

Full Debug summary: Xcode action artifact `EA10C5D5-47DA-43BB-8FC3-50B45DB8DD52`.
Full Release log from this session:
`/private/tmp/taglib-audio-identity-release-final.log` (local, not committed).

AudioMator's enabled application regression was read as the reproduction
reference; its application suite was not run or modified. Its distribution
blocker remains for the consumer to close after adopting the new API, requiring
reload for unavailable identities, and rerunning its own typed/raw policy tests,
complete suites and artifact checks. Platform minimum-OS runtime, signing,
network/provider volumes and hostile writers remain unverified.

## Specification references

The scanner uses the [Microsoft RIFF chunk conventions](https://learn.microsoft.com/en-us/windows/win32/multimedia/resource-interchange-file-format-services),
the [Apple AIFF/AIFF-C specification in Inside Macintosh: Sound](https://www.mmsp.ece.mcgill.ca/Documents/AudioFormats/AIFF/Docs/MacOS_Sound-extract.pdf),
and [RFC 9639's native FLAC layout](https://www.rfc-editor.org/rfc/rfc9639.html).
