#!/usr/bin/env bash

fix_disable_apache_if_unused() {
    section "Apache deaktivieren"
    need_root

    if ! cmd_exists systemctl; then
        warn "systemctl ist nicht verfuegbar."
        return
    fi

    if ! systemctl is-active --quiet apache2 2>/dev/null; then
        info "Apache ist aktuell nicht aktiv."
        return
    fi

    print_key_value "Pruefung" "Apache wird nur deaktiviert, wenn du es bestaetigst."
    print_key_value "Hinweis" "UFW 80/443 wird dabei nicht automatisch entfernt."
    confirm_fix_action "Apache stoppen und beim Boot deaktivieren?" || {
        info "Apache-Fix abgebrochen."
        return
    }

    if ! validate_command "Apache configtest" apache2ctl configtest; then
        warn "Apache-Configtest fehlgeschlagen. Deaktivierung wird trotzdem nicht erzwungen."
        return
    fi

    if systemctl stop apache2 >/dev/null 2>&1 && systemctl disable apache2 >/dev/null 2>&1; then
        ok "Apache wurde gestoppt und deaktiviert."
    else
        bad "Apache konnte nicht sauber gestoppt oder deaktiviert werden."
        return
    fi

    if cmd_exists ss; then
        info "Ports nach Deaktivierung:"
        ss -tulpen 2>/dev/null | grep -E ':(80|443)\b' || info "Keine direkten 80/443-Listener mehr erkannt."
    fi
}
