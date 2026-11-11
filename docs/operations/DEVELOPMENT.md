# Development and maintenance

This document is for contributors and automated agents working on the package itself. It covers repository layout, source-of-truth rules, change workflow, the documentation system, release, and binary maintenance. Application usage belongs in the [guides](../guide/).

## Repository layout

| Path | Purpose |
| --- | --- |
| `Package.swift` | Swift tools 6.4 manifest; products, targets, binary dependency, platform minimums. |
| `Sources/TagLibAudioMetadata/` | Swift facade: models, schema, native mapping catalog, planning, reads, writes, structured conversion, patches, verification, numbering. |
| `Sources/CTagLibBridge/` | Public Objective-C bridge, Objective-C++ implementation, private headers, format registry, and transaction coordinator. |
| `Sources/CTagLibBridgeInternalAPI/` | Package-internal in-place mutation declarations used by the facade. Not a library product. |
| `Sources/CTagLibBridge/include/` | Public bridge header. Foundation-only; no C++ types. |
| `Tests/TagLibAudioMetadataTests/` | Single test target, physically organized by layer. |
| `IntegrationTests/Consumer/` | Facade-only and low-level consumer packages. |
| `scripts/` | Binary build, preservation-corpus generation, documentation generators/checks, the full-suite test gate, evidence summarizer, and gate-policy tests. |
| `ThirdParty/TagLib/` | TagLib and utf8cpp license texts. |
| `docs/guide/` | Task-based guides: getting started, reading, writing, capabilities. |
| `docs/reference/` | API, models, fields, formats, bridge, mapping contract, generated matrix. |
| `docs/explanation/` | Architecture, preservation, transactions, audio identity. |
| `docs/operations/` | Installation, testing, mapping test acceptance, status, development, migration, third-party notices. |
| `docs/records/` | Immutable historical evidence. |
| `.github/workflows/` | CI and binary-release workflows. |
| `.local/` | Local-only working material, ignored by Git; not part of a clean clone. |

## Source-of-truth rules

- Current source code, `Package.swift`, and the test target are authoritative for behavior and dependency identity.
- Native mapping targets come from `MetadataMappingCatalog.swift`; field semantics come from `MetadataFieldSchema.swift`. Never generate production mapping code by parsing Markdown.
- The bridge contains a parallel mapping table for its own projections. Cross-language parity tests are the boundary guard; do not describe the bridge table as the public semantic source when the two disagree.
- `CHANGELOG.md` is release history. Assign a version number only in a commit approved for tagging; otherwise keep changes under an unreleased section.
- Current documents under `docs/` describe the current revision. If a current document and the code disagree, the code wins and the document must be fixed.
- Files under `docs/records/` describe past investigations at named revisions. They are immutable evidence, not current contracts.
- Historical records must not be rewritten to match current behavior. Add an addendum or a superseding record.
- Generated reference pages are derived views of source. The generator owns the marked section; the surrounding prose owns only explanation and navigation.

## Change workflow

1. Inspect the current branch, HEAD, and working tree before editing.
2. Create a focused branch from the current development state. Do not rewrite existing history.
3. Make logically coherent commits as work progresses. Do not accumulate an entire assignment into one commit.
4. Keep production changes and documentation changes reviewable. Do not modify tests merely to make a documentation claim true.
5. Run the relevant checks from [Testing](TESTING.md). Use `bash scripts/validate-tests.sh debug` (or `release`) for full-suite acceptance; a bare `swift test` count is not gate evidence.
6. Update the canonical document for any behavior change. If the change is an investigation or campaign, add a record.
7. Run the documentation generators and `python3 scripts/check-docs.py`.
8. Review the diff and internal links before committing.

Existing commit messages are imperative and capitalized. Do not amend, squash, rebase, reset, force-push, or merge into `main` as part of a normal documentation or maintenance branch.

## Documentation system

The current documentation has one canonical owner per topic. The owner map is in the [documentation hub](../README.md#document-map); the table is not duplicated here.

```text
README.md                                  project entry point and quick start
CHANGELOG.md                               release history
docs/
  README.md                                hub, reading paths, ownership, checks
  guide/
    GETTING_STARTED.md                     install, first read, first patch
    READING.md                             snapshots, Basic/raw/structured reads
    WRITING.md                             patches, Basic/raw/structured writes, erase
    CAPABILITIES.md                        capability and field-support queries
  reference/
    API.md                                 generated manager API
    MODELS.md                              generated value/error model reference
    FIELDS.md                              field registry and typed-patch policy
    FORMATS.md                             generated format matrix and limits
    BRIDGE.md                              public Objective-C surface
    MAPPING_SPEC.md                        native mapping contract
    MAPPING_MATRIX.md                      generated native target matrix
  explanation/
    ARCHITECTURE.md                        modules, flows, source/test map
    PRESERVATION.md                        write semantics and verification
    TRANSACTIONS.md                        staging, durability, concurrency
    AUDIO_CONTENT_CONTINUITY.md            opt-in audio identity
  operations/
    INSTALLATION.md                        binary distribution and embedding
    TESTING.md                             test layers, commands, CI, evidence limits
    STATUS.md                              latest observed validation state
    DEVELOPMENT.md                         this document
    MIGRATION.md                           deprecations and release changes
    THIRD_PARTY_NOTICES.md                 licensing and provenance
  records/                                 immutable historical evidence
```

### Generated vs hand-written content

Reference pages are generated from source; `FIELDS.md` and `FORMATS.md` contain marked sections inside hand-written prose, while `API.md`, `MODELS.md`, and `MAPPING_MATRIX.md` are generated in full:

| Document | Generator | Source of truth |
| --- | --- | --- |
| `reference/API.md` | `generate-api-reference.py` | public Swift declarations |
| `reference/MODELS.md` | `generate-api-reference.py` | public Swift declarations |
| `reference/FIELDS.md` | `generate-field-schema.py` | field schema plus mapping catalog |
| `reference/FORMATS.md` | `generate-format-matrix.py` | format registry, container masks, allowlists |
| `reference/MAPPING_MATRIX.md` | `generate-mapping-matrix.py` | `MetadataMappingCatalog.swift` |

Do not hand-edit generated content. Change the source, run the generator with `--write`, and include the regenerated page in the same commit. `check-docs.py` runs every generator's `--check` mode.

### Documentation style

- Use soft-wrapped Markdown paragraphs. Do not hard-wrap prose to a fixed column.
- Use leading and trailing pipes on every Markdown table row.
- Use relative links between repository documents. Verify them after moving files.
- Label historical claims, author-reported results, unverified behavior, and environment-dependent results explicitly.
- Do not claim that compilation proves runtime behavior.
- Do not present `fixtureCovered` as universal format support.
- Prefer "the package does X on the tested layouts" over "X is supported everywhere".
- Do not duplicate a detailed contract across current documents. Link to the canonical owner.
- Update [Status](STATUS.md) only for a changed latest observed state, not for every run.
- Update [Migration](MIGRATION.md) when a public API is deprecated or its behavior changes.
- Regenerate the field, API, format, and mapping references after changing their sources.

### Test gate maintenance

The full-suite entry point is `scripts/validate-tests.sh`; it accepts only `debug` or `release` and rejects filters, extra arguments and skips. It writes logs and a `summary.json` under `.build/test-evidence/`, then runs `scripts/summarize-test-run.py`. The summarizer fails closed on missing XCTest/Swift Testing summaries, unexpected skips, failed named tests, missing required suites, and parameterized case counts below the frozen minima. `scripts/tests/` exercises those policy rules without running the package suite.

Do not weaken a gate minimum, allow a new skip, or make a matrix expectation match a broken implementation to obtain a green result. The matrix inventory and case minima are owned by [Mapping test acceptance](MAPPING_TEST_STRATEGY.md); test commands and evidence limits are owned by [Testing](TESTING.md).

### Documentation checks

`scripts/check-docs.py` validates:

- relative Markdown links, including heading fragments;
- leading/trailing pipes on table rows;
- exactly one H1 per document;
- presence of every current document in the hub;
- no links to retired current-document paths;
- freshness of the generated API, model, field, format, and mapping sections;
- coverage of every registered format extension in `FORMATS.md`;
- coverage of every public bridge selector and constant in `BRIDGE.md`;
- the prohibition on hand-editing generated markers;
- coverage of every current document, including [Mapping test acceptance](MAPPING_TEST_STRATEGY.md), in the documentation hub.

Run it before committing:

```sh
python3 scripts/check-docs.py
```

The generators are also runnable directly:

```sh
python3 scripts/generate-api-reference.py --write
python3 scripts/generate-field-schema.py --write
python3 scripts/generate-format-matrix.py --write
python3 scripts/generate-mapping-matrix.py --write
```

### Adding a record

Use [records/CONVENTIONS.md](../records/CONVENTIONS.md) and [records/TEMPLATE.md](../records/TEMPLATE.md). A record needs a metadata block, a revision, a method, findings with stable IDs, evidence, limitations, and an index row. Add actionable items to the open register.

## Release process

1. Ensure the changelog's current release section describes the release and current docs match the code. The latest published tag is `0.7.1`; do not describe post-0.7.1 work as part of that tag.
2. Confirm the pinned binary identity in `Package.swift` and `scripts/taglib-binary-version.env`.
3. Run the test, sanitizer, release, strict-platform, consumer, and documentation checks that apply.
4. Create a tag from the reviewed commit. The tag is the release boundary; do not rewrite it.
5. The `remote-tag-consumer` CI job verifies a clean consumer can resolve the published tag.
6. Do not replace an existing binary release asset. Publish a new immutable release revision and update the manifest checksum.

The release version is assigned in the changelog only in the release commit. The README's dependency example selects a tagged range; evaluating `main` or a branch is an explicit choice.

## Binary dependency maintenance

The package consumes a checksum-pinned dynamic XCFramework. `scripts/taglib-binary-version.env` is the single source of binary identity.

```sh
scripts/build-taglib-xcframework.sh --replace
# or reuse a verified checkout
scripts/build-taglib-xcframework.sh --source-dir /path/to/taglib-v2.3.1 --replace
```

The script fixes source revisions, build options, deployment targets, and architectures, and rejects source-tree modifications. Rebuilds are reproducible by source and configuration, not promised byte-for-byte because toolchain metadata and ZIP timestamps vary. After publishing a new release, calculate the SwiftPM checksum and update `Package.swift`. Do not bypass checksum verification.

The dynamic framework is namespaced (`TagLibAudioMetadataTagLib`), but it still exports TagLib C++ symbols. Do not load another incompatible TagLib implementation into the same process. See [Installation](INSTALLATION.md) and [Third-party notices](THIRD_PARTY_NOTICES.md).

## Documentation and records maintenance

- Update `CHANGELOG.md` for user-visible additions, changes, fixes, and deprecations. Keep release boundaries accurate.
- Update [Status](STATUS.md) after a validation campaign that changes the latest known state. Do not turn it into a chronological log.
- When a record is superseded, update the index's status and `Superseded by` fields, not the record body.
- When a finding is repaired, record the commit, the regression test, and the remaining limitation. "Fixed" without evidence is not enough.
- When evidence is missing, write `unknown` or `requires verification`; do not invent certainty.
- Run the documentation check after moving or renaming a document.

## What not to do

- Do not change production behavior merely to make a historical document true.
- Do not weaken a test assertion to obtain a passing count.
- Do not delete historical engineering evidence because it is outdated.
- Do not present a clean-room or independent report's verdict as the current merge decision without checking later records and status.
- Do not add a second copy of a contract that already has a canonical document.
- Do not describe a configured CI job as a passing result for a revision that did not run it.
- Do not hand-edit a generated section; run the generator.
- Do not generate production mapping code from Markdown.
