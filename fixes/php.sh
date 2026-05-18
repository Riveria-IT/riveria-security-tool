#!/usr/bin/env bash

fix_harden_php() {
    section "PHP Haertung"
    confirm_fix_action "PHP-Konfiguration sicher haerten?" || {
        info "PHP-Haertung abgebrochen."
        return
    }

    local ini_files=()
    local ini
    for ini in /etc/php/*/cli/php.ini /etc/php/*/fpm/php.ini /etc/php/*/apache2/php.ini; do
        [ -f "$ini" ] && ini_files+=("$ini")
    done

    if [ "${#ini_files[@]}" -eq 0 ]; then
        warn "Keine php.ini-Dateien in /etc/php gefunden."
        return
    fi

    if ! cmd_exists php; then
        warn "php CLI ist nicht verfuegbar. Validierung der php.ini ist nicht moeglich."
        return
    fi

    local backups=()
    for ini in "${ini_files[@]}"; do
        local backup
        backup="$(safe_backup "$ini")" || {
            bad "Backup fuer $ini fehlgeschlagen."
            return
        }
        backups+=("$backup::$ini")
        ok "Backup erstellt: $backup"

        set_ini_directive "$ini" "expose_php" "Off"
        set_ini_directive "$ini" "display_errors" "Off"
        set_ini_directive "$ini" "log_errors" "On"
        set_ini_directive "$ini" "session.cookie_secure" "1"
        set_ini_directive "$ini" "session.cookie_httponly" "1"
        set_ini_directive "$ini" "session.cookie_samesite" "Lax"
        set_ini_directive "$ini" "session.use_strict_mode" "1"
        set_ini_directive "$ini" "session.use_only_cookies" "1"
        ok "PHP-Haertung eingetragen: $ini"
    done

    for ini in "${ini_files[@]}"; do
        if ! php -c "$ini" -m >/dev/null 2>&1; then
            bad "PHP-Test fehlgeschlagen fuer $ini"
            rollback_php_backups "${backups[@]}"
            return
        fi
    done
    ok "PHP-Konfigurationstest erfolgreich."

    if ! reload_php_services; then
        rollback_php_backups "${backups[@]}"
        return
    fi

    info "PHP-Haertung abgeschlossen."
}

rollback_php_backups() {
    local entry backup ini
    for entry in "$@"; do
        backup="${entry%%::*}"
        ini="${entry##*::}"
        restore_backup "$backup" "$ini" && info "Backup wiederhergestellt: $ini"
    done
}

reload_php_services() {
    local restarted=0 service

    if cmd_exists systemctl; then
        for service in $(systemctl list-unit-files 'php*-fpm.service' --no-legend 2>/dev/null | awk '{print $1}'); do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                systemctl restart "$service" >/dev/null 2>&1 || {
                    bad "Neustart fehlgeschlagen: $service"
                    return 1
                }
                restarted=1
                ok "Neugestartet: $service"
            fi
        done

        reload_service_if_active nginx || true
        reload_service_if_active apache2 || true
        [ "$restarted" -eq 0 ] && info "Kein aktiver PHP-FPM-Dienst gefunden."
    fi

    return 0
}
