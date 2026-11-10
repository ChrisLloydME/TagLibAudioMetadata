# Current validation status

This page records the latest known validation state and the limits that remain. It is a snapshot, not a chronological log. Historical campaigns belong in [engineering records](../records/README.md).

The current documentation describes the working tree, including unreleased native Mapping consistency repairs on top of `0.7.0`. The latest published package remains `0.7.0`. Results below are the latest observed Debug and Release runs after the native Mapping repairs (2026-11-10).

## Latest observed run (2026-11-10)

| Field | Value |
| --- | --- |
| Source revision | `codex/mapping-conformance-repairs`, based on `0f89fbe`; native Mapping/read/write/verification repairs and regression matrix |
| Branch | `codex/mapping-conformance-repairs` |
| Host | macOS 27.2, arm64 |
| Toolchain | Xcode 27.2 (27B52), Apple Swift 6.4.2 |
| Debug command | `swift test --disable-sandbox --disable-keychain --disable-netrc` with workspace-local Clang/Swift module caches |
| Release command | `swift test -c release --disable-sandbox --disable-keychain --disable-netrc` with the same caches |
| Debug XCTest | 158 executed: 156 passed, 2 opt-in skips, 0 failures |
| Release XCTest | 158 executed: 156 passed, 2 opt-in skips, 0 failures |
| Debug Swift Testing | 112 tests in 25 suites: all passed |
| Release Swift Testing | 112 tests in 25 suites: all passed |
| Environment failure | None in these runs, executed with expanded filesystem access. The privilege rejection test passed unchanged. |
| Production source changes | Native YEAR/DATE ownership, exact raw replay, untouched date verification, active-family comments, qualified UFID, primary-family capabilities, and version-aware v2.3 read-only gates. |
| Strict build | `swift build -Xswiftc -warnings-as-errors -Xcc -Werror` passed in this pass. |
| Documentation check | `python3 scripts/check-docs.py` passed for 45 Markdown files. |
| Generated checks | `generate-api-reference.py --check`, `generate-field-schema.py --check`, `generate-format-matrix.py --check`, and `generate-mapping-matrix.py --check` passed. |
| Consumers | Both `TagLibAudioMetadataConsumer` and `TagLibAudioMetadataLowLevelConsumer` passed against this working tree. |

The two XCTest skips are the opt-in external corpus and throughput benchmark. `--disable-sandbox` was required because SwiftPM's manifest sandbox could not launch in this environment; workspace-local module caches were required because the default caches were not writable. Those are build-isolation limitations, not package settings.

Earlier restricted runs failed the privilege test's own precondition because the host stripped setuid/setgid bits after `chmod`. The latest runs used expanded filesystem access and passed the unchanged test; it was not skipped or weakened.

## Hosted release-candidate verification

[CI run 42604530085](https://github.com/ChrisLloydME/TagLibAudioMetadata/actions/runs/42604530085) passed on merged revision `bca046343309fdc9f5e7618900a1eb5b67bae418`. All nine executed jobs succeeded: strict build/tests/consumers/link audit, Release tests, AddressSanitizer, ThreadSanitizer, and the five minimum-platform builds (macOS 13 arm64/x86_64, iOS 16 arm64, iOS 16 Simulator arm64/x86_64). The `remote-tag-consumer` job was skipped because this was a branch push; it runs after publishing the tag.

This hosted run is historical evidence for 0.7.0, not for the current repair branch. Current repairs change production code and have local strict/Debug/Release/consumer evidence above; a new hosted run is separate evidence.

## Remaining verification limits

Do not treat the local or hosted runs above as evidence for:

- minimum-OS runtime, iOS runtime, x86_64 runtime, or physical-device execution;
- cross-tool fixtures or an independent FFprobe/FFmpeg oracle for the 2.2 mappings;
- AIFF, raw Opus, or raw AAC independent-date conformance;
- the MKV native codec, typed `RATE` scale, or a verified media-kind label vocabulary;
- AudioMator adoption, the mirrored specification, application previews/CSV/provider flows, or cross-repository synchronization;
- a tag-triggered consumer run, release signing, archiving, or publication.

## Current limitations relevant to 2.2

| Area | Limitation |
| --- | --- |
| MP4 `RATE` | Registered as read-only; no verified native rating type or scale is available for typed writes. Existing values are preserved. `FormatCapability.writeSupport(for: .rate)` returns `.unsupported`, consistent with the schema and typed-write rejection. |
| MP4 media kind | The native `stik` integer round-trips losslessly, including unknown codes. The label vocabulary is intentionally not bound to numeric codes. |
| MKV | `tvEpisode` and `tvSeason` target registrations exist (`PART_NUMBER@TargetTypeValue=50/60`) but report `.unsupported`; no native codec is implemented. |
| MP4-exclusive Basic fields | Readable through `BasicMetadata`, but `replaceBasicMetadata`/`updateBasicMetadata` do not write them; use `MetadataPatch` or structured writes. |
| Number text | Exact MP4 text padding has no standard portable atom. The formatted-number API normalizes to the native pair and never creates private atoms. |
| Legacy totals | A sole valid orphan total is recovered; contradictory aliases block typed pair edits as `.ambiguous`. ASF number-total-only layouts remain unsupported. |
| ID3v2.3 dates | Exposed read-only until a verified independent native codec exists. `id3v2MajorVersion` identifies the concrete tag; typed and Basic date edits reject before mutation. Legacy engine projections are not verified native date reads. |
| Date coverage | YEAR/DATE/RELEASEDATE/ORIGINALDATE independence is verified for MP3, MP4, FLAC, and Ogg fixtures. RIFF INFO has no native DATE key; WAV writes DATE through ID3v2. AIFF/Opus/AAC independent-date fixtures are still missing. |
| Transaction boundary | Coordination remains process-local; an external writer can race the final identity check. |
| Structured comments/lyrics | Replace-all is supported on ID3-backed formats and TrueAudio; MP4 ignores structured comments/lyrics; APE-family and FLAC/Ogg reject them. |
| YEAR validation | `replaceBasicMetadata`/`updateBasicMetadata` reject non-date YEAR text with `MetadataValidationError.invalidYearText`; the typed `.year` patch path does not run that Basic-specific validator. |
| Bridge model | `writeTagMetadata` cannot write the MP4-exclusive facade fields because `TagLibAudioMetadata` has no matching properties. |

## Previous recorded evidence

| Revision | Evidence | Result |
| --- | --- | --- |
| `c46daa5` | `0.6.0` release candidate, merged as `2bf8d02` | Hosted CI run 40164904366: all nine executed jobs passed, with `remote-tag-consumer` skipped until tagging. |
| `102ddc7` | Release source campaign | Xcode 223 passed, 2 opt-in skips, 0 failed; SwiftPM Debug 222 passed, 2 skipped with the privilege test skipped; Release, ASAN, TSAN, strict, five platform builds, and both consumers passed. |
| `32d945d` | External pre-release assessment target | Xcode 223 passed, 2 opt-in skips, 0 failed; SwiftPM Debug with both opt-ins 225 passed; Release and sanitizers 223 passed, 2 skipped. The assessment held tagging for F-01/F-02. |
| `1fff9f0` | Clean-room remediation final campaign | 208 tests; Debug with both opt-ins, Release, ASAN, TSAN, Xcode, five strict platform builds, consumers, and independent eight-format checks passed. |
| `873cb3e` | Independent audio-identity audit | 222 discovered; 220 passed, 2 opt-in skips, 0 failures in Xcode Debug. iOS Simulator build passed. |

These are historical snapshots at the revisions shown. They are not current merge approvals and do not prove the current documentation or production tree.

## How to interpret prior assessments

- **READY WITH CAVEATS** in the clean-room remediation describes revision `1fff9f0`, not the current HEAD.
- **READY WITH CAVEATS** in the audio-identity audit describes `873cb3e` and was conditional on fixing F1 and qualifying the documentation. F1 was fixed in `bedd725`; F2/F3 remain limitations.
- **NOT READY TO MERGE** in the clean-room audit describes `615bc8c` and was superseded by the remediation.
- **NOT READY TO TAG** in the 2026-10-25 pre-release assessment describes `32d945d`; its F-01 and F-02 findings are repaired in the `0.6.0` release, and hosted CI passed on `c46daa5`.
- No historical verdict is a current merge decision. A new release or merge decision requires a fresh review of the target revision.

## Updating this page

Update this page only when a validation campaign changes the latest known state. Include the revision, environment, command, opt-in state, counts, skips, and any environment-dependent failure. Do not turn it into a log; record a campaign in `docs/records/` and summarize the current state here.
