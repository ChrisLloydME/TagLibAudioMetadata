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

## API consolidation accepted in focused checks

Removed four uncalled Swift helpers, one uncalled C++ number helper, Bool-only write wrappers, redundant read-function arities and three forwarding model constructors. The schema registry now has one canonical collection and a private single-owner engine-key index; the old alias flag and empty collision/preferred-owner tables are removed deliberately under the new cleanup request. Native targets, qualified keys and recovery are unchanged. Current result-bearing consumer calls and full function references compile strictly; capability/registry/audit-remediation tests pass. No failed intermediate compile was committed.

## Ownership split accepted in focused checks

Moved file identity and the existing complete transaction implementation into internal Storage services; moved snapshot values and public nested write contracts into Models/Contracts. Native extraction/readability now has a single internal reader boundary shared by facade reads and storage. Removed the unused public Swift extraction-options type: no public facade operation accepted it; the native low-level option type remains supported. Snapshot tokens no longer depend on a facade-nested POSIX type. Updated API generation to recurse and retain relative source paths. Strict API, identity, transaction, read-lookup, durability and audio-identity checks passed (`/tmp/taglib-architecture-split-fixed.log`).

## Selective extraction accepted in focused checks

Native format branches now skip unrequested Basic/custom/artwork/date projection work; the common PropertyMap is materialized only when needed. Full extraction preserves its prior ordering. Direct bridge Basic/raw/structured readers request their own view. Swift and native transaction readability use the existing zero-mask path with the same parser and Accurate audio credibility; global parser locking, version checks and durability remain intact.

All 32 option combinations match full extraction across 19 native fixtures (including tracker, Ogg and DSD) and three rich temporary copies; every declared Basic carrier property is enumerated. Invalid zero-mask/parser-mismatch inputs and direct native writes fail without file changes. All three regressions are gate-required; all 30 policy checks pass. Existing focused native-state/fixture/transaction checks passed (93 XCTest functions).

The [first optimized run](ARCHITECTURE_IO_OPTIMIZED_2026-11-14.json) and [repeat preserving full-read order](ARCHITECTURE_IO_OPTIMIZED_REPEAT_2026-11-14.json) retain all 48 rows. Raw/structured and readability work are consistently faster, but full snapshots and durable writes vary; the first run has 12–33% slower heavy snapshots and 2–7% slower several writes. The repeat reduces that difference but does not establish a universal snapshot or write improvement. Results are local warmed batch averages; no result is discarded or promoted to a throughput guarantee.

## Complete-read and planning boundaries

All full facade reads and verification now use one complete native-view contract; missing structured evidence throws rather than being replaced by an empty model. Removed the additional tuple-only Basic forwarding helper. The semantic storage planner now takes explicit format/family values and no longer queries the facade. Each patch resolves these immutable values once for planning and verification. Native extraction has a local autorelease pool to bound temporary NSString/NSData/collection lifetimes during a long batch; returned dictionaries retain their values. The selective contract now also compares every stored facade Basic property and raw/structured values across public read entry points after nested pools drain. Strict focused checks pass: 13 XCTest and 46 Swift Testing declarations (`/tmp/taglib-read-planning-pools-fixed.log`).
