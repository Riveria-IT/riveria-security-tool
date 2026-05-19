#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOT_DIR="$BASE_DIR/tests/fixtures/beginner-mode"
TMP_DIR="$BASE_DIR/.riveria-runtime/test-beginner-mode"

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

generate_beginner_fix_assistant_snapshot() {
    local actual_file="$TMP_DIR/beginner-fix-assistant.txt"

    bash <<'EOF' >"$actual_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"
source "./fixes/fixes.sh"

reset_results
register_fix "FIX-UFW-001" "UFW Basisregeln anwenden" \
    "Firewall ist installiert, aber nicht aktiv oder nicht gehaertet" \
    "AUTO-SAFE" \
    "/etc/default/ufw" \
    "ufw default deny incoming" \
    "ufw status" \
    "ufw enable" \
    "UFW-Status erneut pruefen" \
    "" \
    "WARNUNG"
register_fix "FIX-SSH-001" "SSH Root-Login deaktivieren" \
    "SSH Root-Login erhoeht das Risiko eines erfolgreichen Angriffs" \
    "GUIDED" \
    "/etc/ssh/sshd_config" \
    "PermitRootLogin no setzen" \
    "sshd -t" \
    "systemctl reload ssh" \
    "SSH-Konfiguration erneut pruefen" \
    "" \
    "KRITISCH"

printf '2\n0\n' | run_beginner_fix_assistant
EOF

    normalize_output <"$actual_file" >"$actual_file.normalized"
    assert_file_matches "$actual_file.normalized" "$SNAPSHOT_DIR/beginner-fix-assistant.txt"
}

generate_beginner_summary_snapshot() {
    local actual_file="$TMP_DIR/beginner-summary.txt"

    bash <<'EOF' >"$actual_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"

reset_results
SCORE=68
STATUS_LABEL="Mittel"
register_issue "SVC-014" "LOCAL_WEB_URL Backend nicht aktiv" "KRITISCH" \
    "Das konfigurierte LOCAL_WEB_URL-Backend auf Port 9090 wurde nicht als aktiver Listener erkannt." \
    "Backend-Dienst, Proxy-Ziel und Upstream-Konfiguration pruefen." \
    "GUIDED" \
    "no"
register_issue "SVC-006" "UFW nicht aktiv" "WARNUNG" \
    "UFW ist installiert, aber aktuell nicht aktiv." \
    "Basisregeln setzen und Firewall bewusst aktivieren." \
    "AUTO-SAFE" \
    "yes"
register_fix "FIX-UFW-001" "UFW Basisregeln anwenden" \
    "Firewall ist installiert, aber nicht aktiv oder nicht gehaertet" \
    "AUTO-SAFE" \
    "/etc/default/ufw" \
    "ufw default deny incoming" \
    "ufw status" \
    "ufw enable" \
    "UFW-Status erneut pruefen" \
    "" \
    "WARNUNG"
register_fix "FIX-SSH-001" "SSH Root-Login deaktivieren" \
    "SSH Root-Login erhoeht das Risiko eines erfolgreichen Angriffs" \
    "GUIDED" \
    "/etc/ssh/sshd_config" \
    "PermitRootLogin no setzen" \
    "sshd -t" \
    "systemctl reload ssh" \
    "SSH-Konfiguration erneut pruefen" \
    "" \
    "KRITISCH"
print_beginner_summary
EOF

    normalize_output <"$actual_file" >"$actual_file.normalized"
    assert_file_matches "$actual_file.normalized" "$SNAPSHOT_DIR/beginner-summary.txt"
}

generate_beginner_mode_prompt_snapshot() {
    local actual_file="$TMP_DIR/beginner-mode-prompt.txt"

    bash <<'EOF' >"$actual_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"
source "./fixes/fixes.sh"

DRY_RUN_MODE="1"

run_full_audit() {
    reset_results
    SCORE=68
    STATUS_LABEL="Mittel"
    register_issue "SVC-014" "LOCAL_WEB_URL Backend nicht aktiv" "KRITISCH" \
        "Das konfigurierte LOCAL_WEB_URL-Backend auf Port 9090 wurde nicht als aktiver Listener erkannt." \
        "Backend-Dienst, Proxy-Ziel und Upstream-Konfiguration pruefen." \
        "GUIDED" \
        "no"
    register_issue "SVC-006" "UFW nicht aktiv" "WARNUNG" \
        "UFW ist installiert, aber aktuell nicht aktiv." \
        "Basisregeln setzen und Firewall bewusst aktivieren." \
        "AUTO-SAFE" \
        "yes"
    register_fix "FIX-UFW-001" "UFW Basisregeln anwenden" \
        "Firewall ist installiert, aber nicht aktiv oder nicht gehaertet" \
        "AUTO-SAFE" \
        "/etc/default/ufw" \
        "ufw default deny incoming" \
        "ufw status" \
        "ufw enable" \
        "UFW-Status erneut pruefen" \
        "" \
        "WARNUNG"
}

printf 'y\nn\n' | run_beginner_mode
EOF

    normalize_output <"$actual_file" >"$actual_file.normalized"
    assert_file_matches "$actual_file.normalized" "$SNAPSHOT_DIR/beginner-mode-prompt.txt"
}

cd "$BASE_DIR"

generate_beginner_fix_assistant_snapshot
generate_beginner_summary_snapshot
generate_beginner_mode_prompt_snapshot

printf 'Integration-Beginner-Mode-Test erfolgreich.\n'
