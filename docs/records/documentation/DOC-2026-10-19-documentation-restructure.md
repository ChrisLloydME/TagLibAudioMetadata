# Documentation Restructuring Report

| Field | Value |
| --- | --- |
| Report date | 2026-10-19 |
| Repository | `TagLibAudioMetadata` |
| Branch | `docs/documentation-architecture-restructure` |
| Base revision | `d40f7f9459d23fa1fe7f01c419e2e7a3db9aed88` (`main`) |
| Production code changed | No |
| Tests changed | No |
| Dependency upgraded | No |
| Merge into `main` | No |
| Historical records deleted | No |

## Executive summary

The repository had substantial engineering documentation but no stable distinction between current contracts and historical evidence. Current guides contained dated audit conclusions, the project entry point ended with a stale remediation status, the maintenance log called an old task "current", and eight investigation reports sat in `docs/` without an index, lifecycle status, or finding cross-references. Several technical claims were also out of date or contradicted the current source.

This restructuring established:

1. A concise project entry point (`README.md`) and a documentation hub (`docs/README.md`).
2. One canonical owner for each current topic: installation, usage, API reference, formats, preservation, transactions/concurrency, architecture, testing, current status, migration, and development.
3. A historical records archive at `docs/records/` with a centralized investigation index, a finding-disposition summary, an open/bounded finding register, record conventions, and a template.
4. An explicit current validation status (`docs/STATUS.md`) that separates observed results, author-reported results, and unrun checks.
5. Corrections for the concrete documentation inaccuracies found during the audit, including an invalid README example, a read-only format error, stale audio-identity counts, and a misleading "latest validation" pointer.

The production code, tests, package manifest, dependency pin, and CI configuration were not modified. `main` remains at `d40f7f9`; no merge was performed. At that code revision, Xcode `RunAllTests` passed all 225 declarations with 223 passes, 2 opt-in skips, and 0 failures.

## Previous documentation problems

Before this work, the documentation landscape was:

- `README.md` (344 lines) with a long API discussion and a final section titled "Clean-room remediation status (2026-10-19)" that read as current status.
- `MAINTENANCE_PROGRESS.md` (491 lines) whose first heading was "Current task — clean-room audit remediation" and whose test counts stopped at 208 while the current HEAD declares 225 tests.
- `docs/SUPPORT.md` (1,340 lines) combining a current API guide, a format matrix, a field reference, and dated "Verification-hardening evidence" sections.
- `docs/THREAD_SAFETY.md` (68 lines) duplicating transaction and concurrency material that also appeared in the README, architecture, and support guide.
- `docs/MIGRATION_REPORT.md` explicitly labelled as a historical validation snapshot but presented in the current document set and linked from the README as "the migration report".
- Eight audit, review, remediation, verification, migration, and maintenance reports in `docs/` or the repository root with no index, no lifecycle state, and no finding cross-references.
- The original 2026-10-18 independent audit present only as a locally excluded, untracked `AUDIT_REPORT.md`.

Concrete accuracy and maintainability problems found:

1. The README quick-start patch mixed typed track fields with `numberText` in one `MetadataPatch`, which the current validation rejects with `conflictingNumberRepresentations`.
2. The README format table said "Read-only | MOD family and Shorten". The registry marks only `mod` and `shorten` read-only; XM, S3M, and IT are writable (XM fixture-covered; S3M/IT experimental and limited to title/comment).
3. The README directed readers to `MAINTENANCE_PROGRESS.md` for "the latest completed validation for current main". That file described an earlier clean-room task and 208 tests, not the current HEAD's audio-identity work.
4. `docs/AUDIO_CONTENT_CONTINUITY.md` reported 14 new tests and 222 total, before the F1 fix added three BWF/iXML regressions. It did not mention that F1 was fixed, and it did not list the deprecated typed overload among unguarded surfaces or explain the untyped function-reference ambiguity.
5. `docs/INSTALLATION.md` said the `[Unreleased]` APIs "can be ahead of `main` while changes are under review". Unreleased APIs are on `main`; the correct comparison is against the latest tag.
6. `CHANGELOG.md` placed "Historical release provenance" inside `[Unreleased]`, before an unreleased `### Fixed` list. This obscured which entries were release history and which were unreleased.
7. `docs/ARCHITECTURE.md` said public bridge mutators "use the same transaction principles" without stating that they do not inherit facade semantic verification. It also said partial paired-number removal is rejected "on ID3/MP4", understating the native pair formats covered by the current validation.
8. The format documentation did not distinguish the WAV RIFF INFO surface from AIFF/AIFF-C, whose writer path uses ID3v2 and has no RIFF INFO mutation even though the shared capability container mask reports `riffInfo`.
9. Current docs did not state that raw APIs reject native MP4 `----:` atom keys or that `expectedTextFields` uses camel-case Basic field names rather than PropertyMap keys.
10. No current page recorded the actual latest test run or the known environment-dependent privilege-bit test failure. Historical records contained the only detailed test evidence, at older revisions.
11. No symbol-level public API reference existed; readers had to infer signatures from long prose examples.
12. Relative links and prose path references pointed at documents that were conceptually historical, and moving the records required link repair.

## New documentation architecture

```text
README.md                                  project entry point and quick start
CHANGELOG.md                               release history
docs/
  README.md                                documentation hub and canonical-owner map
  INSTALLATION.md                          binary identity, slices, embedding, signing
  USAGE.md                                 public API semantics and recipes
  API_REFERENCE.md                         symbol-level public API index
  FORMATS.md                               22-family matrix and format limitations
  PRESERVATION.md                          preservation, omission, verification, erase
  TRANSACTIONS.md                          atomicity, durability, concurrency, thread safety
  AUDIO_CONTENT_CONTINUITY.md              opt-in audio identity and guarded rebasing
  ARCHITECTURE.md                          implementation and source/test layout
  TESTING.md                               test layers, commands, CI, evidence limits
  STATUS.md                                latest observed validation state
  MIGRATION.md                             compatibility and deprecated-name migration
  DEVELOPMENT.md                           contribution, release, and docs maintenance
  THIRD_PARTY_NOTICES.md                   licensing and provenance
  DOCUMENTATION_RESTRUCTURING_REPORT.md    this report
  records/
    README.md                              investigation index and finding register
    CONVENTIONS.md                         record lifecycle and evidence conventions
    TEMPLATE.md                            new-record template
    audits/                                independent audits
    reviews/                               independent reviews
    remediation/                           remediation campaigns
    verification/                          verification campaigns
    migrations/                            dependency/platform migrations
    maintenance/                           maintenance logs
```

### Separation of current and historical material

- **Current technical documentation** describes the code at the current HEAD. It uses present tense, states its scope, and avoids historical test counts unless it labels them as historical.
- **Engineering records** describe what was examined at a named revision and what was concluded. They are immutable historical evidence. The index annotates their current relevance.
- **Status** is a short snapshot of the latest observed validation state, not a chronological log.
- **Changelog** is release history, not current contract documentation.

### Canonical ownership

| Topic | Canonical document |
| --- | --- |
| Introduction, requirements, install, quick start | `README.md` |
| Navigation and evidence labels | `docs/README.md` |
| Binary distribution and embedding | `docs/INSTALLATION.md` |
| API semantics and recipes | `docs/USAGE.md` |
| Symbol signatures | `docs/API_REFERENCE.md` |
| Format support and limitations | `docs/FORMATS.md` |
| Preservation, omission, verification, erase | `docs/PRESERVATION.md` |
| Atomicity, durability, concurrency | `docs/TRANSACTIONS.md` |
| Audio identity | `docs/AUDIO_CONTENT_CONTINUITY.md` |
| Implementation architecture | `docs/ARCHITECTURE.md` |
| Test commands and evidence limits | `docs/TESTING.md` |
| Latest validation status | `docs/STATUS.md` |
| Compatibility and migration | `docs/MIGRATION.md` |
| Contribution, release, docs maintenance | `docs/DEVELOPMENT.md` |
| Historical investigations | `docs/records/README.md` |

The README was reduced from 344 to 176 lines and now points to the hub instead of carrying deep contracts. `docs/USAGE.md` retains the API guidance but no longer contains a format matrix or dated verification evidence. The new pages own the topics that were previously duplicated across `SUPPORT.md`, `THREAD_SAFETY.md`, the README, and `ARCHITECTURE.md`.

## Historical record-management design

### Record identity

- Record ID: `TYPE-YYYY-MM-DD-short-slug`, for example `AUD-2026-10-19-clean-room`.
- Types: `AUD` (audit), `REV` (review), `REM` (remediation), `VER` (verification), `MIG` (migration), `MAINT` (maintenance), `INC` (incident), `DOC` (documentation).
- Files live under `docs/records/<type-directory>/<record-id>.md`.

### Lifecycle vocabulary

Records use `Final`, `Historical`, `Superseded`, and `Withdrawn`. Findings use `Confirmed`, `Unverified`, `Fixed`, `Fixed (claimed)`, `Bounded`, `Open`, `Not a defect`, and `Superseded`. The distinction between `Fixed` and `Fixed (claimed)` prevents a remediation report from being treated as independent revalidation.

### Index and registers

- `docs/records/README.md` contains the investigation index: ID, date, type, examined revision/branch, current relevance, and findings/outcome.
- A finding-disposition summary maps each record's finding range to the record that contains the detailed matrix.
- A selected cross-record findings table links major defects to their repairs and regressions.
- An open/bounded register lists the limitations and evidence gaps a future maintainer must not describe as fully solved.
- An evidence-confidence section explains why test counts differ across records and why they are not current guarantees.

### Immutability and annotation

Records are not rewritten to match current code. Their original dates, revisions, findings, verdicts, and test counts remain. The index supplies current relevance and supersession. Relative Markdown links were repaired after relocation; prose path references such as `docs/SUPPORT.md` remain as historical coordinates and are explained in the index. The local-only original audit remains untouched and uncommitted.

### Template and conventions

`docs/records/CONVENTIONS.md` documents when to create a record, required metadata, required sections, finding IDs/statuses, immutability, cross-references, evidence standards, and the add-record workflow. `docs/records/TEMPLATE.md` provides the metadata block and section skeleton.

## Major documents created, rewritten, relocated, or consolidated

| Document | Action | Notes |
| --- | --- | --- |
| `README.md` | Rewritten | 344 → 176 lines; concise entry point; invalid patch example removed; stale status section removed; format and audio-identity summaries corrected. |
| `docs/README.md` | Created | Navigation hub, canonical-owner map, current/historical distinction, evidence labels. |
| `docs/INSTALLATION.md` | Updated | Unreleased-vs-tag wording corrected; migration link added. |
| `docs/USAGE.md` | Renamed and rewritten from `docs/SUPPORT.md` | Current API guide only; format matrix moved to `FORMATS.md`; dated verification evidence removed; duplication with preservation/transactions reduced. |
| `docs/API_REFERENCE.md` | Created | Compact symbol-level index of reads, patches, writes, capability APIs, models, errors, and bridge selectors. |
| `docs/FORMATS.md` | Created | Canonical 22-family/37-extension matrix, support levels, cross-format behavior, per-format limitations, fixture evidence. |
| `docs/PRESERVATION.md` | Created | Canonical omission/removal, Basic preservation, typed/raw/structured semantics, verification scope, erase, non-promises. |
| `docs/TRANSACTIONS.md` | Created; `docs/THREAD_SAFETY.md` retired | Consolidates staging, atomicity, durability, rejection cases, process-wide mutex, same-entry coordination, and sanitizer limits. |
| `docs/AUDIO_CONTENT_CONTINUITY.md` | Updated | F1 fix status, F2/F3 caveats, 17 focused tests, current 225-declaration context, historical audit link, verification evidence separated. |
| `docs/ARCHITECTURE.md` | Updated | Bridge verification distinction, partial-pair wording, links to current canonical docs, test-layout notes. |
| `docs/TESTING.md` | Created | Test layers, standard commands, minimum-platform builds, consumers, opt-ins, CI jobs, environment-dependent privilege test, evidence limits. |
| `docs/STATUS.md` | Created | Xcode full-suite pass and command-line environment-dependent failure at `d40f7f9`, earlier campaigns, limitations, and interpretation of prior verdicts. |
| `docs/MIGRATION.md` | Created | Current compatibility promises, deprecated-name table, behavior changes, 0.4→0.5 product split, untyped-reference caveat. |
| `docs/DEVELOPMENT.md` | Created | Repository layout, source-of-truth rules, change/release workflow, documentation ownership, link check, record maintenance. |
| `CHANGELOG.md` | Restructured | Added documentation workstream entry; moved historical release provenance out of `[Unreleased]`; preserved all release entries. |
| `docs/records/README.md` | Created | Investigation index, finding-disposition summary, selected cross-record findings, open/bounded register, evidence confidence. |
| `docs/records/CONVENTIONS.md` | Created | Record types, IDs, metadata, sections, finding statuses, immutability, evidence standard, workflow. |
| `docs/records/TEMPLATE.md` | Created | Required metadata and section template. |

## Historical reports preserved and indexed

The eight committed historical reports were moved into the records archive. The local-only original audit remained in place. Their bodies were preserved; only relative Markdown link targets were repaired after relocation, and the original review's link to the local-only audit was converted to an explicitly unavailable reference so a clean clone does not contain a broken link. No finding, date, revision reference, test count, or verdict was rewritten.

| Record ID | Original path | New path | Examined revision |
| --- | --- | --- | --- |
| `AUD-2026-10-18-independent-technical-audit` | `AUDIT_REPORT.md` (local-only, excluded) | unchanged; not committed | `03473c9` on `main` |
| `REM-2026-10-18-comprehensive-audit` | `docs/REMEDIATION_REPORT_2026-10-18.md` | `docs/records/remediation/REM-2026-10-18-comprehensive-audit.md` | `fix/comprehensive-audit-remediation` from `03473c9` |
| `REV-2026-10-18-post-remediation` | `docs/INDEPENDENT_REVIEW_2026-10-18.md` | `docs/records/reviews/REV-2026-10-18-post-remediation.md` | `review/comprehensive-remediation-verification` from `62504ff`; tested `1e8fb35` |
| `VER-2026-10-18-verification-hardening` | `docs/VERIFICATION_HARDENING_2026-10-18.md` | `docs/records/verification/VER-2026-10-18-verification-hardening.md` | `review/verification-hardening` from `737dd07`; tested `98b17dc` |
| `AUD-2026-10-19-clean-room` | `docs/CLEAN_ROOM_AUDIT_2026-10-19.md` | `docs/records/audits/AUD-2026-10-19-clean-room.md` | `615bc8c` |
| `REM-2026-10-19-clean-room` | `docs/CLEAN_ROOM_REMEDIATION_2026-10-19.md` | `docs/records/remediation/REM-2026-10-19-clean-room.md` | `fix/clean-room-audit-remediation` from `615bc8c`; tested `1fff9f0` |
| `AUD-2026-10-19-audio-content-identity` | `docs/AUDIO_IDENTITY_AUDIT_2026-10-19.md` | `docs/records/audits/AUD-2026-10-19-audio-content-identity.md` | `873cb3e` |
| `MIG-2026-09-01-taglib-2.3.1` | `docs/MIGRATION_REPORT.md` | `docs/records/migrations/MIG-2026-09-01-taglib-2.3.1.md` | TagLib 2.3.1-r2 migration, 2026-09-01 |
| `MAINT-2026-10-19-progress-log` | `MAINTENANCE_PROGRESS.md` | `docs/records/maintenance/MAINT-2026-10-19-progress-log.md` | multiple passes, 2026-09-21 through 2026-10-19 |

The local-only original audit remains at `AUDIT_REPORT.md`, excluded through `.git/info/exclude`. It is indexed with an explicit availability note and is no longer linked from a historical record in a way that breaks a clean clone.

## Technical inaccuracies corrected

1. **Invalid README patch example.** Removed `numberText` from a patch that also used typed `.track`/`.trackTotal`, and documented that one patch must use one number representation.
2. **Read-only format error.** Replaced "MOD family" with MOD (`.mod`, `.module`, `.nst`, `.wow`) and Shorten; clarified that XM is fixture-covered and S3M/IT are writable experimental formats limited to title/comment.
3. **Stale "latest validation" pointer.** Replaced the reference to `MAINTENANCE_PROGRESS.md` with the new `docs/STATUS.md` and the records index.
4. **Audio-identity stale counts and claims.** Updated 14→17 focused tests, 222→225 current declarations, recorded the F1 fix in `bedd725`/`d40f7f9`, and qualified the identity as independent of supported tag regions rather than all metadata edits.
5. **Unguarded deprecated overload and untyped references.** Explicitly documented that the deprecated typed patch overload forwards to the unguarded path and that untyped function references to overloaded names can be ambiguous; typed references are the supported compatibility shape.
6. **Installation version wording.** Corrected the claim that `[Unreleased]` APIs can be "ahead of main"; they are on `main` and ahead of the latest tag.
7. **Changelog hierarchy.** Moved the historical release-provenance note out of `[Unreleased]` and before `[0.5.3]`; all release entries preserved.
8. **Architecture bridge distinction.** Added that public bridge mutators are transactional but do not inherit facade semantic verification; corrected partial-pair wording and grammar.
9. **Format-matrix nuances.** Added the AIFF/AIFF-C `riffInfo` distinction, WAV-specific RIFF policy, bit-depth projection limits, ASF alias cleanup, APE date preservation, and the exact fixture-covered/experimental/read-only sets.
10. **Raw-key and verification-context semantics.** Documented native MP4 `----:` rejection, prefixless PropertyMap keys, `expectedTextFields` camel-case semantics, and `verifyAfterWrite` opt-out.
11. **Current status and verdict interpretation.** Added a page that distinguishes the latest observed run, earlier full campaigns, historical READY/NOT READY verdicts, and unrun checks.
12. **Environment-dependent test.** Documented that the privilege-bit test fails at its own setuid/setgid precondition in a sandbox that strips those bits; it is a host restriction, not a production failure.
13. **Link integrity.** Repaired relative links in moved records and current documents; the local-only audit is referenced as unavailable rather than as a guaranteed repository link.

## Verification performed

| Check | Result |
| --- | --- |
| Source inspection | Read the Swift facade, public bridge header, transaction coordinator, format registry, field schema, audio-identity scanner, read/write/verification extensions, package manifest, CI workflows, and representative tests. |
| Relative link check | All relative Markdown paths and fragments resolve in the working tree; the only pre-creation miss was this report itself. |
| `git diff --check` | Passed; no whitespace errors. |
| Production/test diff | `git diff main...HEAD -- Sources Tests Package.swift IntegrationTests scripts .github` is empty. |
| Xcode suite at `d40f7f9` | `RunAllTests`: 225 total, 223 passed, 2 opt-in skips, 0 failed, 0 expected failures, 0 not run. The privilege-bit test passed. |
| SwiftPM command-line run at `d40f7f9` | `swift test --disable-keychain --disable-netrc --disable-sandbox`: 153 XCTest executed with 2 opt-in skips and 0 failures; 72 Swift Testing declarations with 71 passes and 1 environment-dependent privilege-bit failure. Total 222 passed, 2 skipped, 1 environment-dependent failure of 225 declarations. |
| Release/sanitizer/platform/consumer checks | Not run during this documentation pass. Historical results are recorded at their own revisions and are not restated as current. |
| Documentation examples | Reviewed against current declarations and initializer signatures; not compiled as standalone examples. |

The test run used `--disable-sandbox` because SwiftPM's manifest sandbox could not launch in the execution environment. That is a build-isolation limitation, not a package configuration change.

## Remaining documentation uncertainties

- Historical findings were not independently revalidated in this pass. `Fixed (claimed)` is used where the evidence is a remediation record plus committed tests, not a fresh reproduction.
- The original `AUDIT_REPORT.md` is local-only and absent from a clean clone. Its findings are accessible through the later records that classify them, not as a repository file.
- The pass includes an Xcode full-suite result for `d40f7f9` and a command-line run with one environment-dependent failure. It did not include Release, sanitizers, minimum-platform, consumer, corpus, or benchmark checks.
- Documentation examples were reviewed for signature compatibility but not compiled as a standalone example suite.
- The AIFF/AIFF-C capability container mask reports `riffInfo`, but the AIFF writer path has no RIFF INFO mutation. This is documented as a WAV-specific entry; the production descriptor was not changed.
- Format labels remain coarse family/extension evidence labels. They do not prove per-field or per-codec behavior.
- The API reference is hand-maintained; there is no DocC catalog or generated symbol documentation.
- The record index is manually maintained. Conventions and a link check reduce, but do not eliminate, drift.

## Implementation defects discovered but not repaired

Per the assignment scope, no production code or tests were changed. The following are documented findings or limitations rather than repairs:

1. **Untyped function references are ambiguous after overload additions.** `let f = TagLibMetadataManager.readSnapshot` does not compile without a contextual type. Typed references and direct calls work. This is the audio-identity audit's F2 and is an accepted source-compatibility limitation, now documented.
2. **The deprecated typed patch overload is unguarded.** `applyMetadataPatch(_:to:expectedVersion:failurePolicy:)` forwards to the unguarded path and cannot check `expectedAudioContent`. It is now listed among unguarded surfaces. This is F3.
3. **Audio-identity negative coverage is incomplete.** RF64, RIFX, leading-ID3 FLAC, and malformed AIFF/AIFC are documented as unavailable but have no dedicated negative regressions. This is F5, a test-coverage gap rather than a demonstrated production defect.
4. **AIFF capability container mask includes `riffInfo`.** The shared WAV/AIFF mask reports a container that the AIFF writer does not implement. The docs now scope RIFF INFO to WAV; the descriptor remains unchanged.
5. **No production defect was found that this assignment's scope would justify repairing.** The AIFF descriptor inconsistency, F2, F3, and F5 are documented as actionable findings or limitations; production code and tests were left unchanged as required.

## Git commits created

| Commit | Subject |
| --- | --- |
| `7602e8c` | Archive historical engineering records under docs/records |
| `6e0a510` | Restructure current documentation by topic and separate history |
| `db9ea96` | Add engineering record index and conventions |
| `8a63d6f` | Clarify format boundaries and verification wording |
| `52832b4` | Keep local-only audit reference resolvable in clones |
| `<report commit>` | Record documentation restructuring report |

The report commit is the commit that contains this file. Its hash is content-dependent and therefore not embedded here; resolve it with `git log -1 --format=%H -- docs/DOCUMENTATION_RESTRUCTURING_REPORT.md`. At the time this report was written, branch HEAD was `52832b4`.

No commit was amended, squashed, rebased, reset, or rewritten. `main` was never checked out or modified.

## Final branch and HEAD

| Item | Value |
| --- | --- |
| Branch | `docs/documentation-architecture-restructure` |
| Base `main` | `d40f7f9459d23fa1fe7f01c419e2e7a3db9aed88` |
| Pre-report HEAD | `52832b4` |
| Final HEAD | The report commit described above; run `git rev-parse HEAD` on the branch. |
| Merge status | No merge into `main`; no merge commits added by this work. |

## Working-tree status

Before this report was written, the working tree was clean. The final commit contains this report, its navigation entry, and the status/convention refinements described above; after that commit the tree is clean. `AUDIT_REPORT.md` remains untracked and locally excluded by design.

## Outstanding documentation work

1. Run the remaining verification matrix (Release, ASan, TSan, minimum-platform builds, consumers, opt-in corpus/benchmark) at the final HEAD and update `docs/STATUS.md` with the observed results.
2. Add the missing audio-identity negative regressions for RF64, RIFX, leading-ID3 FLAC, and malformed AIFF/AIFC, or keep the evidence gap explicit in `STATUS.md` and the open register.
3. Decide whether to change the AIFF capability container mask or add a capability note explaining the `riffInfo` entry.
4. Consider a DocC catalog or generated API reference so the symbol index does not depend on manual maintenance.
5. Consider adding the link check from `docs/DEVELOPMENT.md` to CI.
6. Periodically revalidate selected historical findings when they affect a current release decision; do not assume a remediation record's status is current.
7. Keep the record index current when new audits, incidents, remediation, or verification campaigns are added.
