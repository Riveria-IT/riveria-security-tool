#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOT_DIR="$BASE_DIR/tests/fixtures/cli-snapshots"
TMP_DIR="$BASE_DIR/.riveria-runtime/test-cli-snapshots"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR"

normalize_ansi() {
    perl -pe 's/\e\[[0-9;]*m//g'
}

normalize_main_menu_output() {
    normalize_ansi | sed -E 's/[[:space:]]+$//' | awk '1'
}

normalize_fix_assistant_output() {
    normalize_ansi | sed -E 's/[[:space:]]+$//' | awk '1'
}

assert_file_matches() {
    local actual="$1"
    local expected="$2"
    cmp -s "$actual" "$expected"
}

generate_root_warning_snapshot() {
    local actual_file="$TMP_DIR/root-warning.txt"

    bash "$BASE_DIR/riveria-security-tool.sh" >"$actual_file" 2>&1 || true
    normalize_ansi <"$actual_file" >"$actual_file.normalized"
    assert_file_matches "$actual_file.normalized" "$SNAPSHOT_DIR/root-warning.txt"
}

generate_main_menu_snapshot() {
    local actual_file="$TMP_DIR/main-menu.txt"

    bash <<'EOF' >"$actual_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"
source "./fixes/fixes.sh"

need_root() {
    return 0
}

printf '0\n' | main_menu
EOF

    normalize_main_menu_output <"$actual_file" >"$actual_file.normalized"
    assert_file_matches "$actual_file.normalized" "$SNAPSHOT_DIR/main-menu.txt"
}

generate_fix_assistant_snapshot() {
    local actual_file="$TMP_DIR/fix-assistant.txt"

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

printf '4\n0\n' | run_fix_assistant
EOF

    normalize_fix_assistant_output <"$actual_file" >"$actual_file.normalized"
    assert_file_matches "$actual_file.normalized" "$SNAPSHOT_DIR/fix-assistant.txt"
}

generate_confirm_dialog_snapshot() {
    local actual_file="$TMP_DIR/confirm-dialog.txt"

    bash <<'EOF' >"$actual_file"
source "./lib/core.sh"
source "./lib/ui.sh"

FIX_ASSISTANT_MODE=0
if printf 'y\n' | confirm_fix_action "Test-Fix wirklich ausfuehren?"; then
    info "Bestaetigt"
else
    warn "Abgebrochen"
fi
EOF

    normalize_fix_assistant_output <"$actual_file" >"$actual_file.normalized"
    assert_file_matches "$actual_file.normalized" "$SNAPSHOT_DIR/confirm-dialog.txt"
}

generate_fix_selection_snapshot() {
    local actual_file="$TMP_DIR/fix-selection.txt"

    bash <<'EOF' >"$actual_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"
source "./fixes/fixes.sh"

stub_fix_handler() {
    info "Stub-Fix ausgefuehrt."
    info "Fix-Assistent-Modus: $FIX_ASSISTANT_MODE"
}

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
register_fix "FIX-STUB-001" "Stub-Fix ausfuehren" \
    "Kontrollierter Testlauf fuer den Fix-Assistenten" \
    "AUTO-SAFE" \
    "/tmp/stub-backup" \
    "stub_fix_handler" \
    "echo stub-test" \
    "echo stub-reload" \
    "Stub erneut pruefen" \
    "stub_fix_handler" \
    "WARNUNG"

printf '2\ny\n0\n' | run_fix_selection_menu
EOF

    normalize_fix_assistant_output <"$actual_file" >"$actual_file.normalized"
    assert_file_matches "$actual_file.normalized" "$SNAPSHOT_DIR/fix-selection.txt"
}

cd "$BASE_DIR"

generate_root_warning_snapshot
generate_main_menu_snapshot
generate_fix_assistant_snapshot
generate_confirm_dialog_snapshot
generate_fix_selection_snapshot

printf 'Integration-CLI-Snapshots-Test erfolgreich.\n'
