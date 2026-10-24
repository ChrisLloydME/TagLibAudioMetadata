# Current validation status

This page records the latest known validation state and the limits that remain. It is a snapshot, not a chronological log. Historical campaigns belong in [engineering records](records/README.md).

## Latest observed run

| Field | Value |
| --- | --- |
| Production source revision | `fefdb88` (`HEAD` when this documentation pass started) |
| Working tree | Documentation, generated field tables, documentation-check tooling, and documentation records only; production source is unchanged |
| Observation date | 2026-10-24 |
| Host | macOS 27.0.1 (26A434), arm64 |
| Toolchain | Xcode 27.1 (27A9275), Apple Swift 6.4 |
| Command | `swift test --disable-keychain --disable-netrc --disable-sandbox` with workspace-local Clang/Swift module caches |
| XCTest | 153 executed: 151 passed, 2 skipped, 0 failed |
| Swift Testing | 72 tests in 19 suites: 71 passed, 1 environment-dependent failure |
| Overall | 222 passed, 2 skipped, 1 environment-dependent failure of 225 declarations |
| Compile result | Debug build succeeded before the test run |
| Documentation check | `python3 scripts/check-docs.py` passes for the current tree |
| Merge status | No merge was performed. This status is not a merge approval. |

The two XCTest skips are the opt-in external corpus and throughput benchmark. The Swift Testing failure was `CleanRoomPrivilegeTests.privilegedFilesRejectBeforeCloneInBothTransactionEngines` at its own precondition: the requested permissions were `0o4644`, `0o2644`, and `0o6644`, but the sandbox host stripped the privilege bits and reported mode `420` decimal (`0o644`). The production rejection path is covered by the passing Xcode run recorded under the previous revision and by the clean-room record; it was not weakened or skipped for this run.

The `--disable-sandbox` flag was required because SwiftPM's manifest sandbox could not launch in this environment. That is a build-isolation limitation, not a package setting. Workspace-local module caches were used for the same reason.

## What was not run in this pass

Do not treat this status as evidence for:

- Xcode `RunAllTests` at this documentation HEAD;
- AddressSanitizer or ThreadSanitizer;
- Release-mode tests;
- strict minimum-platform builds for macOS 13 arm64/x86_64 and iOS 16 device/simulator;
- both consumer packages;
- the opt-in external corpus and throughput benchmark;
- device, minimum-OS, x86_64, or simulator runtime execution;
- an independent FFprobe/FFmpeg packet comparison for these edits.

## Previous recorded evidence

| Revision | Evidence | Result |
| --- | --- | --- |
| `d40f7f9` | Xcode full suite during the previous documentation pass | 225 declarations: 223 passed, 2 opt-in skips, 0 failed. |
| `e31030d` | SwiftPM command with the same environment caveats | 222 passed, 2 skipped, 1 environment-dependent privilege-bit failure of 225 declarations. |
| `1fff9f0` | Clean-room remediation final campaign | 208 tests; Debug with both opt-ins, Release, ASAN, TSAN, Xcode, five strict platform builds, consumers, and independent eight-format checks passed. |
| `873cb3e` | Independent audio-identity audit | 222 discovered; 220 passed, 2 opt-in skips, 0 failures in Xcode Debug. iOS Simulator build passed. |
| `fefdb88` | This documentation pass, SwiftPM command above | 222 passed, 2 skipped, 1 environment-dependent privilege-bit failure of 225 declarations. |

These are historical snapshots at the revisions shown. They are not current merge approvals and do not prove the current documentation or production tree.

## Current limitations

These are documented boundaries, not silently accepted defects. Links point to the canonical contract.

| Area | Limitation |
| --- | --- |
| Raw API | Native MP4 `----:` atom keys are rejected. Use `StructuredMetadata.mp4Atoms`. |
| Number text | Generic/Xiph `numberText` displays the first component and normalizes total padding; the numeric pair remains authoritative. |
| Structured removal | ASF attributes are upserts; ID3 URL/UFID frames have no individual structured removal operation. |
| Privilege bits | setuid/setgid files are rejected before staging; clear the bits explicitly before editing. The privilege test cannot run under hosts that strip those bits. |
| TrueAudio | Mixed unmodeled APEv2 metadata rejects rather than reconciling with ID3. |
| Whole-map raw replacement | `.replace` owns only the visible PropertyMap; it is not a native archive and cannot reconstruct opaque native data. On WAV, separate RIFF INFO fields can survive and make verification fail. Use `.merge`/`RawMetadataPatch` for preservation, or a structured `.id3v2Only` write when INFO removal is intended. |
| Concurrency | Coordination is process-local. An external process can race the final identity check and rename. |
| Durability | `.durable` means an OS-level flush completed; it is not a hardware or power-loss guarantee. |
| Dependency | The precompiled TagLib binary is not sanitizer-instrumented. Another incompatible TagLib C++ implementation in the same process is an ABI risk. |
| Compatibility | Untyped function references to overloaded names such as `readSnapshot` can be ambiguous. Typed references remain the supported compatibility shape. |
| Deprecated API | The deprecated `applyMetadataPatch(_:to:expectedVersion:failurePolicy:)` overload is unguarded; it cannot check `expectedAudioContent`. |
| Format evidence | Speex, S3M, IT, Shorten, MOD, uncommon aliases, and several platform/runtime combinations lack runtime verification. Shorten and MOD are read-only. |
| Audio identity | RF64, RIFX, leading-ID3 FLAC, and malformed AIFF/AIFC have no dedicated negative regressions even though they are documented as unavailable. |
| Bridge verification | Direct `CTagLibBridge` mutators validate readability but do not perform facade semantic readback. `writeTagMetadata` with `.none` performs no metadata or staged-file readability readback beyond the transaction preflight. |
| Structured policy | `RIFFMetadataWritePolicy` is ignored by formats other than WAV and AIFF/AIFF-C. `.syncBasicFieldsToInfo` does not throw for those other formats, but it does not synchronize anything. |

See [Formats](FORMATS.md), [Write semantics](PRESERVATION.md), [Transactions](TRANSACTIONS.md), and [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md).

## How to interpret prior assessments

- **READY WITH CAVEATS** in the clean-room remediation describes revision `1fff9f0`, not the current HEAD.
- **READY WITH CAVEATS** in the audio-identity audit describes `873cb3e` and was conditional on fixing F1 and qualifying the documentation. F1 was fixed in `bedd725`; F2/F3 remain limitations.
- **NOT READY TO MERGE** in the clean-room audit describes `615bc8c` and was superseded by the remediation.
- No historical verdict is a current merge decision. A new release or merge decision requires a fresh review of the target revision.

## Updating this page

Update this page only when a validation campaign changes the latest known state. Include the revision, environment, command, opt-in state, counts, skips, and any environment-dependent failure. Do not turn it into a log; record a campaign in `docs/records/` and summarize the current state here.
