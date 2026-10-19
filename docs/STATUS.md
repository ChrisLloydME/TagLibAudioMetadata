# Current validation status

This page records the latest known validation state of the code and the limits that remain. It is a status snapshot, not a guarantee and not a chronological log. Historical campaigns belong in [engineering records](records/README.md).

## Status snapshot

| Field | Value |
| --- | --- |
| Code revision reviewed | `d40f7f9` (`main` at the start of the documentation branch; the documentation branch does not change production code) |
| Documentation branch | `docs/documentation-architecture-restructure` |
| Test-run date | 2026-10-19 10:37 CST |
| Host | macOS 27.0.1 (26A434), arm64 |
| Toolchain | Xcode 27.1 (27A9275), Apple Swift 6.4 |
| Command | `swift test --disable-keychain --disable-netrc --disable-sandbox` |
| Test declarations | 225: 153 XCTest + 72 Swift Testing |
| Observed result | 222 passed, 2 skipped, 1 environment-dependent failure |
| Merge status | No merge into `main` was performed. This status is not a merge approval. |

### Observed details

- **XCTest:** 153 executed, 2 skipped, 0 failures.
  - `ExternalCorpusPreservationTests` skipped because `TAGLIB_PRESERVATION_CORPUS` was not set.
  - `SnapshotThroughputBenchmarkTests` skipped because `TAGLIB_BENCHMARK` was not set.
- **Swift Testing:** 72 tests in 19 suites; 71 passed, 1 failed.
  - The failure is `CleanRoomPrivilegeTests.privilegedFilesRejectBeforeCloneInBothTransactionEngines` at its own precondition: this sandbox strips setuid/setgid bits even though `chmod` reports success.
  - The test passed outside the agent sandbox during the clean-room remediation. It is not weakened or skipped here.

This run used `--disable-sandbox` because SwiftPM's manifest sandbox could not launch in the execution environment. That is a build-isolation limitation, not a package setting.

### What was not run in this pass

The following are configured or documented but were **not** executed during the documentation restructuring:

- AddressSanitizer and ThreadSanitizer suites;
- Release-mode suite;
- Xcode test runner suite;
- strict minimum-platform builds for macOS 13 arm64/x86_64 and iOS 16 device/simulator;
- both consumer packages;
- the opt-in external corpus and throughput benchmark;
- an independent FFprobe/FFmpeg packet comparison;
- device, minimum-OS, x86_64, or simulator runtime execution.

Do not treat this status as evidence for those checks.

### Last recorded full-suite evidence before this run

| Revision | Evidence | Result |
| --- | --- | --- |
| `1fff9f0` | Clean-room remediation final campaign | 208 tests; Debug with both opt-ins, Release, ASAN, TSAN, Xcode, five strict platform builds, consumers, and independent eight-format checks passed. |
| `873cb3e` | Independent audio-identity audit | 222 discovered; 220 passed, 2 opt-in skips, 0 failures in Xcode Debug. iOS Simulator build passed. |
| `bedd725` / `d40f7f9` | F1 fix and three BWF/iXML regressions | Test declarations rose from 222 to 225. A full-suite result for this revision was not recorded in the repository before the documentation pass. |

The three added regressions pass in the current run. The clean-room and audio-identity records remain the detailed evidence for their revisions; they are not restated as current results.

## Current limitations

These are documented boundaries. They are not silently accepted defects.

| Area | Limitation |
| --- | --- |
| Raw API | Native MP4 `----:` atom keys are rejected. Use `StructuredMetadata.mp4Atoms`. |
| Number text | Generic/Xiph `numberText` displays the first component and normalizes total padding; the numeric pair remains authoritative. |
| Structured removal | ASF attributes are upserts; ID3 URL/UFID frames have no individual structured removal operation. |
| Privilege bits | setuid/setgid files are rejected before staging; clear the bits explicitly before editing. |
| TrueAudio | Mixed unmodeled APEv2 metadata rejects rather than reconciling with ID3. |
| Whole-map raw replacement | `.replace` owns the visible PropertyMap; it is not a native archive and can remove WAV INFO or opaque native data. Use `.merge`/`RawMetadataPatch` for preservation. |
| Concurrency | Coordination is process-local. An external process can race the final identity check and rename. |
| Durability | `.durable` means an OS-level flush completed; it is not a hardware or power-loss guarantee. |
| Dependency | The precompiled TagLib binary is not sanitizer-instrumented. Another incompatible TagLib C++ implementation in the same process is an ABI risk. |
| Compatibility | Untyped function references to overloaded names such as `readSnapshot` can be ambiguous. Typed references remain the supported compatibility shape. |
| Deprecated API | The deprecated `applyMetadataPatch(_:to:expectedVersion:failurePolicy:)` overload is unguarded; it cannot check `expectedAudioContent`. |
| Format evidence | Speex, S3M, IT, Shorten, MOD, uncommon aliases, and several platform/runtime combinations lack runtime verification. |
| Audio identity | RF64, RIFX, leading-ID3 FLAC, and malformed AIFF/AIFC have no dedicated negative regressions even though they are documented as unavailable. |

See [FORMATS](FORMATS.md), [PRESERVATION](PRESERVATION.md), [TRANSACTIONS](TRANSACTIONS.md), and [AUDIO_CONTENT_CONTINUITY](AUDIO_CONTENT_CONTINUITY.md) for the contracts.

## How to interpret prior assessments

- **READY WITH CAVEATS** in the clean-room remediation describes revision `1fff9f0`, not the current HEAD.
- **READY WITH CAVEATS** in the audio-identity audit describes `873cb3e` and was conditional on fixing F1 and qualifying the documentation. F1 was fixed in `bedd725`; F2/F3 remain limitations.
- **NOT READY TO MERGE** in the clean-room audit describes `615bc8c` and was superseded by the remediation.
- No historical verdict is a current merge decision. A new release or merge decision requires a fresh review of the target revision.

## Updating this page

Update this page only when a validation campaign changes the latest known state. Include the revision, environment, command, opt-in state, counts, skips, and any environment-dependent failure. Do not turn it into a log; record a campaign in `docs/records/` and summarize the current state here.
