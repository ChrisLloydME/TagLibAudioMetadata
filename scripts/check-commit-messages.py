#!/usr/bin/env python3
"""Advisory checker for the repository commit-message contract.

Validates the subject and body of every commit in a revision range against
docs/operations/COMMIT_MESSAGES.md:

* subject is `type: imperative summary` with an allowed type;
* summary starts lowercase, has no scope, no trailing period, no backticks;
* subject length stays within the documented target and hard limit;
* exactly one body paragraph follows a blank line, on a single line;
* the body has no bullets, no "This commit", and no commit hashes;
* subjects are distinct within the checked range.

This is a pre-commit aid for maintainers and automated agents, not a CI gate.

Usage:

    python3 scripts/check-commit-messages.py
    python3 scripts/check-commit-messages.py --range origin/main..HEAD
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import Counter

TYPES = ("feat", "fix", "docs", "test", "refactor", "perf", "build", "ci", "chore", "revert")
SUBJECT_RE = re.compile(r"^(?P<type>%s): (?P<summary>[a-z0-9][^\n]*)$" % "|".join(TYPES))
SCOPE_RE = re.compile(r"^[a-z]+\([^)]+\):")
HASH_RE = re.compile(r"\b(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}\b")

MAX_SUBJECT = 60
MAX_BODY = 300


def run_git(*args: str) -> str:
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def has_ref(ref: str) -> bool:
    return subprocess.run(["git", "rev-parse", "--verify", "--quiet", ref], capture_output=True).returncode == 0


def split_message(raw: str) -> tuple[str, str, bool]:
    """Return (subject, body, blank_separator_present)."""
    lines = raw.rstrip("\n").split("\n")
    subject = lines[0].strip() if lines else ""
    if len(lines) == 1:
        return subject, "", False
    rest = lines[1:]
    if rest and rest[0].strip() == "":
        return subject, "\n".join(rest[1:]).strip(), True
    return subject, "\n".join(rest).strip(), False


def inspect_message(subject: str, body: str, blank_line: bool) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    if not subject:
        errors.append("missing subject")
        return errors, warnings
    match = SUBJECT_RE.match(subject)
    if not match:
        errors.append(f"subject is not '<type>: <lowercase summary>': {subject!r}")
    if SCOPE_RE.match(subject):
        errors.append(f"subject uses a scope: {subject!r}")
    if subject.endswith("."):
        errors.append("subject ends with a period")
    if "  " in subject:
        errors.append("subject contains a double space")
    if "`" in subject:
        errors.append("subject contains a backtick")
    if len(subject) > MAX_SUBJECT:
        errors.append(f"subject is {len(subject)} characters (maximum {MAX_SUBJECT})")

    if not body:
        errors.append("missing body paragraph")
        return errors, warnings
    if not blank_line:
        errors.append("subject and body are not separated by a blank line")
    if "\n" in body:
        errors.append("body is not a single line; do not wrap or add paragraphs")
    if len(body) > MAX_BODY:
        errors.append(f"body is {len(body)} characters (maximum {MAX_BODY})")
    if body.startswith(("- ", "* ")):
        errors.append("body starts with a bullet")
    if "This commit" in body:
        errors.append('body contains "This commit"')
    if HASH_RE.search(body) or HASH_RE.search(subject):
        errors.append("message contains a commit hash")
    if not body.endswith("."):
        warnings.append("body does not end with a period")
    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Check commit messages against the repository contract.")
    parser.add_argument(
        "--range",
        default=None,
        help="revision range to check (default: commits not on origin/main; all reachable commits when that ref is absent)",
    )
    args = parser.parse_args()

    rev_range = args.range or ("origin/main..HEAD" if has_ref("refs/remotes/origin/main") else "HEAD")
    try:
        hashes = run_git("rev-list", "--reverse", rev_range).split()
    except SystemExit as error:
        print(error, file=sys.stderr)
        return 2
    if not hashes:
        print(f"No commits to check in range {rev_range!r}.")
        return 0

    errors: list[str] = []
    warnings: list[str] = []
    subjects: Counter[str] = Counter()
    for commit in hashes:
        raw = run_git("show", "-s", "--format=%B", commit)
        subject, body, blank_line = split_message(raw)
        subjects[subject] += 1
        commit_errors, commit_warnings = inspect_message(subject, body, blank_line)
        errors.extend(f"{commit[:9]} {problem}" for problem in commit_errors)
        warnings.extend(f"{commit[:9]} {problem}" for problem in commit_warnings)

    for subject, count in subjects.items():
        if count > 1:
            warnings.append(f"{count} commits share the subject {subject!r}")

    for warning in warnings:
        print(f"warning: {warning}")
    for error in errors:
        print(f"error: {error}")
    print(f"Checked {len(hashes)} commit(s): {len(errors)} error(s), {len(warnings)} warning(s).")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
