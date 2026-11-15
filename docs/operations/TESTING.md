# Testing and verification

This guide explains how the package is tested, how to run the checks, and what the results do and do not establish. It is not a claim that the current working tree passes. The latest observed result and its environment are in [Status](STATUS.md).

See [Mapping test acceptance](MAPPING_TEST_STRATEGY.md) for the independent lifecycle matrix, mandatory mixed-framework gate and remaining coverage limits. The audit regressions are mandatory normal tests. Current repaired-source results and historical failures are distinguished in the status page; older passing counts never waive a current failure.

## Independent contract system (2026-11-15 upgrade)

The canonical gate is no longer only a collection of named matrices. Five independent layers reconcile the public surface, the intended contract, the public call, the native oracle and the evidence that actually executed:

| Layer | Source | What it establishes and what it does not |
| --- | --- | --- |
| Public-surface inventory | `scripts/package-test-system/public-surface-inventory.json` | Stable IDs and normalized signatures for every public Swift facade/registry declaration and every exported bridge method/property/enum, plus reviewed mode values. Extraction only enumerates production claims; it cannot approve behavior. New or duplicate declarations fail reconciliation. Internal in-place bridge selectors are deliberately excluded. |
| Test-owned contract catalog | `scripts/package-test-system/contract-catalog.json`, `field-schema-claims.json`, `format-capability-claims.json` | Scenario IDs, fixture/version, public surface, input/state partition, intended native ownership, unsupported/rejection outcome, normalization and oracle. Expected native identities are literal test data. Production field and capability snapshots are reviewed claims, not golden targets. Every advertised field and writable family has an independent decision or an explicit limitation. |
| Execution adapters | `Tests/TagLibAudioMetadataTests/ContractSystem/PublicSurfaceAdapters.swift` | One named public call per adapter, with facade wrappers and direct exported-bridge calls kept separate. No coercion, fallback, retry or version clearing. |
| Builders and oracles | `ContractFixtureBuilders.swift`, `ContractNativeOracles.swift` and the retained independent probes | Bounded native readers that never decide expected values through the package reader. Builders are self-tested on literal synchsafe, atom-size, chunk-alignment, flag/grouping, integer and malformed-input vectors. Every seed is independently verified; a failed seed fails the test. |
| Evidence gate | `scripts/test_manifest.py`, `scripts/summarize-test-run.py`, `scripts/validate-tests.sh`, `scripts/validate-contracts.sh` | Fresh commit/diff/source/toolchain manifests, exact scenario-set and assertion-budget comparison, complete framework outcomes, exact optional-skip identities, and runner exit status. Counts and suite banners are supporting evidence only. |

The catalog declares 34 contracts, 71 metadata-operation scenarios and four audit scenarios; the reviewed inventory covers 907 public-surface rows and 62 execution adapters. The audit scenarios reconcile all 100 advertised fields, all advertised writable format families, and the catalog/declaration/adapter sets at runtime. The required minima are **181 XCTest declarations** (179 passed and the two reviewed opt-in skips), **274 Swift Testing declarations in 51 suites** and **92 Python policy regressions**. These are floors, not a claim that every possible file or caller is covered.

### Contract commands

```sh
# Canonical contract lane: policy reconciliation, 13-defect calibration and a
# complete strict gate. This is the acceptance entry point.
bash scripts/validate-contracts.sh debug
bash scripts/validate-contracts.sh release

# Inner framework gate only. It requires a source-bound calibration result;
# validate-contracts.sh supplies or reuses one after checking source identity.
TAGLIB_CALIBRATION_RESULT=/path/to/calibration.json \
  bash scripts/validate-tests.sh debug

# Inventory/catalog reconciliation without building the package.
python3 scripts/package_test_system.py
python3 -m unittest discover -s scripts/tests

# Calibration inventory and a single isolated mutant (development only).
python3 scripts/calibrate-test-system.py --list
python3 scripts/calibrate-test-system.py --mutant numeric-truncation

# Real package-owned consumers through declared products, no @testable access.
bash scripts/validate-consumers.sh
```

`validate-tests.sh` writes `manifest-before.json`, `manifest-after.json`, `tests.log`, `scenarios/` and `summary.json` under a fresh `.build/test-evidence/<mode>-<timestamp>-<pid>/`. Acceptance requires the exact catalog scenario set, each scenario's exact check-name multiset and adapter identity, all framework completion summaries, a source/config identity that did not change during the campaign, and only the two reviewed XCTest skips. Each scenario and actual adapter event must match the campaign UUID, build mode and source hash, with exact per-test adapter/outcome multiplicities from the frozen `scenario-assertions.json` and `runtime-invocations.json` inventories. A missing scenario, removed assertion, duplicate execution, unexpected scenario, stale source hash, mixed configuration, truncated log or hidden failure is rejected. Filters and shards are still rejected rather than being partially aggregated.

### Defect-detection calibration

`scripts/calibrate-test-system.py` copies the package into ignored `.build/test-calibration/<run>/`, builds the actual package test target in that copy, and applies each anchored mutant only inside the copy. The active working tree, dependency binary and fixtures are never patched. A mutant counts as killed only when it compiles, the required test witnesses the intended bad behavior and the expected behavioral assertion fails; compile errors, timeouts, missing fixtures and unrelated failures are inconclusive. The current set has 13 independently activated faults and covers: omitted exported numeric validation; trimmed-versus-untrimmed MP4 key normalization; pre-range numeric truncation; formatter `nil` as deletion; schema-known retention filtering; lost ID3v2.3 version; restored stale MP4 freeform; invalid-text zero coercion and explicit-zero recovery; an advertised but unreachable route; removed adapter invocation; removed preservation assertion; and a weakened native oracle vector. The isolated workspace is restored and hashed after each mutant, and calibration is part of `validate-contracts.sh`, not an optional unexecuted script.

The manifest hashes make stale or accidental mixed evidence fail; they are not a cryptographic defense against a malicious actor with full repository access. Complete acceptance additionally requires an accepted, restored calibration result for the same source hash, commit and mutant definitions. `--require-all-killed` rejects subsets and `--allow-failures`. Development subsets report `partial` and cannot satisfy acceptance. To reuse one complete calibration for Debug and Release, set `TAGLIB_CALIBRATION_RESULT` to its `calibration.json` and run `validate-contracts.sh`; changed source/commit/definitions invalidate reuse. `validate-tests.sh` also requires this variable. Claim-blessing mode is forbidden in acceptance, named evidence directories cannot be overwritten, and both full before/after manifests are mandatory.

Calibration proves the representative defect classes can be caught, not that every future defect will be caught. It also does not establish correctness of the precompiled upstream TagLib binary.

### Surface and partition scope

Runtime scenarios cover MP4 typed deltas, full-model and structured writes, both raw replace/merge modes, raw deltas, formatted-number boundaries and malformed input, verification-disabled paths, erase/wipe, stale version and audio guards, small per-file batches, ID3v2.3 literal dates/flags/grouping and safe date rejections, both private provenance namespaces, FLAC duplicate arrays and explicit removal, WAV/AIFF ID3 chunk alignment, ASF advisory and partial-pair policy, Ogg Vorbis, Opus, APE, WavPack, tracker names, artwork and qualified comment collections. Fields that a scalar API cannot express are preserved and tested as untouchable owners rather than given fabricated setters. Unsupported Matroska registrations, Ogg Speex, IT and S3M remain explicit limitations in the catalog; no fallback writer or new codec is claimed.

## Test layers

The single SwiftPM test target is organized physically by layer:

| Directory | Coverage |
| --- | --- |
| `ContractSystem/` | Public-surface adapters, test-owned contract scenarios, fixture builders, independent native oracles, assertion-budget inventories, and builder self-tests. |
| `Capabilities/` | Public capability model, field-level support, and cross-language schema consistency. |
| `Integration/` | Real-fixture round trips, container projections, native parsers, artwork, dates, numbers, legacy numbering recovery, MP4-exclusive fields, and raw metadata. |
| `Transactions/` | Stale versions, failure atomicity, preservation, same-entry coordination, privilege rejection, and audio-content identity. |
| `Concurrency/` | Cross-format reads/writes, M4A stress, and same-file contention. |
| `ModelSemantics/` | Pure value-model contracts. |
| `Performance/` | Opt-in, non-gating throughput experiments. |
| Root-level tests | Public Objective-C selectors, Swift nested types, current version-aware function references, and no unsolicited console output. |

The suite uses both XCTest and Swift Testing. Test counts vary by runner and by which opt-ins are enabled; do not compare totals across records without checking their scope and revision.

The contract lane (`scripts/validate-contracts.sh`) runs the policy and inventory checks, requires a source-bound calibration result, then executes the mixed-framework gate (`scripts/validate-tests.sh` plus `scripts/summarize-test-run.py`). The gate requires named matrix/oracle execution evidence, exact contract-scenario and adapter records, and minimum parameterized case counts, not only suite banners. An allowlisted optional XCTest skip must match both its class and method; a different class with the same method name fails the gate.

The current upgraded gate requires the legacy sparse-state matrices, the new
contract scenarios and the calibration set. The reviewed floors are 181 XCTest,
274 Swift Testing declarations in 51 suites and 92 Python policy regressions.
The latest observed result and environment belong to [Status](STATUS.md);
historical counts below certify only their recorded revisions. Do not compare
counts across revisions without checking scope and opt-ins.

## Strict test compilation

The full Debug/Release gates pass `-Xswiftc -warnings-as-errors -Xcc -Werror` to compilation. Production and test compilation have no deprecation-warning exception; obsolete compatibility APIs and their compile-only tests have been removed.

## Standard commands

```sh
# Canonical acceptance lane (Debug). No filters or skips are accepted.
bash scripts/validate-contracts.sh debug

# Canonical acceptance lane (Release).
bash scripts/validate-contracts.sh release

# Gate-policy regressions only, without running the package suite.
python3 -m unittest discover -s scripts/tests

# Strict compile: package Swift and C/Objective-C warnings are errors.
swift build --disable-keychain --disable-netrc \
  -Xswiftc -warnings-as-errors -Xcc -Werror

# Focused development run; not acceptance evidence.
swift test --disable-keychain --disable-netrc

# Sanitizers.
swift test --disable-keychain --disable-netrc --sanitize=address
swift test --disable-keychain --disable-netrc --sanitize=thread
```

The gate writes a timestamped `tests.log`, `summary.json`, before/after manifests, and scenario records under `.build/test-evidence/`. The summary is accepted only when both frameworks complete, no unexpected skip or named failure occurs, all required suites execute, every parameterized case count meets its frozen minimum, the exact contract-scenario and adapter records match, and the source identity did not change during the campaign. A bare `swift test` run or a suite banner is not equivalent evidence.

The canonical lane sets `TAGLIB_DISABLE_MANIFEST_SANDBOX=1` and uses an evidence directory that cannot already exist. Some restricted environments also need workspace-local module caches. These settings alter build isolation and must be stated in the verification record when used for a direct inner-gate run.

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
SWIFT_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
TAGLIB_DISABLE_MANIFEST_SANDBOX=1 \
TAGLIB_CALIBRATION_RESULT="$PWD/.build/test-calibration/<run>/calibration.json" \
bash scripts/validate-tests.sh debug
```

### Minimum-platform builds

The CI matrix compiles these triples:

| Destination | Triple |
| --- | --- |
| macOS 13 arm64 | `arm64-apple-macosx13.0` |
| macOS 13 x86_64 | `x86_64-apple-macosx13.0` |
| iOS 16 arm64 | `arm64-apple-ios16.0` |
| iOS 16 Simulator arm64 | `arm64-apple-ios16.0-simulator` |
| iOS 16 Simulator x86_64 | `x86_64-apple-ios16.0-simulator` |

```sh
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
swift build --disable-keychain --disable-netrc \
  --triple arm64-apple-macosx13.0 --sdk "$SDK_PATH"
```

These are compile/link checks. They do not prove runtime behavior on the minimum OS, on a device, or on x86_64. The CI job adds no `-warnings-as-errors` flags; the repository's strict warning check is the separate `build-and-test` step.

### Consumer integration

```sh
swift run --disable-keychain --disable-netrc \
  --package-path IntegrationTests/Consumer TagLibAudioMetadataConsumer
swift run --disable-keychain --disable-netrc \
  --package-path IntegrationTests/Consumer TagLibAudioMetadataLowLevelConsumer
```

The facade consumer uses only the public product. The low-level consumer explicitly imports `CTagLibBridge`. Neither consumer proves an embedding application's signing or rpath configuration.

## Documentation checks

The documentation pipeline is separate from the build and runs before tests in CI:

```sh
python3 scripts/check-docs.py
```

`check-docs.py` validates links, headings, tables, current-document coverage, bridge selector coverage, and freshness of every generated reference page. Regenerate a stale page with:

```sh
python3 scripts/generate-api-reference.py --write
python3 scripts/generate-field-schema.py --write
python3 scripts/generate-format-matrix.py --write
python3 scripts/generate-mapping-matrix.py --write
```

The generators read Swift and Objective-C++ source; no Markdown is converted into production code. Do not hand-edit generated sections between their markers.

## Opt-in checks

### External preservation corpus

```sh
# The output directory must not already exist. Requires Python 3 and FFmpeg
# with the listed encoders.
python3 scripts/make-preservation-corpus.py /tmp/taglib-preservation-corpus

TAGLIB_PRESERVATION_CORPUS=/tmp/taglib-preservation-corpus \
  swift test --disable-sandbox --filter ExternalCorpusPreservationTests
```

The generator writes eight valid tone containers with known metadata: FLAC, MP3, M4A/AAC, Ogg Vorbis, Opus, ASF/WMA, WavPack, and TrueAudio (with an independently seeded ID3v2 tag). It is a controlled synthetic corpus, not a curated application or user-library corpus. The test requires an actual track mutation, total persistence, and non-empty unrelated visible metadata.

### Snapshot throughput

```sh
TAGLIB_BENCHMARK=1 swift test -c release --disable-sandbox \
  --filter SnapshotThroughputBenchmarkTests
```

The benchmark keeps fixture setup outside timing and prints warmed snapshot throughput, verified write batches, and flush samples. It also measures MP3/M4A/FLAC ordinary and 64-key metadata-heavy Basic/snapshot reads, typed/Basic/raw title writes, and declared-capability lookups. Each profile reports five batch-average latencies: `medianMs` is their median and `p95Ms` is their maximum (the nearest-rank 95th percentile of five samples), not a per-operation tail percentile. Reads assert byte immutability; writes include actual staging, verification and durability. It has no performance threshold and is not a gating test. Treat its numbers as local observations, not throughput promises. Baseline and optimized evidence are in the [API/performance record](../records/remediation/REM-2026-11-12-api-mapping-performance.md).

The current gate requires at least 181 XCTest and 274 Swift Testing declarations, plus named passing evidence for descriptor fidelity, the per-read lookup preservation regressions, transaction-readability regressions, every contract scenario and the calibration lane. An unchanged total count cannot substitute for those tests.

### Selective extraction profile and mandatory contracts

`TAGLIB_BENCHMARK=1 TAGLIB_BENCHMARK_PROFILE=projections` selects a separate 48-row workload: three containers, two metadata densities and eight APIs. Each row is the median of three warmed batch-average latencies, not a per-operation percentile. Setup and preservation assertions are outside timing. See the [architecture record](../records/remediation/REM-2026-11-14-package-architecture.md) for baseline/optimized artifacts, variability and exact scope.

`SelectiveExtractionTests` is mandatory in the strict gate: all 32 option combinations are compared against full extraction on 19 committed fixtures and three rich temporary copies. Every Objective-C Basic property, exact raw/structured collections, direct single-view readers and whole-file immutability are checked. Zero-mask invalid/parser-mismatch inputs and direct low-level writes must fail without mutation. These are projection-equivalence checks; the existing independent native byte matrices continue to establish mapping correctness.

## Independent evidence used in the repository

Some integration tests use independent parsers or external tools rather than the package reader as the only oracle:

- a bounded RIFF INFO parser for WAV surfaces;
- independent ID3v2 frame readers, including a tag-boundary-preserving MP3 oracle and container-length/chunk readers for AAC/WAV/AIFF/TTA/DSF/DSDIFF;
- an MP4 atom/item parser, including qualified freeform identities and `mdat` payload comparison;
- an APEv2 item parser and Xiph comment readers for FLAC and Ogg packet payloads;
- a bounded ASF header/attribute parser;
- FLAC metadata-block and Ogg packet comparison that excludes padding but retains duplicates, whitespace and complete audio bytes;
- sparse-state matrices that verify each seeded native date presence and literal value before mutation, then compare unchanged owners, arrays, duplicates, whitespace and audio after every applicable write surface;
- an independent ASF Content Description reader with literal wire vectors and malformed-length bounds;
- generated AIFF and corpus fixtures.

These oracles are intentionally bounded. They do not establish universal codec conformance, every native metadata variant, or correctness of the precompiled TagLib binary. FFprobe/FFmpeg were used during fixture acquisition and historical verification campaigns, but the current suite does not invoke them; the opt-in corpus generator requires FFmpeg.

## CI jobs

| Job | What it does |
| --- | --- |
| `build-and-test` | Documentation check, clean build, strict warning build, gate-policy tests, Debug contract lane (inventory/catalog reconciliation, calibration, complete framework gate), evidence artifact, both consumers, and a dynamic-link/binary-boundary audit. |
| `address-sanitizer` | Full test suite under AddressSanitizer. |
| `release-build-and-test` | Release contract lane against real fixtures, with an evidence artifact. |
| `thread-sanitizer` | Full test suite under ThreadSanitizer. |
| `minimum-platform-builds` | Five compile/link checks for the supported deployment targets. |
| `remote-tag-consumer` | On a tag build, a clean consumer resolves the published tag and runs. |

The CI configuration is evidence only for runs that actually executed. A configured job is not a passing result for an unrun commit. The `taglib-binary-release.yml` workflow is separate: binary release changes must publish the new asset before CI can resolve it.

## Known environment-dependent test

`CleanRoomPrivilegeTests.privilegedFilesRejectBeforeCloneInBothTransactionEngines` tries three permission sets: `0o4644` (setuid), `0o2644` (setgid), and `0o6644` (both). It verifies that both transaction engines reject the file without changing inode, mode, or bytes. The test's own precondition requires the requested bits to survive `chmod`.

Some agent/sandbox environments silently strip those bits even when `chmod` reports success. The documentation-pass rerun in this repository's restricted environment reproduced the full declaration counts but failed the gate only at this precondition. In that environment the test fails at:

```swift
#expect(before.st_mode & 0o7777 == permissions)
```

The observed mode is typically `0o644`, and the failure is a host restriction, not a production defect. Run the test outside the sandbox; do not weaken or skip it to make a suite green. The clean-room remediation record documents a successful run outside the sandbox, and [Status](STATUS.md) records whether the latest observed run saw this limitation.

## What passing tests establish

A passing suite establishes that the assertions actually executed in that environment passed. It does not establish:

- that every documented behavior has a test;
- that every format, alias, or metadata variant works;
- that a passing unit test is an independent oracle;
- that the precompiled TagLib binary is sanitizer-clean;
- that minimum-OS, device, x86_64, or sandboxed runtime behavior matches the host;
- that hardware or power-loss durability holds;
- that another process cannot race a commit.

When a test uses the package reader as both writer and expected-value source, the assertion is a consistency check, not independent evidence of interoperability.

## Reporting a verification result

Record the revision, environment, command, opt-in state, counts, skips, and any environment-dependent failure. Do not report a compile-only check as runtime verification. Put campaign narratives in [engineering records](../records/README.md) and update [Status](STATUS.md) only when the latest known state changes. See [Record conventions](../records/CONVENTIONS.md) for the record format.

## Numbering acceptance regressions

`IndependentAcceptanceProbes` retains the eight originally failing acceptance cases. `NumberingRepairRegressionTests` adds cross-format native cleanup, both private namespaces and foreign lookalikes, explicit legacy resolution, native absence/removal, malformed multi-value rejection, empty-group byte preservation, MP4 bounds and formatted orphan-total preservation. Repairs and exact observed results are in the [numbering acceptance repair record](../records/remediation/REM-2026-11-09-numbering-acceptance-repairs.md). These suites use temporary fixture copies; they do not operate on a user library.

For a bounded six-format write-concurrency profile, set both `TAGLIB_BENCHMARK=1` and `TAGLIB_BENCHMARK_PROFILE=concurrency` on the same optional benchmark method. It measures 1/2/4/8 workers with fresh ordinary and metadata-heavy fixtures and real durable commits. It checks all untouched raw fields after timing. See [write-concurrency evidence](../records/remediation/REM-2026-11-12-write-concurrency.md); file setup and verification are excluded from the batch timings.

Advisory erase/preservation acceptance additionally requires six named functions and 118 parameterized cases: ASF alias erasure (24), unknown-code absence rejection (4), Basic unknown preservation (16), ASF alias preservation (6), exact raw-code verification (4) and known/unknown erase across sixteen formats (64). The erased-MP4 oracle contract is also mandatory. Gate-policy tampering tests reject missing or reduced evidence.

## Diagnostic remediation gate

All 13 `RemediationPreservationTests` methods are required by exact XCTest class/method identity. They cover low-level model preservation, native ASF repeated updates/advisory aliases, unknown advisory codes, APE release projections, Basic number-text consistency, legacy date rejection/preservation, direct bridge rejection and the central facade date guard. Gate-policy tests remove each method's evidence and require rejection. The artwork clear regression independently requires absence of the MP4 `covr` atom. These tests complement the native field matrices; they do not establish the complete format/version/value/API cross-product.
