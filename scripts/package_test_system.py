"""Schema and reconciliation checks for the package-owned contract test system.

Production declarations are only used to *enumerate claims* that must be
reconciled with the reviewed inventories. This module never derives expected
native ownership, expected success or golden values from production metadata.
"""

from __future__ import annotations

import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SYSTEM_DIR = Path(__file__).with_name("package-test-system")

SURFACE_PATH = SYSTEM_DIR / "public-surface-inventory.json"
CATALOG_PATH = SYSTEM_DIR / "contract-catalog.json"
FIXTURE_PATH = SYSTEM_DIR / "fixture-catalog.json"
ADAPTER_PATH = SYSTEM_DIR / "execution-adapters.json"
FIELD_CLAIMS_PATH = SYSTEM_DIR / "field-schema-claims.json"
FORMAT_CLAIMS_PATH = SYSTEM_DIR / "format-capability-claims.json"
SCENARIO_DECLARATIONS_PATH = (
    ROOT / "Tests/TagLibAudioMetadataTests/ContractSystem/ContractScenarioDeclarations.swift"
)
ADAPTER_SOURCE_PATH = (
    ROOT / "Tests/TagLibAudioMetadataTests/ContractSystem/PublicSurfaceAdapters.swift"
)
TEST_INVENTORY_PATH = ROOT / "scripts/required-test-inventory.json"

SCHEMA_VERSION = 1
SURFACE_DECISIONS = {
    "exercised",
    "read_only",
    "compile_only",
    "rejection",
    "model",
    "unverified",
}
OUTCOMES = {
    "supported",
    "read_only_reject",
    "unsupported_reject",
    "unverified",
}
EVIDENCE_TIERS = {"runtime", "compile_only", "documented_limitation"}
PARTITIONS = {
    "encoding_family",
    "numeric_boundary",
    "input_representation",
    "preservation",
    "concrete_version",
    "sequence",
    "validation_execution",
    "transaction",
    "read_registry",
    "batch",
}

# These are the mandatory format families from the upgrade plan. A family can
# be listed as unverified, but then the catalog row must carry a concrete
# reason and the completion report must repeat it.
MANDATORY_FORMAT_FAMILIES = {
    "mp4",
    "id3v24",
    "id3v23",
    "wav",
    "aiff",
    "flac",
    "ogg-vorbis",
    "ogg-opus",
    "ape",
    "wavpack",
    "asf",
    "tracker",
}

# Every encoding family the public model can express. The catalog must contain
# at least one row for each, either runtime exercised or explicitly limited.
MANDATORY_ENCODING_FAMILIES = {
    "text",
    "array",
    "bool",
    "byte",
    "signed_integer",
    "unsigned_integer",
    "int_pair",
    "identifier",
    "artwork",
    "qualified_collection",
}


class InventoryError(Exception):
    """Raised when an inventory cannot be parsed or reconciled."""


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise InventoryError(f"cannot load {path.relative_to(ROOT)}: {error}") from error


def _api_parser():
    spec = importlib.util.spec_from_file_location(
        "swift_api_inventory", Path(__file__).with_name("generate-api-reference.py")
    )
    parser = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(parser)
    return parser


def normalize_signature(text: str) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"\s*,\s*", ", ", text)
    return text


def swift_surface_key(container: str, kind: str, header: str) -> str:
    return f"swift:{container}:{kind}:{normalize_signature(header)}"


def extract_swift_surfaces(root: Path) -> dict[str, dict]:
    """Enumerate public Swift declarations with stable, source-normalized keys."""
    parser = _api_parser()
    parser.SOURCE_DIR = (Path(root) / "Sources/TagLibAudioMetadata").resolve()
    surfaces: dict[str, dict] = {}
    for path in sorted(parser.SOURCE_DIR.rglob("*.swift")):
        for item in parser.SwiftFileParser(path).parse():
            kind = str(item["kind"])
            if kind == "extension":
                # Extensions are declaration containers, not independently
                # callable public entry points; their members are inventoried.
                continue
            container = str(item["container"])
            header = normalize_signature(str(item["header"]))
            key = swift_surface_key(container, kind, header)
            record = {
                "key": key,
                "module": "swift",
                "owner": container,
                "kind": kind,
                "signature": header,
                "path": str(item["path"]),
                "line": int(item["line"]),
                "modifiers": str(item["mods"]).strip(),
            }
            if key in surfaces:
                raise InventoryError(
                    f"ambiguous public Swift declaration key {key!r} at "
                    f"{record['path']}:{record['line']} and "
                    f"{surfaces[key]['path']}:{surfaces[key]['line']}"
                )
            surfaces[key] = record
    return surfaces


def _strip_comments(text: str) -> str:
    out: list[str] = []
    index = 0
    while index < len(text):
        if text.startswith("//", index):
            end = text.find("\n", index)
            index = len(text) if end < 0 else end
        elif text.startswith("/*", index):
            end = text.find("*/", index + 2)
            index = len(text) if end < 0 else end + 2
        elif text[index] == '"':
            end = index + 1
            while end < len(text):
                if text[end] == "\\":
                    end += 2
                elif text[end] == '"':
                    end += 1
                    break
                else:
                    end += 1
            out.append(text[index:end])
            index = end
        else:
            out.append(text[index])
            index += 1
    return "".join(out)


def extract_bridge_surfaces(root: Path) -> dict[str, dict]:
    """Enumerate the exported Objective-C header only.

    Package-internal in-place selectors live in a separate header and are not
    public entry points, so they are deliberately outside this inventory.
    """
    header = Path(root) / "Sources/CTagLibBridge/include/TagLibMetadataExtractor.h"
    text = _strip_comments(header.read_text(encoding="utf-8"))
    surfaces: dict[str, dict] = {}
    consumed: list[tuple[int, int]] = []

    def add(key: str, kind: str, owner: str, signature: str, offset: int) -> None:
        if key in surfaces:
            previous = surfaces[key]
            raise InventoryError(
                f"ambiguous exported bridge declaration key {key!r} at offsets "
                f"{previous['offset']} and {offset}"
            )
        surfaces[key] = {
            "key": key,
            "module": "bridge",
            "owner": owner,
            "kind": kind,
            "signature": normalize_signature(signature),
            "path": header.relative_to(root).as_posix(),
            "line": text.count("\n", 0, offset) + 1,
            "offset": offset,
        }

    interface_re = re.compile(r"@interface\s+([A-Za-z_]\w*)\s*:(?!=)")
    end_re = re.compile(r"@end\b")
    for interface in interface_re.finditer(text):
        owner = interface.group(1)
        body_start = interface.end()
        end_match = end_re.search(text, body_start)
        body_end = end_match.start() if end_match else len(text)
        body = text[body_start:body_end]
        local_consumed: list[tuple[int, int]] = []

        for match in re.finditer(r"^\+?\s*[-+]\s*\(", body, re.MULTILINE):
            start = match.start()
            if any(a <= start < b for a, b in local_consumed):
                continue
            semicolon = body.find(";", start)
            if semicolon < 0:
                raise InventoryError(f"unterminated bridge method in {owner}")
            declaration = body[start : semicolon + 1]
            label = declaration.lstrip().split(None, 1)[0]
            kind = "class_method" if label.startswith("+") else "instance_method"
            add(
                f"bridge:{owner}:{kind}:{normalize_signature(declaration)}",
                kind,
                owner,
                declaration,
                body_start + start,
            )
            local_consumed.append((start, semicolon + 1))

        for match in re.finditer(
            r"@property\s*\(([^)]*)\)\s*([^;]+);", body, re.MULTILINE
        ):
            start = match.start()
            if any(a <= start < b for a, b in local_consumed):
                continue
            declaration = match.group(0)
            add(
                f"bridge:{owner}:property:{normalize_signature(declaration)}",
                "property",
                owner,
                declaration,
                body_start + start,
            )
            local_consumed.append((start, match.end()))

        # Anything method-shaped that the scanner did not consume is a parser
        # failure, not an excuse to silently omit an exported entry point.
        for match in re.finditer(r"^\s*[-+]\s*[A-Za-z_(]", body, re.MULTILINE):
            start = match.start()
            if not any(a <= start < b for a, b in local_consumed):
                raise InventoryError(
                    f"unrecognized exported bridge declaration in {owner}: "
                    f"{body[start:start + 80]!r}"
                )
        consumed.append((body_start, body_end))

    for match in re.finditer(r"typedef\s+NS_(ENUM|OPTIONS)\s*\(([^)]*)\)\s*\{(.*?)\}", text, re.S):
        typedef_kind = match.group(1).lower()
        enum_name = match.group(2).split(",")[-1].strip()
        body = match.group(3)
        add(
            f"bridge:{enum_name}:typedef:{typedef_kind}",
            "enum",
            enum_name,
            match.group(0),
            match.start(),
        )
        consumed.append((match.start(), match.end()))
        for case in re.finditer(r"([A-Za-z_]\w*)\s*(?:=\s*[^,}]+)?", body):
            name = case.group(1)
            if name in {"NS_ENUM", "NS_OPTIONS"}:
                continue
            add(
                f"bridge:{enum_name}:case:{name}",
                "enum_case",
                enum_name,
                name,
                match.start(3) + case.start(),
            )

    for match in re.finditer(r"FOUNDATION_EXPORT\s+[^;]+;", text):
        add(
            f"bridge:constant:{normalize_signature(match.group(0))}",
            "constant",
            "<global>",
            match.group(0),
            match.start(),
        )
        consumed.append((match.start(), match.end()))

    # Reject method-shaped declarations outside an @interface rather than
    # silently dropping them from coverage.
    for match in re.finditer(r"^\s*[-+]\s*[A-Za-z_(]", text, re.MULTILINE):
        start = match.start()
        if not any(a <= start < b for a, b in consumed):
            raise InventoryError(
                f"bridge declaration outside a recognized @interface: "
                f"{text[start:start + 80]!r}"
            )
    return surfaces


def extract_scenario_declarations(root: Path = ROOT) -> list[str]:
    path = Path(root) / "Tests/TagLibAudioMetadataTests/ContractSystem/ContractScenarioDeclarations.swift"
    if not path.exists():
        raise InventoryError(f"missing scenario declarations: {path.relative_to(root)}")
    identifiers = re.findall(r'"(S-[A-Za-z0-9][A-Za-z0-9_-]*)"', path.read_text(encoding="utf-8"))
    duplicates = sorted({item for item in identifiers if identifiers.count(item) > 1})
    if duplicates:
        raise InventoryError(f"duplicate declared scenario IDs: {duplicates}")
    return identifiers


def extract_adapter_declarations(root: Path = ROOT) -> list[str]:
    path = Path(root) / "Tests/TagLibAudioMetadataTests/ContractSystem/PublicSurfaceAdapters.swift"
    if not path.exists():
        raise InventoryError(f"missing adapter source: {path.relative_to(root)}")
    text = path.read_text(encoding="utf-8")
    block = re.search(r"enum\s+PublicSurfaceAdapterID[^{]*\{(.*?)\n\}", text, re.S)
    if not block:
        raise InventoryError("PublicSurfaceAdapterID enum is missing or unparseable")
    identifiers = re.findall(r'case\s+[A-Za-z_]\w*\s*=\s*"([^"]+)"', block.group(1))
    if not identifiers:
        # A raw-value enum is required so adapter IDs and the registry cannot
        # drift through case-identifier renames.
        identifiers = re.findall(r"case\s+([A-Za-z_]\w*)", block.group(1))
    duplicates = sorted({item for item in identifiers if identifiers.count(item) > 1})
    if duplicates:
        raise InventoryError(f"duplicate adapter declarations: {duplicates}")
    return identifiers


def _require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def _nonempty_string(value) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_surface_inventory(
    inventory: dict,
    catalog: dict,
    adapters: list[str],
    extracted_swift: dict[str, dict] | None = None,
    extracted_bridge: dict[str, dict] | None = None,
) -> list[str]:
    errors: list[str] = []
    _require(inventory.get("schema_version") == SCHEMA_VERSION, "surface inventory schema version mismatch", errors)
    rows = inventory.get("surfaces")
    _require(isinstance(rows, list) and bool(rows), "surface inventory has no rows", errors)
    if not isinstance(rows, list):
        return errors

    ids: set[str] = set()
    keys: set[str] = set()
    for row in rows:
        if not isinstance(row, dict):
            errors.append("surface row is not an object")
            continue
        surface_id = row.get("id")
        key = row.get("signature_key")
        decision = row.get("decision")
        _require(_nonempty_string(surface_id), f"surface row has no id: {row!r}", errors)
        _require(_nonempty_string(key), f"surface {surface_id!r} has no signature_key", errors)
        _require(decision in SURFACE_DECISIONS, f"surface {surface_id!r} has invalid decision {decision!r}", errors)
        if isinstance(surface_id, str):
            _require(surface_id not in ids, f"duplicate surface id: {surface_id}", errors)
            ids.add(surface_id)
        if isinstance(key, str):
            _require(key not in keys, f"duplicate surface signature_key: {key}", errors)
            keys.add(key)
        row_adapters = row.get("adapters", [])
        _require(isinstance(row_adapters, list), f"surface {surface_id!r} adapters is not a list", errors)
        for adapter in row_adapters if isinstance(row_adapters, list) else []:
            _require(adapter in adapters, f"surface {surface_id!r} names unknown adapter {adapter!r}", errors)
        contracts = row.get("catalog_contracts", [])
        _require(isinstance(contracts, list), f"surface {surface_id!r} catalog_contracts is not a list", errors)
        if decision == "exercised":
            _require(bool(row_adapters), f"exercised surface {surface_id!r} has no execution adapter", errors)
            _require(bool(contracts), f"exercised surface {surface_id!r} has no catalog contract", errors)
        if decision == "rejection":
            _require(bool(contracts), f"rejection surface {surface_id!r} has no catalog contract", errors)
        if decision == "unverified":
            _require(_nonempty_string(row.get("rationale")), f"unverified surface {surface_id!r} lacks a rationale", errors)
            _require(not row_adapters and not contracts, f"unverified surface {surface_id!r} claims execution evidence", errors)
        if decision == "compile_only":
            _require(_nonempty_string(row.get("rationale")), f"compile-only surface {surface_id!r} lacks a rationale", errors)
        name = str(row.get("signature_key", ""))
        if row.get("module") == "swift" and decision == "model":
            if row.get("kind") in {"func", "subscript"}:
                errors.append(f"callable Swift surface {surface_id!r} cannot be classified as model-only")
            if row.get("kind") in {"var", "let"} and row.get("owner") in {
                "TagLibMetadataManager", "MetadataFieldRegistry", "MetadataMappingCatalog"
            }:
                errors.append(f"public facade/registry property {surface_id!r} cannot be model-only")
        if row.get("module") == "bridge" and row.get("kind") in {"class_method", "instance_method"}:
            _require(decision != "model", f"bridge method {surface_id!r} cannot be model-only", errors)

    contracts = {
        row.get("contract_id"): row
        for row in catalog.get("contracts", [])
        if isinstance(row, dict) and isinstance(row.get("contract_id"), str)
    }
    for row in rows:
        if not isinstance(row, dict):
            continue
        for contract_id in row.get("catalog_contracts", []) or []:
            contract = contracts.get(contract_id)
            _require(contract is not None, f"surface {row.get('id')!r} references missing contract {contract_id!r}", errors)
            if contract is not None:
                _require(
                    contract.get("surface_id") == row.get("id")
                    or row.get("id") in (contract.get("surface_ids") or []),
                    f"contract {contract_id!r} surface_id does not match the owning surface {row.get('id')!r}",
                    errors,
                )

    if extracted_swift is not None:
        extracted = set(extracted_swift)
        declared = {key for key in keys if key.startswith("swift:")}
        _require(not (extracted - declared), f"unclassified public Swift declarations: {sorted(extracted - declared)}", errors)
        _require(not (declared - extracted), f"stale Swift inventory signatures: {sorted(declared - extracted)}", errors)
    if extracted_bridge is not None:
        extracted = set(extracted_bridge)
        declared = {key for key in keys if key.startswith("bridge:")}
        _require(not (extracted - declared), f"unclassified exported bridge declarations: {sorted(extracted - declared)}", errors)
        _require(not (declared - extracted), f"stale bridge inventory signatures: {sorted(declared - extracted)}", errors)
    return errors


def validate_catalog(
    catalog: dict,
    inventory: dict,
    fixtures: dict,
    field_claims: dict,
    format_claims: dict,
    adapter_ids: list[str],
    required_tests: dict | None = None,
    scenario_declarations: list[str] | None = None,
) -> list[str]:
    errors: list[str] = []
    _require(catalog.get("schema_version") == SCHEMA_VERSION, "contract catalog schema version mismatch", errors)
    contracts = catalog.get("contracts")
    _require(isinstance(contracts, list) and bool(contracts), "contract catalog has no contracts", errors)
    if not isinstance(contracts, list):
        return errors

    surfaces = {
        row.get("id"): row
        for row in inventory.get("surfaces", [])
        if isinstance(row, dict)
    }
    fixture_rows = {
        row.get("id"): row
        for row in fixtures.get("fixtures", [])
        if isinstance(row, dict)
    }
    contract_ids: set[str] = set()
    scenario_ids: set[str] = set()
    covered_formats: set[str] = set()
    covered_encodings: set[str] = set()
    covered_partitions: set[str] = set()
    exercised_surfaces: set[str] = set()
    field_keys = {
        row.get("key")
        for row in field_claims.get("fields", [])
        if isinstance(row, dict) and isinstance(row.get("key"), str)
    }
    mode_rows = {
        row.get("id"): row for row in inventory.get("modes", []) if isinstance(row, dict)
    }
    covered_modes: set[tuple[str, str]] = set()

    for contract in contracts:
        if not isinstance(contract, dict):
            errors.append("contract row is not an object")
            continue
        contract_id = contract.get("contract_id")
        _require(_nonempty_string(contract_id), f"contract has no contract_id: {contract!r}", errors)
        if isinstance(contract_id, str):
            _require(contract_id not in contract_ids, f"duplicate contract_id: {contract_id}", errors)
            contract_ids.add(contract_id)
        outcome = contract.get("outcome")
        _require(outcome in OUTCOMES, f"contract {contract_id!r} has invalid outcome {outcome!r}", errors)
        surface_ids = contract.get("surface_ids")
        _require(isinstance(surface_ids, list) and bool(surface_ids),
                 f"contract {contract_id!r} has no surface_ids", errors)
        for surface_id in surface_ids if isinstance(surface_ids, list) else []:
            surface = surfaces.get(surface_id)
            _require(surface is not None, f"contract {contract_id!r} references unknown surface {surface_id!r}", errors)
            if surface is not None:
                _require(
                    contract_id in (surface.get("catalog_contracts") or []),
                    f"contract {contract_id!r} is not listed by surface {surface_id!r}",
                    errors,
                )
                if outcome in {"supported", "read_only_reject", "unsupported_reject"}:
                    exercised_surfaces.add(surface_id)
        if isinstance(surface_ids, list) and surface_ids:
            _require(contract.get("surface_id") == surface_ids[0],
                     f"contract {contract_id!r} surface_id must be the first surface_ids entry", errors)
        adapters = contract.get("adapters")
        _require(isinstance(adapters, list), f"contract {contract_id!r} adapters is not a list", errors)
        for adapter in adapters if isinstance(adapters, list) else []:
            _require(adapter in adapter_ids, f"contract {contract_id!r} names unknown adapter {adapter!r}", errors)
        if outcome != "unverified":
            _require(bool(adapters), f"contract {contract_id!r} has no execution adapters", errors)
        fixture_id = contract.get("fixture_id")
        fixture = fixture_rows.get(fixture_id)
        _require(fixture is not None, f"contract {contract_id!r} references unknown fixture {fixture_id!r}", errors)
        partition = contract.get("partition")
        _require(partition in PARTITIONS, f"contract {contract_id!r} has invalid partition {partition!r}", errors)
        if partition in PARTITIONS:
            covered_partitions.add(partition)
        for field in contract.get("field_family", []) or []:
            _require(field == "*" or field in field_keys,
                     f"contract {contract_id!r} names unknown field {field!r}", errors)
        for fmt in contract.get("format_family", []) or []:
            covered_formats.add(fmt)
        for encoding in contract.get("encoding_families", []) or []:
            covered_encodings.add(encoding)
        _require(_nonempty_string(contract.get("oracle")), f"contract {contract_id!r} has no oracle", errors)
        _require(_nonempty_string(contract.get("normalization")), f"contract {contract_id!r} has no normalization decision", errors)
        _require(_nonempty_string(contract.get("validation_phase")), f"contract {contract_id!r} has no validation phase", errors)
        tier = contract.get("evidence_tier")
        _require(tier in EVIDENCE_TIERS, f"contract {contract_id!r} has invalid evidence tier {tier!r}", errors)

        modes = contract.get("modes", {})
        _require(isinstance(modes, dict), f"contract {contract_id!r} modes is not an object", errors)
        for mode_id, values in (modes.items() if isinstance(modes, dict) else []):
            mode = mode_rows.get(mode_id)
            _require(mode is not None, f"contract {contract_id!r} uses unknown mode {mode_id!r}", errors)
            if mode is None:
                continue
            _require(isinstance(values, list), f"contract {contract_id!r} mode {mode_id!r} values is not a list", errors)
            for value in values if isinstance(values, list) else []:
                _require(value in (mode.get("values") or []),
                         f"contract {contract_id!r} mode {mode_id!r} has unknown value {value!r}", errors)
                covered_modes.add((mode_id, value))

        runtime_test = contract.get("runtime_test")
        scenarios = contract.get("scenarios")
        if outcome == "unverified":
            _require(_nonempty_string(contract.get("limitation_reason")),
                     f"unverified contract {contract_id!r} lacks a limitation_reason", errors)
            _require(tier == "documented_limitation",
                     f"unverified contract {contract_id!r} must be documented_limitation", errors)
            _require(not adapters, f"unverified contract {contract_id!r} must not claim adapters", errors)
            _require(scenarios in (None, []), f"unverified contract {contract_id!r} must not claim runtime scenarios", errors)
            _require(runtime_test in (None, ""), f"unverified contract {contract_id!r} must not claim a runtime test", errors)
            continue

        _require(_nonempty_string(runtime_test), f"contract {contract_id!r} has no runtime test", errors)
        if required_tests is not None and isinstance(runtime_test, str):
            _require(runtime_test in required_tests,
                     f"contract {contract_id!r} runtime test {runtime_test!r} is not in the required inventory", errors)
        _require(isinstance(scenarios, list) and bool(scenarios), f"contract {contract_id!r} has no scenarios", errors)

        if outcome == "supported":
            ownership = contract.get("ownership")
            _require(isinstance(ownership, dict), f"supported contract {contract_id!r} has no ownership block", errors)
            if isinstance(ownership, dict):
                edited = ownership.get("edited")
                _require(isinstance(edited, list), f"supported contract {contract_id!r} has no edited-owner list", errors)
                if partition != "read_registry":
                    _require(isinstance(edited, list) and bool(edited),
                             f"supported write contract {contract_id!r} has no edited owners", errors)
                _require(isinstance(ownership.get("untouched"), list),
                         f"supported contract {contract_id!r} has no untouched-owner decision", errors)
                _require(ownership.get("audio") is True,
                         f"supported contract {contract_id!r} must require audio/sample comparison", errors)

        if outcome in {"read_only_reject", "unsupported_reject"}:
            rejection = contract.get("rejection")
            _require(isinstance(rejection, dict), f"rejecting contract {contract_id!r} has no rejection decision", errors)
            if isinstance(rejection, dict):
                _require(_nonempty_string(rejection.get("expected")),
                         f"rejecting contract {contract_id!r} has no expected rejection", errors)
                _require(rejection.get("unchanged_bytes") is True,
                         f"rejecting contract {contract_id!r} does not require unchanged bytes", errors)
            _require(tier == "runtime", f"rejecting contract {contract_id!r} must be runtime-tested", errors)

        for scenario in scenarios if isinstance(scenarios, list) else []:
            if not isinstance(scenario, dict):
                errors.append(f"contract {contract_id!r} has a non-object scenario")
                continue
            scenario_id = scenario.get("scenario_id")
            _require(_nonempty_string(scenario_id), f"contract {contract_id!r} has a scenario without an id", errors)
            if isinstance(scenario_id, str):
                _require(scenario_id not in scenario_ids, f"duplicate scenario_id: {scenario_id}", errors)
                scenario_ids.add(scenario_id)
            _require(
                isinstance(scenario.get("expected_assertions"), int)
                and int(scenario["expected_assertions"]) > 0,
                f"scenario {scenario_id!r} has no positive assertion budget",
                errors,
            )

    # Independent field coverage decisions, not generated from the catalog's
    # field_family annotations.
    decisions = catalog.get("field_decisions")
    _require(isinstance(decisions, list) and bool(decisions), "contract catalog has no field_decisions", errors)
    decision_fields: set[str] = set()
    for decision in decisions if isinstance(decisions, list) else []:
        if not isinstance(decision, dict):
            errors.append("field decision is not an object")
            continue
        field = decision.get("field")
        _require(_nonempty_string(field), f"field decision has no field: {decision!r}", errors)
        if isinstance(field, str):
            _require(field not in decision_fields, f"duplicate field decision: {field}", errors)
            decision_fields.add(field)
        outcome = decision.get("decision")
        _require(outcome in {"supported", "read_only", "unverified"},
                 f"field {field!r} has invalid decision {outcome!r}", errors)
        contracts_for_field = decision.get("contracts", [])
        _require(isinstance(contracts_for_field, list), f"field {field!r} contracts is not a list", errors)
        for contract_id in contracts_for_field if isinstance(contracts_for_field, list) else []:
            _require(contract_id in contract_ids,
                     f"field {field!r} references unknown contract {contract_id!r}", errors)
        existing = decision.get("existing_runtime_tests", [])
        _require(isinstance(existing, list), f"field {field!r} existing_runtime_tests is not a list", errors)
        for test in existing if isinstance(existing, list) else []:
            if required_tests is not None:
                _require(test in required_tests,
                         f"field {field!r} cites non-required test {test!r}", errors)
        if outcome == "supported":
            _require(bool(contracts_for_field) or bool(existing),
                     f"supported field {field!r} has neither a contract nor existing runtime evidence", errors)
        else:
            _require(_nonempty_string(decision.get("reason")), f"{outcome} field {field!r} lacks a reason", errors)
    _require(decision_fields == field_keys,
             f"field decision set mismatch: missing={sorted(field_keys - decision_fields)}, extra={sorted(decision_fields - field_keys)}",
             errors)

    # Audit scenarios are runtime evidence for the test system itself. They are
    # intentionally not metadata-operation contracts.
    audits = catalog.get("audit_scenarios", [])
    _require(isinstance(audits, list), "audit_scenarios is not a list", errors)
    for audit in audits if isinstance(audits, list) else []:
        if not isinstance(audit, dict):
            errors.append("audit scenario is not an object")
            continue
        scenario_id = audit.get("scenario_id")
        _require(_nonempty_string(scenario_id), f"audit scenario has no id: {audit!r}", errors)
        if isinstance(scenario_id, str):
            _require(scenario_id not in scenario_ids, f"duplicate scenario_id: {scenario_id}", errors)
            scenario_ids.add(scenario_id)
        runtime_test = audit.get("runtime_test")
        _require(_nonempty_string(runtime_test), f"audit scenario {scenario_id!r} has no runtime test", errors)
        if required_tests is not None and isinstance(runtime_test, str):
            _require(runtime_test in required_tests,
                     f"audit scenario {scenario_id!r} runtime test is not required", errors)
        _require(isinstance(audit.get("expected_assertions"), int) and int(audit["expected_assertions"]) > 0,
                 f"audit scenario {scenario_id!r} has no positive assertion budget", errors)
        _require(_nonempty_string(audit.get("purpose")), f"audit scenario {scenario_id!r} has no purpose", errors)

    if scenario_declarations is not None:
        declared = set(scenario_declarations)
        _require(not (declared - scenario_ids),
                 f"scenario declarations absent from the catalog: {sorted(declared - scenario_ids)}", errors)
        _require(not (scenario_ids - declared),
                 f"catalog scenarios absent from runtime declarations: {sorted(scenario_ids - declared)}", errors)

    # Every reviewed mode value must have at least one runtime decision.
    for mode_id, mode in mode_rows.items():
        for value in mode.get("values", []) or []:
            _require((mode_id, value) in covered_modes,
                     f"mode {mode_id!r} value {value!r} has no catalog decision", errors)

    _require(
        not (MANDATORY_ENCODING_FAMILIES - covered_encodings),
        f"encoding families without a coverage decision: {sorted(MANDATORY_ENCODING_FAMILIES - covered_encodings)}",
        errors,
    )
    _require(
        not (MANDATORY_FORMAT_FAMILIES - covered_formats),
        f"format families without a coverage decision: {sorted(MANDATORY_FORMAT_FAMILIES - covered_formats)}",
        errors,
    )
    _require(
        not (PARTITIONS - covered_partitions),
        f"partitions without a coverage decision: {sorted(PARTITIONS - covered_partitions)}",
        errors,
    )
    _require(bool(exercised_surfaces), "catalog exercises no public surface", errors)

    advertised_families = {
        capability.get("identifier")
        for capability in format_claims.get("capabilities", [])
        if isinstance(capability, dict) and capability.get("isWritable")
    }
    format_decisions = catalog.get("format_decisions")
    _require(isinstance(format_decisions, list) and bool(format_decisions),
             "contract catalog has no format_decisions", errors)
    decision_formats: set[str] = set()
    for decision in format_decisions if isinstance(format_decisions, list) else []:
        if not isinstance(decision, dict):
            errors.append("format decision is not an object")
            continue
        fmt = decision.get("format")
        _require(_nonempty_string(fmt), f"format decision has no format: {decision!r}", errors)
        if isinstance(fmt, str):
            _require(fmt not in decision_formats, f"duplicate format decision: {fmt}", errors)
            decision_formats.add(fmt)
        outcome = decision.get("decision")
        _require(outcome in {"supported", "unverified"},
                 f"format {fmt!r} has invalid decision {outcome!r}", errors)
        contracts_for_format = decision.get("contracts", [])
        _require(isinstance(contracts_for_format, list), f"format {fmt!r} contracts is not a list", errors)
        for contract_id in contracts_for_format if isinstance(contracts_for_format, list) else []:
            _require(contract_id in contract_ids,
                     f"format {fmt!r} references unknown contract {contract_id!r}", errors)
        existing = decision.get("existing_runtime_tests", [])
        _require(isinstance(existing, list), f"format {fmt!r} existing_runtime_tests is not a list", errors)
        for test in existing if isinstance(existing, list) else []:
            if required_tests is not None:
                _require(test in required_tests,
                         f"format {fmt!r} cites non-required test {test!r}", errors)
        if outcome == "supported":
            _require(bool(contracts_for_format) or bool(existing),
                     f"supported format {fmt!r} has neither a contract nor existing runtime evidence", errors)
        else:
            _require(_nonempty_string(decision.get("reason")), f"unverified format {fmt!r} lacks a reason", errors)
    _require(decision_formats == advertised_families,
             f"format decision set mismatch: missing={sorted(advertised_families - decision_formats)}, extra={sorted(decision_formats - advertised_families)}",
             errors)
    return errors


def validate_fixtures(fixtures: dict, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    _require(fixtures.get("schema_version") == SCHEMA_VERSION, "fixture catalog schema version mismatch", errors)
    rows = fixtures.get("fixtures")
    _require(isinstance(rows, list) and bool(rows), "fixture catalog is empty", errors)
    seen: set[str] = set()
    for row in rows if isinstance(rows, list) else []:
        if not isinstance(row, dict):
            errors.append("fixture row is not an object")
            continue
        fixture_id = row.get("id")
        _require(_nonempty_string(fixture_id), f"fixture has no id: {row!r}", errors)
        if isinstance(fixture_id, str):
            _require(fixture_id not in seen, f"duplicate fixture id: {fixture_id}", errors)
            seen.add(fixture_id)
        source = row.get("source_path")
        _require(_nonempty_string(source), f"fixture {fixture_id!r} has no source_path", errors)
        if isinstance(source, str):
            _require((root / source).is_file(), f"fixture {fixture_id!r} path does not exist: {source}", errors)
        _require(_nonempty_string(row.get("extension")), f"fixture {fixture_id!r} has no extension", errors)
        _require(_nonempty_string(row.get("format_family")), f"fixture {fixture_id!r} has no format family", errors)
        _require(isinstance(row.get("native_seed"), dict), f"fixture {fixture_id!r} has no native seed decision", errors)
    return errors


def validate_adapters(adapter_rows: dict, declared: list[str], inventory: dict, catalog: dict) -> list[str]:
    errors: list[str] = []
    _require(adapter_rows.get("schema_version") == SCHEMA_VERSION, "adapter schema version mismatch", errors)
    rows = adapter_rows.get("adapters")
    _require(isinstance(rows, list) and bool(rows), "adapter registry is empty", errors)
    ids: set[str] = set()
    for row in rows if isinstance(rows, list) else []:
        if not isinstance(row, dict):
            errors.append("adapter row is not an object")
            continue
        adapter_id = row.get("id")
        _require(_nonempty_string(adapter_id), f"adapter has no id: {row!r}", errors)
        if isinstance(adapter_id, str):
            _require(adapter_id not in ids, f"duplicate adapter id: {adapter_id}", errors)
            ids.add(adapter_id)
        _require(_nonempty_string(row.get("public_symbol")), f"adapter {adapter_id!r} has no public symbol", errors)
        _require(row.get("module") in {"TagLibAudioMetadata", "CTagLibBridge"}, f"adapter {adapter_id!r} has an invalid product module", errors)
        _require(_nonempty_string(row.get("invocation")), f"adapter {adapter_id!r} has no invocation decision", errors)
    _require(set(declared) == ids, f"adapter declaration/registry mismatch: declared-only={sorted(set(declared) - ids)}, registry-only={sorted(ids - set(declared))}", errors)
    used = {
        adapter
        for contract in catalog.get("contracts", [])
        if isinstance(contract, dict)
        for adapter in (contract.get("adapters") or [])
    }
    _require(not (used - ids), f"catalog uses undeclared adapters: {sorted(used - ids)}", errors)
    return errors


def validate_all(root: Path = ROOT) -> dict[str, list[str]]:
    inventory = load_json(Path(root) / SURFACE_PATH.relative_to(ROOT))
    catalog = load_json(Path(root) / CATALOG_PATH.relative_to(ROOT))
    fixtures = load_json(Path(root) / FIXTURE_PATH.relative_to(ROOT))
    adapters = load_json(Path(root) / ADAPTER_PATH.relative_to(ROOT))
    field_claims = load_json(Path(root) / FIELD_CLAIMS_PATH.relative_to(ROOT))
    format_claims = load_json(Path(root) / FORMAT_CLAIMS_PATH.relative_to(ROOT))
    required_tests = json.loads((Path(root) / TEST_INVENTORY_PATH.relative_to(ROOT)).read_text(encoding="utf-8"))
    extracted_swift = extract_swift_surfaces(root)
    extracted_bridge = extract_bridge_surfaces(root)
    declared_adapters = extract_adapter_declarations(root)
    declared_scenarios = extract_scenario_declarations(root)
    return {
        "surface_inventory": validate_surface_inventory(
            inventory, catalog, declared_adapters, extracted_swift, extracted_bridge
        ),
        "contract_catalog": validate_catalog(
            catalog,
            inventory,
            fixtures,
            field_claims,
            format_claims,
            declared_adapters,
            required_tests,
            declared_scenarios,
        ),
        "fixtures": validate_fixtures(fixtures, root),
        "adapters": validate_adapters(adapters, declared_adapters, inventory, catalog),
    }


if __name__ == "__main__":
    import sys

    failures = validate_all()
    for area, errors in failures.items():
        for error in errors:
            print(f"[{area}] {error}", file=sys.stderr)
    if any(failures.values()):
        raise SystemExit(1)
    print("Package test-system inventories are consistent.")
