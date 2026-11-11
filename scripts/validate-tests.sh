#!/usr/bin/env bash
# Full-suite gate; intentionally accepts no test filters or skips.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# -le 1 ]] || { echo "No filters or extra arguments are permitted" >&2; exit 2; }
MODE="${1:-debug}"
case "$MODE" in debug|release) ;; *) echo 'Usage: validate-tests.sh [debug|release]' >&2; exit 2;; esac
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
EVIDENCE=".build/test-evidence/${MODE}-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$EVIDENCE"
OPTIONS=(--disable-keychain --disable-netrc -c "$MODE")
if [[ "${TAGLIB_DISABLE_MANIFEST_SANDBOX:-0}" == 1 ]]; then OPTIONS+=(--disable-sandbox); fi
STATUS=0
swift test "${OPTIONS[@]}" > "$EVIDENCE/tests.log" 2>&1 || STATUS=$?
cat "$EVIDENCE/tests.log"
echo "Test evidence: $EVIDENCE"
python3 scripts/summarize-test-run.py "$EVIDENCE/tests.log" "$STATUS" "$EVIDENCE/summary.json"
