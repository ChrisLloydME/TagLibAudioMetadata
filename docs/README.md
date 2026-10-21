# Documentation hub

This directory contains the maintained documentation for `TagLibAudioMetadata`. It has two layers:

- **Current documentation** describes the code at the revision you are reading. Each topic has one canonical owner, and other documents link to it instead of restating the contract.
- **[Engineering records](records/README.md)** preserve audits, reviews, remediation campaigns, verification runs, migrations, and maintenance logs at named revisions. They are evidence about the past, not current contracts.

The source code, `Package.swift`, and test target are the final authority for behavior and dependency identity. If a current document and the code disagree, the code wins and the document should be fixed. If a historical record and current behavior disagree, the record is still correct for its revision.

## Start by task

| I want to… | Read |
| --- | --- |
| Understand the package, install it, and run a first read/write | [README](../README.md), then [Installation](INSTALLATION.md) |
| Choose the right read or write API for an app | [Usage](USAGE.md) |
| Look up a type, function, default, or error case | [API reference](API_REFERENCE.md) |
| Decide whether a format/field is supported | [Formats](FORMATS.md) |
| Understand omission, deletion, Basic preservation, and verification | [Write semantics](PRESERVATION.md) |
| Understand staging, atomicity, durability, and locking | [Transactions](TRANSACTIONS.md) |
| Rebase edits when audio may have changed | [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md) |
| Understand the implementation and source layout | [Architecture](ARCHITECTURE.md) |
| Run tests, sanitizers, consumers, or opt-in checks | [Testing](TESTING.md) |
| See the latest observed validation state | [Status](STATUS.md) |
| Migrate from an older release or a deprecated API | [Compatibility and migration](MIGRATION.md) |
| Contribute, release, or maintain the documentation | [Development](DEVELOPMENT.md) |
| Investigate a past audit, review, or remediation | [Engineering records](records/README.md) |
| Add a new engineering record | [Record conventions](records/CONVENTIONS.md) and [template](records/TEMPLATE.md) |

## Canonical owners

| Topic | Canonical document | Notes |
| --- | --- | --- |
| Project introduction, requirements, install, quick start | [README](../README.md) | Short examples only; deep behavior belongs in the topic documents. |
| Navigation, ownership, documentation rules | This hub | No technical contract beyond navigation. |
| Binary distribution, slices, embedding, signing | [Installation](INSTALLATION.md) | Includes checksum identity and offline builds. |
| Public API semantics and recipes | [Usage](USAGE.md) | Task-oriented; does not duplicate the symbol index. |
| Complete public surface | [API reference](API_REFERENCE.md) | Signatures, defaults, models, bridge header, deprecations. |
| Format capability and evidence | [Formats](FORMATS.md) | 22-family matrix, per-extension levels, container boundaries. |
| Metadata preservation and write semantics | [Write semantics](PRESERVATION.md) | Omission/removal, model fidelity, verification scope, erase. |
| Atomicity, durability, filesystem checks, concurrency | [Transactions](TRANSACTIONS.md) | Swift facade and public bridge pipelines. |
| Audio identity and guarded rebasing | [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md) | Optional feature; availability, algorithm, cost, caveats. |
| Implementation architecture and source map | [Architecture](ARCHITECTURE.md) | Modules, data flow, invariants, test layout. |
| Test commands and evidence limits | [Testing](TESTING.md) | Commands, CI jobs, opt-ins, independent oracles. |
| Latest observed validation state | [Status](STATUS.md) | A snapshot, not a chronological log. |
| Source compatibility and deprecated names | [Compatibility and migration](MIGRATION.md) | Current deprecation map and behavior changes. |
| Contribution, release, docs and binary maintenance | [Development](DEVELOPMENT.md) | Repository workflow and maintenance procedures. |
| Historical investigation | [Engineering records](records/README.md) | Immutable after publication except link repair and index annotations. |
| Third-party licenses | [Third-party notices](THIRD_PARTY_NOTICES.md) | Legal provenance, not behavior. |

## Evidence vocabulary

Use these labels consistently when reading or writing documentation:

| Label | Meaning |
| --- | --- |
| **Current** | Maintained for the code at this revision. |
| **Observed** | A command was run in a stated environment; it establishes only that run. |
| **Configured** | A check or job exists in the repository; it is not proof that it passed for this revision. |
| **Fixture-covered** | The repository has a fixture and regression tests for an extension; not universal support. |
| **Upstream-supported** | TagLib exposes the format, but this package has no round-trip fixture for it. |
| **Bounded** | An intentional limitation, ideally with a fail-closed behavior. |
| **Historical** | Describes a past revision; not a current assessment. |
| **Unknown** | Insufficient evidence. |

A passing test establishes that the executed assertions passed in that environment. It does not establish every field, codec, platform, or storage device. A compile-only check is not runtime verification. A historical “READY” verdict is not a current merge decision.

## Current vs. historical material

Current documents use the present tense and describe behavior at `HEAD`. They may state test counts only in [Status](STATUS.md), where the environment, revision, and opt-in state are also recorded. Historical records keep their original dates, revisions, findings, verdicts, and counts.

Do not silently rewrite a historical record to match current code. Add an addendum or a superseding record and update the [records index](records/README.md). Repair relative links after a move, but do not change the record's substantive claims.

## Documentation maintenance

- Write soft-wrapped Markdown; do not hard-wrap prose to a fixed column.
- Use leading and trailing pipes on every Markdown table row.
- Link to the canonical owner instead of copying a detailed contract.
- Label historical claims, author-reported results, and unverified behavior.
- Update [Status](STATUS.md) only after a validation campaign that changes the latest known state. Put the full campaign narrative in a record.
- Update [Migration](MIGRATION.md) when a public API is deprecated or its semantics change.
- Update the [API reference](API_REFERENCE.md) when a public declaration is added, removed, or given a new default.
- Run the documentation check before committing:

```sh
python3 scripts/check-docs.py
```

The check validates relative links, table pipe balance, current-document index coverage, and a few structural invariants. It does not prove that prose is technically correct; review against the source.

## Retired documents

The documentation-restructuring report from 2026-10-19 is retained as a historical record at [DOC-2026-10-19](records/documentation/DOC-2026-10-19-documentation-restructure.md). It describes a previous documentation pass, not the current owner map. Do not treat its “remaining work” list as a live backlog; track live work in a current issue or a new record. The 2026-10-21 reconstruction is recorded in [DOC-2026-10-21](records/documentation/DOC-2026-10-21-documentation-reconstruction.md).
