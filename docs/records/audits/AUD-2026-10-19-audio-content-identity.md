# Independent Engineering Audit: Audio-Content Identity and Continuity

**Audit date:** 2026-10-19

**Repository:** `TagLibAudioMetadata`

**Branch:** `fix/audio-content-continuity`

**Audited HEAD:** `873cb3e` (`Document audio continuity adoption and verified format boundaries`)

**Claimed base:** `1310e4f` (`Merge pull request #11 from ChrisLloydME/fix/comprehensive-audit-remediation`)

**Audited commits:** `8a6fa60`, `0c0f902`, `0e8d431`, `2079800`, `873cb3e`

**Method:** Direct inspection of the full working tree and surrounding write/read/transaction code, comparison against the claimed base, execution of the complete Xcode test suite and the new focused tests, a cross-platform iOS Simulator build, and independent Swift probes linked against the freshly built package. The probes exercised crafted WAVE, AIFF, AIFF-C and FLAC files, TagLib metadata edits, guarded and unguarded patch paths, same-file and independent-file concurrency, and measured I/O cost. The working tree was clean at the start of the audit.

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Commit Assessment](#2-commit-assessment)
3. [Findings](#3-findings)
4. [Test Assessment](#4-test-assessment)
5. [Compatibility and Performance](#5-compatibility-and-performance)
6. [Remaining Risks](#6-remaining-risks)
7. [Merge Readiness](#7-merge-readiness)
8. [Repository Integrity](#8-repository-integrity)
9. [Appendix A: Independent Reproducers](#9-appendix-a-independent-reproducers)
10. [Appendix B: Commands and Observed Results](#10-appendix-b-commands-and-observed-results)

## 1. Executive Summary

The five commits add an opt-in audio-content identity to full and Basic snapshots, add typed and raw delta overloads that require both an exact file version and a baseline audio identity, add targeted regression and cost tests, restore the pre-existing snapshot initializer and patch function-reference shapes, and document the contract. The work is additive: default reads do not scan audio, existing write overloads keep their behavior, and the existing transaction/version guards remain in place. The core hash construction is sound for detecting changed encoded audio in the supported containers, and I found no data-loss, corruption or security defect in the guarded write path. All 222 Xcode tests were discovered and the full suite passed with 220 passed and the two existing opt-in skips. The 14 new tests passed. An iOS Simulator build succeeded without warnings or errors. Independent probes confirmed correct behavior for simple WAVE, AIFF, AIFF-C and native FLAC, correct rejection of changed audio, correct stale-version rejection, one-winner behavior under same-file contention, and no errors for concurrent reads or guarded writes of independent files.

The most important finding is a confirmed false-positive failure of the advertised continuity behavior for a common professional WAVE layout. TagLib relocates a `bext` chunk (Broadcast Wave) or an `iXML` chunk from before the `data` chunk to after it whenever it saves metadata. The identity hashes every non-excluded chunk in file order, and `bext`/`iXML` are not excluded. The audio samples remain byte-identical, and the 602-byte `bext` payload was verified byte-identical in a dedicated payload comparison; the relocation itself is the observed structural change that alters the digest. A documented metadata-only rebase then throws `MetadataAudioContentError.changed`. Even the first correct guarded write on such a file succeeds and immediately invalidates the token it just validated; a second guarded write using that token is rejected. This was confirmed for typed and raw patches on both chunks, and for artwork and erase on `bext`, and it is reproducible with a valid PCM WAVE file containing a 602-byte `bext` chunk, the standard BWF layout. The new tests do not cover `bext` or `iXML`; the WAVE fixture used by the identity tests contains an `FLLR` chunk, which happens to remain stable. The type-level documentation says the identity is "independent of supported metadata edits" and the changelog says "independent of supported tag edits"; those statements are false for these layouts. The detailed continuity document implies their inclusion under its general "each non-excluded chunk" rule and contains a general warning that ancillary chunks may change the token, so this is a conservative, fail-closed limitation rather than a data-safety defect, but it directly undermines the feature for broadcast/production WAVE files and the documentation must not claim unqualified independence.

Two lower-severity compatibility issues were also confirmed. Adding public overloads with the same base names makes previously valid untyped function references such as `let f = TagLibMetadataManager.readSnapshot` ambiguous at compile time, although the typed references covered by the compatibility test still compile. The deprecated typed overload `applyMetadataPatch(_:to:expectedVersion:failurePolicy:)` still forwards to the unguarded three-argument path, so a legacy typed rebase bypasses the new audio guard; this is consistent with the general "other write surfaces remain unguarded" limitation but is not called out explicitly. The remaining documentation claims about the iOS Release build, the SwiftPM Release suite and the external AudioMator suite were not independently reproduced here; the full Xcode Debug suite and iOS Simulator compilation were.

No data-safety blocker was found. The identity is deliberately conservative and fails closed when a layout is unsupported or ambiguous. The minimum corrective work for the material finding is small: either exclude the ancillary `bext`/`iXML` chunks from the identity (or make non-audio chunk ordering order-insensitive), or explicitly scope those layouts out, and add `bext`/`iXML` regression tests plus a post-write token-stability test. The documentation claims need the same qualification. If BWF/iXML metadata-only rebasing is an acceptance requirement for the target consumer, these changes are not ready until that is fixed; if the feature is accepted as an opt-in facility for the layouts that remain stable, the safe implementation can merge with those caveats and follow-up work.

**Verdict:** `READY WITH CAVEATS`

**MERGE RECOMMENDATION: YES**, conditional on correcting the documentation/claims and adding the BWF/iXML and post-write token-stability regressions; if BWF/iXML continuity is a release requirement, the verdict becomes `NOT READY TO MERGE` with `MERGE RECOMMENDATION: NO` until the normalization/exclusion fix lands.

## 2. Commit Assessment

The commits are coherent and build on each other. The final tree, not the intermediate states, is what this audit evaluates, but the intermediate decisions explain two compatibility fixes and one moved scan.

| Commit | Purpose | Independent assessment |
| --- | --- | --- |
| `8a6fa60f` | Add the identity type, reader/parser, read overloads, snapshot properties, and the first regression tests. | The core parser and SHA-256 streaming design are sound. The initial snapshot initializer with a defaulted identity parameter changed the function-reference shape, which the later compatibility commit corrects. The parser's file-order, include-all-non-excluded-chunk policy is also the origin of the BWF/iXML false positive. |
| `0c0f9029` | Add guarded typed and raw patch overloads and require a baseline identity. | The guard is correctly placed before mutation on the transactional copy, the public overloads require non-optional version and identity, and the private helper centralizes the logic. Error propagation of `MetadataAudioContentError` through the native transaction coordinator was confirmed by tests. The guard is not present on the deprecated typed overload or on other write surfaces, which is partly documented. |
| `0e8d4315` | Move the audio scan after the extraction seam, add the `afterAudioRead` seam, add AIFF-C/odd-padding and cost tests, and add AIFC assertions. | The scan remains coherent with the captured revision because `audioContentIdentity` independently checks the descriptor and path versions before and after streaming. The AIFF-C and odd-padding tests are meaningful. The cost probe is a measurement-only test with no threshold. |
| `2079800b` | Restore the four-argument snapshot initializer and two-argument Basic snapshot initializer; add the new five/three-argument overloads; add typed function-reference compatibility tests. | Correct and necessary. It preserves the exact typed initializer and reader/patch function types that clients can reference, and the compatibility test compiles. It does not preserve untyped function references, which become ambiguous because of the added overloads; that is a lower-severity source-compatibility regression. |
| `873cb3e5` | Add the continuity contract, README/architecture/thread-safety notes, changelog entry, and additional AIFC assertions. | The detailed contract is generally accurate about version checks, cost, concurrency, unsupported layouts and non-persistence. It lacks a specific BWF/iXML warning and the type doc/changelog make an overbroad independence claim. The verification table overstates what was independently established for release/iOS/external suites unless those local artifacts are accepted at face value. |

Combined behavior is additive. `readSnapshot(from:)`, `readBasicSnapshot(from:)`, the three-argument typed patch, the three-argument raw patch, and the existing initializers retain their behavior and their typed function-reference shapes. Existing tests and the full suite pass. The new behavior is opt-in for reads and explicit for the guarded overloads.

## 3. Findings

| ID | Severity | Status | Finding |
| --- | --- | --- | --- |
| F1 | Medium (High if BWF/iXML support is an acceptance requirement) | Confirmed | `bext`/`iXML` WAVE chunks can be relocated by TagLib during a metadata-only save, changing the audio-content identity and causing false `.changed` rejections and self-invalidating tokens. |
| F2 | Low | Confirmed | Added public overloads make previously valid untyped function references ambiguous at compile time (`readSnapshot`, `readBasicSnapshot`, `applyMetadataPatch`, `applyRawMetadataPatch`, `BasicMetadataSnapshot.init`); typed references remain compatible. |
| F3 | Low | Confirmed, largely intentional | The deprecated typed patch overload with `failurePolicy` still forwards to the unguarded path and is not listed among the explicitly unguarded surfaces. |
| F4 | Low | Confirmed | Documentation overclaims independence from supported metadata edits and repeats verification claims that were not independently established in this audit. |
| F5 | Low | Confirmed | Regression coverage omits `bext`/`iXML`, post-write token stability, RF64/RIFX/leading-ID3 FLAC, malformed AIFF/AIFC, untyped function references, and the deprecated overload. |
| F6 | Informational | Confirmed | The cost probe records observations without thresholds, and the documented millisecond ranges are environment-dependent and not exactly reproducible. |
| F7 | Informational | Confirmed, acceptable | A guarded write holds the same-entry mutation coordinator while hashing the transactional copy, so same-file writers wait for O(audio) time. This is inherent to the guard and does not affect independent files. |
| F8 | Informational | Verified, no defect | The audio-region hashing, framing, bounds checks, descriptor/path version checks, staged guard placement, and final destination version check are sound for the supported layouts. No false-negative continuity case was found for encoded audio in those layouts. |

### F1. `bext`/`iXML` WAVE chunk relocation invalidates a metadata-only identity

**Severity:** Medium. This is a functional false positive, not a data-corruption defect. It would be High if the target product requires automatic metadata-only rebase for Broadcast Wave or iXML-bearing WAVE files, because those layouts fail the advertised workflow.

**Affected code:** `Sources/TagLibAudioMetadata/MetadataAudioContentIdentity.swift`, primarily the WAVE chunk loop at lines 102-142 and the exclusion list at line 128; `appendRange` at lines 62-75 and line 139; `requireAudioContent` at lines 218-226.

**Root cause:** The reader hashes every non-excluded WAVE chunk in file order: chunk ID, 8-byte length prefix, and payload. The WAVE exclusion list is `id3 `, `ID3 `, `JUNK`, `PAD `, and `LIST` whose type is `INFO`. `bext` and `iXML` are not excluded, so their identity depends on both payload and position. TagLib 2.3.1's WAVE save path relocates both chunks, typically from before `data` to after `data`, when it writes ID3/INFO metadata. The audio `data` payload is unchanged, the 602-byte `bext` payload was verified byte-identical in a dedicated comparison, and the `iXML` chunk retained its length across the relocation; the byte sequence of included chunks nevertheless changes, so the SHA-256 digest changes. The same structural behavior was observed for a raw delta, an artwork change, and metadata erasure on `bext`; these all reach a TagLib WAVE save.

**Reproduction evidence:** I built a valid 44.1 kHz, 16-bit, stereo PCM WAVE with the common BWF layout `fmt `, 602-byte `bext`, `data`, then applied a normal typed title patch. The before/after chunk sequences from the independent probe were:

```text
bext before data: stable=false
  before=fmt (16),bext(602),data(176400)
  after =fmt (16),data(176400),bext(602),ID3 (1054)
```

The `bext` payload compared byte-for-byte equal and the `data` payload compared byte-for-byte equal. An `iXML` chunk in the same position behaved identically:

```text
iXML before data: stable=false
  before=fmt (16),iXML(17),data(176400)
  after =fmt (16),data(176400),iXML(17),ID3 (1054)
```

With the baseline identity A and a current file whose `data` chunk is unchanged, a guarded patch using the current file version and A throws:

```text
bext typed title: stable=false audioUnchanged=true guard=threw changed
bext raw title:   stable=false audioUnchanged=true guard=threw changed
bext artwork:     stable=false audioUnchanged=true guard=threw changed
bext erase:       stable=false audioUnchanged=true
iXML typed title: stable=false audioUnchanged=true guard=threw changed
iXML raw title:   stable=false audioUnchanged=true guard=threw changed
```

Placing the chunk after `data` makes the identity stable under the same title patch:

```text
bext after data: stable=true
  before=fmt (16),data(176400),bext(602)
  after =fmt (16),data(176400),bext(602),ID3 (1054)
```

The first guarded write on a pre-relocation BWF file also self-invalidates its token. The guard checks the staged copy before mutation and therefore passes; the write then relocates `bext`; the committed file's identity differs:

```text
baseline identity=...
first guarded succeeded, postWriteIdentityEqual=false
second guarded with original token: threw changed
third guarded with refreshed token: accepted
```

By contrast, simple WAVE without these chunks, AIFF/AIFF-C, and FLAC were stable across title, large album growth, artwork and erase edits in the independent probes. The AIFF `APPL`, `COMT`, `MARK` and `INST` chunks, the FLAC `APPLICATION` chunk, and WAVE `fact`, `cue `, `smpl`, `inst`, `cart`, `MD5`, `PRIV`, `XMP `, `DISP` and `FLLR` chunks did not exhibit this relocation in the tested paths.

**Impact:** A consumer that follows the documented baseline/current comparison will see a non-nil token mismatch after an ordinary metadata-only edit on a BWF/iXML WAVE file and will reload, even though the audio is unchanged. A consumer that ignores the mismatch and calls the guarded overload gets `.changed`. A consumer that performs a guarded write and reuses the same token for a subsequent write gets `.changed` until it re-reads. The feature therefore does not deliver automatic metadata-only rebase for a standard professional WAVE layout, and the type doc/changelog claim that it is independent of supported metadata edits is incorrect for that layout. No audio is lost or corrupted; the failure is fail-closed.

**Recommended remediation (choose one and test it):**

1. Exclude `bext` and `iXML` from the identity alongside the existing metadata exclusions, and document them as non-audio ancillary chunks. This is the smallest change. It is defensible for `iXML`; `bext` also contains a time reference, so if that interpretation is considered part of the audio contract, use option 2 instead.
2. Make the identity insensitive to non-audio chunk ordering. For example, hash audio-bearing chunks (`fmt `, `data`, `fact`, and any other decode-relevant chunk) in a canonical order, and hash ancillary chunks as a normalized multiset or in sorted ID order. This preserves `bext`/`iXML` content detection while removing the relocation false positive.
3. If neither is acceptable, explicitly return `nil`/`.unavailable` for WAVE layouts containing `bext` or `iXML` and document the unsupported layout, so callers are not given a token that silently becomes stale. This is less useful but honest.

In all cases, add regression fixtures with `bext` and `iXML` before `data`, plus a test that a successful guarded write leaves the returned token valid for the next guarded write (or that the documented re-read requirement is enforced/documented). Correct `MetadataAudioContentIdentity.swift` line 6, `CHANGELOG.md` line 12, and the continuity contract to state the BWF/iXML limitation if the conservative behavior is retained.

**Test gap:** `Tests/TagLibAudioMetadataTests/Transactions/AudioContentIdentityTests.swift` never mentions `bext` or `iXML`. Its WAVE fixture (`testAudioFile.wav`) contains `fmt `, `FLLR`, and `data`; `FLLR` is stable, so the test matrix passes and masks the BWF/iXML case. The `metadataEditsArtworkAndErasureRetainIdentity` test at lines 26-52 is therefore an inadequate proof of the "independent of supported metadata edits" claim for WAVE generally.

### F2. Added overloads make untyped function references ambiguous

**Severity:** Low. This is a source-compatibility regression in a narrow usage pattern. Typed references, which the compatibility test covers, still compile.

**Affected code:** `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift` lines 405-409 and 447-456; `Sources/TagLibAudioMetadata/TagLibMetadataManager+Read.swift` lines 462-466; the deprecated overload at `MetadataSnapshotPatch.swift` lines 841-850; the restored initializers at `MetadataSnapshotPatch.swift` lines 44-83.

**Root cause:** Adding another public declaration with the same base name creates an overload set. Swift cannot resolve an untyped function reference such as `let f = TagLibMetadataManager.readSnapshot` without a contextual function type, so a previously valid expression becomes ambiguous. The same applies to `readBasicSnapshot`, `applyMetadataPatch`, `applyRawMetadataPatch`, and `BasicMetadataSnapshot.init` when no type context is provided. `MetadataSnapshot.init` happened to resolve to the legacy four-argument initializer under this compiler and context, but its untyped use is no longer guaranteed to select a unique shape across contexts. Typed declarations such as `let _: (URL) throws -> MetadataSnapshot = TagLibMetadataManager.readSnapshot` continue to compile; `Tests/TagLibAudioMetadataTests/ReviewSourceCompatibilityTests.swift` lines 23-28 verify that shape.

**Reproduction evidence:** Compiling a client file containing `let f = TagLibMetadataManager.readSnapshot` against the built module produced:

```text
error: ambiguous use of 'readSnapshot'
note: found this candidate ... readSnapshot(from:)
note: found this candidate ... readSnapshot(from:includingAudioContent:)
```

Equivalent errors occur for `readBasicSnapshot`, `applyMetadataPatch`, `applyRawMetadataPatch`, and `BasicMetadataSnapshot.init`; `MetadataSnapshot.init` resolved in this specific untyped test but should not be relied on to select a unique shape.

**Impact:** A client that stores an untyped function reference to one of the affected families breaks at compile time on upgrade. Direct calls and typed references are unaffected. The project explicitly committed to preserving public function-reference compatibility in commit `2079800`, so this is a real but narrow gap in that goal.

**Recommended remediation:** Either accept and document the limitation (typed references are the supported compatibility surface), or avoid overloading the existing base names for the new functionality (for example, distinct `readSnapshotIncludingAudioContent`/`applyMetadataPatchWithAudioIdentity` names), or add a compatibility note/test that demonstrates the supported typed shapes. If the new names are changed, re-run the compatibility tests and update the docs.

### F3. The deprecated typed overload remains unguarded

**Severity:** Low. This is a legacy API path, explicitly deprecated, and consistent with the general "other write surfaces remain unguarded" limitation, but it is not enumerated in the continuity document.

**Affected code:** `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift` lines 841-850. The deprecated `applyMetadataPatch(_:to:expectedVersion:failurePolicy:)` forwards to the unguarded three-argument `applyMetadataPatch`, so it never checks `expectedAudioContent` because it has no such parameter.

**Reproduction evidence (code inspection):**

```swift
@available(*, deprecated, message: "Verification mismatches always throw. Omit failurePolicy.")
@discardableResult
public nonisolated static func applyMetadataPatch(
    _ patch: MetadataPatch,
    to url: URL,
    expectedVersion: MetadataFileVersion? = nil,
    failurePolicy: VerificationFailurePolicy
) throws -> MetadataWriteResult {
    try applyMetadataPatch(patch, to: url, expectedVersion: expectedVersion)
}
```

The forwarded call resolves to the unguarded overload, so a caller using the deprecated typed delta path with a fresh version can apply a stale draft after audio replacement. This is a behavior of the existing unguarded surface, not a regression introduced by the new code, but the new documentation says "Other write surfaces (Basic replacement, whole-map raw replacement, structured and bridge APIs) have no new audio guard"; the deprecated typed overload is not in that list.

**Impact:** A legacy consumer could believe it has adopted the new guard while still using the deprecated typed overload. It would not get the audio check. The API is deprecated, so normal migration avoids it.

**Recommended remediation:** Add the deprecated overload to the explicit list of unguarded surfaces in `docs/AUDIO_CONTENT_CONTINUITY.md`, or remove/forward it through a guarded path if backward compatibility permits. Add a regression test that documents the chosen behavior.

### F4. Documentation claims and verification statements need qualification

**Severity:** Low. This is documentation accuracy, not runtime correctness, but it directly affects adoption decisions and the credibility of the verification table.

**Affected code/documentation:** `Sources/TagLibAudioMetadata/MetadataAudioContentIdentity.swift` line 6 ("independent of supported metadata edits"); `CHANGELOG.md` line 12 ("independent of supported tag edits"); `docs/AUDIO_CONTENT_CONTINUITY.md` lines 101-112 (availability table and ancillary warning), lines 115-117 (unavailable formats), lines 121-126 (cost), lines 143-163 (verification table); `README.md` lines around the new adoption paragraph.

**Evidence and impact:**

- F1 contradicts the unqualified "independent of supported metadata edits" claim for BWF/iXML. The detailed table implies their inclusion under the "each non-excluded chunk" rule and the warning at lines 110-111 says ancillary edits may change the token, but the type-level and changelog claims are stronger and false for these layouts. The continuity document should name `bext` and `iXML` explicitly and explain that a TagLib metadata save may relocate them.
- The verification table says "iOS 16 arm64 Release compilation | Passed with Swift warnings-as-errors and Clang Werror" and "Full SwiftPM Release suite ... 153 XCTest ... plus 69 Swift Testing passed". This audit independently reproduced a successful iOS Simulator build (Debug, 11.663 s, no errors or warnings) and the Xcode Debug suite (222 tests, 220 passed, 2 skipped, 0 failed), but did not reproduce an iOS Release/arm64 build, a SwiftPM Release suite, or the external AudioMator application suite. The document itself labels the iOS row compilation-only and the external suite as not run, which is good; the exact Release/SwiftPM claims should be treated as the author's local evidence unless independently checked.
- The cost paragraph cites 1.26-2.53 ms, 16.05-16.64 ms and 66.08-85.36 ms for 1/16/64 MiB. My independent 64 MiB measurement was 75.5-78.6 ms for audio hashing and 0.24-3.9 ms for the default read; an earlier run under different load produced 85.8-112.9 ms. The order of magnitude and O(audio) behavior are correct, but the exact ranges are environment-dependent. The document already says these are observations, not promises; keep that qualification and avoid presenting the ranges as a reproducible acceptance criterion.
- The "14 regression/cost tests" count is correct. The "222 discovered; 220 passed, 2 existing opt-in skips" claim is correct for the Xcode Debug suite I ran. The two skips are confirmed to be `ExternalCorpusPreservationTests` and `SnapshotThroughputBenchmarkTests`.

**Recommended remediation:** Qualify the independence claim to "independent of supported tag regions; ancillary chunk order and ancillary edits may invalidate the token", add the `bext`/`iXML` case to the continuity table/notes and the README, and mark the iOS Release/SwiftPM Release/AudioMator results as author-reported local verification rather than reproduced by this audit. Keep the cost numbers labeled as observations.

### F5. Regression coverage gaps

**Severity:** Low. The existing tests are strong for the fixtures they use, but several documented claims have no direct test.

**Confirmed gaps:**

- No `bext` or `iXML` WAVE test, which is why F1 was not caught.
- No test that a successful guarded write leaves the token valid for a subsequent guarded write, on any format; the BWF case would fail and the simple-fixture case would pass.
- No RF64, RIFX, or leading-ID3 FLAC test despite those being named as unavailable in `docs/AUDIO_CONTENT_CONTINUITY.md` lines 115-116.
- No malformed AIFF/AIFF-C negative test; `malformedAndAmbiguousLayoutsAreUnavailable` covers WAVE and FLAC only.
- No multi-`COMM`/multi-`SSND` AIFF test; the parser rejects them by count, but there is no regression proof.
- No test for untyped function-reference compatibility; the compatibility test uses typed references only.
- No test for the deprecated `failurePolicy` typed overload's guard behavior.
- No test for a `bext`/`iXML` file already in the post-data normalized order, which is the workaround state.
- No test that the guard rejects a changed audio file while the destination bytes and staged-directory cleanup remain intact for `.unavailable` as well as `.changed`; the `.changed` test covers both, the `.unavailable` test checks destination bytes but not the directory listing.

**Impact:** The green suite gives false confidence about "WAVE" support and about the absence of post-write token invalidation. The F1 behavior is invisible to the current tests.

**Recommended remediation:** Add fixtures/tests for: BWF `bext` before `data`; iXML before `data`; the same after `data`; a guarded-write-then-second-guarded-write sequence; RF64/RIFX/leading-ID3 FLAC nil identity; malformed AIFF/AIFC; untyped/typed compatibility references; and the deprecated overload's documented behavior.

### F6. Cost probe is observational, not a threshold test

**Severity:** Informational.

**Affected code:** `Tests/TagLibAudioMetadataTests/Transactions/AudioContentIdentityTests.swift` lines 355-389.

**Observation:** The test generates 1/16/64 MiB PCM WAVE files, reads them three times, prints `AUDIO_IDENTITY_COST`, and asserts only that the identity is non-nil and changes after the final-byte mutation. It has no timing threshold, by design. The documentation quotes exact ranges. My run of the same test produced 1 MiB 1.10-2.55 ms, 16 MiB 22.65-23.19 ms, and 64 MiB 85.8-112.9 ms; a later direct probe produced 75.5-78.6 ms for 64 MiB. The variation is expected for a cached local filesystem. This is not a defect; the test is correctly non-gating.

**Recommended remediation:** Keep the no-threshold design; in the docs, avoid implying a stable range and state the machine/load caveat. If a regression guard is desired, use a generous ceiling or a throughput ratio rather than the exact documented milliseconds.

### F7. Guard holds the same-entry coordinator during the audio scan

**Severity:** Informational, acceptable.

**Affected code:** `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift` lines 501-505; `Sources/TagLibAudioMetadata/RawMetadataPatch.swift` lines 137-140; `TagLibMetadataManager.swift` lines 159-174 and 219-221.

**Observation:** The guard runs inside `withAtomicMetadataWriteMutation`, which holds the native per-directory-entry mutation coordinator for the duration of the operation. Hashing the staged copy is therefore O(audio) time during which other writers to the same entry wait. It does not hold the TagLib global parser mutex while streaming, and reads do not take the entry lock, so independent files and readers are unaffected. In my same-file contention probe, 8 concurrent guarded writes produced exactly 1 success and 7 `TagLibManagerError.fileChanged`, with no leftover temporary files. The behavior is correct; the contract should mention the same-entry wait if latency is documented.

**Recommended remediation:** None required. Optionally state in the continuity/thread-safety docs that the guarded write's second scan occurs under the same-entry coordinator, so concurrent same-file writers wait for it.

### F8. Verification of the core hash and guard that did not reveal defects

**Status:** Verified, no defect found. This section records the independent checks so the absence of a finding is evidence-based rather than assumed.

- The reader hashes `data`/`SSND`/FLAC frames and interpretation chunks (`fmt `, `COMM`, `STREAMINFO`, application blocks) and uses length-prefixed records, so a changed audio payload or changed decode parameters changes the digest. My probes flipped final audio bytes and interpretation bytes and observed changed identities.
- Unsupported or ambiguous layouts return `nil` from `audioContentIdentity` and are treated as `.unavailable` by the guard. The malformed WAVE/FLAC tests and my crafted-layout probes confirm this.
- The snapshot read captures a file version, extracts metadata, scans audio with its own descriptor/path revalidation against that version, and performs a final path-version check. The read-race tests and my independent reads did not produce a mixed snapshot.
- The guarded patch checks the staged copy's identity before mutating it, then retains the existing final destination-version check. The `.changed`, `.unavailable`, stale-version and final-guard tests all pass.
- Concurrent reads and guarded writes of independent files produced zero errors in my probe; same-file writes produced one winner and no leftovers.
- AIFF, AIFF-C and FLAC metadata edits (title, large album growth, artwork, erase) preserved identity in my probes except for the F1 WAVE chunks. FLAC `APPLICATION`, AIFF `APPL`/`COMT`/`MARK`/`INST`, and WAVE `fact`/`cue `/`smpl`/`inst`/`cart`/`MD5`/`PRIV`/`XMP `/`DISP`/`FLLR` remained stable in the tested paths.

## 4. Test Assessment

### Existing coverage

The new file `Tests/TagLibAudioMetadataTests/Transactions/AudioContentIdentityTests.swift` contains 14 tests:

| Test | What it establishes | Assessment |
| --- | --- | --- |
| `optInIdentitiesMatchAcrossSnapshotProjections` | Full and Basic reads return equal identities for WAV, AIFF, FLAC; default reads return nil. | Good. |
| `metadataEditsArtworkAndErasureRetainIdentity` | Title, raw album, artwork and erase preserve identity for the three fixtures. | Good for the fixtures; does not cover `bext`/`iXML` (F1). |
| `sameInodePayloadReplacementChangesIdentity` | Same-inode, same-mtime audio-byte replacement changes the identity. | Good; exercises the core false-negative case. |
| `guardedTypedAndRawRebasesRejectReplacementAudio` | A fresh current version does not authorize stale audio; `.changed`; destination bytes unchanged; staged copy removed. | Good. |
| `guardedRebasesAcceptMetadataOnlyChangesAndKeepVersionGuard` | Matching audio plus stale version is rejected; matching audio plus current version is accepted; metadata preserved. | Good. |
| `guardedRebasesFailClosedWhenCurrentLayoutIsUnavailable` | An unsupported current layout yields `.unavailable`; destination unchanged. | Good; does not check staged-directory cleanup. |
| `finalTransactionGuardStillRejectsChangesAfterAudioValidation` | External replacement after the audio guard but before commit is rejected by the final version check. | Good. |
| `unsupportedFormatsDoNotGrantContinuity` | MP3, M4A, Ogg, WavPack return nil. | Good but narrow representation of the documented unsupported list. |
| `malformedAndAmbiguousLayoutsAreUnavailable` | Empty/truncated/oversized/duplicate-data WAVE and malformed FLAC return nil. | Good; no AIFF/AIFC malformed cases. |
| `interpretationParametersAlsoChangeIdentity` | A byte change in `fmt `, `COMM`, or `STREAMINFO` changes identity. | Good. |
| `audioReaderRejectsChangesAfterStreamingBeforeFinalVersionCheck` | In-place and rename replacement during/after streaming are rejected. | Good; uses internal seam. |
| `aifcAndOddChunkPaddingRetainMetadataIndependence` | Synthesized AIFF-C with FVER, odd/unknown chunks, NAME metadata; identity stable after NAME and guarded title; changed after SSND byte. | Good and directly relevant to AIFF-C/odd padding. |
| `streamingReadsCoverFullPayloadAndMeasureLocalCost` | 1/16/64 MiB reads; final-byte mutation changes identity; prints costs. | Good as a probe; no threshold; BWF not covered. |
| `audioSnapshotsRejectChangesBetweenExtractionAndReturn` | A mutation after extraction causes `fileChanged` for full and Basic reads. | Good. |

The compatibility test `ReviewSourceCompatibilityTests.swift` lines 23-28 verifies typed function-reference shapes for the old snapshot initializers, readers and typed/raw patches, and the new guarded overloads. It does not verify untyped references.

### Results independently observed

- Focused `AudioContentIdentityTests`: 14/14 passed.
- Full Xcode Debug suite: 222 discovered, 220 passed, 2 skipped, 0 failed. The two skips are the environment-gated `ExternalCorpusPreservationTests` and `SnapshotThroughputBenchmarkTests`, matching the documentation.
- iOS Simulator build: succeeded, 11.663 s, zero errors, zero warnings in the build log.
- The `GetTestList` result shows 222 enabled tests, matching the documentation's count.

### Independent experiments

I linked small Swift executables against the freshly built package and the TagLib framework, then ran them outside the repository. The probes generated real PCM WAVE, AIFF, AIFF-C and FLAC containers and used the public read/write/guard APIs. The results are summarized below.

| Experiment | Result |
| --- | --- |
| Simple WAVE, AIFF, AIFF-C, FLAC: title, large album growth, artwork, erase | Identity stable; guarded patches accepted where applicable. |
| WAVE with `bext` before `data` | Identity changed after any metadata save; guard `.changed`; data payload unchanged (F1). |
| WAVE with `iXML` before `data` | Same as `bext` (F1). |
| WAVE with `bext` after `data` | Identity stable, showing the relocation/workaround state. |
| WAVE with `JUNK`, `PAD `, `LIST/INFO`, `id3 `, `FLLR`, `fact`, `cue `, `smpl`, `inst`, `cart`, `MD5 `, `PRIV`, `XMP `, `DISP`, `axml` | Stable in the tested paths. |
| AIFF with `NAME`, `AUTH`, `ANNO`, `COMT`, `MARK`, `INST`, `APPL` before/after COMM/SSND | Stable in the tested paths. |
| FLAC with one/two `APPLICATION` blocks, seek table and padding; title, artwork, erase | Stable; application block count preserved. |
| Audio byte / interpretation byte mutation | Identity changed. |
| Concurrent reads of 8 independent 1 MiB WAVE files (64 iterations) | 0 errors. |
| Concurrent guarded writes to 8 independent files | 0 errors; all titles correct. |
| 8 concurrent guarded writes to one file | 1 success, 7 `fileChanged`, 0 other; no `taglib` leftovers. |
| 64 MiB Basic read: default vs including audio | Default 0.24-3.9 ms; audio 75.5-78.6 ms (cached local). |
| 64 MiB typed write: unguarded vs guarded | Unguarded 26.8 ms; guarded 125.6 ms (one extra audio scan). |
| Untyped `let f = TagLibMetadataManager.readSnapshot` | Ambiguous at compile time (F2). |

### Test weaknesses and missing regressions

The suite's main weakness is fixture selection rather than test logic. The WAVE fixture has an `FLLR` chunk but no `bext` or `iXML`; the AIFF fixture has no native ancillary chunks; the FLAC fixture has Vorbis/padding but no `APPLICATION`. The tests therefore prove stability for a subset of layouts while the documentation generalizes to WAVE/AIFF/FLAC. The following regressions should be added:

- `bext` before `data`, BWF title/raw/artwork/erase; identity must either remain stable (if excluded/canonicalized) or be explicitly documented as unavailable.
- `iXML` before `data`, same matrix.
- `bext`/`iXML` after `data`, to lock in the current normalized-order behavior.
- A guarded write followed by a second guarded write using the same baseline token; assert the token remains valid or the documented re-read requirement is enforced.
- RF64, RIFX, and leading-ID3 FLAC: assert the documented nil/unavailable outcome.
- Malformed AIFF/AIF-C: multiple COMM/SSND, truncated COMM, invalid SSND offset, odd chunk padding.
- Untyped function-reference compatibility, or a documented test that only typed references are guaranteed.
- Deprecated `failurePolicy` typed overload: assert the documented unguarded behavior or the new guard.
- `.unavailable` guard rejection checking destination bytes and staged-directory cleanup.
- A cost regression guard with a generous ceiling or a ratio, if desired; keep it opt-in if timing is environment-sensitive.

## 5. Compatibility and Performance

### Public API and source compatibility

The change is source-additive for direct callers:

| API | Status |
| --- | --- |
| `MetadataSnapshot` / `BasicMetadataSnapshot` stored properties | Added `audioContentIdentity`; `Sendable` remains satisfied. |
| `MetadataSnapshot.init(basic:raw:structured:fileVersion:)` | Restored by commit `2079800`; typed reference compiles. |
| `BasicMetadataSnapshot.init(metadata:fileVersion:)` | Restored by commit `2079800`; typed reference compiles. |
| `MetadataSnapshot.init(..., audioContentIdentity:)` | New five-argument initializer; `fileVersion` has a default, `audioContentIdentity` does not. |
| `BasicMetadataSnapshot.init(..., audioContentIdentity:)` | New three-argument initializer; `audioContentIdentity` has no default. |
| `readSnapshot(from:)`, `readBasicSnapshot(from:)` | Unchanged behavior; default no audio scan; typed references compile. |
| `readSnapshot(from:includingAudioContent:)` | New public overload; opt-in audio scan. |
| `readBasicSnapshot(from:includingAudioContent:)` | New public overload; opt-in audio scan. |
| `applyMetadataPatch(_:to:expectedVersion:)` | Unchanged three-argument path; unguarded; default no audio scan. |
| `applyMetadataPatch(_:to:expectedVersion:expectedAudioContent:)` | New four-argument guarded overload; both parameters non-optional. |
| `applyRawMetadataPatch(_:to:expectedVersion:)` | Unchanged three-argument path; unguarded. |
| `applyRawMetadataPatch(_:to:expectedVersion:expectedAudioContent:)` | New four-argument guarded overload. |
| `MetadataAudioContentIdentity` | New public `Hashable`, `Sendable` value with a private digest; no public constructor or serialization. |
| `MetadataAudioContentError` | New public `Error`, `Equatable`, `Sendable`, `LocalizedError` enum with `.unavailable` and `.changed`. |

Typed function-reference compatibility is covered by `ReviewSourceCompatibilityTests.swift` and compiles. Untyped function references are now ambiguous (F2). There is no ABI-stability promise for this SwiftPM library; the Swift library is rebuilt from source, and the binary target is the separate TagLib framework. Existing direct calls, named arguments and typed references are source-compatible. Adding a stored property to a public struct changes its layout, which is acceptable for a source-distributed package but should be noted for any client that reflects or serializes the value; the type does not conform to `Codable`.

### Behavioral compatibility

- Default `readSnapshot` and `readBasicSnapshot` still do not hash audio and return `audioContentIdentity == nil`. The full suite and the `optInIdentities...` test confirm this.
- The default three-argument typed/raw patch paths still do not hash audio. The guard is only compiled into the new four-argument overloads.
- Existing read/write signatures and default I/O behavior are retained. The only default-path change is internal: the audio scan (when opted in) now runs after the extraction seam, which is not a public behavior change.
- The new guarded overloads require both `expectedVersion` and `expectedAudioContent`; there is no overload accepting an optional version plus an identity, so callers must unwrap `MetadataSnapshot.fileVersion` or use `BasicMetadataSnapshot.fileVersion`. The documentation shows the unwrap.
- The deprecated `failurePolicy` typed overload remains unguarded (F3).
- Other write surfaces (Basic replacement, whole-map raw replacement, structured and bridge APIs) remain unguarded, as documented.

### Platform/build compatibility

The package declares macOS 13 and iOS 16. `CryptoKit` and the used `Darwin` APIs are available on both. The iOS Simulator build succeeded in this audit. An actual iOS 16 arm64 Release/device build was not reproduced; the documentation claims one. The macOS Debug build and full test suite succeeded.

### Performance

The opt-in read is O(audio size) and uses a maximum 64 KiB read buffer with bounded memory. The guard adds one scan of the transactional copy. Measured on a cached local filesystem:

| Workload | Observation |
| --- | --- |
| 64 MiB WAVE Basic read, default | 0.24-3.9 ms (warm), including first-call noise. |
| 64 MiB WAVE Basic read, including audio | 75.5-78.6 ms (one run); 85.8-112.9 ms in a differently loaded run. |
| 64 MiB WAVE typed write, unguarded | 26.8 ms. |
| 64 MiB WAVE typed write, guarded | 125.6 ms (approximately one extra audio scan). |
| 1/16/64 MiB from the repository cost test | 1.10-2.55 ms, 22.65-23.19 ms, 85.8-112.9 ms in my run; documented ranges are 1.26-2.53 ms, 16.05-16.64 ms, 66.08-85.36 ms. |

These measurements confirm the documented O(audio) behavior and the additional scan cost. They do not reproduce the exact documented ranges, which is expected for a cached local machine under varying load. The guard's same-entry wait (F7) is the main concurrency cost; independent files and readers are unaffected in the probes. Memory remains bounded because payloads are read in at most 64 KiB blocks and hashed immediately.

## 6. Remaining Risks

### Confirmed defects

- F1: `bext`/`iXML` WAVE metadata-only edits change the identity and cause false `.changed` rejections; the first guarded write can invalidate its own token. Fail-closed, no data loss.
- F2: Untyped function references become ambiguous; typed references remain compatible.
- F3: The deprecated typed patch overload remains unguarded and is not explicitly listed.

### Intentional limitations and documented behavior

- Only native FLAC and single-data-chunk RIFF WAVE / AIFF / AIFF-C layouts have identities. RF64, RIFX, leading-ID3 FLAC, MP3, MP4/M4A, raw AAC, Ogg/Opus, ASF, APE, WavPack, Musepack, TTA, DSD and tracker formats return nil.
- `nil` means unsupported, ambiguous or not requested, and two nil values must never be treated as continuity. The guarded overload requires a non-optional identity, but a consumer comparing optionals with `==` can still fall into the nil-equals-nil trap; the docs warn explicitly.
- Tokens are in-memory, not persistent identifiers, and are not stable across package versions or re-encoding.
- The checks are optimistic, not a filesystem snapshot or cross-process lock. An uncooperative writer can still race the final check/rename interval. The docs state this.
- Other write surfaces are unguarded. The docs name the main ones; F3 adds the deprecated typed overload to the list.
- The scanner validates container boundaries, not every codec frame or checksum. A malformed but TagLib-accepted payload can still receive an identity; the audio bytes are still hashed.
- `bext`/`iXML` and other ancillary chunks are retained conservatively. The detailed table lists them under the general non-excluded rule; the type doc/changelog overclaim independence (F1/F4).

### Unverified concerns

- The iOS 16 arm64 Release build and warnings-as-errors claim was not reproduced; only an iOS Simulator build was.
- The SwiftPM Release suite (153 XCTest plus 69 Swift Testing) was not reproduced; the Xcode Debug suite was.
- The external AudioMator application suite, its N-05 reproduction and its distribution blocker were not run or verified; the documentation discloses this.
- Platform minimum-OS runtime, signing, network/provider volumes, cold-cache performance and hostile writers remain unverified, as the documentation states.
- The exact documented cost ranges are local observations and vary with load.

### Theoretical risks

- SHA-256 collision resistance is the cryptographic bound; no practical collision concern.
- The identity is not a security boundary against a malicious caller who can fabricate a file with the same digest or supply an arbitrary identity; the API is an optimistic consistency guard.
- The final check/rename interval remains racy against an uncooperative external writer; this is the existing transaction contract.
- The parser does not validate every codec frame; a TagLib-accepted but semantically invalid audio payload can receive an identity. This does not create a false negative for byte changes, because all relevant bytes are hashed.

## 7. Merge Readiness

**Verdict:** `READY WITH CAVEATS`

**MERGE RECOMMENDATION: YES**, conditional on the caveats below.

The implementation is additive, safe, and fail-closed. The core audio-region hashing and the double version/identity guard are correct for the supported layouts. The full suite and the new focused tests pass, the iOS Simulator build succeeds, and the concurrency/cost probes show no data-race or performance pathology. No data-loss or corruption defect was found.

The material caveat is F1: `bext`/`iXML` WAVE files, including the standard Broadcast Wave layout with `bext` before `data`, do not preserve the identity across a metadata-only TagLib save. The token becomes stale after an ordinary metadata edit, and even a successful guarded write invalidates the token it just checked. The current tests do not cover this, and the type doc/changelog claim unqualified independence. This is a conservative false positive, not a false negative, but it defeats the feature for a common professional WAVE layout. It must be either fixed (exclude/canonicalize the ancillary chunks) or explicitly scoped out in the contract, with regression tests. If BWF/iXML metadata-only rebasing is an acceptance requirement for the target product, this is a blocker and the verdict should be read as `NOT READY TO MERGE` with `MERGE RECOMMENDATION: NO` until that work lands.

**Minimum corrective work if the BWF/iXML requirement is in scope:**

1. Choose the normalization policy: exclude `bext`/`iXML` from the identity, or make ancillary chunk order order-insensitive, or return unavailable for those layouts.
2. Add `bext`/`iXML` before-data and after-data regression tests, including title, raw, artwork and erase paths, and a guarded-write-then-second-guarded-write token-stability test.
3. Correct the type doc, `CHANGELOG.md`, README and continuity contract to state the actual support boundary and the post-write re-read requirement if the conservative behavior remains.
4. Re-run the full suite and the iOS build after the change.

**Additional non-blocking follow-up:**

1. Document the untyped function-reference limitation or avoid the overload ambiguity (F2).
2. List the deprecated typed overload among the unguarded surfaces, or guard/remove it (F3).
3. Qualify the iOS Release, SwiftPM Release and cost claims; keep them labeled local observations (F4/F6).
4. Add the missing RF64/RIFX/leading-ID3, malformed AIFF/AIFC and cleanup regressions (F5).

## 8. Repository Integrity

At the start of the audit, `git status --porcelain=v1` returned empty, the branch was `fix/audio-content-continuity`, and `HEAD` was `873cb3e`. The report did not exist at `docs/AUDIO_IDENTITY_AUDIT_2026-10-19.md`.

No production code, tests, fixtures, existing documentation, branches, commits, merges or Git history were modified. The audit's only repository change is the creation of this report. The independent probes and their outputs were placed in `/tmp`, outside the repository. Build artifacts were produced in the existing ignored `.build` directory and Xcode's DerivedData; they are not tracked by Git. After the report is written, the only untracked path should be this report; it is intentionally left uncommitted for review.

## 9. Appendix A: Independent Reproducers

### A.1 BWF `bext` identity instability

The reproducer used the public API and a synthetic valid PCM WAVE. The container was:

```swift
let fmtPCM = Data([1,0,2,0,0x44,0xac,0,0,0x10,0xb1,2,0,4,0,16,0]) // PCM, 2ch, 44.1k, 16-bit
let audio = Data((0..<176_400).map { UInt8(truncatingIfNeeded: $0) })
let bext = Data(repeating: 0x41, count: 602) // valid BWF bext length
let bytes = riff(chunk("fmt ", fmtPCM) + chunk("bext", bext) + chunk("data", audio))
```

The public sequence was:

```swift
try bytes.write(to: url)
let baseline = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
let identity = baseline.audioContentIdentity! // non-nil

// Metadata-only edit through the public unguarded path, standing in for a
// concurrent writer or a normal first edit.
try TagLibMetadataManager.applyMetadataPatch(
    .init(fields: [.album: .text("New album")]), to: url)

let current = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
// current.audioContentIdentity != identity, even though the data chunk is unchanged.

do {
    try TagLibMetadataManager.applyMetadataPatch(
        .init(fields: [.title: .text("Rebased title")]), to: url,
        expectedVersion: current.fileVersion,
        expectedAudioContent: identity)
} catch {
    // MetadataAudioContentError.changed
}
```

The observed chunk order changed from `fmt `, `bext`, `data` to `fmt `, `data`, `bext`, `ID3 `; the `data` and `bext` payloads were byte-identical. The same sequence with an `iXML` chunk produced the same false rejection.

### A.2 First guarded write self-invalidates the token

Using the same BWF file:

```swift
let baseline = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
let id = baseline.audioContentIdentity!
try TagLibMetadataManager.applyMetadataPatch(
    .init(fields: [.title: .text("First guarded")]), to: url,
    expectedVersion: baseline.fileVersion, expectedAudioContent: id)
// Success, but the file now has bext after data.
let after = try TagLibMetadataManager.readBasicSnapshot(from: url, includingAudioContent: true)
// after.audioContentIdentity != id
try TagLibMetadataManager.applyMetadataPatch(
    .init(fields: [.title: .text("Second guarded")]), to: url,
    expectedVersion: after.fileVersion, expectedAudioContent: id)
// Throws MetadataAudioContentError.changed.
```

The third guarded write, using `after.audioContentIdentity`, succeeds. This is the exact workaround a consumer would need: re-read after every write on BWF/iXML files.

### A.3 Untyped function reference

```swift
import TagLibAudioMetadata
let f = TagLibMetadataManager.readSnapshot
```

Compiling this against the built module produced `error: ambiguous use of 'readSnapshot'` with candidates `readSnapshot(from:)` and `readSnapshot(from:includingAudioContent:)`. The typed form `let f: (URL) throws -> MetadataSnapshot = TagLibMetadataManager.readSnapshot` compiles and is covered by `ReviewSourceCompatibilityTests`.

### A.4 Concurrency and cost

The concurrency probe read 8 independent 1 MiB WAVE files with 64 concurrent operations, wrote 8 independent files with guarded patches, and launched 8 guarded writes against one file. Results: 0 read errors, 0 independent-write errors, 1 same-file success with 7 `fileChanged` and no leftovers. The 64 MiB cost probe measured 0.24-3.9 ms for a default Basic read, 75.5-78.6 ms for an audio-hashing Basic read, 26.8 ms for an unguarded typed write, and 125.6 ms for a guarded typed write.

## 10. Appendix B: Commands and Observed Results

The audit used the Xcode MCP tools for the reproducible build/test results because SwiftPM's own manifest sandbox was unavailable in this environment. The package was also built with `swift build --disable-sandbox` to produce current artifacts for the standalone probes.

| Check | Command/action | Result |
| --- | --- | --- |
| Commit range | `git diff --stat 1310e4f..HEAD` | 11 files changed, 953 insertions, 4 deletions; five commits on top of the claimed base. |
| Working tree at start | `git status --porcelain=v1` | Empty. |
| Focused identity tests | Xcode `RunSomeTests` with the 14 identifiers | 14 passed, 0 failed, 0 skipped. |
| Full test suite | Xcode `RunAllTests` | 222 total, 220 passed, 2 skipped, 0 failed. |
| iOS build | Xcode `BuildProject` on `Any iOS Simulator Device` | Succeeded, 11.663 s, 0 errors, 0 warnings in the build log. |
| Cost probe | `streamingReadsCoverFullPayloadAndMeasureLocalCost` | 1/16/64 MiB; printed measurements; passed. |
| Standalone package build | `swift build --disable-sandbox` | Build complete in 4.26 s. |
| Independent probes | Swift executables linked against `.build/out/Products/Debug` and the TagLib framework | Used for the crafted-container, BWF/iXML, concurrency and compatibility results above. |

The two skipped tests are the existing environment-gated external corpus test (`TAGLIB_PRESERVATION_CORPUS`) and the opt-in snapshot throughput benchmark (`TAGLIB_BENCHMARK=1`), matching the documentation.

---

**Report status:** Uncommitted audit report. No production code, tests, fixtures, existing documentation, branches, commits or merges were changed.
