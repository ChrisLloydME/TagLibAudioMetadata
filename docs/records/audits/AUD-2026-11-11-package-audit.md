# Independent package audit: mapping, preservation, and test evidence

| Field | Value |
| --- | --- |
| Record ID | `AUD-2026-11-11-package-audit` |
| Type | Audit |
| Date | `2026-11-11` |
| Status | Final for the examined working tree; not a release approval |
| Examined revision | `26fc76f314bbc2c77f326f1ec50d7c4a794e3068` plus this audit's uncommitted test/gate/documentation changes |
| Branch | `codex/native-mapping-followup-repairs` |
| Environment | macOS 27.2 (26B123), Xcode 27.2 (27B52), Apple Swift 6.4.2, TagLib binary release `taglib-binary-2.3.1-r2`; host manifest sandbox unavailable; `ffprobe` 9.0.2 used for one external MP4 check |
| Supersedes | none; it supersedes the current acceptance value of the repair claims for this tree |
| Superseded by | none |
| Related records | [REM-2026-11-11-native-mapping-followup](../remediation/REM-2026-11-11-native-mapping-followup.md), [REM-2026-11-10-expanded-test-system](../remediation/REM-2026-11-10-expanded-test-system.md), [REM-2026-11-09-numbering-acceptance-repairs](../remediation/REM-2026-11-09-numbering-acceptance-repairs.md) |
| Scope | Independent source review and execution evidence for the package's testing infrastructure, native field mappings, preservation, transaction boundaries, and declared capabilities. AudioMator, other repositories, and user audio were not accessed. Production code was not modified. |

## Summary

**Verdict: NOT READY TO MERGE OR RELEASE.** Two reproduced data-integrity defects are P0
under this audit's severity rubric:

1. An unrelated Basic metadata edit destroys unedited multi-value or malformed
   YEAR/DATE slots on MP4, ID3v2.4, FLAC, and APE. The same edit rejects a valid
   multi-value MP4 `©day` with `MetadataValidationError.invalidYearText` validation instead of preserving
   it (F-01).
2. On ASF, an unrelated Basic metadata edit removes the native
   `WM/EncodingSettings` attribute and rewrites the value as `WM/EncodedBy`;
   the declared Encoder Settings field is neither readable nor writable through
   the corresponding native target. On ID3-backed formats, the same ownership
   conflation makes `TSSE` populate Encoded By, creates a spurious `TENC` frame
   on an unrelated Basic edit, blocks Encoded By removal, and blocks a normal
   Encoder Settings patch (F-02).

Further P1 findings cover MP4 Basic/low-level compatibility-alias handling
(F-03), the MP4 track/disc boundary declaration (F-04), and the mixed-framework
quality gate (F-05). The test infrastructure can prove the three systematic
semantic matrices (MP4, FLAC, ID3v2.4) and the independent native probes, but it
cannot establish Basic-path preservation, ASF or ID3 encoder ownership, the
declared MP4 pair range, or the other formats as a systematic matrix. After the
gate repair, the complete Debug and Release gates fail closed with `accepted:
false`; they must remain failing until the reproduced defects are repaired and
the new regressions pass.

## Scope and revision

The repository was clean at the start:

- HEAD `26fc76f314bbc2c77f326f1ec50d7c4a794e3068` on
  `codex/native-mapping-followup-repairs`, tracking
  `origin/nativeMappingFollowupRepairs`.
- `git status --porcelain` was empty; no stash entries.
- `Package.swift` declares `swift-tools-version: 6.4`, macOS 13/iOS 16,
  `TagLib` binary target `taglib-binary-2.3.1-r2` with checksum
  `d7a36b2492266a17fcd97bd776cd841d9fc85275270bc0c3cb9621395b3178c7`;
  no `Package.resolved` exists.
- No `AGENTS.md` was present in the repository.

Examined: `docs/operations/{TESTING,MAPPING_TEST_STRATEGY,STATUS}.md`,
`docs/guide/{READING,WRITING}.md`, the preservation/transaction/audio-continuity
explanation documents, the mapping specification and generated matrix, the
record index/conventions, the Swift facade, the Objective-C++ bridge, the test
target, `scripts/validate-tests.sh`, `scripts/summarize-test-run.py`,
`scripts/tests/test_test_gate.py`, and `.github/workflows/ci.yml`.

Not examined: AudioMator, another repository, a user audio library, release
signing, hosted CI results, device/minimum-OS runtime, or a full sanitizer rerun.

## Method

1. Recorded Git, toolchain, manifest, dependency, documentation, and command
   baselines before changing anything.
2. Read the required documentation and the production/test source rather than
   accepting the recorded verdicts or commit messages.
3. Ran the mandated checks individually and recorded each exit status. The host
   cannot launch SwiftPM's manifest sandbox (`sandbox-exec: sandbox_apply:
   Operation not permitted`), so the documented
   `TAGLIB_DISABLE_MANIFEST_SANDBOX=1` / `--disable-sandbox` adjustment was used
   and is recorded as an environment limitation, not a code failure.
4. Added independent audit probes using temporary fixture copies. The probes use
   the existing test-only MP4/FLAC/ID3/ASF parsers where available, plus native
   MP4 atom and ASF attribute inspection. They do not repair production code.
5. Captured the pre-fix quality-gate behavior with the committed parser, then
   repaired only the gate and its policy tests. The gate failure evidence was
   preserved before the repair in `.build/audit-evidence/`.
6. Re-ran the complete Debug/Release gates, the strict warning build, both
   consumers, the documentation check, and gate policy tests after the changes.
7. Used `ffprobe` once to independently confirm how a low-level high-valued MP4
   track pair is observed by an external reader.

Evidence status vocabulary: **Reproduced** means a runnable probe or command
failed as described; **Source-Inferred Only** means code inspection identified a
gap without an execution that demonstrates user-visible wrong behavior;
**Unverified** means the claim could not be established locally.

## Findings

### F-01 — Basic replacement destroys unedited date arrays and rejects a valid multi-value MP4 YEAR (P0)

- **Severity:** P0 (loss of unedited metadata on a successful Basic write).
- **Confidence:** Reproduced.
- **Status:** Open.
- **Affected APIs:** `replaceBasicMetadata`, `updateBasicMetadata`.
- **Affected formats:** MP4/M4A; MP3 and other ID3v2.4-backed files; FLAC;
  APE/WavPack/Musepack through the same Xiph/APE Basic writer. Ogg, WAV, AIFF,
  TTA, DSF, and DSDIFF use the same Basic date path but were not separately
  probed; mark those as unverified extensions of the same code path.
- **Condition:** The file already contains a multi-value or malformed YEAR,
  DATE, RELEASEDATE, or ORIGINALDATE value, and the caller changes an unrelated
  Basic field.

Observed:

- FLAC, `YEAR ["2004","2005"]` and `DATE ["2008-03-04","not-a-date"]`:
  an unrelated title edit commits and leaves `YEAR ["2004"]` and
  `DATE ["2008-03-04"]`. RELEASEDATE and ORIGINALDATE arrays are preserved.
- APE: the same edit shortens the native YEAR and DATE item values.
- ID3v2.4: `TDRC` with two values becomes one value; the extra value is lost.
- MP4: freeform DATE, RELEASEDATE, and ORIGINALDATE arrays collapse to one
  value; audio is unchanged in the probe.
- MP4 `©day ["2004","2005"]`: an unrelated Basic edit throws
  `MetadataValidationError.invalidYearText("2004; 2005")` and commits nothing.
  The Basic projection joined the two values into one text string and then the
  YEAR validator rejected the untouched value.
- Audio bytes were compared and unchanged in the FLAC, APE, ID3, and MP4 date
  probes; the damaged field is metadata, not the encoded audio.

Expected: an omitted field is unchanged; a Basic edit must preserve untouched
native date owners, their value arrays, duplicate values, and malformed text.
The package's own preservation contract says that an unrelated Basic edit
restores untouched YEAR/DATE/RELEASEDATE/ORIGINALDATE slots and multi-value
arrays ([PRESERVATION.md](../../explanation/PRESERVATION.md), "Basic preservation
rules" and "Basic replacement and dates").

Source locations:

- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift:847-857`
  (scalar expected number/date text), `:950-957` (ID3v2.3 date gate),
  `:1058-1095` (preservation loop explicitly skips `.year`, `.date`, and
  `.standaloneDate`), `:1126` (bridge Basic write), `:1188` (post-write
  verification).
- `Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc:1196-1224`
  (`SetPropertiesPreservingNativeDates` restores YEAR/DATE arrays),
  `:1264-1295` and `:1307-1314` (the subsequent `setNative`/`setNumber` calls
  replace those restored arrays with one scalar), `:1328-1334` (ASF date
  scalars).
- `Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc:789-833`
  (`BuildGenericPropertyMap` emits scalar date values).
- Verification does not compare untouched date arrays:
  `TagLibMetadataManager+Verification.swift:206-215` only checks the requested
  Basic text fields; `expectedTextFields` in `Write.swift:866-939` does not
  include `date`, and `textFieldValue` has no standalone DATE case.

Reproduction:

```sh
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/basicUnrelatedEditMustPreserveMultivalueDatesOnFLAC
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/basicUnrelatedEditMustPreserveMultivalueDatesOnAPE
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/basicUnrelatedEditMustPreserveMultivalueYearOnID3
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/basicUnrelatedEditMustPreserveMP4DateFreeformArrays
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/basicUnrelatedEditMustAcceptValidMultivalueMP4Year
```

The test-only independent readers are `IndependentFLACProbe`,
`HardeningFixture.apeState`, `IndependentID3Probe`, and `IndependentMP4Probe`.
Log: `/tmp/audit-probes-all-final.log`; the stable gate log is under
`.build/test-evidence/debug-20261111-105705-62009/tests.log`.

Why the existing suite did not detect it:

- The systematic matrices use `applyMetadataPatch`, not Basic replacement.
- `MappingIndependenceRepairTests.unrelatedEditsPreserveNativeDateArraysAnd-
  MalformedText` also uses `applyMetadataPatch`.
- The Basic round-trip tests use scalar dates and do not seed multi-value or
  malformed arrays.
- Basic verification has no untouched-date-array comparison, so a collapse can
  return success.

Recommended permanent regression: a Basic-preservation matrix across MP4,
ID3v2.4, FLAC, APE, Ogg, WAV/AIFF, TTA, and DSD that seeds multi-value and
malformed values in all four date slots and performs an unrelated title edit,
then asserts the exact native arrays/frames with an independent parser.

Recommended fix direction: preserve native date arrays in the Basic writer
(the bridge restores them and then immediately overwrites them), or do not
write a date slot at all when the scalar Basic projection was not edited. Add
`date` and the untouched date owners to Basic verification. Handle a
multi-value MP4 `©day` as preservation or an explicit typed rejection before
staging; do not send the joined display string through `invalidYearText` for a
value the caller did not edit.

### F-02 — Encoded By and Encoder Settings ownership is conflated; ASF loses and relocates an unedited Encoder Settings value (P0)

- **Severity:** P0 (loss of an unedited native field, plus writes to the wrong
  native field). The ID3 manifestations are P1 but share the ownership root.
- **Confidence:** Reproduced.
- **Status:** Open.
- **Affected APIs:** Basic read/`updateBasicMetadata`/`replaceBasicMetadata`;
  `applyMetadataPatch(.encodedBy:)`, `applyMetadataPatch(.encoderSettings:)`;
  ASF native attribute reads.
- **Affected formats:** ASF/WMA (confirmed); ID3-backed MP3/AAC/WAV/AIFF/TTA/
  DSF/DSDIFF (confirmed for MP3; the shared alias/property-map path is the same).
  MP4 and Xiph/APE reads use exact owners and did not show this specific
  contamination in the probes.

Observed on ASF:

- A file seeded with native `WM/EncodingSettings = "Settings"` and a custom
  `HARDEN_KEEP` attribute is edited with only
  `updateBasicMetadata { title = "Unrelated" }`.
- The edit succeeds. The resulting native attributes contain
  `HARDEN_KEEP` and `WM/EncodedBy`; `WM/EncodingSettings` is gone. The value was
  both dropped and relocated to the Encoded By target.
- `readMetadataResult().encoderSettings` is empty while
  `WM/EncodingSettings` exists.
- `applyMetadataPatch(.encoderSettings: .text("New Settings"))` fails with
  `Patched semantic field encoderSettings differs after save.` and
  `Patched field encoderSettings differs after save.`; the original file is not
  committed.
- The audio packet tail is unchanged in the Basic probe.

Observed on ID3v2.4:

- With only `TSSE = "Encoder X"`, `readMetadataResult().encodedBy` is
  `"Encoder X"` and `encodedBy` is not empty. An unrelated Basic title edit then
  creates a native `TENC` frame containing `"Encoder X"`.
- With `TENC = "Encoded By"` and `TSSE = "Settings"`,
  `applyMetadataPatch(.encodedBy: .remove)` fails with
  `Patched semantic field encodedBy remains after removal.` because the read
  falls back to the `TSSE`/`ENCODING` projection.
- `applyMetadataPatch(.encoderSettings: .text("New Settings"))` fails with
  `Unedited PropertyMap field ENCODING changed during the patch.`

Expected: Encoded By owns only its canonical TENC/©enc/ENCODEDBY target;
Encoder Settings owns TSSE/©too/WM/EncodingSettings (and the documented Xiph
`ENCODING` slot). An unedited field must not be dropped, relocated, created, or
allowed to block an edit of the other field.

Source locations:

- `Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc:591-596` treats both
  `ENCODEDBY` and `ENCODING` as Encoded By; only `ENCODERSETTINGS` becomes
  Encoder Settings.
- `Sources/CTagLibBridge/Internal/TLPropertyMapWrites.inc:766-769` repeats the
  `ENCODEDBY`/`ENCODING` fallback and reads only `ENCODERSETTINGS` for the
  Encoder Settings value.
- `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift:447-448` gives
  `.encodedBy` property keys `["ENCODEDBY","ENCODING"]` and `.encoderSettings`
  only `["ENCODERSETTINGS"]`.
- `Sources/TagLibAudioMetadata/MetadataMappingCatalog.swift:350-372` declares
  ASF `WM/EncodedBy` for ENCODEDBY and `WM/EncodingSettings` for ENCODING, but
  the bridge's basic model does not use that ASF target consistently.
- `Sources/TagLibAudioMetadata/MetadataNativePlanning.swift:161-201`: ASF only
  uses native targets for a fixed set including dates/content group/artists/
  peaks; `.encoderSettings` falls through to the `ENCODERSETTINGS` PropertyMap
  spelling instead of `WM/EncodingSettings`.
- `Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc:1316-1335`: the ASF
  native writer set includes `WM/EncodingSettings`? It does not; the list has
  year, DATE, original year, content group, artists, and peaks, but no Encoder
  Settings.
- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift:766-767`
  copies the Basic read values into the bridge model; a polluted
  `encodedBy` therefore becomes a real write.
- ID3 frame extraction: `Sources/CTagLibBridge/Internal/TLContainerExtractors.inc:100-137`
  maps TENC to encodedBy and TSSE to encoderSettings, but the generic model
  fallback (`TLUnifiedExtraction.inc:105-108`) runs first, so after TENC removal
  the TSSE/`ENCODING` projection becomes the encodedBy value.

Reproduction:

```sh
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/asfUnrelatedBasicEditPreservesNativeEncodingSettings
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/asfEncoderOwnersRemainIndependent
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/id3EncoderSettingsMustNotPopulateEncodedBy
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/id3EncodedByRemovalWithEncoderSettingsMustSucceed
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/id3EncoderSettingsEditMustSucceedAndPreserveEncodedBy
```

The ASF check uses `IndependentASF.attributes` and compares the header tail;
the ID3 checks use `IndependentID3Probe`.

Why the existing suite did not detect it:

- The systematic MP4 matrix covers Encoded By/Encoder Settings; the FLAC matrix
  covers them through Xiph owner keys. The ID3v2.4 matrix deliberately covers
  only 20 fields and excludes both encoder fields.
- The ASF tests cover hardened attributes, numbers, artwork, and erasure but do
  not seed or edit `WM/EncodedBy`/`WM/EncodingSettings`, and the Basic ASF test
  only checks track/disc pairs.
- No test asserted that an unrelated Basic edit preserves unknown ASF
  attributes; the custom attribute is preserved, but the declared native
  Encoder Settings target is not.

Recommended permanent regression: for each ID3-backed format and ASF, seed
TENC/TSSE or WM/EncodedBy/WM/EncodingSettings (including one side absent),
perform read, set, replace, remove, and an unrelated Basic edit, then assert the
exact native frames/attributes. Include ASF audio-tail preservation.

Recommended fix direction: separate `ENCODING` from the Encoded By alias and
assign it to Encoder Settings where the contract says it is the Encoder Settings
slot; add explicit ASF `WM/EncodingSettings` read/write and preservation; allow
the ID3 `ENCODING` projection in the `.encoderSettings` verification allowance;
and never let Basic rebuild a property map in a way that drops a native target
that Basic cannot represent.

### F-03 — MP4 Basic/low-level writers do not retire their own compatibility freeform aliases (P1)

- **Severity:** P1 (normal Basic clears fail; the low-level path silently
  resurrects cleared values; Basic sets leave stale duplicate native fields).
- **Confidence:** Reproduced.
- **Status:** Open.
- **Affected APIs:** `replaceBasicMetadata`/`updateBasicMetadata`; low-level
  `writeTagMetadata` with `verification: .none`.
- **Affected format:** MP4/M4A.
- **Fields reproduced:** `encodedBy`, `encoderSettings`, `publisher`,
  `conductor`, `itunesAlbumID`, `itunesPurchaseDate`, `work`. The same
  canonical-atom-plus-freeform-read pattern appears elsewhere in the bridge
  mapping table and is not exhaustively enumerated.
- **Condition:** The old value is stored in the documented compatibility
  freeform (`----:com.apple.iTunes:ENCODEDBY`, `...:ENCODING`, `...:LABEL`,
  `...:CONDUCTOR`, `...:ITUNESALBUMID`, `...:ITUNESPURCHASEDATE`, `...:WORK`)
  rather than in the canonical atom.

Observed:

- Basic clear of any listed field throws
  `TagLibManagerError.verificationFailed([...differs after save...])`; the
  transaction aborts and original bytes remain unchanged. The edit cannot be
  completed through Basic.
- Low-level `writeTagMetadata` with the field set to `nil` commits, but
  `readMetadataResult` immediately returns the old value from the surviving
  freeform. This is false success for the low-level contract's "clears them
  where the format allows".
- Basic set of `encodedBy`/`encoderSettings` over legacy freeforms writes the
  canonical `©enc`/`©too` atoms but leaves the legacy freeforms in place.
- Basic set of `work` with both `©wrk` and freeform WORK present writes the
  canonical value and leaves the legacy freeform value.
- The semantic `applyMetadataPatch(.encodedBy: .remove)` succeeds and removes
  only the owned `ENCODEDBY` alias, preserving `©too` and freeform `ENCODING`.
  This proves the semantic planner already has the needed ownership model; the
  Basic/low-level surface does not use it.

Source locations:

- `Sources/TagLibAudioMetadata/MetadataNativePlanning.swift:32-61` registers
  the freeform read aliases for the semantic planner.
- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift:834-844`
  builds the sparse Basic custom-field map; `:1025-1171` preserves selected
  native arrays but not the freeform read aliases above.
- `Sources/CTagLibBridge/Internal/TLPropertyMapWrites.inc:388-457` (writable
  text mappings) and `:547-583` (freeform reconciliation) do not clear the
  freeform alias for the canonical-atom mappings; the `MP4ItemMatchesField`
  special cases are only used where a freeform description is configured.
- `Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc:94-107` recognizes
  the legacy freeform identities on read.

Reproduction:

```sh
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/basicClearOfLegacyBackedMP4FieldsMustCommit
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/lowLevelClearMustNotResurrectOldMP4Values
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/basicSetMustRetireEditedMP4CompatibilityAliases
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/basicWorkMustKeepCanonicalOwnerAndRetireLegacyFreeform
```

Why the existing suite did not detect it: the MP4 matrix seeds the canonical
atom through the structured path for set/replace/remove, so the freeform-only
initial state is never exercised; Basic tests seed canonical fields; no test
clears a Basic field whose only old value is a compatibility freeform.

Recommended permanent regression: for every canonical MP4 field with a
documented freeform read alias, seed only the freeform, then run Basic read,
set, clear, and low-level clear; assert the canonical write, alias retirement,
and exact sibling preservation with `IndependentMP4Probe`.

Recommended fix direction: have the Basic/legacy writer use the same
ownership/cleanup contract as `semanticStorage`, or route Basic field edits
through that planner for MP4. Do not make verification accept the stale alias;
retire it on an explicit edit and preserve it on unrelated edits.

### F-04 — MP4 track/disc declares a 65535 maximum but 32768…65535 are read as negative and fail verification (P1)

- **Severity:** P1 (a normal edit within the declared range fails; an existing
  native value is reported incorrectly).
- **Confidence:** Reproduced.
- **Status:** Open.
- **Affected APIs:** `applyMetadataPatch`, `replaceBasicMetadata`,
  `writeTrackNumberText`, low-level pair writers, capability/validation.
- **Affected format:** MP4/M4A.
- **Condition:** A track/disc component or total is 32768…65535.

Observed:

| Value | Native `trkn` data after low-level write | Basic read | High-level patch |
| --- | --- | --- | --- |
| 32767 | `000000017fff0000` | 32767 | succeeds |
| 32768 | `0000000180000000` | -32768 | verification fails |
| 65535 | `00000001ffff0000` | -1 | verification fails |

`ffprobe 9.0.2` reports `track=1/-1` and `disc=1/-1` for a file written with
65535. The native data atom contains `0xffff`, so the container bytes are
present; the package's read/verification path interprets them as a signed
16-bit value. The declared constraint and documentation say 1…65535
(`MetadataFieldSchema.swift:252-255`, `MetadataSnapshotPatch.swift:268-279`,
`docs/guide/WRITING.md:53`, `docs/explanation/PRESERVATION.md:88`). The existing
test only checks 65536 rejection; no test covers 32768…65535.

Source locations:

- `Sources/TagLibAudioMetadata/MetadataFieldSchema.swift:252-255` (schema
  constraint 1…`Int32.max` for track/disc; the planner then applies the MP4
  maximum).
- `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift:268-279`
  (`maximum = 65535` for MP4).
- `Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc:31-47`
  (`SetMP4IntPairItem` accepts `int` values up to 65535 and writes them as a
  native pair).
- `Sources/CTagLibBridge/Internal/TLContainerExtractors.inc:214-224` and the
  MP4 read path assign the native pair components into `NSInteger` fields; the
  observed negative values show the signed interpretation.
- `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift:726-727`
  calls `validateNativeNumberPair` before staging; that validator allows 65535,
  so the failure is not a preflight rejection.

Reproduction:

```sh
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter AuditProbeTests/mp4PairUpperBound65535RoundTrips
```

`ffprobe` check:

1. Create `/tmp/audit-pair-65535.m4a` from the fixture and write track 1/65535
   with the low-level model; logs are in `/tmp/audit-pair-external.log`.
2. `ffprobe -v error -show_entries format_tags=track,disc -of
   default=noprint_wrappers=1 /tmp/audit-pair-65535.m4a` → `track=1/-1`,
   `disc=1/-1`.

Why the existing suite did not detect it: `mp4PairOverflowRejectsWithoutMutation`
tests only 65536; the 65535 boundary and 32768 were not exercised. No independent
integer-pair parser validates the native width or sign.

Recommended permanent regression: a table for 0/1/32767/32768/65535/65536 with
independent native pair decoding and Basic readback, for track and disc, plus
the Basic/low-level writers.

Recommended fix direction: either read and verify the MP4 pair as unsigned
16-bit (if the native container supports 65535 and TagLib can be made to agree)
or lower the declared maximum to 32767 and reject 32768+ before staging. In
either case, update the schema, planner, docs, and capability text together.

### F-05 — The mixed-framework gate accepted missing matrix functions and disguised skip identities (P1, testing infrastructure)

- **Severity:** P1 for the acceptance gate (an incomplete run could be accepted
  as complete). It is not a production data defect.
- **Confidence:** Reproduced with the committed parser and a real green log.
- **Status:** Fixed in the testing infrastructure; production code unchanged.
- **Affected scripts:** `scripts/summarize-test-run.py`,
  `scripts/tests/test_test_gate.py`; `scripts/validate-tests.sh` already
  rejected extra arguments.
- **Condition:** A real passing log from
  `.build/test-evidence/release-20261111-094733-54052/tests.log`, with all
  required suite banners retained.

Before the repair, `summarize-test-run.py` checked only suite **names** and the
**method-name suffix** of XCTest skips. It accepted:

1. The same real log with the MP4/FLAC/ID3 matrix and native-probe execution
   lines removed; only the `Suite ... passed` banners remained. `accepted:
   true`, `missing_required_suites: []`.
2. A skip line whose class was changed from
   `ExternalCorpusPreservationTests` to `InjectedCorpusTests` while the method
   name remained allowlisted. `accepted: true`, `unexpected_skips: []`.

The repair now requires named executable evidence and minimum parameterized
case counts:

- `mp4LifecycleHasNativeOwnerAndPreservesSiblings` ≥ 258 cases;
- `wrongValueKindCannotPartiallyCommitAnotherField` ≥ 86 cases;
- `independentCommentLifecycle` ≥ 90 cases;
- `nativeFrameLifecyclePreservesOtherFramesAndAudio` ≥ 60 cases;
- `unavailableTypedMP4WritesRejectBeforeMutation` ≥ 5 cases;
- `everyFieldRequiresAnExplicitCoverageDecision` ≥ 1;
- `flacKnownVectorKeepsDuplicateCommentEntriesAndAudio` ≥ 1;
- `id3KnownVectorAndUnsupportedHeaderBounds` ≥ 1.

It also requires the class **and** method of an allowed XCTest skip, rejects
failed named tests even if an overall passing summary appears, and rejects
failed XCTest test names. The complete run with the real, untampered log is
still accepted.

Reproduction of the pre-fix behavior:

```sh
git show 26fc76f:scripts/summarize-test-run.py > /tmp/old-summarize.py
python3 /tmp/old-summarize.py .build/audit-evidence/matrix-lines-removed.log 0 /tmp/old-matrix.json
python3 /tmp/old-summarize.py .build/audit-evidence/skip-class-tampered.log 0 /tmp/old-skip.json
```

Both old runs returned 0 and `accepted: true`. After the fix, both return 1 and
`accepted: false`; the matrix log reports the five missing named tests and the
skip log reports the unexpected full identity. Evidence: `.build/audit-
evidence/`, `/tmp/audit-probes-all-final.log`, and the final gate logs below.

Why the existing policy tests did not detect it: `scripts/tests/test_test_gate.py`
fed a synthetic log that contained **no matrix test execution lines** and used
only method names for allowlisted skips. It therefore encoded the weak contract
as passing. The repaired policy suite has 19 tests, including named-test
deletion, case-count shrink, other-class allowlisting, named-failure hiding,
and real XCTest skip-diagnostic cases.

### F-06 — Basic verification omits standalone DATE and Content Group (P2, Source-Inferred Only)

- **Severity:** P2 (verification gap / possible false success).
- **Confidence:** Source-Inferred Only; no user-visible wrong write was
  reproduced.
- **Status:** Open.
- **Affected APIs:** `replaceBasicMetadata` and `updateBasicMetadata`.
- **Evidence:** `TagLibMetadataManager+Write.swift:866-939` builds
  `expectedTextFields` with `year`, `releaseDate`, and `originalReleaseDate`,
  but not `date` or `contentGroup`. `TagLibMetadataManager+Verification.swift:
  340-411` has no `"date"` or `"contentGroup"` case in `textFieldValue`. A Basic
  write of those fields can therefore succeed without an exact readback
  comparison. This does not itself prove the bridge writes them incorrectly;
  it does mean the verification claim for those fields is incomplete.
- **Recommended regression:** assert the exact native DATE/©grp value after a
  Basic write and a Basic clear; add the expected fields to the verification
  context.

### F-07 — Systematic cross-format coverage remains narrow (P2, evidence limit)

- **Severity:** P2 (evidence/coverage, not a reproduced behavior defect).
- **Confidence:** Reproduced from the test inventory and the passing matrices.
- **Status:** Open/coverage limit.
- **Evidence:**
  - The systematic independent matrices cover only MP4 (86 fields × 3
    operations + 86 wrong-kind cases), FLAC (30 × 3), and ID3v2.4 (20 × 3).
  - ASF, APE, Ogg, WAV, AIFF, TTA, DSF/DSDIFF, MP4 raw/whole-map, Basic
    replacement, and low-level bridge writes have specialized tests but no
    per-field × operation × independent-byte oracle.
  - The current ID3v2.3 date behavior is now probed by this audit and rejects
    before mutation, but it had no permanent test before this audit.
  - `IndependentMP4Probe` has no malformed/truncated/64-bit-size contract tests;
    `NativeProbeContractTests` covers only FLAC/ID3 known vectors and
    malformed lengths.
  - Several specialized suites (for example
    `MP4ContentGroupVerificationTests`) read the target through the package's
    structured projection rather than the independent byte parser.
  - Generic strings such as `"First"`/`"Replacement"` exercise storage, not
    UUID, ISRC, ReplayGain, or date grammar validity; the strategy document
    acknowledges this, but the distinction must not be lost in coverage claims.
  - No hosted CI, sanitizer, minimum-platform, or device run was performed in
    this audit.
- **Recommended follow-up:** extend the independent per-operation matrix to the
  remaining fixture-covered families, add malformed-input vectors for each
  probe, and require named tests/case counts in the gate as the suite grows.

### F-08 — Test isolation and oracle limitations (P3)

- **Severity:** P3 (maintainability/evidence quality).
- **Confidence:** Source-Inferred Only.
- **Status:** Open as a bounded limitation.
- `MP4ContentGroupVerificationTests` reuses one temporary file across a set and
  replace/remove sequence; `MappingIndependenceRepairTests` loops fields on one
  file. A failure in an earlier step can change the initial state for a later
  step, obscuring attribution even though each iteration uses an independent
  copy in the systematic matrices.
- `FixtureMetadataRoundTripTests` and several specialized suites use the package
  reader as both writer and expected-value source; their assertions are
  consistency checks rather than independent interoperability evidence.
- The test target is not compiled with `-warnings-as-errors`; existing
  deprecation warnings remain in the test build.
- The `CleanRoomPrivilegeTests` failure below is an environment limitation, not
  a production defect, but it makes both full gates red on this host.

## Repairs or recommendations

No production implementation, version, dependency, `Package.resolved`, signing
configuration, or external checkout was modified. The two testing-infrastructure
files were repaired because the gate was the subject of the audit:

1. `scripts/summarize-test-run.py` now requires named matrix/oracle execution
   evidence with minimum case counts, exact class+method skip identity, no
   failed named tests, and no failed XCTest names. It remains fail-closed for
   missing framework summaries, missing required suites, truncation, format
   changes, nonzero runner status, and unexpected skips.
2. `scripts/tests/test_test_gate.py` now has 19 policy tests (13 before) and
   uses realistic Swift Testing/XCTest lines, including the required matrix and
   oracle names.

Why this is a testing repair rather than a weakened requirement: it makes the
gate stricter, rejects the incomplete/tampered real logs that the old parser
accepted, and still accepts the real complete log. It does not change a
production assertion or an expected mapping value.

The permanent production regressions should be the 24 tests in
`Tests/TagLibAudioMetadataTests/Integration/AuditProbeTests.swift`: 16 currently
fail and reproduce F-01 through F-04; 8 pass as controls (semantic alias
removal, unknown advisory preservation, legacy `.date` placement, Basic
ContentGroup/Grouping/Work independence, MP4 movement boundaries, ID3v2.3 date
rejection, ASF semantic preservation). They should remain in the suite and
should be added to the gate's required-test set once the production fixes are
accepted.

Recommended production changes, not implemented here:

- F-01: preserve untouched native date arrays/freeforms in the Basic path; add
  Basic verification for DATE and untouched date owners; reject an unedited
  multi-value YEAR explicitly before staging rather than `invalidYearText`.
- F-02: separate `ENCODING` from `encodedBy`; make Encoder Settings own ASF
  `WM/EncodingSettings` and preserve unmapped native ASF attributes on Basic
  writes; add ID3 `ENCODING` to the `.encoderSettings` verification allowance;
  prevent Basic reads from projecting TSSE/WM/EncodingSettings into Encoded By.
- F-03: retire the edited field's compatibility freeform in Basic/low-level MP4
  writes, using the semantic ownership table; preserve the siblings as the
  semantic path does.
- F-04: decide the MP4 pair native range from an independent unsigned/signed
  contract; align schema, preflight, bridge read/write, verification, and docs.
- F-06: add DATE/Content Group to Basic verification.
- F-07/F-08: extend matrices/oracles and isolate specialized cases.

## Verification

All commands ran from the repository root with Xcode 27.2 / Swift 6.4.2.
`--disable-sandbox` / `TAGLIB_DISABLE_MANIFEST_SANDBOX=1` was required because
the host cannot launch SwiftPM's manifest sandbox. This is an environment
adjustment; the manifest sandbox failure was recorded separately and not treated
as a code failure.

| Check | Result | Counts / limits |
| --- | --- | --- |
| `git status` / `git rev-parse` at start | pass | clean tree; HEAD `26fc76f`; branch as above |
| `python3 -m unittest discover -s scripts/tests` before repair | pass | 13 tests |
| `python3 -m unittest discover -s scripts/tests` after repair | pass | 19 tests |
| `python3 scripts/check-docs.py` before documentation edits | pass | 50 Markdown files |
| `bash scripts/validate-tests.sh debug` without env override | environment failure | `sandbox-exec: sandbox_apply: Operation not permitted`; no tests ran; exit 1 |
| `TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh debug` before audit tests | **fail closed** | XCTest 158 executed (156 passed, 2 opt-in skips); Swift Testing 128 declarations / 31 suites, 1 issue (`CleanRoomPrivilegeTests` host precondition); `accepted: false` |
| `TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh release` before audit tests | **fail closed** | same counts; `accepted: false` |
| `swift build --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror` | environment failure | manifest sandbox unavailable |
| `swift build --disable-sandbox ...` (same warning flags) | pass | build complete; no production warnings |
| Consumer `TagLibAudioMetadataConsumer` | pass | `37 readable extensions`; exit 0 |
| Consumer `TagLibAudioMetadataLowLevelConsumer` | pass | `low-level consumer OK`; exit 0 |
| `swift test --filter AuditProbeTests` | **fail as intended** | 24 tests in 1 suite: 8 passed, 16 failed, 32 issues; 4 P0/P1 root causes |
| Final Debug gate | **fail closed** | XCTest 158 (156 pass, 2 skips); Swift Testing 152 declarations / 32 suites, 33 issues, 17 failed named tests including 16 audit regressions + privilege; `accepted: false` |
| Final Release gate | **fail closed** | same 158 / 152 / 33 / 17; `accepted: false` |
| Gate tamper: matrix execution lines removed | old parser accepted; repaired parser rejects | `.build/audit-evidence/matrix-lines-removed.log`; missing named tests reported |
| Gate tamper: allowlisted method in another class | old parser accepted; repaired parser rejects | `.build/audit-evidence/skip-class-tampered.log`; unexpected full identity reported |
| Gate real complete log | accepted | `.build/audit-evidence/real-green.log`; `accepted: true` |
| `ffprobe` high-pair check | external confirmation | `track=1/-1`, `disc=1/-1` for native `0xffff` |
| ASAN / TSAN | not executed | no claim |
| Minimum-platform builds | not executed | no claim |
| Hosted CI / provenance trial | not executed | no claim |

Final Debug evidence:
`.build/test-evidence/debug-20261111-105705-62009/` (log and `summary.json`).
Final Release evidence:
`.build/test-evidence/release-20261111-105805-62136/`.
Initial gate evidence:
`.build/test-evidence/debug-20261111-095922-56118/` and
`.build/test-evidence/release-20261111-094733-54052/` (the latter was the
pre-audit green reference used for the gate tamper test).
Audit-probe log: `/tmp/audit-probes-all-final.log`; tamper artifacts and the
old/new summaries: `.build/audit-evidence/`.

## Coverage table

Statuses used exactly: **Passed**, **Failed**, **No Test Case** (no executable
case found for this surface), **Not Executed** (a check exists but was not run
in this environment), **Unsupported** (declared unavailable). "Passed" below
means the existing matrix/probe executed; it does not imply that the
independently discovered Basic defects do not exist on another surface.

| Field / behavior | MP4 semantic | MP4 Basic/low-level | ID3v2.4 semantic | ID3 Basic | FLAC/Xiph semantic | ASF | Other / notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| YEAR / DATE / RELEASEDATE / ORIGINALDATE (scalar) | Passed (4×3 matrix) | Failed (F-01 arrays) | Passed (4×3 matrix) | Failed (F-01 arrays; ID3 TDRC collapse) | Passed (scalar) | Passed (ASF typed dates) | ID3v2.3 read-only rejection Passed (audit control); Ogg/WAV/AIFF Basic No Test Case |
| Content Group / Grouping / Work | Passed (3×3 matrix + sibling cases) | Passed (Basic control) | Passed (3×3 matrix; ID3 content-group sibling probe) | No Test Case | Passed (3×3 matrix) | Content Group No Test Case; Grouping/Work Unsupported | ASF Work no native target |
| Encoded By / Encoder Settings | Passed (2×3 matrix) | Failed (F-03 alias state; F-02 ID3/ASF ownership) | Failed (F-02: Encoder Settings patch) | Failed (F-02: pollution/creation/removal) | Passed (2×3 matrix) | Failed (F-02: WM/EncodingSettings read/write/loss) | APE/Ogg semantic No Test Case for the pair |
| Movement number / count | Passed (3×3 matrix; boundaries 0/255/256/32767; overflow rejected across semantic/Basic/structured/low-level) | Passed (boundaries) | Passed (number-pair tests) but no systematic matrix | No Test Case systematic | No Test Case systematic | No Test Case | ID3/FLAC movement has specialized number tests, not per-operation native oracle |
| Track / disc and totals | Passed for ordinary values; Failed at 32768–65535 (F-04) | Failed at 32768–65535; ordinary Passed | Passed (native ID3 pair tests) | Passed (specialized) | Passed (Xiph/APE separate keys; normal) | Passed (native pairs; total-only rejects) | Legacy private atoms tested in `NumberingRepairRegressionTests`; no all-formats per-operation matrix |
| Advisory 0/1/2/unknown/absent | Passed (semantic; unknown preservation) | Passed (audit unknown control) | Passed (Fixture tests) | Passed (specialized; no dedicated audit matrix) | Passed (text extension 0 vs absent) | Passed (Fixture tests) | Raw map representation not a full 4-state matrix |
| Artwork | Passed (structured/collection; Basic multi-artwork control) | Passed (control) | Passed (structured) | No Test Case specifically | Passed (FLAC) | Passed (ASF) | APE/Opus have specialized artwork tests; not all collections |
| Unknown / multivalue / whitespace preservation | Passed (matrix X-MATRIX-KEEP) | Failed for date arrays (F-01) | Passed (matrix X-KEEP) | Failed for TDRC arrays (F-01) | Passed (matrix X-PRESERVE; padded/duplicate) | Custom attribute Passed; WM/EncodingSettings Failed (F-02) | `IndependentMP4Probe` lacks malformed-vector tests |
| Audio payload preservation | Passed (matrix) | Passed (date/artwork controls) | Passed (matrix/probes) | Passed (date probe) | Passed (matrix) | Passed (header-tail control) | Not a byte-exact metadata archive |
| Permissions / ACL / xattr / flags | n/a | n/a | n/a | n/a | n/a | n/a | XCTest `ReliabilityFailureTests` Passed; privilege precondition environment Failed |
| Stale version / symlink / hardlink / atomic failure | n/a | n/a | n/a | n/a | n/a | n/a | XCTest transaction suites Passed; `CleanRoomPrivilegeTests` environment Failed |
| Raw whole-map / raw delta / structured / low-level | Partial | Failed for F-03 low-level clear | Partial | Failed | Partial | Partial | No cross-product matrix; documented raw limitations remain |

## Remaining limitations

- This audit ran only on macOS arm64. The sanitizer, minimum-platform, iOS
  runtime, device, and x86_64 checks were not rerun and remain unverified.
- The host strip of setuid/setgid bits makes `CleanRoomPrivilegeTests` fail its
  own precondition (`before.st_mode & 0o7777 == permissions`, observed
  `0o644` vs `0o4644`). This is an environment restriction, not a production
  defect, but it is a real red gate on this host and must not be reported as a
  production pass.
- The 24 audit probes are intentionally failing reproduction tests. A future
  fix must make them pass and must not delete or weaken them. They are not yet
  in the gate's hardcoded required-test list; adding them after repair is the
  recommended next gate change.
- The independent probes are bounded test readers, not general format
  conformance oracles. The ASF/FLAC/ID3 probes have known input limitations
  documented in their source; the MP4 probe has no malformed-input contract
  test.
- No cross-tool conformance campaign, AudioMator adoption, release signing,
  tag publication, or remote-tag consumer run was performed.
- The `©day` multi-value Basic failure may affect Ogg/WAV/AIFF/TTA/DSF through
  the shared Xiph/ID3 Basic path, but those layouts were not separately seeded
  in this audit; they are unverified extensions, not separate reproduced
  findings.

## References

- Examined commit: `26fc76f314bbc2c77f326f1ec50d7c4a794e3068`
  "Record the native mapping follow-up repairs".
- Tests:
  - `Tests/TagLibAudioMetadataTests/Integration/AuditProbeTests.swift` — 24
    audit repros/controls.
  - `Tests/TagLibAudioMetadataTests/Integration/SemanticLifecycleMatrixTests.swift`,
    `FLACSemanticLifecycleTests.swift`, `ID3SemanticLifecycleTests.swift`,
    `NativeProbeContractTests.swift`, `IndependentMP4Probe.swift`,
    `IndependentFLACProbe.swift`, `IndependentID3Probe.swift`.
  - `Tests/TagLibAudioMetadataTests/Transactions/CleanRoomPrivilegeTests.swift`.
- Gate:
  - `scripts/validate-tests.sh`,
    `scripts/summarize-test-run.py`,
    `scripts/tests/test_test_gate.py`,
    `.github/workflows/ci.yml`.
- Current documentation: [Testing](../../operations/TESTING.md),
  [Mapping test acceptance](../../operations/MAPPING_TEST_STRATEGY.md),
  [Preservation](../../explanation/PRESERVATION.md),
  [Transactions](../../explanation/TRANSACTIONS.md),
  [Status](../../operations/STATUS.md).
- Related records: [REM-2026-11-11-native-mapping-followup](../remediation/REM-2026-11-11-native-mapping-followup.md)
  (its local acceptance claim is not a current acceptance verdict for this
  augmented tree), [REM-2026-11-10-expanded-test-system](../remediation/REM-2026-11-10-expanded-test-system.md),
  [REM-2026-11-09-numbering-acceptance-repairs](../remediation/REM-2026-11-09-numbering-acceptance-repairs.md).
