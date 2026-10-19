# Documentation

This is the entry point for the repository's documentation. It separates **current technical documentation** from **historical engineering records** and makes the authoritative owner for each topic explicit.

Current code is the primary source of truth. A statement in a current document is a description of the code at the revision you are reading; a statement in a record is evidence about a past revision.

## Start here

| I want to… | Read |
| --- | --- |
| Understand the package and install it | [README](../README.md) and [Installation](INSTALLATION.md) |
| Use the public API | [API and usage guide](USAGE.md) |
| Look up a type or method signature | [API reference](API_REFERENCE.md) |
| Know which formats and fields are supported | [Formats](FORMATS.md) |
| Understand preservation, omission, removal, and verification | [Preservation and write semantics](PRESERVATION.md) |
| Understand atomicity, durability, filesystem checks, and thread safety | [Transactions and concurrency](TRANSACTIONS.md) |
| Adopt audio-content continuity for conflict rebasing | [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md) |
| Understand the implementation | [Architecture](ARCHITECTURE.md) |
| Run tests, sanitizers, platform builds, or opt-in checks | [Testing and verification](TESTING.md) |
| See the latest known validation state | [Status](STATUS.md) |
| Migrate from an older release or adopt deprecated-name replacements | [Compatibility and migration](MIGRATION.md) |
| Contribute, release, or maintain the docs | [Development and maintenance](DEVELOPMENT.md) |
| Investigate a past audit, review, or remediation | [Engineering records](records/README.md) |
| Add a new audit or verification record | [Record conventions](records/CONVENTIONS.md) and [template](records/TEMPLATE.md) |

## Current technical documentation

These documents describe the code at the current HEAD and are maintained together with it. Each topic has one canonical owner; other documents link to it rather than restating the detailed contract.

| Document | Canonical scope |
| --- | --- |
| [Installation](INSTALLATION.md) | Package products, binary identity, slices, embedding, signing, offline builds, diagnostics. |
| [Usage](USAGE.md) | Public API semantics, examples, error handling, and integration recipes. |
| [API reference](API_REFERENCE.md) | Symbol-level index of the public surface. |
| [Formats](FORMATS.md) | 22-family capability matrix, per-extension evidence levels, format-specific limitations. |
| [Preservation](PRESERVATION.md) | Model fidelity, omission/removal, Basic preservation, raw/structured semantics, verification scope, erase. |
| [Transactions](TRANSACTIONS.md) | Staging, atomic rename, durability, rejection cases, process-local concurrency, thread safety. |
| [Audio-content continuity](AUDIO_CONTENT_CONTINUITY.md) | Opt-in audio identity, supported layouts, guarded writes, cost, compatibility caveats. |
| [Architecture](ARCHITECTURE.md) | Dependency boundary, read/write pipelines, schema, source and test layout. |
| [Testing](TESTING.md) | Test layers, commands, sanitizers, platform builds, opt-in checks, evidence limits. |
| [Status](STATUS.md) | Latest known validation state and current limitations. |
| [Migration](MIGRATION.md) | Compatibility promises, deprecated-name replacements, behavior changes. |
| [Development](DEVELOPMENT.md) | Repository layout, change workflow, release process, documentation maintenance. |
| [Third-party notices](THIRD_PARTY_NOTICES.md) | TagLib and utf8cpp licensing and provenance. |

`README.md`, `CHANGELOG.md`, `LICENSE`, and `Package.swift` remain at the repository root. The audio fixture provenance is in [Tests/TagLibAudioMetadataTests/Audio/README.md](../Tests/TagLibAudioMetadataTests/Audio/README.md).

## Historical engineering records

Records live under [docs/records/](records/README.md). They preserve audits, independent reviews, remediation campaigns, verification evidence, migrations, and maintenance logs at the revisions they examined. They are immutable historical evidence, not current contracts.

- [Investigation index](records/README.md#investigation-index)
- [Finding dispositions](records/README.md#finding-disposition-summary)
- [Open and bounded findings](records/README.md#open-and-bounded-findings)
- [Record conventions](records/CONVENTIONS.md)

Do not silently update a historical record to match current code. Add an addendum or a superseding record, and update the index's relevance annotation.

## Reading the evidence labels

| Label | Meaning |
| --- | --- |
| Current | Maintained for the current code. |
| Final | A complete record for its scope; immutable. |
| Historical | Describes a past revision; not a current assessment. |
| Superseded | A later record replaces its conclusions. |
| Fixed | A repair exists with source/test evidence, as stated by the record. |
| Fixed (claimed) | A remediation claims a repair; not independently revalidated. |
| Bounded | An intentional, documented limitation. |
| Open | Actionable and unresolved. |
| Unknown | Insufficient evidence. |

A passing test does not prove every documented behavior. A compile-only platform build does not prove runtime behavior. A historical "READY" verdict is not a current merge approval. The latest known state is in [STATUS](STATUS.md).

## Documentation conventions

- Soft-wrap Markdown paragraphs; do not hard-wrap to a fixed column.
- Use leading and trailing pipes on every table row.
- Keep one canonical owner per topic and link rather than duplicate.
- State revision, environment, and scope when reporting evidence.
- Preserve historical records, dates, revisions, and conclusions.
- Repair relative links after moving a document.
- Run the link check in [DEVELOPMENT](DEVELOPMENT.md#link-check) before committing a documentation change.

## Maintaining this hub

When adding a current document, add it to the table above and to the canonical-owner table in [DEVELOPMENT](DEVELOPMENT.md#documentation-architecture). When adding a record, add it to the [investigation index](records/README.md#investigation-index). When retiring a current document, update every relative link and record the consolidation in the changelog or the final restructuring report.
