# Minimum toolchain and changelog repairs — 2026-10-25

| Field | Value |
| --- | --- |
| Record ID | `REM-2026-10-25-pre-release-assessment-repairs` |
| Type | Remediation |
| Date | `2026-10-25` |
| Status | Final |
| Examined revision | External assessment target `32d945d`; repair commit `102ddc7`; documentation tree containing this record |
| Branch | `fix/pre-release-assessment-f01-f02` |
| Environment | macOS 27.0.1 (26A434), arm64; Xcode 27.1 (27A9275); Apple Swift 6.4; Swift 6.0.3, 6.2.4, and 6.3 release toolchains for minimum-version probes |
| Supersedes | `none` |
| Superseded by | `none` |
| Related records | [`REM-2026-10-19-clean-room`](REM-2026-10-19-clean-room.md), [`AUD-2026-10-19-audio-content-identity`](../audits/AUD-2026-10-19-audio-content-identity.md), [current status](../../STATUS.md) |
| Scope | Repair of the external 2026-10-25 pre-release assessment's F-01 minimum-toolchain finding and F-02 changelog release-boundary finding. No production or test Swift source was changed. This is not a new format, security, or release-certification review. |

## Summary

F-01 is closed by raising the package's minimum Swift tools requirement from 6.0 to 6.4. Direct probes showed that the older toolchains cannot compile against the current Apple SDKs: Swift 6.0.3 and 6.2.4 fail on SDK 27's `-target-arch-variant` flag, and Swift 6.3 also fails because its Clang build does not support that SDK flag. Swift 6.0 and 6.1 additionally reject the source syntax that the 6.0 manifest admitted. Swift 6.4 builds and tests the package. The macOS 13 and iOS 16 deployment targets are unchanged; only the required toolchain changed.

F-02 is closed by rewriting the changelog around release deltas instead of dated work sections. `[Unreleased]` now contains only changes since 0.5.3, grouped as Added, Changed, and Fixed. The entries that were beneath `[Unreleased]` at tag 0.5.3 are now part of the 0.5.3 section, and the dated work-log subsections and provenance wrapper are gone. Historical 0.5.1 and 0.5.2 summaries remain short, version-scoped notes.

The full Swift 6.4 matrix passed: Xcode 223 of 225 with two opt-in skips; SwiftPM Debug 222 of 224 with the privilege test skipped; Release, AddressSanitizer, ThreadSanitizer, strict warnings-as-errors, five minimum-platform builds, and both consumers. The full SwiftPM run still reports the known environment-dependent privilege-bit precondition failure. No production or test Swift source changed, so the package's runtime behavior is unchanged.

## Scope and revision

The external assessment examined `32d945d` (`76c51a902262375a4de4675bdf3943a7c8e0b4d3`) and release `0.5.3` (`03473c9`). This record covers its F-01 and F-02 findings and the manifest, documentation, CI, changelog, status, and record changes needed to close them. It does not re-audit transaction behavior, formats, preservation, audio continuity, or the prebuilt TagLib binary.

The repair is `102ddc7` on `fix/pre-release-assessment-f01-f02`. The branch was created from `32d945d`. No tag, merge, push, or publication was performed.

## Method

- Read the assessment's F-01 and F-02 text and compared the `0.5.3` changelog with the current tree.
- Downloaded the notarized Swift 6.0.3, 6.2.4, and 6.3 release packages from swift.org, verified their Apple signatures, and used their compilers directly.
- Probed each older compiler with a minimal Foundation import against the installed macOS 27 SDK, and probed Swift 6.0.3 with the type-level `nonisolated` and trailing-comma syntax.
- Built and tested the repaired package with the installed Swift 6.4 toolchain, including the Xcode suite and the SwiftPM verification matrix.
- Rewrote the changelog from `git log 0.5.3..HEAD` and `git diff 0.5.3..HEAD`, keeping release-scoped historical summaries.

## Findings

### F-01 — The advertised Swift 6.0 minimum was inconsistent with source and current SDKs

- **Severity:** High for consumers admitted by the manifest
- **Confidence:** Confirmed by direct compiler probes
- **Status:** Fixed
- **Evidence:** The package declared `swift-tools-version: 6.0`, but the source used type-level `nonisolated` declarations (`MetadataAudioContentIdentity.swift:40` and `TagLibMetadataManager.swift:15`) from SE-0449, which Swift 6.0.3 rejects, and the tests used trailing commas in call argument lists, which Swift 6.0.3 also rejects. More fundamentally, the older compilers cannot import the current SDK:

  ```text
  Swift 6.0.3: error: 'nonisolated' modifier cannot be applied to this declaration
  Swift 6.2.4: error: unknown argument: '-target-arch-variant'
  Swift 6.3:   error: unknown argument: '-target-arch-variant'
               error: no such module 'CryptoKit'
  Swift 6.4:   build and full test suite passed
  ```

  Swift 6.2.4 reports Apple Clang 17.0.0; Swift 6.3 reports Apple Clang 21.0.0 but still lacks the SDK flag. The installed macOS 26.5 and 27 SDKs therefore require the Swift 6.4 toolchain.
- **Impact:** A consumer on Swift 6.0–6.3 could resolve the package through its manifest and then fail much later during compilation or SDK import. Raising the minimum now rejects those toolchains at manifest resolution, and the package no longer claims a compiler it cannot support.

### F-02 — The changelog described dated work rather than release deltas

- **Severity:** Medium
- **Confidence:** Confirmed by tag and tree comparison
- **Status:** Fixed
- **Evidence:** `git show 0.5.3:CHANGELOG.md` contains `[Unreleased]` followed by `### Fixed` entries that were already present in the tagged source. After the tag, the changelog grew date-named sections such as `Documentation system completion — 2026-10-24`, `Audio-content continuity — 2026-10-19`, and `Remediation — 2026-10-18`, so `[Unreleased]` read as a chronological work log rather than a comparison with 0.5.3.
- **Impact:** The next release notes would have mixed already-shipped 0.5.3 changes with post-tag changes and described internal work dates instead of the user-visible delta from the previous version.

## Repairs or recommendations

- Raised `swift-tools-version` from 6.0 to 6.4 in `Package.swift` and the consumer integration manifest.
- Aligned the README, installation, API, development, and migration documentation with Swift tools 6.4, and recorded the reason for the narrowing in the migration guide and manifest comment.
- Moved all package jobs in `.github/workflows/ci.yml` to the Swift 6.4 runner and added an explicit `swift package dump-package` gate.
- Rewrote `CHANGELOG.md` by release: `[Unreleased]` is now the delta since 0.5.3; 0.5.3 absorbs the entries that shipped in it; 0.5.1 and 0.5.2 remain short reconstructed summaries; the date-named work sections and the `Historical release provenance` wrapper were removed.
- Left production and test Swift source unchanged. The earlier investigation's syntax edits were reverted because they were no longer needed once the minimum moved to a toolchain that accepts both forms.

## Verification

| Check | Result | Counts / limits |
| --- | --- | --- |
| Swift 6.0.3 source-syntax probe | Failed as expected | Type-level `nonisolated` and trailing-comma calls reject. This toolchain is no longer advertised. |
| Swift 6.2.4 SDK 27 Foundation import | Failed as expected | Apple Clang 17.0.0; `-target-arch-variant` is unknown. This toolchain is no longer advertised. |
| Swift 6.3 SDK 27 Foundation import | Failed as expected | Apple Clang 21.0.0 still lacks `-target-arch-variant`; `CryptoKit` is unavailable. This toolchain is no longer advertised. |
| Swift 6.4 `swift package dump-package` | Passed | The manifest with tools 6.4 loads successfully. |
| Swift 6.4 Xcode `RunAllTests` | Passed | 225 declarations: 223 passed, 2 opt-in skips, 0 failed; privilege regression passed. |
| Swift 6.4 SwiftPM Debug, full suite | 1 environment-dependent failure | 222 passed, 2 opt-in skips, 1 privilege-bit precondition failure of 225. The sandbox strips setuid/setgid bits. |
| Swift 6.4 SwiftPM Debug, `--skip CleanRoomPrivilegeTests` | Passed | 222 passed, 2 skipped, 0 failed of 224 exercised declarations. |
| Swift 6.4 Release, privilege test skipped | Passed | 153 XCTest: 151 passed, 2 skipped; 71 Swift Testing tests passed. |
| AddressSanitizer, privilege test skipped | Passed | Same counts; no sanitizer diagnostic. |
| ThreadSanitizer, privilege test skipped | Passed | Same counts; no sanitizer diagnostic. |
| Strict warning build | Passed | Swift warnings-as-errors and C/Objective-C/C++ `-Werror`. |
| Five minimum-platform builds | Passed | macOS 13 arm64/x86_64; iOS 16 device arm64; iOS 16 simulator arm64/x86_64. Compile/link evidence only. |
| Facade and low-level consumers | Passed | Both integration executables ran against the repaired package. |
| Documentation checker | Passed | `python3 scripts/check-docs.py` over the tree containing this record. |

## Remaining limitations

- **Deliberate compatibility narrowing.** Swift 6.0–6.3 consumers are now rejected. They must update to Xcode 27/Swift 6.4. The macOS 13 and iOS 16 deployment targets themselves are unchanged.
- **Runtime coverage is unchanged.** Device, minimum-OS, x86_64, and simulator runtime execution were not performed; the five platform builds are compile/link evidence.
- **The old-toolchain probes are compile-only.** They establish why those toolchains are no longer supported, not that any package version runs correctly on them.
- **No release decision is made here.** No tag was created. The pre-release assessment's release hold and any final release approval remain maintainer decisions.

## Addendum — 0.6.0 release readiness (2026-10-25)

The repair was merged through PR #14 as `2bf8d02`. The release candidate adds `c46daa5`, which fixes Swift 6.4 test-bundle discovery in the CI dynamic-link audit; package and test source were unchanged. Hosted CI run [40164904366](https://github.com/ChrisLloydME/TagLibAudioMetadata/actions/runs/40164904366) passed all nine executed jobs on `c46daa5`; `remote-tag-consumer` was skipped because no tag existed.

The release commit names the reviewed delta `[0.6.0] - 2026-10-25` in the changelog and adds documentation only. No remaining release blocker was identified within this record's scope. The runtime and platform limits above remain. The tag itself has not been created; that release action remains with the maintainer.

## References

- Commits: `32d945d` (assessment target); `102ddc7` (`Require Swift 6.4 and rewrite changelog by release`); `c46daa5` (`Discover the SwiftPM test bundle in the link audit`); `2bf8d02` (merge of PR #14).
- Manifest and integration: `Package.swift`; `IntegrationTests/Consumer/Package.swift`; `.github/workflows/ci.yml`.
- Documentation: [`CHANGELOG.md`](../../../CHANGELOG.md); [`docs/MIGRATION.md`](../../MIGRATION.md); [`docs/STATUS.md`](../../STATUS.md); [`README.md`](../../../README.md).
- External evidence: the 2026-10-25 pre-release assessment (`ASSESSMENT.md`, outside this repository) and the notarized Swift 6.0.3, 6.2.4, 6.3, and 6.4 toolchain packages from swift.org.
