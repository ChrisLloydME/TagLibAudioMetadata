# Documentation hub

This directory is the maintained documentation for `TagLibAudioMetadata`. The latest published tag is `0.7.1`; the current pages describe the `main` working tree after `0.7.1`, including the unreleased audit, native-mapping, test-system and MP4 Content Group repairs. Mapping contract 2.2 behavior was introduced in `0.7.0`. Historical evidence lives under [records](records/README.md).

The source code, `Package.swift`, and the test target are the final authority for behavior and dependency identity. Generated reference pages are views of that source. If a current document and the code disagree, the code wins and the document must be fixed. If a historical record and current behavior disagree, the record is still correct for its revision.

## Reading paths

### I am adopting the package

1. [Getting started](guide/GETTING_STARTED.md) — requirements, first read, first verified patch.
2. [Installation](operations/INSTALLATION.md) — products, binary identity, embedding, signing.
3. [Reading metadata](guide/READING.md) — snapshots, Basic, raw, structured.
4. [Writing metadata](guide/WRITING.md) — typed patches, Basic, raw, structured, erase.
5. [Capabilities](guide/CAPABILITIES.md) — declared format and field support.
6. [Formats](reference/FORMATS.md) — generated matrix and container limits.

### I am implementing an editor

1. [Manager API](reference/API.md) — generated signatures for `TagLibMetadataManager`.
2. [Model reference](reference/MODELS.md) — every public value, schema, numbering, and error type.
3. [Field reference](reference/FIELDS.md) — keys, native targets, typed-patch policy.
4. [Write semantics](explanation/PRESERVATION.md) — omission, preservation, verification, erase.
5. [Transactions](explanation/TRANSACTIONS.md) — staging, durability, concurrency.
6. [Audio-content continuity](explanation/AUDIO_CONTENT_CONTINUITY.md) — guarded rebases, if needed.

For the normative mapping policy, read the [mapping contract](reference/MAPPING_SPEC.md). The [native mapping matrix](reference/MAPPING_MATRIX.md) is generated from `MetadataMappingCatalog.swift`, the executable source of truth for semantic-to-native targets.

### I am maintaining the package

1. [Architecture](explanation/ARCHITECTURE.md) — modules, flows, invariants, source and test layout.
2. [Development](operations/DEVELOPMENT.md) — change workflow, documentation pipeline, release, binary maintenance.
3. [Testing](operations/TESTING.md) — commands, CI, opt-ins, evidence limits.
4. [Mapping test acceptance](operations/MAPPING_TEST_STRATEGY.md) — lifecycle matrices, gate policy, coverage limits.
5. [Status](operations/STATUS.md) — latest observed validation state.
6. [Migration](operations/MIGRATION.md) — deprecations and behavioral changes.
7. [Engineering records](records/README.md) — past investigations and open findings.

## Document map

| Topic | Canonical document | Owns | Does not cover |
| --- | --- | --- | --- |
| Project introduction | [README](../README.md) | Purpose, requirements, install command, first examples. | Detailed contracts. |
| Navigation and ownership | This hub | Reading paths, document map, evidence vocabulary. | Technical behavior. |
| Getting started | [guide/GETTING_STARTED.md](guide/GETTING_STARTED.md) | First read, first patch, next steps. | Complete signatures or edge cases. |
| Reading | [guide/READING.md](guide/READING.md) | Snapshot, Basic, raw, structured reads, versions, extraction options. | Write semantics. |
| Writing | [guide/WRITING.md](guide/WRITING.md) | Typed, raw, Basic, structured writes, erase, recipes. | Deep preservation or transaction rules. |
| Capabilities | [guide/CAPABILITIES.md](guide/CAPABILITIES.md) | Capability queries, field support, evidence interpretation. | Full matrix or native mappings. |
| Manager API | [reference/API.md](reference/API.md) | Generated manager signatures, overload status, source links. | Value model members; per-field mappings. |
| Models | [reference/MODELS.md](reference/MODELS.md) | Generated public model, schema, numbering, and error declarations. | Manager operations. |
| Field registry | [reference/FIELDS.md](reference/FIELDS.md) | Field keys, categories, native targets, typed-patch policy, ownership rules. | Capability evidence per family. |
| Format capability | [reference/FORMATS.md](reference/FORMATS.md) | Generated family matrix, container surfaces, evidence levels, limitations. | General write semantics. |
| Objective-C bridge | [reference/BRIDGE.md](reference/BRIDGE.md) | Low-level product, selectors, projections, bridge transaction boundary. | Swift facade conveniences. |
| Mapping contract | [reference/MAPPING_SPEC.md](reference/MAPPING_SPEC.md) | Native mapping policy, date/number/advisory rules, implementation boundaries. | Generated target matrix details. |
| Mapping matrix | [reference/MAPPING_MATRIX.md](reference/MAPPING_MATRIX.md) | Generated per-family target registrations. | Policy rationale. |
| Preservation and verification | [explanation/PRESERVATION.md](explanation/PRESERVATION.md) | Model fidelity, omission/removal, Basic preservation, raw/structured rules, verification scope, erase. | Staging mechanics. |
| Transactions and concurrency | [explanation/TRANSACTIONS.md](explanation/TRANSACTIONS.md) | Preconditions, staging, atomicity, durability, process-local locking, error codes. | Field-level preservation. |
| Audio-content continuity | [explanation/AUDIO_CONTENT_CONTINUITY.md](explanation/AUDIO_CONTENT_CONTINUITY.md) | Identity availability, algorithm, guarded rebases, cost, limitations. | General snapshot semantics. |
| Implementation architecture | [explanation/ARCHITECTURE.md](explanation/ARCHITECTURE.md) | Modules, read/write flows, invariants, source map, test layout. | Consumer recipes. |
| Installation and distribution | [operations/INSTALLATION.md](operations/INSTALLATION.md) | Products, binary identity, slices, embedding, offline builds, diagnostics. | Format behavior. |
| Testing | [operations/TESTING.md](operations/TESTING.md) | Test layers, commands, CI jobs, opt-ins, independent oracles, evidence limits. | Current pass/fail claims or matrix case counts. |
| Mapping test acceptance | [operations/MAPPING_TEST_STRATEGY.md](operations/MAPPING_TEST_STRATEGY.md) | Required lifecycle matrices, independent oracles, mixed-framework gate, minimum case counts, coverage limits. | General test commands or current status. |
| Validation status | [operations/STATUS.md](operations/STATUS.md) | Latest observed run, environment, counts, skips, known failures, limitations. | Historical campaigns. |
| Development | [operations/DEVELOPMENT.md](operations/DEVELOPMENT.md) | Repository layout, source-of-truth rules, documentation pipeline, release, binary maintenance. | Application usage. |
| Compatibility | [operations/MIGRATION.md](operations/MIGRATION.md) | Source-compatibility promises, deprecation map, behavioral changes, release migration. | Release notes for every version. |
| Third-party licensing | [operations/THIRD_PARTY_NOTICES.md](operations/THIRD_PARTY_NOTICES.md) | TagLib and utf8cpp provenance, licenses, corresponding source. | Behavior. |
| Historical evidence | [records/README.md](records/README.md) | Audits, reviews, remediation, verification, migrations, maintenance logs. | Current contracts. |

When a behavior has two plausible owners, the narrower document wins. For example, format-specific write limits belong to [Formats](reference/FORMATS.md), while the general omission contract belongs to [Write semantics](explanation/PRESERVATION.md).

## Generated reference pages

The following pages are generated from source and must not be hand-edited:

| Page | Generator | Source |
| --- | --- | --- |
| [Manager API](reference/API.md) | `scripts/generate-api-reference.py` | public Swift manager declarations |
| [Models](reference/MODELS.md) | `scripts/generate-api-reference.py` | all other public Swift declarations |
| [Fields](reference/FIELDS.md) | `scripts/generate-field-schema.py` | `MetadataFieldSchema.swift` + `MetadataMappingCatalog.swift` |
| [Formats](reference/FORMATS.md) | `scripts/generate-format-matrix.py` | bridge registry, container masks, allowlists |
| [Mapping matrix](reference/MAPPING_MATRIX.md) | `scripts/generate-mapping-matrix.py` | `MetadataMappingCatalog.swift` |

The surrounding prose and the boundary markers are hand-maintained. `scripts/check-docs.py` verifies generated freshness, links, headings, tables, current-document coverage, bridge selector coverage, and format-extension coverage.

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

A passing test establishes that the executed assertions passed in that environment. It does not establish every field, codec, platform, or storage device. A compile-only check is not runtime verification. A historical "READY" verdict is not a current merge decision.

## Documentation rules

- Write soft-wrapped Markdown; do not hard-wrap prose to a fixed column.
- Use leading and trailing pipes on every Markdown table row.
- Link to the canonical owner instead of copying a detailed contract.
- Prefer precise, testable statements over marketing language.
- Label historical claims, author-reported results, and unverified behavior.
- State the scope of a guarantee: which formats, which surfaces, which environment.
- Do not describe a configured CI job as a passing result for a revision that did not run it.
- Do not present `fixtureCovered` as universal format support.
- Update [Status](operations/STATUS.md) only after a validation campaign that changes the latest known state. Put the campaign narrative in a record.
- Update [Migration](operations/MIGRATION.md) when a public API is deprecated or its semantics change.
- Regenerate the API, model, field, format, and mapping pages after a source change; do not edit their generated sections by hand.

## Documentation checks

Run the structural and generated-artifact check from the repository root:

```sh
python3 scripts/check-docs.py
```

The check validates relative links and heading fragments, table pipe balance, exactly one H1 per document, hub coverage for every current document, generated-section freshness, bridge selector coverage, and format-extension coverage. It does not prove prose or type signatures; those still require review and the compiler.

Regenerate a page after changing its source:

```sh
python3 scripts/generate-api-reference.py --write
python3 scripts/generate-field-schema.py --write
python3 scripts/generate-format-matrix.py --write
python3 scripts/generate-mapping-matrix.py --write
```

## Current vs. historical material

Current documents use the present tense and describe behavior at the revision you are reading. Historical records keep their original dates, revisions, findings, verdicts, and counts.

Do not silently rewrite a historical record to match current code. Add an addendum or a superseding record and update the [records index](records/README.md). Repair relative links after a move, but do not change the record's substantive claims. The 2026-10-19 and 2026-10-21 documentation reports are retained as [DOC-2026-10-19](records/documentation/DOC-2026-10-19-documentation-restructure.md) and [DOC-2026-10-21](records/documentation/DOC-2026-10-21-documentation-reconstruction.md); do not treat their remaining-work lists as a live backlog.
