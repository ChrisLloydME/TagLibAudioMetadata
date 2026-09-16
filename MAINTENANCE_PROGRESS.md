# Metadata Architecture Maintenance Progress

Last updated: 2026-09-15

## Scope

This journal tracks package-side work for the coordinated metadata correctness and architecture review. TagLibAudioMetadata is an independent Swift package and must remain usable without AudioMator assumptions. AudioMator has a separate journal in its repository.

## Current findings

- Work begins on branch `codex/wav-number-pair-stability`, tracking `origin/wavNumberPairStability`; the working tree was clean before this journal was added.
- The package already exposes `MetadataSnapshot`, `MetadataPatch`, `RawMetadataPatch`, `MetadataFileVersion`, and `expectedVersion` APIs with regression tests.
- The high-level product previously source-reexported `CTagLibBridge` through `LegacyBridgeReexport.swift`, despite defining a separate low-level product.
- Swift transaction identity includes link count. The Objective-C++ transaction path had an independent version comparator that omitted link count, allowing transaction behavior to drift.
- Legacy `AUDIOMATOR_*` exact-number metadata keys remain readable for compatibility. New exact-text writes use package-neutral `TAGLIBAUDIOMETADATA_*` keys; relevant pair edits migrate lazily and unrelated edits preserve legacy storage.
- The legacy Objective-C model retains a Boolean `explicitContent` compatibility property that maps `false` to `clean`; the typed `explicitAdvisory` model itself has four states.

## Confirmed hypotheses

- Public API boundary: confirmed that the high-level module currently reexports the bridge.
- Product-neutral metadata: confirmed that AudioMator-branded keys remain in externally observable read/write logic; migration behavior still needs exact characterization.
- Duplicate transaction machinery: confirmed structurally. The safe Swift facade now has one authoritative Swift coordinator; the separately named low-level bridge product retains its own coordinator for direct Objective-C callers. Consolidating those across the product/language boundary would be a separate breaking redesign, so this maintenance pass instead aligns and regression-tests their identity and hard-link invariants.
- Hard-link identity drift: confirmed. The Objective-C++ final version comparison omitted `st_nlink`; the comparator and commit-time policy now require the link count to remain exactly one.
- Schema ownership: only `DATE` is shared, intentionally, because date/year and release-date projections map to one native field in several containers. Shared ownership and preferred scalar lookup are now explicit and tested.
- High-level bridge exposure: confirmed and fixed for the upcoming 0.5 line. Direct bridge users must add `TagLibAudioMetadataLowLevel` and `import CTagLibBridge`.

## Pending verification

- Consider a later mechanical rename of remaining package-internal historical `AudioMator*` symbols. They are not externally observable; user-facing error text and written metadata no longer carry AudioMator product assumptions.
- Publish the intentional breaking high-level bridge-boundary/API changes as version 0.6.0 before AudioMator can resolve its final remote dependency requirement.

## Architectural direction

- Keep semantic API, transaction coordination, and container codecs as distinct layers.
- Make one transaction coordinator authoritative where practical; otherwise enforce identical version and hard-link invariants with tests.
- Preserve read compatibility for legacy AudioMator keys, write only package-neutral keys, and migrate only when the relevant number metadata changes.

## Completed tasks

- Established repository/branch baseline.
- Created this durable journal before substantive refactoring.
- Aligned the Objective-C++ transaction identity check with Swift link-count semantics and added a Swift coordinator regression test for a hard link created during mutation.
- Added package-neutral MP4 exact-number provenance keys with backward reads and lazy, pair-specific migration of legacy AudioMator keys.
- Made the `DATE` shared-owner exception explicit and added an undeclared-collision regression test.
- Removed the high-level bridge reexport and updated package tests and migration documentation for the explicit low-level product.
- Extended `MetadataPatch` with an intentional formatted track/disc payload so exact number text, advisory, artwork, and ordinary semantic fields can share one transaction.
- Corrected WAV formatted-number writes to target the WAV ID3v2 tag and save with `StripNone`, matching the typed number-pair path instead of routing exact text through a normalizing PropertyMap.
- Added a mixed RIFF INFO + ID3v2 WAV regression covering exact `01/10` and `02/03` text, movement number/count, untouched INFO bytes, and continued readability.
- Removed AudioMator-specific wording from low-level bridge errors; remaining AudioMator-prefixed C++ identifiers are private historical implementation names only.

## Tests and validation

- Passed: `swift test --filter SameFileTransactionTests` (3 tests) using installed stable Xcode 27 / Swift 6.4.
- Passed: `swift test --filter FixtureMetadataRoundTripTests/testM4A` (12 tests).
- Passed: `swift test --filter FormatCapabilityTests` (15 tests).
- Environment note: `/Applications/Xcode-beta.app` is not installed, so the required beta toolchain could not be used; `/Applications/Xcode.app` is the active developer directory.
- Passed: full `swift test` (113 tests, 2 opt-in tests skipped, 0 failures).
- Passed: focused formatted-number `MetadataPatch` tests, including rejection of competing typed and exact representations before mutation.
- Passed after formatted-number patch API: full `swift test` (115 tests, 2 opt-in tests skipped, 0 failures).
- Passed after the WAV exact-number correction: full `swift test` (116 tests, 2 opt-in tests skipped, 0 failures).

## Commits

- `85596ad` — `docs: start metadata maintenance journal`
- `6ea5195` — `fix: detect hard links added during transactions`
- `6bfd1b1` — `refactor: enforce package metadata boundaries`
- `252c16d` — `feat: include formatted numbers in semantic patches`
