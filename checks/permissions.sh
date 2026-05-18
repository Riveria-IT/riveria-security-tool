#!/usr/bin/env bash

run_permission_checks() {
    section "Rechte & Besitzer"
    local registered_perm_fix=0
    local registered_world_fix=0

    local world_writable
    world_writable="$(find /var/www /srv /opt -xdev -perm -0002 -print 2>/dev/null | head -n 20 || true)"
    if [ -n "$world_writable" ]; then
        register_issue "PERM-001" "World-writable Dateien oder Ordner gefunden" "WARNUNG" \
            "Mindestens ein Pfad ist fuer andere beschreibbar." \
            "Berechtigungen gezielt pruefen und unnoetige Schreibrechte entfernen." "GUIDED" "no"
        warn "World-writable Pfade gefunden."
        printf '%s\n' "$world_writable"
    else
        ok "Keine world-writable Pfade in der Basispruefung gefunden."
    fi

    local file mode found_sensitive=0
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        mode="$(get_octal_mode "$file")"
        case "$(basename "$file")" in
            .env)
                found_sensitive=1
                case "$mode" in
                    600) ok ".env sicher: $file ($mode)" ;;
                    640) ok ".env gut: $file ($mode)" ;;
                    644)
                        register_issue "PERM-002" ".env zu offen" "WARNUNG" \
                            "Eine .env-Datei ist fuer andere lesbar." \
                            "Auf 600 oder 640 reduzieren und Gruppenzuordnung pruefen." "AUTO-SAFE" "yes"
                        if [ "$registered_perm_fix" -eq 0 ]; then
                            register_fix "FIX-PERM-001" "Sensible Dateirechte haerten" \
                                ".env oder Konfigdateien haben zu offene Rechte" "AUTO-SAFE" "$file" \
                                "chmod 640/600 fuer sensible Dateien" "stat auf Zielpfaden" "kein Reload" \
                                "Dateirechte erneut pruefen" "fix_permissions_basics" "WARNUNG"
                            registered_perm_fix=1
                        fi
                        warn ".env mit offenen Rechten: $file ($mode)"
                        ;;
                    666|777)
                        register_issue "PERM-003" ".env kritisch offen" "KRITISCH" \
                            "Eine .env-Datei ist stark ueberberechtigt." \
                            "Sofort auf 600 oder 640 reduzieren." "AUTO-SAFE" "yes"
                        if [ "$registered_perm_fix" -eq 0 ]; then
                            register_fix "FIX-PERM-001" "Sensible Dateirechte haerten" \
                                ".env oder Konfigdateien haben zu offene Rechte" "AUTO-SAFE" "$file" \
                                "chmod 640/600 fuer sensible Dateien" "stat auf Zielpfaden" "kein Reload" \
                                "Dateirechte erneut pruefen" "fix_permissions_basics" "KRITISCH"
                            registered_perm_fix=1
                        fi
                        bad ".env kritisch offen: $file ($mode)"
                        ;;
                    *)
                        [ -n "$mode" ] && info ".env gefunden: $file ($mode)"
                        ;;
                esac
                ;;
            wp-config.php|config.php|config.inc.php|database.php|settings.php)
                found_sensitive=1
                case "$mode" in
                    600|640) ok "Konfigdatei solide: $file ($mode)" ;;
                    644)
                        register_issue "PERM-004" "Konfigdatei zu offen" "WARNUNG" \
                            "Eine sensible Konfigurationsdatei ist fuer andere lesbar." \
                            "Auf 600 oder 640 reduzieren." "AUTO-SAFE" "yes"
                        if [ "$registered_perm_fix" -eq 0 ]; then
                            register_fix "FIX-PERM-001" "Sensible Dateirechte haerten" \
                                "Konfigurationsdateien haben zu offene Rechte" "AUTO-SAFE" "$file" \
                                "chmod 640/600 fuer sensible Dateien" "stat auf Zielpfaden" "kein Reload" \
                                "Dateirechte erneut pruefen" "fix_permissions_basics" "WARNUNG"
                            registered_perm_fix=1
                        fi
                        warn "Konfigdatei mit offenen Rechten: $file ($mode)"
                        ;;
                esac
                ;;
            id_rsa|*.pem|*.key)
                found_sensitive=1
                case "$mode" in
                    600) ok "Schluesseldatei sicher: $file ($mode)" ;;
                    *)
                        register_issue "PERM-005" "Private Key zu offen" "KRITISCH" \
                            "Eine private Schluesseldatei hat unsichere Rechte." \
                            "Auf 600 reduzieren und Besitz pruefen." "AUTO-SAFE" "yes"
                        if [ "$registered_perm_fix" -eq 0 ]; then
                            register_fix "FIX-PERM-001" "Sensible Dateirechte haerten" \
                                "Schluessel- oder Konfigdateien haben zu offene Rechte" "AUTO-SAFE" "$file" \
                                "chmod 600 fuer private Keys, 640/600 fuer Configs" "stat auf Zielpfaden" "kein Reload" \
                                "Dateirechte erneut pruefen" "fix_permissions_basics" "KRITISCH"
                            registered_perm_fix=1
                        fi
                        bad "Private Key mit unsicheren Rechten: $file ($mode)"
                        ;;
                esac
                ;;
        esac
    done < <(permissions_collect_sensitive_files)

    if [ "$found_sensitive" -eq 0 ]; then
        info "Keine sensiblen Konfigurations- oder Schluesseldateien gefunden."
    fi

    local sensitive_world
    sensitive_world="$(find /var/www /srv /opt -xdev -type f -perm -0002 \( -name '.env' -o -name 'wp-config.php' -o -name 'config.php' -o -name 'config.inc.php' -o -name 'database.php' -o -name 'settings.php' -o -name 'id_rsa' -o -name '*.pem' -o -name '*.key' \) 2>/dev/null | head -n 20 || true)"
    if [ -n "$sensitive_world" ]; then
        register_issue "PERM-006" "Sensible Dateien world-writable" "KRITISCH" \
            "Mindestens eine sensible Datei ist fuer andere beschreibbar." \
            "Other-write entfernen und Besitz pruefen." "AUTO-SAFE" "yes"
        if [ "$registered_world_fix" -eq 0 ]; then
            register_fix "FIX-PERM-002" "Other-write auf sensiblen Dateien entfernen" \
                "Sensible Dateien sind fuer andere beschreibbar" "AUTO-SAFE" "betroffene Dateien" \
                "chmod o-w auf sensiblen Dateien" "stat auf Zielpfaden" "kein Reload" \
                "Dateirechte erneut pruefen" "fix_permissions_world_writable_configs" "KRITISCH"
            registered_world_fix=1
        fi
        bad "Sensible world-writable Dateien gefunden."
        printf '%s\n' "$sensitive_world"
    fi
}
