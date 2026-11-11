#!/usr/bin/env python3
"""Structural and generated-artifact checks for the repository documentation.

This is intentionally not a prose linter or a Swift compiler. It catches the
mechanical problems that make documentation hard to maintain:

* broken relative links and heading fragments;
* Markdown table rows without leading/trailing pipes;
* a changed set of current documents that is not reflected in the hub;
* links to retired current-document paths;
* missing top-level headings;
* stale generated reference pages;
* missing registered format extensions or a stale family/extension count;
* public Swift declarations that are absent from the generated reference;
* public bridge selectors and constants that are absent from the bridge page.

Run from the repository root or any subdirectory:

    python3 scripts/check-docs.py
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent

CURRENT_DOCUMENTS = (
    "README.md",
    "guide/GETTING_STARTED.md",
    "guide/READING.md",
    "guide/WRITING.md",
    "guide/CAPABILITIES.md",
    "reference/API.md",
    "reference/MODELS.md",
    "reference/FIELDS.md",
    "reference/FORMATS.md",
    "reference/BRIDGE.md",
    "reference/MAPPING_SPEC.md",
    "reference/MAPPING_MATRIX.md",
    "explanation/ARCHITECTURE.md",
    "explanation/PRESERVATION.md",
    "explanation/TRANSACTIONS.md",
    "explanation/AUDIO_CONTENT_CONTINUITY.md",
    "operations/INSTALLATION.md",
    "operations/TESTING.md",
    "operations/MAPPING_TEST_STRATEGY.md",
    "operations/STATUS.md",
    "operations/DEVELOPMENT.md",
    "operations/MIGRATION.md",
    "operations/THIRD_PARTY_NOTICES.md",
)

RETIRED_PATHS = {
    "docs/SUPPORT.md",
    "docs/THREAD_SAFETY.md",
    "docs/DOCUMENTATION_RESTRUCTURING_REPORT.md",
    "docs/USAGE.md",
    "docs/API_REFERENCE.md",
    "docs/FIELD_SCHEMA.md",
    "docs/BRIDGE.md",
    "docs/FORMATS.md",
    "docs/PRESERVATION.md",
    "docs/TRANSACTIONS.md",
    "docs/AUDIO_CONTENT_CONTINUITY.md",
    "docs/ARCHITECTURE.md",
    "docs/TESTING.md",
    "docs/STATUS.md",
    "docs/MIGRATION.md",
    "docs/DEVELOPMENT.md",
    "docs/THIRD_PARTY_NOTICES.md",
    "docs/INSTALLATION.md",
    "docs/METADATA_MAPPING_SPEC.md",
}

LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
IMAGE_RE = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")


def markdown_files() -> list[Path]:
    files: list[Path] = []
    for root, dirs, names in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in {".git", ".build", ".swiftpm", ".local"}]
        for name in names:
            if name.endswith(".md"):
                files.append(Path(root) / name)
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


def run_generator(name: str, errors: list[str]) -> None:
    result = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / name), "--check"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        errors.append(f"{name} --check failed: {detail}")


def check_generated_pages(errors: list[str]) -> None:
    for generator in (
        "generate-api-reference.py",
        "generate-field-schema.py",
        "generate-format-matrix.py",
        "generate-mapping-matrix.py",
    ):
        run_generator(generator, errors)


def parse_format_registry(errors: list[str]) -> tuple[list[tuple[str, list[str]]], int]:
    source = (ROOT / "Sources/CTagLibBridge/TLFormatRegistry.mm").read_text(encoding="utf-8")
    extension_map: dict[str, list[str]] = {}
    for name, body in re.findall(r"const char \*?(k\w+Extensions)\[\] = \{([^}]*)\};", source):
        extension_map[name] = re.findall(r'"([^"]+)"', body)
    fields = source.split("const TLFormatCapabilityDescriptor kDescriptors[] = {", 1)[1].split(
        "};", 1
    )[0]
    families: list[tuple[str, list[str]]] = []
    for line in fields.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        tokens = re.findall(r'"(?:[^"\\]|\\.)*"|\b\w+\b', line)
        if len(tokens) < 5:
            continue
        extension_key = tokens[4]
        if extension_key not in extension_map:
            errors.append(f"TLFormatRegistry.mm: unknown extension table {extension_key}")
            continue
        families.append((tokens[1].strip('"'), extension_map[extension_key]))
    return families, sum(len(extensions) for _, extensions in families)


def check_formats(errors: list[str]) -> None:
    families, extension_count = parse_format_registry(errors)
    formats = (ROOT / "docs/reference/FORMATS.md").read_text(encoding="utf-8")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    expected_count = f"{len(families)} families and {extension_count} extensions"
    if expected_count not in formats:
        errors.append(f"docs/reference/FORMATS.md: missing registry count '{expected_count}'")
    if expected_count not in readme:
        errors.append(f"README.md: missing registry count '{expected_count}'")
    for _, extensions in families:
        for extension in extensions:
            if f"`{extension}`" not in formats:
                errors.append(
                    f"docs/reference/FORMATS.md: registered extension '{extension}' is not listed"
                )


def check_public_api_index(errors: list[str]) -> None:
    api = (ROOT / "docs/reference/API.md").read_text(encoding="utf-8")
    models = (ROOT / "docs/reference/MODELS.md").read_text(encoding="utf-8")
    declarations = api + "\n" + models
    names: set[str] = set()
    types: set[str] = set()
    for path in (ROOT / "Sources/TagLibAudioMetadata").glob("*.swift"):
        source = path.read_text(encoding="utf-8")
        for match in re.finditer(r"public\s+nonisolated\s+static\s+func\s+(\w+)", source):
            names.add(match.group(1))
        for match in re.finditer(r"public\s+(?:final\s+)?(?:struct|enum|class)\s+(\w+)", source):
            types.add(match.group(1))
    for name in sorted(names):
        if f"`{name}" not in declarations and f"{name}(" not in declarations:
            errors.append(f"docs/reference/API.md: public manager function '{name}' is not indexed")
    for name in sorted(types):
        if f"`{name}`" not in declarations:
            errors.append(f"docs/reference/MODELS.md: public type '{name}' is not indexed")


def check_bridge_index(errors: list[str]) -> None:
    header = (ROOT / "Sources/CTagLibBridge/include/TagLibMetadataExtractor.h").read_text(
        encoding="utf-8"
    )
    bridge = (ROOT / "docs/reference/BRIDGE.md").read_text(encoding="utf-8")
    for match in re.finditer(
        r"\+\s*\([^)]*\)\s*(\w+)((?:\s*:\s*\([^)]*\)\s*\w+)*)", header
    ):
        name = match.group(1)
        if name not in bridge:
            errors.append(f"docs/reference/BRIDGE.md: bridge selector '{name}' is not indexed")
    for match in re.finditer(r"NS_SWIFT_NAME\(([^)]*)\)", header):
        name = match.group(1).split("(")[0].rstrip(":")
        if name and name not in bridge:
            errors.append(f"docs/reference/BRIDGE.md: Swift bridge name '{name}' is not indexed")
    for block in re.finditer(
        r"typedef\s+NS_(?:ENUM|OPTIONS)\([^)]*\)\s*\{([^}]*)\}\s*(\w+);",
        header,
        re.S,
    ):
        body, type_name = block.groups()
        if type_name not in bridge:
            errors.append(f"docs/reference/BRIDGE.md: bridge type '{type_name}' is not indexed")
        for case_name in re.findall(r"(\w+)\s*=", body):
            if case_name not in bridge:
                errors.append(
                    f"docs/reference/BRIDGE.md: bridge constant '{case_name}' is not indexed"
                )
    for name in re.findall(r"FOUNDATION_EXPORT\s+NSErrorDomain\s+const\s+(\w+)", header):
        if name not in bridge:
            errors.append(f"docs/reference/BRIDGE.md: bridge constant '{name}' is not indexed")

def check_retired_paths(errors: list[str]) -> None:
    # Retired paths are rejected when they appear as Markdown link targets in
    # check_links(). Prose mentions stay legal in historical records.
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
    check_generated_pages(errors)
    check_formats(errors)
    check_public_api_index(errors)
    check_bridge_index(errors)
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
