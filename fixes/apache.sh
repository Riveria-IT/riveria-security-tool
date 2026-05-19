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

    detect_active_listeners

    local apache_public_listeners apache_local_listeners
    local public_listener_lines=() local_listener_lines=()
    apache_public_listeners="$(list_listener_binds_for_process 'apache2|httpd' 'public' || true)"
    apache_local_listeners="$(list_listener_binds_for_process 'apache2|httpd' 'local' || true)"

    while IFS= read -r line; do
        [ -n "$line" ] && public_listener_lines+=("$line")
    done <<EOF
$apache_public_listeners
EOF

    while IFS= read -r line; do
        [ -n "$line" ] && local_listener_lines+=("$line")
    done <<EOF
$apache_local_listeners
EOF

    if [ -n "$apache_public_listeners" ]; then
        warn "Apache hat aktive oeffentliche Listener und wird deshalb nicht automatisch deaktiviert."
        print_array_lines "${public_listener_lines[@]}"
        info "Wenn Apache absichtlich Requests verarbeitet oder Backend fuer einen Proxy ist, muss er aktiv bleiben."
        return
    fi

    if [ -n "$apache_local_listeners" ]; then
        warn "Apache hat lokale Listener und koennte als internes Backend genutzt werden."
        print_array_lines "${local_listener_lines[@]}"
        info "Automatische Deaktivierung wird aus Sicherheitsgruenden abgebrochen."
        return
    fi

    print_key_value "Pruefung" "Apache wird nur deaktiviert, wenn du es bestaetigst."
    print_key_value "Hinweis" "UFW 80/443 wird dabei nicht automatisch entfernt."
    confirm_fix_action "Apache stoppen und beim Boot deaktivieren?" || {
        info "Apache-Fix abgebrochen."
        return
    }

    if dry_run_enabled; then
        dry_run_info "Apache wuerde erst per 'apache2ctl configtest' geprueft, dann gestoppt und deaktiviert."
        dry_run_info "UFW-Regeln fuer 80/443 wuerden dabei nicht automatisch entfernt."
        return
    fi

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
        detect_active_listeners
        info "Ports nach Deaktivierung:"
        ss -tulpen 2>/dev/null | grep -E ':(80|443)\b' || info "Keine direkten 80/443-Listener mehr erkannt."
    fi
}
