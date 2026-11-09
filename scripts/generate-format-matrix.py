#!/usr/bin/env python3
"""Render the declared format capability matrix from the bridge sources.

The matrix in ``docs/reference/FORMATS.md`` is generated from
``Sources/CTagLibBridge/TLFormatRegistry.mm`` (descriptors and extension
aliases), ``TLMetadataCore.inc`` (container masks and writable formats), and
``TLRawInspection.inc`` (evidence levels and field allowlists). The registry is
the source of truth; the documentation table is a derived view.

Usage:
    python3 scripts/generate-format-matrix.py --write
    python3 scripts/generate-format-matrix.py --check
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = ROOT / "Sources/CTagLibBridge/TLFormatRegistry.mm"
CORE = ROOT / "Sources/CTagLibBridge/Internal/TLMetadataCore.inc"
INSPECTION = ROOT / "Sources/CTagLibBridge/Internal/TLRawInspection.inc"
DOCUMENT = ROOT / "docs/reference/FORMATS.md"

BEGIN = "<!-- BEGIN GENERATED FORMAT MATRIX -->"
END = "<!-- END GENERATED FORMAT MATRIX -->"

CONTAINER_NAMES = {
    "TLMetadataContainerTag": "tag",
    "TLMetadataContainerPropertyMap": "propertyMap",
    "TLMetadataContainerID3v1": "id3v1",
    "TLMetadataContainerID3v2": "id3v2",
    "TLMetadataContainerAPE": "ape",
    "TLMetadataContainerMP4ItemMap": "mp4",
    "TLMetadataContainerXiph": "xiph",
    "TLMetadataContainerASF": "asf",
    "TLMetadataContainerRIFFInfo": "riffInfo",
}


def parse_extension_tables(text: str) -> dict[str, list[str]]:
    tables: dict[str, list[str]] = {}
    for name, body in re.findall(
        r"const char \*?(k\w+Extensions)\[\] = \{([^}]*)\};", text
    ):
        tables[name] = re.findall(r'"([^"]+)"', body)
    return tables


def parse_descriptors(text: str) -> list[dict[str, object]]:
    tables = parse_extension_tables(text)
    block = text.split("const TLFormatCapabilityDescriptor kDescriptors[] = {", 1)[1].split(
        "};", 1
    )[0]
    descriptors: list[dict[str, object]] = []
    for line in block.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        tokens = re.findall(r'"(?:[^"\\]|\\.)*"|\bnullptr\b|\btrue\b|\bfalse\b|TL\w+|k\w+', line)
        if len(tokens) < 12:
            continue
        format_name = tokens[0]
        extensions_key = tokens[4]
        if extensions_key not in tables:
            continue
        descriptors.append(
            {
                "format": format_name,
                "identifier": tokens[1].strip('"'),
                "display_name": tokens[2].strip('"'),
                "codec_name": tokens[3].strip('"'),
                "extensions": tables[extensions_key],
                "structured_read": tokens[5].strip('"'),
                "structured_write": tokens[6].strip('"'),
                "can_read_artwork": tokens[7] == "true",
                "can_write_artwork": tokens[8] == "true",
                "preserves_multi_value": tokens[9] == "true",
                "read_only_reason": None
                if tokens[10] == "nullptr"
                else tokens[10].strip('"'),
                "notes": None if tokens[11] == "nullptr" else tokens[11].strip('"'),
            }
        )
    return descriptors


def parse_container_masks(text: str) -> dict[str, list[str]]:
    block = text.split("static TLMetadataContainerMask ContainerMaskForFormat", 1)[
        1
    ].split("\n}", 1)[0]
    masks: dict[str, list[str]] = {}
    pending: list[str] = []
    terms: list[str] = []
    collecting = False
    for line in block.splitlines():
        stripped = line.strip()
        case_match = re.match(r"case (TLTagFileFormat\w+):", stripped)
        if case_match:
            pending.append(case_match.group(1))
            continue
        if "return " in stripped:
            collecting = True
            terms = re.findall(r"TLMetadataContainer\w+", stripped)
        elif collecting and stripped.startswith("|"):
            terms.extend(re.findall(r"TLMetadataContainer\w+", stripped))
        if collecting and ";" in stripped:
            ordered = [CONTAINER_NAMES[name] for name in terms if name in CONTAINER_NAMES]
            for format_name in pending:
                masks[format_name] = ordered
            pending = []
            terms = []
            collecting = False
    return masks

def parse_writable_formats(text: str) -> set[str]:
    block = text.split("static bool IsWritableTagFileFormat", 1)[1].split("\n}", 1)[0]
    writable: set[str] = set()
    for line in block.splitlines():
        case_match = re.search(r"case (TLTagFileFormat\w+):", line)
        if case_match:
            writable.add(case_match.group(1))
    # The switch returns false for the listed formats and true for the default.
    return writable


def parse_fixture_extensions(text: str) -> set[str]:
    match = re.search(r"fixtureCoveredExtensions = \[NSSet setWithArray:@\[(.*?)\]\]", text, re.S)
    return set(re.findall(r'@"([^"]+)"', match.group(1))) if match else set()


def parse_support_levels(text: str) -> tuple[set[str], set[str], set[str]]:
    fixtures = parse_fixture_extensions(text)
    read_only = set(re.findall(r"TLTagFileFormat(Shorten|MOD)", text))
    experimental = set(re.findall(r"case TLTagFileFormat(S3M|IT):", text))
    return fixtures, read_only, experimental


def parse_field_allowlists(text: str) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    def parse_function(name: str) -> dict[str, list[str]]:
        block = text.split(f"static NSArray<NSString *> * _Nullable {name}", 1)[1].split(
            "\n}", 1
        )[0]
        result: dict[str, list[str]] = {}
        pending: list[str] = []
        for line in block.splitlines():
            case_match = re.search(r"case (TLTagFileFormat\w+):", line)
            if case_match:
                pending.append(case_match.group(1))
                continue
            return_match = re.search(r"return @\[(.*?)\];", line)
            if return_match and pending:
                fields = re.findall(r'@"([^"]+)"', return_match.group(1))
                for format_name in pending:
                    result[format_name] = fields
                pending = []
        return result

    return parse_function("ExplicitReadableFieldsForFormat"), parse_function(
        "ExplicitWritableFieldsForFormat"
    )


def primary_support_level(
    descriptor: dict[str, object],
    fixtures: set[str],
    read_only: set[str],
    experimental: set[str],
) -> str:
    extension = str(descriptor["extensions"][0])
    if extension in fixtures:
        return "fixtureCovered"
    format_short = str(descriptor["format"]).replace("TLTagFileFormat", "")
    if format_short in read_only:
        return "readOnly"
    if format_short in experimental:
        return "experimental"
    return "upstreamSupported"


def escape(value: str) -> str:
    return value.replace("|", "\\|")


def render() -> str:
    registry = REGISTRY.read_text(encoding="utf-8")
    core = CORE.read_text(encoding="utf-8")
    inspection = INSPECTION.read_text(encoding="utf-8")
    descriptors = parse_descriptors(registry)
    masks = parse_container_masks(core)
    non_writable = parse_writable_formats(core)
    fixtures, read_only_formats, experimental_formats = parse_support_levels(inspection)
    readable_allowlists, writable_allowlists = parse_field_allowlists(inspection)

    lines = [
        BEGIN,
        "<!-- Generated from TLFormatRegistry.mm, TLMetadataCore.inc, and TLRawInspection.inc. -->",
        "",
    ]
    extension_count = sum(len(descriptor["extensions"]) for descriptor in descriptors)
    levels = Counter()
    rendered_rows: list[str] = []
    for descriptor in descriptors:
        writable = str(descriptor["format"]) not in non_writable
        level = primary_support_level(
            descriptor, fixtures, read_only_formats, experimental_formats
        )
        levels[level] += 1
        containers = masks.get(str(descriptor["format"]), [])
        readable_fields = readable_allowlists.get(str(descriptor["format"]))
        writable_fields = writable_allowlists.get(str(descriptor["format"]))
        notes = descriptor["notes"] or descriptor["read_only_reason"] or ""
        if readable_fields is not None:
            notes = (
                f"Read allowlist: {', '.join(readable_fields)}. "
                + (f"Write allowlist: {', '.join(writable_fields or [])}. " if writable else "")
                + notes
            ).strip()
        elif writable_fields is not None:
            notes = f"Write allowlist: {', '.join(writable_fields)}. {notes}".strip()
        structured = (
            f"{descriptor['structured_read']} / {descriptor['structured_write']}"
            if writable
            else f"{descriptor['structured_read']} / none"
        )
        extensions = ", ".join(f"`{value}`" for value in descriptor["extensions"])
        rw = "R/W" if writable else "read-only"
        artwork = (
            ("R/W" if descriptor["can_read_artwork"] and descriptor["can_write_artwork"] and writable else "R")
            if descriptor["can_read_artwork"] or descriptor["can_write_artwork"]
            else "—"
        )
        rendered_rows.append(
            f"| {escape(str(descriptor['display_name']))} (`{descriptor['identifier']}`) | "
            f"{extensions} | {rw} | {', '.join(containers) or '—'} | {structured} | "
            f"{level} | {artwork} | {escape(str(notes)) or '—'} |"
        )
    lines.extend(
        [
            f"The registry contains {len(descriptors)} families and {extension_count} extensions. "
            "R/W means a declared save path exists; it does not promise every metadata surface "
            "or every file layout. Artwork R/W is independent of non-artwork structured support.",
            "",
            "| Evidence level | Families |",
            "| --- | --- |",
        ]
    )
    for level in ("fixtureCovered", "experimental", "upstreamSupported", "readOnly"):
        if levels.get(level):
            lines.append(f"| `{level}` | {levels[level]} |")
    lines.extend(
        [
            "",
            "| Family (identifier) | Extensions | R/W | Declared containers | Structured read/write | Primary evidence | Artwork | Notes |",
            "| --- | --- | --- | --- | --- | --- | --- | --- |",
            *rendered_rows,
            END,
        ]
    )
    return "\n".join(lines)


def replace_section(text: str, section: str) -> str:
    if BEGIN not in text or END not in text:
        raise ValueError(f"{DOCUMENT} is missing the generated-matrix markers")
    prefix, remainder = text.split(BEGIN, 1)
    _, suffix = remainder.split(END, 1)
    return prefix + section + suffix


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()

    section = render()
    text = DOCUMENT.read_text(encoding="utf-8")
    expected = replace_section(text, section)
    if args.write:
        DOCUMENT.write_text(expected, encoding="utf-8")
        print(f"Updated {DOCUMENT.relative_to(ROOT)}.")
        return 0
    if args.check:
        if expected != text:
            print(
                f"{DOCUMENT.relative_to(ROOT)} is stale. Run "
                "python3 scripts/generate-format-matrix.py --write",
                file=sys.stderr,
            )
            return 1
        print("Format matrix matches the bridge registry.")
        return 0
    print(section)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
