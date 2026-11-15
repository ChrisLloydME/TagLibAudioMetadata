#!/usr/bin/env bash
# Canonical contract lane: policy reconciliation, deterministic calibration and
# the complete strict framework gate. No filters or shards are accepted.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# -le 1 ]] || { echo "No filters or extra arguments are permitted" >&2; exit 2; }
MODE="${1:-debug}"
case "$MODE" in debug|release) ;; *) echo 'Usage: validate-contracts.sh [debug|release]' >&2; exit 2;; esac

python3 -m unittest discover -s scripts/tests
python3 scripts/package_test_system.py
python3 scripts/calibrate-test-system.py --require-all-killed
TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh "$MODE"
