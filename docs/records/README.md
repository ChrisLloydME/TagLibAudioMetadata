# Engineering records index

This directory is the durable archive for audits, independent reviews, remediation work, verification campaigns, migrations, and maintenance investigations. It is deliberately separate from the current technical documentation under `docs/`.

- **Current documentation** describes the code at the branch or release you are reading. Start at [the documentation hub](../README.md).
- **Engineering records** describe what was examined, when, at which revision, what was found, and what happened next. They are evidence, not current contracts.

Historical records are retained unchanged apart from relative-link repair after relocation. A record's conclusions are not automatically current. The status table below is the authoritative interpretation of how much confidence to place in each record today.

## How to use this index

1. Find the investigation in [the investigation index](#investigation-index).
2. Read its **current relevance** and the linked record.
3. For a disputed or material finding, follow the cross-reference to the remediation or verification record that addressed it.
4. Check [open and bounded findings](#open-and-bounded-findings) before treating an old conclusion as resolved.
5. Check [docs/STATUS.md](../STATUS.md) for the latest known validation state of the current branch.

Do not cite an old record's "fixed", "ready", or test-count statement as evidence about the current HEAD without checking the later records and current source.

## Reading historical paths

Records were written before the 2026-10-19 documentation restructuring. They may cite former paths such as `docs/SUPPORT.md`, `docs/THREAD_SAFETY.md`, or `MAINTENANCE_PROGRESS.md` in prose. Those are historical coordinates, not current links. Markdown link targets were repaired after relocation; prose path references were intentionally left unchanged so the original evidence is not rewritten. Use the index and the current [documentation hub](../README.md) to find the present location.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| Current | Maintained documentation for the current code. Not stored in this archive. |
| Final | The record is complete and immutable for its stated scope. Its findings may still be historical. |
| Historical | Describes a past revision, branch, or release. Retained as evidence; not a current assessment. |
| Superseded | A later record replaces its conclusions. The original is preserved. |
| Withdrawn | The author retracted the record's conclusions. |
| Open | An actionable gap remains, or the claim has not been resolved. |
| Bounded | A real limitation is intentional and documented; it is not a silent defect. |
| Unknown | Evidence is insufficient to classify the finding confidently. |

## Investigation index

| Record ID | Date | Type | Examined revision / branch | Current relevance | Findings and outcome |
| --- | --- | --- | --- | --- | --- |
| [AUD-2026-10-18-independent-technical-audit](#local-only-original-audit) | Not recorded (input to the 2026-10-18 remediation) | Independent audit | `03473c9` on `main`, tags through `0.5.3` | Historical; superseded by later remediation and review records. Local-only working-tree file at `.local/audits/`; not tracked. | 64 findings: 22 production, 12 public-API, 15 test, 15 documentation. Remediation and review records classify all 64. |
| [REM-2026-10-18-comprehensive-audit](remediation/REM-2026-10-18-comprehensive-audit.md) | 2026-10-18 | Remediation | `fix/comprehensive-audit-remediation`, based on `03473c9` | Historical. Its self-assessment was too broad in places; [REV-2026-10-18](reviews/REV-2026-10-18-post-remediation.md) independently found 21 additional defects. | 22 P findings (17 fixed, 1 partial, 4 improved), 12 A, 15 T, 15 D. Complete matrix in the record. |
| [REV-2026-10-18-post-remediation](reviews/REV-2026-10-18-post-remediation.md) | 2026-10-18 | Independent review | `review/comprehensive-remediation-verification`, based on remediation HEAD `62504ff`; final tested source `1e8fb35` | Historical. It supersedes the remediation's self-assessment where they conflict. Later clean-room work supersedes its merge-readiness statement for the current HEAD. | Independently classified all 64 original findings and added IV-01 through IV-21. Final verdict: READY WITH CAVEATS, no reproduced merge blocker in the reviewed scope. |
| [VER-2026-10-18-verification-hardening](verification/VER-2026-10-18-verification-hardening.md) | 2026-10-18 | Verification campaign | `review/verification-hardening`, based on the prior review HEAD `737dd07`; final tested source `98b17dc` | Historical. Superseded for current status by later records and `docs/STATUS.md`. | VH-01 through VH-03 repaired. 186 tests at that revision. Genuine DSD/APE/Musepack fixtures and independent ASF/audio checks added. Verdict: READY WITH CAVEATS. |
| [AUD-2026-10-19-clean-room](audits/AUD-2026-10-19-clean-room.md) | 2026-10-19 | Independent clean-room audit | `review/verification-hardening` at `615bc8c` | Historical. Its NOT READY verdict was the input to REM-2026-10-19. | AUD-01 through AUD-20: five high-severity integrity findings and related medium/low findings. Verdict: NOT READY TO MERGE. |
| [REM-2026-10-19-clean-room](remediation/REM-2026-10-19-clean-room.md) | 2026-10-19 | Remediation | `fix/clean-room-audit-remediation`, based on `615bc8c`; final implementation `1fff9f0` | Historical. It supersedes the clean-room audit's dispositions. Superseded for current status by the audio-identity work and `docs/STATUS.md`. | All 20 AUD findings fixed or explicitly bounded. 208 tests at that revision. Verdict: READY WITH CAVEATS; merge recommendation yes at that revision. |
| [AUD-2026-10-19-audio-content-identity](audits/AUD-2026-10-19-audio-content-identity.md) | 2026-10-19 | Independent audit | `fix/audio-content-continuity` at `873cb3e`, based on `1310e4f` | Historical. F1 was fixed after the audit by `bedd725` (merged in `d40f7f9`). F2/F3 remain limitations; F4/F5 were partially addressed. | F1 through F8. F1 BWF/iXML relocation fixed; F2/F3 open limitations; F4 documentation corrected; F5 partially closed; F6/F7 informational; F8 no defect found. Verdict: READY WITH CAVEATS, conditional. |
| [MIG-2026-09-01-taglib-2.3.1](migrations/MIG-2026-09-01-taglib-2.3.1.md) | 2026-09-01 | Migration report | TagLib 2.3.1-r2 migration | Historical validation snapshot. Current migration guidance is [docs/MIGRATION.md](../MIGRATION.md). | Binary identity, slices, ABI boundary, and migration decisions. Test counts are period evidence, not current health. |
| [MAINT-2026-10-19-progress-log](maintenance/MAINT-2026-10-19-progress-log.md) | 2026-10-19 (covers 2026-09-21 through 2026-10-19) | Maintenance log | Multiple branches and revisions; see the record | Historical. Superseded by `docs/STATUS.md` for current validation state. | Chronological maintenance notes, validation summaries, and commit lists. The "current task" heading inside it is historical, not current. |
| [DOC-2026-10-19-documentation-restructure](documentation/DOC-2026-10-19-documentation-restructure.md) | 2026-10-19 | Documentation record | `docs/documentation-architecture-restructure` | Historical. Superseded as a current owner map by `DOC-2026-10-21`. | Previous documentation problems, then-current architecture, record system, corrections, verification, and commits. |
| [DOC-2026-10-21-documentation-reconstruction](documentation/DOC-2026-10-21-documentation-reconstruction.md) | 2026-10-21 | Documentation record | `e31030d` working tree | Historical. Its owner map was current for that pass; `DOC-2026-10-24` adds the missing reference layer and supersedes its current-owner role. | Rebuilt the owner map and API index, corrected WAV/format/bridge guidance, moved the prior report, added the docs check, and refreshed status. |
| [DOC-2026-10-24-documentation-completion](documentation/DOC-2026-10-24-documentation-completion.md) | 2026-10-24 | Documentation record | `fefdb88` production source; documentation-only working tree | Final for its revision. The current reference layer is in [docs/API_REFERENCE.md](../API_REFERENCE.md), [docs/FIELD_SCHEMA.md](../FIELD_SCHEMA.md), and [docs/BRIDGE.md](../BRIDGE.md). Production behavior unchanged. | Added generated field schema and bridge references, completed the Swift API index, rewrote the current topic documents, extended the docs check, and refreshed status. |
| [REM-2026-10-25-pre-release-assessment-repairs](remediation/REM-2026-10-25-pre-release-assessment-repairs.md) | 2026-10-25 | Remediation | `fix/pre-release-assessment-f01-f02`, based on `32d945d`; repair `102ddc7` | Final for its revision. Closes the external pre-release assessment's F-01 and F-02. F-01 is resolved by requiring Swift 6.4; F-02 by a release-based changelog rewrite. | Raised the minimum Swift tools from 6.0 to 6.4 after 6.0.3, 6.2.4, and 6.3 could not import SDK 27 modules; rewrote the changelog around version deltas. Swift 6.4 Xcode, Debug, Release, ASAN, TSAN, strict, platform, and consumer checks passed. |

### Local-only original audit

The 2026-10-18 independent audit is stored in the maintainer's local working tree at `.local/audits/AUD-2026-10-18-independent-technical-audit.md`. The `.local/` directory is ignored by Git (`.gitignore` and `.git/info/exclude`) and is not part of a clean clone, so this is a local coordinate rather than a repository link. Historical records still refer to its former root path `AUDIT_REPORT.md`; treat that as a historical coordinate, not a current file location. The audit is indexed here because later records treat it as evidence.

## Finding disposition summary

This table is a map, not a replacement for the records' complete matrices. "Claimed fixed" means a later record presents source and test evidence; this documentation pass did not independently re-run every historical reproduction.

| Source record | Finding range | Disposition | Where the detail lives |
| --- | --- | --- | --- |
| AUD-2026-10-18 | P-01..P-22, A-01..A-12, T-01..T-15, D-01..D-15 | Classified by REM-2026-10-18; 21 further defects and incomplete repairs found by REV-2026-10-18. | Complete matrices in both records. |
| REV-2026-10-18 | IV-01..IV-21 | All 21 have corrective repairs and regression coverage recorded. Not independently revalidated in this pass. | REV-2026-10-18 sections C and D. |
| VER-2026-10-18 | VH-01..VH-03 | Fixed, with focused regressions. | VER-2026-10-18 section D. |
| AUD-2026-10-19 clean-room | AUD-01..AUD-20 | Fixed or bounded; complete matrix in the remediation record. | REM-2026-10-19 section B. |
| AUD-2026-10-19 audio identity | F1..F8 | F1 fixed; F2/F3 open limitations; F4 corrected; F5 partially closed; F6/F7 informational; F8 no defect. | This index and the audit record. |
| External pre-release assessment 2026-10-25 | F-01..F-02 | Both repaired. F-01 is closed by raising the minimum to Swift 6.4 after older-toolchain and SDK-import probes; F-02 by replacing dated work sections with release-based deltas. | REM-2026-10-25. |

## Selected cross-record findings

| Finding | Source | Summary | Current status | Evidence |
| --- | --- | --- | --- | --- |
| P-01 / A-01 / D-01 | AUD-2026-10-18 | Structured property writes replaced the whole PropertyMap and deleted omitted metadata. | Fixed: structured properties are deltas; non-empty properties require `includeProperties`. | REM-2026-10-18, regression tests in `FixtureMetadataRoundTripTests` and `AuditRemediationRegressionTests`. |
| P-02 / IV-04 | AUD-2026-10-18 / REV-2026-10-18 | Basic read-modify-write truncated full recording dates; the first repair lost secondary date values. | Fixed in the review; covered by date-preservation tests. | REM-2026-10-18 and REV-2026-10-18 sections C/D. |
| P-05 / IV-08 | AUD-2026-10-18 / REV-2026-10-18 | APIC/COMM/USLT frame edits could report success without writing the payload. | Fixed: collection frames are rejected in `id3v2Frames`; dedicated artwork/comment/lyrics APIs own them. | REM-2026-10-18, `AuditRemediationRegressionTests`, `ReviewMetadataIntegrityTests`. |
| P-07 / A-02 | AUD-2026-10-18 | Whole-map raw replacement is not a native archive. | Bounded and documented: use `.merge` or `RawMetadataPatch` for preservation. | Current [USAGE](../USAGE.md) and [PRESERVATION](../PRESERVATION.md). |
| P-09 / IV-20 | AUD-2026-10-18 / REV-2026-10-18 | Number pairs were split or stale totals survived on some writers. | Fixed across the supported native ID3 families. Generic/Xiph display normalization remains bounded. | `CleanRoomID3Tests`, `FixtureMetadataRoundTripTests`. |
| P-18 / A-08 | AUD-2026-10-18 | Several write surfaces lacked an optimistic-concurrency token. | Fixed: structured, raw whole-map, and `writeTagMetadata` accept `expectedVersion`. | REM-2026-10-18 matrix; current API signatures. |
| IV-01 | REV-2026-10-18 | Omitted structured artwork was deleted by APE/ASF writes. | Fixed; omitted artwork is preserved. | `ReviewMetadataIntegrityTests`, `ReviewNativeContainerTests`. |
| IV-03 | REV-2026-10-18 | Unchanged native comment/lyric language and description were rewritten. | Fixed for the tested ID3-backed families. | `ReviewMetadataIntegrityTests`, `CleanRoomID3Tests`. |
| AUD-01 | AUD-2026-10-19 clean-room | MP4 freeform Patch and Basic writes could disagree and report false verified success. | Fixed: schema-native keys, alias cleanup, semantic readback verification. | `CleanRoomMP4Tests`, REM-2026-10-19. |
| AUD-02 | AUD-2026-10-19 clean-room | Qualified ID3 comment/lyric collection removal no-oped or partially removed. | Fixed: scalar Patch owns the represented collection; raw patches stay key-specific. | `CleanRoomID3Tests`. |
| AUD-03 | AUD-2026-10-19 clean-room | First ID3v2 write on an ID3v1-only MPEG file hid legacy fields. | Fixed: visible legacy map is promoted before creating ID3v2. | `CleanRoomMPEGTests`. |
| AUD-04 | AUD-2026-10-19 clean-room | ID3-backed number pairs were split on AAC/TTA/AIFF/DSF/DSDIFF. | Fixed with a shared native ID3 pair writer. | `CleanRoomID3Tests`, 7 formats × 5 writer routes. |
| AUD-18 | AUD-2026-10-19 clean-room | `COPYFILE_CLONE` may drop setuid/setgid bits. | Bounded: both transaction engines reject privilege-bearing files before staging. | `CleanRoomPrivilegeTests`; requires a host outside this sandbox to run. |
| F1 | AUD-2026-10-19 audio identity | TagLib relocated WAVE `bext`/`iXML`, invalidating a metadata-only audio identity. | Fixed by excluding those ancillary chunks; three regressions added. | `bedd725`; `AudioContentIdentityTests.waveAncillary*`. |
| VH-01..VH-03 | VER-2026-10-18 | ASF WORD/DWORD siblings, lost ASF totals, and unsupported GUID encoding. | Fixed with focused ASF regressions. | `HardeningASFTests`. |

## Open and bounded findings

These are the items a future maintainer or agent should not describe as fully solved. "Open" means the limitation or evidence gap is actionable; "Bounded" means the package deliberately fails or narrows the contract.

| ID | Class | Item | Current treatment |
| --- | --- | --- | --- |
| OPEN-001 | Open / source compatibility | Adding `includingAudioContent:` overloads makes untyped function references such as `let f = TagLibMetadataManager.readSnapshot` ambiguous. Typed references still compile. | Documented in [AUDIO_CONTENT_CONTINUITY](../AUDIO_CONTENT_CONTINUITY.md). Do not promise untyped reference compatibility. |
| OPEN-002 | Bounded / API | The deprecated `applyMetadataPatch(_:to:expectedVersion:failurePolicy:)` overload forwards to the unguarded path and cannot check `expectedAudioContent`. | Listed among unguarded surfaces in [AUDIO_CONTENT_CONTINUITY](../AUDIO_CONTENT_CONTINUITY.md). Use the guarded overload. |
| OPEN-003 | Open / test coverage | Audio identity has no RF64, RIFX, leading-ID3 FLAC, or malformed AIFF/AIFC negative regressions, although those layouts are documented as unavailable. | Treat as an evidence gap, not proof of correctness. See `AudioContentIdentityTests`. |
| OPEN-004 | Bounded / format evidence | Speex, S3M, IT, Shorten, MOD, uncommon aliases, minimum-OS runtime, device runtime, and x86_64 runtime lack runtime verification in this repository. | Configured support labels are not runtime proof. See [FORMATS](../FORMATS.md) and [STATUS](../STATUS.md). |
| OPEN-005 | Bounded / dependency | The precompiled TagLib binary is not sanitizer-instrumented; another incompatible TagLib C++ implementation in the same process remains an ABI risk. | Dynamic framework is namespaced; sanitizer runs cover package code only. See [TRANSACTIONS](../TRANSACTIONS.md). |
| OPEN-006 | Bounded / concurrency | Coordination is process-local. An external writer can race the final identity check and rename. | No cross-process lock is claimed. See [TRANSACTIONS](../TRANSACTIONS.md). |
| OPEN-007 | Bounded / removal | Structured ASF attributes are upserts; ID3 URL/UFID frames have no individual structured removal operation. | Empty payloads reject; use verified full erase only when deleting everything is intended. See [USAGE](../USAGE.md). |
| OPEN-008 | Bounded / raw API | Native MP4 freeform atom identifiers are rejected by raw APIs; use `StructuredMetadata.mp4Atoms`. | Explicit validation, tested with verification disabled. See [USAGE](../USAGE.md). |
| OPEN-009 | Bounded / number text | Generic/Xiph `numberText` displays the first component and normalizes total padding; the numeric pair remains authoritative. | Documented; exact native slash text is not promised there. See [FORMATS](../FORMATS.md). |
| OPEN-010 | Bounded / TrueAudio | Mixed TrueAudio APEv2 metadata is rejected rather than reconciled with ID3. | Safe failure; original bytes remain. See [FORMATS](../FORMATS.md). |

## Evidence confidence

- Records written before 2026-10-19 use different test totals and different definitions of "verified". Read the record's own scope and environment.
- From 2026-10-25 the package requires Swift tools 6.4. Swift 6.0–6.3 are not supported and cannot import current Apple SDKs; older records that mention tools 6.0 describe their revision, not the current manifest.
- The clean-room audit observed 186 tests; the remediation final campaign reported 208. The audio-identity work raised the count to 222 before the three BWF regressions, for 225 test declarations at the current HEAD.
- Test totals are not evidence that arbitrary files, formats, platforms, or metadata variants are safe.
- The current validation state, including the last executed suite observed during the documentation pass, is in [docs/STATUS.md](../STATUS.md).

## Adding a record

Follow [CONVENTIONS.md](CONVENTIONS.md) and start from [TEMPLATE.md](TEMPLATE.md). Add one row here and, if the record creates or leaves an actionable finding, add it to the open register. Do not rewrite an existing final record; add an addendum or a superseding record instead.
