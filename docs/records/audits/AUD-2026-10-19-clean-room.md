# Clean-Room Independent Technical Audit — TagLibAudioMetadata

**Audit date:** 2026-10-19  
**Audited branch:** `review/verification-hardening`  
**Audited revision:** `615bc8c928a57fc221dace14849455031d4d73ba`  
**Working tree at start:** clean (`git status --porcelain=v1` empty; only the branch header was printed)  
**Audit type:** independent, clean-room, read-only production audit with disposable external fixtures and harnesses  
**Report status:** primary deliverable, saved uncommitted at `docs/CLEAN_ROOM_AUDIT_2026-10-19.md`

## A. Executive Summary

TagLibAudioMetadata is a substantial and generally carefully engineered Swift package. Its strongest areas are the transaction architecture, optimistic-concurrency token model, native-bridge exception and locking discipline, source-compatibility layering, and an unusually broad test suite. The package builds cleanly, its 186-test suite passes (184 passed, 2 intentional skips), and independent AddressSanitizer and ThreadSanitizer runs over the package's Swift/Objective-C++ code reported no sanitizer finding. The transaction design correctly uses sibling clone/copy staging, file synchronization, pre-rename identity checks, atomic rename, directory synchronization, hard-link and symlink rejection, and explicit committed-but-durability-uncertain status. Those are material strengths and should not be lost in remediation.

The package is nevertheless **not ready to merge** under its current documented contracts. Independent runtime experiments produced multiple reproducible counterexamples in supported, public operations:

1. `applyMetadataPatch` can report a verified success while an MP4 semantic field still reads the old value. This occurs for schema-backed freeform fields such as `acoustID`, `acoustIDFingerprint`, and `work`, because the Basic writer and the typed Patch writer select different native keys and verification checks only the Patch-selected raw key, not the semantic field or all native aliases.
2. Typed Patch removal of ID3 comments and lyrics is broken when the native frame carries a description/language. A single `eng/Notes` comment survives `.comment: .remove` with an empty warning result; a text update appends a second comment instead of replacing the existing one. The same happens for qualified `USLT` lyrics. This affects every ID3v2-backed format, including MP3, WAV, AIFF, TTA, DSF, DSDIFF, and AAC.
3. `writeTrackNumberText` and the low-level `writeTrackNumber` on an MP3 whose metadata exists only in ID3v1 create a new, sparse ID3v2 tag containing only the track field. The package's reader still shows the ID3v1 title/artist/album because it merges fallback tags, but `ffprobe` and ID3v2-preferring players see only the track. The operation returns success with no warning.
4. Track/disc pair writes are not consistently native ID3 writes on several advertised ID3-backed formats. On AAC through Basic and number-text APIs, and on TTA, AIFF, DSF, and DSDIFF through both Basic and typed Patch paths, totals are written as separate `TXXX` fields while `TRCK`/`TPOS` contain only the number. `MetadataPatch(numberText:)` on AAC returns success while `BasicMetadata.trackNumberText` is `"03"` rather than the requested `"03/12"`.
5. MP4 Basic edits unconditionally remove recognized freeform number aliases such as `----:com.apple.iTunes:TRACKNUMBER` and `DISCNUMBER`, even when the edit is only a title change and the native `trkn`/`disk` pairs are unchanged. The low-level `writeTrackNumber` additionally removes disc aliases when it was asked only to write a track number.

Several lower-severity but real issues compound these: MP4 Basic date fields cannot be edited independently, raw PropertyMap APIs cannot target MP4 freeform keys, ASF erase fails on custom attributes, AAC loses native comment/lyric language and description spelling on an unrelated Basic edit, and the documentation overstates combined `TRCK`/`TPOS` behavior, MP4 multi-value separators, and verified deletion guarantees.

Metadata-integrity confidence is therefore **partial**, not low: the package preserves a great deal correctly and has strong controls for many formats, but the false-success and native-representation defects above are exactly the class of problem a metadata editor must not ship. Test-suite confidence is **moderate**: the tests are well organized and include real independent parsers for WAV INFO, MP4 atoms, APE, ASF, DSD, and encoded audio, but major assertions still use the package reader as the oracle, and the failing workflows are largely outside the fixture matrix. Documentation confidence is **moderate to low** on the specific contracts affected by these findings; general architectural and installation documentation is substantially accurate.

**Merge decision: NOT READY TO MERGE.** The separate recommendation is **MERGE RECOMMENDATION: NO**. The confirmed high-severity defects are within supported, documented operations, not merely unsupported edge cases. The minimum repair set is listed in section L.

## B. Repository and Architecture

### B.1 Audited state

The audit started from `review/verification-hardening` at `615bc8c928a57fc221dace14849455031d4d73ba` (`Record verification hardening evidence and final merge assessment`, 2026-10-18 22:27:51 +0800). `git status --porcelain=v1` was empty before any source inspection. The branch is 59 commits after the `0.5.3` tag (`git describe --tags` reports `0.5.3-59-g615bc8c`). No branch switch, commit, merge, reset, or tracked-file modification was performed. The only repository write is this report.

### B.2 Package configuration

`Package.swift` declares Swift tools 6.0, macOS 13+, iOS 16+, and GNU C++20. Products are `TagLibAudioMetadata` (Swift facade) and `TagLibAudioMetadataLowLevel` (`CTagLibBridge`). Targets are:

| Target | Type | Role |
| --- | --- | --- |
| `TagLib` | remote binary target | checksum-pinned `TagLibAudioMetadataTagLib-2.3.1-apple-dynamic.xcframework.zip` |
| `CTagLibBridge` | C/Objective-C++ target | public bridge header and all TagLib integration |
| `CTagLibBridgeInternalAPI` | internal target | package-only in-place primitives and coordination declarations; not a product |
| `TagLibAudioMetadata` | Swift target | facade, models, patches, verification |
| `TagLibAudioMetadataTests` | test target | 186 discovered tests plus audio/artwork resources |

The binary target is pinned to release `taglib-binary-2.3.1-r2` and checksum `d7a36b2492266a17fcd97bd776cd841d9fc85275270bc0c3cb9621395b3178c7`. The bridge links Foundation and imports TagLib headers through `TLTagLibHeaders.hpp`, which supports both the legacy `TagLib` and namespaced `TagLibAudioMetadataTagLib` header layouts. No source/static/Homebrew fallback exists.

### B.3 Execution paths

The read path is `TagLibMetadataManager.readSnapshot` / `readMetadataResult` / `readBasicSnapshot` → `TagLibMetadataExtractor.metadataProjections` → a single locked `TagLib::FileRef` session → format-specific extraction (ID3v2, MP4, Xiph, ASF, APE, RIFF) → Objective-C dictionaries → Swift value models. Reads capture file identity before and after extraction; `readSnapshot` and `readBasicSnapshot` compare the full `MetadataFileVersion`, while the simpler read APIs use the readable-content subset.

The write path is `withAtomicMetadataWriteMutation` (or `withAtomicFileMutationOutcome`) → same-entry coordination lock → expected-version check → `readMetadataResult` validation → clone/copy staging in the destination directory → in-place bridge mutation on the staging file → verification read(s) → `F_FULLFSYNC`/`fsync` on the staged file → reopen and revalidate original identity → `rename` → parent-directory sync → commit status. The public low-level bridge uses its own equivalent native transaction (`PerformAtomicTagLibMutation`) with the same clone, fsync, identity, rename, and directory-sync model.

The verification path is layered. Basic replacement verifies Basic fields, artwork presence/absence, custom keys/values, explicit advisory, and preserved raw values; typed Patch verifies number fields through `BasicMetadata` and other fields through the raw PropertyMap; raw writes verify the visible PropertyMap; structured writes verify properties, frames, atoms, attributes, artwork, lyrics, and comments. Transaction-level verification additionally re-reads the staged file to ensure it remains readable before commit.

### B.4 Public API structure

The Swift facade exposes:

| Area | Principal types and entry points |
| --- | --- |
| Reading | `readMetadataResult`, `readBasicSnapshot`, `readSnapshot`, `rawMetadataResult`, `readStructuredMetadataResult`, best-effort variants |
| Basic writing | `replaceBasicMetadata`, `updateBasicMetadata`, deprecated `writeMetadata` compatibility |
| Typed patches | `MetadataPatch`, `MetadataPatchValue`, `applyMetadataPatch`, `MetadataNumberTextPatch` |
| Raw metadata | `RawMetadataDump`, `RawMetadataPatch`, `writeRawMetadataPropertyMap[Values][WithVerification]`, `applyRawMetadataPatch` |
| Structured metadata | `StructuredMetadata`, `StructuredID3v2Frame`, `StructuredMP4Atom`, `StructuredASFAttribute`, `StructuredArtwork`, `writeStructuredMetadataWithVerification` |
| Native bridge write | `writeTagMetadata`, `MetadataWriteVerificationContext` |
| Numbering helpers | `writeTrackNumberText`, `writeNumberPairs`-equivalent behavior through patches |
| Erasure | `eraseAllMetadataWithVerification`, deprecated `eraseAllMetadata` |
| Capabilities | `formatCapabilities`, `capability(forExtension:)`, `probeFile`, field schemas, extension lists |
| Versions | `MetadataFileVersion`, `BasicMetadataSnapshot.fileVersion`, `MetadataSnapshot.fileVersion` |
| Errors | `TagLibManagerError`, patch validation errors, raw patch errors, structured validation errors |

The public Objective-C header is intentionally limited to read and transactional write APIs; in-place primitives and coordination live in `CTagLibBridgeInternalAPI`, which is not a product.

### B.5 Transaction and verification architecture

The transaction model is the strongest part of the implementation. It treats the destination path, not the inode, as the identity being coordinated; rejects symlinks and hard links; uses a sibling path so the final rename is same-volume; copies ACLs and relies on the documented `COPYFILE_CLONE` semantics for stat/xattr/data; syncs the staged file; rechecks original identity immediately before rename; and reports directory-sync failure as a committed-but-durability-uncertain outcome rather than an ordinary failure. The `MetadataFileVersion` token includes device, inode, size, link count, modification time, and status-change time, and is checked under the same-entry lock before staging. This is a solid ordinary-filesystem design with appropriately documented limits (no cross-process lock, no hardware power-loss guarantee).

### B.6 Native dependency configuration

The precompiled TagLib framework is dynamic, includes macOS arm64/x86_64 and iOS device/simulator slices, and is not sanitizer-instrumented. The package's own ASAN/TSAN runs therefore cover Swift and Objective-C++ bridge code, not TagLib internals. The package documents this limitation in `docs/THREAD_SAFETY.md`, and the current code's C++ exception containment around bridge entry points is generally consistent.

## C. Independent Production Findings

### C.1 Summary table

| ID | Severity | Confidence | Classification | Category | Short title |
| --- | --- | --- | --- | --- | --- |
| AUD-01 | HIGH | CONFIRMED | Confirmed defect | Data integrity / public API / verification | MP4 Basic/Patch native key divergence yields stale semantic fields and false verified success |
| AUD-02 | HIGH | CONFIRMED | Confirmed defect | Data integrity / public API | Typed Patch cannot remove or replace qualified ID3 comments/lyrics; removal no-ops or partially removes |
| AUD-03 | HIGH | CONFIRMED | Confirmed defect | Data integrity | `writeTrackNumberText`/low-level track writes on ID3v1-only MPEG files create sparse ID3v2 and hide unrelated fields |
| AUD-04 | HIGH | CONFIRMED | Confirmed defect | Data integrity / format correctness | AAC/TTA/AIFF/DSF/DSDIFF number pairs are split into `TRCK`/`TPOS` plus `TXXX` totals instead of combined pairs |
| AUD-05 | HIGH | CONFIRMED | Confirmed defect | Data integrity | MP4 number-alias cleanup deletes unrelated user freeform metadata on Basic edits and low-level track-only writes |
| AUD-06 | MEDIUM | CONFIRMED | Confirmed defect | Functional correctness / transaction semantics | Typed track/advisory patches fail on MP3 files with mixed ID3v1/ID3v2 because default `save()` rewrites tags |
| AUD-07 | MEDIUM | CONFIRMED | Confirmed defect | Data integrity / capability | AAC Basic edits silently degrade native ID3 comment/lyric language and description; capability omits ID3v2 |
| AUD-08 | MEDIUM | CONFIRMED | Confirmed defect | Public API contract | MP4 Basic `year`/`releaseDate` fields cannot be edited independently; misleading `.date` error |
| AUD-09 | MEDIUM | CONFIRMED | Confirmed defect | Functional correctness | Raw PropertyMap APIs cannot target MP4 freeform keys; merge fails or no-ops and replace fails |
| AUD-10 | MEDIUM | CONFIRMED | Confirmed defect | Functional correctness | ASF `eraseAllMetadataWithVerification` cannot remove custom attributes and throws residual failure |
| AUD-11 | LOW | CONFIRMED | Confirmed defect | Model / data integrity | MP4 custom freeform atoms can appear under two case variants; edits may false-fail or duplicate |
| AUD-12 | LOW | CONFIRMED | Documentation defect | Documentation | MP4 Basic multi-value separator is documented as `", "` but produces `"; "` |
| AUD-13 | LOW | CONFIRMED | Confirmed defect | Functional correctness | Lossless formats omit bit depth (Ogg FLAC, APE, WavPack, ASF) |
| AUD-14 | LOW | CONFIRMED | Test / verification gap | Verification | Basic artwork `.present` verification checks only non-nil data, not bytes or MIME |
| AUD-15 | LOW | CONFIRMED | Functional limitation | Functional correctness | Generic `writeTrackNumberText` loses exact slash display and total padding on FLAC/Ogg/MP3 |
| AUD-16 | LOW | CONFIRMED | Functional limitation | Functional correctness | Structured ASF attributes and ID3 URL/UFID frames have no removal path |
| AUD-17 | LOW | CONFIRMED | Design risk | Data integrity | Raw whole-map `.replace` on MP3 overwrites ID3v1, while docs only warn about WAV INFO/opaque fields |
| AUD-18 | LOW | UNVERIFIED RISK | Unverified risk | Transaction safety | `COPYFILE_CLONE` does not preserve setuid/setgid bits; docs claim flags/permissions coverage |
| AUD-19 | LOW | UNVERIFIED RISK | Coverage gap | Format support | AIFF, Speex, S3M, IT, Shorten, MOD have no runtime round-trip fixtures in this audit |
| AUD-20 | INFORMATIONAL | CONFIRMED | Design observation | Public API | Successful verified writes usually return empty `warnings`; most diagnostics are thrown failures |

### C.2 AUD-01 — MP4 Basic/Patch native key divergence yields stale semantic fields and false verified success

**Severity:** HIGH. **Confidence:** CONFIRMED. **Classification:** CONFIRMED DEFECT. **Category:** Data integrity, public API contract, verification.

**Affected files and locations:**

- `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift:265-296` (`propertyStorage` selects `schema.propertyMapKeys.first` for every non-MP4-native field).
- `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift:542-555` (typed Patch writes the selected key and removes only that key's alias list).
- `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift:627-678` (unedited/patched verification uses `afterRaw.properties` and the single storage key).
- `Sources/CTagLibBridge/Internal/TLPropertyMapDelta.inc:89-212` (`applyPropertyMapValuesInPlace` uses `file->properties()` and `setProperties`, which does not necessarily remove native freeform items that are not represented by the selected PropertyMap key).
- `Sources/CTagLibBridge/Internal/TLWriteBridgeOperations.inc:251-318` (Basic MP4 writer applies schema freeform mappings and canonical advisory/alias cleanup).
- `Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc:459-537` (`kWritableTextMappings`, including freeform descriptions such as `Acoustid Id`, `MusicIP PUID`, and `WORK`) and `:218-238` (reader mapping table).
- `Sources/CTagLibBridge/Internal/TLContainerExtractors.inc:405-426` (freeform extraction loop can overwrite an earlier semantic value based on item iteration order).

**Affected APIs:** `applyMetadataPatch`, `replaceBasicMetadata`, `updateBasicMetadata`, `writeTagMetadata`, and the underlying raw/property writers for MP4.

**Affected format:** MP4/M4A family (`mp4`, `m4a`, `m4b`, `m4r`, `m4v`, `3g2`).

**Triggering conditions:** A file has the schema's native MP4 freeform field (or the package previously created one through a Basic write), and the caller then updates the same semantic field through `applyMetadataPatch`. The field is one of the fields where Basic uses a schema freeform description but Patch uses a PropertyMap canonical key: `work`, `acoustID`, `acoustIDFingerprint`, `originalReleaseDate`, `artistType`, and `musicIPPUID`.

**Expected behavior:** A successful verified Patch updates the semantic field, so `readMetadataResult(from:).field` returns the requested value, and the previous native representation is either updated or removed so that a subsequent read cannot return the old value. If the writer cannot achieve that, verification must fail before commit.

**Actual behavior:** The Patch returns `MetadataWriteResult(warnings: [])` and commits, but the semantic Basic field still reads the old value for `work`, `acoustID`, and `acoustIDFingerprint`. For other fields the semantic value becomes new but the native key differs from the schema and from the Basic writer. The following table records independent observations from the audited build:

| Field | Setup | Patch result | Persisted native items | Basic read after patch |
| --- | --- | --- | --- | --- |
| `work` | Seed `----:com.apple.iTunes:WORK` = `EXTERNAL-work` via structured write; patch `.work` = `PATCH-work` | Success, warnings `[]` | `----:com.apple.iTunes:WORK` = `EXTERNAL-work` (old freeform remains); `©wrk` changed | `EXTERNAL-work` (old) |
| `work` | Basic seed `work = OLD-work`; patch `NEW-work` | Success, warnings `[]` | Freeform `WORK` = old; `©wrk` = new | `OLD-work` |
| `acoustID` | Seed `----:com.apple.iTunes:Acoustid Id` = `EXTERNAL-OLD`; patch `.acoustID` = `PATCH-NEW` | Success, warnings `[]` | `----:com.apple.iTunes:Acoustid Id` = old; `----:com.apple.iTunes:ACOUSTID_ID` = new | `EXTERNAL-OLD` |
| `acoustID` | Basic seed produced both `ACOUSTID ID` and `Acoustid Id`; patch `.acoustID` | Success, warnings `[]` | Old `Acoustid Id` remains; new `ACOUSTID_ID` added | `OLD-acoustID` |
| `acoustIDFingerprint` | External `Acoustid Fingerprint` = old; patch | Success, warnings `[]` | Old `Acoustid Fingerprint` remains; new `ACOUSTID_FINGERPRINT` added | `OLD-acoustIDFingerprint` |
| `originalReleaseDate` | Basic seed wrote `ORIGINAL YEAR`; patch `.originalReleaseDate` | Success, warnings `[]` | Old `ORIGINAL YEAR` removed; `ORIGINALDATE` written | New (semantic), but native name differs from schema |
| `artistType` | Basic seed wrote `ARTISTTYPE`; patch `.artistType` | Success, warnings `[]` | Old `ARTISTTYPE` removed; `MUSICBRAINZ_ARTISTTYPE` written | New (semantic), native name differs from schema |
| `musicIPPUID` | Basic seed `musicIPPUID` = `OLD` | **Fails** `verificationFailed(["musicIPPUID differs after save (expected \"OLD\", got \"\")"])` | Basic writer wrote `----:com.apple.iTunes:MusicIP PUID`, but reader does not recognize the spaced form | Not committed |
| `musicIPPUID` | External `MusicIP PUID` = old; patch `.musicIPPUID` | Success, warnings `[]` | Old `MusicIP PUID` remains; `MUSICIP_PUID` added | New (semantic) but old native field remains |

The critical false-success cases were reproduced independently of the package reader where possible. After the external `Acoustid Id` scenario, `ffprobe` reported both `ACOUSTID_ID=PATCH-NEW` and `Acoustid Id=EXTERNAL-OLD`; `readMetadataResult` returned `EXTERNAL-OLD`. After the `work` scenario, `ffprobe` reported the old `WORK` freeform value while the Basic field remained old.

A representative harness sequence was:

```swift
let url = copyFixture("m4a")
try TagLibMetadataManager.writeStructuredMetadataWithVerification(
    StructuredMetadata(mp4Atoms: [
        .init(key: "----:com.apple.iTunes:Acoustid Id",
              type: "stringList", values: ["EXTERNAL-OLD"])
    ]), to: url)

let before = try TagLibMetadataManager.readMetadataResult(from: url)   // acoustID == "EXTERNAL-OLD"
let result = try TagLibMetadataManager.applyMetadataPatch(
    MetadataPatch(fields: [.acoustID: .text("PATCH-NEW")]), to: url)
// result.warnings == []
let after = try TagLibMetadataManager.readMetadataResult(from: url)    // acoustID == "EXTERNAL-OLD"
```

**Technical evidence:** The verification loop at `MetadataSnapshotPatch.swift:662-669` looks up `afterRaw.properties.first { storage.writeKey.caseInsensitiveCompare($0.key) == .orderedSame }`. It never evaluates `textFieldValue(field, from: afterBasic)`. For `acoustID`, `storage.writeKey` is `ACOUSTID_ID`; that new key exists in the PropertyMap, so verification passes, even though the pre-existing `ACOUSTID ID`/`Acoustid Id` native item remains and the reader's freeform loop subsequently overwrites the semantic field with the old value. For `work`, the Patch writes `WORK` (which TagLib materializes as `©wrk`), while the Basic writer also created a freeform `----:com.apple.iTunes:WORK`; the reader's freeform loop assigns the old freeform value last.

**Root cause or suspected root cause:** The package maintains three field mapping systems that are not kept behaviorally equivalent: the Swift schema's `propertyMapKeys` and `mappings`, the Objective-C writer's `kWritableTextMappings`, and TagLib's own PropertyMap-to-native translation. `propertyStorage` chooses the first PropertyMap key for all formats instead of the schema's MP4 freeform mapping. `applyPropertyMapValuesInPlace` does not remove native freeform aliases that TagLib does not expose under the selected key, and verification checks one raw key rather than the semantic field and all aliases.

**Practical impact:** A professional editor can issue a verified `applyMetadataPatch` for a MP4 field, receive success, and continue displaying the old value. Duplicate native fields can make different tools disagree depending on atom order. This is a direct violation of the documented "a requested value that is missing or otherwise unconfirmed is a verification failure" contract and a merge blocker under the audit's criteria.

**Recommended remediation direction:** Make MP4 patch storage schema-driven per format: use the schema's `mp4`/`mp4Freeform` mappings, remove every alias including freeform items, and verify both the semantic `BasicMetadata` field and the complete alias group. Add an invariant that a successful Patch cannot leave a second native representation of the same field with an old value. The same centralized mapping should be used by Basic, Patch, raw, and structured writes.

**Suggested regression tests:** Seed `----:com.apple.iTunes:Acoustid Id` and `WORK` independently, patch `.acoustID`/`.work`/`.acoustIDFingerprint`, assert `BasicMetadata` equals the new value and exactly one native representation remains; seed via Basic first and repeat; test `originalReleaseDate` and `artistType` against their schema MP4 mappings; test `musicIPPUID` Basic round trip on M4A.

### C.3 AUD-02 — Typed Patch cannot remove or replace qualified ID3 comments/lyrics

**Severity:** HIGH. **Confidence:** CONFIRMED. **Classification:** CONFIRMED DEFECT. **Category:** Data integrity, public API contract.

**Affected files and locations:**

- `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift:265-296` (`propertyStorage` for `.comment` selects `COMMENT`; for `.lyrics` selects `LYRICS`).
- `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift:542-555` (removal/write uses only those unqualified keys).
- `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift:662-669` (verification checks only the unqualified key).
- `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift:440-455` and the schema's qualified-prefix handling (recognizes `COMMENT:` and `LYRICS:` keys for reads/preservation).
- `Sources/CTagLibBridge/Internal/TLPropertyMapDelta.inc:89-212` and the native ID3 property-map behavior.

**Affected APIs:** `applyMetadataPatch` with `MetadataPatchValue.remove` or `.text` for `.comment` and `.lyrics`.

**Affected formats:** All ID3v2-backed formats: MP3, MP2, AAC, WAV, AIFF, TTA, DSF, DSDIFF, and ID3-tagged variants of those formats.

**Triggering conditions:** A native ID3 `COMM` or `USLT` frame has a non-empty description (for example `Notes` or `Paroles`) or another property that makes TagLib expose the PropertyMap key as `COMMENT:<description>` or `LYRICS:<description>` rather than `COMMENT`/`LYRICS`.

**Expected behavior:** `.remove` removes the field entirely, including all native frames for that semantic field. `.text` replaces the existing semantic comment/lyric rather than adding a second frame. If multiple native entries cannot be faithfully represented by the scalar field, the API should reject the operation or document a precise collection contract.

**Actual behavior:** The operation returns success with `warnings == []` while doing nothing, or while appending a new frame. Independent observations:

```text
Seed single structured comment: eng/Notes/English comment
Raw before: COMMENT:NOTES = ["English comment"]
applyMetadataPatch(.comment: .remove)
Result: success, warnings []
Raw after: COMMENT:NOTES = ["English comment"]      <-- unchanged
Structured after: ["eng/Notes/English comment"]      <-- unchanged

applyMetadataPatch(.comment: .text("New comment"))
Result: success, warnings []
Structured after: ["eng/Notes/English comment", "XXX//New comment"]
Raw: COMMENT = ["New comment"] | COMMENT:NOTES = ["English comment"]
Basic.comment after: "New comment"                    <-- old native comment remains
```

The same experiment with a single `fra/Paroles/French lyrics` USLT:

```text
Raw before: LYRICS:PAROLES = ["French lyrics"]
applyMetadataPatch(.lyrics: .remove) -> success, warnings []
Raw after: LYRICS:PAROLES = ["French lyrics"]         <-- unchanged
Basic.lyrics after: "French lyrics"

applyMetadataPatch(.lyrics: .text("New lyrics")) -> success, warnings []
Structured after: ["fra/Paroles/French lyrics", "XXX/LYRICS/New lyrics"]
Raw: LYRICS = ["New lyrics"] | LYRICS:PAROLES = ["French lyrics"]
```

With two native comments or lyrics, `.remove` sometimes removes the unqualified frame and leaves the qualified one, so the operation reports success while one entry remains. This is worse than a simple no-op because it gives a false impression of partial cleanup.

**Technical evidence:** The raw PropertyMap exposes qualified keys. `propertyStorage` returns only `schema.propertyMapKeys.first` (`COMMENT` or `LYRICS`), and the bridge's `applyPropertyMapValuesInPlace` erases and writes only those keys. The verification loop then looks only for `COMMENT`/`LYRICS` after the write. For `.remove`, the absence of the unqualified key makes the verifier pass; for `.text`, the presence of the new unqualified key makes it pass. Qualified old keys are classified as unedited and unchanged, so no warning is raised.

**Root cause or suspected root cause:** The generic scalar field mapping does not include the qualified alias group that the read path and preservation path already understand. The correct fix likely requires native comment/lyric collection removal or expansion of the removal and verification sets to all `COMMENT:*`/`LYRICS:*` keys (and then a policy for which one to retain when the semantic model is scalar).

**Practical impact:** A user requesting deletion of a comment for privacy or cleanup can receive success while the comment remains on disk. A user requesting a replacement can end up with duplicate comments, with different players showing different values. This directly violates the removal and replacement contracts and is a merge blocker.

**Recommended remediation direction:** Implement a native ID3 comment/lyric writer that removes all existing frames for the semantic field before adding the requested scalar value, or explicitly reject scalar edits when multiple described frames exist and direct the caller to `StructuredMetadata`. Extend verification to inspect the full qualified key group and the structured collection count.

**Suggested regression tests:** Seed one and two qualified `COMM`/`USLT` frames and assert `.remove` clears all; seed qualified frames and assert `.text` leaves exactly one; run the same tests on MP3, WAV, AAC, TTA, DSF, and DSDIFF; verify with an independent ID3 frame parser, not only `readMetadataResult`.

### C.4 AUD-03 — ID3v1-only MPEG track writes create sparse ID3v2 and hide unrelated metadata

**Severity:** HIGH. **Confidence:** CONFIRMED. **Classification:** CONFIRMED DEFECT. **Category:** Data integrity.

**Affected files and locations:**

- `Sources/CTagLibBridge/Internal/TLMetadataCore.inc:20-32` (`SaveMetadataPreservingOtherTagSurfaces` saves MPEG with `ID3v2` only, `StripNone`, `DoNotDuplicate`).
- `Sources/CTagLibBridge/Internal/TLRawBridgeOperations.inc:471-623` (`writeTrackNumberText`, MPEG branch creates `ID3v2Tag(true)` and writes TRCK/TPOS, then uses the preserving save).
- `Sources/CTagLibBridge/Internal/TLBasicBridgeOperations.inc:152-249` (`writeTrackNumber`, MPEG branch uses the same preserving save).
- `Sources/CTagLibBridge/Internal/TLWriteBridgeOperations.inc:1-160` (Basic `writeMetadata` writes title/artist/etc. to the `tag` object and therefore promotes fields differently; this contrast is control evidence).

**Affected APIs:** `writeTrackNumberText`, `writeTrackNumber` (public low-level bridge), and indirectly any public operation that creates a new ID3v2 tag for a track update.

**Affected formats:** MP3 and MP2 (MPEG audio with ID3v1-only metadata).

**Triggering conditions:** A valid MPEG audio file has only an ID3v1 tag (or has a rich ID3v1 tag but no on-disk ID3v2 tag), and the caller writes a track/disc number using `writeTrackNumberText` or the low-level `writeTrackNumber`.

**Expected behavior:** Writing the track number should not make unrelated title/artist/album/comment/genre/year metadata inaccessible. If the writer creates an ID3v2 representation, it must carry forward the existing ID3v1 fields into the preferred tag, or keep the file ID3v1-only so the existing tag remains authoritative. A verified API must not report success after causing this kind of effective loss.

**Actual behavior:** The API returns success with no warnings, creates a new sparse ID3v2 tag containing only `TRCK`/`TPOS` (plus an encoder `TSSE`), and leaves the ID3v1 fields untouched but shadowed. The package's own `readMetadataResult` still shows the old title/artist/album because it merges ID3v1 fallback per field, so its verification passes. `ffprobe`, which prefers ID3v2, shows only the new track. Independent reproduction:

```python
# Build a true ID3v1-only MP3 from the repository fixture.
data = open("Tests/TagLibAudioMetadataTests/Audio/testAudioFile.mp3", "rb").read()
n = (data[6] << 21) | (data[7] << 14) | (data[8] << 7) | data[9]   # remove ID3v2
data = data[10 + n:]
data += b"TAG" + fixed("Legacy Title", 30) + fixed("Legacy Artist", 30) + \
        fixed("Legacy Album", 30) + fixed("1999", 4) + \
        fixed("Legacy Comment", 30) + b"\0"
```

Before the call, `ffprobe` reported title, artist, album, date, comment, and genre. After `writeTrackNumberText("07/12", discNumberText: nil, to: url)` returned success with `warnings == []`, `ffprobe` reported only `TAG:track=07/12`. The package reader still reported the title and artist. The ID3v1 bytes remained on disk, so the data was not physically destroyed; it became effectively inaccessible to normal ID3v2 readers.

The low-level `TagLibMetadataExtractor.writeTrackNumber(7, totalTracks: 12, padWidth: 2, to: url)` produced the same result. The Basic `replaceBasicMetadata` path on the same input did not show this behavior because it writes the complete Basic field set through the tag object and promotes the fields into ID3v2. This contrast points to the track-only helper rather than to all ID3v1 handling.

**Technical evidence:** `SaveMetadataPreservingOtherTagSurfaces` intentionally saves only ID3v2 with `DoNotDuplicate`, which is correct for avoiding a lossy ID3v1 projection when ID3v2 already exists. It does not merge existing ID3v1 fields into a newly created ID3v2 tag. `writeTrackNumberText` calls `ID3v2Tag(true)` and writes only `TRCK`/`TPOS`, so the new tag is sparse. Its verification checks only the track/disc fields and therefore does not notice that other ID3v2-visible fields are absent.

**Root cause or suspected root cause:** A "create ID3v2 if missing" path is combined with an ID3v2-only save without a semantic carry-forward of the existing ID3v1 (or APE) tag fields. The verification layer and the package reader both mask it by merging ID3v1 fallback.

**Practical impact:** An unrelated title, artist, album, comment, genre, or year can disappear from common players after what appears to be a successful track-number edit. This is a silent metadata-preservation failure in a supported MP3 operation and a merge blocker.

**Recommended remediation direction:** For MPEG track-only writes, either update ID3v1 in place when no ID3v2 exists, or when creating ID3v2 copy all existing ID3v1/APE fields into the new tag. Add verification of unedited Basic fields and native tag surfaces. The same policy should apply to `writeTrackNumberText`, low-level `writeTrackNumber`, and any similar "create tag" helper.

**Suggested regression tests:** For true ID3v1-only MP3 and MP2 fixtures, capture native ID3v1 bytes, run each track/disc writer, read with an independent ID3v2 parser and `ffprobe`, and assert that all pre-existing fields remain visible in the preferred tag. Include controls for a tagless file and a file with both tags.

### C.5 AUD-04 — ID3-backed number pairs are split on AAC/TTA/AIFF/DSF/DSDIFF

**Severity:** HIGH. **Confidence:** CONFIRMED. **Classification:** CONFIRMED DEFECT. **Category:** Data integrity, format correctness, public API contract.

**Affected files and locations:**

- `Sources/CTagLibBridge/Internal/TLPropertyMapDelta.inc:265-463` (`writeNumberPairsInPlace` has special MPEG, WAV, and MP4 branches; all other formats enter the generic PropertyMap branch).
- `Sources/CTagLibBridge/Internal/TLPropertyMapDelta.inc:427` and `:554` (default `file.save()` paths in the native delta writer).
- `Sources/CTagLibBridge/Internal/TLWriteBridgeOperations.inc:79-100` (`writeMetadata` AAC branch uses `ApplyGenericPropertyMapToFile`; TTA/AIFF/DSF/DSDIFF use generic property map paths).
- `Sources/CTagLibBridge/Internal/TLBasicBridgeOperations.inc:152-249` (low-level `writeTrackNumber` uses the generic number-text writer for AAC/TTA/AIFF/DSF/DSDIFF).
- `Sources/CTagLibBridge/Internal/TLRawBridgeOperations.inc:471-623` and `TLBasicBridgeOperations.inc:152-249` (AAC/TTA/AIFF/DSF/DSDIFF use `WritePropertyMapNumberTextToFile`, which writes separate canonical keys).
- `Sources/CTagLibBridge/Internal/TLPropertyMapWrites.inc:70-189` (`WritePropertyMapNumberTextToFile`).
- `README.md:169-171`, `docs/SUPPORT.md:137-138`, and `docs/ARCHITECTURE.md:110-111` claim ID3 combined `TRCK`/`TPOS` and `MVIN` behavior.

**Affected APIs:** `replaceBasicMetadata`, `updateBasicMetadata`, `applyMetadataPatch` for `.track`/`.trackTotal`/`.disc`/`.discTotal` and `numberText`, `writeTrackNumberText`, public low-level `writeTrackNumber`.

**Affected formats:** AAC (`mpeg-aac`) for Basic and number-text APIs; TTA, AIFF, DSF, and DSDIFF for both Basic and typed Patch paths. MP3/MP2 and WAV have working special branches; MP4 uses native `trkn`/`disk`; FLAC/Ogg and similar generic formats use separate canonical keys by design.

**Triggering conditions:** Set a positive track/disc number and total through the affected API on one of these formats.

**Expected behavior:** For ID3v2-backed formats, the package's documented contract is combined native `TRCK`/`TPOS` values (for example `3/12` and `1/2`). The public `numberText` request with `"03/12"` should produce a track pair that reads back as the requested formatted pair or a documented normalized equivalent. Verification must not report success for a different representation that loses the total from the standard ID3 field.

**Actual behavior:** The package writes the number to `TRCK`/`TPOS` and the total to `TXXX:TRACKTOTAL`/`TXXX:DISCTOTAL`. Independent observations:

| Format / API | Resulting `TRCK`/`TPOS` | Resulting totals |
| --- | --- | --- |
| AAC via `replaceBasicMetadata` track 3, total 12, disc 1, total 2 | `TRCK=3`, `TPOS=1` | `TXXX:TRACKTOTAL=12`, `TXXX:DISCTOTAL=2` |
| AAC via `applyMetadataPatch` same typed fields | `TRCK=3/12`, `TPOS=1/2` | none |
| AAC via `MetadataPatch(numberText: "03/12", "01/02")` | `TRCK=03`, `TPOS=01` | `TXXX:TRACKTOTAL=12`, `TXXX:DISCTOTAL=2`; `Basic.trackNumberText == "03"`; success warnings `[]` |
| AAC via `writeTrackNumberText("03/12", disc: "01/02")` | `TRCK=03`, `TPOS=01` | `TXXX:TRACKTOTAL=12`, `TXXX:DISCTOTAL=2` |
| TTA, AIFF, DSF, DSDIFF via typed Patch 3/12, 1/2 | `TRCK=3`, `TPOS=1` | `TXXX:TRACKTOTAL=12`, `TXXX:DISCTOTAL=2` |
| TTA, AIFF, DSF, DSDIFF via Basic replacement | same split | same |
| FLAC/Ogg via `writeTrackNumberText("03/10", "01/02")` | `TRACKNUMBER=03`, `DISCNUMBER=01` | `TRACKTOTAL=10`, `DISCTOTAL=2`; `Basic.trackNumberText == "03"`; success warnings `[]` |

For TTA/DSF/DSDIFF, a total-only request such as `.trackTotal: .integer(10)` also succeeds with `TRACKNUMBER` absent or zero and `TRACKTOTAL=10`; the package's documented partial-pair warning says a first component cannot be removed while retaining its total on ID3/MP4, but the validation list does not include these formats.

**Technical evidence:** The native branch dispatcher in `writeNumberPairsInPlace` handles MPEG, WAV, and MP4; it does not handle TTA, AIFF, DSF, or DSDIFF. The generic property map maps `TRACKNUMBER` to `TRCK` and `TRACKTOTAL` to a separate TXXX key on ID3v2. AAC's Basic writer uses `ApplyGenericPropertyMapToFile` instead of the MPEG branch. The verification path examines `BasicMetadata.track`/`trackTotal`, which the reader derives from the split keys, so it passes. `MetadataPatch(numberText:)` runs `writeNumberPairsInPlace` first (correct combined representation on AAC) and then `writeTrackNumberTextInPlace` (split representation), leaving the final split state.

**Root cause or suspected root cause:** Format dispatch is duplicated across Basic, Patch, number-text, and low-level writers. The ID3-specific pair writer recognizes only MPEG and WAV; other ID3-backed formats fall through to a generic PropertyMap path that is correct for FLAC/Ogg but not for combined ID3 semantics.

**Practical impact:** Other ID3v2 readers see track/disc numbers but not totals, and exact formatted text is not preserved as documented. For a DSD or AIFF library editor this is a silent native representation regression. The success result makes it hard for the caller to detect.

**Recommended remediation direction:** Extend the ID3-specific pair writer to every ID3v2-backed family (MP2/MP3, AAC, WAV, AIFF, TTA, DSF, DSDIFF), using combined `TRCK`/`TPOS` and `MVIN` where supported. Reuse this writer from Basic, Patch, number-text, and low-level paths. Update `validateNativeNumberPair` and the capability tables to reflect the actual representation. If a format cannot represent a pair, fail before staging rather than writing a split custom field.

**Suggested regression tests:** For each ID3-backed format, assert native frame bytes/values (`TRCK == "3/12"`, `TPOS == "1/2"`, `MVIN` pair) after Basic, Patch, `numberText`, `writeTrackNumberText`, and low-level writes. Use an independent ID3 parser. Test total-only/zero-component rejection for every ID3-backed family.

### C.6 AUD-05 — MP4 number-alias cleanup deletes unrelated user metadata

**Severity:** HIGH. **Confidence:** CONFIRMED. **Classification:** CONFIRMED DEFECT. **Category:** Data integrity.

**Affected files and locations:**

- `Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc:97-115` (`RemoveRecognizedMP4NumberPairFreeformItems`).
- `Sources/CTagLibBridge/Internal/TLWriteBridgeOperations.inc:247-251` (Basic MP4 writer calls it with `removeTrackAliases=true, removeDiscAliases=true` before writing anything else).
- `Sources/CTagLibBridge/Internal/TLBasicBridgeOperations.inc:251-292` (low-level `writeTrackNumber` calls it with both flags true even though only track is written).
- `Sources/CTagLibBridge/Internal/TLPropertyMapDelta.inc` (Patch number writes use the same helper with more targeted flags in some branches).

**Affected APIs:** `replaceBasicMetadata` / `updateBasicMetadata` (any Basic write) and low-level `TagLibMetadataExtractor.writeTrackNumber`.

**Affected format:** MP4/M4A family.

**Triggering conditions:** A file contains freeform fields named `----:com.apple.iTunes:TRACKNUMBER`, `TRACKTOTAL`, `TRACK`, `TOTALTRACKS`, `DISCNUMBER`, `DISCTOTAL`, `DISC`, or `TOTALDISCS` (for example, a custom tag or another tool's representation). A Basic edit changes any field, even only the title; or low-level `writeTrackNumber` is called.

**Expected behavior:** A title-only Basic edit should preserve unrelated native freeform data. A low-level "write only the track number" call should not delete disc-related aliases. If the package intentionally canonicalizes number aliases, it should do so only when the corresponding number pair is being changed and should document the cleanup precisely.

**Actual behavior:** Seeding `TRACKNUMBER=CUSTOM-TRACK`, `TRACKTOTAL=CUSTOM-TOTAL`, `DISCNUMBER=CUSTOM-DISC`, `UNRELATED=KEEP`, plus native `trkn`/`disk`, then performing a Basic title edit produced:

```text
Before: DISCNUMBER=CUSTOM-DISC | TRACKNUMBER=CUSTOM-TRACK | TRACKTOTAL=CUSTOM-TOTAL | UNRELATED=KEEP | disk | trkn
After:  UNRELATED=KEEP | disk | trkn
```

`da` and `trkn` remained, but every recognized freeform alias was removed even though the track/disc numbers were unchanged. In a separate test, low-level `writeTrackNumber(7, total: 20, padWidth: 2)` on a file seeded with `DISCNUMBER`, `DISCTOTAL`, `TRACKNUMBER`, plus `trkn`/`disk` removed the disc aliases as well. The public header describes `writeTrackNumber` as writing only the track number and total (with optional padding), so deleting disc data is outside the requested operation.

**Technical evidence:** `RemoveRecognizedMP4NumberPairFreeformItems(tag, true, true)` is unconditional in the Basic MP4 writer. It is not gated by `trackPairChanged` or `discPairChanged`. The low-level `writeTrackNumber` hard-codes both flags true; it does not write disc at all. The reader skips these aliases when native `trkn`/`disk` are present, so they are opaque to the Basic model and are not preserved by the schema-driven preservation code.

**Root cause or suspected root cause:** A cleanup helper intended to prevent stale number aliases is applied too broadly. The Basic write path always rewrites the complete modeled track/disc surface, but a title-only edit still has unchanged pairs; and the low-level track API cleans disc aliases even though disc is not part of the call.

**Practical impact:** User-defined or third-party freeform metadata can disappear from a supported file after an unrelated edit. The data is not recoverable through the package reader because the aliases are hidden when native pairs exist. This is a preservation defect and a merge blocker under the audit criteria.

**Recommended remediation direction:** Only remove aliases whose corresponding pair is actually being changed. In Basic writes, compare the original and requested pair; in low-level track-only writes, pass `removeDiscAliases=false`. Document that recognized number aliases are canonicalized when numbers change, not on every write.

**Suggested regression tests:** Seed each recognized freeform alias plus `trkn`/`disk`; perform title-only Basic edit and assert all aliases remain; change only track and assert track aliases are handled but disc aliases remain; change only disc and assert the inverse; run low-level track-only and assert disc aliases remain.

### C.7 AUD-06 — Typed track/advisory patches fail on mixed ID3v1/ID3v2 MP3 files

**Severity:** MEDIUM. **Confidence:** CONFIRMED. **Classification:** CONFIRMED DEFECT. **Category:** Functional correctness, transaction semantics.

**Affected files and locations:**

- `Sources/CTagLibBridge/Internal/TLPropertyMapDelta.inc:395` and `:427` (`file.save()` default in `writeNumberPairsInPlace`).
- `Sources/CTagLibBridge/Internal/TLPropertyMapDelta.inc:583` (`file.save()` default in the MPEG branch of `writeExplicitAdvisoryInPlace`).
- `Sources/CTagLibBridge/Internal/TLMetadataCore.inc:20-32` (`SaveMetadataPreservingOtherTagSurfaces`, which should be used by these paths).

**Affected APIs:** `applyMetadataPatch` for `.track`/`.disc`/`.movement` and `explicitAdvisory` on MPEG formats.

**Affected formats:** MP3, MP2, AAC (MPEG-family save paths).

**Triggering conditions:** A file has both an ID3v2 tag and an ID3v1 tag, and ID3v1 contains fields that are absent or different in ID3v2 (for example legacy album/year/comment values).

**Expected behavior:** The operation updates the requested field and preserves unrelated native tag content, or fails cleanly without modifying the destination. The package's own `SaveMetadataPreservingOtherTagSurfaces` is the intended helper for this.

**Actual behavior:** `applyMetadataPatch(.track...)` throws `TagLibManagerError.verificationFailed` with details such as `Unedited PropertyMap field ALBUM changed during the patch`, `GENRE changed`, `DATE changed`, `COMMENT changed`. The file hash is unchanged, so the rollback is correct, but the operation is unusable on a common legacy-tag layout. `applyMetadataPatch(explicitAdvisory: .explicit)` fails similarly. A separate track patch on an MP3 with no ID3v1 tag created an empty ID3v1 tag (`TAG` + zero padding), which is an unexpected native structure even when no data was lost.

The root mechanical difference is visible in the native paths: track/advisory writes use plain `file.save()` (default `AllTags`/duplicate behavior), while Basic writes and `writeTrackNumberText` use `SaveMetadataPreservingOtherTagSurfaces` with `ID3v2`-only save and `DoNotDuplicate`. The default save causes the visible PropertyMap to change for fields that the caller did not edit.

**Technical evidence:** In the mixed-tag experiment, the initial file had `Modern Title`/`Modern Artist` in ID3v2 and `Legacy Title`/`Legacy Artist`/`Legacy Album`/`1999`/`Legacy Comment` in ID3v1. The track patch's before snapshot showed the modern ID3v2 fields; after the native save, the visible PropertyMap included the legacy album/year/comment or changed them, so the unedited-field comparison correctly aborted. The destination SHA-256 was identical before and after the failure.

**Root cause or suspected root cause:** `writeNumberPairsInPlace` and `writeExplicitAdvisoryInPlace` were not migrated to the preserving MPEG save helper. Their default `save()` has semantics that merge/duplicate ID3v1 and ID3v2, which is incompatible with the facade's preservation-oriented verification.

**Impact:** Users with legacy MP3s cannot change track numbers or explicit advisory through the typed Patch API. This is a functional regression rather than corruption, but it is a supported operation failing on realistic input and is inconsistent with the package's own helper and documentation.

**Recommended remediation direction:** Use `SaveMetadataPreservingOtherTagSurfaces` (or an equivalent explicit `ID3v2`/`StripNone`/`DoNotDuplicate` save) in every MPEG delta path, and add a preflight/merge policy for existing ID3v1/APE fields. Avoid creating empty secondary tags on tagless files.

**Suggested regression tests:** Build MP3/MP2/AAC fixtures with sparse ID3v2 plus rich ID3v1, apply track/disc/advisory patches, assert requested fields update and unedited native tags remain; assert no new empty tags appear on tagless input; compare native ID3v1 bytes before/after.

### C.8 AUD-07 — AAC Basic edits silently degrade native ID3 comment/lyric metadata

**Severity:** MEDIUM. **Confidence:** CONFIRMED. **Classification:** CONFIRMED DEFECT. **Category:** Data integrity, capability.

**Affected files and locations:**

- `Sources/CTagLibBridge/Internal/TLMetadataCore.inc:647-650` (AAC container mask is `Tag | PropertyMap`; it omits ID3v2).
- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift:899-990` (`preservedCollections` is populated only when `metadataFieldFormats` contains `.id3v2`).
- `Sources/CTagLibBridge/Internal/TLStructuredMutation.inc:1025-1045` (AAC structured branch rejects comments/lyrics).
- `Sources/CTagLibBridge/Internal/TLUnifiedExtraction.inc:113-130` (AAC read path still appends structured ID3v2 frames/comments/lyrics).
- `Sources/CTagLibBridge/TLFormatRegistry.mm:30` (AAC descriptor says PropertyMap structured support).

**Affected APIs:** `replaceBasicMetadata`, `updateBasicMetadata`, and any Basic path that performs an unrelated edit on an AAC file with native ID3 comment/lyric frames.

**Affected format:** Raw AAC (`.aac`).

**Triggering conditions:** An AAC file has ID3v2 `COMM`/`USLT` frames with language/description metadata; the caller edits an unrelated Basic field (for example the title).

**Expected behavior:** An unrelated Basic edit preserves native comment/lyric languages and descriptions (as the package does for MP3/WAV/AIFF/TTA), or fails safely if it cannot replay them.

**Actual behavior:** An independently constructed AAC file before the edit returned:

```text
comments = ["eng/Notes/Native comment"]
lyrics   = ["fra/Paroles/Native lyrics"]
```

After `replaceBasicMetadata` with only the title changed, it returned success with `warnings == []` but:

```text
comments = ["XXX/NOTES/Native comment"]
lyrics   = ["XXX/PAROLES/Native lyrics"]
```

The text survived, but the language and description spelling were normalized. There was no failure, so a caller that does not inspect structured metadata will not know. The package's own `FormatCapability` for AAC also reports `structuredReadSupport == propertyMap` and `containers == ["tag", "propertyMap"]`, even though the read path returns ID3v2 frames/comments/lyrics; this is a capability/documentation mismatch.

**Technical evidence:** `preservedCollections` is keyed off `capability.metadataFieldFormats.contains(.id3v2)`. AAC's capability does not contain `.id3v2`, so the Basic write skips the native comment/lyric replay that protects MP3/WAV/AIFF/TTA. The generic PropertyMap preservation restores `COMMENT:NOTES`/`LYRICS:PAROLES` text but not language/description. The AAC structured writer explicitly rejects comments/lyrics, so there is no structured fallback.

**Root cause or suspected root cause:** AAC is implemented through TagLib's MPEG/ID3v2 path, but its registry entry and capability projection classify it as a PropertyMap-only tag. That classification suppresses native collection preservation and understates structured read support.

**Practical impact:** Users can lose language/description semantics on an unrelated edit in a supported format, and tools that display comments/lyrics by language/description may behave differently. The text itself is retained, so severity is below the text-loss cases, but this is still a preservation defect.

**Recommended remediation direction:** Correct the AAC container mask to include ID3v2 (and any supported legacy tag), make `preservedCollections` apply, and add AAC structured comment/lyric write support or fail explicitly. Align the capability descriptor with the actual read/write paths. Document the limitation for any AAC native collection that cannot be replayed.

**Suggested regression tests:** Construct an AAC file with `COMM` `eng/Notes` and `USLT` `fra/Paroles`; perform a title-only Basic edit; assert language/description are unchanged via an independent ID3 parser; also assert a structured comment/lyric write either succeeds or throws a typed unsupported error before commit.

### C.9 AUD-08 — MP4 Basic date fields cannot be edited independently

**Severity:** MEDIUM. **Confidence:** CONFIRMED. **Classification:** CONFIRMED DEFECT. **Category:** Public API contract.

**Affected files and locations:**

- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift:11-28` (`validateDateStorageCompatibility`).
- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift:802-807` (MP4 expected year derived from release date).
- `Sources/CTagLibBridge/Internal/TLWriteBridgeOperations.inc:260-275` and `:405-407` (`setYear` then `©day` mapping overwrites).
- `README.md:118-122` and `docs/SUPPORT.md` MP4 date ownership guidance.

**Affected API:** `replaceBasicMetadata` / `updateBasicMetadata` with MP4 `BasicMetadata.year` or `releaseDate`.

**Affected format:** MP4/M4A family.

**Triggering conditions:** A file has an MP4 `©day` value. The caller edits only `year`, only `releaseDate`, or clears `releaseDate` while retaining `year`.

**Expected behavior:** The public fields should either be independently writable where representable, or be documented as a single date projection with an explicit rejection that identifies the actual field. A year-only edit should not fail with an error naming `.date`.

**Actual behavior:** The following independent sequence on an M4A with `year = "2024"`, `releaseDate = "2024-05-01"`:

```text
replaceBasicMetadata(year = "2025")                         -> throws .unsupportedFieldForFormat(.date, "mp4")
replaceBasicMetadata(releaseDate = "2025-05-01")            -> throws .unsupportedFieldForFormat(.date, "mp4")
replaceBasicMetadata(year = "2024", releaseDate = "")       -> throws .unsupportedFieldForFormat(.date, "mp4")
applyMetadataPatch(.releaseDate: "2025-05-01")              -> success; year becomes 2025
```

The errors are safe (no commit), but the Basic model advertises both fields while the MP4 path accepts neither single-field edit. The error names `.date`, not `.releaseDate` or `.year`, and does not explain the required consistency constraint. The documentation says MP4 `.releaseDate` owns the day atom and `.date` is unsupported, but it does not clearly state that Basic `year` and `releaseDate` must be changed together or that a release-date-only Basic edit is rejected.

**Technical evidence:** `validateDateStorageCompatibility` returns early only when `year` is empty. If `year` is non-empty, it requires a non-empty `releaseDate` whose first four characters equal `year`; any single-field edit violates one side. `writeMetadata` then writes `setYear` and the `©day` mapping in an order that can overwrite the year value if the release date is empty. `MetadataPatch(.releaseDate)` uses the property path and works.

**Root cause or suspected root cause:** The Basic model exposes two derived fields over one native atom without a clear scalar-write contract. Validation is correct about consistency but reports an unrelated field and does not offer a documented single-field operation.

**Practical impact:** Callers cannot use the recommended Basic API to change a release date independently on MP4, and must discover the unadvertised joint constraint or switch to `MetadataPatch`. This is an API ergonomics/contract defect rather than corruption.

**Recommended remediation direction:** Document and enforce a single authoritative MP4 date field (likely `releaseDate`) and make `year` read-only or reject it explicitly with a field-specific error. Alternatively, implement combined semantics where a year-only edit updates the year portion of `©day` and a release-only edit updates the date while keeping `year` consistent. Improve the error to name `.releaseDate` where appropriate.

**Suggested regression tests:** Exercise year-only, release-only, clear-release, clear-year, and both-field edits across M4A; assert either successful semantics or a specific validation error naming the actual field, with byte-identical rollback.

### C.10 AUD-09 — Raw PropertyMap APIs cannot target MP4 freeform keys

**Severity:** MEDIUM. **Confidence:** CONFIRMED. **Classification:** CONFIRMED DEFECT / functional limitation. **Category:** Functional correctness, public API contract.

**Affected files and locations:**

- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift:353-381` (merge normalizes keys to uppercase).
- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift:433-464` (values merge normalization).
- `Sources/TagLibAudioMetadata/RawMetadataPatch.swift:76-84` (raw patch key normalization).
- `Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc:1173-1210` (`BuildRawPropertyMapValues`).
- `Sources/CTagLibBridge/Internal/TLPropertyMapWrites.inc:1-68` (`WriteRawPropertyMapToFile` / values use `file.save()`).
- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Verification.swift` raw replacement canonicalization.

**Affected APIs:** `writeRawMetadataPropertyMapValuesWithVerification` with `.merge` and `.replace`, `writeRawMetadataPropertyMapWithVerification`, `applyRawMetadataPatch`.

**Affected format:** MP4/M4A freeform atoms (`----:com.apple.iTunes:*`).

**Triggering conditions:** The caller supplies an MP4 freeform key, with either the canonical lowercase prefix or an uppercase equivalent, to a raw merge/replace API.

**Expected behavior:** Raw PropertyMap APIs are documented as exact-key/array APIs. A supplied `----:com.apple.iTunes:CUSTOM_FIELD` should update that freeform atom or fail with a clear error; `.merge` should preserve omitted keys.

**Actual behavior:** With a seeded `----:com.apple.iTunes:CUSTOM_FIELD = ["one"]`, a default `.merge` for `["two"]` throws `verificationFailed(["PropertyMap field ----:COM.APPLE.ITUNES:CUSTOM_FIELD differs from the requested delta."])`. With `verifyAfterWrite: false`, it returns success while the file remains unchanged (the key is silently not applied). A `.replace` with only that key throws `verificationFailed(["Raw property-map replacement did not persist the complete requested map (missing keys: CUSTOM_FIELD)."])`; the original file is unchanged. The normalization to uppercase destroys the freeform prefix case that TagLib uses, and the expected-map canonicalizer strips the prefix for comparison while the native item remains, producing a mismatch.

**Technical evidence:** `validatedRawKey`/merge normalization calls `.uppercased()` on all keys. `rawPropertyMapReplacementWarnings` canonicalizes `----:com.apple.iTunes:` to its description but the mutation has already targeted a differently cased key. The bridge's `setProperties` path does not update the existing native freeform item under the uppercase key. The default verification is fail-safe, but the API is unusable for these keys and can silently no-op when verification is disabled.

**Root cause or suspected root cause:** Global uppercase normalization is appropriate for ID3/Xiph-style keys but not for case-sensitive MP4 freeform atom keys. The raw API's verification and mutation normalizers are not format-aware.

**Practical impact:** Advanced editors cannot use raw PropertyMap APIs to manage MP4 freeform metadata even though the package exposes freeform atoms through structured metadata and documents raw APIs for exact arrays. The workaround is `writeStructuredMetadataWithVerification`, which is not obvious from the raw API docs.

**Recommended remediation direction:** Preserve `----:` prefix case and freeform descriptions for MP4; normalize only prefixless keys. Make verification use the actual native item key. Either support freeform raw writes or reject them with a typed unsupported error and direct callers to structured metadata.

**Suggested regression tests:** Seed and update/remove a freeform MP4 key via `.merge`, `.replace`, and `RawMetadataPatch`; assert exact key/case and values, no duplicates; run with and without verification; test both lowercase and uppercase input to ensure no unintended aliases.

### C.11 AUD-10 — ASF erase fails on custom attributes

**Severity:** MEDIUM. **Confidence:** CONFIRMED. **Classification:** CONFIRMED DEFECT / functional limitation. **Category:** Functional correctness.

**Affected files and locations:**

- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift:488-657` (`eraseAllMetadataWithVerification`, `shouldWipeNativeMetadataContainer`).
- `Sources/CTagLibBridge/Internal/TLWriteBridgeOperations.inc:716-776` (ASF `writeMetadata` and generic property path).
- `Sources/CTagLibBridge/Internal/TLMetadataCore.inc:20-32` (no ASF native wipe helper).
- `docs/SUPPORT.md:779-802` (erase contract and residual warnings).

**Affected API:** `eraseAllMetadataWithVerification` and deprecated `eraseAllMetadata`.

**Affected format:** ASF/WMA.

**Triggering conditions:** An ASF file has a custom native attribute (for example `ERASE_CUSTOM` created through Basic custom fields) and the caller erases metadata.

**Expected behavior:** The verified erase clears the modeled fields, raw PropertyMap, and native metadata container for supported families, or returns a typed, documented unsupported result / residual warning that the caller can act on. Since the API's result includes warnings, one might expect a successful result with a residual warning, but it throws a verification failure instead.

**Actual behavior:** After seeding a title, artist, comment, custom field, and artwork through Basic, `eraseAllMetadataWithVerification` threw:

```text
verificationFailed(["Some metadata fields still remain after erase: CUSTOM."])
```

The destination was not committed (safe), but the erase operation cannot complete on a writable ASF family with custom attributes. The `shouldWipeNativeMetadataContainer` list includes MP3/MP4/FLAC/APE/WV/MPC/WAV/TTA/DSDIFF but not ASF; the generic property map clear does not remove ASF attributes that are not represented in the visible PropertyMap. The test matrix in the repository covers erase for MP3/M4A/FLAC/Ogg/OGA/WAV, not ASF.

**Technical evidence:** The residual warning is generated from the post-erase Basic custom fields; the custom attribute remains in the ASF tag. `writeMetadata` with empty Basic preserves unknown PropertyMap entries via `PreservedUnknownPropertyMapEntries`, and the raw empty-map write does not remove native ASF attributes that TagLib's `setProperties` does not expose. No ASF wipe branch exists in the native `wipeMetadata` implementation.

**Root cause or suspected root cause:** Erase has a generic PropertyMap clear plus a native wipe switch that omits ASF; ASF custom attributes require a dedicated native removal path.

**Practical impact:** A destructive clear cannot be performed on a supported writable format with custom ASF attributes. The failure is safe, but it is a functional gap in an advertised operation and a test coverage gap.

**Recommended remediation direction:** Implement ASF native attribute clearing for erase (remove non-picture custom attributes and pictures) or return a typed unsupported/residual result before staging. Update capability/docs to state ASF erase limitations. Add ASF to the erase matrix.

**Suggested regression tests:** Seed ASF with custom string/binary attributes, standard attributes, and pictures; call erase; assert all are removed and audio is unchanged; assert a safe typed failure on unsupported attribute types.

### C.12 AUD-11 through AUD-20 — Additional confirmed observations and limitations

These are lower-severity but still actionable. They are not all merge blockers individually, but they reinforce the need for a unified mapping/verification design.

**AUD-11 (LOW, CONFIRMED, model/data integrity):** A single MP4 freeform atom can appear in `BasicMetadata.customFields` under two keys, for example `MYFIELD` and `MyField`, because the generic PropertyMap reader adds an uppercase key and the freeform loop adds the original-case description. Editing one key through Basic can produce a false verification failure or a duplicate native atom. Affected `TLContainerExtractors.inc:405-426` and `MergeCustomPropertyMapFields` in `TLPropertyMapCodec.inc`. Recommendation: normalize custom field identity per format and avoid duplicate projections; add a case-variant test.

**AUD-12 (LOW, CONFIRMED, documentation):** `BasicMetadata` and SUPPORT state that multi-value display separators are `", "` for ID3/MP4 and `"; "` for generic/Xiph. Independent MP4 test with `©ART` values `["Alpha", "Beta"]` returned `BasicMetadata.artist == "Alpha; Beta"`; ID3 returned `"Alpha, Beta"`. The implementation uses the generic `; ` path for MP4 because `ExtractMP4Metadata` does not override artist. Affected `README.md`, `docs/SUPPORT.md`, `TagLibMetadataModels.swift`, and `TLPropertyMapCodec.inc:610-617`. Recommendation: either make MP4 use `, ` or correct the docs; add MP3/MP4 multi-value tests.

**AUD-13 (LOW, CONFIRMED, functional):** `BasicMetadata.bitDepth` is 0 for lossless formats where TagLib exposes the property: Ogg FLAC (16 expected), APE, WavPack, and ASF. The native extraction sets bit depth only for MP4/FLAC/WAV/AIFF/TTA. Affected `TLUnifiedExtraction.inc` format-specific branches. Recommendation: project `bitsPerSample` where available and add tests; not a metadata-integrity blocker.

**AUD-14 (LOW, CONFIRMED, verification gap):** Basic artwork verification uses `.present`/`.absent`, which only checks that `artworkData` is non-nil/nil (`TagLibMetadataManager+Verification.swift:288-299`). It does not compare bytes or MIME. A writer that wrote corrupt or wrong artwork of nonzero length would pass the Basic verifier. Structured/Patch artwork verification is stronger. Recommendation: add exact byte/MIME expectations or route Basic artwork verification through structured matching; add a test with deliberately swapped same-length bytes.

**AUD-15 (LOW, CONFIRMED, functional limitation):** `writeTrackNumberText` on FLAC/Ogg returns success but `Basic.trackNumberText` reads `"03"` rather than the requested `"03/10"` because those formats store separate `TRACKNUMBER`/`TRACKTOTAL`; the package's display projector does not synthesize the slash. On MP3, `"01/02"` can return as `"01/2"` because only the first component is padded. The semantic pair is preserved, so this is a formatting/display contract issue, not data loss. Affected `TLPropertyMapWrites.inc:70-189`, `TLBasicBridgeOperations.inc:35-45`, and `TagLibMetadataManager+Read.swift` fallback. Recommendation: document the generic-format behavior or synthesize display text; add exact-text tests.

**AUD-16 (LOW, CONFIRMED, functional limitation):** `StructuredMetadata` has no remove operation for `asfAttributes` and no removal path for ID3 `url`/`ufid` frames when the value/data is empty; the writers skip empty entries rather than removing. Affected `TLStructuredMutation.inc`. Recommendation: define replace/remove semantics or document the limitation; add tests.

**AUD-17 (LOW, CONFIRMED, design risk):** `writeRawMetadataPropertyMapValuesWithVerification(.replace)` on MP3 can overwrite an existing ID3v1 tag with values from ID3v2. A test showed an ID3v1 `Legacy Title/Artist/Album/Year/Comment` becoming the replacement title with empty other fields. The docs explicitly say `.replace` owns the visible PropertyMap and can remove opaque native fields, so this may be an intentional consequence, but the ID3v1 loss is not called out in the same way as WAV INFO. Recommendation: document ID3v1/APE consequences or provide a preservation mode; add a test.

**AUD-18 (LOW, UNVERIFIED RISK, transaction safety):** `COPYFILE_CLONE` guarantees data/stat/xattr but the man page states setuid/setgid bits are not copied when cloning succeeds. The package's docs claim tests validate "flags, permissions"; the existing test does not cover setuid/setgid. This is a source-level risk, not a reproduced failure. Recommendation: explicitly clear or preserve expected privilege bits and test; document the clone caveat.

**AUD-19 (LOW, UNVERIFIED RISK, format coverage):** The audit verified a generated AIFF Basic/Patch smoke flow and a generated MP2 flow, and exercised the repository fixtures for the other families. AIFF still has no repository round-trip fixture, and Speex, S3M, IT, Shorten, and MOD were not executed at all. These remain source-level support claims. Recommendation: add fixtures or downgrade the advertised evidence level.

**AUD-20 (INFORMATIONAL, public API design):** `MetadataWriteResult.warnings` is effectively empty for most successful verified writes because verification mismatches are thrown and all warning-bearing checks throw. The only common successful warnings are structured container advisories (for example WAV). This is not a defect, but callers should not treat warning emptiness as a broad verification statement; the behavior should be documented precisely. See `TagLibMetadataManager+Verification.swift` and `throwOnVerificationFailures`.

## D. Public API Assessment

### D.1 Omission, clearing, empty values, and replacement

The public model generally distinguishes these concepts well in its documentation and validation:

- `MetadataPatch.fields` omission means unchanged; `.remove` means explicit removal; `.text("")` and `.values([])` are rejected instead of being ambiguous deletion aliases.
- `MetadataPatch.artwork` has `.unchanged`, `.replace([...])`, and `.removeAll`.
- `MetadataPatch.numberText` is separate from typed number fields and rejects conflicting use.
- `MetadataPatch.explicitAdvisory` distinguishes `.unspecified`, `.notExplicit`, `.clean`, and `.explicit`.
- `RawMetadataPatch` distinguishes values to set from keys to remove and rejects empty arrays.
- `StructuredMetadata` uses non-empty collections as replace-all and empty collections as omitted unless `replacingCollections` names them.
- `BasicMetadata` uses empty strings/zero numbers for replacement/clearing; removing a `customFields` entry does not delete it unless the value is explicitly empty or a patch/raw removal is used.

These are good API decisions, and the source-compatibility tests confirm the legacy overloads remain compilable. The failures are in the implementation of specific field families, not in the high-level distinction model.

### D.2 Read/write symmetry

Read/write symmetry is inconsistent for the fields in AUD-01, AUD-02, AUD-04, and AUD-07. Examples:

- `work`, `acoustID`, `acoustIDFingerprint`: Basic writer and reader agree on a freeform representation; typed Patch writes a different key and the reader can still return the old value.
- `.comment`/`.lyrics`: a structured read exposes language/description and multiple entries; typed Patch is scalar and cannot remove or replace qualified entries.
- AAC: read exposes structured ID3 comments/lyrics; capability says PropertyMap-only; Basic write degrades language/description; structured write rejects comments/lyrics.
- TTA/AIFF/DSF/DSDIFF: read accepts combined `TRCK`/`TPOS`; writers emit split `TRCK` + TXXX totals.
- MP4 `.originalReleaseDate`: schema and Basic writer use `ORIGINAL YEAR`; typed Patch writes `ORIGINALDATE`.
- MP4 `musicIPPUID`: Basic writer writes `MusicIP PUID`; reader only recognizes `MUSICIP_PUID` for MP4; Basic write fails verification.

### D.3 Version tokens and optimistic concurrency

`MetadataFileVersion` is a well-designed local identity token. It includes device/inode/size/link count/mtime/ctime; `readSnapshot` and `readBasicSnapshot` return it; expected-version checks occur inside the transaction after the same-entry lock and before staging. The tests cover stale-version rejection, concurrent change, alias paths, and successful normal reads. The documented limitation that it is not a content digest or cross-process lock is accurate. This area is a strength.

### D.4 Error contracts

The error model is generally clear and structured:

- `TagLibManagerError` covers unsupported format, file changed, hard-linked file, verification failure, native operation failure with underlying NSError, and committed-but-durability-uncertain.
- Patch validation errors are specific and localized.
- Raw patch errors distinguish invalid key, empty array, conflicting key, and embedded NUL.
- Structured validation rejects embedded NULs, unsupported ID3 frame types, invalid numeric widths, and unsupported payload types.
- Transaction rollback preserves the original bytes and surfaces native causes where available.

The main error-contract defects are false success in AUD-01/AUD-02/AUD-04/AUD-07, the misleading MP4 `.date` error in AUD-08, and the ASF erase residual error in AUD-10. The mixed-tag failure in AUD-06 is a correct error (no commit) but an unusable operation.

### D.5 Source compatibility and overloads

The package preserves a large legacy surface: deprecated `writeMetadata`, `writeRawMetadataPropertyMap`, `writeTagMetadata` variants, `failurePolicy` overloads, `FormatSupportLevel.verified`, `ArtworkVerificationExpectation.unchanged`, and `TagLibManagerError.failedToRead`. `ReviewSourceCompatibilityTests` and `PublicAPICompatibilityTests` compile representative function references and nested types. The build emits deprecation warnings but no errors. This is a strength, although the deprecated `Bool` writers discard `MetadataWriteResult` commit status and warnings (documented for raw convenience, less explicit for `writeMetadata`).

### D.6 Unsupported operations

Most unsupported operations fail safely before commit: role-qualified Patch fields, MP4 `.date`, raw hidden keys, invalid structured payloads, embedded NULs, unsupported frame types, invalid number widths, and unsupported artwork counts. The audit did not find a case where an unsupported operation silently corrupted audio. The defects are operations that are **advertised as supported** but do not honor their semantic contract.

## E. Metadata Integrity Assessment

### E.1 Summary matrix

| Area | Requested persistence | Untouched preservation | Explicit removal | Verification | Audit result |
| --- | --- | --- | --- | --- | --- |
| Basic standard fields (MP3/MP4/FLAC/Ogg/WAV/AAC/TTA/AIFF) | Usually correct for title/artist/album/genre/comment | Good via Basic preservation and raw replay | Empty strings/zero values generally clear | Basic readback | Partial: AAC comments/lyrics language loss; MP4 date coupling |
| Basic custom fields | Good for ordinary keys; empty value deletes | Good for unchanged; known names handled | Nil does not delete by design; empty does | Basic/raw | Partial: MP4 case duplicates and `musicIPPUID` failure |
| Typed Patch standard text | Mostly correct | Raw unedited fields compared | Broken for qualified comments/lyrics | Raw key | Partial: AUD-02, AUD-04 |
| Typed Patch numbers | Correct on MP3/WAV/MP4 | Raw/afterBasic | Partial-pair policy inconsistent on TTA/AIFF/DSF/DSDIFF | Basic/raw | Partial: AUD-04 |
| Raw property maps | Exact for case-normalized keys | Good for omitted on merge | Exact remove works for normal keys | Complete visible map | Partial: MP4 freeform keys cannot be targeted (AUD-09) |
| Structured properties/frames/atoms/attributes/artwork | Good for supported payloads | Tests show omitted artwork and atoms preserved in many formats | Collections can be replaced/cleared; some atom/frame types lack removal | Structured readback | Mostly strong; ASF attribute deletion and ID3 URL/UFID gaps |
| Artwork | Data/MIME/role supported | Front/back and MIME correction tests | Patch `.removeAll` and low-level remove work | Structured exact; Basic only presence | Partial: Basic verifier weak (AUD-14) |
| Recording/release dates | MP4 release works via Patch; ID3/FLAC dates | Date arrays/aliases preserved in Basic tests | Typed Patch removes | Raw/Basic | Partial: MP4 Basic year/release coupling (AUD-08) |
| Track/disc pairs and totals | Correct MP3/WAV/MP4 | Good in tests | Generic formats preserve totals by policy | Basic/raw | Partial: AUD-04 |
| Explicit advisory | Four-state model correct; MP4 `rtng` canonicalization | Tests pass across formats | `.unspecified` clears canonical | Basic | Strong |
| Native comments/lyrics | Basic replacement works for MP3/WAV/AIFF/TTA | MP3 native language test passes | Structured replace works; typed Patch broken | Structured | Partial: AUD-02/AUD-07 |
| Native ID3 unknowns/opaque | Opaque frames preserved unless rejected | Structured properties preserve; opaque mutations reject | N/A | Frame summaries | Strong for the tested contract |
| Audio payload | Existing independent tests cover representative formats | N/A | N/A | Byte/payload oracles | Strong in tested matrix; no corruption observed |

### E.2 Requested-field persistence

The package reliably persists requested fields in the common cases the tests cover: MP3/MP4/FLAC/Ogg/WAV Basic title/artist/album/genre/comment, MP4 native pairs and advisory, MP3/WAV combined numbers, structured ID3 frames/comments/lyrics/artwork, structured MP4 atoms, structured ASF attributes/pictures, APE/WavPack/MPC tags/artwork, and DSD PropertyMap/artwork. The independent `ffprobe` and byte-level checks in this audit confirmed successful title/artist/album changes for MP3, MP4, FLAC, Ogg, WAV, AAC, WMA, WavPack, APE, Musepack, TTA, DSF, DSDIFF, AIFF, MP2, and XM where exercised.

The requested-field failures are concentrated in the implementations cited above, not in the transaction layer. In every false-success case observed, the file was left readable and the transaction was committed; the defect is that the requested semantic change or the expected native representation was not what verification claimed.

### E.3 Untouched-field preservation

The strongest preservation evidence is in the repository tests and independent checks:

- WAV RIFF INFO chunk bytes remain identical through track/text/Basic edits in `WAVInfoProjectionTests`, using an independent chunk parser.
- MP4 hidden/private atoms and encoded audio survive structured property edits in `ReviewNativeContainerTests`.
- APE/WavPack/Musepack native tags and audio survive tagged edits in `HardeningFormatTests`.
- DSD audio and native COMM/USLT/APIC/opaque payloads survive raw deltas; Basic edits that would require lossy replay are rejected.
- ASF sibling attributes and pictures survive targeted edits.
- Artwork bytes survive property-only structured edits for MP3/FLAC/MP4 in this audit.
- ID3/Basic native comment/lyric language preservation is tested for MP3.

The counterexamples are equally important:

- MP4 number aliases are deleted by unrelated Basic edits (AUD-05).
- ID3v1 fields are shadowed by sparse ID3v2 in track-only writes (AUD-03).
- AAC comment/lyric language/description is degraded by unrelated Basic edits (AUD-07).
- MP4 freeform old values survive Patch updates and become the semantic value (AUD-01).
- ASF erase leaves custom attributes and fails (AUD-10).

### E.4 Explicit removal

`MetadataPatchValue.remove` works correctly for ordinary scalar keys (for example MP4/FLAC title, raw property keys, structured properties with empty arrays), but it is not reliable for qualified ID3 comments/lyrics. The `.comment`/`.lyrics` removal tests in this audit are decisive: the API returns success while the data remains. This is the most serious explicit-removal defect because it can be used for privacy-sensitive cleanup.

`StructuredMetadata` collection removal (empty collection plus `replacingCollections`) works for supported comments/lyrics/artwork and is the correct workaround. The existence of a workaround does not repair the scalar API contract.

### E.5 Artwork

Artwork handling is generally strong: Basic and structured writers preserve existing front/back roles, MIME correction preserves picture descriptions, structured replace/remove works across ID3/MP4/APE/ASF/FLAC/Xiph, and independent byte checks exist for several formats. Basic `replaceBasicMetadata` does not remove artwork when `artworkData` is nil; that is a documented low-level-only removal path, not necessarily a defect, but the Basic model's nil semantics should be explicit. Basic verification's `.present` check is weak (AUD-14).

### E.6 Dates

ID3/FLAC/Ogg recording and release dates, date arrays, and year aliases are handled by the Basic preservation logic and have dedicated tests. MP4 has one `©day` atom; `MetadataPatch(.releaseDate)` works, `.date` is correctly rejected, but Basic year/release fields cannot be edited independently and produce misleading preflight errors (AUD-08). MP4 `originalReleaseDate` native mapping is inconsistent between Basic and Patch (AUD-01).

### E.7 Aliases and custom metadata

Basic preservation of documented aliases (`PUBLISHER`, `CATALOG`, `ORIGINAL YEAR`, MusicBrainz space forms) and qualified people keys works in the tested ID3/FLAC/Ogg cases. Custom field empty-value deletion and unchanged known-name preservation work. The remaining alias problems are MP4 freeform mapping, duplicate custom-field case projections, and overbroad number-alias deletion. These are not merely presentation issues; they affect native persistence.

### E.8 Number pairs

MP3, WAV, and MP4 number pairs are handled with dedicated native writers and tested. AAC Basic/number-text and TTA/AIFF/DSF/DSDIFF are not, producing split totals and false exact-text success (AUD-04). Total-only and partial-pair validation is inconsistent across ID3-backed families. The generic FLAC/Ogg separate-key representation is intentional and documented, but its display projection loses the slash (AUD-15).

### E.9 Write verification and audio payload

The transaction/verification architecture is strong in its general design and in the cases it actually checks. Audio payload integrity was tested independently for representative MP3/MP4/FLAC/Ogg/WAV/AAC/APE/DSD operations and no payload corruption was observed. The central verification weakness is semantic: it verifies selected raw keys or Basic projections, not all native aliases or the semantic field in every path. AUD-01/AUD-02/AUD-04/AUD-07 are verification failures as much as writer failures.

## F. Format Capability Assessment

### F.1 Registry facts

`formatCapabilities` returns 22 families and 37 unique extensions; `readableExtensions` has 37 and `writableExtensions` has 32. The README's counts are correct. Supported writable families per the registry are MP3/MP2, AAC, MP4/M4A, FLAC, Ogg Vorbis, Ogg Opus, Ogg FLAC (`.oga`), Speex (`.spx`), APE, WavPack, Musepack, WAV, AIFF, TrueAudio, ASF/WMA, DSF, DSDIFF, S3M, IT, and XM; Shorten and MOD are read-only.

### F.2 Runtime/source assessment

| Family | Extensions | Evidence in this audit | Integrity assessment |
| --- | --- | --- | --- |
| MPEG/ID3 | `mp3`, `mp2` | Fixtures + generated MP2; Basic/Patch reads/writes; ID3v1 experiments | Strong general behavior; AUD-03/AUD-06/AUD-02 |
| AAC | `aac` | Fixture; Basic/Patch/number-text; Python-built ID3v2 comments/lyrics | Basic numbers split; native comment language/description loss; capability omits ID3v2 (AUD-04/AUD-07) |
| MP4/M4A | `m4a`, `m4r`, `m4b`, `m4p`, `mp4`, `m4v`, `3g2` | Fixtures, independent atom/audio tests, freeform experiments | Strong native pairs/advisory/artwork; AUD-01/AUD-05/AUD-08 |
| FLAC | `flac` | Fixture, multi-value, artwork, numbers, dates, independent payload | Strong; AUD-15 display only |
| Ogg Vorbis | `ogg` | Fixture, multi-value, artwork, numbers, independent payload | Strong; AUD-15 display only |
| Ogg Opus | `opus` | Synthetic fixture, title/custom preservation | Strong for tested path |
| Ogg FLAC | `oga` | Empty FLAC fixture; property/artwork/read | Works; bit depth 0 (AUD-13); codec capability is extension-based |
| Ogg Speex | `spx` | Source/registry only | Unverified upstream support |
| APE | `ape` | Hardening fixture, independent APE parser, native preservation | Strong; one-front-cover policy documented |
| WavPack | `wv` | Fixture, independent APE parser, artwork/preservation | Strong; bit depth 0 |
| Musepack | `mpc` | Hardening fixture, independent parser | Strong; bit depth 0 |
| WAV/RIFF | `wav` | Independent RIFF INFO tests, structured policy, artwork | Strong; combined ID3 numbers special path |
| AIFF | `aiff`, `aif`, `aifc`, `afc` | Generated AIFF; Basic/Patch tests | Works for tested fields; AUD-04 split numbers; no fixture |
| TrueAudio | `tta` | Fixture; Basic/artwork; number/movement experiments | Works; AUD-04 split numbers; movement pair fails verification |
| ASF/WMA | `wma`, `asf` | Fixture; independent attribute/picture tests; erase matrix | Strong targeted edits; AUD-10 erase |
| DSF | `dsf` | Hardening fixture; independent DSD parser; Basic/artwork/raw deltas | Strong; AUD-04 split numbers; comments/lyrics safely rejected |
| DSDIFF | `dff`, `dsdiff` | Hardening fixture; independent DSD parser | Strong; AUD-04 split numbers; native collection write limits |
| Shorten | `shn` | Source/registry only | Read-only claim; unverified runtime |
| MOD | `mod`, `module`, `nst`, `wow` | Source/registry only | Read-only claim; unverified runtime |
| S3M | `s3m` | Source/registry only | Experimental; title/comment write claim untested |
| IT | `it` | Source/registry only | Experimental; untested |
| XM | `xm` | Fixture; raw map round trip; Basic unsupported-field failure | Strong for supported fields; Basic full-model writes fail on unsupported artist/custom |

### F.3 Verified versus source-only

**Runtime verified in this audit:** MP3, MP4/M4A (AAC and ALAC), FLAC, Ogg Vorbis, Ogg Opus, Ogg FLAC, WAV, AAC, ASF/WMA, WavPack, APE, Musepack, TTA, DSF, DSDIFF, XM, AIFF (generated), MP2 (generated). This means read/write for representative fields, not every API/field combination.

**Source-only or fixture-limited:** Speex, S3M, IT, Shorten, MOD, less-common extension aliases (`m4b`, `m4r`, `m4p`, `m4v`, `3g2`, `aifc`, `afc`, `module`, `nst`, `wow`), and some codec variants within Ogg/MP4/AAC. Their advertised support should be treated as upstream/source-level until exercised.

### F.4 Format detection and capability

Extension-based dispatch is used for all non-Ogg families; Ogg uses a bounded codec sniffer. The sniffer logic is reasonable and tested for Vorbis/Opus/FLAC/Speex aliases. Capability reporting is extension-level, not content-level: a `.ogg` Opus file or a `.oga` Vorbis file reports the registered family for the extension, not the detected codec. This is documented as a declared family capability rather than a runtime verdict, but callers should not infer codec identity from `capability(forExtension:)` alone; a content probe is needed.

### F.5 Format/API consistency

The most important cross-format inconsistencies are the number-pair writers (AUD-04), AAC native IDF3 classification (AUD-07), MP4 freeform mapping (AUD-01/AUD-09), and ID3 comment/lyric scalar handling (AUD-02). These are not theoretical variations; they are same-semantic-field operations that produce different native representations depending on the chosen public API.

## G. Transaction and Native Safety

### G.1 Studied transaction properties

**Atomicity:** The destination is not modified before verification. The operation runs on a sibling staging file; rename replaces the directory entry atomically. A failure before rename leaves the original untouched; a failure after rename is reported as committed with durability uncertainty. The tests cover pre-commit failure, corrupt input, write failure, directory-sync failure, and temp cleanup.

**Identity and versioning:** `FileIdentity` captures device, inode, size, link count, mtime, and ctime. `MetadataFileVersion` exposes the same. The transaction validates original identity before staging and again immediately before rename. Reads compare identity around extraction. Hard links and symlinks are rejected. The final check includes link count, so a new hard link during the transaction is detected.

**Concurrency:** A process-wide recursive mutex serializes TagLib object use; a per-directory-entry lock serializes same-file mutations across facade and public bridge paths. The lock key uses parent directory identity plus entry name, supports symlink aliases, and is resilient to inode replacement. Read paths do not hold the mutation lock for their full duration; they use identity checks. Tests exercise independent-file concurrency, same-file coordination, and concurrent M4A reads. No deadlock or data race was observed in TSAN.

**Filesystem metadata:** `copyfile` is called with `COPYFILE_CLONE | COPYFILE_ACL`. The system man page documents `COPYFILE_CLONE` as also implying `COPYFILE_STAT`, `COPYFILE_XATTR`, `COPYFILE_DATA`, and `COPYFILE_NOFOLLOW_SRC`; the audit confirmed those semantics. Tests verify ACLs, extended attributes, flags, and permissions on the supported APFS path. The setuid/setgid clone caveat is an unverified risk (AUD-18), not a reproduced failure.

**Durability:** `F_FULLFSYNC` is used on the staged file with `fsync` fallback; the parent directory is synced after rename. A failure after rename returns `.committedButDurabilityUncertain` / a typed native error, not a generic failure. The documentation correctly distinguishes OS-level synchronization from hardware power-loss guarantees.

**Cleanup:** Temporary files are removed on pre-rename failure; tests verify no residue after success/failure. Random UUID sibling names and `COPYFILE_CLONE`'s implied exclusive create reduce temp-path collision risk.

**Cross-process coordination:** No cross-process lock is claimed. The documentation states that uncooperative external writers can race the final identity-check/rename interval. This is an appropriate limitation, not a new defect.

### G.2 Native bridge safety

The bridge uses a recursive mutex around TagLib parser/tag/property-map/file objects. Foundation objects are populated while holding the lock. C++ exceptions are contained at public entry points through `TAGLIB_BRIDGE_CATCH_WITH_ERROR` or `TAGLIB_BRIDGE_CATCH_SAFE`; errors carry a description and code. Public entry points validate embedded NULs, numeric ranges, artwork size, and structured payload types. Raw and structured writers reject unsupported types where they cannot reconstruct or verify payloads. `TagLibAtomicMutationDepth` is thread-local and in-place primitives set it correctly; public transactional writers check depth and recurse into the staging file safely.

Potential residual risks, not confirmed defects:

- Precompiled TagLib is not sanitizer-instrumented; a memory-safety issue inside TagLib would not be detected by ASAN/TSAN on the binary.
- Malformed/oversized native metadata can consume resources inside TagLib; the package has no hard limits beyond type/size validations.
- `writeTagMetadata` and raw low-level entry points do not inherit facade semantic verification; this is documented for the low-level product but remains a footgun.
- The final identity-check/rename window is inherently racy against external processes; documented.

### G.3 Native and filesystem failure behavior

The audit's failure experiments showed correct byte-preserving rollback for mixed-tag verification failure, unsupported operations, embedded NULs, invalid numeric widths, opaque frames, corrupt input, expected-version mismatch, and hard links. The only transaction-adjacent issue found is the functional mixed-tag failure (AUD-06), which does not corrupt data. No broken rollback, audio-payload corruption, or false commit-status result was found.

### G.4 Performance and maintainability observations

No correctness-preserving performance regression was demonstrated, and the opt-in throughput benchmark was skipped. The architecture does perform several full metadata parses per mutation: Basic replacement reads a Basic+PropertyMap snapshot, may read structured collections, writes, replays preservation values, and verifies; typed Patch reads a full snapshot, may write numbers/advisory/properties/artwork in several passes, and verifies with `.all`. Each pass is a separate TagLib open/save of the staging file. This is a deliberate correctness trade-off and is documented, not a defect by itself, but it makes the write path sensitive to semantic duplication and increases recovery surface. The process-wide recursive mutex also serializes parsing across independent files while the lock is held; the tests show correctness, not throughput.

The most important maintainability risk is demonstrated by the findings themselves: field-to-native mapping exists independently in the Swift schema, `kWritableTextMappings`, the reader's known-field table, and per-format writer branches. AUD-01, AUD-04, AUD-07, and AUD-12 are all divergence between those copies. A table-driven semantic writer would reduce both the defect rate and the test matrix. This is a design improvement with demonstrated benefit, not a speculative refactor request.

### G.5 Security and robustness observations

The package validates embedded NULs, numeric widths, artwork sizes, structured payload types, and opaque-frame mutation support before commit, and it contains C++ exceptions at bridge boundaries. The independent malformed-input and ASAN/TSAN runs did not produce a memory-safety finding in package code. Residual security concerns are bounded: the precompiled TagLib parser is not instrumented, malformed/oversized native metadata can consume resources inside TagLib, and the package does not impose a global metadata-size limit. The final identity-check/rename window is intentionally not a cross-process lock. No exploitability claim is made without a reproduced failure; the realistic risks are denial of service through a third-party parser and races with uncooperative external writers, both documented limitations rather than confirmed package vulnerabilities.

## H. Test Suite Assessment

### H.1 Execution results

The complete test suite was run in an external scratch directory to avoid repository build artifacts. Final results:

| Command | Result |
| --- | --- |
| `swift test --disable-sandbox --scratch-path /tmp/taglib-audit-build` | 153 XCTest tests (2 skipped, 0 failures) + 33 Swift Testing tests in 7 suites (all pass) |
| `swift test --disable-sandbox --scratch-path /tmp/taglib-audit-asan --sanitize=address` | Same counts, no AddressSanitizer error |
| `swift test --disable-sandbox --scratch-path /tmp/taglib-audit-tsan --sanitize=thread` | Same counts, no ThreadSanitizer warning |
| Xcode `BuildProject` | Build succeeded |
| Xcode `RunAllTests` | 186 tests: 184 passed, 0 failed, 2 skipped, 0 expected failures, 0 not run |

The initial `swift test` attempt without `--disable-sandbox` failed in this environment because SwiftPM's manifest sandbox attempted `sandbox-exec`, which the host sandbox denied. The retry with `--disable-sandbox` is the reported test run. No repository files were modified by the test runs; `.build` artifacts are ignored.

### H.2 Strong tests and reliable evidence

The following are genuine strengths:

- `WAVInfoProjectionTests` parses RIFF chunks independently and verifies byte-identical INFO metadata through track/title/Basic edits.
- `ReviewNativeContainerTests` has an independent MP4 atom walker, ASF header parser, and APE item parser; it checks hidden atom preservation, sibling ASF attributes, native audio payloads, and artwork roles.
- `HardeningFormatTests` parses APE/DSD containers independently, verifies encoded audio equality, and checks native COMM/USLT/APIC/opaque frame preservation.
- `HardeningAudioPayloadTests` reconstructs encoded audio and codec headers independent of whole-file equality.
- `ReliabilityFailureTests` covers directory-sync uncertainty, corrupt input, hard links, symlinks, numeric overflow, malformed structured payloads, and rollback.
- `SameFileTransactionTests` covers same-entry coordination, expected versions, aliases, and concurrent writes.
- `ConcurrentFormatOperationTests` and `ConcurrentM4AReadTests` exercise repeated concurrent reads/writes with stability assertions.
- `Capability/FormatCapabilityTests` cross-checks Swift schema mappings against the bridge mapping tables and capability descriptors.
- `ReviewSourceCompatibilityTests` and `PublicAPICompatibilityTests` lock down legacy function references and nested types.
- `testBasicTitleEditPreservesNativeCommentAndLyricLanguages` independently parses MP3 COMM/USLT payloads and tests intentional replacement/clearing controls.
- `testArtworkMIME...`, `testUnrelatedBasicEditDoesNotDuplicateBackOnlyArtwork`, and the structured artwork tests cover important preservation cases.

### H.3 False negatives, vacuous assertions, and blind spots

The suite is not sufficient to establish the current contracts. Specific concerns:

1. **Same-library oracle in many metadata tests.** Tests such as `testExtendedBasicFieldsRoundTripAcrossID3AndMP4`, `testBasicMetadataWritesAndClearsAcrossFixtures`, `testStructuredMetadataWritesPropertiesAndContainerDataTogether`, and many `XCTAssertEqual(try readMetadataResult(...).field, expected)` assertions use the package reader as both writer oracle and expected reader. This cannot detect a writer/reader mapping divergence like AUD-01 or AUD-04 unless the reader happens to expose the difference.
2. **No ID3v1-only or sparse-ID3v2/rich-ID3v1 fixture.** `testBasicMetadataWritesAndClearsAcrossFixtures` starts from standard fixtures with no legacy tags; it does not test track-only writes on ID3v1-only files (AUD-03) or mixed-tag track/advisory patches (AUD-06). The historical audit's "ID3v1/tagless reads/writes work in spot checks" is not coverage of these operations.
3. **No qualified comment/lyric removal test.** The existing native-comment test covers an unrelated Basic edit, not `applyMetadataPatch(.comment/.lyrics: .remove)` on `COMMENT:<desc>`/`LYRICS:<desc>` (AUD-02).
4. **No AAC native ID3 comment/lyric test.** `testBasicTitleEditPreservesNativeCommentAndLyricLanguages` is MP3-only; AAC is not in the native-collection matrix (AUD-07).
5. **No TTA/AIFF/DSF/DSDIFF track/disc test.** Number-pair tests cover MP3, MP4, WAV, FLAC/Ogg, and ASF; these ID3-backed families are absent (AUD-04).
6. **No MP4 Basic-to-Patch cross-API test.** `mp4DeltasPreserveNativeAtomsAndAudioPayload` tests structured deltas, not `replaceBasicMetadata` followed by `applyMetadataPatch(.work/.acoustID/...)` (AUD-01).
7. **No MP4 number-alias preservation test.** Existing tests seed `trkn`/`disk` and private internal formatting atoms, not the user-facing freeform number aliases removed by Basic/low-level writes (AUD-05).
8. **No ASF erase test.** The erase matrix omits WMA/ASF (AUD-10).
9. **No `musicIPPUID` MP4 test.** The extended Basic round-trip test omits this field; Basic write fails on M4A (AUD-01).
10. **Basic artwork verification is not exercised as a verifier.** Tests assert package artwork bytes, but no test deliberately corrupts/changes artwork bytes while keeping them non-nil to confirm `.present` would catch it (AUD-14).
11. **`testBasicMetadataWritesAndClearsAcrossFixtures` starts from `BasicMetadata.empty`**, so it tests clearing/writing from scratch but not preservation of pre-existing rich metadata; other tests cover selected preservation, but not the failing families above.
12. **`testEraseAllMetadataReportsNoResidualCoreFields` covers only MP3/M4A/FLAC/Ogg/OGA/WAV**, and verifies with the package reader. It does not cover ASF, APE, WavPack, Musepack, TTA, DSF, DSDIFF, AIFF, XM, AAC, or MP2.
13. **`testXMSupportedFieldsRoundTripWithoutCorruptingModule` uses `verifyAfterWrite: false`** and relies on raw readback; it is a legitimate normalization case but demonstrates that the default verifier is bypassed for a supported writer.
14. **The external corpus test is skipped by default.** `ExternalCorpusPreservationTests` is the strongest independent external evidence and did not run in the default suite (`skipped`). The audit's own external experiments partly fill that gap but not the whole corpus.
15. **The performance benchmark is skipped by default.** No performance claim is substantiated by an executed benchmark in this audit.
16. **Source-only formats have no runtime tests.** AIFF (until this audit's generated test), Speex, S3M, IT, Shorten, MOD, and several extension aliases are registry claims without current regression fixtures.
17. **Tests accept some broad outcomes.** For example, `HardeningFormatTests` uses `#expect(throws: (any Error).self)` for Basic edits that must fail safely; that is appropriate for a safety contract but does not distinguish a specific error or prove which metadata would have been lost. The important part is that the original bytes are unchanged, which those tests check.
18. **The suite does not verify semantic truth for MP4 freeform fields.** Independent atom tests check keys/values but not the cross-API semantic field behavior that fails in AUD-01.
19. **No test checks that a successful verified write leaves no old duplicate native representation.** This is the core invariant missing for AUD-01/AUD-02/AUD-04.

### H.4 Specific false-negative mechanism

For AUD-01, a test written as:

```swift
try TagLibMetadataManager.applyMetadataPatch(
    MetadataPatch(fields: [.acoustID: .text("NEW")]), to: url)
XCTAssertEqual(try TagLibMetadataManager.rawMetadataResult(from: url)
    .first { $0.key == "ACOUSTID_ID" }?.value, "NEW")
```

would pass while `BasicMetadata.acoustID` remains old. A correct test must assert the semantic field and the absence/replacement of every alias, preferably with an independent atom parser. Many existing tests are shaped like the former.

For AUD-02, a test that seeds an unqualified `COMMENT` and removes it passes; the failure requires a qualified description/language. The existing tests do not construct that native shape through the typed Patch path.

For AUD-03, a test that starts from the repository's standard tagged fixture has an ID3v2 tag and therefore does not exercise the sparse-tag creation. The fixture matrix needs a true ID3v1-only case.

For AUD-04, tests that assert `Basic.track`/`trackTotal` pass because the reader understands both combined and split forms. They do not inspect `TRCK`/`TPOS` framing.

### H.5 Test recommendations

Concrete additions:

- Independent ID3 frame parser tests for combined `TRCK`/`TPOS`/`MVIN` on every ID3-backed family and every writer API.
- MP4 atom tests for freeform field cross-API updates and old-alias removal, covering `work`, `acoustID`, `acoustIDFingerprint`, `originalReleaseDate`, `artistType`, `musicIPPUID`.
- True ID3v1-only and sparse-ID3v2/rich-ID3v1 MP3/MP2 fixtures for track text, track patch, advisory patch, Basic write, and erase.
- Qualified COMM/USLT single/multiple removal and replacement tests on MP3, AAC, WAV, AIFF, TTA, DSF, DSDIFF.
- AAC native comment/lyric language/description preservation test using an independently built ID3v2 tag.
- MP4 number-alias preservation tests for title-only Basic and track-only low-level writes.
- ASF custom-attribute erase test, plus a clear result contract for residual warnings.
- Basic artwork exact-bytes/MIME verifier test.
- Raw MP4 freeform merge/replace tests with and without verification.
- MP4 Basic date single-field tests with field-specific error expectations.
- External corpus test executed in at least one gating or pre-merge job.
- A "no stale alias" invariant helper reused by all Patch/Structured tests.

## I. Documentation Assessment

### I.1 Material inaccuracies

| Claim/location | Observed behavior | Assessment |
| --- | --- | --- |
| `docs/SUPPORT.md:805-810`: "A requested value that is missing, different, unsupported ... is a verification failure: it throws and the staged file is not committed." | `applyMetadataPatch(.acoustID/.work)` returns success while `BasicMetadata` remains old; `.comment/.lyrics: .remove` returns success while native frames remain | **Materially false for supported operations.** AUD-01/AUD-02 |
| `README.md` Basic/SUPPORT: MP4 multi-value display separator is `", "` | MP4 `artist` with `["Alpha","Beta"]` returns `"Alpha; Beta"` | **False.** AUD-12 |
| `README.md:169-171`, `docs/ARCHITECTURE.md:110-111`, `docs/SUPPORT.md:137-138`: ID3 retains combined `TRCK`/`TPOS`, movement uses `MVIN`, pair mutations preserve omitted components | AAC Basic/number-text and TTA/AIFF/DSF/DSDIFF Basic/Patch write split `TRCK`+`TXXX` totals; TTA/DSF movement pair fails verification | **Materially incomplete/false for advertised ID3 families.** AUD-04 |
| `CHANGELOG`/`SUPPORT`: native ID3 comment/lyric languages/descriptions preserved on unrelated edits | MP3/WAV/AIFF/TTA path is strong; AAC degrades `eng/Notes` to `XXX/NOTES` | **Broad claim overstates AAC.** AUD-07 |
| `FormatCapability` AAC `containers`/`metadataFieldFormats` says PropertyMap-only; `structuredReadSupport=propertyMap` | Read path exposes ID3v2 frames/comments/lyrics; Basic native collections are not preserved | **Capability inaccuracy.** AUD-07 |
| `docs/SUPPORT.md:779-802`: erase wipes native metadata for supported families and reports residual fields | ASF/WMA custom attributes cause `verificationFailed` and no commit; ASF has no native wipe | **Incomplete limitation.** AUD-10 |
| Low-level header: `writeTrackNumber` writes only the track number/total | It deletes disc freeform aliases (`true,true` cleanup) | **False API comment/behavior.** AUD-05 |
| Raw API docs: exact keys/arrays and `.merge` preserves hidden MP4 freeform atoms | MP4 freeform keys cannot be targeted; merge fails or no-ops, replace fails | **Material limitation not documented.** AUD-09 |
| Basic docs: `year`/`releaseDate` fields | MP4 single-field edits are rejected with `.date` error | **Missing constraint/inaccurate field attribution.** AUD-08 |
| Erase docs / test narrative: "residual warnings" | ASF residual is a thrown verification failure, not a returned warning | **Contract ambiguity.** AUD-10 |
| `FormatCapability`/README "fixtureCovered" for AAC/TTA/DSF etc. | Fixtures exist, but important native fields (comments/lyrics, number pairs) are not covered | **Coverage caveat should be stronger.** |

### I.2 Accurate documentation and strengths

The following documentation is substantially accurate and useful:

- `docs/THREAD_SAFETY.md` correctly describes the process-wide mutex, per-entry mutation coordination, read identity checks, and the lack of cross-process guarantees.
- `docs/ARCHITECTURE.md` accurately describes the dependency boundary, the namespaced binary, the namespaced-vs-ABI isolation limitation, the transaction sequence, and the staging/verification model.
- `docs/INSTALLATION.md` accurately documents the binary identity, supported slices, embedding/signing, checksum verification, and offline behavior.
- The README's evidence labels (`fixtureCovered`, `upstreamSupported`, `experimental`, `readOnly`) are conceptually honest and explicitly say a configured label is not empirical verification.
- The transaction and source-compatibility contracts are clearly stated and match the code in the areas audited.
- The documentation explicitly warns that the package is not a lossless native archive and that whole-map replacement owns the visible map.

These strengths do not offset the material false claims above; they show that the documentation is generally high quality but not reliable for the specific preservation/verification contracts that failed.

### I.3 Editorial suggestions

- Clarify that `MetadataWriteResult.warnings` is primarily for non-fatal container advisories; verification mismatches throw.
- Add a per-format/per-API preservation matrix rather than broad prose claims.
- Add explicit limitations for AAC native comments/lyrics, ASF custom erase, MP4 freeform raw APIs, TTA/AIFF/DSF/DSDIFF number pairs, and MP4 Basic date fields.
- State that capability reporting is extension-level, not a content-codec verdict.
- State that `replaceBasicMetadata` on MP4 writes the complete modeled track/disc surface and may remove recognized freeform aliases, if that behavior is retained.

## J. Build and Runtime Verification

### J.1 Environment

| Item | Value |
| --- | --- |
| Host | macOS 27.0.1 (26A434), arm64 |
| Xcode | 27.1 (27A9275) |
| Swift | Apple Swift 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1) |
| Package tools | Swift 6.0, GNU C++20 |
| Build products | external scratch `/tmp/taglib-audit-build`, `/tmp/taglib-audit-asan`, `/tmp/taglib-audit-tsan` |
| Test harness | separate external Swift executable compiled against the SwiftPM build products; disposable fixtures and tag builders under `/tmp/taglib-audit-*` |

### J.2 Commands and results

```sh
swift test --disable-sandbox --scratch-path /tmp/taglib-audit-build
# 153 XCTest: 2 skipped, 0 failures
# 33 Swift Testing in 7 suites: all pass

swift test --disable-sandbox --scratch-path /tmp/taglib-audit-asan --sanitize=address
# 153 XCTest + 33 Swift Testing: all pass, no AddressSanitizer report

swift test --disable-sandbox --scratch-path /tmp/taglib-audit-tsan --sanitize=thread
# 153 XCTest + 33 Swift Testing: all pass, no ThreadSanitizer report
```

Xcode tool results:

```text
BuildProject: The project built successfully (0.835 s)
RunAllTests: 186 tests: 184 passed, 0 failed, 2 skipped, 0 expected failures, 0 not run
```

The two skipped tests are `ExternalCorpusPreservationTests.testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus` (requires an external corpus) and `SnapshotThroughputBenchmarkTests.testOptInIndependentFileSnapshotThroughput` (opt-in benchmark). This audit did not claim those results.

### J.3 Independent experiments

The independent harness used the repository fixtures and generated fixtures in `/tmp`; no tracked fixture was modified. Representative experiments:

| Experiment | Method | Result |
| --- | --- | --- |
| MP4 freeform stale after Patch | Seed external `Acoustid Id`/`WORK`; apply Patch; read Basic; inspect atoms and `ffprobe` | Success with old Basic value and duplicate/old atoms (AUD-01) |
| Qualified ID3 comment/lyric removal | Seed structured `eng/Notes`/`fra/Paroles`; apply `.remove`/`.text`; inspect frames and structured collections | No-op removal, duplicate text append (AUD-02) |
| ID3v1-only MP3 track text | Strip ID3v2 from fixture, append ID3v1; call `writeTrackNumberText`/low-level; `ffprobe` before/after | Sparse ID3v2, unrelated fields hidden (AUD-03) |
| AAC/TTA/AIFF/DSF/DFF numbers | Basic, Patch, numberText, number-text writers; inspect `TRCK`/`TPOS`/`TXXX` frames | Split totals, false exact-text success (AUD-04) |
| MP4 number aliases | Seed aliases + pairs; title-only Basic; low-level track-only | Unrelated aliases deleted (AUD-05) |
| Mixed ID3v1/ID3v2 MP3 patch | Append ID3v1; apply track/advisory; capture error/hash | `verificationFailed`, no commit (AUD-06) |
| AAC native comments | Python-built ID3v2 with `COMM eng/Notes`, `USLT fra/Paroles`; Basic title edit | Language/description normalized, success (AUD-07) |
| MP4 Basic dates | Seed `©day`; year-only/release-only/clear tests | `.date` validation errors (AUD-08) |
| Raw MP4 freeform | Seed freeform; merge/replace with/without verification | Failed or no-op (AUD-09) |
| ASF erase | Seed custom attribute; erase | Residual failure (AUD-10) |
| Format matrix | Basic title/artist/album/comment for all fixtures | Success where supported; no payload corruption observed |
| AIFF/MP2 generated | `ffmpeg` generated; Basic/Patch | Basic works; AIFF number pair split |
| Artwork preservation | Seed and property-edit MP3/FLAC/MP4 | Artwork bytes preserved |

### J.4 Not independently verified

- iOS device/simulator runtime and minimum-OS runtime; only macOS 27 host build/test was exercised.
- The external preservation corpus test (skipped by default).
- The opt-in performance benchmark.
- Speex, S3M, IT, Shorten, MOD, and all extension aliases without fixtures.
- Hardware power-loss behavior and cross-process race outcomes.
- Full sanitizer instrumentation of the precompiled TagLib framework.

## K. Risk and Priority Matrix

### K.1 Must fix before merge

| Finding | Why blocking | Minimum fix |
| --- | --- | --- |
| AUD-01 | Verified Patch can leave stale MP4 semantic values and duplicate native atoms | Use schema/native MP4 mappings for Patch; remove all aliases; verify semantic Basic field + all aliases |
| AUD-02 | Explicit comment/lyric deletion returns success while data remains | Native collection-aware removal/replacement or explicit rejection; verify all qualified keys |
| AUD-03 | Track-only ID3v1 MPEG write hides unrelated metadata from common readers | Merge ID3v1 fields into new ID3v2 or keep ID3v1 authoritative; verify unedited Basic fields |
| AUD-04 | ID3-backed number pairs are split; `numberText` false success | Extend native ID3 pair writer to AAC/TTA/AIFF/DSF/DSDIFF; verify frames |
| AUD-05 | Basic/low-level MP4 writes delete unrelated freeform aliases | Scope cleanup to the pair actually changed; low-level track-only must not touch disc |

### K.2 Important but non-blocking

| Finding | Priority | Reason |
| --- | --- | --- |
| AUD-06 mixed-tag MP3 patch failure | High/Medium | Common files cannot edit track/advisory; safe rollback |
| AUD-07 AAC native comment/lyric language loss | Medium | Text retains, semantics degrade; capability mismatch |
| AUD-08 MP4 Basic date coupling | Medium | API ergonomics/contract; no corruption |
| AUD-09 raw MP4 freeform APIs | Medium | Default fails safe; verification-off no-op |
| AUD-10 ASF erase | Medium | Destructive clear broken on one family; safe failure |
| AUD-11 custom case duplicates | Low | Model/UI risk |
| AUD-12 MP4 separator | Low | Documentation/UI |
| AUD-13 bit depth | Low | Property completeness |
| AUD-14 Basic artwork verifier | Low | Verification weakness |
| AUD-15 exact text/display | Low | Formatting semantics |
| AUD-16 structured removal gaps | Low | API completeness |
| AUD-17 raw replace ID3v1 | Low | Documented replace boundary, but data risk |
| AUD-18 setuid/setgid clone | Low | Unverified filesystem edge |
| AUD-19 format fixtures | Low | Coverage |
| AUD-20 warnings semantics | Informational | Documentation |

### K.3 Testing improvements

Add the concrete tests in H.5. Highest priority: independent parser assertions for AUD-01/AUD-02/AUD-03/AUD-04/AUD-05, external corpus execution, and a no-stale-alias invariant.

### K.4 Documentation corrections

Correct the claims in I.1. Add a per-format/per-API matrix and explicit limitations. Do not describe "fixtureCovered" as field-level proof.

### K.5 Optional design improvements

- Centralize field-to-native mapping and format dispatch in a single table-driven writer rather than maintaining Swift schema, `kWritableTextMappings`, and native branches separately.
- Make `MetadataWriteResult.warnings` semantics explicit and ensure successful results carry only advisories.
- Consider making `BasicMetadata.year` read-only for MP4 or implementing combined date semantics.
- Add an explicit preservation mode for MP4 number aliases rather than unconditional cleanup.
- Add structured removal semantics for ASF attributes and ID3 URL/UFID.

### K.6 External dependency limitations

- TagLib is precompiled and not sanitizer-instrumented; memory safety inside TagLib remains an external risk.
- Dynamic C++ symbol interposition is documented as unsupported.
- Cross-process coordination is not provided; the final check/rename window remains racy against uncooperative writers.
- Hardware power-loss durability is not guaranteed.

### K.7 Unverified risks

- Setuid/setgid preservation under clone.
- iOS/min-OS runtime behavior.
- Speex/S3M/IT/Shorten/MOD and extension aliases.
- External corpus behavior on third-party tagged files.
- Resource exhaustion from malformed/oversized native metadata.
- Full binary/GUID ASF identity preservation in hostile inputs.

## L. Independent Merge Decision

### L.1 Decision

**NOT READY TO MERGE.**

**MERGE RECOMMENDATION: NO.**

The implementation has strong architectural work and a passing, broad test suite, but the current revision contains confirmed high-severity defects in supported public operations. In particular:

- A verified `applyMetadataPatch` can return success while an MP4 semantic field remains old and a duplicate native value remains.
- A verified `.comment`/`.lyrics: .remove` can return success while the native comment/lyric remains.
- A supported track-text operation can hide unrelated ID3v1 metadata from common readers.
- Advertised ID3-backed number pairs are split into nonstandard or partial native representations on AAC/TTA/AIFF/DSF/DSDIFF.
- An unrelated MP4 Basic edit can delete user freeform number aliases.

These are not merely missing tests or theoretical edge cases; they are reproduced with current code, standard fixtures or independently constructed files, and independent tools (`ffprobe`, structured item/frame inspection). They meet the audit's stated blocker categories: silent loss of unrelated metadata, verified writes falsely reporting successful persistence, and unsupported native conversions changing representation.

### L.2 Minimum corrective work

1. **Unify MP4 field mapping and verification (AUD-01).** Make `applyMetadataPatch` use the schema's MP4 freeform/native mapping; remove all old aliases; verify `BasicMetadata` plus every alias. Add cross-API tests for `work`, `acoustID`, `acoustIDFingerprint`, `originalReleaseDate`, `artistType`, `musicIPPUID`.
2. **Fix qualified ID3 comment/lyric semantics (AUD-02).** Remove all native `COMM`/`USLT` frames for scalar `.remove`/`.text`, or reject scalar edits with a typed structured-API requirement; verify collection counts and languages/descriptions.
3. **Fix MPEG secondary-tag handling (AUD-03/AUD-06).** Use a single preserving MPEG write path for track/advisory delta writers; when creating ID3v2, carry forward ID3v1/APE fields; avoid empty secondary tags; add true ID3v1-only and mixed-tag fixtures.
4. **Fix ID3-backed number pairs (AUD-04).** Extend the native combined `TRCK`/`TPOS`/`MVIN` writer to AAC/TTA/AIFF/DSF/DSDIFF; make `numberText` use it last; extend validation and frame-level tests.
5. **Scope MP4 number-alias cleanup (AUD-05).** Only remove aliases for pairs actually changed; low-level track-only must not remove disc aliases; document any retained canonicalization.
6. **Address the important medium issues before release:** AAC native ID3 comments/lyrics capability and preservation, MP4 Basic date semantics, raw MP4 freeform keys, ASF erase, and the related documentation claims.
7. **Then** rerun the full suite plus the new independent tests, ASAN/TSAN, and the external corpus test; only then reconsider merge readiness.

### L.3 Why the remaining strengths do not justify YES

The transaction layer, concurrency tests, payload oracles, and source compatibility are genuine and should be preserved. They reduce the risk of catastrophic file loss and make remediation tractable. They do not compensate for a metadata editor returning verified success without applying the requested semantic change. The package's own documentation promises exactly the verification behavior that AUD-01/AUD-02/AUD-04 violate.

## M. Optional Historical Cross-Check

### M.1 Method and disclosure

Phase One was completed before consulting historical audit/remediation reports. A broad `grep` across `docs/` during Phase One incidentally surfaced a few excerpt lines from `docs/INDEPENDENT_REVIEW_2026-10-18.md`; I did not open or use that report or other historical reports until Phase Two. All findings in C were established from current source, current public API, independent runtime experiments, and the test suite before the cross-check. No historical classification was used to create or remove a finding.

### M.2 Historical documents consulted

After the independent findings were recorded, I consulted:

- `docs/INDEPENDENT_REVIEW_2026-10-18.md`
- `docs/REMEDIATION_REPORT_2026-10-18.md`
- `docs/VERIFICATION_HARDENING_2026-10-18.md`
- `docs/MIGRATION_REPORT.md`
- `CHANGELOG.md`
- `MAINTENANCE_PROGRESS.md`
- `AUDIT_REPORT.md`

### M.3 Historical claims and comparison

The historical independent review concluded **READY WITH CAVEATS** for the review branch and stated that no demonstrated merge-blocking defect remained unresolved in the reviewed contracts. It reported 173 tests (171 passed, 2 skipped) at that time; the current tree has 186 tests. It identified related categories: P-06/IV-03 native comment/lyric language preservation (repaired for MP3/WAV/TTA), P-09/IV-10/IV-20 number-pair canonicalization/total handling, P-03/IV-12 alias cleanup, P-07/A-02 raw replacement limitations, and the general format-dispatch duplication risk. The current `CHANGELOG` and `SUPPORT` documents make broad preservation/verification claims consistent with that favorable assessment.

My independent evidence agrees with the historical strengths (transaction architecture, payload tests, concurrency, source compatibility) but disagrees with the conclusion that no merge-blocking defect remains. The differences are concrete, not a reclassification of the same evidence:

- **AUD-01** (MP4 freeform stale values/false success) was not found in the historical summary or the CHANGELOG's field lists. The historical review's MP4 tests cover native atoms and deltas, not Basic-to-Patch semantic transitions for `work`/`acoustID`/`acoustIDFingerprint`.
- **AUD-02** (qualified comment/lyric removal) is related to IV-12/P-06 but distinct: the historical repairs address Basic alias cleanup and native collection replay on Basic edits; they do not cover typed Patch `.remove` on a qualified `COMM`/`USLT`.
- **AUD-03** (ID3v1-only track text hides fields) is not in the historical finding tables. The old audit mentions ID3v1 spot checks and the changelog says MPEG ID3v2-only saves avoid lossy ID3v1 projections; neither establishes preservation when creating a new ID3v2 for a track-only write.
- **AUD-04** (AAC Basic/number-text and TTA/AIFF/DSF/DSDIFF split totals) is adjacent to IV-10/IV-20 but the historical repairs and tests focus on MP3/MP4/WAV/FLAC/Ogg/ASF. The current documentation still states combined ID3 behavior.
- **AUD-05** (MP4 number alias removal on title-only Basic and low-level track-only) is adjacent to the historical "MP4 native pairs authoritative, remove conflicting aliases" change; the historical tests seed native pairs/private atoms, not user freeform aliases on an unrelated edit or disc aliases on a track-only call.
- **AUD-07** (AAC native comment language loss) is adjacent to IV-03, but IV-03's evidence and repaired formats are MP3/WAV/TTA. AAC is omitted from the native-collection preservation path.
- **AUD-10** (ASF erase custom attribute) is not addressed by the historical erase matrix, which covers MP3/M4A/FLAC/Ogg/OGA/WAV.

### M.4 Historical issues that remain relevant

- P-06/IV-03's core lesson still applies: PropertyMap replay cannot reconstruct native comment/lyric languages/descriptions; the current AAC path demonstrates the same failure class outside the historical repair set.
- P-09/IV-10/IV-20's core lesson still applies: number-pair semantics differ by format and writer; current AAC/TTA/AIFF/DSF/DSDIFF behavior shows the repair was not comprehensive.
- P-03/IV-12's alias cleanup needs a precise notion of "represented alias"; current typed comment/lyric removal still targets only the unqualified key.
- P-07/A-02's raw replacement warning remains relevant; current raw MP4 freeform behavior is a further limitation.
- The historical review's own statement that "a new reproducible counterexample should be treated as a defect and reassessed" supports the NOT READY decision here.

### M.5 Historical issues apparently fixed and independently confirmed

The audit independently confirmed several historical repairs: WAV INFO preservation through typed/Basic edits; omitted structured artwork preservation; MIME/description preservation on artwork correction; opaque ID3 payload rejection; NUL rejection across multiple writers; same-entry coordination; source compatibility; and transaction rollback/durability status. These are real strengths and are credited in this report.

### M.6 Documentation discrepancy with history

The historical review's READY WITH CAVEATS decision and the current README/CHANGELOG "verification hardening" narrative are broader than the current behavior. The current docs should not cite the historical test counts or "no demonstrated blocker" conclusion as evidence for the current HEAD; the current HEAD has 186 tests and still reproduces the defects above. The historical reports are useful engineering context, not substitutes for current evidence.

## Appendix A — Reproduction Recipes

The following recipes reproduce the high-severity findings using only public package APIs and ordinary inspection tools. Build a disposable test executable or test target against the local package; do not run destructive operations against repository fixtures. All paths below are examples under `/tmp`.

### A.1 ID3v1-only MP3 (AUD-03)

```python
import uuid

src = "Tests/TagLibAudioMetadataTests/Audio/testAudioFile.mp3"
data = open(src, "rb").read()
if data[:3] == b"ID3":
    n = (data[6] << 21) | (data[7] << 14) | (data[8] << 7) | data[9]
    data = data[10 + n:]

def fixed(text, width):
    return text.encode("utf-8")[:width].ljust(width, b"\0")

tag = (b"TAG" + fixed("Legacy Title", 30) + fixed("Legacy Artist", 30)
       + fixed("Legacy Album", 30) + fixed("1999", 4)
       + fixed("Legacy Comment", 30) + b"\0")
assert len(tag) == 128
path = f"/tmp/id3v1-only-{uuid.uuid4()}.mp3"
open(path, "wb").write(data + tag)
print(path)
```

Then call, on a second copy of that path:

```swift
try TagLibMetadataManager.writeTrackNumberText("07/12", discNumberText: nil, to: url)
// For contrast, applyMetadataPatch on this input uses the MPEG native-pair
// branch and does not reproduce the sparse-tag result; keep it as a control.
```

Inspect with:

```sh
ffprobe -v error -show_entries format_tags -of default=nw=1 "$path"
python3 - "$path" <<'PY'
import sys
d = open(sys.argv[1], "rb").read()
print("ID3v2:", d[:3], "ID3v1:", d[-128:-125], "size:", len(d))
PY
```

`writeTrackNumberText` and low-level `writeTrackNumber` create a sparse ID3v2; the package's `readMetadataResult` still shows ID3v1 fallback fields because it merges them. The low-level variant is:

```swift
import CTagLibBridge
try CTagLibBridge.TagLibMetadataExtractor.writeTrackNumber(
    7, totalTracks: 12, padWidth: 2, to: url)
```

### A.2 MP4 freeform stale field (AUD-01)

```swift
import Foundation
import TagLibAudioMetadata

let url = try copyFixture("m4a")  // disposable copy
try TagLibMetadataManager.writeStructuredMetadataWithVerification(
    StructuredMetadata(mp4Atoms: [
        .init(key: "----:com.apple.iTunes:Acoustid Id",
              type: "stringList", values: ["EXTERNAL-OLD"])
    ]), to: url)

let before = try TagLibMetadataManager.readMetadataResult(from: url)
assert(before.acoustID == "EXTERNAL-OLD")

let result = try TagLibMetadataManager.applyMetadataPatch(
    MetadataPatch(fields: [.acoustID: .text("PATCH-NEW")]), to: url)
assert(result.warnings.isEmpty)

let after = try TagLibMetadataManager.readMetadataResult(from: url)
print("semantic:", after.acoustID)  // EXTERNAL-OLD in the audited build
let atoms = try TagLibMetadataManager.readStructuredMetadataResult(from: url).mp4Atoms
print(atoms.filter { $0.key.lowercased().contains("acoust") }
    .map { "\($0.key)=\($0.values)" })
```

Replace `Acoustid Id` with `WORK`/`.work` or `Acoustid Fingerprint`/`.acoustIDFingerprint` for the related cases. The same pattern with `replaceBasicMetadata` first reproduces the Basic-created variant.

### A.3 Qualified ID3 comment/lyric removal (AUD-02)

```swift
let url = try copyFixture("mp3")
try TagLibMetadataManager.writeStructuredMetadataWithVerification(
    StructuredMetadata(comments: [
        .init(language: "eng", description: "Notes", text: "English comment")
    ]), to: url, replacingCollections: [.comments])

let remove = try TagLibMetadataManager.applyMetadataPatch(
    MetadataPatch(fields: [.comment: .remove]), to: url)
print(remove.warnings)  // [] in the audited build
print(try TagLibMetadataManager.readStructuredMetadataResult(from: url).comments)
// still ["eng/Notes/English comment"]

let text = try TagLibMetadataManager.applyMetadataPatch(
    MetadataPatch(fields: [.comment: .text("New comment")]), to: url)
print(text.warnings)    // []
print(try TagLibMetadataManager.readStructuredMetadataResult(from: url).comments)
// ["eng/Notes/English comment", "XXX//New comment"] in the audited build
```

Use `StructuredMetadata(lyrics: [.init(language: "fra", description: "Paroles", text: "French lyrics")])` and `.lyrics` for the USLT case. The workaround is a structured collection replacement with `replacingCollections: [.comments]`/`[.lyrics]`.

### A.4 AAC/TTA/AIFF/DSF/DSDIFF split numbers (AUD-04)

For AAC Basic:

```swift
var m = try TagLibMetadataManager.readMetadataResult(from: aacURL)
m.track = 3; m.trackTotal = 12; m.disc = 1; m.discTotal = 2
_ = try TagLibMetadataManager.replaceBasicMetadata(m, to: aacURL)
let frames = try TagLibMetadataManager.readStructuredMetadataResult(from: aacURL).id3v2Frames
print(frames.filter { ["TRCK", "TPOS", "TXXX"].contains($0.frameID) }
    .map { "\($0.frameID):\($0.description ?? "")=\($0.values)" })
// TRCK=3, TPOS=1, TXXX:TRACKTOTAL=12, TXXX:DISCTOTAL=2
```

For AAC exact text:

```swift
_ = try TagLibMetadataManager.applyMetadataPatch(
    MetadataPatch(numberText: .init(trackNumberText: "03/12",
                                    discNumberText: "01/02")), to: aacURL)
print(try TagLibMetadataManager.readMetadataResult(from: aacURL).trackNumberText)
// "03" in the audited build; TRCK=03 plus TXXX:TRACKTOTAL=12
```

For TTA/AIFF/DSF/DSDIFF, apply the typed fields or call `replaceBasicMetadata` on a fresh fixture; inspect `id3v2Frames` the same way. The audited build produced `TRCK=3`, `TPOS=1`, `TXXX:TRACKTOTAL=12`, `TXXX:DISCTOTAL=2`.

### A.5 MP4 number-alias deletion (AUD-05)

```swift
let url = try copyFixture("m4a")
let seed = StructuredMetadata(mp4Atoms: [
    .init(key: "trkn", type: "intPair", first: 3, second: 12),
    .init(key: "disk", type: "intPair", first: 1, second: 2),
    .init(key: "----:com.apple.iTunes:TRACKNUMBER", type: "stringList", values: ["CUSTOM-TRACK"]),
    .init(key: "----:com.apple.iTunes:TRACKTOTAL", type: "stringList", values: ["CUSTOM-TOTAL"]),
    .init(key: "----:com.apple.iTunes:DISCNUMBER", type: "stringList", values: ["CUSTOM-DISC"]),
    .init(key: "----:com.apple.iTunes:UNRELATED", type: "stringList", values: ["KEEP"]),
])
try TagLibMetadataManager.writeStructuredMetadataWithVerification(seed, to: url)

var m = try TagLibMetadataManager.readMetadataResult(from: url)
m.title = "Title only edit"
_ = try TagLibMetadataManager.replaceBasicMetadata(m, to: url)
let atoms = try TagLibMetadataManager.readStructuredMetadataResult(from: url).mp4Atoms
print(atoms.filter { $0.freeformDescription != nil }
    .map { "\($0.key)=\($0.values)" })
// UNRELATED remains; TRACKNUMBER/TRACKTOTAL/DISCNUMBER are gone
```

For the low-level disc-alias variant, seed `DISCNUMBER`/`DISCTOTAL` plus `trkn`/`disk`, then call `TagLibMetadataExtractor.writeTrackNumber(7, totalTracks: 20, padWidth: 2, to: url)` and inspect the atoms.

### A.6 AAC native comment language (AUD-07)

Build a disposable AAC with an ID3v2 tag using the same frame helper style as the test suite:

```python
import uuid

def syncsafe(n):
    return bytes([(n >> 21) & 0x7F, (n >> 14) & 0x7F,
                  (n >> 7) & 0x7F, n & 0x7F])

def frame(fid, payload):
    return fid.encode() + syncsafe(len(payload)) + b"\0\0" + payload

def comm(desc, lang, text):
    return frame("COMM", b"\x03" + lang.encode() + desc.encode()
                 + b"\0" + text.encode())

def uslt(desc, lang, text):
    return frame("USLT", b"\x03" + lang.encode() + desc.encode()
                 + b"\0" + text.encode())

frames = comm("Notes", "eng", "Native comment") + uslt("Paroles", "fra", "Native lyrics")
tag = b"ID3\x04\x00\x00" + syncsafe(len(frames)) + frames
src = "Tests/TagLibAudioMetadataTests/Audio/testAudioFile.aac"
path = f"/tmp/aac-native-{uuid.uuid4()}.aac"
open(path, "wb").write(tag + open(src, "rb").read())
print(path)
```

Then read, change only the title with `replaceBasicMetadata`, and read again. The audited build changed `eng/Notes` to `XXX/NOTES` and `fra/Paroles` to `XXX/PAROLES` while returning success.

### A.7 Mixed ID3v1/ID3v2 track patch (AUD-06)

Use the Python ID3v1 builder from A.1 on a file that already has a rich ID3v2 tag. Apply:

```swift
try TagLibMetadataManager.applyMetadataPatch(
    MetadataPatch(fields: [.track: .integer(7), .trackTotal: .integer(12)]), to: url)
// Throws verificationFailed with unedited ALBUM/GENRE/DATE/COMMENT changes
// before commit; SHA-256 of the file is unchanged.
```

### A.8 ASF erase (AUD-10)

```swift
var m = BasicMetadata.empty
m.title = "Erase Title"
m.customFields = ["ERASE_CUSTOM": "present"]
_ = try TagLibMetadataManager.replaceBasicMetadata(m, to: wmaURL)
do {
    _ = try TagLibMetadataManager.eraseAllMetadataWithVerification(from: wmaURL)
} catch {
    print(error) // verificationFailed(["Some metadata fields still remain after erase: CUSTOM."])
}
```

### A.9 Raw MP4 freeform (AUD-09)

Seed `----:com.apple.iTunes:CUSTOM_FIELD`, then call `.merge` and `.replace` with the same key. Default verification throws; `verifyAfterWrite: false` returns success without changing the atom. See section C.10 for exact output.

### A.10 Build harness note

The audit used a standalone Swift executable compiled against the package's build products, plus `ffprobe` and small Python parsers. The key API calls above are sufficient to reproduce the behavior from a package test target or a disposable SwiftPM consumer; no private API or source modification is required.

## N. Repository Integrity Confirmation

- No production source file was modified.
- No test file was modified.
- No fixture was modified.
- No existing documentation or historical report was modified.
- No package configuration, dependency, or binary target was modified.
- No branch was created.
- No commit was created.
- No merge, reset, rebase, amend, squash, stage, force-push, or discard operation was performed.
- The original working tree was clean at the start and remains clean except for this new untracked report.
- The report was written to `docs/CLEAN_ROOM_AUDIT_2026-10-19.md` and left uncommitted for the repository owner.
- Build/test artifacts were directed to `/tmp/taglib-audit-*`; any repository `.build` updates are ignored artifacts, not tracked source changes.
- The audit did not run destructive experiments against repository fixtures or user audio; all destructive experiments used disposable copies under `/tmp/taglib-audit-data`.
- No merge was performed; the merge recommendation is advisory only.

**Final merge recommendation: NO. Current state: NOT READY TO MERGE.**
