# Agent prompt: implement the metadata mapping refactor

Copy the instructions below into the agent session opened on this repository. This is an implementation assignment, not a request for another design proposal. The agent may use Xcode Code Intelligence's available ACP tools for source navigation, builds, test discovery, test execution and diagnostics. Tool names vary: discover the actual tools instead of inventing names or assuming a terminal exists.

## Assignment

Implement the package-side `AM-TLAM-MAPPING-2.2` contract in `docs/METADATA_MAPPING_SPEC.md`. Read that entire file before editing. It is the normative target and includes the complete matrix, independent date rules, legacy total recovery, private formatting retirement, four-state advisory, 26 MP4-exclusive entries and two MKV-exclusive target registrations. This prompt supplies execution order and acceptance gates; it does not replace that specification.

You have access to **this repository only**. Do not open, read, edit, compile or test any sibling repository, application project, resolved dependency source, external engine checkout or user music library. References to a companion application or mirrored specification in the contract are context, not permission to access them. Implement package APIs and report the public migration instructions for the application maintainer. Leave cross-repository synchronization to the maintainer.

Complete the authorized implementation and tests without stopping after a plan or a compile-only result. Work in the current suitable feature branch; never modify main or rewrite history. Do not publish a release, assign a release number, push, create/merge a PR, or rebuild the external binary artifact. If Git commit tools are available, make coherent local implementation commits after their relevant checks pass; otherwise leave an explicitly listed reviewable diff. Never claim an unavailable action succeeded.

## Mandatory requirements

1. Year, Date, Release Date, Original Release Date and Purchase Date are independent. `YEAR=2004` and `RELEASEDATE=2017-06-09` are valid simultaneously. No year extraction, year/date synthesis, fallback filling, shared dirty intent, year-equality validation or cross-field clearing is allowed.
2. Store totals in native pairs or the format's declared ordinary total keys. Preserve an untouched sibling component, including a recoverable legacy total. Never create a private field to pretend a total is supported.
3. Retain and recover old standalone total aliases. `TRCK=3` plus `TXXX:TRACKTOTAL=12` must not become just `TRCK=3` after cleanup. Write the resolved pair before retiring the explicitly selected aliases within the same staged transaction.
4. Both `AUDIOMATOR_*_TEXT` and `TAGLIBAUDIOMETADATA_*_TEXT` MP4 namespaces are legacy formatting provenance. Stop creating or renaming them on every default write surface, including formatted-number convenience APIs. Keep unrelated edits preservation-safe. Cleanup/recovery is explicit, scoped and version-guarded.
5. ITUNESADVISORY has four distinct states: absent/unset; present 0=not Explicit; present 1=Explicit; present 2=Clean. Zero is not absence. Unknown existing values are preserved with provenance, not silently recoded.
6. Mapping targets, native shapes and capability claims must agree. An entry or a passing self-read does not establish native persistence. Every activated changed mapping requires native verification and tests.
7. Keep transaction staging, expected-version validation, audio-content guards, process-local reservations and durability reporting. Never retry a failed commit, clear a version token, substitute another file, disable verification, or fall back to a raw/Basic writer after a semantic validation failure.
8. Do not alter external binary URLs/checksums, vendor source, suppress concurrency warnings, skip failing tests, weaken unrelated assertions or add unsolicited network activity. This package remains multi-platform: retain the package's macOS/iOS support, products, deployment minimums and public Objective-C boundary. Do not apply the companion app's macOS-only rule to this package.
9. Use neutral package terminology. Do not introduce external editor branding into source names, public APIs, comments, documentation or commit messages. Existing historical records remain immutable.

## Read and inspect first

Read `docs/METADATA_MAPPING_SPEC.md`, `docs/ARCHITECTURE.md`, `docs/FIELD_SCHEMA.md`, `docs/PRESERVATION.md`, `docs/TRANSACTIONS.md`, `docs/AUDIO_CONTENT_CONTINUITY.md`, `docs/API_REFERENCE.md`, `docs/TESTING.md`, `docs/DEVELOPMENT.md` and `Package.swift`. Current-state documents may describe old behavior; the explicit 2.2 target is the authorized change. Do not rewrite historical evidence to match new behavior.

Inspect these implementation paths before changing them:

| Area | Starting locations |
| --- | --- |
| Registry and capabilities | Sources/TagLibAudioMetadata/MetadataFieldSchema.swift; Sources/CTagLibBridge/TLFormatRegistry.mm; Sources/CTagLibBridge/Internal/TLFormatRegistry.hpp |
| Models and snapshot | Sources/TagLibAudioMetadata/TagLibMetadataModels.swift; MetadataSnapshotPatch.swift |
| Read and legacy conveniences | TagLibMetadataManager+Read.swift; TagLibMetadataManager+Write.swift; TagLibMetadataManager+Compatibility.swift |
| Typed/raw writes | MetadataSnapshotPatch.swift; RawMetadataPatch.swift; TagLibMetadataManager+Structured.swift |
| Verification/internal inventory | TagLibMetadataManager+Verification.swift; TagLibMetadataManager.swift |
| Native schema and extraction | Sources/CTagLibBridge/Internal/TLMetadataCore.inc; TLContainerExtractors.inc |
| Native mutation | TLPropertyMapCodec.inc; TLPropertyMapDelta.inc; TLPropertyMapWrites.inc; TLRawBridgeOperations.inc; TLBasicBridgeOperations.inc; TLWriteBridgeOperations.inc; TLStructuredMutation.inc |
| Existing tests and native oracles | Tests/TagLibAudioMetadataTests/Capabilities; ModelSemantics; Integration; Transactions; Concurrency |

The abbreviated Swift filenames in this table are under `Sources/TagLibAudioMetadata/`; abbreviated bridge filenames are under `Sources/CTagLibBridge/Internal/`. Use source search to find all callers, not only these starting files. In particular search for numeric parsing, `prefix(4)`, year/release comparisons, hidden internal keys, private namespace constants, native slot aliases and every number-text entry point.

## Phase 0: establish the baseline

- Record branch, HEAD, working-tree changes, selected Xcode toolchain, package scheme/test target and available tools. Preserve pre-existing work; do not reset or clean it away.
- Discover the package's build and test actions in Xcode. It has one test target, `TagLibAudioMetadataTests`, using both XCTest and Swift Testing. Confirm the runner actually discovers both frameworks.
- Run a baseline package build and test suite when the tools permit. Record test identifiers and failures. Do not assume a historical application test failure is a current package failure, and do not claim a known historical failure is fixed without reproduction.
- Create a short tracked implementation record under `docs/records/` following that directory's conventions and index rules. Record baseline, intended phases, acceptance ledger and subsequent command/tool results. Do not add generated build output or real media metadata.
- Build a coverage ledger: all 79 current enum cases, five core additions/migration entries, 26 exclusive MP4 names (some overlap), and both MKV target identities. For each, list native targets, type/cardinality, capability state, implementation path and test IDs. Do not sum overlapping lists as unique field counts.

**Gate 0:** You can name the real baseline, tool limitations, existing failures and each affected write/read surface. If the package cannot be tested because of tool access, report that limitation, continue source work that is independently safe, and leave the final validation gate explicitly incomplete.

## Phase 1: registry and public model

Implement one explicit semantic/native registry for the target profile. Extend the existing registry rather than adding a second unrelated table that can drift. Swift and bridge representations may remain separate where language boundaries require it, but consistency tests must compare them. Do not attempt to generate production mapping code by parsing Markdown at runtime.

Registry entries need semantic identity, input/display aliases, native read identities, exactly one preferred write location per family/version, value shape/bounds, provenance, shared-storage group, capabilities and mapping-contract version. Native case, freeform namespace/description, role, language and Matroska target are identity components. Do not uppercase a native atom name to implement canonical-key lookup.

Keep engine PropertyMap names separate from semantic names. Examples: the engine may label TIT1 as WORK and ©grp as GROUPING, but the target semantic owner of both slots is CONTENTGROUP. WORK and GROUPING have their own target locations. LABEL's chosen MP4 slot is ©pub, not a duplicate write to F(LABEL). Conductor uses ©con. Follow every explicit matrix decision, not a generic engine-key fallback.

Use an explicit compatibility boundary for the old public `.date` enum case. A recommended additive layout is a new `.year` semantic identity and a new `.standaloneDate` identity, while retaining `.date` as a deprecated legacy YEAR-slot spelling. Both `.year` and legacy `.date` cannot be supplied in one patch; reject that collision. Do not silently repurpose old `.date` callers as standalone DATE edits. Ensure canonical registry enumeration has one preferred semantic owner even if legacy API aliases exist. Document new enum cases and source-compatibility implications for exhaustive client switches.

Preserve existing public function signatures/selectors where possible; use explicit additions and deprecations for changed semantics. Extend Basic/snapshot models with independent stored fields and field provenance as needed. Keep existing model construction source-compatible using defaults or overloads; inspect actual initializers before editing. A convenience string must not become the authoritative full-fidelity representation for aliases, multi-values or unknown native enums. Expose a mapping contract version independently of the package release version.

**Gate 1:** Focused model/capability tests pass; all planned entries have an explicit mapping or a precise unsupported status; no two independent writable fields own the same native slot. Duplicate API aliases are detected rather than written twice.

## Phase 2: independent reads

- Read Year's complete stored value from its declared native slot. Remove four-character truncation from authoritative reads. Preserve full text already present in a Year slot.
- Read standalone Date, Release Date and Original Release Date independently. Never populate missing Year from ©day projected as a different semantic field, from Release Date, from Original Date or from a purchase timestamp. Under this profile ©day itself belongs to YEAR; standalone DATE is a different registered location.
- Keep TYER, TDAT and TIME independent on ID3v2.3. Do not synthesize one timestamp. On v2.4 TDRC belongs to YEAR and TXXX(DATE) is standalone DATE.
- Preserve contradictory aliases and exact value arrays with provenance. Do not hide ambiguity by preferring a longer string or a newer-looking date.
- Inventory legacy total aliases and all four private-number-text identities through structured/native reads. Distinguish native-present, absent, recovered legacy component and unresolved recovery. Do not collapse malformed input or parse failures to zero.
- Represent unknown advisory codes without adding an editable fifth state to the four-state semantic enum. Use a separate raw/provenance result or equivalent full-fidelity snapshot status; preserve known public convenience values without treating them as an instruction to rewrite the unknown source.

**Gate 2:** Temporary-fixture tests show YEAR=2004 and RELEASEDATE=2017-06-09 separately, missing fields stay missing, full Year text survives, standalone dates remain separate, and recovered total values remain visible with source provenance. Include independent raw/native read assertions.

## Phase 3: semantic patch planning and native writes

Build a validated native delta from only requested fields. Validate exact target, tag version, type, bounds, cardinality and alias resolution before staging. Unsupported matrix cells remain unsupported; do not create private replacements. Preserve raw/native distinctions outside the selected delta.

Remove all automatic Year/Release Date reconciliation from Basic updates, replacements and compatibility wrappers. Do not replace that logic with synchronization under a new name. Baseline-aware no-op Basic updates must preserve unknown values and full text. Explicit field edits change only their selected native storage. If a convenience replacement cannot express an ambiguous baseline losslessly, reject the ambiguous edit with a precise error instead of guessing.

For each changed mapping update the Swift planner, bridge writer, reader, capability and verification together. Avoid a period where a field is writable through one entry point but read from a different slot. Version-invalid ID3 frames use only declared extension codecs or explicit conversion; ordinary edits retain the source tag version.

In tests, independent date values with different years are positive cases. Removing Year removes neither Date nor Release Date. Importing differing years is not a conflict. Add native-slot collision rejection and original-byte preservation tests.

**Gate 3:** Set/replace/remove/no-op tests pass on MP3, M4A, FLAC, Ogg, AAC and WAV temporary copies for the corresponding advertised paths, including independent dates and unrelated raw-value preservation. Use the existing package fixtures, not another repository's fixtures. Keep the same version/audio guards at final commit.

## Phase 4: numbering and legacy recovery

Implement and test these operations separately: set number, set total, remove number, remove total, replace pair, remove pair and formatted-text write. An omitted component preserves its baseline, including a resolved legacy-only total. MP4 uses native trkn/disk and the zero sentinel for component absence, never displayed ordinal zero; enforce 16-bit native component bounds. Ordinary typed positive values and raw absence remain distinct.

Implement section 6.1 exactly. Native positive components are authoritative when present; agreeing aliases are redundant; a sole valid orphan total is recoverable with provenance; contradictions/malformed/multi-value candidates need explicit resolution. A total key in Vorbis/APE is ordinary metadata and must not be retired as if it were an app-private field.

Provide a package-owned inventory/normalization plan with immutable before-values, exact native identities, exact value arrays/types, resolved after-pair, selected removals and expected version. Headless callers must explicitly choose the resolution policy. Reject stale plans. Apply native write and selected removals in one transaction, then verify both persistence and removal before publication. Do not use a whole-map or whole-atom-collection replacement for cleanup.

Implement section 6.2 retirement on every number-write surface. Do not rename AUDIOMATOR provenance into TAGLIBAUDIOMETADATA provenance. Standard-only files remain standard-only. Unrelated edits preserve both namespaces exactly. A track edit leaves the entire disc group untouched. Matching private formatting can be retired only when the caller explicitly accepted the plan's normalization; conflicting or malformed data requires explicit replacement/recovery intent. Format normalization can be a warning; exact-text mode must reject an unrepresentable MP4 padding request rather than secretly save it in private atoms.

Keep the public raw-delta reserved-key protection. Add the narrow internal operation necessary for explicit cleanup instead of allowing arbitrary internal-key mutation through customFields. Expose inventory for inspection even if the ordinary raw PropertyMap continues to filter it.

**Gate 4:** Tests cover native-only, each private namespace alone, both agreeing, both disagreeing, orphan totals, contradictory native totals, total-only pairs, individual clearing, whole-pair clearing, padding, malformed/multi-value/overflow text, namespace/case lookalikes and unchanged opposite pairs. Prove TRCK=3 plus TXXX:TRACKTOTAL=12 migrates to 3/12 before the old total is removed. Prove every rejected operation preserves original bytes. Native readback, not just Basic totals, must prove success.

## Phase 5: advisory and MP4-exclusive fields

Implement present-zero versus absence end-to-end: model, patch, native rtng codec, readback and verification. Explicit unspecified/remove deletes; notExplicit sets 0; explicit sets 1; clean sets 2. Never use a truthy check to detect field presence. Preserve unknown legacy codes on unrelated writes. An explicit replacement of unknown data is a separate request with selected alias resolution.

For all 26 MP4-exclusive entries in section 8.1, implement or reuse the exact native codec, including new public registry identities for missing fields. Reuse existing semantics for totals and other overlapping entries rather than creating duplicates. Verify integer widths/types, string identifiers, separate episode number/identifier, season zero, media-kind enum, gapless 1/remove and Boolean present false. Do not infer enum codes by list order. RATE must not inherit an unrelated rating scale. Use the existing versioned engine's verified codec and native parsers; if a requested codec cannot be established, leave that exact entry unsupported with a concrete reason and mark its completion gate incomplete rather than inventing a value/type.

MKV section 8.2 defines target registrations but expressly permits implementation to remain pending. Record TVEPISODE/PART_NUMBER/50 and TVSEASON/PART_NUMBER/60 separately. Do not advertise Matroska typed writes or add a new container backend/dependency merely to satisfy this assignment. Keep both explicitly gated until an actual native codec, target identity and fixture validation exist. This is the contract's deliberate scope boundary, not a missing silently ignored task.

**Gate 5:** Advisory transition absent→0→1→2→absent passes with exact native assertions; unknown values and Title-only changes preserve their state. All 26 MP4 rows have explicit implementation/test evidence or an honestly incomplete entry. Both MKV target registrations exist without false capability claims. No account/network discovery is introduced.

## Phase 6: preservation and regression sweep

Search every legacy, semantic, Basic, raw and structured path again. Check for hidden old mapping tables, private-atom creation, automatic date filling, raw-key collisions and verification that can accidentally succeed through a leftover alias. Test semantically identical edits through applicable public entry points. A full replacement is not equivalent to a delta; verify its documented preservation behavior separately.

Run relevant existing ID3, MP4, generic, ASF, APE, WAV, audio-payload, alias, source-compatibility, concurrency and transaction tests. The package already has Opus, AIFF, WMA, APE, WavPack, TTA and DSD fixtures: discover and use the repository's actual coverage instead of assuming the companion app's fixture gaps apply. Preserve existing module/native-header capabilities. Narrow an unsafe operation with a precise error rather than erasing data to pass a test.

Existing tests may assert behavior the contract intentionally replaces, such as private prefix migration or Year synchronization. Replace those assertions with stronger target assertions in the same change and explain the semantic replacement. Do not delete an entire test or mark it skipped/expected-failure. Retain all independent preservation and failure-atomicity checks. Do not turn pre-existing failures green by editing expected values without investigating the code.

**Gate 6:** No unexplained new failures; no weakened protection or ignored failures; audio payload and unrelated native content survive. Relevant transaction/race tests prove rejected operations leave source bytes unchanged and successful commits retain durability status.

## Phase 7: documentation and final verification

Update actual implemented behavior in `docs/API_REFERENCE.md`, `docs/FIELD_SCHEMA.md`, `docs/FORMATS.md`, `docs/USAGE.md`, `docs/PRESERVATION.md`, `docs/MIGRATION.md`, `docs/ARCHITECTURE.md`, `docs/TESTING.md`, README and the unreleased changelog as applicable. Regenerate FIELD_SCHEMA from the actual registry; never hand-edit its generated tables. Update public type/manager API indexes and any count checks when adding cases. Update the spec's implementation status by section; do not mark the entire target implemented while an activation gate is incomplete.

If Python/terminal execution is available, run:

```sh
python3 scripts/generate-field-schema.py --write
python3 scripts/generate-field-schema.py --check
python3 scripts/check-docs.py
git diff --check
```

Do not manufacture shell access by editing the project to execute scripts or by opening another application's terminal. If ACP lacks a required tool, list the exact unexecuted check and supply the changes needed for a maintainer to run it; do not claim the documentation gate passed. Keep the generator/checker updated legitimately for new API aliases and counts; do not remove its coverage rules.

Prefer Xcode's discovered package build and test tools. Record selected scheme, destination, test IDs/counts, result/log references and actual diagnostics. A test action returning before results are available is not completion; inspect the finished result. Build success alone is not test success. Never launch the companion application.

If a terminal is available and Xcode's tools cannot provide an equivalent result, use the repository's documented commands:

```sh
swift test --disable-keychain --disable-netrc
swift build --disable-keychain --disable-netrc -Xswiftc -warnings-as-errors -Xcc -Werror
swift test --disable-keychain --disable-netrc -c release
swift run --disable-keychain --disable-netrc --package-path IntegrationTests/Consumer TagLibAudioMetadataConsumer
swift run --disable-keychain --disable-netrc --package-path IntegrationTests/Consumer TagLibAudioMetadataLowLevelConsumer
```

Run the full default suite in Debug and Release after focused tests pass. Run both public consumers and the strict warning check when the tools support them. Use supported macOS and iOS/iOS Simulator build destinations to compile the public products; minimum-platform matrix commands are documented in `docs/TESTING.md`. Unavailable destinations are unverified, never silently counted as passed. Sanitizers and the full CI matrix remain separately reported if not run; this task does not require adding performance benchmarks or downloading a new corpus.

An environment that strips setuid/setgid bits can fail the privilege-test precondition. Keep that test intact, identify the exact precondition and report the environment limitation. Cache/manifest access errors are environment issues: use only approved tool permissions, do not diagnose them as source failures or suppress them. Do not rebuild the external engine to get around a binary limitation; provide a minimal reproduction and gate the affected operation instead.

## Final acceptance checklist

Completion requires evidence, not a statement of intent:

- All changed production paths compile without added warnings; public facade and low-level consumers build/run where tools permit.
- Registry coverage accounts for every original case, all additions, old API aliases, all 26 exclusive MP4 rows and both gated MKV identities. Correct native slots and per-version extension status are tested.
- Independent Year/date read/set/remove tests pass, including 2004 versus 2017 and missing-field preservation; no automatic reconciliation survives.
- Number components and orphan totals survive until a successful explicit migration; native pairs round-trip; private atoms are not created/renamed; touched/untouched group boundaries and exact retirement are verified.
- Advisory's four states, present zero, unknown source values and explicit replacement have native tests.
- Raw arrays, alias conflicts, role/language identity, artwork and unrelated unknown metadata retain the promised fidelity; unsupported shapes reject before mutation.
- Version/audio guards, failure-byte preservation, concurrency and durability regressions pass.
- Focused tests, full Debug/Release tests, strict compile, consumer checks and documentation checks have actual results. Any unavailable check or unresolved relevant failure makes the corresponding completion gate incomplete.
- Current docs describe only implemented behavior; migration notes explain changed native mappings, independent date semantics, old enum compatibility and private-text retirement. The tracked record includes exact executed evidence and an honest capability matrix.

Report the final result as: changed APIs/files and why; each phase's gate result; test/build commands or Xcode actions and their outcomes; known baseline versus new failures; unsupported/unverified entries; package-only migration instructions for the application maintainer; branch/commits or uncommitted diff. Do not claim the application was updated, mirrored files were synchronized, a release was published, or every container is supported.

If blocked, stop only the dependent work and continue independent phases. Record a concrete blocker with field/native identity, minimal temporary-fixture reproduction, expected versus observed behavior, exact failing diagnostic and next required maintainer action. Do not resolve a hard problem by lowering the acceptance criteria, inventing a fallback mapping, or handing back only a plan.
