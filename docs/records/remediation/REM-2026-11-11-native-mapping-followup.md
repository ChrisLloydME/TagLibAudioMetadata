# Native mapping follow-up repairs

| Field | Value |
| --- | --- |
| Record ID | `REM-2026-11-11-native-mapping-followup` |
| Type | Remediation / verification |
| Date | 2026-11-11 |
| Status | Final for the recorded local scope; publication pending |
| Examined revision | `e0a4091` plus retained test-system and functional working-tree changes |
| Branch | `codex/native-mapping-followup-repairs` |
| Environment | macOS arm64, stable Xcode 27.2, Apple Swift 6.4.2 |
| Supersedes | none; resolves implementation findings from `REM-2026-11-10-expanded-test-system` |
| Superseded by | none |
| Scope | Seven failing field/format combinations, related Basic/bridge writes, native sibling preservation and MP4 Movement range; no sanitizer/platform certification or publication |

## Summary and method

The expanded test-system matrices originally failed with 19 issues. All original matrix expectations remain intact. Exact independent native oracles now pass for MP4 Encoded By, Encoder Settings, Movement Number/Count; FLAC Content Group/Encoder Settings; and ID3v2.4 Content Group.

Content Group/Grouping/Work are read from their exact native owners in ID3 and native-text containers. MP4 Encoded By no longer falls back to ©too; Encoder Settings reads canonical ©too or its own compatible freeforms. Native-text Encoder Settings reads ENCODING instead of relying on a bridge projection for another semantic identity. Generic legacy bridge behavior for other families (including ASF) was retained after the full suite exposed an overbroad intermediate read change; that intermediate change was reverted before final acceptance.

Known engine projections (ID3 TIT1 → WORK; MP4 ©too → ENCODING) are allowed only for edits of their actual owner, while exact native siblings and compatible alias arrays remain protected. Editing Encoded By does not consume a legacy Encoder Settings freeform.

MP4 Movement components use registry-planned independent integer atoms. Mixed Track/Movement patches no longer route movement through the shared number-pair mechanism or rewrite its untouched sibling. Basic and low-level pair bridge writers also use the canonical atoms and retire owned legacy freeforms. Additional regressions cover mixed patches, Basic/low-level entry points, independent legacy encoder storage and ID3 siblings.

## Integer boundary discovered during verification

This native MP4 codec reliably round-trips nonnegative signed 16-bit Movement values. Zero, 255, 256 and 32767 passed native-byte and semantic checks. Values 32768, 65535, 65536 and Int32.max are explicitly rejected rather than truncated or stored in freeforms. Semantic, Basic and structured facade entry points preflight this format-specific constraint; corresponding bridge writers guard it too. Tests verify rejected compound writes leave original file bytes unchanged. Global semantic integer constraints remain broader because other formats differ.

## Final verification

Both complete Debug and Release gate runs passed: 158 XCTest executed (156 passed, two existing opt-in skips), plus 128 Swift Testing declarations in 31 suites. Required suites were present, no unexpected skips were accepted, and both gates wrote `accepted: true`. Logs: `/tmp/taglib-native-repairs-final-debug.log` and `/tmp/taglib-native-repairs-final-release.log`.

Strict package compilation passed with `-Xswiftc -warnings-as-errors -Xcc -Werror`: `/tmp/taglib-native-repairs-final-strict.log`. Consumer and AudioMator acceptance are recorded in the final addendum below. Package tests used explicit `TAGLIB_DISABLE_MANIFEST_SANDBOX=1` for local cache/sandbox constraints. No release version, tag, lock update, binary-framework rebuild or publication occurred; bridge source is compiled normally by SwiftPM.

## Consumer and final hygiene addendum

Both independent consumers passed: `TagLibAudioMetadataConsumer` reported 37 readable extensions (`/tmp/taglib-native-repairs-consumer.log`), and `TagLibAudioMetadataLowLevelConsumer` passed (`/tmp/taglib-native-repairs-lowlevel-consumer.log`). AudioMator resolved this local checkout through its existing ignored override workspace and passed all 574 serial app-hosted tests with zero failures (`/tmp/audiomator-native-repairs-final.log`). No normal-project dependency pin or lock was changed; this result does not imply that published 0.7.1 contains these repairs.

Thirteen gate-policy tests passed, documentation checks passed for 50 Markdown files, and `git diff --check` passed. No interactive UI smoke test, sanitizers, alternate-platform runtime run, commit or publication was performed. Previously uncommitted test-system work was retained in the functional branch.
