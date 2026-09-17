# Maintenance Progress

Last updated: 2026-09-17

## Scope and product boundary

This journal tracks the independent maintenance review of TagLibAudioMetadata. The package may serve AudioMator, but its public API, safety guarantees, tests, and release process must remain suitable for unrelated third-party consumers. AudioMator has a separate journal in its repository.

## Baseline architecture inspected

- `Package.swift` publishes a high-level `TagLibAudioMetadata` product and a public `TagLibAudioMetadataLowLevel` product backed directly by `CTagLibBridge`.
- The high-level Swift facade owns typed snapshots, patches, verification policy, and transaction-facing models; the Objective-C++ bridge also contains transaction and in-place mutation machinery.
- Package targets currently support macOS 13 and iOS 16 and use Swift tools 6.0 plus the binary TagLib target.
- Tests cover format capabilities, fixtures, raw patches, same-file transactions, concurrency, reliability fault injection, public API compatibility, and WAV projection.

## Confirmed problems

- The Swift field registry treated `ARTISTTYPE` as canonical while the bridge and
  typed object codec wrote `MUSICBRAINZ_ARTISTTYPE`; the prior consistency test
  used set containment and could not detect canonical order drift.
- Both raw PropertyMap write families use TagLib `setProperties`, so their default
  semantics are complete replacement. Multi-value API naming/documentation did
  not expose a merge choice, and replacement verification checked only supplied
  keys rather than proving omitted old keys were gone.
- `VerificationFailurePolicy.warn` was selectable even though all verification
  mismatches throw and roll back. The weaker policy cannot satisfy the package's
  transaction contract.
- `syncBasicFieldsToInfo` proceeded into a transaction even though it is not
  implemented, then manufactured a verification failure.
- Low-level bridge code reported committed-but-durability-uncertain using a
  private magic NSError code (`9110`) rather than an exported typed contract.
- The public `TagLibAudioMetadataLowLevel` product exposes all package-internal
  `*InPlace` mutations and the mutation-coordination block.

## Rejected or revised findings

- The process-wide recursive mutex does not serialize whole transactions. Source
  inspection shows it covers TagLib entry points/object lifetimes; file copying,
  flushing, rename, and directory syncing occur outside it. A separate per-entry
  lock serializes transactions for the same destination. The conservative global
  TagLib lock remains justified by shared TagLib registries.
- Logging is opt-in rather than unsolicited, but the bridge accepted an
  AudioMator-specific environment variable. That product-specific alias was
  removed; `TAGLIBAUDIOMETADATA_DEBUG` remains the independent package switch.
- The two transaction engines have different jobs today: bridge methods provide
  safe low-level single-operation transactions, while the Swift engine keeps
  multi-step mutation plus semantic verification inside one pre-commit staging
  transaction. Consolidation without a generic internal transaction SPI would
  either duplicate staging or weaken verification; no speculative rewrite yet.

## Architectural decisions

- Preserve the existing transaction guarantees (identity/version validation, same-directory staging, verification, fsync, atomic replacement, parent-directory durability reporting) unless direct source inspection demonstrates a defect.
- Raw in-place mutation primitives must not become the default third-party escape hatch merely because an advanced product is public.
- Canonical metadata mapping order is behavior because the first property-map key controls typed writes.

## Completed changes and commits

- Canonicalized artist type on `MUSICBRAINZ_ARTISTTYPE` across the Swift schema and
  bridge, with ordered cross-language schema assertions.
- Added `.replace`/`.merge` mode to multi-value raw writes and complete-map
  replacement verification, including stale omitted-key detection.
- Made `.warn` unavailable and made unsupported RIFF INFO synchronization fail
  before staging begins with `unsupportedWritePolicy`.
- Exported the low-level NSError domain and typed durability-uncertain code.
- Removed the AudioMator-specific debug environment alias.
- Consumer-contract corrections committed as `fa34ed4`.
- Moved every in-place mutator and the coordination callback out of the public
  Low-Level header into the non-product `CTagLibBridgeInternalAPI` target. Public
  bridge mutators continue to use the safe transactional implementation.

## Tests added or updated

- Exact ordered bridge/Swift mapping comparison and explicit artist-type mapping.
- Raw scalar and multi-value replacement/merge behavior, including removal of
  omitted keys and preservation under merge.
- Unsupported RIFF write policy fails without changing original bytes.
- Public low-level durability error domain/code availability.
- Public Low-Level header exclusion test plus an external consumer build: safe
  Low-Level selectors compile, while `writeMetadataInPlace` is no longer a member.

## Remaining work

- Inspect the public low-level headers/product boundary and durability-uncertain contract.
- Commit the validated Low-Level public-boundary isolation.
- Determine whether the two transaction engines can be consolidated without weakening guarantees.
- Audit logging, lock granularity, public surface, CI, release tooling, and documentation.

## Unresolved questions

- Whether an intentionally public safe low-level product is still needed after unsafe primitives are hidden.
- Whether source generation or a shared generated mapping artifact is the least fragile cross-language schema design.

## Cross-repository dependencies

- AudioMator currently resolves published TagLibAudioMetadata 0.5.1. Package API changes must be released independently and then deliberately adopted by AudioMator.
