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

## Final measured candidate

[All 48 final measurements](ARCHITECTURE_IO_FINAL_2026-11-14.json) are from production `f2ac9ad`, after complete-read/planning consolidation and local autorelease pools. All benchmark invocations exited zero and retained raw arrays/artwork/read immutability assertions. The preceding two runs remain available above. Negative deltas mean lower elapsed time; these local three-batch medians are descriptive, not a performance gate.

| Format / density | Facade raw | Facade structured | Full snapshot | Durable typed title write |
| --- | ---: | ---: | ---: | ---: |
| mp3 / ordinary | 0.121 → 0.092 ms (-24.3%) | 0.126 → 0.100 ms (-20.8%) | 0.137 → 0.142 ms (+3.6%) | 9.639 → 10.570 ms (+9.7%) |
| mp3 / metadata-and-artwork | 2.060 → 1.143 ms (-44.5%) | 2.597 → 1.625 ms (-37.4%) | 3.254 → 3.237 ms (-0.5%) | 21.001 → 20.271 ms (-3.5%) |
| m4a / ordinary | 0.192 → 0.141 ms (-26.9%) | 0.201 → 0.162 ms (-19.7%) | 0.216 → 0.228 ms (+5.5%) | 9.400 → 10.438 ms (+11.0%) |
| m4a / metadata-and-artwork | 3.227 → 1.127 ms (-65.1%) | 3.734 → 1.627 ms (-56.4%) | 4.105 → 4.066 ms (-0.9%) | 25.802 → 23.174 ms (-10.2%) |
| flac / ordinary | 0.142 → 0.094 ms (-33.5%) | 0.143 → 0.101 ms (-29.3%) | 0.153 → 0.162 ms (+5.5%) | 9.998 → 9.709 ms (-2.9%) |
| flac / metadata-and-artwork | 1.937 → 0.876 ms (-54.8%) | 2.026 → 0.940 ms (-53.6%) | 2.300 → 2.559 ms (+11.3%) | 19.700 → 17.184 ms (-12.8%) |

The consistent benefit is selective extraction and metadata-heavy verified writes. Ordinary MP3/M4A writes are slower in this final run; heavy FLAC full snapshots are also slower. Full snapshots still need all views and are not universally faster. Explicit pools move temporary-object cleanup into the native read interval instead of deferring it to an outer pool; this bounds the lifetime of native temporaries but changes where cleanup cost is paid. Total process memory was not measured. Durability flushes and complete native verification remain in the write timing. No parser-concurrency increase, reduced verification, or universal write-speed claim is made.

## Final automated acceptance

Production source: `f2ac9adb9cd842f268e65285225c65ce7c815acc`. Subsequent campaign commits contain documentation, measurement artifacts and the policy-test lower-bound assertion only. No production/test Swift or native source changed after the accepted candidate.

| Check | Actual result / evidence |
| --- | --- |
| `TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh debug` | Accepted, exit 0: 167 XCTest (165 passed, two original opt-in skips), 186 Swift Testing in 42 suites; all mandatory named native matrices and selective contracts. `.build/test-evidence/debug-20261114-182100-6841/` |
| Same full strict Release gate | Accepted, exit 0, same counts and mandatory evidence. `.build/test-evidence/release-20261114-182604-7715/` |
| Policy / documentation / generators | 30 Python policy tests, 57 Markdown files, API/field/format/mapping checks passed. A one-declaration shrink below the new XCTest floor is rejected. |
| Independent consumers | Both facade and low-level products compiled with strict Swift/C warnings and ran successfully (37 readable extensions / low-level consumer OK). `/tmp/taglib-architecture-consumer.log`, `/tmp/taglib-architecture-lowlevel-consumer.log` |
| Targeted Address Sanitizer | Exit 0, 15 XCTest plus 17 Swift Testing passed, no report. `/tmp/taglib-architecture-asan.log` |
| Targeted Thread Sanitizer | Exit 0, same 15 + 17 passed, no report. `/tmp/taglib-architecture-tsan.log` |
| AudioMator local candidate | Unchanged app source `0e739d982520127d7ee5a2962cb5e7afab4f12f3`, clean package candidate `f2ac9ad` captured in `source.txt`; 13 policy checks, 62 core tests and 580 serial app-hosted tests passed, followed by unsigned Release and artifact validation. App evidence `.deriveddata-codex/Validation/20261114-182135-7046/`. No additional app migration code was required. |

Sanitizers used `swift test --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror --sanitize=address|thread --filter 'SelectiveExtractionTests|ReadLookupPreservationTests|SameFileTransactionTests|ConcurrentFormatOperationTests|ConcurrentM4AReadTests|AudioContentIdentityTests'`. This exercises package/bridge instrumentation, not the prebuilt TagLib binary or the complete parameterized suite. All facade native views remain valid after local/nested pool drainage. Full gates retain the host privilege precondition; no mandatory test was skipped, weakened or made optional.

The manifest sandbox override and filesystem/cache access were needed in this host environment. Existing app MainActor/XCTest initializer warnings remain outside the package cleanup; they were not suppressed. No minimum-platform runtime, device, hosted CI, full-suite sanitizer or manual UI acceptance was performed. No app was manually launched. Published versions, package/binary pins, tags and remote branches were not changed. This remains an explicitly breaking candidate, not a 0.7.x patch.
