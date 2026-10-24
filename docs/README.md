# Documentation hub

This directory is the maintained documentation for `TagLibAudioMetadata`. It has two layers:

- **Current documentation** describes the code at the revision you are reading. Each topic has one canonical owner; other documents link to it instead of restating the contract.
- **[Engineering records](records/README.md)** preserve audits, reviews, remediation campaigns, verification runs, migrations, and maintenance logs at named revisions. They are evidence about the past, not current contracts.

The source code, `Package.swift`, and the test target are the final authority for behavior and dependency identity. If a current document and the code disagree, the code wins and the document should be fixed. If a historical record and current behavior disagree, the record is still correct for its revision.

## Reading paths

### I am adopting the package

1. [Project README](../README.md) — purpose, requirements, quick start.
2. [Installation](INSTALLATION.md) — products, binary identity, embedding, signing.
3. [Usage](USAGE.md) — choose a read/write layer and apply a first patch.
4. [Formats](FORMATS.md) — check the extension and field before enabling a control.

### I am implementing an editor

1. [Usage](USAGE.md) — read snapshots, typed patches, Basic updates, raw and structured edits.
2. [API reference](API_REFERENCE.md) — signatures, defaults, nested types, errors.
3. [Field schema](FIELD_SCHEMA.md) — field keys, container mappings, patch constraints.
4. [Write semantics](PRESERVATION.md) — omission, preservation, verification scope, erase.
5. [Transactions](TRANSACTIONS.md) — staged writes, durability, concurrency.
6. [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md) — guarded conflict rebasing, if needed.

### I am maintaining the package

1. [Architecture](ARCHITECTURE.md) — modules, flows, invariants, source and test layout.
2. [Testing](TESTING.md) — commands, CI, opt-ins, evidence limits.
3. [Status](STATUS.md) — latest observed validation state.
4. [Development](DEVELOPMENT.md) — change workflow, documentation system, release, binary maintenance.
5. [Compatibility and migration](MIGRATION.md) — deprecations and behavioral changes.
6. [Engineering records](records/README.md) — past investigations and open findings.

## Current documents

| Topic | Canonical document | Owns | Does not cover |
| --- | --- | --- | --- |
| Project introduction | [README](../README.md) | Purpose, requirements, install command, first examples. | Detailed contracts. |
| Navigation and ownership | This hub | Reading paths, document map, evidence vocabulary. | Technical behavior. |
| Installation and distribution | [Installation](INSTALLATION.md) | Products, requirement matrix, binary identity, slices, embedding, offline builds, diagnostics. | Format behavior. |
| Task-based usage | [Usage](USAGE.md) | Choosing a layer, first read/write recipes, error handling, common tasks. | Complete signatures; deep preservation or transaction rules. |
| Complete Swift surface | [API reference](API_REFERENCE.md) | Every public Swift declaration, default, nested type, model, and error. | Per-field container mappings; bridge selectors. |
| Field registry | [Field schema](FIELD_SCHEMA.md) | `MetadataFieldKey`, schemas, `PropertyMap`/ID3v2/MP4 mappings, patch value constraints, registry lookup rules. | Capability evidence per family. |
| Objective-C bridge | [Bridge reference](BRIDGE.md) | Low-level product, bridge model, selectors, projection shapes, bridge transaction boundary. | Swift facade conveniences. |
| Format capability | [Formats](FORMATS.md) | 22-family registry matrix, container surfaces, evidence levels, per-format limits, fixtures. | General write semantics. |
| Preservation and verification | [Write semantics](PRESERVATION.md) | Model fidelity, omission/removal, Basic preservation, raw/structured write rules, verification scope, erase. | Staging mechanics. |
| Transactions and concurrency | [Transactions](TRANSACTIONS.md) | Preconditions, staging, atomicity, durability, process-local locking, error codes. | Field-level preservation. |
| Audio-content continuity | [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md) | Identity availability, algorithm, guarded rebases, cost, limitations. | General snapshot semantics. |
| Implementation architecture | [Architecture](ARCHITECTURE.md) | Modules, read/write flows, invariants, source map, test layout. | Consumer recipes. |
| Testing | [Testing](TESTING.md) | Test layers, commands, CI jobs, opt-ins, independent oracles, evidence limits. | Current pass/fail claims. |
| Validation status | [Status](STATUS.md) | Latest observed run, environment, counts, skips, known failures, current limitations. | Historical campaigns. |
| Compatibility | [Compatibility and migration](MIGRATION.md) | Source-compatibility promises, deprecation map, behavioral changes, 0.4→0.5 migration. | Release notes for every version. |
| Development | [Development](DEVELOPMENT.md) | Repository layout, change workflow, documentation maintenance, release, binary dependency. | Application usage. |
| Third-party licensing | [Third-party notices](THIRD_PARTY_NOTICES.md) | TagLib and utf8cpp provenance, licenses, corresponding source. | Behavior. |
| Historical evidence | [Engineering records](records/README.md) | Audits, reviews, remediation, verification, migrations, maintenance logs. | Current contracts. |

When a behavior has two plausible owners, the narrower document wins: for example, format-specific write limits belong to [Formats](FORMATS.md), while the general omission contract belongs to [Write semantics](PRESERVATION.md).

## Evidence vocabulary

Use these labels consistently when reading or writing documentation:

| Label | Meaning |
| --- | --- |
| **Current** | Maintained for the code at this revision. |
| **Observed** | A command was run in a stated environment; it establishes only that run. |
| **Configured** | A check or job exists in the repository; it is not proof that it passed for this revision. |
| **Fixture-covered** | The repository has a fixture and regression tests for an extension; not universal support. |
| **Upstream-supported** | TagLib exposes the format, but this package has no round-trip fixture for it. |
| **Experimental** | A save path exists, but the container behavior is incomplete or narrowly scoped. |
| **Read-only** | Readable by the package, with no supported save path. |
| **Bounded** | An intentional limitation, ideally with a fail-closed behavior. |
| **Historical** | Describes a past revision; not a current assessment. |
| **Unknown** | Insufficient evidence. |

A passing test establishes that the executed assertions passed in that environment. It does not establish every field, codec, platform, or storage device. A compile-only check is not runtime verification. A historical “READY” verdict is not a current merge decision.

## Documentation rules

- Write soft-wrapped Markdown; do not hard-wrap prose to a fixed column.
- Use leading and trailing pipes on every Markdown table row.
- Link to the canonical owner instead of copying a detailed contract.
- Prefer precise, testable statements over marketing language.
- Label historical claims, author-reported results, and unverified behavior.
- State the scope of a guarantee: which formats, which surfaces, which environment.
- Do not describe a configured CI job as a passing result for a revision that did not run it.
- Do not present `fixtureCovered` as universal format support.
- Update [Status](STATUS.md) only after a validation campaign that changes the latest known state. Put the campaign narrative in a record.
- Update [Compatibility and migration](MIGRATION.md) when a public API is deprecated or its semantics change.
- Update [API reference](API_REFERENCE.md) when a public declaration is added, removed, or given a new default.
- Update [Field schema](FIELD_SCHEMA.md) by running the generator, not by editing the generated tables by hand.

## Documentation checks

Run the structural check from the repository root:

```sh
python3 scripts/check-docs.py
```

The check validates relative links and heading fragments, table pipe balance, exactly one H1 per document, hub coverage for every current document, generated field-table freshness, format-extension coverage against the bridge registry, and index coverage for every public manager function and public Swift type. It does not prove prose or type signatures; those still require review and the compiler.

The field tables in [Field schema](FIELD_SCHEMA.md) are generated from `MetadataFieldSchema.swift`:

```sh
python3 scripts/generate-field-schema.py --write   # update
python3 scripts/generate-field-schema.py --check   # compare without writing
```

`scripts/check-docs.py` runs the `--check` form. If the registry changes and the tables are not regenerated, the documentation check fails.

## Current vs. historical material

Current documents use the present tense and describe behavior at the revision you are reading. They may state test counts only in [Status](STATUS.md), where the environment, revision, and opt-in state are recorded. Historical records keep their original dates, revisions, findings, verdicts, and counts.

Do not silently rewrite a historical record to match current code. Add an addendum or a superseding record and update the [records index](records/README.md). Repair relative links after a move, but do not change the record's substantive claims.

## Retired documents

The 2026-10-19 documentation-restructuring report is retained as [DOC-2026-10-19](records/documentation/DOC-2026-10-19-documentation-restructure.md), and the 2026-10-21 reconstruction as [DOC-2026-10-21](records/documentation/DOC-2026-10-21-documentation-reconstruction.md). Both describe earlier passes, not the current owner map. Do not treat their “remaining work” lists as a live backlog; track live work in a current issue or a new record.
