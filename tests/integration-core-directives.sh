#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$BASE_DIR/tests/fixtures/core-directives"
TMP_DIR="$BASE_DIR/.riveria-runtime/test-core-directives"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR"

assert_file_matches() {
    local actual="$1"
    local expected="$2"
    cmp -s "$actual" "$expected"
}

generate_shell_directive_snapshot() {
    local actual_file="$TMP_DIR/sshd_config"

    cat >"$actual_file" <<'EOF'
Port 2222
PermitRootLogin yes
# PermitRootLogin prohibit-password
PasswordAuthentication yes
X11Forwarding yes
# X11Forwarding no
EOF

    bash <<EOF
source "./lib/core.sh"
set_config_directive "$actual_file" "PermitRootLogin" "no"
set_config_directive "$actual_file" "X11Forwarding" "no"
set_config_directive "$actual_file" "PubkeyAuthentication" "yes"
EOF

    assert_file_matches "$actual_file" "$FIXTURE_DIR/sshd_config.expected"
}

generate_ini_directive_snapshot() {
    local actual_file="$TMP_DIR/php.ini"

    cat >"$actual_file" <<'EOF'
memory_limit = 128M
; expose_php = On
expose_php = On
display_errors = On
; display_errors = Off
EOF

    bash <<EOF
source "./lib/core.sh"
set_ini_directive "$actual_file" "expose_php" "Off"
set_ini_directive "$actual_file" "display_errors" "Off"
set_ini_directive "$actual_file" "log_errors" "On"
EOF

    assert_file_matches "$actual_file" "$FIXTURE_DIR/php.ini.expected"
}

cd "$BASE_DIR"

generate_shell_directive_snapshot
generate_ini_directive_snapshot

printf 'Integration-Core-Directives-Test erfolgreich.\n'
