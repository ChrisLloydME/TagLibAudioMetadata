# API ownership and metadata I/O performance — 2026-11-12

Branch: `codex/api-mapping-performance`. Baseline: published 0.7.3 (`7ca1b75326388a5902815f70145b600299944ae0`). This is unreleased work; commits record each independently reviewable phase.

## Scope and acceptance

1. Audit backward source-compatibility paths separately from native-file read compatibility. Remove ambiguous API aliases and obsolete bridge-version dispatch, without discarding existing native metadata or disabling explicit legacy-number recovery.
2. Keep one semantic meaning per public field: YEAR and standalone DATE remain independent. Deprecation alone is insufficient for an alias that still denotes a different field.
3. Establish warmed Release read/write measurements before performance edits. Include multiple containers, ordinary and metadata-heavy files, exact API names, repetition counts, medians and tail latency. Setup is outside measured intervals; timings are local observations.
4. Optimize measured redundant work while preserving concrete-layout capability checks, native owners/arrays, exact version and audio guards, atomic staging, verification and durable flushes. Do not remove the TagLib serial guard or weaken durability for a throughput number.
5. Run strict Debug/Release package gates, documentation/generator and policy checks, independent consumers, and the real AudioMator integration using an explicit local candidate. API removals require migration notes and consumer updates.

## Initial diagnosis

- `MetadataFieldKey.date` is a live YEAR alias although `BasicMetadata.date` means independent DATE; planning/validation retains branches for both spellings.
- `TagLibMetadataManager+Compatibility.swift` preserves older function-reference arities and failure-policy overloads. Several other deprecated entry points retain ambiguous replacement/read names.
- `bridgeTextDumpIfAvailable` dynamically probes obsolete bridge selectors despite Swift and the bundled bridge being built/released together.
- The Boolean advisory setter cannot distinguish absent, not-explicit and clean states.
- Declared format capabilities are repeatedly reconstructed across the bridge; these descriptors are immutable, unlike per-file metadata/version/layout evidence.
- The existing optional benchmark measures warmed reads and verified writes. It is retained and expanded; no skipped production regression is introduced.

## Evidence

Baseline, measured decisions, implementation commits and final acceptance will be appended as work completes. No performance gain or release readiness is claimed before those checks execute.

## Baseline captured before production edits

The expanded `SnapshotThroughputBenchmarkTests` ran in Release with `TAGLIB_BENCHMARK=1`, `--disable-sandbox --disable-keychain --disable-netrc`. All 33 profile measurements completed. Ordinary and 64-key metadata-heavy MP3/MP4/FLAC fixtures are measured separately; each API has five warmed samples and fixed iteration counts. Read probes also assert exact file-byte immutability. Verified writes include real staging, verification and flushes. [Raw baseline measurements](API_IO_BASELINE_2026-11-12.json) are committed; host logs remain outside source control.

A concrete mapping-maintenance defect was also found: `MetadataFieldSchema` still accepts `id3`, `id3User`, `mp4` and `mp4Freeform` call-site hints and discards them. Some hints contradict the actual catalog (for example Release Date still lists ©day). These obsolete second-table hints will be removed; native-file aliases with preservation/migration purpose will remain explicitly separated.

## API cleanup accepted independently

Removed the typed `.date` YEAR alias, dead native-target hints, deprecated read/replacement/failure-policy overloads, old function-reference arities, runtime selector fallback and lossy Boolean advisory setters/expectations. The bridge descriptor now orders YEAR before its engine DATE alias, matching the single Swift owner. Existing file aliases and explicit numbering recovery remain intact. Strict focused tests passed (29 XCTest and 7 Swift Testing declarations). The complete strict Debug gate then passed: 158 XCTest declarations (156 passed, the two existing opt-in skips), 179 Swift Testing declarations in 41 suites, and every mandatory native matrix. See `.build/test-evidence/debug-20261112-131752-18246/`. No warning demotion remains on the test target. This is intentionally breaking source API work, not a patch-compatible release.

## Performance implementation

Only build-time declared capabilities are cached; exact extension support levels and value-copy behavior are verified against the bridge. Per-read indexes preserve first-owner precedence and native values; Unicode raw keys retain the prior Foundation comparison. The same index now supplies custom-field arrays, removing a quadratic scan across custom fields and raw properties. Redundant pre-read identity lookup is combined without removing the post-read check. No mutable per-file state is cached.

A first profile found the descriptor query approximately 100 times faster while metadata-heavy reads remained limited by custom-field assembly. That evidence motivated the second lookup change; the final identical-workload profile is recorded separately below. The optional benchmark reports batch-average latency distributions, not per-operation tail percentiles.

The pinned binary's namespaced headers and its Stem item type are now used directly; silent fallback to an unrelated old host framework has been removed. This does not change the binary version or checksum.

Focused strict checks after these changes passed 27 XCTest and 24 Swift Testing declarations, including the native audit regressions. Gate policy now requires all four new passing XCTest identities and a 162-declaration floor; all 26 policy tests pass. Full strict Debug/Release and real consumer acceptance remain pending until their evidence is appended.

## Measured outcome on the same Apple M1 host

The final Release profile completed successfully on production commit `3ab2a34` with strict Swift/C warnings. [All 33 candidate measurements](API_IO_OPTIMIZED_2026-11-12.json) retain the same workloads and five-sample metric definition as the baseline. Values below are median batch-average milliseconds per operation. These are descriptive local samples, not confidence intervals or performance guarantees.

| Container | Metadata | API | Baseline median ms | Candidate median ms | Change |
| --- | --- | --- | ---: | ---: | ---: |
| mp3 | ordinary | basic | 0.257457 | 0.228923 | -11.1% |
| mp3 | ordinary | snapshot | 0.166703 | 0.156690 | -6.0% |
| mp3 | ordinary | typed-title | 10.518635 | 11.703083 | +11.3% |
| mp3 | ordinary | basic-title | 13.254667 | 14.514000 | +9.5% |
| mp3 | ordinary | raw-title | 11.508083 | 11.454021 | -0.5% |
| mp3 | metadata-heavy | basic | 3.837034 | 3.475606 | -9.4% |
| mp3 | metadata-heavy | snapshot | 3.829472 | 3.437099 | -10.2% |
| mp3 | metadata-heavy | typed-title | 24.464729 | 23.265646 | -4.9% |
| mp3 | metadata-heavy | basic-title | 44.270406 | 41.518219 | -6.2% |
| mp3 | metadata-heavy | raw-title | 19.995281 | 19.495073 | -2.5% |
| mp3 | descriptor-only | declared-capability | 0.012802 | 0.000158 | -98.8% |
| m4a | ordinary | basic | 0.259578 | 0.238181 | -8.2% |
| m4a | ordinary | snapshot | 0.255849 | 0.233211 | -8.8% |
| m4a | ordinary | typed-title | 11.891594 | 9.501698 | -20.1% |
| m4a | ordinary | basic-title | 15.267094 | 13.016781 | -14.7% |
| m4a | ordinary | raw-title | 10.829542 | 9.257416 | -14.5% |
| m4a | metadata-heavy | basic | 4.535545 | 4.194147 | -7.5% |
| m4a | metadata-heavy | snapshot | 4.519643 | 4.181517 | -7.5% |
| m4a | metadata-heavy | typed-title | 26.730573 | 25.784792 | -3.5% |
| m4a | metadata-heavy | basic-title | 57.222031 | 54.745229 | -4.3% |
| m4a | metadata-heavy | raw-title | 29.751198 | 29.501386 | -0.8% |
| m4a | descriptor-only | declared-capability | 0.017918 | 0.000150 | -99.2% |
| flac | ordinary | basic | 0.180699 | 0.178730 | -1.1% |
| flac | ordinary | snapshot | 0.175648 | 0.181012 | +3.1% |
| flac | ordinary | typed-title | 9.899333 | 10.224396 | +3.3% |
| flac | ordinary | basic-title | 13.011083 | 11.452198 | -12.0% |
| flac | ordinary | raw-title | 10.221344 | 9.758448 | -4.5% |
| flac | metadata-heavy | basic | 2.890130 | 2.483096 | -14.1% |
| flac | metadata-heavy | snapshot | 2.883247 | 2.472818 | -14.2% |
| flac | metadata-heavy | typed-title | 19.975250 | 18.504323 | -7.4% |
| flac | metadata-heavy | basic-title | 37.232385 | 33.728198 | -9.4% |
| flac | metadata-heavy | raw-title | 17.250875 | 18.259791 | +5.8% |
| flac | descriptor-only | declared-capability | 0.012230 | 0.000140 | -98.9% |

### Interpretation and remaining costs

- Warm declared-capability queries improve by roughly 80–120 times. First access still constructs immutable descriptors; this is not a cold-start or memory measurement.
- Metadata-heavy Basic/snapshot reads improve by about 7–14% in these samples. Replacing the custom-field nested scan gives the most credible algorithmic improvement; metadata is never cached across files or reads.
- Verified writes reuse the improved reads but remain dominated by native serialization, full preservation verification, staging and hardware flushes. Heavy Basic writes improve 4–9%; some ordinary MP3 writes and FLAC raw writes are slower in this run. The earlier first-pass run varied in the opposite direction for ordinary MP3. Do not claim every write is faster or a statistically established write-speed improvement from five batches. Durability/verification were intentionally retained.
- Full-file copies, large artwork, long or damaged audio, cold filesystems, network volumes, peak memory, sanitizer overhead and application throughput were not benchmarked. This profile is a repeatable package baseline, not universal format/storage coverage.
- Further work should profile bridge projection construction and sorted property conversion, then consider sharing already version-bound read evidence within one transaction. It must not reuse stale metadata, remove independent owner verification, weaken guards or reduce fsync strength. Consumer-side batching should combine already selected edits into one patch, never skip validation. No such next-phase changes are claimed here.

Reproduction: `TAGLIB_BENCHMARK=1 swift test -c release --disable-sandbox --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror --filter SnapshotThroughputBenchmarkTests`. Setup and parser warmup are outside timed regions. Ordinary and 64-custom-key fixtures are separate fresh copies. This run completed before full gates or application compilation began. Raw host logs: `/tmp/taglib-io-optimized-final-benchmark.log`; baseline `/tmp/taglib-api-perf-expanded-baseline.log`. Committed JSON preserves the measured values if temporary logs expire.

The final source review also replaces erase's removed Boolean expectation with exact `.unspecified` advisory verification. Erase intends absence, not a present Clean or Not Explicit value. This strengthens that intermediate verification without changing flush/staging behavior; final gates include the explicit expectation.

## Final verification

Final production implementation: `4dd2a60`; later source changes in this campaign are documentation/comments only. The exact-advisory addition initially had an incorrect argument order, which strict compilation rejected; it was corrected before the final runs. The focused fixture suite then passed 69 tests. The failed intermediate gate remains rejected and is not acceptance evidence.

| Check | Observed result | Evidence |
| --- | --- | --- |
| Final strict Debug | Accepted: 162 XCTest declarations, 160 passed / two existing opt-in skips; 179 Swift Testing declarations in 41 suites passed; all mandatory native matrices | `.build/test-evidence/debug-20261112-133244-22151/` |
| Final strict Release | Accepted: 162 XCTest declarations, 160 passed / two existing opt-in skips; 179 Swift Testing declarations in 41 suites passed; all mandatory native matrices | `.build/test-evidence/release-20261112-133604-22116/` |
| Gate policy | 26 regressions passed | `python3 -m unittest discover -s scripts/tests` |
| Reference/documentation checks | 54 Markdown files and all four generated-reference checks passed | `scripts/check-docs.py` and generators `--check` |
| Independent consumers, final production | Facade and low-level executables built with strict warnings and ran successfully | `/tmp/taglib-io-facade-consumer-final.log`, `/tmp/taglib-io-lowlevel-consumer-final.log` |
| Real AudioMator candidate integration | 62 core and 579 serial app-hosted tests passed; unsigned Release and macOS artifact validation passed. Final affected erase journey also passed after rebuilding against the exact advisory check | Application record `Docs/Engineering/TAGLIB_API_PERFORMANCE_CANDIDATE_2026-11-12.md`, branch `codex/package-api-performance-integration` |

The AudioMator source migration uses current canonical identities without changing its published 0.7.3 dependency pin; evaluation uses the explicit ignored local workspace. Its full Debug run precedes the final erase-only verification addition; the additional affected erase test and Release build include it. Existing application XCTest isolation warnings were not suppressed; strict package gates are separate.

No tag, push, release publication, dependency version bump, binary change or manual application launch occurred. Sanitizers, minimum-platform/device runtime and broad storage/large-artwork performance remain unmeasured. The candidate intentionally breaks the old source interface and must be adopted as an explicitly breaking release with its migration guide.

Both final gates are accepted with all required named matrix/oracle/cache/lookup evidence and no unexpected skips or failed tests. The candidate meets this campaign's API cleanup, package correctness, repeatable performance evaluation and real-consumer integration criteria. It is ready for review and deliberate breaking-version adoption, not an automatic patch publication.

## Later evidence boundary

This record's `4dd2a60` / 162-XCTest final verification is final for the API-cleanup phase described here. The subsequent [write-preparation campaign](REM-2026-11-12-write-concurrency.md) records production `bbf64c3`, 164 XCTest / 179 Swift Testing and both later full gate citations. The [independent-review repairs](REM-2026-11-14-independent-review-repairs.md) supersede both for current advisory erase/preservation behavior. Historical counts are not current-HEAD acceptance. Commit `9e16ccc` itself failed to compile because of argument ordering; `4dd2a60` fixed it. The original phase wording must not be read as a guarantee that every intermediate commit compiles independently; history has not been rewritten.
