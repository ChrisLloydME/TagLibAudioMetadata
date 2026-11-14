#!/usr/bin/env python3
"""Render the metadata field registry into docs/reference/FIELDS.md.

The Swift sources are authoritative:

* ``MetadataFieldSchema.swift`` declares the public field keys, categories,
  PropertyMap aliases, and typed-patch policy;
* ``MetadataMappingCatalog.swift`` declares the exact native targets.

The script reads those files and rewrites three marked sections in the reference
page: the registry summary, the per-category native tables, and the typed-patch
contract table. Run with ``--check`` in CI and ``--write`` after a source change.

Usage:
    python3 scripts/generate-field-schema.py --write
    python3 scripts/generate-field-schema.py --check
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Sources/TagLibAudioMetadata/MetadataFieldSchema.swift"
CATALOG = ROOT / "Sources/TagLibAudioMetadata/MetadataMappingCatalog.swift"
DOCUMENT = ROOT / "docs/reference/FIELDS.md"

SUMMARY_BEGIN = "<!-- BEGIN GENERATED FIELD SUMMARY -->"
SUMMARY_END = "<!-- END GENERATED FIELD SUMMARY -->"
TABLES_BEGIN = "<!-- BEGIN GENERATED FIELD TABLES -->"
TABLES_END = "<!-- END GENERATED FIELD TABLES -->"
PATCH_BEGIN = "<!-- BEGIN GENERATED PATCH CONTRACT -->"
PATCH_END = "<!-- END GENERATED PATCH CONTRACT -->"

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

CATALOG_FAMILIES = (
    "id3v23",
    "id3v24",
    "mp4",
    "vorbisComment",
    "apev2",
    "asf",
    "riffInfo",
)

SEMANTIC_OVERRIDES = {
    "year": "YEAR",
    "standaloneDate": "DATE",
    "publisher": "LABEL",
    "encoderSettings": "ENCODING",
    "mediaType": "MEDIA",
    "movement": "MOVEMENTNAME",
    "explicitContent": "ITUNESADVISORY",
    "itunesOwner": "OWNER",
    "tvShowSort": "SHOWSORT",
    "custom": "<explicit key>",
}


def unescape(value: str) -> str:
    return re.sub(
        r"\\u\{([0-9A-Fa-f]+)\}",
        lambda match: chr(int(match.group(1), 16)),
        value,
    )


def quoted_values(text: str) -> list[str]:
    return [unescape(value) for value in re.findall(r'"((?:[^"\\]|\\.)*)"', text)]


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
                "multi": bool(re.search(r"\bmulti:\s*true", entry)),
                "people": bool(re.search(r"\bpeople:\s*true", entry)),
                "role": bool(re.search(r"\brole:\s*true", entry)),
                "artwork": key == "artwork",
                "canonical": True,
                "write_unsupported_reason": None,
            }
        else:
            key_match = re.search(r"key:\s*\.(\w+)", entry)
            display_match = re.search(r'displayName:\s*"((?:[^"\\]|\\.)*)"', entry)
            category_match = re.search(r"category:\s*\.(\w+)", entry)
            if not key_match or not display_match or not category_match:
                raise ValueError(f"Could not parse field entry: {entry[:80]}")
            field = {
                "key": key_match.group(1),
                "display": unescape(display_match.group(1)),
                "category": category_match.group(1),
                "property_keys": named_array(entry, "propertyMapKeys"),
                "multi": bool(re.search(r"\bisMultiValue:\s*true", entry)),
                "people": bool(re.search(r"\bisPeopleField:\s*true", entry)),
                "role": bool(re.search(r"\bisRoleQualified:\s*true", entry)),
                "artwork": bool(re.search(r"\bisArtworkField:\s*true", entry)),
                "canonical": not bool(
                    re.search(r"\bisCanonicalSemanticOwner:\s*false", entry)
                ),
                "write_unsupported_reason": None,
            }
        fields.append(field)
    return fields


def parse_catalog_profiles() -> dict[str, dict[str, object]]:
    text = CATALOG.read_text(encoding="utf-8")
    profiles: dict[str, dict[str, object]] = {}
    for block in re.findall(r"MetadataTargetProfile\((.*?)\n        \),", text, re.S):
        semantic_match = re.search(r'semanticKey:\s*"((?:[^"\\]|\\.)*)"', block)
        if not semantic_match:
            continue
        semantic = unescape(semantic_match.group(1))
        targets: dict[str, list[dict[str, str]]] = {
            family: [] for family in CATALOG_FAMILIES
        }
        for target_match in re.finditer(
            r"MetadataNativeTarget\(family: \.(\w+), storage: \.(\w+), "
            r'nativeIdentity: "((?:[^"\\]|\\.)*)"(.*?)\)',
            block,
            re.S,
        ):
            family, storage, identity, tail = target_match.groups()
            component_match = re.search(r"numberComponent: \.(\w+)", tail)
            preferred = "preferredWrite: true" in tail
            targets.setdefault(family, []).append(
                {
                    "storage": storage,
                    "identity": unescape(identity),
                    "component": component_match.group(1) if component_match else "",
                    "preferred": preferred,
                }
            )
        reason_match = re.search(
            r'writeUnsupportedReason:\s*"((?:[^"\\]|\\.)*)"', block
        )
        profiles[semantic.upper()] = {
            "targets": targets,
            "reason": unescape(reason_match.group(1)) if reason_match else None,
        }
    return profiles


def semantic_key(field: dict[str, object]) -> str:
    key = str(field["key"])
    if key in SEMANTIC_OVERRIDES:
        return SEMANTIC_OVERRIDES[key]
    property_keys = list(field["property_keys"])  # type: ignore[arg-type]
    return property_keys[0].upper() if property_keys else key.upper()


def native_cell(targets: list[dict[str, str]]) -> str:
    if not targets:
        return "—"
    rendered: list[str] = []
    for target in targets:
        identity = target["identity"]
        storage = target["storage"]
        if storage == "mp4Freeform":
            identity = f"----:com.apple.iTunes:{identity}"
        elif storage == "userTextFrame":
            identity = f"TXXX:{identity}"
        elif storage == "extensionFrame":
            identity = f"EXTFRAME:{identity}"
        elif storage == "identifierFrame":
            identity = f"UFID:{identity}"
        elif storage == "engineTextKey":
            identity = f"{identity} (engine)"
        if target["component"]:
            identity = f"{identity} ({target['component']})"
        if not target["preferred"]:
            identity = f"{identity} (read)"
        rendered.append(f"`{identity}`")
    return ", ".join(rendered)


def code_list(values: list[str]) -> str:
    return ", ".join(f"`{value}`" for value in values) if values else "—"


def render_field_table(
    field: dict[str, object], profiles: dict[str, dict[str, object]]
) -> list[str]:
    semantic = semantic_key(field)
    profile = profiles.get(semantic.upper(), {})
    targets = profile.get("targets", {})
    flags: list[str] = []
    if field["multi"]:
        flags.append("multi")
    if field["people"]:
        flags.append("people")
    if field["role"]:
        flags.append("role")
    if field["artwork"]:
        flags.append("artwork")
    if not field["canonical"]:
        flags.append("legacy alias")
    return [
        f"| `{field['key']}` | {field['display']} | `{semantic}` | "
        f"{code_list(list(field['property_keys']))} | "
        f"{native_cell(targets.get('id3v23', []))} | "
        f"{native_cell(targets.get('id3v24', []))} | "
        f"{native_cell(targets.get('mp4', []))} | "
        f"{native_cell(targets.get('vorbisComment', []))} | "
        f"{native_cell(targets.get('apev2', []))} | "
        f"{native_cell(targets.get('asf', []))} | "
        f"{native_cell(targets.get('riffInfo', []))} | "
        f"{', '.join(flags) or '—'} |"
    ]


def parse_shared_owners() -> tuple[dict[str, list[str]], dict[str, str]]:
    text = SOURCE.read_text(encoding="utf-8")
    owners: dict[str, list[str]] = {}
    preferred: dict[str, str] = {}
    block_match = re.search(
        r"sharedPropertyMapKeyOwners:[^=]*=\s*\[(.*?)\n    \]", text, re.S
    )
    if block_match:
        for key, cases in re.findall(r'"([^"]+)":\s*\[([^\]]*)\]', block_match.group(1)):
            owners[key] = re.findall(r"\.(\w+)", cases)
    preferred_match = re.search(
        r"preferredSharedPropertyMapKeyOwner:[^=]*=\s*\[(.*?)\n    \]", text, re.S
    )
    if preferred_match:
        for key, case in re.findall(r'"([^"]+)":\s*\.(\w+)', preferred_match.group(1)):
            preferred[key] = case
    return owners, preferred


def parse_patch_policy(fields: list[dict[str, object]]) -> list[dict[str, object]]:
    text = SOURCE.read_text(encoding="utf-8")
    multi = {str(field["key"]): bool(field["multi"]) for field in fields}
    kinds: dict[str, list[str]] = {}
    default_kinds = ["text"]
    kinds_block = text.split("public var acceptedPatchValueKinds", 1)[1].split(
        "public var integerConstraint", 1
    )[0]
    for case_text, value_text in re.findall(
        r"case\s+([^:]+):\s*(.*?)(?=\n\s*case\s|\n\s*default:|\Z)", kinds_block, re.S
    ):
        keys = re.findall(r"\.(\w+)", case_text)
        values = re.findall(r"\.(text|integer|boolean|values)\b", value_text)
        for key in keys:
            kinds[key] = values
    default_match = re.search(
        r"default:\s*(.+?)(?=\n\s*\})", kinds_block, re.S
    )
    if default_match and "isMultiValue" in default_match.group(1):
        default_kinds = ["text", "values"]

    constraints: dict[str, tuple[str, str]] = {}
    constraint_block = text.split("public var integerConstraint", 1)[1].split(
        "public init(", 1
    )[0]
    for case_text, value_text in re.findall(
        r"case\s+([^:]+):\s*(.*?)(?=\n\s*case\s|\n\s*default:|\Z)",
        constraint_block,
        re.S,
    ):
        keys = re.findall(r"\.(\w+)", case_text)
        minimum = re.search(r"minimum:\s*([^,\n]+)", value_text)
        maximum = re.search(r"maximum:\s*([^,\n]+)", value_text)
        if minimum and maximum:
            for key in keys:
                constraints[key] = (minimum.group(1).strip(), maximum.group(1).strip())

    result: list[dict[str, object]] = []
    for field in fields:
        key = str(field["key"])
        accepted = kinds.get(key)
        if accepted is None:
            accepted = list(default_kinds) if multi.get(key) else [default_kinds[0]]
        minimum, maximum = constraints.get(key, ("", ""))
        minimum = minimum.strip()
        maximum = maximum.strip()
        if minimum.count("(") < minimum.count(")"):
            minimum = minimum[:-1]
        if maximum.count("(") < maximum.count(")"):
            maximum = maximum[:-1]
        if minimum == "Int(Int32.max)":
            minimum = "Int32.max"
        if maximum == "Int(Int32.max)":
            maximum = "Int32.max"
        if maximum == "Int(UInt32.max)":
            maximum = "UInt32.max"
        result.append(
            {
                "key": key,
                "kinds": accepted,
                "minimum": minimum,
                "maximum": maximum,
            }
        )
    return result


def render_summary(
    fields: list[dict[str, object]],
    profiles: dict[str, dict[str, object]],
) -> str:
    canonical = [field for field in fields if field["canonical"]]
    aliases = [field for field in fields if not field["canonical"]]
    owners, preferred = parse_shared_owners()
    category_counts: "OrderedDict[str, int]" = OrderedDict(
        (category, 0) for category in CATEGORY_ORDER
    )
    for field in fields:
        category_counts[str(field["category"])] = (
            category_counts.get(str(field["category"]), 0) + 1
        )
    categories = ", ".join(
        f"{CATEGORY_TITLES.get(category, category)} ({count})"
        for category, count in category_counts.items()
        if count
    )
    shared = "; ".join(
        f"{key} → {', '.join('.' + case for case in cases)}"
        + (
            f" (preferred `. {preferred[key]}`)".replace(". ", ".")
            if key in preferred
            else ""
        )
        for key, cases in owners.items()
    )
    unsupported = [
        f".{field['key']} — {profiles.get(semantic_key(field).upper(), {}).get('reason')}"
        for field in fields
        if profiles.get(semantic_key(field), {}).get("reason")
    ]
    lines = [
        SUMMARY_BEGIN,
        f"**{len(fields)} fields** are declared in {len(category_counts)} categories: {categories}.",
        "",
        f"{len(canonical)} canonical semantic "
        f"{'owner' if len(canonical) == 1 else 'owners'} and {len(aliases)} legacy "
        f"{'alias' if len(aliases) == 1 else 'aliases'} "
        f"({', '.join('.' + str(field['key']) for field in aliases) or 'none'}). "
        "The tables below are generated from the Swift registry and catalog; do not "
        "edit them by hand.",
    ]
    if shared:
        lines.extend(["", f"Shared PropertyMap keys: {shared}."])
    if unsupported:
        lines.extend(
            [
                "",
                "Typed writes are withheld for: "
                + "; ".join(unsupported)
                + ".",
            ]
        )
    lines.extend([SUMMARY_END, ""])
    return "\n".join(lines)


def render_tables(
    fields: list[dict[str, object]], profiles: dict[str, dict[str, object]]
) -> str:
    by_category: "OrderedDict[str, list[dict[str, object]]]" = OrderedDict(
        (category, []) for category in CATEGORY_ORDER
    )
    for field in fields:
        by_category.setdefault(str(field["category"]), []).append(field)

    lines = [
        TABLES_BEGIN,
        f"<!-- Generated from MetadataFieldSchema.swift and MetadataMappingCatalog.swift. {len(fields)} fields. -->",
        "",
    ]
    for category, category_fields in by_category.items():
        if not category_fields:
            continue
        lines.extend(
            [
                f"### {CATEGORY_TITLES.get(category, category)}",
                "",
                "| Key | Display name | Semantic key | PropertyMap keys | ID3v2.3 | ID3v2.4 | MP4 | Vorbis | APE | ASF | RIFF | Flags |",
                "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
            ]
        )
        for field in category_fields:
            lines.extend(render_field_table(field, profiles))
        lines.append("")
    lines.append(TABLES_END)
    return "\n".join(lines)


def render_patch_contract(
    fields: list[dict[str, object]],
    profiles: dict[str, dict[str, object]],
) -> str:
    policy = parse_patch_policy(fields)
    by_key = {str(field["key"]): field for field in fields}
    lines = [
        PATCH_BEGIN,
        "| Field | Accepted `.MetadataPatchValue` kinds | Numeric range | Typed-write note |",
        "| --- | --- | --- | --- |",
    ]
    for entry in policy:
        key = str(entry["key"])
        field = by_key[key]
        kinds = ", ".join(f"`.{kind}`" for kind in entry["kinds"]) or "none"
        if entry["minimum"] and entry["maximum"]:
            numeric = f"`{entry['minimum']}...{entry['maximum']}`"
        else:
            numeric = "—"
        notes: list[str] = []
        if field["role"]:
            notes.append("role-qualified: typed patch rejects; use raw/structured")
        reason = profiles.get(semantic_key(field).upper(), {}).get("reason")
        if reason:
            notes.append(f"typed write withheld: {reason}")
        if field["artwork"]:
            notes.append("use `MetadataPatch.artwork`")
        if key == "explicitContent":
            notes.append("use `MetadataPatch.explicitAdvisory`")
        if field["key"] == "custom":
            notes.append("use `MetadataPatch.customFields`")
        lines.append(
            f"| `.{key}` | {kinds} | {numeric} | {'; '.join(notes) or '—'} |"
        )
    lines.extend(
        [
            "",
            "`.remove` is accepted by every field that passes the kind check; it is "
            "not a value kind. Empty text and empty arrays are validation errors, "
            "not deletion aliases.",
            PATCH_END,
        ]
    )
    return "\n".join(lines)


def replace_marked(text: str, begin: str, end: str, section: str) -> str:
    if begin not in text or end not in text:
        raise ValueError(f"{DOCUMENT} is missing the markers {begin!r} and {end!r}")
    prefix, remainder = text.split(begin, 1)
    _, suffix = remainder.split(end, 1)
    return prefix + section + "\n" + suffix.lstrip("\n")


def rendered_document() -> str:
    text = DOCUMENT.read_text(encoding="utf-8")
    fields = parse_fields()
    profiles = parse_catalog_profiles()
    text = replace_marked(text, SUMMARY_BEGIN, SUMMARY_END, render_summary(fields, profiles))
    text = replace_marked(text, TABLES_BEGIN, TABLES_END, render_tables(fields, profiles))
    text = replace_marked(
        text, PATCH_BEGIN, PATCH_END, render_patch_contract(fields, profiles)
    )
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--write", action="store_true", help="rewrite the reference page")
    group.add_argument("--check", action="store_true", help="fail if the page is stale")
    args = parser.parse_args()

    expected = rendered_document()
    if args.write:
        DOCUMENT.write_text(expected, encoding="utf-8")
        print(f"Updated {DOCUMENT.relative_to(ROOT)}.")
        return 0
    if args.check:
        actual = DOCUMENT.read_text(encoding="utf-8")
        if actual != expected:
            print(
                f"{DOCUMENT.relative_to(ROOT)} is stale. Run "
                "python3 scripts/generate-field-schema.py --write",
                file=sys.stderr,
            )
            return 1
        print("Field reference matches MetadataFieldSchema.swift and the mapping catalog.")
        return 0
    print(expected)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
