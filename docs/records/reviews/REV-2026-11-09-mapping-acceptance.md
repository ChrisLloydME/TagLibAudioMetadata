# REV-2026-11-09 — independent mapping acceptance review

- Record ID: REV-2026-11-09
- Date: 2026-11-09
- Type: Independent acceptance review
- Examined revision: `3d5087123296c1320b799daac57e457fd1209f7d`, branch `codex/metadata-mapping-spec`
- Status: Final review; acceptance rejected; findings open
- Target: AM-TLAM-MAPPING-2.2 and the package implementation prompt

## Verdict and scope

The package is not accepted as a complete contract implementation. Eight independent temporary-fixture tests fail, including native data removal, cross-group cleanup and stale-plan execution. These are reproducible implementation failures, not the previously documented privilege-bit environment limitation. Do not release or adopt the cleanup API until they are resolved.

The implementation's existing default tests pass in this review environment, including the privilege-bit test with appropriate access. This establishes that the original suite misses the findings below, not that the findings are harmless. The intentional RATE/media-label/MKV limitations remain separate from these unintentional defects.

The repository initially contained uncommitted alias-collision and coverage changes, and advanced during initial inspection. After the maintainer confirmed the other agent had stopped, the reviewed final HEAD was 3d50871. Review probes were added afterward; no production source was modified by this reviewer. No sibling application, real music library, release, tag or remote branch was modified.

## Reproducible findings

All reproduction tests are in [IndependentAcceptanceProbes.swift](../../../Tests/TagLibAudioMetadataTests/Integration/IndependentAcceptanceProbes.swift). Each writes only a temporary copy of a package fixture. Keep these tests enabled during repairs; do not relax their expected preservation rules.

### F1 — P1: ordinary Xiph numbers are erased by useNative cleanup

Location: `MetadataNumberInventory.swift:467`, `:534`, `:585` and `:642`. Native values are extracted only from MP4 pairs or ID3 TRCK/TPOS. Ordinary FLAC TRACKNUMBER/TRACKTOTAL and DISCNUMBER/DISCTOTAL become recovered aliases with nil nativeValue. A useNative plan therefore selects nil values; execution turns them into zeros and removes both pairs. The shared alias list also pulls disc keys into track cleanup, and nil expected components bypass verification.

Reproduction: seed FLAC track 3/12 and disc 1/2 in ordinary fields; plan useNative for only the track group; apply. Both ordinary pairs are lost instead of remaining intact. Test: `xiphNativeCleanupMustNotEraseOrdinaryTotals`.

Repair gate: classify native fields per actual family; retain component presence; do not interpret missing nativeValue as a removal request. Restrict removal sets and verification to selected groups and assert exact retained sibling values, including nil/absence semantics. Repeat on APE and ASF in addition to the demonstrated FLAC case.

### F2 — P1: track-only cleanup deletes a disc alias

Location: `MetadataNumberInventory.swift:503–515`, `:554–557`. Both group inventories receive the same combined legacyAliasIdentities array. Selecting track can consequently schedule disc identities for removal.

Reproduction: MP4 trkn=3/0 plus TRACKTOTAL=12, disk=1/2 plus DISCTOTAL=99; plan useLegacy for track only. The plan includes the disc freeform and application removes it successfully. Test: `trackCleanupMustPreserveDiscAliases` verifies both the invalid plan and actual lost disc data.

Repair gate: collect group-local identities from the start, preserve exact native identity and value arrays, reject cross-group removals, and verify the untouched group before publication. Do not fix this only by suppressing a warning.

### F3 — P1: callers can replace the captured plan version with a newer token

Location: `MetadataNumberInventory.swift:580–586`. `expectedVersion ?? plan.fileVersion` permits a new caller-supplied version to override the version on which the plan was based.

Reproduction: prepare a replacement plan for track 4/15 from track 3/12; externally change total to 20; obtain the new token and pass it to applyNumberNormalization with the old plan. The stale plan commits instead of rejecting, overwriting the intervening edit. Test: `stalePlanMustNotBeRevalidatedByNewVersion` verifies an unexpected successful commit and changed bytes.

Repair gate: bind execution to plan.fileVersion; if an additional expectedVersion is supplied, require equality with that captured token. An explicitly rebased plan must be rebuilt and re-previewed, not revalidated by changing its token. Preserve original bytes on rejection.

### F4 — P1: native-versus-alias conflicts are silently ignored

Location: `MetadataNumberInventory.swift:218–224`, `:268–274`. A positive native value returns immediately without inspecting any alias candidate. The inventory discards conflict evidence and lets later native pair mutation remove the contradictory alias.

Reproduction: MP4 trkn=3/12 and TRACKTOTAL=99. The total is reported native instead of ambiguous; an ordinary track-number edit succeeds and changes the file instead of requiring resolution. Test: `nativeAndAliasConflictMustBeAmbiguous`.

Repair gate: inspect all candidates even when native is present; retain native as the displayed authority while reporting ambiguity and exact alternative values. A pair edit must require an explicit resolution when candidates disagree; unrelated edits must preserve all values.

### F5 — P2: private-only formatted numbers cannot be restored

Location: `MetadataNumberInventory.swift:474–516`, `:531–547`. Private text is parsed into privateTexts, but its values never participate in recoverable number/total candidates. useLegacy reads only component inventories, so a private-only 03/12 cannot produce a restore plan.

Reproduction: remove trkn and retain only AUDIOMATOR_TRACKNUMBER_TEXT=03/12. The inventory sees the private atom, but the explicit useLegacy plan has no 3/12 pair. Test: `privateOnlyNumbersMustBeRecoverable`.

Repair gate: add an explicit private-only recovery candidate with exact namespace/type/array provenance, strictly validate and bound components, allow a selected candidate to populate a restore plan, and verify native persistence before retiring its sole source. Cover both namespaces, disagreement and malformed/multi-value text.

### F6 — P2: disc replacement policy actually changes the planned track values

Location: `MetadataNumberInventory.swift:548–550`. The replace policy always assigns the replacement to track, ignoring groups. With groups=[disc], the disc remains unchanged and verification complains that the unselected track did not become the replacement.

Reproduction: native track=3/12, disc=1/2; request replace(4,7) for disc only. The operation fails verification rather than producing disc=4/7. Test: `discReplacementMustReplaceDiscNotTrack`.

Repair gate: apply replacement to the explicitly selected group or make replacement values keyed by group. Do not validate an unselected group against replacement values. Cover track, disc, both and empty group selection explicitly.

### F7 — P2: an ambiguous disc blocks an unrelated track edit

Location: `MetadataSnapshotPatch.swift:485–488`; also `MetadataNumberInventory.swift:538–545`. The typed planner resolves both groups before checking which group was requested. Plan useLegacy likewise checks all groups unconditionally.

Reproduction: valid track=3/12; no native disc; DISCTOTAL=2 and TOTALDISCS=9. Changing only track to 5 throws ambiguousNumberRecovery for discTotal. Test: `unresolvedDiscMustNotBlockTrackEdit`.

Repair gate: resolve, validate and mutate only touched groups; retain every unresolved unselected group exactly. Apply this to typed, formatted-number, Basic and normalization APIs.

### F8 — P2: the old total-only prohibition remains in the shared validator

Location: `MetadataSnapshotPatch.swift:268–274`. validateNativeNumberPair still rejects a missing number with a retained total for MP4 and all ID3-backed families. This contradicts the target native MP4 0/total sentinel and the declared verified text-pair total-only route.

Reproduction: native MP4 trkn=3/12; request removal of .track only. It throws unsupportedPartialPairRemoval instead of persisting trkn first=0, second=12. Test: `mp4RetainedTotalMustAllowNumberRemoval`.

Repair gate: replace the family-wide prohibition with exact codec capability and bounds validation. Cover total-only creation, number removal preserving total, total removal preserving number, full removal and independent native readback. Do not remove this check wholesale without confirming each family codec; unsupported layouts must remain honestly rejected.

## Verification actually executed

Stable `/Applications/Xcode.app` was selected. Initial sandboxed execution failed on manifest/cache access after waiting for an earlier SwiftPM process; it did not establish a source-code failure. With approved access, the following command ran against the final implementation plus the eight review probes:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH="$PWD/.build/modulecache" \
SWIFT_MODULECACHE_PATH="$PWD/.build/modulecache" \
swift test --disable-sandbox --disable-keychain --disable-netrc
```

| Check | Observed result |
| --- | --- |
| Full Debug build/test invocation | Build succeeded; test invocation failed on review probes |
| Original XCTest | 156 declarations: 154 passed, 2 existing opt-in skips, 0 failures |
| Swift Testing including probes | 101 tests: original 93 passed, eight review tests failed; 14 assertion/error issues |
| Privilege-bit precondition | Passed in this run with approved access |
| Focused original mapping/date/advisory/numbering tests plus first seven probes | 46 tests across seven suites: 39 original tests passed; seven probes failed |
| Final standalone review suite | Eight tests failed, 14 issues |
| Documentation check | Passed after adding the review record: 38 Markdown files |
| Mapping generator and field-schema freshness | Passed |

Local logs from this session: `/tmp/taglib-mapping-acceptance-full.log`, `/tmp/taglib-mapping-acceptance-focused.log`, `/tmp/taglib-mapping-acceptance-final-probes.log`. Logs are not committed. The retained test source makes each finding independently reproducible without those logs.

Not rerun: Release, strict warning-only build, consumers, sanitizers, minimum-platform/iOS matrix, external interoperability tools or application adoption. Earlier implementation claims about those checks are not independently validated by this review. This is not an exhaustive review of every new codec; additional defects may remain after these eight are repaired.

## Handoff and reacceptance

Repair F1–F4 first because successful operations currently remove or overwrite metadata without the required resolution. Then repair recovery, group selection and total-only handling. Keep all eight probes, add family-specific regressions, and rerun the full suite. Reacceptance requires eight passing probes, no new original-suite failures, native before/after preservation evidence and accurate documentation. An implementation-complete claim based solely on the original suite is rejected.
