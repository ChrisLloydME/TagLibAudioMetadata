# Development and maintenance

This document describes the repository layout, change workflow, release process, and documentation maintenance conventions. It is for contributors and automated agents working on the package itself.

## Repository layout

| Path | Purpose |
| --- | --- |
| `Package.swift` | Swift tools 6.0 manifest; products, targets, binary dependency, platform minimums. |
| `Sources/TagLibAudioMetadata/` | Swift facade: models, schema, reads, writes, structured conversion, patches, verification. |
| `Sources/CTagLibBridge/` | Public Objective-C bridge, Objective-C++ implementation, private headers, format registry, and transaction coordinator. |
| `Sources/CTagLibBridgeInternalAPI/` | Package-internal in-place mutation declarations used by the facade. Not a library product. |
| `Sources/CTagLibBridge/include/` | Public bridge header. It exposes no C++ types and only transactional mutators. |
| `Tests/TagLibAudioMetadataTests/` | Single test target, physically organized by layer. |
| `IntegrationTests/Consumer/` | Facade-only and low-level consumer packages. |
| `scripts/` | Binary build and preservation-corpus generation. |
| `ThirdParty/TagLib/` | TagLib and utf8cpp license texts. |
| `docs/` | Current documentation; historical engineering records are under `docs/records/`. |
| `.github/workflows/` | CI and binary-release workflows. |

## Source-of-truth rules

- Current source code and `Package.swift` are authoritative for behavior and dependency identity.
- `CHANGELOG.md` is the release history. It can describe unreleased work; do not assign an untagged version number.
- Current docs under `docs/` describe the current HEAD. If a current doc and the code disagree, the code wins and the doc should be fixed.
- Files under `docs/records/` describe past investigations at named revisions. They are immutable evidence, not current contracts.
- Historical records must not be rewritten to match current behavior. Add an addendum or a superseding record.

## Change workflow

1. Inspect the current branch, HEAD, and working tree before editing.
2. Create a focused branch from the current development state. Do not rewrite existing history.
3. Make logically coherent commits as work progresses. Do not accumulate an entire assignment into one commit.
4. Keep production changes and documentation changes reviewable. Do not modify tests merely to make a documentation claim true.
5. Run the relevant checks from [TESTING](TESTING.md).
6. Update the canonical document for any behavior change. If the change is an investigation or campaign, add a record.
7. Review the diff and internal links before committing.

Existing commit messages are imperative and capitalized, for example `Preserve WAVE audio identity across bext and iXML relocation` and `Record complete clean-room remediation evidence and merge assessment`. Follow that style.

Do not amend, squash, rebase, reset, force-push, or merge into `main` as part of a normal documentation or maintenance branch. If a branch becomes stale, create a new branch rather than rewriting shared history.

## Documentation architecture

The current documentation has one canonical owner per topic:

| Topic | Canonical document |
| --- | --- |
| Project introduction, install, quick start | `README.md` |
| Documentation navigation | `docs/README.md` |
| Embedded framework, slices, signing, binary identity | `docs/INSTALLATION.md` |
| Public API semantics and recipes | `docs/USAGE.md` |
| Symbol-level API index | `docs/API_REFERENCE.md` |
| Format capability, evidence, limitations | `docs/FORMATS.md` |
| Preservation and write/verification contract | `docs/PRESERVATION.md` |
| Transactions, durability, filesystem, thread safety | `docs/TRANSACTIONS.md` |
| Audio-content identity and conflict rebasing | `docs/AUDIO_CONTENT_CONTINUITY.md` |
| Implementation architecture and source layout | `docs/ARCHITECTURE.md` |
| Testing and verification guidance | `docs/TESTING.md` |
| Current validation status | `docs/STATUS.md` |
| Compatibility and migration | `docs/MIGRATION.md` |
| Historical engineering records | `docs/records/README.md` |
| Record conventions | `docs/records/CONVENTIONS.md` |

Do not duplicate a detailed contract across several current documents. Link to the canonical owner. Short summaries in `README.md`, `USAGE.md`, and `STATUS.md` are acceptable when they point to the detail.

### Documentation style

- Use soft-wrapped Markdown paragraphs. Do not hard-wrap prose to a fixed column.
- Use leading and trailing pipes on every Markdown table row.
- Use relative links between repository documents. Verify them after moving files.
- Label historical claims, author-reported results, and unverified behavior explicitly.
- Do not claim that compilation proves runtime behavior.
- Do not present `fixtureCovered` as universal format support.
- Prefer "the package does X on the tested layouts" over "X is supported everywhere".

### Link check

Run this before committing a documentation change:

```sh
python3 - <<'PY'
import os, re
for root, dirs, names in os.walk('.'):
    if '.git' in root or '.build' in root:
        continue
    for name in names:
        if not name.endswith('.md'):
            continue
        path = os.path.join(root, name)
        text = open(path, encoding='utf-8').read()
        for match in re.finditer(r'\[[^\]]*\]\(([^)]+)\)', text):
            target = match.group(1).split('#')[0]
            if not target or target.startswith(('http://', 'https://', 'mailto:')):
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
            if not os.path.exists(resolved):
                print(f'{path}: missing {match.group(1)}')
PY
```

The original local-only `AUDIT_REPORT.md` is intentionally untracked and may be linked from a historical record. A clean clone will not have it; the record index explains that.

## Adding a record

Use [records/CONVENTIONS.md](records/CONVENTIONS.md) and [records/TEMPLATE.md](records/TEMPLATE.md). A record needs a metadata block, a revision, a method, findings with stable IDs, evidence, limitations, and an index row. Add actionable items to the open register.

## Release process

1. Ensure the changelog's `[Unreleased]` section describes the release and that current docs match the code.
2. Confirm the pinned binary identity in `Package.swift` and `scripts/taglib-binary-version.env`.
3. Run the test, sanitizer, release, strict-platform, and consumer checks that apply.
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

The dynamic framework is namespaced (`TagLibAudioMetadataTagLib`), but it still exports TagLib C++ symbols. Do not load another incompatible TagLib implementation into the same process. See [INSTALLATION](INSTALLATION.md) and [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md).

## Documentation and records maintenance

- Update `CHANGELOG.md` for user-visible additions, changes, fixes, and deprecations. Keep release boundaries accurate.
- Update [STATUS](STATUS.md) after a validation campaign that changes the latest known state. Do not turn it into a chronological log; that is what records are for.
- When a record is superseded, update the index's status and `Superseded by` fields, not the record body.
- When a finding is repaired, record the commit, the regression test, and the remaining limitation. "Fixed" without evidence is not enough.
- When evidence is missing, write `unknown` or `requires verification`; do not invent certainty.

## What not to do

- Do not change production behavior merely to make a historical document true.
- Do not weaken a test assertion to obtain a passing count.
- Do not delete historical engineering evidence because it is outdated.
- Do not present a clean-room or independent report's verdict as the current merge decision without checking the later records and status.
- Do not add a second copy of a contract that already has a canonical document.
