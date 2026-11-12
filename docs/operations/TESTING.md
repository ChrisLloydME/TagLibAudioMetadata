# Testing and verification

This guide explains how the package is tested, how to run the checks, and what the results do and do not establish. It is not a claim that the current working tree passes. The latest observed result and its environment are in [Status](STATUS.md).

See [Mapping test acceptance](MAPPING_TEST_STRATEGY.md) for the independent lifecycle matrix, mandatory mixed-framework gate and remaining coverage limits. The audit regressions are mandatory normal tests. Current repaired-source results and historical failures are distinguished in the status page; older passing counts never waive a current failure.

## Test layers

The single SwiftPM test target is organized physically by layer:

| Directory | Coverage |
| --- | --- |
| `Capabilities/` | Public capability model, field-level support, and cross-language schema consistency. |
| `Integration/` | Real-fixture round trips, container projections, native parsers, artwork, dates, numbers, legacy numbering recovery, MP4-exclusive fields, and raw metadata. |
| `Transactions/` | Stale versions, failure atomicity, preservation, same-entry coordination, privilege rejection, and audio-content identity. |
| `Concurrency/` | Cross-format reads/writes, M4A stress, and same-file contention. |
| `ModelSemantics/` | Pure value-model contracts. |
| `Performance/` | Opt-in, non-gating throughput experiments. |
| Root-level tests | Public Objective-C selectors, Swift nested types, current version-aware function references, and no unsolicited console output. |

The suite uses both XCTest and Swift Testing. Test counts vary by runner and by which opt-ins are enabled; do not compare totals across records without checking their scope and revision.

The mixed-framework gate (`scripts/validate-tests.sh` plus `scripts/summarize-test-run.py`) requires named matrix/oracle execution evidence and minimum parameterized case counts, not only suite banners. An allowlisted optional XCTest skip must match both its class and method; a different class with the same method name fails the gate.

The `0.7.3` gate requires the sparse-state matrices and 8,282 additional parameterized cases in addition to the previous lifecycle evidence. Its latest recorded result is 158 XCTest declarations (156 passed, two original opt-in skips), 179 Swift Testing declarations in 41 suites, and 24 policy regressions; both Debug and Release gates were accepted. The latest observed result and environment belong to [Status](STATUS.md); the required inventory belongs to [Mapping test acceptance](MAPPING_TEST_STRATEGY.md#sparse-state-and-write-surface-acceptance). The recorded runs were on the pre-merge state-coverage branch; release preparation changes documentation only. The `0.7.2` release line's 165 Swift Testing declarations in 36 suites and 22 policy regressions are historical and do not certify `0.7.3`. Do not compare counts across revisions without checking scope and opt-ins.

## Strict test compilation

The full Debug/Release gates pass `-Xswiftc -warnings-as-errors -Xcc -Werror` to compilation. Production and test compilation have no deprecation-warning exception; obsolete compatibility APIs and their compile-only tests have been removed.

## Standard commands

```sh
# Full-suite acceptance gate (Debug). No filters or skips are accepted.
bash scripts/validate-tests.sh debug

# Full-suite acceptance gate (Release).
bash scripts/validate-tests.sh release

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

The gate writes a timestamped `tests.log` and `summary.json` under `.build/test-evidence/`. The summary is accepted only when both frameworks complete, no unexpected skip or named failure occurs, all required suites execute, and every parameterized case count meets its frozen minimum. A bare `swift test` run or a suite banner is not equivalent evidence.

Some restricted environments cannot launch SwiftPM's manifest sandbox or write to the default module cache. `scripts/validate-tests.sh` supports `TAGLIB_DISABLE_MANIFEST_SANDBOX=1` for that case; workspace-local module caches can avoid the default cache. These workarounds alter build isolation and must be stated in the verification record.

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
SWIFT_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh debug
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

The current gate requires at least 162 XCTest and 179 Swift Testing declarations, plus named passing evidence for descriptor fidelity and the three per-read lookup preservation regressions. An unchanged total count cannot substitute for those tests.

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
| `build-and-test` | Documentation check, clean build, strict warning build, gate-policy tests, Debug `validate-tests.sh`, evidence artifact, both consumers, and a dynamic-link/binary-boundary audit. |
| `address-sanitizer` | Full test suite under AddressSanitizer. |
| `release-build-and-test` | Release-mode `validate-tests.sh` against real fixtures, with an evidence artifact. |
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
