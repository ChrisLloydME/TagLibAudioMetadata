# Write concurrency and transaction preparation — 2026-11-12

Branch: `codex/api-mapping-performance`; production baseline `16b01fb`. This campaign continues the API/performance work with no version publication.

## Scope and safeguards

Measure 1/2/4/8 workers on 24 independent files across MP3/M4A/FLAC/AAC/Vorbis/WAV, ordinary and 64-custom-key metadata-heavy workloads. Each worker owns an independent file and uses its captured version. Fresh fixtures, setup and complete readback are outside timing. Every write must report a durable commit, the requested title must persist, and all untouched raw arrays and key date/artist projections must match. Three counterbalanced samples per setting are descriptive local batch medians, not tail percentiles or device-wide recommendations.

Keep TagLib calls serialized and retain same-entry coordination, version/audio guards, staged verified writes, fsync strength and commit-status reporting. Do not remove the global lock based only on a passing stress test. Existing app batch parallelism is four. The prior actual app run measured 48 files / six formats at about 1.60 seconds serial versus 0.49 seconds at four workers; that is previous-run evidence, not the new package benchmark.

## Baseline

[Eight baseline measurements](WRITE_CONCURRENCY_BASELINE_2026-11-12.json) were captured before production edits. Ordinary batches: 285/216/164/123 ms at 1/2/4/8 workers. Metadata-heavy batches: 520/333/267/269 ms. Eight helps the ordinary package workload but does not improve the heavy workload; simply raising the universal limit is not justified by both profiles.

Reproduce with `TAGLIB_BENCHMARK=1 TAGLIB_BENCHMARK_PROFILE=concurrency swift test -c release --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror --filter SnapshotThroughputBenchmarkTests`.

## Investigation and next experiment

Initial source inspection identifies work whose results are discarded: transaction preflight requests full Basic/raw/structured metadata and creates Swift projections solely to establish readability. Each Xiph/APE unified extraction also builds the same visible PropertyMap twice. Evaluate narrower readability extraction and per-open reuse without weakening parser/audio credibility or any persisted-state verification. Full gates, independent consumers and real app integration will be required for production changes.

## Implemented preparation optimization

- Swift transaction preflight uses Basic-only bridge evidence, without creating raw/structured/Swift models that are discarded. It retains the exact extension-selected parser, Accurate audio properties, credibility policy and before/after readable-file identity comparison.
- Public bridge pre/post readability checks use the same Basic-only evidence. Full semantic/native preservation checks on facade writes remain unchanged.
- Unified extraction reuses the visible PropertyMap from the exact same open file for native Xiph/APE dates. A different explicitly selected Ogg parser keeps the existing fallback. No state is retained across reads or transactions.
- New mandatory regressions compare readability across all eleven committed fixture extensions and assert corrupt/wrong-parser files fail before the mutation callback or staging. Gate floor becomes 164 XCTest; 179 Swift Testing and all existing native matrices remain required. All 27 policy checks pass.

Strict focused validation passed 75 XCTest and 24 Swift Testing declarations, followed by the five lookup/readability tests. [Eight optimized samples](WRITE_CONCURRENCY_OPTIMIZED_2026-11-12.json) completed successfully with real durable commits and unchanged-field assertions. At four workers the ordinary batch median changes 164→150 ms and heavy 267→254 ms. Eight-worker heavy batches improve 269→226 ms; ordinary eight-worker batches vary 123→130 ms. These are small local samples, with no universal throughput or per-file latency guarantee.

Full strict Debug and Release gates passed on production `bbf64c3`: each executed 164 XCTest declarations (162 passed, two original opt-in skips) and 179 Swift Testing declarations in 41 suites, with all mandatory native matrices and named preflight/cache/lookup evidence. Evidence: `.build/test-evidence/debug-20261112-135450-25050/` and `.build/test-evidence/release-20261112-135822-25044/`. Both independent consumers compiled with strict warnings and ran successfully; all 27 policy checks passed.

The real AudioMator executor profile also passed: 48 ordinary files took 710/513/343/316 ms at 1/2/4/8 workers; heavy metadata took 1482/910/770/745 ms. Eight versus four adds only about 8%/3% here, so its default remains four. Source inspection found MusicBrainz/iTunes and filename/CSV plans were still serial despite Inspector already being parallel. The app branch now applies the existing four-file executor to those plans, retaining captured values, exact fingerprint preflights, per-file coordination, stable result order and cancellation accounting. Real cancellation/boundary tests pass; complete app gate is pending in `Docs/Engineering/WRITE_CONCURRENCY_2026-11-12.md` on `codex/package-api-performance-integration`.

This campaign does not claim a measured before/after provider-plan speedup from the executor profile alone. The profile measures independent guarded write/reload throughput; the new plan cancellation gate proves four actual file commits can be in flight instead of the old sequential loop. No global TagLib lock or durability guard was removed.
