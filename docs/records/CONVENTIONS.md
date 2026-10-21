# Record conventions

These conventions keep engineering evidence traceable without turning documentation into a bureaucracy. A record is a Markdown file plus one row in the [record index](README.md).

## When to create a record

Create a record for:

- an independent or self-directed audit;
- an incident or a reproduced defect investigation;
- a remediation campaign that changes production behavior;
- a verification campaign whose evidence matters beyond the current test run;
- a dependency, binary, or platform migration;
- a maintenance pass with decisions or validation worth preserving.

Do not create a record for a routine test run, a single typo fix, or a change fully described by a commit and the changelog. Put routine validation in [docs/STATUS.md](../STATUS.md).

## Record types and identifiers

| Type | Prefix | Use |
| --- | --- | --- |
| Audit | `AUD` | Independent or internal examination that produces findings. |
| Review | `REV` | Verification of someone else's remediation or assessment. |
| Remediation | `REM` | Work performed in response to findings. |
| Verification | `VER` | A bounded evidence campaign, such as sanitizer, platform, corpus, or format verification. |
| Migration | `MIG` | Dependency, binary, platform, or API migration. |
| Maintenance | `MAINT` | A maintenance pass with decisions and validation. |
| Incident | `INC` | A reproduced failure or data-integrity incident. |
| Documentation | `DOC` | A documentation architecture or governance change. |

Use `TYPE-YYYY-MM-DD-short-slug`, for example `AUD-2026-10-19-clean-room`. The date is the record's completion date (or last-update date for a living maintenance log). If the date is unknown, use the date of the earliest reliable surrounding evidence and say so in the metadata.

File location:

```text
docs/records/<type-directory>/<RECORD-ID>.md
```

Type directories are `audits/`, `reviews/`, `remediation/`, `verification/`, `migrations/`, `maintenance/`, `incidents/`, and `documentation/` as needed. All records, including documentation-restructuring reports, live under the matching type directory.

## Required metadata

Start every new record with this table:

| Field | Value |
| --- | --- |
| Record ID | `AUD-YYYY-MM-DD-slug` |
| Type | Audit / review / remediation / verification / migration / maintenance / incident / documentation |
| Date | `YYYY-MM-DD` |
| Status | Final / historical / superseded / withdrawn |
| Examined revision | Commit hash, tag, or explicit range |
| Branch | Branch name, or `not applicable` |
| Environment | OS, Xcode, Swift, and any dependency version that affects the evidence |
| Supersedes | Record ID or `none` |
| Superseded by | Record ID or `none` |
| Related records | Record IDs, commits, or current docs |
| Scope | One or two sentences on what was and was not examined |

New records must state their scope and environment. Historical records imported into this archive may lack these fields; the index supplies them instead of rewriting the record.

## Required sections

1. **Summary** — verdict, confidence, and the most important findings.
2. **Scope and revision** — what was examined, what was not, and the exact revision.
3. **Method** — source inspection, runtime probes, tests, external tools, or a combination.
4. **Findings** — stable finding IDs, severity, confidence, and evidence.
5. **Repairs or recommendations** — what changed, or what should change. Do not present a recommendation as implemented.
6. **Verification** — commands, counts, environment, and limits. Distinguish compile, runtime, and reasoning evidence.
7. **Remaining limitations** — unverified behavior, accepted boundaries, and follow-up work.
8. **References** — commits, tests, source paths, current documentation.

A short verification record may omit sections that do not apply, but it must still state the revision and the evidence limits.

## Finding IDs and statuses

Use `F-01`, `F-02`, ... for findings in a new record, or retain an established domain prefix (`AUD-01`, `IV-01`, `VH-01`, `P-01`) when importing an existing record. Qualify a finding with its record when the bare ID could be ambiguous: `AUD-2026-10-19-clean-room/AUD-01`.

Use these finding statuses:

| Status | Meaning |
| --- | --- |
| Confirmed | Reproduced or established by source/runtime evidence. |
| Unverified | Plausible or reported, but not reproduced. |
| Fixed | A repair exists with source and regression evidence. |
| Fixed (claimed) | A remediation record claims a repair; no independent revalidation was performed. |
| Bounded | The limitation is intentional, documented, and fails safely or narrows the contract. |
| Open | Actionable and unresolved. |
| Not a defect | Revalidation did not support the reported defect. |
| Superseded | A later record replaces the finding or its conclusion. |

Never upgrade `Fixed (claimed)` to `Fixed` without naming the evidence. A passing test does not prove every documented behavior; state what the test actually exercises.

## Immutability and supersession

- A committed **Final** record is immutable. Do not silently update its findings, verdicts, dates, or test counts.
- If a conclusion changes, create an addendum section in a new record, or a superseding record with `Supersedes` and `Superseded by` links.
- Relocating a record is allowed when the archive organization requires it. Preserve the record content and repair only relative links. Record the move in the commit message.
- Never delete a record because it is outdated. Mark it historical or superseded in the index.

## Cross-references

- Add the record to [the investigation index](README.md).
- Link findings that cross record boundaries in the [open register](README.md#open-and-bounded-findings).
- Reference commits by hash and subject; do not rely on branch names alone.
- Reference tests by file and function where practical.
- Link current technical contracts rather than restating them. If a record and a current document disagree, the current document wins for current behavior; the record wins for what was observed at its revision.

## Evidence standard

A record should make it possible for another engineer to answer:

- What revision was examined?
- What commands or probes produced the evidence?
- Which observations were made directly, which came from another report, and which remain unverified?
- What was repaired, by which commit, and what regression covers it?
- What did the repair not cover?
- What is the latest known disposition?

Avoid unsupported guarantees, invented test counts, and claims that a compile-only exercise proves runtime behavior.

## Adding a record

1. Copy [TEMPLATE.md](TEMPLATE.md).
2. Fill in metadata and scope before writing conclusions.
3. Write findings with stable IDs and evidence.
4. Add the row to the investigation index.
5. Add any actionable or bounded item to the open register.
6. Run the link check described in [DEVELOPMENT.md](../DEVELOPMENT.md).
7. Commit the record and index update together.
