# Numbering-contract repairs and final Debug acceptance

| Field | Value |
| --- | --- |
| Record ID | `REM-2026-11-17-numbering-contract-repairs` |
| Type | Remediation / verification |
| Date | `2026-11-17` |
| Status | Final, package-only Debug acceptance |
| Examined revision | Base `0414154a21699b24ab85e1e83814c74cf8a6211b`; accepted source `558df00db502044e23d9935aa0b9fb328f237369` on `codex/numbering-contract-repairs-20261117` |
| Source identity | `5cbc2ba2b6030751e624dc5f523fd6352ce9ac46e726c753e71df68ebb9b1032`; manifest before/after identical; tracked-diff hash empty |
| Environment | macOS 27.2.1 (26B131), arm64; Xcode 27.2 (27B52); Swift 6.4.2; TagLib 2.3.1-r2 (SwiftPM checksum `d7a36b2492266a17fcd97bd776cd841d9fc85275270bc0c3cb9621395b3178c7`) |
| Supersedes | The open dispositions F-01, F-02, F-03, F-04 and F-07 in `AUD-2026-11-17-pre-release` |
| Related records | `AUD-2026-11-17-pre-release`, `REM-2026-11-16-automatic-numbering`, `REM-2026-11-15-test-system-acceptance` |

## Verdict

The repaired candidate is accepted for the package-only **Debug** contract campaign
on the source commit above. The audit defects F-01 (explicit zero ignored by the
convenience/direct-bridge surfaces), F-02 (convenience provenance not retired),
F-03 (opaque partial private recovery), F-04 (gate coverage gaps) and F-07 (ID3
explicit-zero inventory rejection) are closed. F-05 (Basic unchanged-zero
semantics) and F-06 (exact alias ownership boundary) are retained as documented
boundaries. F-10's low-level preservation rule is retained.

The final gate accepted **181 XCTest declarations** (179 passed, the same two
reviewed opt-in skips), **306 Swift Testing declarations in 55 suites**,
**81/81 contract scenarios**, **97 Python policy regressions** and
**23/23 killed calibration mutants**. Both package-owned consumers, focused
AddressSanitizer and ThreadSanitizer lanes, and all five minimum-platform Debug
builds passed. No Release lane, application repository, push, PR, merge, tag,
publication or binary/dependency change was performed.

## Finding dispositions

| Finding | Disposition | Evidence |
| --- | --- | --- |
| F-01 explicit zero ignored | **Closed.** Presence is intent: only an omitted total resolves, while `/0` and an empty total are explicit zero. The Swift preflight, MP4 native branch and PropertyMap branch all use slash presence. | `explicitIntentMatrix` (60 cells), `explicitIntentFacadeVerificationDisabled` (30 cells), direct-bridge cells across all five formats, `explicitZeroTotalIsNotRecoveredFromOldNumberText`, contract `C-MP4-NUMBER-INTENT` |
| F-02 convenience provenance not retired | **Closed.** The facade resolves and stages first, writes the selected numeric pairs and text, then retires exactly the selected groups' four recognized private identities in the same transaction. A selected track is retired even when its numeric value is unchanged; `nil` disc leaves the disc group unselected. | `convenienceNumberTextRetiresEditedGroupProvenance`, `convenienceRetiresBothSelectedGroupsAndPreservesOthers`, `convenienceTrackSelectionRetiresEvenWhenValueUnchanged`, `facadeAndPatchUseOneStage`, `facadeDoesNotCreatePrivateAtoms` |
| F-03 opaque partial/multi-value private recovery | **Closed.** Non-strict private evidence is group-level opaque: it cannot supply a missing canonical component. Valid native components remain authoritative. Inventory reads report `.ambiguous` with `recoveredValue == nil`; typed and number-text writes reject before staging with `ambiguousNumberRecovery`; explicit full replacement still succeeds. | `opaquePrivateEvidenceIsNotRecovered` (both malformed arrays), `partialMalformedPrivateTextMustNotSupplyMissingSibling`, `canonicalNativeTotalBeatsOpaquePrivateEvidence`, `malformedNumberTextCannotEraseExistingPairs`, contract `S-MP4-INTENT-03` |
| F-04 gate coverage gaps | **Closed.** Added the 60-cell facade/bridge intent matrix, the 30-cell verification-disabled matrix, recovery/opaque/retirement/ID3 sequences and transaction/native/audio controls. Bound the new declarations and case minima into both required-test inventories and the summary floor. Added new contract/audit scenario checks, exact assertion budgets, six declared scenario IDs, two runtime tests, and seven new targeted calibration mutants. | `NumberingContractRepairTests`, `ContractNumberIntentTests`, `contract-catalog.json`, `scenario-assertions.json`, `runtime-invocations.json`, `required-test-inventory.json`, `summarize-test-run.py`, `calibration-mutants.json`, `test_test_gate.py` |
| F-07 ID3 explicit-zero text rejected by inventory | **Closed.** Inventory parsing accepts a zero total from `TRCK`/`TPOS`, reads a package-written `5/0` as number 5 with total absent, preserves the literal text on unrelated edits, and supports a subsequent total-only edit (`5/15`). Zero-padded `05/00` follows the same path. | `id3ExplicitZeroReopensAndAllowsTotalOnlyEdit` (track/disc), `id3ZeroPaddedExplicitZeroRoundTrips`, contract `C-ID3-NUMBER-INTENT` |
| F-05 Basic unchanged-zero semantics | **Retained and unchanged.** A Basic full-model edit that leaves an already-zero total unchanged is not clear intent and can still recover eligible private evidence. Use typed/number-text/convenience/normalization when a clear is intended. | Existing Basic/numbering suites remain green; no Basic behavior was changed |
| F-06 exact alias ownership | **Retained.** Only the four exact `com.apple.iTunes` identities are owned. Foreign namespaces, case-lookalikes and unrelated multi-value atoms survive selected-group retirement. | `convenienceRetiresBothSelectedGroupsAndPreservesOthers`, `contractPrivateProvenance` |
| F-10 low-level preservation | **Retained.** Direct bridge/raw/structured/full-model writes preserve unmodeled private owners; only the facade convenience API retires selected exact provenance. | `lowLevelBridgePreservesUnmodeledPrivateOwners`, `contractNumberIntentAndRetirement` S-MP4-INTENT-02 |
| F-08 environment | The canonical lane ran with authorized wider access so the unchanged privilege test could establish setuid/setgid modes. The test passed without weakening or skipping. | Full gate and `CleanRoomPrivilegeTests` |
| F-09 documentation recency | This record, the audit status, index and current validation page now distinguish the historical failing audit from the repaired accepted candidate. | This record and the documentation checks |

## Native outcomes

The assertions below use fresh fixture copies and the independent test readers;
they are not production-reader readback. The matrix seeds track `3/12` and disc
`1/12`; disc cells supply a consistent track `3/12` while editing the disc. The
requests are `5` (omitted total), `5/0` (explicit zero) and `5/15` (positive
total). Disc cells use number `1` with the same three totals.

| Format / native owner | Omitted total | Explicit `n/0` | Explicit `n/15` |
| --- | --- | --- | --- |
| MP4 `trkn` / `disk` | pair `n/12`; existing total preserved | pair `n/0`; zero is present in the native pair | pair `n/15` |
| ID3 `TRCK` / `TPOS` | text `n/12` | text `n/0`; inventory number `n`, total absent | text `n/15` |
| FLAC `TRACKNUMBER`/`TRACKTOTAL`, `DISCNUMBER`/`DISCTOTAL` | number `n`, total `12` | number `n`, total key removed | number `n`, total `15` |
| Ogg Vorbis comments | same as FLAC | same as FLAC | same as FLAC |
| WavPack/APE `TRACK`/`TRACKTOTAL`, `DISC`/`DISCTOTAL` | number `n`, total `12` | number `n`, total item removed | number `n`, total `15` |

The direct exported bridge and the Swift facade produce the same outcomes. The
verification-disabled facade matrix produces the same native outcomes without
claiming warnings. `5/0` never recovers the old `12`; a later read or unrelated
edit does not resurrect it. The ID3 literal `5/0` is preserved until a later
total-only edit, which writes `5/15` and retains number `5`.

## Matrices and controls

- **A — explicit intent, 60 cells:** five formats (`m4a`, `mp3`, `flac`, `ogg`,
  `wv`) × two surfaces (facade, direct bridge) × two groups (track, disc) ×
  three requests (omitted total, explicit zero, positive total), seeded over an
  existing total. Each cell checks the edited group, the untouched group and
  audio equality.
- **B — verification disabled, 30 cells:** the same five formats × two groups ×
  three requests through the facade with `verifyAfterWrite: false`; native
  outcomes are identical to A.
- **C — recovery/opaque/retirement/ID3 sequences:** strict single-value
  recovery for both groups, matching and conflicting namespaces, opaque
  multi-value and cross-namespace malformed evidence, exact error identity,
  byte equality on rejection, selected-group retirement, unchanged-value
  selection, `nil`-disc non-selection, one-stage patch/facade saves, full
  replacement over ambiguity, ID3 track/disc `5/0` reopen + title-only
  preservation + total-only follow-up, and zero-padded ID3 text.
- **D — controls:** title-only writes do not create or migrate a pair; reads do
  not mutate bytes or versions; direct bridge writes preserve unmodeled private
  owners; foreign/case-lookalike/unknown atoms survive; no private atoms are
  created; malformed and stale writes leave bytes unchanged.

The audit regressions remain ten declarations with their controls. The repair
suite contributes fourteen declarations and 105 parameterized cases; the new
contract suite contributes two declarations and six scenarios. The full suite's
306 declarations are not a claim that every possible file or caller is covered.

## Gate and bounded verification

| Check | Result | Evidence |
| --- | --- | --- |
| Policy and inventory | **Pass**, 97 policy regressions; 907 public-surface rows, 36 contracts, 81 scenarios, 62 adapters reconcile | `.build/numbering-repairs-accepted2-gate.log` |
| Calibration | **23/23 killed**, control build/run pass, all restorations true, `source_restored: true`; definition hash `06ad6129f5093a39cdc29f2c1282a232eb5486f404310e43dde6f55659d75539` | `.build/test-calibration/20261117T122517-35984/calibration.json` |
| Canonical strict Debug gate | **accepted: true**; 181 XCTest (179 passed, two reviewed opt-in skips), 306 Swift Testing declarations in 55 suites, 81/81 scenarios, no named failures, no unexpected skips; exit 0 | `.build/test-evidence/debug-numbering-repairs-accepted2-20261117/` |
| Manifest identity | Commit `558df00db502044e23d9935aa0b9fb328f237369`; source hash `5cbc2ba2b6030751e624dc5f523fd6352ce9ac46e726c753e71df68ebb9b1032`; before/after identical; empty tracked diff; clean status | `manifest-before.json`, `manifest-after.json`, `summary.json` |
| Consumers | **Pass**: facade consumer and low-level consumer both wrote real files and passed independent native/audio/stale checks | `.build/numbering-repairs-consumers.log` |
| Focused ASan | **Pass**: 26 tests in 3 suites, no sanitizer findings | `.build/numbering-repairs-asan.log` |
| Focused TSan | **Pass**: 26 tests in 3 suites, no sanitizer findings | `.build/numbering-repairs-tsan.log` |
| Minimum platforms | **5/5 pass**: macOS 13 arm64/x86_64, iOS 16 device arm64, iOS 16 simulator arm64/x86_64; strict Debug builds | `.build/platform-macos13-arm64.log`, `.build/platform-macos13-x86_64.log`, `.build/platform-ios16-arm64.log`, `.build/platform-ios16-sim-arm64.log`, `.build/platform-ios16-sim-x86_64.log` |
| Documentation | Link/heading/table/generated-reference checks | `python3 scripts/check-docs.py` |

The accepted source commit is `558df00`. The record/index/status edits that
follow it are documentation-only; they do not change `Sources/`, `Tests/` or
`scripts/`. The worktree was clean before the gate and at this record's source
checkpoint. The two XCTest opt-in skips are the existing external-corpus and
snapshot-throughput skips; no new skip was accepted.

## Remaining limitations

- This is a package-only **Debug** acceptance. No Release build or Release test
  lane was run; no signing, optimization, release diagnostic or publication
  claim is made.
- The pinned TagLib binary is not sanitizer-instrumented. ASan/TSan cover package
  Swift/Objective-C++ and test code only.
- The independent probes are bounded test oracles, not general media parsers.
  Audio comparisons use `mdat`/packet payloads and the retained probes; they do
  not prove every codec, container layout or decoder behavior.
- Minimum-platform builds are compile/link checks, not device or minimum-OS
  runtime evidence. No hosted CI, application repository, external decoder or
  embedding application was used.
- The contract system is finite. The 23 mutants demonstrate detection of the
  reviewed defect classes; they do not prove every future defect is caught.
- F-05 and F-10 remain deliberate boundaries; they were not changed by this
  repair.

## References

- Base: `0414154a21699b24ab85e1e83814c74cf8a6211b`; accepted source:
  `558df00db502044e23d9935aa0b9fb328f237369` on
  `codex/numbering-contract-repairs-20261117`.
- Production paths: `Sources/TagLibAudioMetadata/MetadataNumberInventory.swift`,
  `MetadataSnapshotPatch.swift`, `TagLibMetadataManager+Write.swift`;
  `Sources/CTagLibBridge/Internal/TLRawBridgeOperations.inc`,
  `TLPropertyMapWrites.inc`.
- Tests: `Tests/TagLibAudioMetadataTests/Integration/NumberingContractRepairTests.swift`,
  `PreReleaseAuditTests.swift`, `FixtureMetadataRoundTripTests.swift`,
  `Tests/TagLibAudioMetadataTests/ContractSystem/ContractNumberIntentTests.swift`,
  `ContractScenarioDeclarations.swift`.
- Gate data: `scripts/calibration-mutants.json`,
  `scripts/package-test-system/contract-catalog.json`,
  `scenario-assertions.json`, `runtime-invocations.json`,
  `public-surface-inventory.json`, `scripts/required-test-inventory.json`,
  `scripts/summarize-test-run.py`, `scripts/tests/test_test_gate.py`.
- Evidence: `.build/test-evidence/debug-numbering-repairs-accepted2-20261117/`,
  `.build/test-calibration/20261117T122517-35984/calibration.json`,
  `.build/numbering-repairs-accepted2-gate.log`.
- Related: [AUD-2026-11-17-pre-release](../audits/AUD-2026-11-17-pre-release.md),
  [REM-2026-11-16-automatic-numbering](REM-2026-11-16-automatic-numbering.md),
  [REM-2026-11-15-test-system-acceptance](REM-2026-11-15-test-system-acceptance.md),
  [Testing](../../operations/TESTING.md),
  [Status](../../operations/STATUS.md).
