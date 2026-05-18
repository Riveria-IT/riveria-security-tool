#!/usr/bin/env bash

fix_harden_ssh() {
    section "SSH Haertung"
    local config="/etc/ssh/sshd_config"

    [ -f "$config" ] || {
        warn "sshd_config nicht gefunden."
        return
    }

    confirm_fix_action "SSH-Konfiguration sicher haerten?" || {
        info "SSH-Haertung abgebrochen."
        return
    }

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
    set_config_directive "$config" "PasswordAuthentication" "yes"
    set_config_directive "$config" "MaxAuthTries" "3"
    set_config_directive "$config" "LoginGraceTime" "30"
    set_config_directive "$config" "X11Forwarding" "no"
    if [ -n "$SSH_ALLOWED_USER" ]; then
        set_config_directive "$config" "AllowUsers" "$SSH_ALLOWED_USER"
    fi
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

    info "Bitte aktuelle SSH-Session offen lassen und neuen Login testen."
}
