#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$BASE_DIR/tests/fixtures/fix-handlers"
TMP_DIR="$BASE_DIR/.riveria-runtime/test-fix-handlers"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR"

normalize_ansi() {
    perl -pe 's/\e\[[0-9;]*m//g'
}

normalize_output() {
    normalize_ansi | sed -E 's/[[:space:]]+$//'
}

assert_file_matches() {
    local actual="$1"
    local expected="$2"
    cmp -s "$actual" "$expected"
}

generate_ufw_handler_snapshot() {
    local scenario_dir="$TMP_DIR/ufw"
    local output_file="$scenario_dir/output.txt"
    local commands_file="$scenario_dir/ufw-commands.txt"

    mkdir -p "$scenario_dir"

    bash <<EOF >"$output_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"
source "./fixes/ufw.sh"

UFW_COMMAND_LOG="$commands_file"

need_root() {
    return 0
}

cmd_exists() {
    case "\$1" in
        ufw) return 0 ;;
        *) command -v "\$1" >/dev/null 2>&1 ;;
    esac
}

ufw() {
    printf '%s\n' "\$*" >>"\$UFW_COMMAND_LOG"
    case "\${1:-}" in
        status)
            printf 'Status: inactive\n'
            ;;
        enable)
            printf 'Firewall is active\n'
            ;;
    esac
    return 0
}

validate_command() {
    local description="\$1"
    shift
    "\$@" >/dev/null 2>&1 || return 1
    ok "\$description erfolgreich."
}

reset_results
WEB_PORT="8088"
register_detected_profile "Webserver"
register_detected_profile "Reverse Proxy"
register_active_listener "tcp" "0.0.0.0:8088" 'users:((\"docker-proxy\",pid=1,fd=1))'
register_active_listener "tcp" "0.0.0.0:8443" 'users:((\"nginx\",pid=2,fd=1))'

printf 'y\n' | fix_setup_ufw
EOF

    normalize_output <"$output_file" >"$output_file.normalized"
    assert_file_matches "$output_file.normalized" "$FIXTURE_DIR/ufw-output.txt"
    assert_file_matches "$commands_file" "$FIXTURE_DIR/ufw-commands.txt"
}

generate_nginx_handler_snapshot() {
    local scenario_dir="$TMP_DIR/nginx"
    local output_file="$scenario_dir/output.txt"
    local site_file="$scenario_dir/site.conf"
    local snippet_file="$scenario_dir/riveria-security-headers.conf"

    mkdir -p "$scenario_dir"
    cat >"$site_file" <<'EOF'
server {
    listen 80;
    server_name example.com;
    root /srv/example/public;
}
EOF

    bash <<EOF >"$output_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"
source "./fixes/nginx.sh"

need_root() {
    return 0
}

cmd_exists() {
    case "\$1" in
        nginx|systemctl) return 0 ;;
        *) command -v "\$1" >/dev/null 2>&1 ;;
    esac
}

systemctl() {
    [ "\${1:-}" = "reload" ] && [ "\${2:-}" = "nginx" ] && return 0
    return 0
}

validate_command() {
    local description="\$1"
    shift
    ok "\$description erfolgreich."
}

nginx_security_snippet_path() {
    printf '%s' "$snippet_file"
}

nginx_find_candidate_files() {
    printf '%s\n' "$site_file"
}

reset_results
PUBLIC_WEB_URL="https://example.com"
register_detected_component "nginx"
BACKUP_DIR="$scenario_dir/backups"
mkdir -p "\$BACKUP_DIR"

printf 'y\n' | fix_create_nginx_security_headers
EOF

    normalize_output <"$output_file" >"$output_file.normalized"
    sed -E \
        -e "s#${scenario_dir}/riveria-security-headers\\.conf#__SNIPPET_PATH__#g" \
        -e "s#${scenario_dir}/site\\.conf#__SITE_PATH__#g" \
        -e "s#${scenario_dir}/backups/[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9-]+_site\\.conf#__BACKUP_PATH__/site.conf.bak#g" \
        "$output_file.normalized" >"$output_file.fixture"
    sed -E \
        -e "s#${scenario_dir}/riveria-security-headers\\.conf#__SNIPPET_PATH__#g" \
        "$site_file" >"$site_file.fixture"

    assert_file_matches "$output_file.fixture" "$FIXTURE_DIR/nginx-output.txt"
    assert_file_matches "$snippet_file" "$FIXTURE_DIR/nginx-snippet.conf"
    assert_file_matches "$site_file.fixture" "$FIXTURE_DIR/nginx-site.conf"
}

generate_ssh_handler_snapshot() {
    local scenario_dir="$TMP_DIR/ssh"
    local output_file="$scenario_dir/output.txt"
    local config_file="$scenario_dir/sshd_config"

    mkdir -p "$scenario_dir"
    cat >"$config_file" <<'EOF'
Port 2222
PermitRootLogin yes
PasswordAuthentication yes
X11Forwarding yes
EOF

    bash <<EOF >"$output_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"
source "./fixes/ssh.sh"

need_root() {
    return 0
}

validate_command() {
    local description="\$1"
    shift
    ok "\$description erfolgreich."
}

cmd_exists() {
    case "\$1" in
        systemctl) return 0 ;;
        *) command -v "\$1" >/dev/null 2>&1 ;;
    esac
}

systemctl() {
    [ "\${1:-}" = "reload" ] && { [ "\${2:-}" = "ssh" ] || [ "\${2:-}" = "sshd" ]; } && return 0
    return 0
}

safe_backup() {
    local target="\$1"
    local backup="$scenario_dir/backups/\$(basename "\$target").bak"
    mkdir -p "$scenario_dir/backups"
    cp -a "\$target" "\$backup"
    printf '%s' "\$backup"
}

restore_backup() {
    local backup_file="\$1"
    local target_file="\$2"
    cp -a "\$backup_file" "\$target_file"
}

list_listener_binds_for_process() {
    printf '0.0.0.0:2222\n'
}

fix_harden_ssh() {
    local original_config="/etc/ssh/sshd_config"
    local config="$config_file"
    section "SSH Haertung"

    [ -f "\$config" ] || {
        warn "sshd_config nicht gefunden."
        return
    }

    detect_active_listeners
    local ssh_listener_info ssh_port
    ssh_listener_info="\$(list_listener_binds_for_process 'sshd' || true)"
    ssh_port="22"
    if [ -n "\$ssh_listener_info" ]; then
        ssh_port="\$(printf '%s\n' "\$ssh_listener_info" | head -n 1)"
        ssh_port="\$(listener_port_from_bind "\$ssh_port")"
    fi

    print_key_value "Erkannter SSH-Port" "\$ssh_port"
    info "Der Fix aendert bewusst keine AllowUsers- oder PasswordAuthentication-Regel, um bestehende Setups nicht auszusperren."

    confirm_fix_action "SSH-Konfiguration sicher haerten?" || {
        info "SSH-Haertung abgebrochen."
        return
    }

    local backup
    backup="\$(safe_backup "\$config")" || {
        bad "Backup von \$config fehlgeschlagen."
        return
    }
    ok "Backup erstellt: \$backup"

    set_config_directive "\$config" "PermitRootLogin" "no" || {
        bad "PermitRootLogin konnte nicht gesetzt werden."
        restore_backup "\$backup" "\$config"
        return
    }
    set_config_directive "\$config" "PubkeyAuthentication" "yes"
    set_config_directive "\$config" "MaxAuthTries" "3"
    set_config_directive "\$config" "LoginGraceTime" "30"
    set_config_directive "\$config" "X11Forwarding" "no"
    ok "SSH-Defaults wurden eingetragen."

    if ! validate_command "SSH-Konfigurationstest" sshd -t -f "\$config"; then
        restore_backup "\$backup" "\$config"
        info "Backup wurde wiederhergestellt: \$backup"
        return
    fi

    if cmd_exists systemctl; then
        if systemctl reload ssh >/dev/null 2>&1 || systemctl reload sshd >/dev/null 2>&1; then
            ok "SSH wurde neu geladen."
        else
            bad "SSH konnte nicht neu geladen werden."
            restore_backup "\$backup" "\$config"
            return
        fi
    fi

    info "Bitte aktuelle SSH-Session offen lassen und neuen Login auf Port \$ssh_port testen."
}

printf 'y\n' | fix_harden_ssh
EOF

    normalize_output <"$output_file" >"$output_file.normalized"
    sed -E \
        -e "s#${scenario_dir}/sshd_config#__SSH_CONFIG__#g" \
        -e "s#${scenario_dir}/backups/sshd_config\\.bak#__SSH_BACKUP__#g" \
        "$output_file.normalized" >"$output_file.fixture"
    assert_file_matches "$output_file.fixture" "$FIXTURE_DIR/ssh-output.txt"
    assert_file_matches "$config_file" "$FIXTURE_DIR/sshd_config"
}

generate_permissions_handler_snapshot() {
    local scenario_dir="$TMP_DIR/permissions"
    local output_file="$scenario_dir/output.txt"
    local env_file="$scenario_dir/.env"

    mkdir -p "$scenario_dir"
    cat >"$env_file" <<'EOF'
APP_KEY=base64:test
DB_PASSWORD=secret
EOF
    chmod 644 "$env_file"

    bash <<EOF >"$output_file"
source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"
source "./fixes/permissions.sh"

need_root() {
    return 0
}

permissions_collect_sensitive_files() {
    printf '%s\n' "$env_file"
}

permissions_collect_sensitive_files_in_webroot() {
    return 0
}

safe_backup() {
    local target="\$1"
    local backup="$scenario_dir/backups/\$(basename "\$target").bak"
    mkdir -p "$scenario_dir/backups"
    cp -a "\$target" "\$backup"
    printf '%s' "\$backup"
}

restore_backup() {
    local backup_file="\$1"
    local target_file="\$2"
    cp -a "\$backup_file" "\$target_file"
}

printf 'y\n' | fix_permissions_basics
EOF

    normalize_output <"$output_file" >"$output_file.normalized"
    sed -E \
        -e "s#${scenario_dir}/\\.env#__ENV_FILE__#g" \
        -e "s#${scenario_dir}/backups/\\.env\\.bak#__ENV_BACKUP__#g" \
        "$output_file.normalized" >"$output_file.fixture"
    assert_file_matches "$output_file.fixture" "$FIXTURE_DIR/permissions-output.txt"

    if [ "$(stat -f '%Lp' "$env_file" 2>/dev/null || stat -c '%a' "$env_file" 2>/dev/null)" != "640" ]; then
        return 1
    fi
}

cd "$BASE_DIR"

generate_ufw_handler_snapshot
generate_nginx_handler_snapshot
generate_ssh_handler_snapshot
generate_permissions_handler_snapshot

printf 'Integration-Fix-Handlers-Test erfolgreich.\n'
