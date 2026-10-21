#!/usr/bin/env python3
"""Structural checks for the repository documentation.

This is intentionally not a prose linter or a Swift API checker. It catches the
mechanical problems that make documentation hard to maintain:

* broken relative links and heading fragments;
* markdown table rows without leading/trailing pipes;
* a changed set of current documents that is not reflected in the hub;
* links to retired current-document paths;
* missing top-level headings.

Run from the repository root or any subdirectory:

    python3 scripts/check-docs.py
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent

CURRENT_DOCUMENTS = (
    "README.md",
    "INSTALLATION.md",
    "USAGE.md",
    "API_REFERENCE.md",
    "FORMATS.md",
    "PRESERVATION.md",
    "TRANSACTIONS.md",
    "AUDIO_CONTENT_CONTINUITY.md",
    "ARCHITECTURE.md",
    "TESTING.md",
    "STATUS.md",
    "MIGRATION.md",
    "DEVELOPMENT.md",
    "THIRD_PARTY_NOTICES.md",
)

RETIRED_PATHS = {
    "docs/SUPPORT.md",
    "docs/THREAD_SAFETY.md",
    "docs/DOCUMENTATION_RESTRUCTURING_REPORT.md",
}

LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
IMAGE_RE = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")


def markdown_files() -> list[Path]:
    files: list[Path] = []
    for root, dirs, names in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in {".git", ".build", ".swiftpm"}]
        for name in names:
            if name.endswith(".md"):
                path = Path(root) / name
                # The maintainer's local-only audit is intentionally untracked.
                if path == ROOT / "AUDIT_REPORT.md":
                    continue
                files.append(path)
    return sorted(files)


def strip_code_fences(text: str) -> list[tuple[int, str, bool]]:
    """Return (line_number, line, in_fence) for each line."""
    result: list[tuple[int, str, bool]] = []
    fence: str | None = None
    for number, line in enumerate(text.splitlines(), start=1):
        stripped = line.lstrip()
        if stripped.startswith("```") or stripped.startswith("~~~"):
            marker = stripped[:3]
            if fence is None:
                fence = marker
            elif marker == fence:
                fence = None
            result.append((number, line, True))
            continue
        result.append((number, line, fence is not None))
    return result


def github_slug(heading: str) -> str:
    value = heading.strip().lower()
    value = re.sub(r"[`*_~]", "", value)
    value = re.sub(r"[^\w\s\-.]", "", value, flags=re.UNICODE)
    value = re.sub(r"[\s.]+", "-", value)
    value = re.sub(r"-+", "-", value).strip("-")
    return value


def heading_slugs(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    slugs: set[str] = set()
    for _, line, in_fence in strip_code_fences(text):
        if in_fence:
            continue
        match = re.match(r"^(#{1,6})\s+(.*?)\s*$", line)
        if match:
            slugs.add(github_slug(match.group(2)))
    return slugs


def split_target(raw: str) -> tuple[str, str]:
    target = raw.strip()
    if target.startswith("<") and ">" in target:
        target = target[1 : target.index(">")]
    else:
        target = target.split(" ", 1)[0]
    path, _, fragment = target.partition("#")
    return unquote(path), unquote(fragment)


def check_links(path: Path, errors: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    for match in list(LINK_RE.finditer(text)) + list(IMAGE_RE.finditer(text)):
        raw = match.group(1)
        if not raw or raw.startswith(("http://", "https://", "mailto:", "tel:")):
            continue
        target_path, fragment = split_target(raw)
        if not target_path and not fragment:
            continue
        if target_path.startswith("/"):
            resolved = ROOT / target_path.lstrip("/")
        elif not target_path:
            resolved = path
        else:
            resolved = (path.parent / target_path).resolve()
        try:
            relative = resolved.relative_to(ROOT)
        except ValueError:
            errors.append(f"{path.relative_to(ROOT)}: link escapes repository: {raw}")
            continue
        if str(relative) in RETIRED_PATHS:
            errors.append(f"{path.relative_to(ROOT)}: link targets retired document: {raw}")
        if not resolved.exists():
            errors.append(f"{path.relative_to(ROOT)}: missing link target: {raw}")
            continue
        if fragment and resolved.suffix == ".md":
            if fragment not in heading_slugs(resolved):
                errors.append(f"{path.relative_to(ROOT)}: missing heading fragment: {raw}")


def table_rows(text: str) -> list[tuple[int, str]]:
    rows: list[tuple[int, str]] = []
    lines = strip_code_fences(text)
    previous_was_table = False
    for number, line, in_fence in lines:
        if in_fence:
            previous_was_table = False
            continue
        stripped = line.strip()
        is_table = stripped.startswith("|") or (
            previous_was_table and "|" in stripped and not stripped.startswith(("```", "#"))
        )
        if is_table:
            rows.append((number, line))
        previous_was_table = is_table or bool(re.match(r"^\s*\|?[\s:|-]+\|[\s:|-]*$", line))
    return rows


def check_tables(path: Path, errors: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    for number, line in table_rows(text):
        stripped = line.strip()
        if not stripped.startswith("|") or not stripped.endswith("|"):
            errors.append(
                f"{path.relative_to(ROOT)}:{number}: table row lacks leading/trailing pipe"
            )


def check_headings(path: Path, errors: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    h1_count = 0
    for _, line, in_fence in strip_code_fences(text):
        if not in_fence and re.match(r"^#\s+\S", line):
            h1_count += 1
    if h1_count != 1:
        errors.append(f"{path.relative_to(ROOT)}: expected exactly one H1, found {h1_count}")


def check_current_documents(errors: list[str]) -> None:
    docs = ROOT / "docs"
    for name in CURRENT_DOCUMENTS:
        path = docs / name
        if not path.exists():
            errors.append(f"docs/{name}: canonical current document is missing")
    hub = docs / "README.md"
    if not hub.exists():
        errors.append("docs/README.md: hub is missing")
        return
    hub_text = hub.read_text(encoding="utf-8")
    for name in CURRENT_DOCUMENTS:
        if name == "README.md":
            continue
        if f"]({name})" not in hub_text and f"]({name}#" not in hub_text:
            errors.append(f"docs/README.md: hub does not link to current document {name}")


def check_retired_paths(errors: list[str]) -> None:
    # Retired paths are rejected when they appear as Markdown link targets in
    # check_links(). Prose mentions are allowed in historical records and the
    # changelog, where they are legitimate historical coordinates.
    return


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()

    errors: list[str] = []
    files = markdown_files()
    for path in files:
        check_links(path, errors)
        check_tables(path, errors)
        check_headings(path, errors)
    check_current_documents(errors)
    check_retired_paths(errors)

    if errors:
        print("Documentation check failed:\n", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        print(f"\n{len(errors)} issue(s) across {len(files)} Markdown files.", file=sys.stderr)
        return 1

    print(f"Documentation check passed: {len(files)} Markdown files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
