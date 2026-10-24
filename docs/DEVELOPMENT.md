# Development and maintenance

This document is for contributors and automated agents working on the package itself. It covers repository layout, change workflow, documentation maintenance, release, and binary dependency maintenance. Application usage belongs in [Usage](USAGE.md).

## Repository layout

| Path | Purpose |
| --- | --- |
| `Package.swift` | Swift tools 6.0 manifest; products, targets, binary dependency, platform minimums. |
| `Sources/TagLibAudioMetadata/` | Swift facade: models, schema, reads, writes, structured conversion, patches, verification. |
| `Sources/CTagLibBridge/` | Public Objective-C bridge, Objective-C++ implementation, private headers, format registry, and transaction coordinator. |
| `Sources/CTagLibBridgeInternalAPI/` | Package-internal in-place mutation declarations used by the facade. Not a library product. |
| `Sources/CTagLibBridge/include/` | Public bridge header. Foundation-only; no C++ types. |
| `Tests/TagLibAudioMetadataTests/` | Single test target, physically organized by layer. |
| `IntegrationTests/Consumer/` | Facade-only and low-level consumer packages. |
| `scripts/` | Binary build, preservation-corpus generation, documentation checks, field-table generation. |
| `ThirdParty/TagLib/` | TagLib and utf8cpp license texts. |
| `docs/` | Current documentation; historical records under `docs/records/`. |
| `.github/workflows/` | CI and binary-release workflows. |
| `.local/` | Local-only working material, ignored by Git (including the local audit input); not part of a clean clone. |

## Source-of-truth rules

- Current source code, `Package.swift`, and the test target are authoritative for behavior and dependency identity. CI configuration is authoritative only for which checks are configured, not for whether they passed.
- `CHANGELOG.md` is release history. It can describe unreleased work; do not assign an untagged version number.
- Current documents under `docs/` describe the current revision. If a current document and the code disagree, the code wins and the document should be fixed.
- Files under `docs/records/` describe past investigations at named revisions. They are immutable evidence, not current contracts.
- Historical records must not be rewritten to match current behavior. Add an addendum or a superseding record.
- The documentation check is a structural aid, not a proof of technical accuracy. Review prose against the source.

## Change workflow

1. Inspect the current branch, HEAD, and working tree before editing.
2. Create a focused branch from the current development state. Do not rewrite existing history.
3. Make logically coherent commits as work progresses. Do not accumulate an entire assignment into one commit.
4. Keep production changes and documentation changes reviewable. Do not modify tests merely to make a documentation claim true.
5. Run the relevant checks from [Testing](TESTING.md).
6. Update the canonical document for any behavior change. If the change is an investigation or campaign, add a record.
7. Run `python3 scripts/check-docs.py`.
8. Review the diff and internal links before committing.

Existing commit messages are imperative and capitalized, for example `Preserve WAVE audio identity across bext and iXML relocation` and `Record complete clean-room remediation evidence and merge assessment`. Follow that style.

Do not amend, squash, rebase, reset, force-push, or merge into `main` as part of a normal documentation or maintenance branch. If a branch becomes stale, create a new branch rather than rewriting shared history.

## Documentation system

The current documentation has one canonical owner per topic. The owner map is maintained in the [documentation hub](README.md#current-documents); the table is not duplicated here.

```text
README.md                                  project entry point and quick start
CHANGELOG.md                               release history
docs/
  README.md                                hub, reading paths, ownership, evidence vocabulary
  INSTALLATION.md                          binary distribution and embedding
  USAGE.md                                 task-based API guide and recipes
  API_REFERENCE.md                         complete public Swift surface
  FIELD_SCHEMA.md                          field registry and container mappings
  BRIDGE.md                                public Objective-C surface
  FORMATS.md                               capability matrix and container limits
  PRESERVATION.md                          write semantics and verification
  TRANSACTIONS.md                          staging, durability, concurrency
  AUDIO_CONTENT_CONTINUITY.md              opt-in audio identity
  ARCHITECTURE.md                          modules, flows, source/test map
  TESTING.md                               test layers, commands, CI, evidence limits
  STATUS.md                                latest observed validation state
  MIGRATION.md                             deprecations and behavior changes
  DEVELOPMENT.md                           this document
  THIRD_PARTY_NOTICES.md                   licensing and provenance
  records/                                 immutable historical evidence
```

### Documentation style

- Use soft-wrapped Markdown paragraphs. Do not hard-wrap prose to a fixed column.
- Use leading and trailing pipes on every Markdown table row.
- Use relative links between repository documents. Verify them after moving files.
- Label historical claims, author-reported results, unverified behavior, and environment-dependent results explicitly.
- Do not claim that compilation proves runtime behavior.
- Do not present `fixtureCovered` as universal format support.
- Prefer “the package does X on the tested layouts” over “X is supported everywhere”.
- Do not duplicate a detailed contract across current documents. Link to the canonical owner.
- Update [Status](STATUS.md) only for a changed latest observed state, not for every run.
- Update [Migration](MIGRATION.md) when a public API is deprecated or its behavior changes.
- Update [API reference](API_REFERENCE.md) when a public declaration is added, removed, or given a new default.
- Regenerate [Field schema](FIELD_SCHEMA.md) after changing `MetadataFieldSchema.swift`.

### Documentation checks and generation

`scripts/check-docs.py` validates:

- relative Markdown links, including heading fragments;
- leading/trailing pipes on table rows;
- exactly one H1 per document;
- presence of every current document in the hub;
- no links to retired current-document paths;
- every `MetadataFieldKey` appears in the generated field tables and the tables are current;
- every registered format extension appears in `FORMATS.md`, and the stated family/extension count matches the registry;
- every public manager function name and public Swift type is indexed in `API_REFERENCE.md`.

Run it before committing:

```sh
python3 scripts/check-docs.py
```

The field tables are generated from the Swift registry:

```sh
python3 scripts/generate-field-schema.py --write
python3 scripts/generate-field-schema.py --check
```

`check-docs.py` runs the `--check` form, so a source change that adds or removes a field fails until the document is regenerated. The generator is a documentation helper; it does not modify Swift or bridge code.

CI runs the same documentation check in the `build-and-test` job. The script deliberately does not attempt to verify prose or Swift signatures; those require review and the compiler.

### Adding a record

Use [records/CONVENTIONS.md](records/CONVENTIONS.md) and [records/TEMPLATE.md](records/TEMPLATE.md). A record needs a metadata block, a revision, a method, findings with stable IDs, evidence, limitations, and an index row. Add actionable items to the open register.

## Release process

1. Ensure the changelog's `[Unreleased]` section describes the release and current docs match the code.
2. Confirm the pinned binary identity in `Package.swift` and `scripts/taglib-binary-version.env`.
3. Run the test, sanitizer, release, strict-platform, consumer, and documentation checks that apply.
4. Create a tag from the reviewed commit. The tag is the release boundary; do not rewrite it.
5. The `remote-tag-consumer` CI job verifies a clean consumer can resolve the published tag.
6. Do not replace an existing binary release asset. Publish a new immutable release revision and update the manifest checksum.

The repository does not assign an untagged release version in advance. The README's dependency example selects a tagged range; evaluating `main` or a branch is an explicit choice.

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
- Update [Status](STATUS.md) after a validation campaign that changes the latest known state. Do not turn it into a chronological log; that is what records are for.
- When a record is superseded, update the index's status and `Superseded by` fields, not the record body.
- When a finding is repaired, record the commit, the regression test, and the remaining limitation. “Fixed” without evidence is not enough.
- When evidence is missing, write `unknown` or `requires verification`; do not invent certainty.
- Run the documentation check after moving or renaming a document.

## What not to do

- Do not change production behavior merely to make a historical document true.
- Do not weaken a test assertion to obtain a passing count.
- Do not delete historical engineering evidence because it is outdated.
- Do not present a clean-room or independent report's verdict as the current merge decision without checking the later records and status.
- Do not add a second copy of a contract that already has a canonical document.
- Do not describe a configured CI job as a passing result for a revision that did not run it.
- Do not hand-edit the generated field tables; run the generator.
