#!/usr/bin/env bash

fix_install_fail2ban() {
    section "Fail2ban"
    confirm_fix_action "Fail2ban installieren oder absichern?" || {
        info "Fail2ban-Fix abgebrochen."
        return
    }

    local config="/etc/fail2ban/jail.local"
    local backup=""
    local install_attempted=0

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
    ok "jail.local wurde geschrieben."

    if ! validate_command "Fail2ban-Konfigurationstest" fail2ban-client -t; then
        if [ -n "$backup" ]; then
            restore_backup "$backup" "$config"
            info "Backup wurde wiederhergestellt: $backup"
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
