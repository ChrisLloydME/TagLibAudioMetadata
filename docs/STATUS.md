# Current validation status

This page records the latest known validation state and the limits that remain. It is a snapshot, not a chronological log. Historical campaigns belong in [engineering records](records/README.md).

## Latest observed run

| Field | Value |
| --- | --- |
| Release | `0.6.0` (2026-10-25) |
| Production source revision | `c46daa5` (`Discover the SwiftPM test bundle in the link audit`), merged as `2bf8d02` |
| Working tree | Clean after this release documentation commit; package manifest, changelog, and source are in the `c46daa5`/`2bf8d02` tree |
| Observation date | 2026-10-25 |
| Host | macOS 27.0.1 (26A434), arm64 |
| Toolchain | Xcode 27.1 (27A9275), Apple Swift 6.4 |
| Command | `swift test --disable-keychain --disable-netrc --disable-sandbox --skip CleanRoomPrivilegeTests` with workspace-local Clang/Swift module caches |
| XCTest | 153 executed: 151 passed, 2 skipped, 0 failed |
| Swift Testing | 71 tests in 18 suites: 71 passed, 0 failed (privilege test skipped) |
| Overall | 222 passed, 2 skipped, 0 failed of 224 exercised declarations; the full run including the privilege test reports 222 passed, 2 skipped, 1 environment-dependent failure of 225 |
| Xcode suite | `RunAllTests` at `102ddc7` (source-equivalent to `c46daa5`; that commit changes CI only): 223 passed, 2 opt-in skips, 0 failed of 225; the privilege regression passed |
| Hosted CI | [Run 40164904366](https://github.com/ChrisLloydME/TagLibAudioMetadata/actions/runs/40164904366) at `c46daa5`: all nine executed jobs passed; `remote-tag-consumer` was skipped because no tag existed yet |
| Minimum toolchain | Swift tools 6.4. Swift 6.0/6.1 reject the source syntax; Swift 6.2.4 and 6.3 cannot import macOS 26.5/27 SDK modules. Older toolchains are rejected at manifest resolution. |
| Additional checks | Release, AddressSanitizer, ThreadSanitizer, strict warnings-as-errors, five minimum-platform builds, and both consumers passed |
| Documentation check | `python3 scripts/check-docs.py` passes for the current tree |
| Merge status | Merged to `main` as `2bf8d02`; tag `0.6.0` has not been created. This release commit is tag-ready. |

The `0.6.0` release delta from `0.5.3` is documented in the changelog. The release code is `c46daa5`, merged as `2bf8d02`; the commit containing this page adds documentation only. Hosted CI passed on the release code. The tag itself has not been created.

The two XCTest skips are the opt-in external corpus and throughput benchmark. The full SwiftPM run's Swift Testing failure was `CleanRoomPrivilegeTests.privilegedFilesRejectBeforeCloneInBothTransactionEngines` at its own precondition: the requested permissions were `0o4644`, `0o2644`, and `0o6644`, but the sandbox host stripped the privilege bits and reported mode `420` decimal (`0o644`). The production rejection path is covered by the passing Xcode run at the same revision and by the clean-room record; it was not weakened or skipped in the Xcode run.

The `--disable-sandbox` flag was required because SwiftPM's manifest sandbox could not launch in this environment. That is a build-isolation limitation, not a package setting. Workspace-local module caches were used for the same reason.

## What was not run in this pass

Do not treat this status as evidence for:

- a tag-triggered `remote-tag-consumer` run; the job requires the published tag;
- the opt-in external corpus and throughput benchmark;
- device, minimum-OS, x86_64, or simulator runtime execution;
- an independent FFprobe/FFmpeg packet comparison for these edits;
- a release-signing, archive, or publication exercise beyond the hosted CI build and test.

## Previous recorded evidence

| Revision | Evidence | Result |
| --- | --- | --- |
| `c46daa5` | `0.6.0` release candidate, merged as `2bf8d02` | Hosted CI [run 40164904366](https://github.com/ChrisLloydME/TagLibAudioMetadata/actions/runs/40164904366): all nine executed jobs passed, with `remote-tag-consumer` skipped until tagging. |
| `102ddc7` | Release source campaign | Xcode 223 passed, 2 opt-in skips, 0 failed; SwiftPM Debug 222 passed, 2 skipped with the privilege test skipped; Release, ASAN, TSAN, strict, five platform builds, and both consumers passed. |
| `32d945d` | External pre-release assessment target | Xcode 223 passed, 2 opt-in skips, 0 failed; SwiftPM Debug with both opt-ins 225 passed; Release and sanitizers 223 passed, 2 skipped. The assessment held tagging for F-01/F-02. |
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
| Minimum toolchain | Swift tools 6.4 is required. Swift 6.0–6.3 cannot compile against current Apple SDKs and are rejected at manifest resolution. This is a deliberate compatibility narrowing; the macOS 13/iOS 16 deployment targets are unchanged. See [MIGRATION](MIGRATION.md#minimum-swift-tools) and [REM-2026-10-25](records/remediation/REM-2026-10-25-pre-release-assessment-repairs.md). |
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
- **NOT READY TO TAG** in the 2026-10-25 pre-release assessment describes `32d945d`; its F-01 and F-02 findings are repaired in the `0.6.0` release, and hosted CI passed on `c46daa5`. The tag itself is created only by the maintainer; Swift 6.0 is no longer a supported toolchain.
- No historical verdict is a current merge decision. A new release or merge decision requires a fresh review of the target revision.

## Updating this page

Update this page only when a validation campaign changes the latest known state. Include the revision, environment, command, opt-in state, counts, skips, and any environment-dependent failure. Do not turn it into a log; record a campaign in `docs/records/` and summarize the current state here.
