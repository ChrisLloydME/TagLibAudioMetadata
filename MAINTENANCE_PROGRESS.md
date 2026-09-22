# Maintenance Progress

Last updated: 2026-09-22

## 2026-09-22 second maintenance pass

### Current status

- Began from clean `main` at `0ccd4a7`. This repository has no `AGENTS.md`; the
  package remains an independent multi-platform product under its existing
  package contract.
- The reported build, sanitizer, and minimum-platform CI failures shared a
  Swift compiler/type-inference failure in
  `TagLibMetadataManager+Read.swift`. The source-compatible correction now lets
  every local lane reach its intended checks; no second-layer defect appeared.
- Xcode 27 is the stable local toolchain. Older supported CI toolchains still
  need source-compatible expressions and remain part of package validation.
- The second pass is complete locally. Implementation, documentation, the full
  package suite, strict-warning build, sanitizer lanes, and minimum-platform
  matrix pass; hosted CI remains authoritative after push.

### Remaining work

- No implementation work remains in this pass. The independent package release
  and downstream AudioMator integration remain deferred to release preparation.

### Completed changes

- Replaced three fragile nested capability expressions with explicitly typed
  `FormatCapability` values, `Self.capability(forExtension:)`, and the fully
  qualified `MetadataFieldFormat.mp4` case. The reported failures across the
  ordinary, sanitizer, and minimum-platform jobs shared this compiler-inference
  root cause rather than representing eight independent defects.
- Routed `updateBasicMetadata(at:_:)` through `readBasicSnapshot(from:)`,
  avoiding unused structured/container models without changing provenance or
  optimistic-concurrency semantics.
- Updated current architecture/support documentation for clone-or-copy staging
  and the focused update path; the 2026-09-01 migration report is explicitly
  labeled as historical evidence. The Xcode 27 workflow no longer calls the
  stable toolchain a preview.

### Commits

- `c9ff8a4` — open the second package maintenance pass.
- `299a506` — fix capability inference on supported CI toolchains.
- `fdef171` — use focused snapshots for Basic metadata updates.
- `3150c1e` — refresh package maintenance documentation.

### Tests and validation

- Complete package suite: 137 tests executed, 2 opt-in tests skipped, 0 failures.
- Strict warning build passed with Swift and Clang warnings treated as errors.
- macOS 13 builds passed for arm64 and x86_64.
- iOS 16 builds passed for device arm64 and Simulator arm64/x86_64.
- AddressSanitizer and ThreadSanitizer suites each passed 137 tests with the same
  2 opt-in skips. These local runs confirm both jobs now reach sanitizer execution;
  hosted CI remains authoritative for its older runner toolchain.
- Final post-documentation/optimization package suite: 137 tests executed, 2
  opt-in tests skipped, 0 failures.

### Deferred release integration

- Publish these package changes only during release preparation. AudioMator must
  then update its exact pin, map typed commit status, adopt selective Basic reads,
  and execute cross-repository integration coverage.

## 2026-09-21 coordinated reliability pass

### Current status

- The worktree began clean on `main` at `62dcf9b`.
- The new audit was checked against current source. The first mutation-contract
  problems are now fixed and the pass has moved on to API misuse resistance.

### Newly confirmed findings

- High-level writes still throw `committedButDurabilityUncertain` after atomic rename when parent-directory `fsync` fails. Tests prove the new metadata is already visible, but the public result cannot represent that committed state.
- `MetadataNumberTextPatch.trackNumberText` remains mandatory. Disc-only formatted edits therefore cannot be represented without also enabling the track-pair write.
- `applyMetadataPatch` still requests `.all` verification projections even for scalar-only changes.
- Extension capability and concrete-file validity are distinct in implementation, but public naming and consumer guidance still deserve review.
- `VerificationFailurePolicy` has one usable case; it remains compatibility surface rather than a meaningful policy.
- `BasicMetadata.empty` plus whole-object writes remains potentially destructive by design and needs an explicit API/deprecation decision.

### Revised or already-addressed findings

- Transaction duplication is not presently equivalent duplication: the Swift facade keeps multi-step semantic verification inside one transaction, while public bridge methods provide safe single-operation transactions. Consolidation remains deferred pending a generic internal SPI.
- The process-wide TagLib mutex does not cover copying, `fsync`, rename, or directory sync; it protects TagLib entry points and shared registries.
- Unsafe in-place bridge methods are already isolated from the public low-level product.
- Optional read helpers no longer print unsolicited diagnostics; throwing reads are already the detailed primary path, though lossy naming remains under review.

### Immediate implementation order

1. Return a typed durability status from high-level write APIs after successful rename, reserving throws for pre-commit failures.
2. Redesign formatted number patches so track and disc can independently be unchanged, set, or removed; preserve source compatibility where practical.
3. Add focused transaction and number-representation regressions, then run the complete package suite before committing.
4. Continue the whole-object API, verification projection, capability, fixture-level, and explicit-advisory review after the correctness contract lands.

### Completed in this pass

- Added `MetadataCommitStatus` to high-level write results. Successful rename plus
  failed parent-directory `fsync` now returns `.durabilityUncertain(detail)`;
  pre-commit failures still throw, and the internal generic transaction helper
  retains its historical typed error behavior.
- Made `MetadataNumberTextPatch.trackNumberText` optional with the same semantics
  as disc text: `nil` unchanged, nonempty set, empty remove. The package-internal
  bridge now gates track and disc mutation independently for PropertyMap, ID3,
  MP4, and WAV paths.
- Added fault-injection coverage proving a high-level committed-but-uncertain
  result leaves the changed metadata visible, plus M4A regressions proving
  disc-only and track-only formatted edits preserve the opposite representation.
- Added `updateBasicMetadata(at:_:)` for version-checked read/modify/write edits
  and explicitly named the destructive whole-object operation
  `replaceBasicMetadata`. The ambiguous `writeMetadata` and
  `writeMetadataWithVerification` entry points remain available as deprecated
  source-compatible wrappers.
- Added regressions proving the safe update preserves an unspecified artist and
  the explicit replacement clears it.
- Removed the obsolete `failurePolicy` argument from the primary verified-write
  APIs and renamed internal verification handling around failures rather than
  warnings. Verification mismatches still always abort before commit; the
  one-case policy type and labeled overloads are deprecated compatibility
  surface, so existing callers can migrate without an immediate source break.
- Migrated package tests and current documentation examples to the policy-free
  APIs; historical changelog entries retain the signatures they documented at
  the time.
- Deprecated only the setter of the lossy `BasicMetadata.isExplicit` Boolean.
  The compatibility getter remains, while writes now point consumers to the
  four-state `explicitAdvisory` value.
- Kept throwing result reads as the primary error-preserving interface and
  renamed optional conveniences around explicit `bestEffort` semantics. The
  old optional names remain as deprecated wrappers, and stale documentation
  claiming that they print errors was corrected.
- Separated extension declarations from concrete-file validity in public naming:
  `capability(forExtension:)`, `isReadableExtension`, and
  `isWritableExtension` describe configured support, while `probeFile(at:)`
  opens and reads the actual file before returning its capability. Ambiguous
  legacy names remain deprecated wrappers.
- Revised the fixture-coverage finding: production does not inspect repository
  fixtures at runtime. `fixtureCovered` is static evidence metadata configured
  in the capability registry, and documentation now states that it is neither a
  per-file validation result nor a blanket release guarantee.
- Added `readBasicSnapshot(from:)`, returning normalized Basic metadata and its
  exact `MetadataFileVersion` without constructing the structured inspector
  projection. This creates a focused loading path for consumers such as
  AudioMator after an independent package release.
- Routed `updateBasicMetadata(at:_:)` through that focused snapshot path, so a
  Basic read/modify/write no longer constructs unused structured/container
  inspector models while retaining the same version-checked replacement.
- Revised the patch-verification performance finding: current `.all` reads are
  not merely verifying changed scalar fields. They also enforce preservation of
  every untouched PropertyMap value and artwork collection. Removing structured
  verification would weaken that contract; an artwork-only bridge projection
  remains a possible future optimization, not a safe change in this pass.
- Replaced both transaction engines' generic sibling copy with macOS
  `copyfile(COPYFILE_CLONE | COPYFILE_ACL)`. The flag attempts a same-volume
  copy-on-write clone and automatically falls back to a regular copy, while the
  existing verification, fsync, identity, atomic rename, ACL/xattr/flags, and
  cleanup behavior remains in place.

### Validation in this pass

- Focused reliability and fixture round-trip suites: 85 tests, 0 failures.
- Focused Basic replacement/update and public API compatibility suites: 7 tests,
  0 failures.
- Complete package suite after the Basic API changes: 133 tests executed, 2
  opt-in tests skipped, 0 failures.
- Complete package suite after the verification-policy migration: 133 tests
  executed, 2 opt-in tests skipped, 0 failures.
- Advisory model semantics suite after deprecating the Boolean setter: 3 tests,
  0 failures.
- Complete package suite after the best-effort read API migration: 135 tests
  executed, 2 opt-in tests skipped, 0 failures.
- Complete package suite after extension/probe capability separation: 136 tests
  executed, 2 opt-in tests skipped, 0 failures.
- Complete package suite after the focused Basic snapshot API: 137 tests
  executed, 2 opt-in tests skipped, 0 failures.
- Complete package suite after copy-on-write staging: 137 tests executed, 2
  opt-in tests skipped, 0 failures. The existing dual-engine preservation test
  continued to pass for xattrs, ACLs, flags, permissions, and payload bytes.

### Commits created in this pass

- `9d85a01` — reopen the package reliability journal.
- `1436956` — fix committed write and number-patch outcomes.
- `300f16d` — clarify destructive Basic metadata replacement.
- `17a808b` — deprecate the obsolete verification failure policy.
- `3ae4879` — deprecate the lossy explicit-advisory setter.
- `1eb4069` — make lossy read semantics explicit.
- `2ceac41` — separate extension support from concrete-file probing.
- `5174cf0` — add focused Basic metadata snapshots.
- `2fb5597` — use copy-on-write transaction staging.

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
- The audit's optional-read logging finding was also confirmed: the legacy
  nonthrowing `readMetadata` convenience printed the source filename and error
  directly to stdout. It now returns `nil` without unsolicited diagnostics;
  callers that need details use `readMetadataResult`.
- A full AudioMator integration run exposed a transient false read conflict.
  Read validation compared status-change time even though permissions, ACLs, or
  extended attributes can change it without changing audio bytes. Read guards
  now compare entry identity, size, and modification time; optimistic mutation
  versions retain the stronger full identity including status-change time.
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
- Low-Level boundary isolation committed as `f6a314d`.
- Removed unsolicited stdout logging from the nonthrowing read convenience and
  separated read-content stability from the stricter mutation version identity.
- Read-content identity and logging corrections committed as `f0ea153`.

## Tests added or updated

- Exact ordered bridge/Swift mapping comparison and explicit artist-type mapping.
- Raw scalar and multi-value replacement/merge behavior, including removal of
  omitted keys and preservation under merge.
- Unsupported RIFF write policy fails without changing original bytes.
- Public low-level durability error domain/code availability.
- Public Low-Level header exclusion test plus an external consumer build: safe
  Low-Level selectors compile, while `writeMetadataInPlace` is no longer a member.
- Read-identity tests prove status-only permission changes remain readable while
  byte/size changes are rejected.
- Added a source-policy regression preventing `print`, `debugPrint`, or `NSLog`
  calls from returning to the high-level Swift facade. The bridge's environment-
  gated diagnostic logger remains deliberately opt-in.

## Remaining work

- Publish the coordinated package changes as a new independent release before
  AudioMator can adopt them from its remote exact-version dependency.
- A future generic internal transaction SPI could consolidate staging mechanics,
  but only if it preserves the Swift facade's multi-step semantic verification.
- Source-generating the cross-language schema remains an optional maintainability
  improvement; the exact ordered consistency tests currently fail closed on drift.

## Unresolved questions

- Whether an intentionally public safe low-level product is still needed after unsafe primitives are hidden.
- Whether source generation or a shared generated mapping artifact is the least fragile cross-language schema design.

## Cross-repository dependencies

- AudioMator currently resolves published TagLibAudioMetadata 0.5.2. Package API changes must be released independently and then deliberately adopted by AudioMator.

## Validation

- Complete package suite after the final read/logging fixes: 128 tests executed,
  2 opt-in tests skipped, 0 failures.
- CI configuration includes strict warning builds, external high- and low-level
  consumers, dynamic-link audit, AddressSanitizer, ThreadSanitizer, release tests,
  and minimum-platform macOS/iOS builds. Those hosted CI jobs were inspected but
  were not reproduced locally in full.
