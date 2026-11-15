#!/usr/bin/env bash
# Full-suite contract gate; intentionally accepts no test filters or shards.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# -le 1 ]] || { echo "No filters or extra arguments are permitted" >&2; exit 2; }
MODE="${1:-debug}"
case "$MODE" in debug|release) ;; *) echo 'Usage: validate-tests.sh [debug|release]' >&2; exit 2;; esac
[[ "${TAGLIB_WRITE_CLAIMS:-0}" != 1 ]] || { echo 'Claim blessing is forbidden in acceptance' >&2; exit 2; }
[[ -f "${TAGLIB_CALIBRATION_RESULT:-}" ]] || { echo 'Run validate-contracts.sh, or provide source-bound TAGLIB_CALIBRATION_RESULT' >&2; exit 2; }
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if [[ -n "${TAGLIB_EVIDENCE_ID:-}" ]]; then
  [[ "$TAGLIB_EVIDENCE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,100}$ ]] || { echo 'Unsafe evidence ID' >&2; exit 2; }
  EVIDENCE=".build/test-evidence/${MODE}-${TAGLIB_EVIDENCE_ID}"
else
  EVIDENCE=".build/test-evidence/${MODE}-$(date +%Y%m%d-%H%M%S)-$$"
fi
[[ ! -e "$EVIDENCE" ]] || { echo 'Evidence campaign already exists' >&2; exit 2; }
SCENARIOS="$EVIDENCE/scenarios"
mkdir -p "$SCENARIOS"
export TAGLIB_TEST_EVIDENCE_DIR="$SCENARIOS"
export TAGLIB_CAMPAIGN_ID="$(python3 -c 'import uuid; print(uuid.uuid4())')"
export TAGLIB_CAMPAIGN_MODE="$MODE"

python3 scripts/test_manifest.py write --mode "$MODE" --file "$EVIDENCE/manifest-before.json" >/dev/null

export TAGLIB_CAMPAIGN_SOURCE_HASH="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["source_hash"])' "$EVIDENCE/manifest-before.json")"
OPTIONS=()
while IFS= read -r option; do OPTIONS+=("$option"); done < <(python3 scripts/test_manifest.py options --mode "$MODE")
STATUS=0
swift test "${OPTIONS[@]}" > "$EVIDENCE/tests.log" 2>&1 || STATUS=$?

python3 scripts/test_manifest.py write --mode "$MODE" --file "$EVIDENCE/manifest-after.json" >/dev/null

cat "$EVIDENCE/tests.log"
echo "Test evidence: $EVIDENCE"
python3 scripts/summarize-test-run.py "$EVIDENCE/tests.log" "$STATUS" "$EVIDENCE/summary.json" \
  --evidence-dir "$SCENARIOS" \
  --manifest "$EVIDENCE/manifest-before.json" \
  --manifest-after "$EVIDENCE/manifest-after.json" \
  --mode "$MODE" \
  --calibration "$TAGLIB_CALIBRATION_RESULT"
