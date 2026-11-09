#!/usr/bin/env python3
"""Render the executable native mapping catalog as a reference matrix.

``Sources/TagLibAudioMetadata/MetadataMappingCatalog.swift`` is the package's
declarative source of truth for semantic-to-native targets. This script reads
that Swift table and writes ``docs/reference/MAPPING_MATRIX.md``. No Markdown
is ever converted back into production code.

Usage:
    python3 scripts/generate-mapping-matrix.py --write
    python3 scripts/generate-mapping-matrix.py --check
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Sources/TagLibAudioMetadata/MetadataMappingCatalog.swift"
DOCUMENT = ROOT / "docs/reference/MAPPING_MATRIX.md"

FAMILIES = (
    ("id3v23", "ID3v2.3"),
    ("id3v24", "ID3v2.4"),
    ("mp4", "MP4"),
    ("vorbisComment", "Vorbis"),
    ("apev2", "APE"),
    ("asf", "ASF"),
    ("riffInfo", "RIFF"),
    ("matroska", "Matroska"),
)


def unescape(value: str) -> str:
    return re.sub(
        r"\\u\{([0-9A-Fa-f]+)\}",
        lambda match: chr(int(match.group(1), 16)),
        value,
    )


def parse_catalog() -> tuple[str, str, list[dict[str, object]]]:
    text = CATALOG.read_text(encoding="utf-8")
    version = re.search(r'contractVersion\s*=\s*"([^"]+)"', text)
    decision = re.search(r'decisionDate\s*=\s*"([^"]+)"', text)
    profiles: list[dict[str, object]] = []
    for block in re.findall(r"MetadataTargetProfile\((.*?)\n        \),", text, re.S):
        semantic_match = re.search(r'semanticKey:\s*"((?:[^"\\]|\\.)*)"', block)
        shape_match = re.search(r"shape:\s*\.(\w+)", block)
        if not semantic_match or not shape_match:
            continue
        reason_match = re.search(
            r'writeUnsupportedReason:\s*"((?:[^"\\]|\\.)*)"', block
        )
        targets: dict[str, list[dict[str, object]]] = {}
        for target_match in re.finditer(
            r"MetadataNativeTarget\(family: \.(\w+), storage: \.(\w+), "
            r'nativeIdentity: "((?:[^"\\]|\\.)*)"(.*?)\)',
            block,
            re.S,
        ):
            family, storage, identity, tail = target_match.groups()
            component_match = re.search(r"numberComponent: \.(\w+)", tail)
            targets.setdefault(family, []).append(
                {
                    "storage": storage,
                    "identity": unescape(identity),
                    "component": component_match.group(1) if component_match else "",
                    "preferred": "preferredWrite: true" in tail,
                }
            )
        profiles.append(
            {
                "semantic": unescape(semantic_match.group(1)),
                "shape": shape_match.group(1),
                "reason": unescape(reason_match.group(1)) if reason_match else None,
                "targets": targets,
            }
        )
    return (
        version.group(1) if version else "unknown",
        decision.group(1) if decision else "unknown",
        profiles,
    )


def render_target(target: dict[str, object]) -> str:
    storage = str(target["storage"])
    identity = str(target["identity"])
    component = str(target["component"])
    if storage == "userTextFrame":
        text = f"TXXX({identity})"
    elif storage == "extensionFrame":
        text = f"EXT({identity})"
    elif storage == "engineTextKey":
        text = f"{identity} (engine)"
    elif storage == "identifierFrame":
        text = f"UFID({identity})"
    elif storage == "qualifiedTextFrame":
        text = f"{identity} (qualified)"
    elif storage == "roleFrame":
        text = f"{identity} (roles)"
    elif storage == "binaryFrame":
        text = identity
    elif storage == "mp4Freeform":
        text = f"F({identity})"
    elif storage == "complexProperty":
        text = identity
    elif storage == "matroskaSimpleTag":
        text = identity.replace("@TargetTypeValue=", "@")
    else:
        text = identity
    if component:
        text = f"{text}#{component}"
    if not target["preferred"]:
        text = f"{text} (read)"
    else:
        text = f"**{text}**"
    return text


def render_matrix(profiles: list[dict[str, object]]) -> str:
    lines = [
        "## Matrix",
        "",
        "**Bold** marks the preferred typed-write target for that family. `(read)` ",
        "marks a registration that is readable but is not a typed write destination. ",
        "`#number` and `#total` identify components of one shared native pair. ",
        "`TXXX(...)` is an ID3v2 user-text description, `EXT(...)` is a registered ",
        "extension frame, `F(...)` is an exact MP4 freeform description, and ",
        "`@...` is a Matroska `TargetTypeValue`.",
        "",
        "| Semantic key | Shape | "
        + " | ".join(title for _, title in FAMILIES)
        + " |",
        "| --- | --- | " + " | ".join("---" for _ in FAMILIES) + " |",
    ]
    for profile in sorted(profiles, key=lambda value: str(value["semantic"])):
        targets = profile["targets"]  # type: ignore[assignment]
        cells = []
        for family, _ in FAMILIES:
            family_targets = targets.get(family, [])  # type: ignore[union-attr]
            cells.append(
                "<br>".join(render_target(target) for target in family_targets)
                if family_targets
                else "—"
            )
        key = str(profile["semantic"])
        if key == "<explicit key>":
            key = "`<explicit key>`"
        else:
            key = f"`{key}`"
        lines.append(
            f"| {key} | `{profile['shape']}` | " + " | ".join(cells) + " |"
        )
    return "\n".join(lines)


def render() -> str:
    version, decision, profiles = parse_catalog()
    family_counts: Counter[str] = Counter()
    preferred_counts: Counter[str] = Counter()
    for profile in profiles:
        for family, targets in profile["targets"].items():  # type: ignore[union-attr]
            family_counts[family] += len(targets)
            preferred_counts[family] += sum(
                1 for target in targets if target["preferred"]
            )
    read_only = [
        str(profile["semantic"])
        for profile in profiles
        if profile["reason"]
    ]
    lines = [
        "# Native mapping matrix",
        "",
        "<!-- Generated by scripts/generate-mapping-matrix.py from MetadataMappingCatalog.swift. Do not edit by hand. -->",
        "",
        f"Contract `{version}` (decision date `{decision}`). The table is generated ",
        "from the executable `MetadataMappingCatalog` target table; the Swift catalog ",
        "is the package-side source of truth for semantic-to-native targets.",
        "",
        f"`{len(profiles)}` semantic profiles; "
        f"`{sum(len(profile['targets']) for profile in profiles)}` native target registrations "
        f"(`{sum(preferred_counts.values())}` preferred write targets).",
        "",
        "| Family | Targets | Preferred write targets |",
        "| --- | --- | --- |",
    ]
    for family, title in FAMILIES:
        lines.append(
            f"| {title} | {family_counts.get(family, 0)} | {preferred_counts.get(family, 0)} |"
        )
    if read_only:
        lines.extend(
            [
                "",
                "Typed writes are withheld for: "
                + ", ".join(f"`{value}`" for value in read_only)
                + ".",
            ]
        )
    lines.extend(
        [
            "",
            "`.date` is a legacy spelling of the `YEAR` profile and `.year` is the ",
            "canonical YEAR identity; both map to the same native targets. The ",
            "catalog itself stores one `YEAR` profile.",
            "",
            render_matrix(profiles),
            "",
            "## How to use this table",
            "",
            "The matrix describes declared native targets, not per-file success. ",
            "A target can be read-only, unavailable for a particular tag version, or ",
            "normalized by the container. Query `FormatCapability` for declared ",
            "support and `probeFile(at:)` for a concrete file. See ",
            "[Formats](FORMATS.md), [Field reference](FIELDS.md), and ",
            "[Mapping contract](MAPPING_SPEC.md).",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()

    expected = render()
    if args.write:
        DOCUMENT.write_text(expected, encoding="utf-8")
        print(f"Updated {DOCUMENT.relative_to(ROOT)}.")
        return 0
    if args.check:
        if not DOCUMENT.exists() or DOCUMENT.read_text(encoding="utf-8") != expected:
            print(
                f"{DOCUMENT.relative_to(ROOT)} is stale. Run "
                "python3 scripts/generate-mapping-matrix.py --write",
                file=sys.stderr,
            )
            return 1
        print("Mapping matrix matches MetadataMappingCatalog.swift.")
        return 0
    print(expected, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
