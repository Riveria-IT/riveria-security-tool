#!/usr/bin/env bash

ufw_rule_exists() {
    local rule="$1"
    ufw status 2>/dev/null | grep -Fq "$rule"
}

build_ufw_port_plan() {
    local ports=()
    ports+=("22/tcp")

    if printf '%s\n' "${DETECTED_PROFILES[@]}" | grep -Eq 'Webserver|PHP Backend|Laravel|Symfony|WordPress|Reverse Proxy|Webmail Server'; then
        ports+=("80/tcp" "443/tcp")
    fi

    if printf '%s\n' "${DETECTED_PROFILES[@]}" | grep -Eq 'Mailserver|Mailcow Server'; then
        ports+=("25/tcp" "110/tcp" "143/tcp" "465/tcp" "587/tcp" "993/tcp" "995/tcp" "4190/tcp")
    fi

    if [ -n "$WEB_PORT" ] && [ "$WEB_PORT" != "80" ] && [ "$WEB_PORT" != "443" ]; then
        ports+=("${WEB_PORT}/tcp")
    fi

    local unique=()
    local port
    for port in "${ports[@]}"; do
        append_unique "$port" "${unique[@]}" || unique+=("$port")
    done

    printf '%s\n' "${unique[@]}"
}

show_ufw_plan() {
    local ports=()
    local port
    while IFS= read -r port; do
        [ -n "$port" ] && ports+=("$port")
    done < <(build_ufw_port_plan)

    section "UFW Regelplan"
    print_key_value "Incoming" "deny"
    print_key_value "Outgoing" "allow"
    print_key_value "IPv6" "bestehende Einstellung beibehalten"
    if [ "${#ports[@]}" -eq 0 ]; then
        info "Keine Portfreigaben geplant."
    else
        info "Geplante Freigaben:"
        print_array_lines "${ports[@]}"
    fi
}

fix_setup_ufw() {
    section "UFW Basis"
    need_root

    if [ "${#DETECTED_PROFILES[@]}" -eq 0 ] && [ "${#DETECTED_COMPONENTS[@]}" -eq 0 ]; then
        detect_services >/dev/null 2>&1
    fi

    if ! cmd_exists ufw; then
        bad "ufw ist nicht installiert."
        return
    fi

    local ports=()
    local port
    while IFS= read -r port; do
        [ -n "$port" ] && ports+=("$port")
    done < <(build_ufw_port_plan)

    show_ufw_plan
    confirm_fix_action "Diese UFW-Basisregeln anwenden?" || {
        info "UFW-Konfiguration abgebrochen."
        return
    }

    local backup_files=("/etc/default/ufw" "/etc/ufw/user.rules" "/etc/ufw/user6.rules")
    local file backup backups=()
    for file in "${backup_files[@]}"; do
        [ -f "$file" ] || continue
        backup="$(safe_backup "$file")" || {
            bad "Backup fehlgeschlagen: $file"
            rollback_ufw_backups "${backups[@]}"
            return
        }
        backups+=("$backup::$file")
        ok "Backup erstellt: $backup"
    done

    if ! ufw default deny incoming >/dev/null 2>&1; then
        bad "UFW Default deny incoming fehlgeschlagen."
        rollback_ufw_backups "${backups[@]}"
        return
    fi
    if ! ufw default allow outgoing >/dev/null 2>&1; then
        bad "UFW Default allow outgoing fehlgeschlagen."
        rollback_ufw_backups "${backups[@]}"
        return
    fi
    ok "UFW Default-Regeln gesetzt."

    for port in "${ports[@]}"; do
        if ufw_rule_exists "$port"; then
            info "Regel bereits vorhanden: $port"
            continue
        fi
        if ! ufw allow "$port" >/dev/null 2>&1; then
            bad "Portfreigabe fehlgeschlagen: $port"
            rollback_ufw_backups "${backups[@]}"
            return
        fi
        ok "Freigabe gesetzt: $port"
    done

    if ! printf 'y\n' | ufw enable >/dev/null 2>&1; then
        bad "UFW konnte nicht aktiviert werden."
        rollback_ufw_backups "${backups[@]}"
        return
    fi
    ok "UFW ist aktiviert."

    if ! validate_command "UFW Statuspruefung" ufw status; then
        rollback_ufw_backups "${backups[@]}"
        return
    fi
}

rollback_ufw_backups() {
    local entry backup target
    for entry in "$@"; do
        backup="${entry%%::*}"
        target="${entry##*::}"
        restore_backup "$backup" "$target" && info "Backup wiederhergestellt: $target"
    done
}
