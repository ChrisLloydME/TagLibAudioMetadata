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
