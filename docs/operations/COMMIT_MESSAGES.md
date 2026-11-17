# Commit messages

Status: current. This page is the canonical commit-message contract for contributors and automated agents. [AGENTS.md](../../AGENTS.md) repeats the rules that must hold without opening this page, and [Development](DEVELOPMENT.md) links here from the change workflow. The contract applies to new commits; a full-history audit can still report commits created before it existed.

## Format

A commit message has exactly two parts: a Conventional Commit subject and one body paragraph.

```text
<type>: <imperative summary>

<one-paragraph body>
```

```text
fix: preserve literal legacy dates in projections

Move literal ID3v2.3 date parsing into the native extractor, preserve standalone TXXX date owners across patches, and reject legacy TYER/TDAT values that are not four digits or a valid DDMM pair.
```

The subject is what `git log --oneline` shows, so it must stand alone as a readable change index. The body carries the detail that the subject cannot: which contract, container, API surface, or evidence record changed. Every commit carries a body; a subject-only message is incomplete.

## Subject line

| Rule | Requirement |
| --- | --- |
| Type | One of `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`; `revert` only for a reversion. |
| Separator | Exactly `: ` (colon and one space) between the type and the summary. |
| Summary | Lowercase first word, imperative mood ("Add", "Preserve", "Reject", "Merge", not "Added" or "Adds"). |
| Scope | None. Do not write `fix(spm):` or `feat(api):`. |
| Length | 50 characters is the target; 60 is the hard maximum. |
| Punctuation | No trailing period, no backticks, no emoji, no issue numbers. |
| Uniqueness | Distinct from every other subject in the reachable history; `git log --oneline` is an index, not a list of repeated labels. |

Name the change, not the effort. "Preserve WAV INFO during targeted writes" describes a behavior; "Work on preservation" and "Update documentation" do not. When two subjects would describe the same commit, the more specific one wins.

Keep repository nouns in their established spelling in the summary: `MP4`, `ID3v2.3`, `WAV`, `AIFF`, `FLAC`, `Ogg`, `ASF`, `APE`, `PropertyMap`, `TagLib`.

## Types

| Type | Use for | Typical paths |
| --- | --- | --- |
| `feat` | A new public capability, API, format surface, or user-visible behavior. | `Sources/`, public tests |
| `fix` | Correcting wrong behavior, a contract violation, data loss, or a crash. | `Sources/`, `Tests/` |
| `docs` | Documentation, records, journals, changelog and release preparation. | `docs/`, `README.md`, `CHANGELOG.md`, `MAINTENANCE_PROGRESS.md` |
| `test` | Tests, fixtures, calibration harnesses, and gate policy. | `Tests/`, `IntegrationTests/`, `scripts/tests/`, `scripts/calibrate-test-system.py` |
| `refactor` | Restructuring code without changing external behavior. | `Sources/` |
| `perf` | Measured performance or I/O work, including benchmark baselines. | `Sources/`, `Tests/`, records |
| `build` | `Package.swift`, dependencies, binary frameworks, vendored artifacts, build scripts. | `Package.swift`, `Vendor/`, `scripts/` |
| `ci` | GitHub Actions workflows and release automation. | `.github/workflows/` |
| `chore` | Merge commits, licensing, ignore rules, repository housekeeping. | repository root |
| `revert` | Reverting a commit; otherwise unused. | anywhere |

Choose the type of the substantive change when a commit touches both code and documentation. A commit that changes only documentation is `docs` even when it also updates an index or a record table.

Release preparation is `docs`, because the change is changelog, migration, installation, and status text. A merge commit is `chore`, because the work itself is described by the commits it brings in.

## Body

- Exactly one paragraph, written on a single line. Do not wrap the body to a fixed width; do not add a second paragraph.
- One or two sentences, at most 300 characters, ending with a period.
- Present tense and concrete. State what changed and for which format, API, or evidence.
- Add information the subject does not already carry. Do not restate the subject.
- No bullet lists, headings, code fences, or backticks.
- No "This commit", no first-person voice, no rationale that the diff does not support.
- Do not embed short or full commit hashes. History can be rewritten and hashes go stale; name the revision by what it is.
- Pull-request and review references belong in merge-commit provenance, not in ordinary bodies.

## Special commits

### Merge commits

GitHub's default `Merge pull request #N from owner/branch` subject does not match this style. Use `chore: merge <topic>` and keep the provenance in the body.

```text
chore: merge automatic numbering recovery

Merge pull request #26 from ChrisLloydME/automatic-numbering-recovery, refactoring automatic numbering and strengthening test assertions.
```

If the merge has no pull request, describe the integration instead: `chore: merge <branch topic>` with the source branch in the body.

### Release preparation

Use `docs: prepare <version> release` and summarize the release surface in the body: changelog section, migration guidance, installation changes, status snapshot.

```text
docs: prepare 0.8.0 release

Finalize the changelog, README, status, migration, installation, reference and records pages for the breaking 0.8.0 release boundary, including the removed API table, the contract acceptance lane and the archived assignments.
```

A version number is assigned only in a commit approved for tagging; otherwise keep the change under the unreleased section, as described in [Development](DEVELOPMENT.md#source-of-truth-rules).

### Breaking changes

This repository does not use the `!` marker. State the removal or behavior change in the body and name the migration action or the document that owns it. The release boundary remains the tag, not the commit subject.

### Reverts

Use `revert: <original summary>` as the subject and state what is reverted and why in the body, naming the change by its subject rather than by hash. A `git revert` message must be edited before committing.

## Good and bad examples

The first column shows representative pre-contract messages; the corrected forms are illustrative.

| Instead of | Write | Why |
| --- | --- | --- |
| `Record automatic numbering standalone Debug acceptance` | `docs: record standalone Debug numbering acceptance` + body | Adds the type and removes the sentence-style capitalization. |
| `Fix ASF and MP4 bool attribute construction` | `fix: bind bool values before MP4 and ASF attributes` + body | Imperative, specific, and says what changed rather than which formats were touched. |
| `Merge pull request #26 from ChrisLloydME/automatic-numbering-recovery` | `chore: merge automatic numbering recovery` + PR body | Matches the type vocabulary and keeps provenance in the body. |
| `fix: Fixes the crash.` | `fix: reject stale snapshot edits with file versions` + body | Lowercase imperative, no period, and names the defect. |
| `docs: update docs` | `docs: document native-owner preservation` + body | The subject names the topic, not the activity. |

Two real messages in this style:

```text
refactor: isolate unsafe bridge mutation API

Keep the public Low-Level product transactional by moving in-place mutation and coordination declarations into a non-product implementation target used only by the Swift facade and package tests.
```

```text
fix: make metadata write contracts explicit

Unify artist-type canonical mapping, verify complete PropertyMap replacement, expose merge semantics for multi-value writes, reject unsupported RIFF synchronization before staging, and publish the durability-uncertain bridge error contract.
```

## Checklist before committing

1. Read the staged diff. Do not derive the message from the branch name or from the task statement alone.
2. Pick one type. If two seem to apply, use the type of the substantive change.
3. Write the subject, then shorten it until it fits 50 characters without losing the object of the verb.
4. Write one body paragraph that a reviewer could not already infer from the subject.
5. Check for bullets, restated subjects, invented claims, and commit hashes.
6. Run the checker on your range, then commit.

## Checking messages

`scripts/check-commit-messages.py` is an advisory checker for this contract. It validates the subject format, type, length, trailing punctuation, required single-line body, bullet and "This commit" patterns, and embedded commit hashes, and it flags duplicate subjects.

```bash
python3 scripts/check-commit-messages.py --range origin/main..HEAD
```

With no `--range`, it checks the commits that are not yet on `origin/main`, which is the set a pre-commit or pre-push check should cover; when that remote-tracking ref is absent, it checks every commit reachable from `HEAD`. Use `--range HEAD` for a full-history audit and expect pre-contract commits to be reported. It prints one line per problem and exits non-zero when an error is found. It is not wired into CI, because CI checkouts are shallow and merge messages are generated by GitHub; treat it as a pre-commit check for agents and maintainers.
