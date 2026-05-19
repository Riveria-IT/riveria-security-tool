#!/usr/bin/env bash

fix_install_fail2ban() {
    section "Fail2ban"
    need_root
    confirm_fix_action "Fail2ban installieren oder absichern?" || {
        info "Fail2ban-Fix abgebrochen."
        return
    }

    local config_dir="/etc/fail2ban/jail.d"
    local config="$config_dir/riveria-sshd.local"
    local backup=""
    local install_attempted=0

    if dry_run_enabled; then
        if ! cmd_exists fail2ban-client; then
            dry_run_info "Fail2ban wuerde bei Bedarf ueber apt-get installiert."
        fi
        dry_run_info "Fail2ban-Jail-Datei wuerde geschrieben: $config"
        dry_run_info "Anschliessend wuerde 'fail2ban-client -t', 'systemctl enable fail2ban' und 'systemctl restart fail2ban' erfolgen."
        return
    fi

    if ! cmd_exists fail2ban-client; then
        if ! cmd_exists apt-get; then
            bad "apt-get ist nicht verfuegbar. Installation nicht moeglich."
            return
        fi
        info "Installiere Fail2ban ueber apt-get."
        if ! apt-get update >/dev/null 2>&1 || ! apt-get install -y fail2ban >/dev/null 2>&1; then
            bad "Fail2ban konnte nicht installiert werden."
            return
        fi
        install_attempted=1
        ok "Fail2ban wurde installiert."
    fi

    mkdir -p "$config_dir" || {
        bad "Konfigurationsordner konnte nicht erstellt werden: $config_dir"
        return
    }

    if [ -f "$config" ]; then
        backup="$(safe_backup "$config")" || {
            bad "Backup von $config fehlgeschlagen."
            return
        }
        ok "Backup erstellt: $backup"
    fi

    cat >"$config" <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
EOF
    ok "Riveria-Fail2ban-Jail wurde geschrieben."

    if ! validate_command "Fail2ban-Konfigurationstest" fail2ban-client -t; then
        if [ -n "$backup" ]; then
            restore_backup "$backup" "$config"
            info "Backup wurde wiederhergestellt: $backup"
        else
            rm -f "$config"
        fi
        return
    fi

    if cmd_exists systemctl; then
        if systemctl enable fail2ban >/dev/null 2>&1 && systemctl restart fail2ban >/dev/null 2>&1; then
            ok "Fail2ban ist aktiviert und laeuft."
        else
            bad "Fail2ban konnte nicht aktiviert oder gestartet werden."
            if [ -n "$backup" ]; then
                restore_backup "$backup" "$config"
                systemctl restart fail2ban >/dev/null 2>&1 || true
                info "Backup wurde wiederhergestellt: $backup"
            fi
            [ "$install_attempted" -eq 1 ] && warn "Das Paket bleibt installiert und sollte manuell geprueft werden."
            return
        fi
    fi

    validate_command "Fail2ban-Statuspruefung" fail2ban-client ping
}
