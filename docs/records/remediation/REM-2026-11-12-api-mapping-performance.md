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
