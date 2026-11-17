# Agent instructions

This file is the entry point for automated agents working in this repository. It applies to the whole tree; if a nested `AGENTS.md` is added later, the closer file wins for its directory. [docs/operations/DEVELOPMENT.md](docs/operations/DEVELOPMENT.md) covers layout, source-of-truth rules, workflow and checks, and [docs/operations/COMMIT_MESSAGES.md](docs/operations/COMMIT_MESSAGES.md) is the full commit-message contract.

## Commit messages

Every commit message must satisfy all of the following.

1. Subject: `type: imperative summary`, where `type` is one of `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`; `revert` is reserved for a reversion.
2. The summary starts with a lowercase word, uses the imperative mood ("Add", "Preserve", "Reject"), has no scope such as `(spm)`, no `!`, no trailing period, no backticks or emoji, and is at most 60 characters (aim for 50).
3. Exactly one body paragraph follows, on a single line: one or two sentences, at most 300 characters, ending with a period, naming what changed and for which format, API surface, or evidence.
4. The body adds information the subject does not carry. No bullet lists, no headings, no "This commit", no restated subject, no invented facts or rationale, and no commit hashes.
5. Merge commits use `chore: merge <topic>` and keep the pull-request provenance in the body. Release preparation uses `docs: prepare <version> release`.
6. The subject is distinct from every other subject in the reachable history.

```text
refactor: isolate unsafe bridge mutation API

Keep the public Low-Level product transactional by moving in-place mutation and coordination declarations into a non-product implementation target used only by the Swift facade and package tests.
```

```text
fix: make metadata write contracts explicit

Unify artist-type canonical mapping, verify complete PropertyMap replacement, expose merge semantics for multi-value writes, reject unsupported RIFF synchronization before staging, and publish the durability-uncertain bridge error contract.
```

Before committing, check your range:

```bash
python3 scripts/check-commit-messages.py --range origin/main..HEAD
```

## Repository guardrails

- Do not rewrite, amend, squash, rebase, reset, or force-push published history as part of a normal branch; add commits instead.
- Do not hand-edit generated reference pages: `docs/reference/API.md`, `docs/reference/MODELS.md`, the marked sections of `docs/reference/FIELDS.md` and `docs/reference/FORMATS.md`, and `docs/reference/MAPPING_MATRIX.md`. Change the source, regenerate, and commit the regenerated page.
- Files under `docs/records/` are immutable evidence about past revisions. Add an addendum or a superseding record instead of rewriting them.
- Run `python3 scripts/check-docs.py` after any documentation change, and run the relevant checks in [docs/operations/TESTING.md](docs/operations/TESTING.md) for code changes.
- `.local/` is ignored local working material and is never part of a commit.
