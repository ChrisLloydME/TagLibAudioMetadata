# Testing and verification guide

This document explains how the package is tested, how to run the checks, and what the results do and do not establish. It is a guide, not a claim that the current working tree passes. See [STATUS](STATUS.md) for the latest recorded result.

## Test layers

The single SwiftPM test target is organized physically by layer:

| Directory | What it covers |
| --- | --- |
| `Capabilities/` | Public capability model, field-level support, and cross-language schema consistency. |
| `Integration/` | Real-fixture round trips, container projections, native parsers, artwork, dates, numbers, and raw metadata. |
| `Transactions/` | Stale versions, failure atomicity, preservation, same-entry coordination, privilege rejection, and audio-content identity. |
| `Concurrency/` | Cross-format reads and writes, M4A stress, and same-file contention. |
| `ModelSemantics/` | Pure value-model contracts. |
| `Performance/` | Opt-in, non-gating throughput experiments. |
| Root-level compatibility tests | Public Objective-C selectors, Swift nested types, deprecated function references, and no unsolicited console output. |

At the current HEAD the test target declares 153 XCTest functions and 72 Swift Testing functions, for 225 test declarations. Two XCTest tests are opt-in and skip by default. Test counts vary by runner and by which opt-ins are enabled; do not compare counts across records without checking their scope.

## Standard commands

```sh
# Resolve/build and run the suite
swift test --disable-keychain --disable-netrc

# Strict compile: package Swift and C/Objective-C warnings are errors
swift build --disable-keychain --disable-netrc \
  -Xswiftc -warnings-as-errors -Xcc -Werror

# Release mode
swift test --disable-keychain --disable-netrc -c release

# Sanitizers
swift test --disable-keychain --disable-netrc --sanitize=address
swift test --disable-keychain --disable-netrc --sanitize=thread
```

Some restricted environments cannot launch SwiftPM's manifest sandbox. `swift test --disable-sandbox` works around that but weakens a build-time isolation layer; use it only when the environment requires it and say so in the verification record.

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
  --triple arm64-apple-macosx13.0 --sdk "$SDK_PATH" \
  -Xswiftc -warnings-as-errors -Xcc -Werror
```

These are compile/link checks. They do not prove runtime behavior on the minimum OS, on a device, or on x86_64.

### Consumer integration

```sh
swift run --disable-keychain --disable-netrc \
  --package-path IntegrationTests/Consumer TagLibAudioMetadataConsumer
swift run --disable-keychain --disable-netrc \
  --package-path IntegrationTests/Consumer TagLibAudioMetadataLowLevelConsumer
```

The facade consumer uses only the public product. The low-level consumer explicitly imports `CTagLibBridge`. Neither consumer proves that an embedding application's signing or rpath configuration is correct.

## Opt-in checks

### External preservation corpus

```sh
# The output directory must not already exist. Requires Python 3 and FFmpeg
# with the listed encoders.
python3 scripts/make-preservation-corpus.py /tmp/taglib-preservation-corpus

TAGLIB_PRESERVATION_CORPUS=/tmp/taglib-preservation-corpus \
  swift test --disable-sandbox --filter ExternalCorpusPreservationTests
```

The generator writes eight valid tone containers with known metadata. It is a controlled synthetic corpus, not a curated application or user-library corpus. The test requires an actual track mutation, total persistence, and non-empty unrelated visible metadata.

### Snapshot throughput

```sh
TAGLIB_BENCHMARK=1 swift test -c release --disable-sandbox \
  --filter SnapshotThroughputBenchmarkTests
```

The benchmark keeps fixture setup outside timing and prints warmed snapshot throughput, write batches, and flush samples. It has no performance threshold and is not a gating test. Treat its numbers as local observations, not throughput promises.

## Independent evidence used in the repository

Some integration tests use independent parsers or external tools rather than the package reader as the only oracle:

- a bounded RIFF/INFO parser for WAV surfaces;
- an ID3v2 frame parser for native number, comment, lyric, and artwork checks;
- an MP4 atom/item parser, including `mdat` payload comparison;
- an APEv2 item parser;
- a bounded ASF header/attribute parser;
- DSF/DSDIFF native frame checks;
- FFprobe/FFmpeg for generated-format metadata and encoded-packet comparison;
- generated AIFF and corpus fixtures.

These oracles are intentionally bounded. They do not establish universal codec conformance, every native metadata variant, or correctness of the precompiled TagLib binary.

## CI jobs

| Job | What it does |
| --- | --- |
| `build-and-test` | Clean build, strict warning build, `swift test`, both consumers, and a dynamic-link/binary-boundary audit. |
| `address-sanitizer` | Full test suite under AddressSanitizer. |
| `release-build-and-test` | Release-mode tests against real fixtures. |
| `thread-sanitizer` | Full test suite under ThreadSanitizer. |
| `minimum-platform-builds` | Five strict compile/link checks for the supported deployment targets. |
| `remote-tag-consumer` | On a tag build, a clean consumer resolves the published tag and runs. |

The CI configuration is evidence only for runs that actually executed. A configured job is not a passing result for an unrun commit. The `taglib-binary-release.yml` workflow is separate: binary release changes must publish the new asset before CI can resolve it.

## Known environment-dependent test

`CleanRoomPrivilegeTests.privilegedFilesRejectBeforeCloneInBothTransactionEngines` sets setuid/setgid bits with `chmod` and verifies that both transaction engines reject the file without changing inode, mode, or bytes.

Some agent/sandbox environments silently strip those bits even when `chmod` reports success. In that environment the test fails at its own `before.st_mode` precondition. This is a host restriction, not a production defect. Run the test outside the sandbox; do not weaken or skip it to make a suite green. The clean-room remediation record documents a successful run outside the sandbox.

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

Record the revision, environment, command, opt-in state, counts, skips, and any environment-dependent failure. Do not report a compile-only check as runtime verification. See [records/CONVENTIONS.md](records/CONVENTIONS.md) for the record format and [STATUS.md](STATUS.md) for the current summary.
