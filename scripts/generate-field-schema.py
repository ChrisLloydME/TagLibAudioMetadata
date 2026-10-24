#!/usr/bin/env python3
"""Render the public metadata field registry into docs/FIELD_SCHEMA.md.

The registry lives in Sources/TagLibAudioMetadata/MetadataFieldSchema.swift.
This script is a documentation aid, not a source generator: it reads the
declarative table and emits the human-readable tables between the markers in
the document. The Swift source remains authoritative.

Usage:
    python3 scripts/generate-field-schema.py --write
    python3 scripts/generate-field-schema.py --check
    python3 scripts/generate-field-schema.py          # print the section
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Sources/TagLibAudioMetadata/MetadataFieldSchema.swift"
DOCUMENT = ROOT / "docs/FIELD_SCHEMA.md"
BEGIN = "<!-- BEGIN GENERATED FIELD TABLES -->"
END = "<!-- END GENERATED FIELD TABLES -->"

CATEGORY_ORDER = (
    "basic",
    "numbering",
    "dates",
    "people",
    "peopleRoles",
    "lyricsAndComments",
    "artwork",
    "sorting",
    "identifiers",
    "release",
    "technical",
    "replayGain",
    "itunes",
    "custom",
)

CATEGORY_TITLES = {
    "basic": "Basic and descriptive",
    "numbering": "Numbering",
    "dates": "Dates",
    "people": "People",
    "peopleRoles": "Role-qualified people",
    "lyricsAndComments": "Lyrics and comments",
    "artwork": "Artwork",
    "sorting": "Sorting",
    "identifiers": "Identifiers",
    "release": "Release",
    "technical": "Technical",
    "replayGain": "ReplayGain",
    "itunes": "iTunes",
    "custom": "Custom",
}


def unescape(value: str) -> str:
    return re.sub(r"\\u\{([0-9A-Fa-f]+)\}", lambda match: chr(int(match.group(1), 16)), value)


def quoted_values(text: str) -> list[str]:
    return [unescape(value) for value in re.findall(r'"((?:[^"\\]|\\.)*)"', text)]


def named_array(text: str, name: str) -> list[str]:
    match = re.search(rf"{name}:\s*\[", text)
    if not match:
        return []
    start = match.end()
    depth = 1
    index = start
    while index < len(text) and depth:
        if text[index] == "[":
            depth += 1
        elif text[index] == "]":
            depth -= 1
        index += 1
    return quoted_values(text[start : index - 1])


def balanced_entries(block: str) -> list[str]:
    entries: list[str] = []
    index = 0
    while index < len(block):
        match = re.search(r"(schema\(|MetadataFieldSchema\()", block[index:])
        if not match:
            break
        start = index + match.start()
        cursor = start
        depth = 0
        while cursor < len(block):
            if block[cursor] == "(":
                depth += 1
            elif block[cursor] == ")":
                depth -= 1
                if depth == 0:
                    cursor += 1
                    break
            cursor += 1
        entries.append(block[start:cursor])
        index = cursor
    return entries


def parse_fields() -> list[dict[str, object]]:
    source = SOURCE.read_text(encoding="utf-8")
    block = source.split("public nonisolated static let allSchemas", 1)[1].split(
        "public nonisolated static let schemasByKey", 1
    )[0]
    fields: list[dict[str, object]] = []
    for entry in balanced_entries(block):
        if entry.startswith("schema("):
            match = re.match(
                r'schema\(\.(\w+),\s*"((?:[^"\\]|\\.)*)",\s*\.(\w+),\s*\[',
                entry,
            )
            if not match:
                raise ValueError(f"Could not parse schema entry: {entry[:80]}")
            key, display, category = match.groups()
            start = entry.index("[", match.end() - 1) + 1
            depth = 1
            cursor = start
            while depth:
                if entry[cursor] == "[":
                    depth += 1
                elif entry[cursor] == "]":
                    depth -= 1
                cursor += 1
            property_keys = quoted_values(entry[start : cursor - 1])
            field = {
                "key": key,
                "display": unescape(display),
                "category": category,
                "property_keys": property_keys,
                "id3": named_array(entry, "id3"),
                "id3_user": named_array(entry, "id3User"),
                "mp4": named_array(entry, "mp4"),
                "mp4_freeform": named_array(entry, "mp4Freeform"),
                "multi": bool(re.search(r"\bmulti:\s*true", entry)),
                "people": bool(re.search(r"\bpeople:\s*true", entry)),
                "role": bool(re.search(r"\brole:\s*true", entry)),
                "artwork": key == "artwork",
            }
        else:
            key = re.search(r"key:\s*\.(\w+)", entry).group(1)
            display = unescape(re.search(r'displayName:\s*"((?:[^"\\]|\\.)*)"', entry).group(1))
            category = re.search(r"category:\s*\.(\w+)", entry).group(1)
            field = {
                "key": key,
                "display": display,
                "category": category,
                "property_keys": named_array(entry, "propertyMapKeys"),
                "id3": [],
                "id3_user": [],
                "mp4": [],
                "mp4_freeform": [],
                "multi": False,
                "people": False,
                "role": False,
                "artwork": "isArtworkField: true" in entry,
            }
        fields.append(field)
    return fields


def code_list(values: list[str]) -> str:
    return ", ".join(f"`{value}`" for value in values) if values else "—"


def render_field_table(field: dict[str, object]) -> list[str]:
    id3 = list(field["id3"])  # type: ignore[arg-type]
    id3.extend(f"TXXX:{value}" for value in field["id3_user"])  # type: ignore[arg-type]
    mp4 = list(field["mp4"])  # type: ignore[arg-type]
    mp4.extend(
        f"----:com.apple.iTunes:{value}" for value in field["mp4_freeform"]  # type: ignore[arg-type]
    )
    if field["key"] == "artwork":
        id3 = ["APIC"]
        mp4 = ["covr"]
    flags = []
    if field["multi"]:
        flags.append("multi")
    if field["people"]:
        flags.append("people")
    if field["role"]:
        flags.append("role")
    if field["artwork"]:
        flags.append("artwork")
    return [
        f"| `{field['key']}` | {field['display']} | {code_list(field['property_keys'])} | "
        f"{code_list(id3)} | {code_list(mp4)} | {', '.join(flags) or '—'} |"
    ]


def render() -> str:
    fields = parse_fields()
    by_category: "OrderedDict[str, list[dict[str, object]]]" = OrderedDict(
        (category, []) for category in CATEGORY_ORDER
    )
    for field in fields:
        by_category.setdefault(str(field["category"]), []).append(field)

    lines = [
        BEGIN,
        f"<!-- Generated from `MetadataFieldSchema.swift`. {len(fields)} fields. -->",
        "",
    ]
    for category, category_fields in by_category.items():
        if not category_fields:
            continue
        lines.append(f"### {CATEGORY_TITLES.get(category, category)}")
        lines.append("")
        lines.append(
            "| Key | Display name | PropertyMap keys | ID3v2 | MP4 | Flags |"
        )
        lines.append("| --- | --- | --- | --- | --- | --- |")
        for field in category_fields:
            lines.extend(render_field_table(field))
        lines.append("")
    lines.append(END)
    return "\n".join(lines)


def replace_section(text: str, section: str) -> str:
    if BEGIN not in text or END not in text:
        raise ValueError(f"{DOCUMENT} is missing the generated-table markers")
    prefix, remainder = text.split(BEGIN, 1)
    _, suffix = remainder.split(END, 1)
    return prefix + section + suffix


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--write", action="store_true", help="update docs/FIELD_SCHEMA.md")
    group.add_argument("--check", action="store_true", help="fail if the document is stale")
    args = parser.parse_args()

    section = render()
    if args.write:
        text = DOCUMENT.read_text(encoding="utf-8")
        DOCUMENT.write_text(replace_section(text, section), encoding="utf-8")
        print(f"Updated {DOCUMENT.relative_to(ROOT)}.")
        return 0
    if args.check:
        text = DOCUMENT.read_text(encoding="utf-8")
        if replace_section(text, section) != text:
            print(
                "docs/FIELD_SCHEMA.md is stale. Run "
                "python3 scripts/generate-field-schema.py --write",
                file=sys.stderr,
            )
            return 1
        print("Field schema tables match MetadataFieldSchema.swift.")
        return 0
    print(section)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
