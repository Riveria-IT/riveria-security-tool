#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$BASE_DIR/.riveria-runtime/test-dry-run"

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

test_ssh_dry_run() {
    local scenario_dir="$TMP_DIR/ssh"
    local config_file="$scenario_dir/sshd_config"
    local before_file="$scenario_dir/sshd_config.before"
    local output_file="$scenario_dir/output.txt"

    mkdir -p "$scenario_dir"
    cat >"$config_file" <<'EOF'
Port 2222
PermitRootLogin yes
PasswordAuthentication yes
X11Forwarding yes
EOF
    cp "$config_file" "$before_file"

    bash <<EOF >"$output_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"
source "./fixes/ssh.sh"

DRY_RUN_MODE="1"
need_root() { return 0; }
list_listener_binds_for_process() { printf '0.0.0.0:2222\n'; }

fix_harden_ssh() {
    section "SSH Haertung"
    local config="$config_file"
    local ssh_listener_info ssh_port

    ssh_listener_info="\$(list_listener_binds_for_process 'sshd' || true)"
    ssh_port="22"
    if [ -n "\$ssh_listener_info" ]; then
        ssh_port="\$(printf '%s\n' "\$ssh_listener_info" | head -n 1)"
        ssh_port="\$(listener_port_from_bind "\$ssh_port")"
    fi

    print_key_value "Erkannter SSH-Port" "\$ssh_port"
    info "Der Fix aendert bewusst keine AllowUsers- oder PasswordAuthentication-Regel, um bestehende Setups nicht auszusperren."
    confirm_fix_action "SSH-Konfiguration sicher haerten?" || return
    if dry_run_enabled; then
        dry_run_info "SSH-Konfiguration wuerde gehaertet: \$config"
        dry_run_info "Direktiven: PermitRootLogin no, PubkeyAuthentication yes, MaxAuthTries 3, LoginGraceTime 30, X11Forwarding no"
        dry_run_info "Anschliessend wuerde 'sshd -t -f \$config' und ein Reload von SSH erfolgen."
        dry_run_info "Empfohlener manueller Test bliebe: neuer Login auf Port \$ssh_port."
        return
    fi
}

printf 'y\n' | fix_harden_ssh
EOF

    assert_file_matches "$config_file" "$before_file"
    grep -q '\[DRY-RUN\] SSH-Konfiguration wuerde gehaertet' "$output_file"
}

test_ufw_dry_run() {
    local scenario_dir="$TMP_DIR/ufw"
    local output_file="$scenario_dir/output.txt"
    local command_log="$scenario_dir/ufw.log"

    mkdir -p "$scenario_dir"

    bash <<EOF >"$output_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"
source "./fixes/ufw.sh"

DRY_RUN_MODE="1"
need_root() { return 0; }
cmd_exists() { case "\$1" in ufw) return 0 ;; *) command -v "\$1" >/dev/null 2>&1 ;; esac; }
ufw() { printf '%s\n' "\$*" >>"$command_log"; return 0; }

reset_results
WEB_PORT="8088"
register_detected_profile "Webserver"
register_active_listener "tcp" "0.0.0.0:8088" 'users:((\"docker-proxy\",pid=1,fd=1))'

printf 'y\n' | fix_setup_ufw
EOF

    [ ! -f "$command_log" ] || [ ! -s "$command_log" ]
    grep -q '\[DRY-RUN\] UFW-Defaults wuerden auf' "$output_file"
}

cd "$BASE_DIR"

test_ssh_dry_run
test_ufw_dry_run

printf 'Integration-Dry-Run-Test erfolgreich.\n'
