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
if [[ -z "${TAGLIB_CALIBRATION_RESULT:-}" ]]; then
  CALIBRATION_ID="$(date +%Y%m%dT%H%M%S)-$$"
  python3 scripts/calibrate-test-system.py --require-all-killed --run-id "$CALIBRATION_ID"
  export TAGLIB_CALIBRATION_RESULT="$PWD/.build/test-calibration/$CALIBRATION_ID/calibration.json"
fi
# Reuse is allowed only for identical source, commit and complete mutant definitions.
python3 - "$TAGLIB_CALIBRATION_RESULT" <<'CHECK'
import importlib.util, json, sys
from pathlib import Path
sys.path.insert(0, 'scripts')
import test_manifest
spec = importlib.util.spec_from_file_location('summary', 'scripts/summarize-test-run.py')
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
errors = module.verify_calibration(json.loads(Path(sys.argv[1]).read_text()),
    {'source_hash': test_manifest.current_source_hash(), 'commit': test_manifest._git('rev-parse', 'HEAD')})
if errors: raise SystemExit('Invalid calibration: ' + '; '.join(errors))
CHECK
TAGLIB_DISABLE_MANIFEST_SANDBOX=1 bash scripts/validate-tests.sh "$MODE"
