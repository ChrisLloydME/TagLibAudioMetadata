#!/usr/bin/env python3
"""Create and compare the frozen source/build identity for a test campaign."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RELEVANT_ROOTS = (
    "Package.swift",
    "Sources",
    "Tests",
    "scripts",
    "IntegrationTests/Consumer",
    "docs",
)
SYSTEM_FILES = (
    "scripts/package-test-system/public-surface-inventory.json",
    "scripts/package-test-system/contract-catalog.json",
    "scripts/package-test-system/fixture-catalog.json",
    "scripts/package-test-system/execution-adapters.json",
    "scripts/package-test-system/field-schema-claims.json",
    "scripts/package-test-system/format-capability-claims.json",
    "scripts/required-test-inventory.json",
)


def _run(command: list[str], check: bool = False) -> str:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"{' '.join(command)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def _git(*args: str, check: bool = False) -> str:
    return _run(["git", *args], check=check)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


IGNORED_PARTS = {".build", ".git", ".swiftpm", "__pycache__", ".local", "DerivedData"}


def _relevant_files() -> list[Path]:
    files: list[Path] = []
    for entry in RELEVANT_ROOTS:
        path = ROOT / entry
        if path.is_file():
            files.append(path)
        elif path.is_dir():
            for root, names, filenames in os.walk(path):
                names[:] = [name for name in names if name not in IGNORED_PARTS]
                files.extend(Path(root, name) for name in filenames)
    return sorted({path.resolve() for path in files if path.is_file()})


def _source_state() -> dict:
    files = _relevant_files()
    hashes = {
        path.relative_to(ROOT).as_posix(): _sha256(path)
        for path in files
    }
    digest = hashlib.sha256()
    for relative, value in sorted(hashes.items()):
        digest.update(relative.encode("utf-8") + b"\0" + value.encode("ascii") + b"\n")
    status = _git("status", "--porcelain", "--untracked-files=all")
    tracked_diff = _git("diff", "--binary", "HEAD", "--", *RELEVANT_ROOTS)
    return {
        "source_hash": digest.hexdigest(),
        "file_hashes": hashes,
        "git_status": status,
        "tracked_diff_hash": hashlib.sha256(tracked_diff.encode("utf-8")).hexdigest(),
    }


def build(mode: str) -> dict:
    state = _source_state()
    system_hashes = {relative: _sha256(ROOT / relative) for relative in SYSTEM_FILES}
    return {
        "schema_version": 1,
        "run_id": f"{mode}-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-{os.getpid()}",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "mode": mode,
        "commit": _git("rev-parse", "HEAD"),
        "branch": _git("rev-parse", "--abbrev-ref", "HEAD"),
        "toolchain": {
            "swift": _run(["swift", "--version"]),
            "xcodebuild": _run(["xcodebuild", "-version"]),
            "platform": platform.platform(),
            "machine": platform.machine(),
            "developer_dir": _run(["xcode-select", "-p"]),
        },
        "system_hashes": system_hashes,
        **state,
    }


def stable_manifest(manifest: dict) -> dict:
    """Drop per-run timestamps/ids before comparing before/after snapshots."""
    return {key: value for key, value in manifest.items() if key not in {"created_at", "run_id"}}


def current_source_hash() -> str:
    return _source_state()["source_hash"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["write", "check"])
    parser.add_argument("--mode", choices=["debug", "release"], required=True)
    parser.add_argument("--file", required=True)
    parser.add_argument("--against", help="existing manifest to compare against")
    args = parser.parse_args()
    manifest = build(args.mode)
    if args.action == "write":
        Path(args.file).write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(args.file)
        return 0
    if not args.against:
        parser.error("--against is required for check")
    previous = json.loads(Path(args.against).read_text(encoding="utf-8"))
    errors = []
    if stable_manifest(previous) != stable_manifest(manifest):
        errors.append("source/config identity changed between campaign start and check")
    if previous.get("commit") != _git("rev-parse", "HEAD"):
        errors.append("manifest commit does not match current HEAD")
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("manifest is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
