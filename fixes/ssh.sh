#!/usr/bin/env bash

fix_harden_ssh() {
    section "SSH Haertung"
    local config="/etc/ssh/sshd_config"

    [ -f "$config" ] || {
        warn "sshd_config nicht gefunden."
        return
    }

    detect_active_listeners
    local ssh_listener_info ssh_port
    ssh_listener_info="$(list_listener_binds_for_process 'sshd' || true)"
    ssh_port="22"
    if [ -n "$ssh_listener_info" ]; then
        ssh_port="$(printf '%s\n' "$ssh_listener_info" | head -n 1)"
        ssh_port="$(listener_port_from_bind "$ssh_port")"
    fi

    print_key_value "Erkannter SSH-Port" "$ssh_port"
    info "Der Fix aendert bewusst keine AllowUsers- oder PasswordAuthentication-Regel, um bestehende Setups nicht auszusperren."

    confirm_fix_action "SSH-Konfiguration sicher haerten?" || {
        info "SSH-Haertung abgebrochen."
        return
    }

    if dry_run_enabled; then
        dry_run_info "SSH-Konfiguration wuerde gehaertet: $config"
        dry_run_info "Direktiven: PermitRootLogin no, PubkeyAuthentication yes, MaxAuthTries 3, LoginGraceTime 30, X11Forwarding no"
        dry_run_info "Anschliessend wuerde 'sshd -t -f $config' und ein Reload von SSH erfolgen."
        dry_run_info "Empfohlener manueller Test bliebe: neuer Login auf Port $ssh_port."
        return
    fi

    local backup
    backup="$(safe_backup "$config")" || {
        bad "Backup von $config fehlgeschlagen."
        return
    }
    ok "Backup erstellt: $backup"

    set_config_directive "$config" "PermitRootLogin" "no" || {
        bad "PermitRootLogin konnte nicht gesetzt werden."
        restore_backup "$backup" "$config"
        return
    }
    set_config_directive "$config" "PubkeyAuthentication" "yes"
    set_config_directive "$config" "MaxAuthTries" "3"
    set_config_directive "$config" "LoginGraceTime" "30"
    set_config_directive "$config" "X11Forwarding" "no"
    ok "SSH-Defaults wurden eingetragen."

    if ! validate_command "SSH-Konfigurationstest" sshd -t -f "$config"; then
        restore_backup "$backup" "$config"
        info "Backup wurde wiederhergestellt: $backup"
        return
    fi

    if cmd_exists systemctl; then
        if systemctl reload ssh >/dev/null 2>&1 || systemctl reload sshd >/dev/null 2>&1; then
            ok "SSH wurde neu geladen."
        else
            bad "SSH konnte nicht neu geladen werden."
            restore_backup "$backup" "$config"
            if systemctl reload ssh >/dev/null 2>&1 || systemctl reload sshd >/dev/null 2>&1; then
                info "Backup wurde wiederhergestellt und SSH erneut geladen."
            fi
            return
        fi
    fi

    info "Bitte aktuelle SSH-Session offen lassen und neuen Login auf Port $ssh_port testen."
}
