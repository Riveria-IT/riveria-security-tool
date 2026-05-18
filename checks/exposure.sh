#!/usr/bin/env bash

exposure_http_probe() {
    local base_url="$1"
    local path="$2"
    [ -n "$base_url" ] || return 0
    get_http_code "${base_url}${path}"
}

run_exposure_checks() {
    section "Sensitive Exposure"

    local roots=("/var/www" "/srv" "/opt")
    local env_hits base_public_url env_http_code env_http_target
    base_public_url="$(printf '%s\n' "$PUBLIC_WEB_URL" | sed -E 's#^([a-zA-Z]+://[^/]+).*#\1#')"
    env_hits="$(find "${roots[@]}" -maxdepth 4 \( -name '.env' -o -name '.env.local' -o -name '.env.production' -o -name '.env.backup' \) 2>/dev/null | head -n 20 || true)"
    if [ -n "$env_hits" ]; then
        env_http_target=""
        env_http_code=""
        if [ -n "$base_public_url" ]; then
            env_http_target="$base_public_url/.env"
            env_http_code="$(get_http_code "$env_http_target")"
        fi

        case "$env_http_code" in
            200)
                register_issue "EXP-001" ".env ueber HTTP erreichbar" "KRITISCH" \
                    "Eine .env-Datei wurde gefunden und die Basis-URL liefert fuer /.env einen HTTP-200-Hinweis." \
                    "Webroot sofort absichern, Dotfiles blockieren und Inhalte niemals ausgeben." "GUIDED" "no"
                bad ".env-Hinweis mit HTTP 200 erkannt."
                ;;
            403)
                register_issue "EXP-002" ".env gefunden, Zugriff geblockt" "WARNUNG" \
                    "Eine .env-Datei wurde gefunden. HTTP liefert fuer /.env einen 403-Hinweis." \
                    "Block-Regeln und Webroot-Struktur trotzdem manuell pruefen." "GUIDED" "no"
                warn ".env gefunden, HTTP-Zugriff wirkt geblockt (403)."
                ;;
            404)
                info ".env gefunden, HTTP-Basischeck liefert 404."
                ;;
            *)
                register_issue "EXP-003" ".env Datei im Suchbereich gefunden" "WARNUNG" \
                    "Eine .env-Datei wurde in einem typischen Projektpfad gefunden. Inhalt wird nicht angezeigt." \
                    "Webroot und HTTP-Erreichbarkeit manuell pruefen." "GUIDED" "no"
                warn ".env-Dateien gefunden. Inhalte werden absichtlich nicht angezeigt."
                ;;
        esac
        printf '%s\n' "$env_hits"
    else
        ok "Keine .env-Dateien in der Basispruefung gefunden."
    fi

    local risky_files
    risky_files="$(find "${roots[@]}" -maxdepth 5 -type f \( -name '*.sql' -o -name '*.bak' -o -name '*.old' -o -name '*.backup' -o -name '*.zip' -o -name '*.tar' -o -name '*.tar.gz' -o -name 'id_rsa' -o -name 'id_dsa' -o -name '*.pem' -o -name '*.key' -o -name 'wp-config.php.bak' \) 2>/dev/null | head -n 20 || true)"
    if [ -n "$risky_files" ]; then
        register_issue "EXP-004" "Quarantaene-Kandidaten gefunden" "WARNUNG" \
            "Es wurden Backup-, Dump- oder Schluesseldateien in typischen Projektpfaden gefunden." \
            "Pruefen, ob diese Dateien aktiv benoetigt werden. Unnoetige Funde in Quarantaene verschieben." "GUIDED" "yes"
        register_fix "FIX-QUAR-001" "Gefaehrliche Altdateien in Quarantaene verschieben" \
            "Backup-, Dump- oder Schluesseldateien liegen im Projektbereich" "GUIDED" "QUARANTINE_DIR Zeitstempelordner" \
            "Dateien kontrolliert verschieben, nicht loeschen" "Existenz im Zielordner pruefen" "kein Reload" \
            "Suchpfade erneut pruefen" "fix_quarantine_sensitive_files" "WARNUNG"
        warn "Quarantaene-Kandidaten gefunden."
        printf '%s\n' "$risky_files"
    else
        ok "Keine typischen Quarantaene-Kandidaten gefunden."
    fi

    local exposed_markers
    exposed_markers="$(find "${roots[@]}" -maxdepth 4 \( -type f \( -name 'phpinfo.php' -o -name 'info.php' -o -name 'test.php' -o -name 'debug.php' -o -name 'adminer.php' -o -name 'composer.json' -o -name 'composer.lock' -o -name 'config.inc.php' -o -name 'database.php' -o -name 'settings.php' \) -o -type d \( -name '.git' -o -name 'phpmyadmin' -o -name 'vendor' -o -name 'storage' -o -name 'logs' -o -name 'config' -o -name 'database' \) \) 2>/dev/null | head -n 20 || true)"
    if [ -n "$exposed_markers" ]; then
        register_issue "EXP-005" "Potenziell exponierte Dateien oder Verzeichnisse gefunden" "WARNUNG" \
            "Im Projektbereich wurden Dateien oder Ordner gefunden, die bei falschem Webroot problematisch sein koennen." \
            "HTTP-Erreichbarkeit und Webroot-Struktur manuell pruefen." "MANUAL" "no"
        warn "Potenziell exponierte Dateien oder Verzeichnisse gefunden."
        printf '%s\n' "$exposed_markers"
    else
        ok "Keine typischen Expositions-Marker gefunden."
    fi

    if [ -n "$base_public_url" ]; then
        local probe_paths=("/phpinfo.php" "/info.php" "/test.php" "/debug.php" "/adminer.php" "/composer.json" "/composer.lock" "/.git/config")
        local dir_probe_paths=("/phpmyadmin/" "/vendor/" "/storage/" "/logs/" "/config/" "/database/")
        local probe_path probe_code any_http_exposure=0
        for probe_path in "${probe_paths[@]}"; do
            probe_code="$(exposure_http_probe "$base_public_url" "$probe_path")"
            case "$probe_code" in
                200)
                    any_http_exposure=1
                    register_issue "EXP-006" "HTTP-exponierter Sensitiv-Pfad erkannt" "KRITISCH" \
                        "Die Basispruefung liefert fuer mindestens einen sensiblen Pfad HTTP 200." \
                        "Betroffenen Pfad sofort absichern oder entfernen." "GUIDED" "no"
                    bad "HTTP 200 fuer sensiblen Pfad: $probe_path"
                    ;;
                403)
                    info "HTTP 403 fuer sensiblen Pfad: $probe_path"
                    ;;
                404|000)
                    ;;
                *)
                    info "HTTP $probe_code fuer $probe_path"
                    ;;
            esac
        done

        for probe_path in "${dir_probe_paths[@]}"; do
            probe_code="$(exposure_http_probe "$base_public_url" "$probe_path")"
            case "$probe_code" in
                200|301|302)
                    any_http_exposure=1
                    register_issue "EXP-007" "Potenziell exponiertes Verzeichnis ueber HTTP erkannt" "WARNUNG" \
                        "Die Basispruefung liefert fuer mindestens ein sensibles Verzeichnis einen HTTP-Hinweis." \
                        "Directory Exposure und Reverse-Proxy-Regeln manuell pruefen." "MANUAL" "no"
                    warn "HTTP-Hinweis fuer sensibles Verzeichnis: $probe_path ($probe_code)"
                    ;;
                403)
                    info "HTTP 403 fuer sensibles Verzeichnis: $probe_path"
                    ;;
                404|000)
                    ;;
                *)
                    info "HTTP $probe_code fuer Verzeichnis $probe_path"
                    ;;
            esac
        done
        [ "$any_http_exposure" -eq 0 ] && ok "Keine sensiblen Standardpfade mit HTTP 200 erkannt."
    fi
}
