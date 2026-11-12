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
