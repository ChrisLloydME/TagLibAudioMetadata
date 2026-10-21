# Documentation system reconstruction

| Field | Value |
| --- | --- |
| Record ID | `DOC-2026-10-21-documentation-reconstruction` |
| Type | Documentation |
| Date | `2026-10-21` |
| Status | Final |
| Examined revision | `e31030d` working tree; documentation and documentation-check tooling changes only, plus one corrected source comment |
| Branch | `docs/documentation-architecture-restructure` (working tree; no merge performed) |
| Environment | macOS 27.0.1 (26A434), arm64; Xcode 27.1 (27A9275); Apple Swift 6.4 |
| Supersedes | `DOC-2026-10-19-documentation-restructure` as the current owner map |
| Superseded by | `none` |
| Related records | `DOC-2026-10-19-documentation-restructure`, `AUD-2026-10-19-audio-content-identity` |
| Scope | Rebuilt the current-documentation structure, audited it against the Swift facade and public bridge, added structural documentation checks, and refreshed the observed validation snapshot. Production behavior was out of scope; no implementation change was made. |

## Summary

The previous documentation pass separated current contracts from historical records, but the current set still had overlapping ownership, a very long usage guide that repeated contracts, an incomplete symbol index, and several format/verification descriptions that were too broad. The reconstruction replaces the hub with a task-oriented owner map, makes the API reference cover the complete public surface, moves task detail out of the usage guide, corrects the format/WAV/bridge limitations found during a source read, and adds `scripts/check-docs.py` with a CI step.

The documentation check passes. A full SwiftPM test run at the starting revision produced 222 passes, 2 opt-in skips, and 1 environment-dependent sandbox failure; the failure is the known privilege-bit precondition, not a production regression. The Xcode full-suite run, sanitizers, release run, platform builds, consumers, corpus, and benchmark were not run in this pass.

## Scope and revision

The source inspection covered `Package.swift`, every Swift file under `Sources/TagLibAudioMetadata/`, the public bridge header and transaction coordinator, the format registry and container masks, and the representative tests used to confirm behavior. The working tree started at `e31030d`; production code was not modified except a documentation comment in `TagLibMetadataManager.RawPropertyMapWriteMode.replace` that incorrectly said a WAV replacement can remove RIFF INFO.

The review deliberately did not:

- revalidate historical audit findings;
- run Xcode `RunAllTests` or a device/simulator runtime;
- run AddressSanitizer, ThreadSanitizer, Release, or minimum-platform builds;
- run the consumer packages, external corpus, or benchmark;
- create a DocC catalog or generated symbol documentation.

## Method

- Read the public declarations and source behavior rather than trusting prior prose.
- Cross-checked claims against the format registry, container masks, transaction pipeline, Structured mutation paths, verification helpers, and audio-identity scanner.
- Ran a temporary compile-only documentation example test to catch argument-order and signature errors; it was removed after the run. The only runtime failure in that probe was an intentionally invalid `/tmp/example.mp3` URL.
- Probed WAV whole-map `.replace` behavior with `info-only.wav`. The call did not remove RIFF INFO; verification failed because the separate INFO field remained. The documentation and the misleading source comment were corrected accordingly.
- Ran `python3 scripts/check-docs.py` after the rewrite.
- Ran `swift test --disable-keychain --disable-netrc --disable-sandbox` with workspace-local module caches for the observed status.

## Findings

### F-01 — Current documents had overlapping and duplicated contracts

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** `docs/USAGE.md` (1,181 lines) repeated preservation, transaction, format, and verification material that also appeared in dedicated documents. `README.md` carried a second reliability summary. `docs/README.md` and `docs/DEVELOPMENT.md` each carried an owner table.
- **Impact:** A maintainer had to update several copies for one behavior change; readers could not tell which statement was canonical.

### F-02 — The API reference omitted public surface

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The prior `docs/API_REFERENCE.md` did not document `MetadataExtractionOptions`, the complete `MetadataFieldKey` set, construction limits such as `BasicMetadata` having no public memberwise initializer, several structured write-type restrictions, or the full `MetadataWriteVerificationContext` field set.
- **Impact:** Consumers had to infer signatures from examples or source.

### F-03 — WAV whole-map replacement guidance was wrong

- **Severity:** High for a caller who relied on it
- **Confidence:** Confirmed by local probe
- **Status:** Fixed
- **Evidence:** With `info-only.wav`, `writeRawMetadataPropertyMapWithVerification(["TITLE": "Only"], mode: .replace)` failed verification with an unexpected retained INFO/ENCODEDBY value; it did not remove RIFF INFO. The source comment on `RawPropertyMapWriteMode.replace` also claimed it could remove INFO.
- **Impact:** A caller following the old claim could either lose a verified write or misunderstand how to remove INFO. Current docs direct callers to `.merge`/`RawMetadataPatch` for preservation and structured `.id3v2Only` for INFO removal.

### F-04 — Format evidence wording was too broad

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The prior matrix described `supportLevel` as family/primary-derived without noting that `capability(forExtension:)` returns the requested extension's level; it said Basic and typed Patch WAV writes were affected by `riffPolicy`; and it did not clearly separate structured write types from inspection-only types.
- **Impact:** UI code could enable unsupported operations or expect a policy parameter that does not exist on Basic/Patch APIs.

### F-05 — Bridge readback limits were underspecified

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** Direct bridge mutators validate staged readability, but `writeTagMetadata` runs an in-place bridge primitive inside the facade transaction and, with `.none`, adds neither semantic readback nor a staged-file readability readback. The prior docs described only "no semantic verification."
- **Impact:** A caller could overstate the guarantee of `writeTagMetadata` with the default context.

### F-06 — The prior restructuring report remained in the current-document set

- **Severity:** Low
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** `docs/DOCUMENTATION_RESTRUCTURING_REPORT.md` described a completed 2026-10-19 pass but sat beside current contracts and was linked as a current document.
- **Impact:** Its "remaining work" and owner table could be mistaken for the live backlog and current architecture.

### F-07 — Status was a 2026-10-19 snapshot

- **Severity:** Medium
- **Confidence:** Confirmed
- **Status:** Fixed
- **Evidence:** The prior status was tied to `d40f7f9` and an earlier Xcode run. A fresh SwiftPM run at `e31030d` reproduced the known counts and sandbox failure.
- **Impact:** Readers could not tell which observed result applied to the documentation revision.

## Repairs or recommendations

- Rewrote the root README and `docs/README.md` around a concise entry point, task paths, one canonical owner per topic, and an explicit evidence vocabulary.
- Rewrote `docs/USAGE.md` around task selection and recipes; moved long contract explanations to `PRESERVATION.md`, `TRANSACTIONS.md`, `FORMATS.md`, and `AUDIO_CONTENT_CONTINUITY.md`.
- Expanded `docs/API_REFERENCE.md` with the manager API, nested types, model fields, construction limits, schema, errors, public bridge selectors, and deprecation map.
- Corrected `FORMATS.md` for per-extension levels, tracker allowlists, WAV-only RIFF policy, structured write types, audio-identity availability, and ASF/DSD/APE boundaries.
- Corrected the WAV whole-map `.replace` description in docs and in the `RawPropertyMapWriteMode.replace` source comment.
- Moved the 2026-10-19 report to `docs/records/documentation/DOC-2026-10-19-documentation-restructure.md` and annotated it as historical in the records index.
- Added `scripts/check-docs.py` and a `Documentation checks` step to `.github/workflows/ci.yml`.
- Updated `STATUS.md` with the fresh observed run and the current limitations table.

## Verification

| Check | Result | Counts / limits |
| --- | --- | --- |
| `python3 scripts/check-docs.py` | Pass | 30 Markdown files after this record; relative links, fragments, table pipes, hub coverage, H1 count |
| Temporary documentation compile test | Passed type-checking | Compile-only; removed after run; did not execute valid file operations |
| `swift test --disable-keychain --disable-netrc --disable-sandbox` | Observed | 153 XCTest: 151 passed, 2 skipped; 72 Swift Testing: 71 passed, 1 environment-dependent privilege-bit failure; Debug build succeeded |
| Xcode `RunAllTests` | Not run | No current-run claim |
| ASAN / TSAN / Release / minimum-platform / consumers / corpus / benchmark | Not run | Configured in CI; not evidence for this working tree |

## Remaining limitations

- The documentation check is structural. It cannot prove prose, API signatures, or behavior.
- The API reference is hand-maintained. A future DocC catalog or generated symbol index would reduce drift; none was added.
- The temporary compile test covered examples but was not committed as a permanent documentation-example target.
- Historical records were not independently revalidated; their index annotations remain the authority for current relevance.
- No production behavior was changed, so no new runtime evidence exists beyond the pre-existing tests.

## References

- Commits: `e31030d` Record documentation restructuring report and final status (starting revision)
- Tests: `Tests/TagLibAudioMetadataTests/`; `AudioContentIdentityTests`, `FixtureMetadataRoundTripTests`, `Capabilities/FormatCapabilityTests`
- Current documentation: [hub](../../README.md), [API reference](../../API_REFERENCE.md), [formats](../../FORMATS.md), [status](../../STATUS.md)
- Related records: [previous documentation pass](DOC-2026-10-19-documentation-restructure.md), [audio-identity audit](../audits/AUD-2026-10-19-audio-content-identity.md)
