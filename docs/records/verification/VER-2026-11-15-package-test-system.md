# VER-2026-11-15: independent package contract test system

Date: 2026-11-15 (Asia/Shanghai). Package: TagLibAudioMetadata only. Branch:
`codex/package-test-system-upgrade-20261115`. Reviewed production baseline:
`f483f5f`; handoff documentation checkout: `500d435`. Implementation commits:
`198fdee` (contract system and calibration), `ee435fa` (manifest source-identity
fix), with documentation/evidence follow-ups recorded by the final report.

No sibling application, application UI, provider client, external acceptance
host or dependency source was read, built or used. The package's own copied
fixtures, declared products and ignored `.build` calibration space were
sufficient.

## 1. Baseline discovery and gap ledger

Observed discovery on the baseline test tree (not old documentation):

| Framework / policy | Discovered | Result |
| --- | --- | --- |
| XCTest | 181 declarations; 179 run, 2 reviewed opt-in skips | Passed |
| Swift Testing | 231 declarations in 45 suites (documentation said 42) | Passed except the privilege precondition |
| Python policy | 41 regressions | Passed |
| Baseline canonical gate | One named failure: `privilegedFilesRejectBeforeCloneInBothTransactionEngines` | Host workspace sandbox strips setuid/setgid bits |

The baseline failure occurs before implementation and is an environment
precondition, not a regression. Running the same unchanged precondition with
authorized full host access preserves `04644`/`02644` bits and is the required
acceptance environment. No setuid check was weakened.

The prior system still allowed the following defect classes (the gap ledger):

| Gap | Baseline weakness | Layer that closes it |
| --- | --- | --- |
| G-01 public entry points | Strong matrices did not enumerate every facade/bridge signature, overload or mode. | Public-surface inventory with 907 declarations and reviewed mode values. |
| G-02 coverage decisions | Field/format claims and runtime coverage had no independent decision ledger. | `field_decisions` for 100 fields, `format_decisions` for 20 advertised writable families, and 33 contracts with 70 scenarios. |
| G-03 validation vs execution | The gate could accept a name/count while the named call or native owner was not exercised. | Exact scenario evidence with per-scenario runtime identity, adapter, outcome and assertion budget. |
| G-04 preservation flags/identity | Values could be compared while flags, grouping, duplicates and native identities were not. | ID3v2.3 status/format/group assertions; untouched-owner and audio/sample comparisons in every supported scenario. |
| G-05 counts vs execution | Suite banners and declarations could pass without complete execution evidence. | Source/build/test/catalog manifests, exact observed scenario sets, complete framework summaries and skip identity. |
| G-06 builders/oracles | Fixture builders were trusted without independent boundary self-tests. | Synchsafe, atom/chunk bounds, alignment, flags/grouping, integer widths, malformed-input and literal-vector self-tests. |
| G-07 unsupported paths | Skips, `continue` or silent fallback could stand in for a rejection decision. | Explicit `unsupported_reject`/`read_only_reject` contracts with byte-unchanged and error identity checks. |
| G-08 calibration | Passing tests did not prove they could fail for the intended defect. | Twelve isolated compile-and-activate mutants; all killed with restored source and hash witnesses. |
| G-09 external consumers | Consumers only compiled typical calls. | Consumers now copy fixtures, perform real writes through declared products, parse native bytes independently and verify encoded audio. |
| G-10 release evidence | Stale/mixed logs and filter/shard partial runs were difficult to distinguish. | Campaign manifests reject changed source/config and the runner rejects filters/shards without complete aggregation. |

## 2. Implemented layers

### 2.1 Public-surface inventory

`scripts/package-test-system/public-surface-inventory.json` contains 907
stable-key rows: 779 Swift declarations and 128 exported Objective-C bridge
declarations. It enumerates facade and exported bridge signatures, overloads,
verification/audio/version modes, raw replace/merge modes, structured
sub-surfaces, normalization, erase/wipe, reads and registry queries. Public
value-model declarations are classified as model rows; callable facade/registry
rows require an explicit exercised/read-only/rejection/compile-only/unverified
decision and adapter link. Internal in-place selectors in
`TagLibMetadataExtractor+Internal.h` are excluded by design.

`scripts/package_test_system.py` reconciles the reviewed rows against a fresh
syntax scan. New, removed, duplicate or renamed public declarations fail; the
extractor also has syntax/ambiguity failure paths and policy fixtures. Adding a
capability or field changes the reviewed claims snapshot and requires a matching
decision row.

### 2.2 Test-owned contract catalog

`contract-catalog.json` has 33 contracts and 70 metadata scenarios. Every
contract records the public surface(s), adapter(s), field/format/encoding
families, fixture, input/state partition, literal intended ownership, expected
native oracle, unsupported/rejection outcome, validation phase and normalization
decision. `field-schema-claims.json` (100 fields) and
`format-capability-claims.json` (22 families, 20 writable) enumerate production
claims for review; they do not generate expected native values or success.
Field and format decisions are independent top-level ledgers. Three audit
scenarios check the field set, the writable-format set and the
catalog/declaration/adapter reconciliation at runtime.

### 2.3 Execution adapters and public scenarios

`Tests/TagLibAudioMetadataTests/ContractSystem/PublicSurfaceAdapters.swift`
declares 62 raw-value adapter identities. Each invokes exactly one named public
API; facade wrappers and direct bridge calls are separate adapters; no adapter
falls back, retries, coerces or clears a version. The scenarios cover:

- MP4 typed deltas, sequences, full-model writes, raw value replace/merge, raw
  deltas, numeric boundaries, malformed number text, disabled verification,
  erase/wipe, stale version/audio guards, batches and normalization;
- ID3v2.3 version/flags/grouping preservation, literal dates, protected-layout
  rejection, ID3v2.4 private provenance;
- FLAC duplicate arrays/whitespace/removal, WAV/AIFF chunk alignment and INFO
  preservation, ASF advisory states and partial-pair rejection;
- Ogg Vorbis, Opus, APE and WavPack text lifecycles, XM tracker bytes, artwork
  and qualified comment collections;
- all four value kinds plus byte, signed, unsigned, intPair, identifier,
  artwork and qualified collection encodings.

### 2.4 Builders and native oracles

Test-owned builders write independent ID3v2.3/v2.4 frames, MP4 atom trees,
FLAC Vorbis comments and RIFF/AIFF chunks. Bounded native readers decode the
result without asking the package reader what the expected value is. The
self-tests use literal vectors for synchsafe boundaries (127/128, 16383/16384),
v2.3 plain versus v2.4 synchsafe frame sizes, status/format/grouping bytes,
uint16/int16 encodings, chunk padding/declared sizes and malformed/truncated
inputs. Seed verification occurs before every public operation; a failed seed
fails the test.

### 2.5 Evidence gate

`validate-tests.sh` writes a fresh evidence directory containing
`manifest-before.json`, `manifest-after.json`, `tests.log`, `scenarios/*.json`
and `summary.json`. `summarize-test-run.py` rejects:

- incomplete or failed framework summaries, hidden named failures, unexpected
  skips or a nonzero runner exit;
- a changed commit/source/diff/toolchain/system-file identity, including source
  changes during the campaign;
- missing, duplicate or unexpected scenarios, wrong runtime-test identity,
  wrong outcome or any assertion-budget mismatch;
- fewer than 181 XCTest, 272 Swift Testing declarations in 51 suites, or any
  reduced required case count.

The two reviewed opt-in XCTest skips remain exact class+method identities.
`validate-contracts.sh` makes policy checks, the bounded calibration set and the
complete framework gate one required lane.

## 3. Calibration

`scripts/calibrate-test-system.py` copies the package into ignored
`.build/test-calibration/<run>/`, builds the public-product probe harness and
applies anchored mutants only inside that copy. Each mutant record contains the
patch, target fingerprint, probe command, observed activation witness, exit
status and restore hash check. A mutant is killed only on a successful build,
an `ACTIVATION <probe>` witness and the intended `FAIL <probe>` assertion.

The accepted run (`20261115T063441Z`, working source at `198fdee`) killed all 12:

| Mutant | Activation witness |
| --- | --- |
| exported numeric validation | overflow was accepted by `writeTrackNumber` |
| key normalization mismatch | trimmed validation wrote no canonical `trkn` |
| numeric truncation | 65536 was accepted instead of rejected |
| formatter nil as delete | over-width formatter removed the pair instead of rejecting |
| global known-field retention filter | FLAC full-model write dropped `TRACKERNAME` |
| legacy default v4 save | v2.3 file became v4 after an unrelated edit |
| restored stale MP4 freeform | old `MUSICBRAINZ_ALBUMTYPE` reappeared |
| invalid text zero / explicit-zero recovery | `5/0` became `5/12` |
| advertised unreachable route | `mka` was advertised writable while the planner rejected it |
| removed adapter invocation | the named public call did not reach `©nam` |
| removed preservation assertion | only title/audio checks remained |
| oracle vector corruption | corrupted UTF-8 native text was accepted |

No mutant exposed a production defect requiring a production change. The
calibration probes themselves were corrected when they initially asserted the
wrong retention/alias owner; the accepted run is the evidence, not the earlier
inconclusive attempts.

## 4. External package-owned consumers

`scripts/validate-consumers.sh` builds and runs both declared products.
`TagLibAudioMetadataConsumer` copies a package M4A, applies a typed façade patch
with the snapshot version, reopens, independently parses the native `©nam` atom,
compares `mdat` bytes and rejects a stale version without mutation.
`TagLibAudioMetadataLowLevelConsumer` imports only `CTagLibBridge`, writes a
model through `writeMetadata`, parses native `TIT2`, compares encoded audio and
checks that the unreachable Matroska route is not advertised. Neither consumer
uses `@testable` or internal selectors.

## 5. Commands and results

Focused and complete commands used during implementation:

```sh
swift test --disable-sandbox --disable-keychain --disable-netrc \
  --filter 'ContractMP4ScenarioTests|ContractBridgeAndEncodingTests|ContractNativeContainerTests|ContractFieldCoverageTests'
python3 -m unittest discover -s scripts/tests
python3 scripts/package_test_system.py
python3 scripts/calibrate-test-system.py
bash scripts/validate-consumers.sh
bash scripts/validate-contracts.sh debug
bash scripts/validate-contracts.sh release
```

The final accepted runs, sanitizer results and minimum-platform results are
recorded in the acceptance addendum below. Commands not executed are not
reported as accepted.

## 6. Framework declarations versus scenario counts

| Measure | Count |
| --- | --- |
| XCTest declarations (two opt-in skips) | 181 |
| Swift Testing declarations | 272 |
| Swift Testing suites | 51 |
| Catalog metadata scenarios | 70 |
| Catalog audit scenarios | 3 |
| Catalog contracts | 33 |
| Public surface rows | 907 |
| Execution adapter identities | 62 |
| Advertised fields with decisions | 100 |
| Advertised writable formats with decisions | 20 |
| Python policy regressions | 76 |
| Calibration mutants | 12 |

Scenario count is not a test declaration count: one parameterized test can
execute several scenarios and one scenario can contain a parameterized matrix.
The evidence gate checks both, so neither can substitute for the other.

## 7. Remaining limits

- Finite tests cannot prove every possible file, tag layout or caller correct.
  The inventory and catalog are auditable decisions, not a universal safety
  claim.
- The calibration set proves the representative defect classes are detectable;
  it is not a proof that every future defect will be caught.
- Ogg Speex, IT and S3M remain explicit `unverified` decisions: no committed
  fixture/typed runtime scenario and no fallback writer is claimed.
- Matroska registrations remain target-only with no registered family, native
  codec or fixture.
- MP4 audio-content continuity is explicitly unavailable (`nil`), matching the
  existing audio-identity policy; M4A scenarios compare raw `mdat` bytes.
- The pinned TagLib binary is not sanitizer-instrumented; sanitizer runs cover
  package code and tests only.
- The mandatory privilege test requires an authorized host whose filesystem
  preserves setuid/setgid bits. The DSH workspace sandbox strips them, so final
  gates must run with authorized full host access; the check itself is
  unchanged.
- No ACP/Xcode Code Intelligence tool was exposed in this session. Navigation,
  builds, tests and diagnostics used shell, Git, Swift, Xcode toolchain and
  Python as available; no invented tool or broad model-assisted diagnostic was
  substituted for implementation.

## 8. Final acceptance addendum

The accepted source is `2cedf9e` with a clean tree. Its Swift/Objective-C
sources, tests, inventories, catalog, adapters, oracles and calibration
definitions are unchanged from `714710d`; `2cedf9e` adds the stable evidence-ID
support and this acceptance addendum. A later documentation-only correction
records the exact evidence identities; it does not change executable source.

Stable evidence directories:

| Lane | Evidence | Result |
| --- | --- | --- |
| Debug | `.build/test-evidence/debug-final-20261115/` | `accepted: true`; 181 XCTest executed (179 passed, 2 reviewed skips), 272 Swift Testing declarations in 51 suites passed, 73/73 scenarios, 0 failures |
| Release | `.build/test-evidence/release-final-20261115/` | `accepted: true`; 181 XCTest executed (179 passed, 2 reviewed skips), 272 Swift Testing declarations in 51 suites passed, 73/73 scenarios, 0 failures |
| Calibration (Debug lane) | `.build/test-calibration/20261115T072347Z/calibration.json` | `accepted`; all 12 mutants compiled, activated and were killed; every source restored and hash-checked |
| Calibration (Release lane) | `.build/test-calibration/20261115T072927Z/calibration.json` | `accepted`; all 12 mutants compiled, activated and were killed; every source restored and hash-checked |

Both lanes re-ran the policy suite (76 regressions), inventory/catalog
reconciliation and the bounded calibration set before the complete framework
gate. The two final summaries bind the same campaign manifest commit
`2cedf9e` and the same source hash
`ef15b3e6252a1887bd73d8b57d4d2d82c09fcff3eb8706366016d06cc0595b85`.
The two XCTest skips are exactly the reviewed opt-in identities:
`ExternalCorpusPreservationTests.testTrackMutationPreservesOtherVisiblePropertiesInExternalCorpus`
and
`SnapshotThroughputBenchmarkTests.testOptInIndependentFileSnapshotThroughput`.
No additional skip, expected failure, filter, shard or conditional pass was
used.

Focused sanitizer evidence (current HEAD source, separate scratch paths):

| Lane | Command focus | Result |
| --- | --- | --- |
| AddressSanitizer | `ContractBuilderOracleSelfTests` + `contractMP4TypedVertical` + `contractNormalizationPlan` | 9 tests in 3 suites passed |
| ThreadSanitizer | `contractMP4PublicSequence` + `contractV23FlaggedPreservation` + `contractBridgeReadsRegistry` | 3 tests in 3 suites passed |

Minimum-platform builds all completed on the same source:

| Target | Result |
| --- | --- |
| macOS 13 arm64 | build passed |
| macOS 13 x86_64 | build passed |
| iOS 16 arm64 | build passed |
| iOS 16 Simulator arm64 | build passed |
| iOS 16 Simulator x86_64 | build passed |

The standalone consumers perform real writes and independent native/audio
checks. The final policy suite is 76 regressions. Unexecuted work is not
inferred green.
