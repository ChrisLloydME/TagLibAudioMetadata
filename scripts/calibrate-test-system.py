#!/usr/bin/env python3
"""Deterministic compile-and-activate calibration for the package contract system.

Every mutant runs in an isolated source copy under ignored .build space. The
active checkout, dependency binary and user fixtures are never modified. A
mutant is killed only when it compiles, its intended behavior is witnessed and
a behavioral probe exits with the expected failure.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MUTANTS = ROOT / "scripts/calibration-mutants.json"
HARNESS_SOURCE = ROOT / "scripts/calibration/CalibrationProbes"
CALIBRATION_ROOT = ROOT / ".build/test-calibration"
BUILD_TIMEOUT = 900
PROBE_TIMEOUT = 180
IGNORED = {".build", ".git", ".local", ".swiftpm", "__pycache__", "DerivedData"}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_head() -> str:
    result = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else "unknown"


def copy_tree(source: Path, destination: Path) -> None:
    def ignore(_directory: str, names: list[str]) -> set[str]:
        return {name for name in names if name in IGNORED}
    shutil.copytree(source, destination, ignore=ignore, symlinks=True)


def prepare_workspace(run_id: str) -> Path:
    workspace = CALIBRATION_ROOT / run_id
    if workspace.exists():
        shutil.rmtree(workspace)
    (workspace / "logs").mkdir(parents=True)
    package = workspace / "package"
    copy_tree(ROOT, package)
    # Reuse the ordinary build-system binary cache. This is a cache only; no
    # dependency source or binary is edited.
    artifacts = ROOT / ".build/artifacts"
    if artifacts.is_dir():
        target = package / ".build/artifacts"
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(artifacts, target, symlinks=True)
    harness = workspace / "harness"
    sources = harness / "Sources/CalibrationProbes"
    sources.mkdir(parents=True)
    for path in sorted(HARNESS_SOURCE.glob("*.swift")):
        shutil.copy2(path, sources / path.name)
    shutil.copy2(
        package / "Tests/TagLibAudioMetadataTests/ContractSystem/PublicSurfaceAdapters.swift",
        sources / "PublicSurfaceAdapters.swift",
    )
    (harness / "Package.swift").write_text(
        (ROOT / "scripts/calibration/Package.swift.template").read_text(),
        encoding="utf-8",
    )
    fixtures = workspace / "fixtures"
    fixtures.mkdir()
    for name in ("Audio", "Artwork"):
        shutil.copytree(
            package / "Tests/TagLibAudioMetadataTests" / name,
            fixtures / name,
            symlinks=True,
        )
    # Flatten the fixture directories expected by the probes.
    for path in list((fixtures / "Audio").glob("*")):
        shutil.copy2(path, fixtures / path.name)
    for path in list((fixtures / "Artwork").glob("*")):
        shutil.copy2(path, fixtures / path.name)
    return workspace


def run(command: list[str], cwd: Path, env: dict, timeout: int, log: Path) -> tuple[int, str, str]:
    started = time.monotonic()
    try:
        result = subprocess.run(
            command, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout
        )
        output = result.stdout + result.stderr
        log.write_text(output, encoding="utf-8")
        return result.returncode, output, "completed"
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or "") + (error.stderr or "")
        if isinstance(output, bytes):
            output = output.decode("utf-8", "replace")
        log.write_text(output, encoding="utf-8")
        return 124, output, f"timeout after {timeout}s"
    finally:
        _ = started


def build(workspace: Path, log: Path) -> tuple[bool, str]:
    environment = os.environ.copy()
    environment["CALIBRATION_FIXTURES"] = str(workspace / "fixtures")
    code, output, state = run(
        [
            "swift", "build",
            "--package-path", str(workspace / "harness"),
            "--scratch-path", str(workspace / "harness/.build"),
            "--disable-sandbox", "--disable-keychain", "--disable-netrc",
            "-Xswiftc", "-warnings-as-errors", "-Xcc", "-Werror",
        ],
        cwd=workspace,
        env=environment,
        timeout=BUILD_TIMEOUT,
        log=log,
    )
    if state != "completed":
        return False, state
    return code == 0, "compiled" if code == 0 else "compile-failed"


def probe_binary(workspace: Path) -> Path:
    return workspace / "harness/.build/debug/CalibrationProbes"


def run_probe(workspace: Path, probe: str, log: Path) -> tuple[int, str]:
    environment = os.environ.copy()
    environment["CALIBRATION_FIXTURES"] = str(workspace / "fixtures")
    code, output, state = run(
        [str(probe_binary(workspace)), probe],
        cwd=workspace,
        env=environment,
        timeout=PROBE_TIMEOUT,
        log=log,
    )
    if state != "completed":
        return 124, output
    return code, output


def apply_patches(workspace: Path, patches: list[dict]) -> tuple[list[tuple[Path, bytes]], list[dict]]:
    originals: dict[Path, bytes] = {}
    fingerprints = []
    for patch in patches:
        relative = patch["file"]
        base = workspace / "package" if relative.startswith(("Sources/", "Tests/", "Package.swift")) else workspace
        target = (base / relative).resolve()
        workspace_resolved = workspace.resolve()
        if workspace_resolved not in target.parents:
            raise RuntimeError(f"mutant target escapes workspace: {target}")
        if not target.is_file():
            raise RuntimeError(f"mutant target is missing: {target}")
        if target not in originals:
            originals[target] = target.read_bytes()
        original = target.read_bytes()
        text = original.decode("utf-8")
        occurrences = text.count(patch["find"])
        if occurrences != 1:
            raise RuntimeError(f"anchored patch occurs {occurrences} times in {relative}")
        patched = text.replace(patch["find"], patch["replace"], 1)
        target.write_text(patched, encoding="utf-8")
        fingerprints.append({"file": relative, "sha256": sha256(target)})
    return list(originals.items()), fingerprints


def restore(workspace: Path, backups: list[tuple[Path, bytes]]) -> bool:
    for target, original in backups:
        target.write_bytes(original)
    return all(target.read_bytes() == original for target, original in backups)


def load_mutants() -> list[dict]:
    return json.loads(MUTANTS.read_text(encoding="utf-8"))["mutants"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--mutant", action="append", default=[])
    parser.add_argument("--allow-failures", action="store_true")
    parser.add_argument("--require-all-killed", action="store_true")
    parser.add_argument("--run-id")
    args = parser.parse_args()
    mutants = load_mutants()
    if args.list:
        for mutant in mutants:
            print(f"{mutant['id']}: {mutant['description']}")
        return 0
    selected = [m for m in mutants if not args.mutant or m["id"] in args.mutant]
    if not selected:
        print(f"no matching mutants: {args.mutant}", file=sys.stderr)
        return 2
    run_id = args.run_id or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    workspace = prepare_workspace(run_id)
    environment = os.environ.copy()
    environment["CALIBRATION_FIXTURES"] = str(workspace / "fixtures")
    record = {
        "schema_version": 1,
        "run_id": run_id,
        "commit": git_head(),
        "workspace": str(workspace.relative_to(ROOT)),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "control": {},
        "mutants": [],
    }
    build_ok, build_state = build(workspace, workspace / "logs/control-build.log")
    record["control"]["build"] = build_state
    if not build_ok:
        record["acceptance"] = "inconclusive"
        record["reason"] = f"control build failed: {build_state}"
        (workspace / "calibration.json").write_text(json.dumps(record, indent=2) + "\n")
        print(json.dumps(record, indent=2))
        return 2
    control_code, control_output = run_probe(workspace, "control", workspace / "logs/control-run.log")
    record["control"].update({
        "exit_status": control_code,
        "clean": control_code == 0 and "CLEAN OK" in control_output,
        "witness": [line for line in control_output.splitlines() if line.startswith(("CLEAN", "FAIL", "INCONCLUSIVE"))],
    })
    if not record["control"]["clean"]:
        record["acceptance"] = "inconclusive"
        record["reason"] = "control probe failed on the unmutated package"
        (workspace / "calibration.json").write_text(json.dumps(record, indent=2) + "\n")
        print(json.dumps(record, indent=2))
        return 2

    all_killed = True
    for mutant in selected:
        started = time.monotonic()
        detail = {
            "id": mutant["id"],
            "description": mutant["description"],
            "probe": mutant["probe"],
            "status": "inconclusive",
            "patches": mutant["patches"],
            "fingerprints": [],
            "commands": [],
            "activation_witness": [],
            "expected_failure": f"FAIL {mutant['probe']}: behavioral assertion failed after activation",
            "restored": False,
        }
        try:
            backups, fingerprints = apply_patches(workspace, mutant["patches"])
        except RuntimeError as error:
            detail["reason"] = str(error)
            record["mutants"].append(detail)
            all_killed = False
            continue
        detail["fingerprints"] = fingerprints
        build_ok, build_state = build(workspace, workspace / f"logs/{mutant['id']}-build.log")
        detail["build"] = build_state
        if not build_ok:
            detail["reason"] = f"mutant build failed: {build_state}"
            restore(workspace, backups)
            detail["restored"] = restore(workspace, backups)
            record["mutants"].append(detail)
            all_killed = False
            continue
        code, output = run_probe(workspace, mutant["probe"], workspace / f"logs/{mutant['id']}-probe.log")
        detail["commands"] = [
            f"swift build --package-path {workspace.name}/harness --scratch-path {workspace.name}/harness/.build",
            f"{workspace.name}/harness/.build/debug/CalibrationProbes {mutant['probe']}",
        ]
        detail["probe_exit_status"] = code
        detail["activation_witness"] = [
            line for line in output.splitlines()
            if line.startswith(("ACTIVATION", "FAIL", "INCONCLUSIVE", "CLEAN"))
        ]
        detail["duration_seconds"] = round(time.monotonic() - started, 2)
        activated = any(line.startswith(f"ACTIVATION {mutant['probe']}") for line in output.splitlines())
        failed = any(line.startswith(f"FAIL {mutant['probe']}:") for line in output.splitlines())
        if code == 1 and activated and failed:
            detail["status"] = "killed"
        elif code == 0:
            detail["status"] = "survived"
            detail["reason"] = "probe accepted the mutated behavior"
            all_killed = False
        elif code == 2:
            detail["status"] = "inconclusive"
            detail["reason"] = "probe reported an unrelated/unexpected failure"
            all_killed = False
        else:
            detail["status"] = "inconclusive"
            detail["reason"] = f"unexpected probe exit {code} without the intended witness"
            all_killed = False
        restored = restore(workspace, backups)
        detail["restored"] = restored
        if not restored:
            detail["status"] = "inconclusive"
            detail["reason"] = "mutant source could not be restored exactly"
            all_killed = False
        record["mutants"].append(detail)

    final_build_ok, final_build_state = build(workspace, workspace / "logs/control-final-build.log")
    record["control"]["final_build"] = final_build_state
    if not final_build_ok:
        record["control"]["final_clean"] = False
    control_code, control_output = run_probe(workspace, "control", workspace / "logs/control-final.log")
    record["control"]["final_exit_status"] = control_code
    record["control"]["final_clean"] = control_code == 0 and "CLEAN OK" in control_output
    accepted = all_killed and record["control"]["final_clean"] and all(
        mutant["status"] == "killed" and mutant["restored"] for mutant in record["mutants"]
    )
    record["acceptance"] = "accepted" if accepted else "failed"
    record["finished_at"] = datetime.now(timezone.utc).isoformat()
    (workspace / "calibration.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record, indent=2))
    if accepted:
        return 0
    return 0 if args.allow_failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
