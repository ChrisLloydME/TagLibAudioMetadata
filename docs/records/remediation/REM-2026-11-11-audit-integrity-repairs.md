# Independent-audit integrity repairs

| Field | Value |
| --- | --- |
| Record ID | `REM-2026-11-11-audit-integrity-repairs` |
| Type | Remediation / verification |
| Date | `2026-11-11` |
| Status | Final |
| Examined revision | Working tree based on `c3f1481e977b4abe3c750f3df968f920193df6eb`, with the source/test/documentation repairs described below; uncommitted |
| Branch | `codex/audit-integrity-repairs` |
| Environment | macOS 27.2 (26B123), Xcode 27.2 (27B52), Apple Swift 6.4.2, arm64; TagLib 2.3.1-r2 unchanged |
| Supersedes | Acceptance verdict of `AUD-2026-11-11-package-audit` for this repaired working tree; the historical audit remains unchanged |
| Superseded by | none |
| Related records | `AUD-2026-11-11-package-audit`; `REM-2026-11-11-native-mapping-followup` |
| Scope | Repair reproduced package defects and strengthen native persistence/test-gate evidence. Verify both package consumers and AudioMator through its existing local override. No publication, tag, dependency lock update or interactive UI acceptance. |

## Summary

The original 24 audit regressions/controls pass. Full strict Debug and Release gates both report `accepted: true`. The two P0 and three P1 findings no longer block this repaired source tree. Basic standalone Date/Content Group verification and additional defects found by the expanded matrices are repaired. Coverage limitations remain explicit; no universal field/format/platform certification is claimed.

## Scope and revision

The branch was created from the clean audit follow-up checkout at `c3f1481`. The changes remain in the working tree for maintainer review. No test asserting a reproduced production defect was skipped, deleted or marked expected failure. Three redundant optional checks in the original audit file were replaced with direct nonoptional bindings, and one unused write result was explicitly discarded to enable strict test compilation; functional expectations remain unchanged.

AudioMator used `.tmp/MappingIntegration.xcworkspace` to compile this package checkout. Its existing dirty documentation was preserved. No AudioMator application source, dependency requirement or lock was changed by this repair campaign.

## Method

Permanent audit probes, fresh-fixture parameterized lifecycle cases, independent native-byte/packet readers, complete mixed-framework gates, strict production compilation and two separate package consumer executables. No network service, user audio or interactive application session was used. Build/test commands ran with expanded filesystem access for caches and privilege-test prerequisites; package commands explicitly disabled the unavailable manifest sandbox.

## Findings and repairs

| Audit finding | Disposition | Repair and evidence |
| --- | --- | --- |
| F-01 / P0 | Fixed | Preserve all four unchanged date owners using native arrays/frames/atoms, including malformed text, duplicates, whitespace and absence. Unchanged invalid/multi-value YEAR bypasses new-value validation. Bind the preservation read to the file version. All original audit probes plus 26 Basic date cases pass across MP3/AAC/WAV/AIFF/TTA/DSF/DSDIFF/FLAC/APE/WavPack/Musepack/Vorbis/Opus. |
| F-02 / P0 | Fixed | `ENCODEDBY` belongs to Encoded By; `ENCODING`/`ENCODERSETTINGS` belong to Encoder Settings. Read/write ID3 TENC/TSSE and ASF WM/EncodedBy/WM/EncodingSettings independently. Audit Basic and semantic regressions pass; encoder fields are included in the 22-field ID3 matrices and seven-attribute ASF matrix. |
| F-03 / P1 | Fixed | Low-level MP4 replacement writes retire the edited owner aliases alongside canonical atoms, including typed store IDs and purchase date. Basic restores unchanged native owners/aliases exactly. Audit set/clear/low-level and untouched-alias regressions pass. |
| F-04 / P1 | Fixed | Normalize the pinned engine's signed IntPair projection to the stored unsigned 16-bit values at all bridge read/retention surfaces. Twelve cases test 32767/32768/65535 across semantic, Basic, structured and low-level writes with independent native-component assertions. Movement retains its separate 32767 maximum. |
| F-05 / P1 | Fixed and strengthened | Retain the auditor's fail-closed parser; require every audit test and all new named matrices and minimum parameterized counts. Twenty-two policy tests pass, including incomplete-evidence tampering and exact skip identities. |
| F-06 / P2 | Fixed | Include standalone Date and Content Group in Basic expectations and value lookup. Two regressions require correct expectations to pass and incorrect ones to produce verification failures. |
| F-07 / coverage | Expanded / bounded | Independent lifecycle matrices now cover every major writable container family represented below. These remain declared field subsets, not all field/value/version combinations. Raw whole-map operations and uncommon layouts retain specialized coverage. |
| F-08 / maintainability | Fixed within reported scope | Separate old Content Group/date operations into fresh fixtures; add malformed/truncated/extended-size MP4 oracle vectors. Compile both test configurations with warnings as errors, allowing visible DeprecatedDeclaration diagnostics only in the test target for deliberate obsolete-API compatibility checks. |

Additional reproduced defects repaired during expansion:

- Generic ID3-backed Basic writes created `TXXX:YEAR` and used engine DATE ownership. AIFF/TTA/DSD and WAV now use the same explicit versioned date owners as MPEG.
- The old preserved-value comparator trimmed whitespace and removed duplicates before checking exact arrays, producing false failures. Native preservation now compares exact arrays and absence.
- ASF Content Group projects to engine WORK; only that projection may change during a Content Group edit, and unsupported ASF Work is not populated from it.
- APE native `ALBUM ARTIST`/`MIXARTIST` project to engine `ALBUMARTIST`/`REMIXER`. Verification accounts for that dialect; independent expected native identities remain literal.
- Structured empty ID3 text/userText removal previously tried to verify a nonexistent present frame. It now verifies absence. The 396-case container matrix exercises this setup/removal behavior without bypassing verification.
- DSF/DSDIFF now accept native frame upserts needed for exact date replay; their descriptor/reference reflects this. Comment/lyric collection replacement remains explicitly unsupported and rejects safely.

## Verification

| Check | Result |
| --- | --- |
| Full Debug gate | Passed: 158 XCTest declarations (156 passed, 2 existing optional skips), 165 Swift Testing declarations in 36 suites, zero failures, `accepted: true` |
| Full Release gate | Same counts and zero failures, `accepted: true` |
| Original audit probes | All 24 passed in both full gates |
| Mandatory semantic lifecycle cases | MP4 258; FLAC 90; MP3/ID3v2.4 66; additional ID3 containers 396; APE-family 270; Ogg Vorbis/Opus 180; ASF 21 |
| Additional parameterized checks | 86 wrong-kind, 5 unsupported, 26 Basic date-preservation, 2 Basic verification and 12 MP4 pair-boundary cases, plus ordinary alias/oracle regressions |
| Test gate policy | 22 Python tests passed |
| Strict production build | Passed with `-Xswiftc -warnings-as-errors -Xcc -Werror`; no diagnostic exception |
| Package consumers | Facade: 37 readable extensions; low-level: OK |
| AudioMator core | 62 passed, zero failures |
| AudioMator local-override Debug | 574 app-hosted tests passed, zero failures/skips, serial |
| AudioMator local-override Release | Unsigned universal build and macOS 15.0 artifact validation passed |
| Documentation | 52 Markdown files passed; API, field, format and mapping generators up to date; diff whitespace check passed |
| Privilege rejection | Passed unchanged in both package gates under expanded filesystem access; no environment skip or weakened precondition |

Commands:

```sh
TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh debug
TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh release
swift build --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror
python3 -m unittest discover -s scripts/tests
python3 scripts/check-docs.py
swift run --disable-sandbox --disable-keychain --disable-netrc --package-path IntegrationTests/Consumer TagLibAudioMetadataConsumer
swift run --disable-sandbox --disable-keychain --disable-netrc --package-path IntegrationTests/Consumer TagLibAudioMetadataLowLevelConsumer
```

AudioMator commands used the stable toolchain, `.deriveddata-codex`, unsigned builds and the ignored local override:

```sh
swift test --filter AudioMatorCoreLogicTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace .tmp/MappingIntegration.xcworkspace -scheme AudioMator -configuration Debug -destination 'platform=macOS' -derivedDataPath .deriveddata-codex -parallel-testing-enabled NO -maximum-parallel-testing-workers 1 CODE_SIGNING_ALLOWED=NO test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace .tmp/MappingIntegration.xcworkspace -scheme AudioMator -configuration Release -destination 'generic/platform=macOS' -derivedDataPath .deriveddata-codex CODE_SIGNING_ALLOWED=NO build
bash scripts/validate-macos-artifact.sh .deriveddata-codex/Build/Products/Release/AudioMator.app 15.0
```

Evidence: package Debug `.build/test-evidence/debug-20261111-124030-69547/`; Release `.build/test-evidence/release-20261111-124120-69890/`. Local command logs: `/tmp/taglib-audit-final-{debug,release,strict,consumer,lowlevel}.log`, `/tmp/audiomator-audit-repairs-{core,override,release,artifact}.log`. Build/test output remains ignored and uncommitted.

## Remaining limitations

- No hosted CI, sanitizer, minimum-OS/device or package x86_64 runtime campaign was run for this tree. Existing CI configuration is not new execution evidence.
- The native probes are bounded test readers. Ogg checks packet/comment structure, not CRC or decoder correctness. The ID3 probes restrict versions/encodings/flags; this matrix is ID3v2.4 evidence.
- Full field × format × tag-version × public API coverage remains a larger cross-product. Raw whole-map replacement and arbitrary binary structures are not universally certified.
- No new external-tool oracle campaign was run. Some external readers still sign-extend MP4 pair components above 32767; the package's repaired unsigned readback does not change them.
- DSD comment/lyric collection replacement, unverified ID3v2.3 independent date writes, MKV native codec and typed MP4 RATE writes retain their documented capability restrictions.
- Local override acceptance does not establish resolution of a published 0.7.1 tag, signing, notarization, distribution readiness or maintainer UI acceptance. Publication remains maintainer-owned.

## References

- [Original immutable audit](../audits/AUD-2026-11-11-package-audit.md)
- [Current acceptance strategy](../../operations/MAPPING_TEST_STRATEGY.md)
- [Preservation contract](../../explanation/PRESERVATION.md)
- [Current status](../../operations/STATUS.md)
