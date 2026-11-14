# Package architecture, API consolidation and selective I/O — 2026-11-14

Branch: `codex/package-architecture-performance`, based on verified `733210a`. This continues the explicitly breaking candidate; no publication or dependency bump is authorized by this campaign.

## Scope and acceptance

1. Delete internal functions without callers and source-compatibility-only forwarding arities. Consolidate snapshot constructors and remove Bool-only writes that hide commit status. Native-file aliases, exact provenance and explicit recovery remain supported.
2. Keep one canonical field registry rather than legacy alias flags/empty shared-owner routing. All current field keys are canonical; qualified/raw engine aliases still resolve through their explicit keys.
3. Separate opaque snapshot models, public write contracts, native projection extraction, file identity and metadata transactions. The public facade remains the entry point, not the owner of POSIX copying/sync/rename machinery.
4. Make selective extraction perform only the requested metadata work, while retaining the same concrete parser, Accurate audio credibility, identity/version/audio checks, native verification, global TagLib guard and durable atomic commit.
5. Compare the same warmed workloads before/after. All strict native-state gates, policy checks, independent consumers, targeted sanitizer checks and real AudioMator local-candidate verification must pass; do not claim UI or minimum-platform runtime acceptance.

## Baseline

[All 48 measurements](ARCHITECTURE_IO_BASELINE_2026-11-14.json) were captured before production edits. Three containers × ordinary/metadata-and-artwork fixtures × eight APIs include bridge Basic/raw/structured/zero-mask extraction, facade raw/structured/snapshot, and real verified title writes. Heavy fixtures contain 64 multivalue custom keys and a 1 MiB JPEG payload. Read immutability, untouched raw arrays and artwork are asserted. The benchmark reports three batch-average samples, not per-operation tails or a device-wide guarantee.

Reproduce with `TAGLIB_BENCHMARK=1 TAGLIB_BENCHMARK_PROFILE=projections swift test -c release --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror --filter SnapshotThroughputBenchmarkTests`.

## Initial diagnosis

- Four internal Swift retention/verification functions and one native number-text helper have no callers.
- Snapshot/read overloads and one Structured initializer retain older function-reference shapes. Bool erase/raw wrappers discard a verified result's commit status.
- The field registry still carries canonical-owner flags and empty collision/preferred-owner tables even though built-in fields are now all canonical. This phase intentionally simplifies that public schema model rather than retaining extensibility solely for historical shapes.
- `TagLibMetadataManager.swift` combines POSIX transaction machinery with public result types and format discovery. Snapshot models share a file with patch execution.
- Raw/structured/zero-mask native reads build discarded Basic/custom/artwork projections. Public bridge single-view readers request all views. Readability checks still materialize full Basic tags for a parser/audio-credibility decision.

Implementation and final evidence will be appended as each phase passes.
