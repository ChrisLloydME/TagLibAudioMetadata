# Pre-release audit of automatic numbering and public number writes

| Field | Value |
| --- | --- |
| Record ID | `AUD-2026-11-17-pre-release` |
| Type | Audit |
| Date | `2026-11-17` |
| Status | Final |
| Examined revision | `2df252584aa12c3d0e5a088da8cb24a44b99197b` (candidate start; canonical lane); regression tests committed as `b4d6b2b`; the record/index/status commit is a documentation-only follow-up. `git diff 2df2525..HEAD -- Sources` is empty. |
| Branch | `codex/pre-release-audit-20261117`, created from `main` at the candidate HEAD |
| Environment | macOS 27.2.1 (26B131), arm64; Xcode 27.2 (27B52); Swift 6.4.2 (swiftlang-6.4.2.1.9, clang-2100.4.1.1); TagLib 2.3.1-r2 (upstream `54ae7d8ac45755e286a5c574280f48d5bef93aef`, SwiftPM ZIP checksum `d7a36b2492266a17fcd97bd776cd841d9fc85275270bc0c3cb9621395b3178c7`) |
| Supersedes | `none` (qualifies the automatic-numbering acceptance in `REM-2026-11-16-automatic-numbering` for the current candidate) |
| Superseded by | `none` |
| Related records | `REM-2026-11-16-automatic-numbering`, `REM-2026-11-15-test-system-acceptance`, `VER-2026-11-15-package-test-system`, `AUD-2026-11-11-package-audit` |
| Scope | Independent package-only pre-release audit of the current candidate: automatic numbering, public write surfaces, native ownership/preservation, transactions, the test system, focused sanitizers, both package-owned consumers and minimum-platform Debug builds. No application repository, no Release build or Release test lane, no production repair, and no publication action. |

## Summary

**Verdict: NOT READY.** Three reproduced package defects and one material test-gate
coverage gap remain in the current candidate:

1. **F-01 (High, confirmed):** `writeTrackNumberText` silently ignores an explicit
   zero total in the supplied text on MP4 and PropertyMap-backed formats
   (FLAC, Ogg, APE-family, WavPack, Musepack). A call that asks for `"5/0"`
   against an existing `12` total leaves `5/12` and returns success with no
   warnings. The direct bridge method behaves the same way. The ordinary
   `MetadataPatch.numberText` path and the ID3 bridge branch do implement the
   requested clear, so the defect is a public entry-point inconsistency, not a
   missing grammar.
2. **F-02 (High for behavior, medium for contract scope, confirmed):**
   `writeTrackNumberText` does not retire recognized private MP4 number
   provenance for the group it edits. The amended "normal number edit" rule
   (`applyMetadataPatch` typed fields, Basic edits and
   `MetadataPatch.numberText`) retires exact private provenance in the same
   staging transaction; the convenience entry point leaves it behind. A later
   legitimate edit can recover the stale value.
3. **F-03 (Medium, confirmed):** a recognized private text atom that contains a
   parseable pair plus an unparseable/multi-value sibling is treated as
   unambiguous evidence for a missing native component. The typed and
   `numberText` paths recover the parseable value and then retire the whole
   atom. This is a regression from the `0.8.0` `numberText` broad unresolved-
   group rejection, and it contradicts the "opaque/malformed missing components
   must not be guessed" rule. The current gate's malformed test only covers a
   wholly unparseable atom.
4. **F-04 (Medium, confirmed):** the canonical contract lane can pass while
   these defects are present. The `C-MP4-NUMBER-TEXT` scenarios do not exercise
   an explicit zero against an existing total, the title-only no-migration
   control cannot distinguish an absent pair from a written `0/0` pair, the
   rewritten fixture test asserts two private namespaces that it never seeds,
   and the calibration set has no mutant for the convenience preserve/retire
   branches. This is a test-gate blocker in the sense that the evidence does not
   establish the claimed public-surface behavior, not a claim that the runner
   itself is broken.

The clean candidate's complete strict Debug canonical lane was **accepted**
(181 XCTest declarations with the two reviewed skips, 280 Swift Testing
declarations in 52 suites, 75/75 scenarios and 16/16 killed calibration
mutants). That result is recorded below because it is true and useful: it
demonstrates the gate and the production suite pass, and it also demonstrates
that the gate does not cover F-01 to F-03. The new audit regressions reproduce
those failures directly.

Release builds and Release test lanes were excluded by instruction. The
verdict therefore does not speak to Release behavior, hosted CI, device or
minimum-OS runtime, or an embedding application.

## Scope and revision

- Repository: `/Users/lloyd/Developer/Xcode/TagLibAudioMetadata`.
- Starting branch and commit: `main` at
  `2df252584aa12c3d0e5a088da8cb24a44b99197b` ("chore: merge automatic numbering
  recovery"). The working tree was clean, including untracked files, before the
  audit branch was created. The audit did not switch to `main` afterwards.
- Previous published release: tag `0.8.0` at
  `9e986eb7bf4f019949d17cc1e117334793b5f932`. `959d68854db600a5726b6b9cb9c05018b9335f22`
  (the "accepted source" named in `STATUS.md`) has an identical
  `Sources/`, `Tests/` and `scripts/` tree to `0.8.0`; the remaining changes were
  documentation/evidence. The candidate's source changes since `0.8.0` are
  confined to `Sources/TagLibAudioMetadata/MetadataNumberInventory.swift` and
  `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift`, plus the automatic
  numbering tests, calibration definitions, required-test inventory and
  documentation. The bridge, writer and raw/structured production paths are
  unchanged from `0.8.0`.
- Candidate production source tree: the same `Sources/`, `Tests/` and
  `scripts/` content as the tested `e9fb7da16e793d78d3a8460f7790b61dc8d26016`
  revision; the merge commit and the later commit are documentation-only. The
  old evidence's commit and source hash are still stale for this candidate, so
  every acceptance artifact below was generated fresh.
- Audit branch: `codex/pre-release-audit-20261117`; regression test commit
  `b4d6b2b`; the final record/index/status commit is documentation-only. The
  worktree was clean at the final revision. The only changes from `2df2525` are
  the audit regression test and the audit record/index/status edits; no
  production source changed.
- Binary/dependency identity: TagLib 2.3.1-r2, upstream source commit
  `54ae7d8ac45755e286a5c574280f48d5bef93aef`, SwiftPM checksum
  `d7a36b2492266a17fcd97bd776cd841d9fc85275270bc0c3cb9621395b3178c7`. Resolved
  macOS slice SHA-256 `b44be8e3c1eb49bbfca02adc56ae97fe2d3f982451554dddc0a8f139e3bf2f90`;
  iOS device slice `d83e4530519eeedc77aac39458bdcee7a60d1384cde242b2116d444e477906a9`;
  iOS simulator slice
  `70783c40647621465436ec345dc6669dd584c9503d3f61475e160b2547ecd788`.
- Toolchain/OS: recorded above and in the campaign manifest. The build target
  was `arm64-apple-macosx27.2.0` with SDK
  `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk`.
- Concurrent worktree changes: `/bin/ps` is not permitted in the sandbox, so
  process enumeration was unavailable. `git status --porcelain=v2
  --untracked-files=all` was empty before the branch, before the canonical lane,
  and again while the lane ran; the lane's before/after manifests also record
  the same source hash. No concurrent source change was observed. The audit's
  own scratch probes were kept under ignored `.build/audit-scratch/` and removed
  from `Tests/` before the baseline lane.
- Explicit exclusions: no application repository was inspected, built, launched
  or used; no Release build, Release test lane, signing check, publication,
  push, PR, merge, tag or binary/dependency change; no production behavior was
  modified.

## Method

- Read the current repository instructions, test/language guide, preservation
  rules, mapping specification, testing guide, status page, release-boundary
  records, public API index and the 2026-11-16 automatic-numbering record.
- Inspected the complete `0.8.0..HEAD` diff, not only final files. Traced the new
  `automaticNumberValue` resolution, the removal of the broad `numberText`
  unresolved-group check, the new private-provenance retirement, verification
  and warning paths, and the rewritten/removed tests. Compared the unchanged
  bridge and writer code with `0.8.0` to distinguish candidate regressions from
  pre-existing defects.
- Exercised public APIs on fresh copies of committed fixtures:
  `applyMetadataPatch` typed fields, `MetadataPatch.numberText`,
  `writeTrackNumberText`, `replaceBasicMetadata`/`updateBasicMetadata`,
  `writeStructuredMetadataWithVerification`, `writeTagMetadata`,
  `applyRawMetadataPatch`, direct `TagLibMetadataExtractor` bridge calls,
  numbering inventory/planning, and read operations.
- Used the test-only independent readers already in the target:
  `IndependentMP4Probe`, `IndependentFLACProbe`, `IndependentOggProbe`,
  `IndependentID3Probe`. Native assertions use literal atom payloads,
  Vorbis-comment arrays and ID3 frame text, never the package reader as the
  expected-value source. Each reproduction uses a new fixture copy. Rejected
  writes are checked with `Data(contentsOf:)` equality, version equality and,
  where available, audio-payload equality.
- Ran the current canonical policy/inventory checks, the complete strict Debug
  contract lane with a fresh 16-mutant calibration campaign, the existing
  numbering and release-acceptance tests, both package-owned consumers, focused
  AddressSanitizer and ThreadSanitizer lanes for the changed numbering tests,
  and minimum-platform Debug builds. Documentation link/heading/generated-page
  checks were run separately.
- The privilege test was independently investigated. The default DSH
  workspace-write sandbox strips setuid/setgid on `chmod` (`0o4644` becomes
  `0o644`, `0o2644` becomes `0o644`); the authorized wider-access mode can
  establish `0o4644`/`0o2644`, and the unchanged test then passes. The canonical
  lane below was run in that wider-access mode, not in a mode that weakens or
  skips the test.

## Findings

### F-01 — `writeTrackNumberText` ignores an explicit zero total on MP4 and PropertyMap formats

- **Severity:** High.
- **Confidence:** Confirmed (reproduced on MP4, FLAC and Ogg; direct bridge also
  reproduced; ID3 control passes).
- **Status:** Open. Pre-existing in `0.8.0`, still present in the candidate.
- **API/format/trigger:** facade
  `TagLibMetadataManager.writeTrackNumberText(_:discNumberText:to:verifyAfterWrite:expectedVersion:)`
  and direct `TagLibMetadataExtractor.writeTrackNumberText(_:discNumberText:to:)`.
  MP4/M4A and PropertyMap-backed formats (FLAC, Ogg Vorbis/Opus/FLAC, APE-family,
  WavPack, Musepack). Seed an existing pair (track `3/12` or disc `1/2`), then
  supply `"5/0"` (or disc `"1/0"`).
- **Expected:** the supplied text is documented as authoritative; a text with an
  explicit `/0` sets the total to zero. `MetadataPatch.numberText` already
  produces `trkn 5/0`, `TRACKNUMBER=5` with no `TRACKTOTAL`, etc., and the ID3
  branch of the direct bridge writes `"5/0"`. The number-only form (`"5"`, no
  slash) is the case that preserves the existing total.
- **Observed:** MP4 returns success with `trkn 5/12` and `warnings == []`;
  FLAC/Ogg return success with `TRACKTOTAL=12` still present. The direct bridge
  behaves identically. Disc `"1/0"` against `disk 1/2` leaves `1/2`. The
  convenience facade's verification deliberately disables exact text
  verification when the expected total is zero and the pre-write total is
  non-zero, so it cannot detect the mismatch.
- **Reproduction:** fresh copies of `testAudioFile.m4a`, `.flac`, `.ogg`, `.mp3`;
  seed `3/12` through `applyMetadataPatch`; call
  `writeTrackNumberText("5/0", discNumberText: nil, to: url)`; inspect
  `IndependentMP4Probe.values["trkn"]` or
  `IndependentFLACProbe/IndependentOggProbe.comments`. The permanent regression
  is `PreReleaseAuditTests.convenienceNumberTextExplicitZeroIsAuthoritative` and
  `convenienceDiscExplicitZeroIsAuthoritative`; the MP4 control is
  `metadataPatchNumberTextExplicitZeroIsAuthoritative`.
- **Native evidence:** MP4 `trkn` payload `[0,5,0,12,0,0]` (number 5, total 12)
  after the requested clear; FLAC/Ogg Vorbis comment `TRACKTOTAL=12`. The ID3
  control writes `TRCK=5/0`; the ordinary number-text patch control writes
  `trkn 5/0`/removes `TRACKTOTAL`.
- **Release impact:** a public, documented number-formatting entry point silently
  fails to perform the requested write and reports durable success. This is
  exactly the "incorrect success" class the release audit is required to catch.
  It also leaves a stale total that later recovery paths can resurrect.
- **Minimal repair direction:** distinguish an omitted total from an explicit
  zero by the presence of `/`, not by `total > 0`, in (a) the Swift
  `recoverTrack`/`recoverDisc` predicates, (b) the MP4 `if (totalTracks <= 0 &&
  itemMap contains trkn)` preservation branch, (c) the PropertyMap
  `explicitTrackTotal > 0 ? ... : existing` branches for track and disc, and (d)
  the facade verification's `verifiesExactTrackText`/`verifiesExactDiscText`
  predicates. Add MP4/FLAC/Ogg and disc regressions plus a calibration mutant
  that removes the slash/presence distinction. Do not fix by special-casing
  zero as "remove both"; the documented partial-pair representation is
  `0/total`.

### F-02 — `writeTrackNumberText` does not retire recognized private provenance

- **Severity:** High for the stated behavior; Medium if the convenience API is
  declared out of the amendment's scope. The audit brief states that a normal
  number edit must retire eligible provenance in the same transaction; the API
  is a public facade number edit, so this record treats the current behavior as
  a contract gap rather than a documented exemption.
- **Confidence:** Confirmed (reproduced MP4).
- **Status:** Open.
- **API/format/trigger:** facade `writeTrackNumberText` on MP4 with recognized
  private atoms `----:com.apple.iTunes:AUDIOMATOR_TRACKNUMBER_TEXT` and
  `----:com.apple.iTunes:TAGLIBAUDIOMETADATA_TRACKNUMBER_TEXT` (or the disc
  identities). Seed `trkn 3/0` and private `03/12`; call
  `writeTrackNumberText("5/12", discNumberText: nil, to: url)`.
- **Expected:** the edited track group's exact recognized private identities are
  absent after success; the disc group's identities, foreign namespaces,
  unrelated atoms and audio remain unchanged. This is the behavior of the typed
  and `MetadataPatch.numberText` paths and the amended preservation contract.
- **Observed:** `trkn` becomes `5/12`, the private track atoms remain
  (`AUDIOMATOR...` and `TAGLIBAUDIOMETADATA...` are both still present), and the
  call returns `warnings == []`. The facade's inventory has the exact identities
  available before staging, so this is not a missing-observation problem.
- **Reproduction:** `PreReleaseAuditTests.convenienceNumberTextRetiresEditedGroupProvenance`
  (currently failing on the two private identities). The disc, foreign,
  unrelated and audio assertions in the same test currently pass, which limits
  the defect to the edited group's private retirement.
- **Native evidence:** `IndependentMP4Probe.items` still contains the private
  freeform atoms after the write; `trkn` is `[5,12]`.
- **Release impact:** stale private provenance survives a successful edit.
  A later partial edit can recover or retire it, contrary to the policy that a
  normal number edit leaves no eligible stale evidence. At minimum callers
  cannot rely on the postcondition; at worst a later clear/edit resurrects the
  old value. The ordinary path's tests explicitly assert retirement, so the
  asymmetry is not documented as intentional.
- **Minimal repair direction:** route the convenience method's selected groups
  through the same inventory-based retirement used by
  `MetadataPatch.numberText`, on its existing staged file, or have it delegate
  to the number-text patch path while preserving its verify/formatting options.
  Add both namespaces, both groups, counterpart/foreign/audio preservation and a
  calibration mutant for the omitted retirement. If maintainers decide the
  convenience API is exempt, state that carve-out explicitly in the public
  contract and stop describing it as a normal number edit.

### F-03 — Partial/multi-value malformed private text is used for recovery and then retired

- **Severity:** Medium.
- **Confidence:** Confirmed (reproduced MP4, typed and `numberText` paths).
- **Status:** Open. The typed behavior pre-dates the candidate; the
  `numberText` behavior is a candidate regression from `0.8.0`'s broad
  unresolved-group rejection.
- **API/format/trigger:** `applyMetadataPatch` typed `.track` (or `.disc`) and
  `MetadataPatch.numberText` with a count-only or number-only text, on MP4 where
  the edited group has `trkn 3/0` and one recognized private atom with values
  `["03/12", "garbage"]` or `["03/12", "A1/13"]`.
- **Expected:** a missing native component may be recovered only from
  unambiguous historical evidence. The atom is marked `isStrictlyNumeric ==
  false` because it is multi-valued/malformed; the whole atom is not a clean
  pair. The package's own malformed test rejects a wholly unparseable atom
  (`A1/12`) with byte preservation. The same rule must cover a partially
  parseable/multi-valued atom; otherwise the parseable total is chosen while the
  malformed sibling is silently deleted by retirement.
- **Observed:** the call succeeds, writes `trkn 5/12`, returns
  `warnings == []`, and removes the private atom. At `0.8.0`, the same
  `numberText` input (`"5"`) rejected because the selected group had unresolved
  components; the candidate removed that broad check and the new per-component
  `opaquePair` test only fires when the component state is `.absent`, not when
  the component is `recoveredLegacy` from the non-strict atom.
- **Reproduction:** `PreReleaseAuditTests.partialMalformedPrivateTextMustNotSupplyMissingSibling`
  (two parameter cases, currently failing: expected rejection and unchanged
  bytes, actual durable `5/12` plus retirement). The strict control
  `strictPrivateTextStillRecoversMissingSibling` passes and writes `5/12`.
- **Native evidence:** independent probe shows the private atom disappears and
  `trkn` becomes `[5,12]`; `numberingInventory` reports the total as
  `recoveredLegacy` with `privateTexts[0].isStrictlyNumeric == false`.
- **Release impact:** malformed/opaque historical evidence is guessed and then
  destroyed. This is a silent data-loss class for a non-canonical native layout;
  the write reports durable success. It is exactly the edge the amendment's
  "opaque, malformed, or conflicting missing components must not be guessed"
  rule is meant to cover.
- **Minimal repair direction:** carry per-component provenance from
  `MetadataNumberPrivateTextInventory` into the component resolution; treat a
  recovered component supplied by a non-strict atom as unresolved for automatic
  recovery (unless the caller explicitly supplies/removes it), and apply the
  same rule to the `numberText` number-only total recovery. Add the two
  parameterized regressions, a matching-parseable control, and a calibration
  mutant that makes the partial case parse/recover. Do not simply widen
  `opaquePair` to the whole group without considering cross-component evidence;
  the goal is to reject non-strict evidence for the component being recovered.

### F-04 — Test-gate coverage gaps let a green lane coexist with F-01 to F-03

- **Severity:** Medium.
- **Confidence:** Confirmed by inspection of the declared catalog/scenarios and
  the executed tests, plus the focused reproductions.
- **Status:** Open.
- **Evidence:**
  - `C-MP4-NUMBER-TEXT` declares four scenarios (`S-MP4-NUMTEXT-01..04`):
    facade `"05/12"` on a fresh fixture, bridge `writeTrackNumber(7,12,width:3)`,
    bridge `writeTrackNumberText("9")` on a fresh fixture, and facade `""`
    removal. There is no case with an existing total plus explicit `"5/0"`, no
    disc-zero case, no private-provenance case, no `unchanged`/nil mode (despite
    the declared `number_text: set/remove/unchanged`) and no preservation check
    for an existing total. The exact assertion budgets (4/4/3/4) pass.
  - `AutomaticNumberingTests.numberTextRetiresProvenanceInSameSave` exercises
    `MetadataPatch.numberText`, not `writeTrackNumberText`; the convenience
    contract and the facade-level provenance retirement are not covered.
  - `ordinaryNumberEditsRecoverAndRetireOnlyOwnedGroup` operation 5 (title only)
    uses a `pair()` helper that returns `[0,0]` for an absent atom and excludes
    the pair key from its item loop; it would not fail if the title-only write
    created a `trkn 0/0` atom. The audit's
    `titleOnlyWriteDoesNotCreateOrMigrateNumberPair` checks the stronger
    absence and currently passes, so the production behavior is correct but the
    gate's assertion is weak.
  - `FixtureMetadataRoundTripTests.testM4ABasicNumericEditsRetireOnlyEditedPrivateProvenance`
    and `testM4ANumberPatchRetiresPrivateFormattingWithoutRenamingIt` assert
    that `TAGLIBAUDIOMETADATA_*` identities are nil, but the fixtures seed only
    `AUDIOMATOR_*` identities. Those assertions are vacuous (the separate
    `AutomaticNumberingTests` does seed both prefixes, which limits the coverage
    loss but does not fix the misleading test).
  - The 16-mutant set includes retirement, opaque-sibling and canonical-authority
    faults, but no mutant for the convenience `"5/0"` preserve branch and no
    partial-parse recovery fault. The new `guessed-opaque-number-sibling` mutant
    is killed only by the wholly-unparseable test.
  - Current `STATUS.md`/`TESTING.md`/`MAPPING_TEST_STRATEGY.md` still state 274
    Swift Testing declarations in 51 suites, 92 Python regressions and 13
    calibration mutants for the 0.8.0 lane; the current candidate's accepted
    lane reports 280 in 52, 93 Python regressions and 16 mutants. This is an
    editorial/recency gap, not by itself a production blocker.
- **Impact:** a passing canonical gate is not sufficient evidence for the
  convenience API's explicit-zero semantics, its provenance retirement, or the
  partial-malformed recovery contract. The user-visible failures in F-01 to
  F-03 are real despite the green lane.
- **Repair direction:** add the missing contract scenarios and assertions
  (existing-total explicit zero, disc zero, number-only preserve, private
  retirement both namespaces/both groups, partial-malformed rejection), tighten
  the title-only control to atom absence, seed both namespaces in the fixture
  tests that assert both, add the corresponding calibration mutants, and refresh
  the current counts after the test additions are reviewed.

### F-05 — Basic full-model edits can recover a hidden private total when the model's zero is unchanged

- **Severity:** Low.
- **Confidence:** Confirmed (reproduced MP4).
- **Status:** Bounded / by design consequence, documented here so it is not
  mistaken for the automatic-patch behavior.
- **Trigger:** `trkn 3/0` plus private `03/12`; read Basic (total projects 0);
  set `basic.track = 5` and keep `trackTotal = 0`; call
  `replaceBasicMetadata`. The diff sees no changed total field, so the group is
  edited only by the track field; `automaticNumberValue` recovers the private
  total and writes `5/12`, then retires the private atoms.
- **Why it is not a normal-path defect:** Basic uses the documented "diff the
  normalized model against a versioned snapshot" implementation. The model's
  zero equals the pre-write Basic projection, so it is not an explicit
  replacement; the package's automatic recovery then treats the missing total
  as recoverable. A Basic-only caller who must force zero can use
  `MetadataPatch.numberText`/`writeTrackNumberText` (after F-01 is repaired) or
  `planNumberNormalization`. This is the scalar-projection boundary already
  described in the preserving guide: consumers use the numbering inventory for
  recovered display values. It is still a surprising limitation and should be
  documented next to the Basic API.

### F-06 — Alias ownership boundary: case-lookalike aliases are owned; foreign namespaces survive

- **Severity:** Informational.
- **Confidence:** Confirmed (probed).
- **Status:** Bounded, with the exact policy recorded.
- **Observed:** a `----:com.apple.iTunes:tracktotal` freeform is recognized as
  the track-total alias, recovered and removed when the track group is edited;
  a `----:org.example:TRACKTOTAL` freeform is ignored and preserved; a
  lowercased private provenance description
  (`audiomator_tracknumber_text`) is not one of the four exact identities and is
  preserved. Exact prefix/description membership is used for private
  retirement; no prefix broadening was observed.
- **Why:** the package's PropertyMap alias vocabulary is case-insensitive, so a
  case variant in the canonical namespace is the same owned alias. The four
  private provenance identities are exact and case-sensitive. Foreign
  namespaces are not owned. This matches the current docs and the independent
  probe; the user brief's "case-lookalike keys" requirement is met for private
  provenance, while a case variant of a documented alias is treated as that
  alias. If the intended rule is stricter for aliases, this needs an explicit
  contract change, not a silent implementation change.

### F-07 — ID3 `numberText` explicit zero creates a text the inventory reports invalid

- **Severity:** Low.
- **Confidence:** Confirmed at the text/inventory level; the downstream
  rejection is a source-supported consequence, not a data-loss reproduction.
- **Status:** Risk / cross-contract inconsistency.
- **Observed:** on MP3, `MetadataPatch(numberText: "5/0")` writes `TRCK=5/0`.
  `numberingInventory` then reports the number component as invalid
  (the strict pair parser requires a positive total) and the total as absent,
  while Basic reads the text as `5/0`. A later total-only edit is rejected until
  both components are supplied because the number component is unresolved.
  The text is preserved as requested; no bytes are lost.
- **Impact:** a package-written value is not cleanly round-trippable through the
  package's own inventory, and the user may need an explicit full replacement.
  It does not contradict the MP4 zero-sentinel rules; it is the ID3 text
  representation that is under-specified.
- **Repair direction:** either normalize an explicit zero total on ID3 to the
  canonical number-only text (write `"5"`, not `"5/0"`) or teach the inventory
  and parser to treat a trailing `/0` as an absent total while keeping the
  exact text available. Add MP3/other-ID3 cross-format number-text tests.

### F-08 — Environment: privilege precondition and the authorized rerun

- **Severity:** Environment (not a package defect).
- **Confidence:** Confirmed.
- **Status:** Environment limitation resolved for the recorded lane.
- **Observed:** under the default workspace-write sandbox, `chmod 0o4644`
  yields `0o644` and `chmod 0o2644` yields `0o644`; the unchanged
  `CleanRoomPrivilegeTests.privilegedFilesRejectBeforeCloneInBothTransactionEngines`
  cannot pass its own mode precondition. Under the authorized wider-access
  mode, `chmod 0o4644` yields `-rwSr--r--` and `chmod 0o2644` yields
  `-rw-r-Sr--`, and the unchanged test passes. The canonical lane below was run
  in the authorized mode; its privilege test is a real pass under that mode,
  not a skip or a weakened assertion. A gate run in the default sandbox would be
  red for an environmental reason, not a production failure.

### F-09 — Documentation/release-boundary recency

- **Severity:** Informational.
- **Confidence:** Confirmed.
- **Status:** Bounded; not a standalone production blocker.
- **Observed:** the current status/testing pages still describe the `0.8.0`
  accepted lane's 274/51/92/13 counts and the 0.8.0 release boundary; the
  candidate's accepted lane is 280/52/93/16. The automatic-numbering record's
  baseline line names `e91d822` and its tested revision `e9fb7da`; the tag is
  `9e986eb`, and `959d688` is the source-equivalent accepted tree. The
  automatic-numbering record itself is final for its revision and is not
  rewritten here.
- **Impact:** an engineer reading only the status page could overestimate the
  current evidence. The new record and index row provide the current
  disposition; a separate editorial pass should refresh the counts and release
  boundary when the defects are repaired.

### F-10 — Lower-level surfaces intentionally do not auto-retire; the convenience API is different

- **Severity:** Informational.
- **Confidence:** Confirmed by source and probe.
- **Status:** By design / bounded for the low-level surfaces; F-02 remains open
  for the facade convenience API.
- **Observed:** a low-level full-model `writeTagMetadata` that changes
  `trackNumber`/`totalTracks` leaves private `AUDIOMATOR_TRACKNUMBER_TEXT`
  in place; structured and raw writers likewise preserve unmodeled private
  owner data. The amendment names typed fields, Basic edits and
  `MetadataPatch.numberText` as automatic-retirement surfaces; low-level writes
  are preservation surfaces and are expected to leave unmodeled owners alone.
  `writeTrackNumberText` is a facade-level public number write and is treated as
  a normal number edit by the audit brief, hence F-02. The contrast is important:
  do not "fix" the low-level surfaces by deleting unknown private data, and do
  not use them as evidence that the convenience facade is compliant.

## Repairs or recommendations

No production source was changed by this audit. The defects are reported for a
subsequent repair task. In priority order:

1. Repair F-01 in the Swift recovery predicates, the MP4 and PropertyMap
   preserve branches, and the facade exact-text verification; add cross-format
   track/disc regressions with an existing total and an explicit zero.
2. Repair F-02 by applying the existing group-scoped retirement to the
   convenience entry point in the same transaction; add both-namespace and
   counterpart/foreign/audio assertions.
3. Repair F-03 with per-component opaque provenance and add partial-parse
   rejection plus strict controls.
4. Close the F-04 gate gaps (scenarios, assertion strength, namespace seeding,
   calibration mutants, current counts) after the production repairs are in
   place.
5. Add the F-05, F-06 and F-07 boundaries to the current contract/testing docs
   when the repair branch updates them; do not broaden ownership or normalize
   unrelated fields to make the cases easier.

## Verification

| Check | Result | Counts / limits |
| --- | --- | --- |
| `python3 -m unittest discover -s scripts/tests` | pass | 93 tests; canonical policy set at the candidate |
| `python3 scripts/package_test_system.py` | pass | 907 public-surface rows, 34 contracts, 75 scenarios, 62 adapters, reviewed decisions reconcile |
| `TAGLIB_DISABLE_MANIFEST_SANDBOX=1 TAGLIB_EVIDENCE_ID=pre-release-audit-20261117 bash scripts/validate-contracts.sh debug` (authorized wider-access mode) | **accepted** | 181 XCTest declarations, 179 passed and the two reviewed skips; 280 Swift Testing declarations in 52 suites; 75/75 scenarios; runner exit 0; source hash `051ed48e06d1131cef9d5aa0ccc5e55567cd57d1e9d344bd2235a63243a9f31b`; commit `2df2525`; manifest before/after identical |
| Calibration inside the lane | **accepted, 16/16 killed** | `.build/test-calibration/20261117T101902-8014/calibration.json`; each mutant `build_exit_status=0`, behavioral `named_failure=true`, `restored=true`; control build/run pass; `source_restored=true`; definition hash `d77e700002b9d4322629348948f011dbd91f7a071947b63e6ccf76db8319e9fd` |
| Focused existing numbering tests | pass | `AutomaticNumberingTests` 6 declarations / 21 lifecycle cases / 4 number-text cases; the pre-audit focused run passed |
| Focused audit regressions after test additions | **fail as reproduced** | `PreReleaseAuditTests` at test commit `b4d6b2b`, with production source at `2df2525`: 10 declarations, 12 issues: `convenienceNumberTextExplicitZeroIsAuthoritative` 3 (m4a/flac/ogg; mp3 control passes), `convenienceDiscExplicitZeroIsAuthoritative` 3 (m4a/flac/ogg), `convenienceNumberTextRetiresEditedGroupProvenance` 2 (both private identities remain), `partialMalformedPrivateTextMustNotSupplyMissingSibling` 4 (two parameter cases × throw + byte-equality). The 3-case `metadataPatchNumberTextExplicitZeroIsAuthoritative`, strict-evidence, title-only, read-stability, zero-component and full-replacement controls pass. Log: `.build/pre-release-audit-regressions-final.log` (runner exit 1, as expected before repair). |
| `python3 scripts/check-docs.py` | pass | 70 Markdown files; link/heading/table/generated-reference checks |
| `bash scripts/validate-consumers.sh` | pass | Both `TagLibAudioMetadataConsumer` and `TagLibAudioMetadataLowLevelConsumer`; real facade/bridge writes, independent native/audio/stale checks; log `.build/pre-release-audit-consumers.log` |
| Focused AddressSanitizer | pass | `swift test --sanitize=address --filter AutomaticNumberingTests`: 6 declarations, 21 lifecycle cases, 4 number-text cases; no sanitizer finding; log `.build/pre-release-audit-asan.log`; pinned TagLib binary uninstrumented |
| Focused ThreadSanitizer | pass | Same filter/counts; no sanitizer finding; log `.build/pre-release-audit-tsan.log`; same binary limit |
| Minimum-platform Debug builds | pass (5/5) | macOS 13 arm64/x86_64, iOS 16 arm64, iOS 16 simulator arm64/x86_64; `swift build --triple ... --sdk ...` with the installed Xcode SDKs; logs `.build/pre-release-audit-platform-*.log` |
| Release lane | not run | Excluded by instruction |
| Hosted CI, device runtime, external corpus | not run | Not available/authorized in this campaign |
| Privilege test | pass under authorized mode; default sandbox precondition fails | `chmod` probe above; unchanged test passed in the focused run and in the canonical lane |

### Canonical lane acceptance JSON

```json
{
  "accepted": true,
  "runner_exit_status": 0,
  "framework_errors": [],
  "manifest_errors": [],
  "calibration_errors": [],
  "scenario_errors": [],
  "xctest_executed": 181,
  "xctest_skipped": 2,
  "xctest_failures": 0,
  "swift_testing_declarations": 280,
  "swift_testing_suites": 52,
  "swift_testing_result": "passed",
  "scenario_expected_count": 75,
  "scenario_observed_count": 75,
  "campaign_manifest_commit": "2df252584aa12c3d0e5a088da8cb24a44b99197b",
  "campaign_source_hash": "051ed48e06d1131cef9d5aa0ccc5e55567cd57d1e9d344bd2235a63243a9f31b",
  "calibration_source_hash": "051ed48e06d1131cef9d5aa0ccc5e55567cd57d1e9d344bd2235a63243a9f31b",
  "unexpected_skips": [],
  "missing_required_tests": [],
  "missing_required_xctest": [],
  "missing_required_suites": [],
  "failed_named_tests": [],
  "failed_xctest_names": [],
  "source_inventory_errors": []
}
```

The before/after manifests carry the same commit, branch, toolchain, SDK,
build options and source hash. The canonical lane's outer log ends with
`GATE_EXIT:0`. The calibration JSON records `acceptance: "accepted"`,
`source_restored: true`, and 16 killed mutants; the per-mutant records show
`build_exit_status: 0`, `named_failure: true` and a behavioral activation
witness (for example the omitted-retirement mutant fails the native
`after.items[identity] == nil` assertion rather than failing to compile).

### Framework results

- XCTest: `Executed 181 tests, with 2 tests skipped and 0 failures`.
  The two skips are exactly
  `ExternalCorpusPreservationTests.testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus`
  and
  `SnapshotThroughputBenchmarkTests.testOptInIndependentFileSnapshotThroughput`;
  no other skip was accepted.
- Swift Testing: `Test run with 280 tests in 52 suites passed after 167.204
  seconds`; the summary records 280 declarations, 52 suites and
  `swift_testing_result: "passed"`.
- Scenarios: 75 expected / 75 observed with an empty `scenario_errors` list;
  the per-scenario records are under
  `.build/test-evidence/debug-pre-release-audit-20261117/scenarios/`.
- Runner: exit status 0, all framework/manifest/calibration/scenario error
  arrays empty.
- Focused audit regressions (added after the baseline lane): 10 declarations,
  12 recorded issues as itemized in the verification table. The focused runner
  exit status was 1; those failures are the reproduction evidence for F-01 to
  F-03 and are not a claim that the final audit branch passes the canonical
  lane. The production source was not changed after the accepted baseline lane;
  the audit branch adds tests and records only.

## Remaining limitations

- Release was not built or tested. No claim is made about Release performance,
  optimization, signing, or Release-only diagnostics.
- The pinned TagLib binary is not sanitizer-instrumented; ASan/TSan findings
  cover package Swift/Objective-C++ and test code only.
- The independent MP4/FLAC/Ogg/ID3 probes are deliberately bounded test oracles,
  not a general media parser or universal codec conformance proof. Audio
  comparisons are `mdat`/Vorbis packet payload comparisons; they do not establish
  every container structure or decoder behavior.
- No hosted CI, device, minimum-OS runtime, external decoder, or embedding
  application was executed. Minimum-platform builds are compile/link checks, not
  runtime evidence.
- Duplicate private freeform atoms could not be seeded through the package's
  structured writer (the seed itself failed verification); the duplicate
  identity path is source-reviewed and the inventory's duplicate handling is not
  independently exercised here. The multi-value partial case is reproduced.
- Performance was not benchmarked in this campaign (the repository benchmark is
  opt-in and Release-oriented, and Release is excluded). Source inspection found
  no new per-read extraction, extra clone, retry, global serialization or sticky
  failure cache on the changed paths; the convenience ambiguity path stages
  before rejecting, unlike the patch number-text preflight. No timing claim is
  made.
- The application repository was deliberately not used. This record does not
  establish any application integration, dirty-state behavior, UI mapping,
  signing, rpath, or entitlement behavior.
- The record is final for the candidate revision and the executed scope. It does
  not claim that every format, field, malformed layout or public caller was
  exercised.

## References

- Candidate: `2df252584aa12c3d0e5a088da8cb24a44b99197b` ("chore: merge automatic
  numbering recovery"); prior source: `0.8.0` at
  `9e986eb7bf4f019949d17cc1e117334793b5f932`; accepted source
  `959d68854db600a5726b6b9cb9c05018b9335f22`; previous automatic-numbering
  tested source `e9fb7da16e793d78d3a8460f7790b61dc8d26016`.
- Production paths: `Sources/TagLibAudioMetadata/MetadataNumberInventory.swift`,
  `Sources/TagLibAudioMetadata/MetadataSnapshotPatch.swift`,
  `Sources/TagLibAudioMetadata/TagLibMetadataManager+Write.swift`,
  `Sources/CTagLibBridge/Internal/TLRawBridgeOperations.inc`,
  `Sources/CTagLibBridge/Internal/TLPropertyMapWrites.inc`,
  `Sources/CTagLibBridge/Internal/TLPropertyMapCodec.inc`.
- Tests: `Tests/TagLibAudioMetadataTests/Integration/PreReleaseAuditTests.swift`
  (audit regressions), `AutomaticNumberingTests.swift`,
  `FixtureMetadataRoundTripTests.swift`, `IndependentAcceptanceProbes.swift`,
  `ContractSystem/ContractMP4ScenarioTests.swift`,
  `ContractSystem/PublicSurfaceAdapters.swift`.
- Catalog/evidence: `scripts/package-test-system/contract-catalog.json`
  (`C-MP4-NUMBER-TEXT`, `C-MP4-NUMBER-TEXT-INVALID`),
  `scripts/package-test-system/scenario-assertions.json`,
  `scripts/calibration-mutants.json`, `scripts/required-test-inventory.json`.
- Evidence directories: `.build/test-evidence/debug-pre-release-audit-20261117/`,
  `.build/test-calibration/20261117T101902-8014/calibration.json`,
  `.build/pre-release-audit-gate.log` (outer lane log).
- Current contracts: [Testing and verification](../../operations/TESTING.md),
  [Mapping test acceptance](../../operations/MAPPING_TEST_STRATEGY.md),
  [Numbering inventory and preservation](../../explanation/PRESERVATION.md),
  [Mapping specification](../../reference/MAPPING_SPEC.md),
  [Writing guide](../../guide/WRITING.md).
- Related records: [REM-2026-11-16-automatic-numbering](../remediation/REM-2026-11-16-automatic-numbering.md),
  [REM-2026-11-15-test-system-acceptance](../remediation/REM-2026-11-15-test-system-acceptance.md),
  [VER-2026-11-15-package-test-system](../verification/VER-2026-11-15-package-test-system.md),
  [AUD-2026-11-11-package-audit](./AUD-2026-11-11-package-audit.md).
