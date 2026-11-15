# Package-only test-system upgrade: implementation plan

Date: 2026-11-15 (Asia/Shanghai). Production baseline: `f483f5f` (merged public-write repairs through `c3c655e`; later acceptance documentation). This plan authorizes future implementation; it does not claim that the upgraded test system exists or has passed.

## 1. Objective and absolute repository boundary

Make defects in **this package's own public read/write, mapping, preservation, validation and transaction contracts** detectable independently inside this repository. Read, build, test and assess only TagLibAudioMetadata. Do not access a sibling application, its source, tests, dependency resolution, working directory, UI, provider clients, history or integration results. No application checkout, local override, copied application implementation, application-hosted test or application acceptance is required or permitted. The package's independently built consumers and copied package fixtures are sufficient.

Synthetic package-level operation sequences may resemble how any editor uses a metadata library: read a snapshot, prepare an explicit delta, commit selected fields, reopen, clear, retry only after an explicit new read. Define those sequences from package contracts, not from an external application. They must use the public package products. No network services, account credentials or live provider data.

Finite tests cannot prove every possible file or caller correct. The deliverable is **auditable coverage decisions for every public surface and advertised field**, runtime evidence for the mandatory partitions, calibrated defect detection, and explicit untested limitations. Never turn “all sources reviewed,” counts or a green scalar round trip into a universal safety claim.

## 2. Why the current system needs structural changes

The existing native matrices, strict gates, parser vectors and preservation regressions are valuable and must remain. The recent handoff nevertheless missed:

- a validator/executor identity mismatch: validation inspected an untrimmed MP4 key, execution trimmed it;
- partial surface repair: structured rejection passed while scalar renumbering, whole-model and two raw writers still committed overflow;
- an error sentinel being interpreted as deletion: over-width formatting returned nil;
- preservation assertions comparing date values but omitting protected frame flags;
- a lenient comparison parser reused for input validation;
- descriptor, capability and executable-route disagreements;
- incorrect synchsafe sizes in a test fixture builder.

`ReleaseAcceptanceTests` now exercises these concrete cases, but appending another special suite after every review is insufficient. Existing gate code requires selected names/counts and source inventory, yet mostly identifies Swift Testing execution by bare method names and minima. It needs an explicit contract/surface model and stronger evidence accounting, not a replacement that silently drops old coverage.

Current observed floors are 181 XCTest, 231 Swift Testing declarations and 41 Python policy tests. They identify the baseline, not the target architecture. Do not lower them to make a refactor pass; if names are reorganized, supply an explicit old-to-new case map and equivalent-or-stronger evidence.

## 3. Required deliverables

1. A checked-in public-surface inventory, a test-owned contract/scenario catalog and an explicit coverage-decision ledger.
2. Reusable but bounded fixture builders, independent native oracles and named public writer adapters. Do not replace all native readers with one large generic framework.
3. Public black-box contract suites plus isolated internal unit/fault tests. Actual product consumers perform real fixture writes and native assertions, not only compilation or extension counting.
4. Coverage of field ownership, representability, invalid inputs, preservation, transactions, read projections, concrete versions and public workflow sequences.
5. Deterministic fault/mutation calibration demonstrating that representative historical defect classes are caught.
6. A fail-closed release-evidence runner, schema-validated coverage accounting and adversarial gate-policy tests.
7. An English final evidence record stating exact source/build/test identity, decisions, commands, outcomes and remaining limits. No dependency/version/publication changes and no external application acceptance.

## 4. Architecture: keep five concerns separate

### A. Public-surface inventory

Assign stable IDs to every public read/write entry point, including overloads and modes. Inventory the Swift facade and exported Objective-C header separately. Include:

- Basic read/update/replacement; typed/custom/advisory/artwork patches;
- formatted number text and scalar low-level renumbering;
- scalar/array raw maps, replace/merge modes and raw deltas;
- structured properties versus native atoms/frames/attributes/collections;
- full-model low-level wrapper and **direct exported bridge** calls;
- explicit normalization-plan creation/application, erase and direct wipe;
- expected-version/audio-content overloads and enabled/disabled verification paths;
- complete/selective/raw/structured reads, best-effort variants, capabilities and registry lookups.

Do not count an internal in-place selector as public coverage. Do not treat testing a Swift wrapper as testing the exported bridge, even if it eventually calls it. Resolve signatures from current source/public symbols; use compiler/index/symbol tools where available. A lightweight parser must have syntax fixtures and fail on unrecognized declarations rather than silently omit them. Do not introduce a large new tool dependency just for extraction.

A changed or new public signature must produce a coverage-decision failure until assigned an explicit disposition. Inventory extraction may enumerate production symbols, but it must not derive expected behavior or mark tests passed.

### B. Test-owned contract catalog

Use stable `contract_id`, `surface_id`, `scenario_id`, fixture/version ID and native oracle ID. Define operation intent and the set of permitted changes **before** invoking the SUT. Distinguish modeled full replacement, omission-safe delta, explicit collection removal, raw whole-map ownership and full erase. Store expected native identities/types/components as test-owned literals justified by the contract and pinned engine behavior. Never obtain an expected owner from the same production mapping table being tested.

A catalog row records: field family, destination/tag version, state partition, operation, public entry point/mode, required outcome, owned/untouched identities, normalization rule, validation phase, oracle, runtime test identity and evidence tier. Explicit outcomes are supported, read-only/reject, unsupported/reject, or unverified with a concrete reason. Unsupported is a tested rejection, not a skip. Missing is not unsupported. No catch-all `if capability says unsupported { continue }` may turn advertised coverage into a pass.

Use production schemas/capabilities only to enumerate claims to reconcile against the independent catalog. Adding a field, codec or capability must fail the decision check until reviewed. Do not generate golden native targets or expected success from production metadata.

### C. Execution adapters

An adapter translates a test scenario into **one named public call**, without selecting a fallback. Register adapters once and check that every inventoried write surface has one or an explicit compile-only/read-only rationale. Keep the intended product imports visible. Test the facade-only consumer and low-level consumer as independent external SwiftPM targets with declared product dependencies, no `@testable` imports or internal selectors. Do not claim that transitive module visibility is a security boundary.

Adapters may not repair input, coerce text to integer, suppress errors, clear versions, auto-normalize aliases or retry through a different writer. Failures must identify surface, scenario, fixture and stage. Internal transaction/fault tests remain separate and can use narrow package-private seams.

### D. Native oracles and fixture builders

Reuse the existing MP4, ID3, FLAC, APE, ASF and container/audio readers where trustworthy. Give each a documented bounded grammar and self-tests from literal wire vectors, malformed/truncated inputs, size overflows, supported encodings, extended lengths and container boundaries. A reader must reject layouts it does not understand, not manufacture an empty map. The oracle may use the SUT to check that a fixture is recognized, but its native assertions cannot call the SUT to decide expected values.

Before every operation, independently verify the seed. After it, compare the requested native result, the contract-defined untouched owner multiset (arrays, duplicates, flags and identity), and encoded audio/sample payload where a bounded oracle exists. Do not require whole-file equality after a valid metadata rewrite; metadata padding/order can change. For rejected operations require unchanged original bytes and identity as appropriate.

Correct and self-test builders: ID3 synchsafe sizes at 127/128/255/16383/16384; frame sizes/flags/grouping/encoding; RIFF/AIFF sizes and alignment; DSDIFF nested chunk limits; MP4 data types and extended atom lengths; APE/ASF lengths and language/stream scopes; Ogg packet/page bounds and CRC when the builder changes pages. Unsupported reader scope stays explicit. Never modify repository fixtures in place; use unique per-case copies with deterministic cleanup.

Keep extraction-equivalence tests labeled as equivalence, not independent correctness. Keep external tools optional secondary evidence and record their versions/availability; no release test may require live network access.

### E. Evidence and gate policy

The canonical runner owns fresh run directories and a manifest containing commit, tracked diff and untracked relevant-source hashes, test/contract manifests, build configuration/flags, toolchain/SDK/target, run ID and runner exit status. Include evidence from the actual build inputs, not only current HEAD. Reject source changes during the campaign or require a fresh run. Associate Debug/Release and each platform with separate runs; do not combine fragments from different sources/configurations.

Prefer structured runner/discovery identities when the installed tools provide them. If using text logs, preserve the existing fail-closed parser and explicitly establish one source/suite owner per required bare method name; duplicate/ambiguous names reject. Where feasible migrate to fully qualified identities without weakening old checks. Fail on missing/truncated/unknown-format logs, missing framework completion, named failures, unexpected skips, nonzero status and stale manifests.

Add observed scenario IDs to runtime evidence, and compare the expected/observed sets, not just total counts or maximum counts. Missing, duplicate or unexpected cases and mismatched manifests fail. A completion event is not an assertion pass: framework failures remain fatal, and case events may only describe actions actually executed. Case catalogs may not be “covered” by iterating labels without invoking adapters and oracles. Calibrate this with deliberately removed operations/assertions.

The manifest/hashes prevent accidental stale or mixed evidence; they do not cryptographically authenticate arbitrary logs written by a malicious actor with full repository access. State that limit.

## 5. Mandatory coverage partitions

Use a risk-based finite matrix, not an uncontrolled full Cartesian product. Preserve existing every-field owner/lifecycle and sparse-state matrices. Add the following independent dimensions and explicit coverage decisions:

| Concern | Mandatory partitions and assertions |
| --- | --- |
| Native encoding/shape | Every advertised writable field has native-owner evidence; encoding families include text/arrays, bool, byte, signed/unsigned integers, intPair components, IDs, artwork and qualified collections. Every applicable public surface is exercised for each encoding family it can express. Boundary-derived cases must come from a test-owned domain, not the current validator. |
| Numeric/input representation | min/max, just outside each bound, UInt16 32767/32768/65535/65536, signed/unsigned boundaries, fraction, negative, overflow-length decimal, missing value, wrong object/type, embedded NUL, malformed pair, extra slash, explicit zero total, empty clear, nil omission, case/whitespace identity and mixed valid+invalid payload. Width 0/64/65 and extreme padding rejection must not allocate the requested huge result. |
| Preservation | schema-known but unmodeled owners, unknown/custom owners, both private provenance namespaces, untouched track/disc groups, standard aliases, absent owners, arrays/duplicates/whitespace, comment/lyric qualifiers, status/format/group flags, unsupported opaque structures and audio payload. Model ownership and global schema recognition are distinct. |
| Concrete versions/containers | MP4; ID3v2.4; supported literal v2.3 layouts and safe rejections; WAV/AIFF ID3 saves; Xiph/FLAC/Ogg; APE families; ASF native attributes; supported tracker routes. Enumerate every writable family/extension and distinguish alias compile/config evidence from fixture runtime. Unsupported/unverified codecs and Matroska gates remain explicit. |
| Sequence semantics | read -> edit one owner -> commit -> reopen -> edit another -> clear -> reopen; alternating public surfaces; full-model RMW with unmodeled owners; valid/invalid multi-field atomicity; mixed per-pair intent; normalization preview/apply/version invalidation; erase/reopen. Success must persist the intended owners, not merely return normally. |
| Validation vs execution | Same identity/type policy from preflight to staged execution. Test normalized-key/case variants, caller-facing type mismatches, capability/planner agreement and metadata changed between preflight/staging. Prove preflight timing separately from rollback using narrow observers, not whole-file equality alone. |
| Transactions | stale versions, audio guard mismatch, symlink/hardlink/privilege preconditions, failed clone/save/verification/sync/rename, after-rename directory-sync uncertainty, same-file contention and distinct-file isolation. No blind retry or error-to-deletion sentinel. |
| Reads/registry | 32 extraction masks retain their equivalence contracts plus independent native vectors. Registry namespaces, concrete support and executable writes agree within documented scopes; unavailable role/rate/Matroska paths reject without new fallbacks. |
| Public-use batches | A package-owned sequence prepares explicit patches for multiple copied files; only selected fields change, rejected files remain unchanged, successful files persist. Define per-file transactions; do not claim an all-or-nothing batch API. Exercise numeric IDs as integer values and wrong-kind text rejection without implementing a provider client. |

Not every field belongs on every API: unexpressible fields require omission/preservation tests, not a fabricated setter. “All coverage decisions present” is separate from “all variants runtime tested.” A reasoned unverified row is a limitation, not a passed case or an automatic new support claim.

## 6. Defect-detection calibration: required, not optional

Implement a small deterministic calibration runner using disposable source copies/worktrees **inside ignored package-owned build space**, isolated build paths and copied fixtures. Never mutate the maintainer's active checkout to run mutants; never edit dependency caches/binaries. Normal build/cache use and reading pinned binary headers are allowed. No broad external OCR/model-assisted audit.

For each mutant, record the exact anchored source patch, source fingerprint, focused command, activation witness, expected assertion failure, exit status and restored/isolated state. A mutant counts as killed only if it compiles, demonstrably activates the intended bad behavior and a relevant behavioral assertion fails. Compile errors, missing fixtures, timeouts, unrelated failures or an unapplied patch are inconclusive and fail calibration acceptance. Do not deliberately cause unbounded host allocation; demonstrate the padding defect through a bounded sentinel/validation fault or safe post-bound subprocess rejection.

Minimum calibration set:

1. Remove validation from one exported numeric writer while leaving another correct: cross-surface tests must fail.
2. Validate one key representation but execute another: whitespace/case bypass must fail.
3. Cast a wide native pair component before range checking: boundary byte checks must fail.
4. Treat formatter failure as nil/removal: preservation must fail on a bounded >64-width fixture.
5. Filter every schema-known field out of full-model retention: unmodeled-owner tests must fail.
6. Ignore v2.3 status/group evidence or default a container save to v4: protected-owner/version assertions must fail.
7. Restore an old MP4 freeform after a canonical raw edit: native lifecycle must fail.
8. Coerce an invalid number string to zero or recover an explicitly zero total: intent/preflight checks must fail.
9. Advertise a route the planner cannot execute: capability/route contract tests must fail.
10. Remove an adapter invocation or preservation assertion from a required scenario: evidence/calibration must detect that labels/counts alone are insufficient. If a particular assertion is redundant, identify another relevant behavioral check that kills the mutant rather than weakening it.

Also calibrate oracle independence: deliberately corrupt a saved native value/flag or an oracle vector and require detection; production self-read agreement must not rescue it. Keep targeted calibration bounded and repeatable for CI. Do not install a huge mutation-testing framework. The routine contract lane must enforce calibration status or run the bounded calibration set; a never-run optional script is insufficient. Publish which additional mutants remain deferred.

## 7. Phased implementation and exit gates

### Phase 0 — New branch and baseline

Create `codex/package-test-system-upgrade-20261115` from the documentation handoff checkout. Preserve user changes; do not edit main or reset/rewrite history. Read current code/tests/gates and the previous repair/acceptance record. Confirm baseline public API inventory, test discovery, current required manifests and tool availability. Record feasible baseline runs and environment blockers honestly. Do not copy stale counts from documentation.

Exit: branch exists; evidence identity recorded; gap ledger links each recent escaped defect to a missing surface/partition/assertion.

### Phase 1 — Inventory and contract catalog

Implement schema-validated inventories/coverage decisions and policy unit tests. Reconcile both public products, every overload/mode and every advertised field/family. Include explicit by-design decisions. Fail on new/unclassified claims, duplicate identities and missing adapters. Keep expected native targets independent of production.

Exit: adding a fake new API/field or deleting a decision causes a meaningful failure; unsupported rows have actual rejection coverage where required, not skips.

### Phase 2 — Test primitives and public consumers

Self-test builders/oracles first, then migrate a small representative cross-surface scenario vertically from seed to native assertion and evidence. Retain old suites. Add real public-contract execution to independently built consumer targets. Keep internal seams isolated, task-local/per-call where possible; no globally mutable observers.

Exit: builder/oracle boundary vectors pass; independent consumers do actual file I/O through declared products; a wrong native owner/value cannot pass through shared expected-data generation.

### Phase 3 — Systematic contract suites and bounded behavior repairs

Implement mandatory partitions and sequence cases incrementally. For every missing path, write the correct failing regression first, then make the smallest production repair if a real package defect is reproduced. This task authorizes those necessary repairs, not unrelated API cleanup or a mapping rewrite. Maintain a traceable defect record; do not change behavior merely because a generic matrix expected all APIs to be equivalent.

Exit: every critical contract row has a named runtime test and independent result; each actual defect is repaired or explicitly blocks completion. Normalization is checked semantically where specified; unsupported layouts reject safely.

### Phase 4 — Calibration and gate hardening

Implement and execute the compile-and-activate calibration set and oracle vectors. Upgrade the canonical runner to compare manifests and scenario sets, while retaining all existing framework/status/skip checks. Adversarial policy tests must cover stale/mixed runs, incomplete shards, missing discovery/case events, duplicate IDs, removed execution, reduced minima, hidden failures, wrong runner status and altered output format. If sharding is not implemented, reject shard/filter arguments rather than pretending to aggregate them.

Exit: both real complete evidence and intentionally corrupted evidence exercise the gate; only the complete valid run is accepted. Every mandatory mutant is killed for its intended reason. Do not accept a parser merely because mocked strings pass; include real runner logs.

### Phase 5 — Full package acceptance and handoff

Run focused regressions, Python policy tests, both canonical complete Debug/Release gates, real standalone consumers, targeted ASan/TSan and the existing five minimum-platform compile/link jobs where available. Use the stable installed toolchain. No application validation. Keep the two exact existing optional skip identities; the privilege precondition is mandatory. If the host strips privilege bits, use an authorized capable environment or report formal acceptance blocked. Do not add skip logic or mask failure.

Use shell commands only when available; ACP/Xcode tools may discover/build/test, but cannot by themselves establish canonical script acceptance if the script/evidence lane was not executed. Preserve native result bundles and report missing operations. Do not invent tool names. Git branch creation is required before implementation; if unavailable, do not edit main.

Useful baseline commands (retain canonical semantics while extending the runner):

```sh
python3 -m unittest discover -s scripts/tests
python3 scripts/check-docs.py
TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh debug
TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh release
```

Run the newly strengthened package-owned public consumers using their actual declared product names. Update current testing documentation and add an English final record. Historical records remain immutable. Commit coherent phases after relevant checks, including red-to-green repair evidence; never commit generated build products, temporary fixtures or mutants.

## 8. Completion criteria

- Package-only repository boundary respected; no sibling access or acceptance dependency.
- All public APIs/overloads/modes and advertised fields have explicit, validated coverage decisions; all mandatory partitions execute or completion is blocked with a precise reason.
- Existing evidence is retained or has a reviewed stronger replacement map. No skipped regressions, relaxed validators, fallback writers or new capabilities merely to make tests pass.
- Every mandatory calibration mutant compiles/activates and is caught behaviorally; missing execution/assertions and oracle defects cannot be disguised by counts.
- Complete Debug/Release gates accept the frozen final source, required scenario sets, framework results and only existing optional skips. Consumers, sanitizers and platform results are recorded separately; unexecuted work is not inferred green.
- No dependency URL/checksum, version, platform/product, signing or publication changes. Independent date intents, private provenance, advisory states, concrete v2.3 restrictions, unsupported role/rate/Matroska policy and transaction guarantees remain intact.
- Final report identifies branch/commits, tested source, scenario coverage versus limitations, defect repairs, calibration results, commands/results and evidence paths. Do not claim exhaustive correctness or release readiness if mandatory calibration/gates remain blocked.

Use [the startup prompt](PACKAGE_TEST_SYSTEM_AGENT_PROMPT_2026-11-15.md) to begin execution.
