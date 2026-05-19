#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOT_DIR="$BASE_DIR/tests/fixtures/result-view"
TMP_DIR="$BASE_DIR/.riveria-runtime/test-result-view"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR"

normalize_ansi() {
    perl -pe 's/\e\[[0-9;]*m//g'
}

normalize_output() {
    normalize_ansi | sed -E 's/[[:space:]]+$//' | awk '1'
}

assert_file_matches() {
    local actual="$1"
    local expected="$2"
    cmp -s "$actual" "$expected"
}

generate_simple_issue_summary_snapshot() {
    local actual_file="$TMP_DIR/simple-issues.txt"

    bash <<'EOF' >"$actual_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"

RESULT_VIEW_MODE="simple"
reset_results
register_issue "SVC-006" "UFW nicht aktiv" "WARNUNG" \
    "UFW ist installiert, aber aktuell nicht aktiv." \
    "Basisregeln setzen und Firewall bewusst aktivieren." \
    "AUTO-SAFE" \
    "yes"
register_issue "SVC-014" "LOCAL_WEB_URL Backend nicht aktiv" "KRITISCH" \
    "Das konfigurierte LOCAL_WEB_URL-Backend auf Port 9090 wurde nicht als aktiver Listener erkannt." \
    "Backend-Dienst, Proxy-Ziel und Upstream-Konfiguration pruefen." \
    "GUIDED" \
    "no"
print_issue_summary
EOF

    normalize_output <"$actual_file" >"$actual_file.normalized"
    assert_file_matches "$actual_file.normalized" "$SNAPSHOT_DIR/simple-issues.txt"
}

cd "$BASE_DIR"

generate_simple_issue_summary_snapshot

printf 'Integration-Result-View-Test erfolgreich.\n'
