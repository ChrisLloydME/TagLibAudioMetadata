#!/usr/bin/env python3
"""Render the normative AM-TLAM-MAPPING-2.2 target matrix as Swift source.

The specification in ``docs/METADATA_MAPPING_SPEC.md`` is the normative
contract.  This development-time tool extracts the explicit per-format matrix,
the MP4-exclusive table and the gated MKV registrations into a plain Swift
value table.  Production code never parses Markdown; it only consumes the
checked-in generated file.

Usage:
    python3 scripts/generate-mapping-registry.py --write
    python3 scripts/generate-mapping-registry.py --check
    python3 scripts/generate-mapping-registry.py          # print
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "docs/METADATA_MAPPING_SPEC.md"
OUTPUT = ROOT / "Sources/TagLibAudioMetadata/MetadataMappingCatalog.swift"

HEADER = """//
//  MetadataMappingCatalog.swift
//  TagLibAudioMetadata
//
//  Generated from docs/METADATA_MAPPING_SPEC.md by
//  scripts/generate-mapping-registry.py. Do not edit by hand.
//

import Foundation

public enum MetadataMappingCatalog {
    /// The mapping contract this catalog implements, independent of the
    /// package release version.
    public static let contractVersion = "AM-TLAM-MAPPING-2.2"
    public static let decisionDate = "2026-11-09"

    public static let profiles: [MetadataTargetProfile] = [
"""

FOOTER = """    ]

    private static let bySemanticKey: [String: MetadataTargetProfile] =
        Dictionary(uniqueKeysWithValues: profiles.map { ($0.semanticKey, $0) })

    public static func profile(forSemanticKey key: String) -> MetadataTargetProfile? {
        bySemanticKey[key.uppercased()]
    }

    /// Every semantic key with an explicit registration, sorted for stable
    /// coverage reporting.
    public static let semanticKeys: [String] =
        profiles.map(\\.semanticKey).sorted()
}
"""

FAMILIES = ["id3v23", "id3v24", "mp4", "vorbisComment", "apev2", "asf", "riffInfo"]


def cell(raw: str) -> str:
    value = raw.strip()
    if value.startswith("`") and value.endswith("`"):
        value = value[1:-1]
    return value.strip()


def parse_core_matrix() -> list[dict[str, object]]:
    text = SPEC.read_text(encoding="utf-8")
    block = text.split("| Existing/new case | Semantic key; shape |", 1)[1].split("\n\n", 1)[0]
    entries: list[dict[str, object]] = []
    for line in block.splitlines():
        if not line.startswith("| `"):
            continue
        cells = [cell(part) for part in line.strip().strip("|").split("|")]
        if len(cells) != 9:
            raise ValueError(f"Unexpected matrix row: {line[:60]}")
        key = cells[0].replace(" (new)", "").strip()
        semantic, _, shape_text = cells[1].partition(";")
        semantic = semantic.strip().strip("`")
        if semantic.startswith("PICTURE ("):
            semantic = "PICTURE"
        shape = infer_shape(shape_text.strip(), semantic)
        targets = []
        for family, raw in zip(FAMILIES, cells[2:]):
            targets.extend(parse_cell(family, raw, semantic, key, shape))
        entries.append(
            {
                "case": key,
                "semantic": semantic,
                "shape": shape,
                "targets": targets,
                "reason": None,
            }
        )
    return entries


def infer_shape(text: str, semantic: str) -> str:
    text = text.lower()
    if "picture" in text or "artwork" in text:
        return "pictureCollection"
    if "advisory enum" in text:
        return "advisory"
    if "boolean" in text:
        return "boolean"
    if "integer" in text:
        return "integer"
    if "role/person" in text:
        return "roleText"
    if "text[]" in text or "identifier[]" in text:
        return "textArray"
    if "date" in text and "time" in text:
        return "text"
    return "text"


def parse_cell(family: str, raw: str, semantic: str, case: str, shape: str) -> list[dict[str, object]]:
    """Translate one matrix cell into zero or more native targets."""
    if raw == "—" or not raw:
        return []
    component = None
    if raw.startswith("PAIR(") and raw.endswith(")"):
        inner = raw[5:-1]
        component = "number" if case in {"track", "disc", "movementNumber"} else "total"
        raw = inner
    if raw.startswith("EXT(") and raw.endswith(")"):
        inner = raw[4:-1]
        if inner.startswith("F(") and inner.endswith(")"):
            return [
                target(family, "mp4Freeform", inner[2:-1], shape, True, component,
                       note="explicit conventional extension")
            ]
        if family in {"vorbisComment", "apev2"}:
            return [target(family, "textKey", inner, shape, True, component)]
        return [
            target(family, "extensionTextKey", inner, shape, True, component,
                   note="explicit registered text extension")
        ]
    if raw.startswith("EXTFRAME(") and raw.endswith(")"):
        return [target(family, "extensionFrame", raw[9:-1], shape, True, component,
                       note="version-extension frame")]
    if raw.startswith("TXXX(") and raw.endswith(")"):
        return [target(family, "userTextFrame", raw[5:-1], shape, True, component)]
    if raw.startswith("UFID(") and raw.endswith(")"):
        return [target(family, "identifierFrame", raw[5:-1], shape, True, component)]
    if raw.startswith("F(") and raw.endswith(")"):
        return [target(family, "mp4Freeform", raw[2:-1], shape, True, component)]
    if raw.startswith("TDAT"):
        return [target(family, "textFrame", "TDAT", shape, True, component,
                       note="legacy DDMM text")]
    if family.startswith("id3v2"):
        if raw in {"APIC", "PIC"}:
            return [target(family, "binaryFrame", raw, "pictureCollection", True, None)]
        if raw.startswith("USLT"):
            return [target(family, "qualifiedTextFrame", "USLT", shape, True, None,
                           note="entry identity includes language and description")]
        if raw.startswith("COMM"):
            return [target(family, "qualifiedTextFrame", "COMM", shape, True, None,
                           note="entry identity includes language and description")]
        if raw.startswith("TMCL") or raw.startswith("TIPL") or raw.startswith("IPLS"):
            return [target(family, "roleFrame", raw.split()[0], shape, True, None,
                           note="shared role collection")]
        if re.fullmatch(r"[A-Z0-9]{4}", raw):
            return [target(family, "textFrame", raw, shape, True, component)]
        return [target(family, "engineTextKey", raw, shape, True, component,
                       note="engine text mapping")]
    if family == "mp4":
        if raw in {"trkn", "disk"}:
            return [target(family, "intPair", raw, "intPair", True, component)]
        if raw in {"cpil", "pgap", "hdvd", "shwm"}:
            return [target(family, "mp4Integer", raw, "boolean", True, component)]
        if raw in {"rtng"}:
            return [target(family, "mp4Integer", raw, "advisory", True, component)]
        if raw in {"tmpo", "tves", "tvsn", "plID", "atID", "cnID", "cmID", "geID", "sfID", "stik", "rate"}:
            return [target(family, "mp4Integer", raw, shape, True, component)]
        if raw == "covr":
            return [target(family, "mp4Atom", raw, "pictureCollection", True, None)]
        if raw == "apID" or raw == "ownr":
            return [target(family, "mp4Atom", raw, "text", True, component)]
        return [target(family, "mp4Atom", raw, shape, True, component)]
    if family == "vorbisComment":
        if raw.startswith("PICTURE"):
            return [target(family, "complexProperty", "PICTURE", "pictureCollection", True, None)]
        return [target(family, "textKey", raw, shape, True, component)]
    if family == "apev2":
        if raw.startswith("COVER ART"):
            return [target(family, "complexProperty", "COVER ART", "pictureCollection", True, None)]
        return [target(family, "textKey", raw, shape, True, component)]
    if family == "asf":
        if raw.startswith("WM/Picture"):
            return [target(family, "asfAttribute", "WM/Picture", "pictureCollection", True, None)]
        return [target(family, "asfAttribute", raw, shape, True, component)]
    if family == "riffInfo":
        if raw in {"ICRD", "ITRK", "INAM", "IART", "IPRD", "ICMT", "IGNR", "IMUS", "ICOP", "ILNG"}:
            return [target(family, "riffInfoKey", raw, shape, True, component)]
        return [target(family, "engineTextKey", raw, shape, True, component)]
    raise ValueError(f"Unsupported family {family}")


def target(
    family: str,
    storage: str,
    identity: str,
    shape: str,
    preferred: bool,
    component: str | None,
    note: str | None = None,
) -> dict[str, object]:
    return {
        "family": family,
        "storage": storage,
        "identity": identity,
        "shape": shape,
        "preferred": preferred,
        "component": component,
        "note": note,
    }


# semantic, native identity, shape, writable, number component, reason
MP4_EXCLUSIVE = {
    "DIRECTOR": ("director", "©dir", "textArray", True, None, None),
    "ITUNESACCOUNT": ("itunesAccount", "apID", "text", True, None, None),
    "ITUNESADVISORY": ("ITUNESADVISORY", "rtng", "advisory", True, None, None),
    "ITUNESALBUMID": ("itunesAlbumID", "plID", "integer", True, None, None),
    "ITUNESARTISTID": ("itunesArtistID", "atID", "integer", True, None, None),
    "ITUNESCATALOGID": ("itunesCatalogID", "cnID", "integer", True, None, None),
    "ITUNESCOMPOSERID": ("itunesComposerID", "cmID", "integer", True, None, None),
    "ITUNESCOUNTRYID": ("itunesCountryID", "sfID", "integer", True, None, None),
    "ITUNESGAPLESS": ("itunesGapless", "pgap", "boolean", True, None, None),
    "ITUNESGENREID": ("itunesGenreID", "geID", "integer", True, None, None),
    "ITUNESHDVIDEO": ("itunesHDVideo", "hdvd", "boolean", True, None, None),
    "ITUNESMEDIATYPE": ("itunesMediaType", "stik", "integer", True, None, None),
    "ITUNESOWNER": ("OWNER", "ownr", "text", True, None, None),
    "ITUNESPURCHASEDATE": ("itunesPurchaseDate", "purd", "text", True, None, None),
    "RATE": ("rate", "rate", "integer", False, None,
             "no verified native rating type or scale in this profile"),
    "SHOWMOVEMENT": ("showMovement", "shwm", "boolean", True, None, None),
    "STOREDESCRIPTION": ("storeDescription", "sdes", "text", True, None, None),
    "TOTALDISCS": ("discTotal", "disk", "integer", True, "total", None),
    "TOTALTRACKS": ("trackTotal", "trkn", "integer", True, "total", None),
    "TVEPISODE": ("tvEpisode", "tves", "integer", True, None, None),
    "TVEPISODEID": ("tvEpisodeID", "tven", "text", True, None, None),
    "TVNETWORK": ("tvNetwork", "tvnn", "text", True, None, None),
    "TVSEASON": ("tvSeason", "tvsn", "integer", True, None, None),
    "TVSHOW": ("tvShow", "tvsh", "text", True, None, None),
    "TVSHOWSORT": ("SHOWSORT", "sosn", "text", True, None, None),
    "WORK": ("work", "©wrk", "text", True, None, None),
}

SEMANTIC_KEYS = {
    "title": "TITLE",
    "artist": "ARTIST",
    "album": "ALBUM",
    "albumArtist": "ALBUMARTIST",
    "date": "YEAR",
    "standaloneDate": "DATE",
    "releaseDate": "RELEASEDATE",
    "originalReleaseDate": "ORIGINALDATE",
    "track": "TRACKNUMBER",
    "trackTotal": "TRACKTOTAL",
    "disc": "DISCNUMBER",
    "discTotal": "DISCTOTAL",
    "artwork": "PICTURE",
    "lyrics": "LYRICS",
    "comment": "COMMENT",
    "genre": "GENRE",
    "composer": "COMPOSER",
    "conductor": "CONDUCTOR",
    "remixer": "REMIXER",
    "performer": "PERFORMER",
    "producer": "PRODUCER",
    "engineer": "ENGINEER",
    "lyricist": "LYRICIST",
    "involvedPeople": "INVOLVEDPEOPLE",
    "musicianCredits": "MUSICIANCREDITS",
    "publisher": "LABEL",
    "copyright": "COPYRIGHT",
    "encodedBy": "ENCODEDBY",
    "encoderSettings": "ENCODING",
    "isrc": "ISRC",
    "barcode": "BARCODE",
    "catalogNumber": "CATALOGNUMBER",
    "asin": "ASIN",
    "releaseType": "RELEASETYPE",
    "releaseStatus": "RELEASESTATUS",
    "releaseCountry": "RELEASECOUNTRY",
    "mediaType": "MEDIA",
    "work": "WORK",
    "movement": "MOVEMENTNAME",
    "movementNumber": "MOVEMENTNUMBER",
    "movementCount": "MOVEMENTCOUNT",
    "discSubtitle": "DISCSUBTITLE",
    "subtitle": "SUBTITLE",
    "grouping": "GROUPING",
    "mood": "MOOD",
    "language": "LANGUAGE",
    "musicalKey": "INITIALKEY",
    "bpm": "BPM",
    "compilation": "COMPILATION",
    "explicitContent": "ITUNESADVISORY",
    "sortTitle": "TITLESORT",
    "sortArtist": "ARTISTSORT",
    "sortAlbum": "ALBUMSORT",
    "sortAlbumArtist": "ALBUMARTISTSORT",
    "sortComposer": "COMPOSERSORT",
    "musicBrainzArtistID": "MUSICBRAINZ_ARTISTID",
    "musicBrainzAlbumID": "MUSICBRAINZ_ALBUMID",
    "musicBrainzAlbumArtistID": "MUSICBRAINZ_ALBUMARTISTID",
    "musicBrainzTrackID": "MUSICBRAINZ_TRACKID",
    "musicBrainzReleaseGroupID": "MUSICBRAINZ_RELEASEGROUPID",
    "musicBrainzReleaseTrackID": "MUSICBRAINZ_RELEASETRACKID",
    "musicBrainzWorkID": "MUSICBRAINZ_WORKID",
    "acoustID": "ACOUSTID_ID",
    "acoustIDFingerprint": "ACOUSTID_FINGERPRINT",
    "musicIPPUID": "MUSICIP_PUID",
    "replayGainTrackGain": "REPLAYGAIN_TRACK_GAIN",
    "replayGainAlbumGain": "REPLAYGAIN_ALBUM_GAIN",
    "itunesAlbumID": "ITUNESALBUMID",
    "itunesArtistID": "ITUNESARTISTID",
    "itunesCatalogID": "ITUNESCATALOGID",
    "itunesGenreID": "ITUNESGENREID",
    "itunesMediaType": "ITUNESMEDIATYPE",
    "itunesPurchaseDate": "ITUNESPURCHASEDATE",
    "itunesNorm": "ITUNNORM",
    "itunesSMPB": "ITUNSMPB",
    "originalAlbum": "ORIGINALALBUM",
    "originalArtist": "ORIGINALARTIST",
    "artistType": "MUSICBRAINZ_ARTISTTYPE",
    "trackerName": "TRACKERNAME",
    "custom": "<explicit key>",
    "contentGroup": "CONTENTGROUP",
    "artists": "ARTISTS",
    "replayGainTrackPeak": "REPLAYGAIN_TRACK_PEAK",
    "replayGainAlbumPeak": "REPLAYGAIN_ALBUM_PEAK",
    "year": "YEAR",
    "director": "DIRECTOR",
    "itunesAccount": "ITUNESACCOUNT",
    "itunesComposerID": "ITUNESCOMPOSERID",
    "itunesCountryID": "ITUNESCOUNTRYID",
    "itunesGapless": "ITUNESGAPLESS",
    "itunesHDVideo": "ITUNESHDVIDEO",
    "itunesOwner": "ITUNESOWNER",
    "rate": "RATE",
    "showMovement": "SHOWMOVEMENT",
    "storeDescription": "STOREDESCRIPTION",
    "tvEpisode": "TVEPISODE",
    "tvEpisodeID": "TVEPISODEID",
    "tvNetwork": "TVNETWORK",
    "tvSeason": "TVSEASON",
    "tvShow": "TVSHOW",
    "tvShowSort": "TVSHOWSORT",
}


def merge_exclusive(entries: list[dict[str, object]]) -> None:
    by_semantic = {str(entry["semantic"]): entry for entry in entries}
    for field, (semantic, atom, shape, writable, component, reason) in MP4_EXCLUSIVE.items():
        entry = by_semantic.get(semantic.upper())
        if entry is None:
            entry = {
                "case": field.lower(),
                "semantic": semantic.upper(),
                "shape": shape,
                "targets": [],
                "reason": reason,
            }
            entries.append(entry)
            by_semantic[semantic.upper()] = entry
        # The exclusive table is the sole preferred MP4 write location.
        filtered = [
            target_
            for target_ in entry["targets"]  # type: ignore[union-attr]
            if not (target_["family"] == "mp4" and target_["preferred"])
        ]
        filtered.append(
            target("mp4", "mp4Integer" if shape in {"integer", "boolean", "advisory"} else "mp4Atom",
                   atom, shape, writable, component if component in {"total", "number"} else None,
                   note=reason)
        )
        entry["targets"] = filtered
        if reason:
            entry["reason"] = reason


def add_mkv(entries: list[dict[str, object]]) -> None:
    by_semantic = {str(entry["semantic"]): entry for entry in entries}
    for semantic, level in (("TVEPISODE", "50"), ("TVSEASON", "60")):
        entry = by_semantic[semantic]
        entry["targets"].append(  # type: ignore[union-attr]
            target(
                "matroska",
                "matroskaSimpleTag",
                f"PART_NUMBER@TargetTypeValue={level}",
                "integer",
                False,
                None,
                note="target registration only; native implementation pending",
            )
        )


def add_year_alias(entries: list[dict[str, object]]) -> None:
    by_semantic = {str(entry["semantic"]): entry for entry in entries}
    year = by_semantic["YEAR"]
    entries.append(
        {
            "case": "year",
            "semantic": "YEAR",
            "shape": "text",
            "targets": [dict(t) for t in year["targets"]],  # type: ignore[index]
            "reason": None,
            "canonicalOwner": True,
        }
    )


def swift_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def render() -> str:
    entries = parse_core_matrix()
    merge_exclusive(entries)
    add_mkv(entries)

    lines = [HEADER]
    for entry in entries:
        lines.append("        MetadataTargetProfile(")
        lines.append(f"            semanticKey: {swift_string(str(entry['semantic']))},")
        lines.append(f"            shape: .{entry['shape']},")
        lines.append("            targets: [")
        for target_ in entry["targets"]:  # type: ignore[union-attr]
            args = [
                f"family: .{target_['family']}",
                f"storage: .{target_['storage']}",
                f"nativeIdentity: {swift_string(str(target_['identity']))}",
                f"shape: .{target_['shape']}",
                f"preferredWrite: {'true' if target_['preferred'] else 'false'}",
            ]
            if target_["component"]:
                args.append(f"numberComponent: .{target_['component']}")
            if target_["note"]:
                args.append(f"note: {swift_string(str(target_['note']))}")
            lines.append("                MetadataNativeTarget(" + ", ".join(args) + "),")
        lines.append("            ],")
        if entry["reason"]:
            lines.append(f"            writeUnsupportedReason: {swift_string(str(entry['reason']))}")
        lines.append("        ),")
    lines.append(FOOTER)
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = render()
    if args.write:
        OUTPUT.write_text(rendered + "\n", encoding="utf-8")
        print(f"Wrote {OUTPUT.relative_to(ROOT)}")
        return 0
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != rendered + "\n":
            print("MetadataMappingCatalog.swift is stale; run --write", file=sys.stderr)
            return 1
        print("MetadataMappingCatalog.swift is up to date")
        return 0
    print(rendered)
    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main())
