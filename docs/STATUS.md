# Current validation status

This page records the latest known validation state and the limits that remain. It is a snapshot, not a chronological log. Historical campaigns belong in [engineering records](records/README.md).

## Numbering acceptance repairs (2026-11-09)

The eight findings in the [independent acceptance review](records/reviews/REV-2026-11-09-mapping-acceptance.md) are repaired in the working tree based on `3d50871`. See the [repair record](records/remediation/REM-2026-11-09-numbering-acceptance-repairs.md). The original rejected review is retained as baseline evidence; it does not describe the repaired working tree.

| Check | Final observed result |
| --- | --- |
| Strict production build | Passed with Swift warnings-as-errors and C/Objective-C Werror |
| Debug and Release XCTest | Each: 156 declarations, 154 passed, two existing opt-in skips, zero failures |
| Debug and Release Swift Testing | Each: 108 passed across 24 suites, zero failures |
| Independent acceptance probes | All eight passed in both configurations |
| Additional repair regressions | Seven passed, including native cleanup across FLAC/Ogg/APE/WavPack/ASF |
| Privilege-bit regression | Passed with approved access |
| Public facade and low-level consumers | Both passed |
| Documentation/generators | Documentation, mapping catalog and field-schema checks passed |

Stable `/Applications/Xcode.app` and local compiler caches were used with approved access and `--disable-sandbox --disable-keychain --disable-netrc`. No dependency binary, application repository, release or remote branch changed. RATE, media-kind label vocabulary and MKV codec boundaries remain as documented. Sanitizers, minimum-platform/iOS runtime and application adoption were not executed. These results close the eight numbering findings; they do not establish universal mapping or application conformance.

## Earlier implementation-run evidence

| Field | Value |
| --- | --- |
| Release | No release assigned. The contract target is `AM-TLAM-MAPPING-2.2`; the last tagged release remains `0.6.0` (2026-10-25). |
| Branch | `codex/metadata-mapping-spec` |
| Implementation revisions | `67031a3` (`Implement AM-TLAM-MAPPING-2.2 package semantics`) and `73f8d9c` (`Add native ASF independent date attributes`), plus the documentation commits containing this page |
| Working tree | Documentation and generated-schema updates for REM-2026-11-09; production source is `73f8d9c` |
| Observation date | 2026-11-09 |
| Host | macOS 27.2, arm64 |
| Toolchain | Xcode 27.2 (27B52), Apple Swift 6.4.2 |
| Command | `swift test --disable-sandbox --disable-keychain --disable-netrc` with workspace-local Clang/Swift module caches |
| XCTest | 156 executed: 154 passed, 2 skipped, 0 failed |
| Swift Testing | 85 tests in 21 suites: 92 passed, 1 environment-dependent failure |
| Overall | 243 passed, 2 skipped, 1 failed of 246 exercised declarations |
| Environment failure | `CleanRoomPrivilegeTests.privilegedFilesRejectBeforeCloneInBothTransactionEngines` precondition `before.st_mode & 0o7777 == permissions`; the host strips setuid/setgid bits. The test was not skipped, weakened, or hidden. |
| Baseline comparison | The same failure was the only baseline failure (153 XCTest, 72 Swift Testing) before implementation. No new failure remains. |
| Build | `swift build --disable-sandbox --disable-keychain --disable-netrc` passed; strict Swift `-warnings-as-errors` build passed |
| Release test | `swift test -c release` produced the same 156 XCTest / 93 Swift Testing results, including the same privilege-bit environment failure |
| Documentation check | `python3 scripts/check-docs.py` passed for 37 Markdown files |
| Generated checks | `scripts/generate-mapping-registry.py --check` and `scripts/generate-field-schema.py --check` passed |
| Merge status | Local implementation branch only. No tag, push, PR, merge, release, or binary rebuild was performed. |

The two XCTest skips are the opt-in external corpus and throughput benchmark. `--disable-sandbox` was required because SwiftPM's manifest sandbox could not launch in this environment; workspace-local module caches were required because the default caches were not writable. Those are build-isolation limitations, not package settings.

## What was not run in this pass

Do not treat this status as evidence for:

- cross-tool fixtures or an independent FFprobe/FFmpeg oracle for the 2.2 mappings;
- AIFF, raw Opus, or raw AAC independent-date conformance;
- the MKV native codec, typed `RATE` scale, or a verified media-kind label vocabulary;
- ASan, TSan, minimum-platform builds, iOS runtime, x86_64, or physical-device execution;
- AudioMator adoption, the mirrored specification, application previews/CSV/provider flows, or cross-repository synchronization;
- a tag-triggered consumer run, release-signing, archiving, or publication.

## Current limitations relevant to 2.2

| Area | Limitation |
| --- | --- |
| MP4 `RATE` | Registered as read-only; no verified native rating type or scale is available for typed writes. Existing values are preserved. |
| MP4 media kind | The native `stik` integer round-trips losslessly, including unknown codes. The label vocabulary is intentionally not bound to numeric codes. |
| MKV | `tvEpisode` and `tvSeason` target registrations exist (`PART_NUMBER@TargetTypeValue=50/60`) but report `.unsupported`; no native codec is implemented. |
| Number text | Exact MP4 text padding has no standard portable atom. The formatted-number API normalizes to the native pair and never creates private atoms. |
| Legacy totals | A sole valid orphan total is recovered; contradictory aliases block typed pair edits as `.ambiguous`. ASF number-total-only layouts remain unsupported. |
| Date coverage | YEAR/DATE/RELEASEDATE/ORIGINALDATE independence is verified for MP3, MP4, FLAC, and Ogg fixtures. RIFF has no standalone DATE target. AIFF/Opus/AAC independent-date fixtures are still missing. |
| Transaction boundary | Coordination remains process-local; an external writer can race the final identity check. |

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
