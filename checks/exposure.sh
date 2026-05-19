#!/usr/bin/env bash

exposure_http_probe() {
    local base_url="$1"
    local path="$2"
    [ -n "$base_url" ] || return 0
    get_http_code "${base_url}${path}"
}

webroot_sensitive_http_probe() {
    local base_url="$1"
    local file="$2"
    local rel_path

    rel_path="$(webroot_relative_path "$file")" || return 1
    exposure_http_probe "$base_url" "$rel_path"
}

collect_sensitive_webroot_candidates() {
    local webroot

    detect_webroots
    for webroot in "${DETECTED_WEBROOTS[@]}"; do
        [ -d "$webroot" ] || continue
        find "$webroot" -maxdepth 5 \
            \( -type f \( \
                -name '.env' -o -name '.env.local' -o -name '.env.production' -o -name '.env.backup' -o \
                -name 'phpinfo.php' -o -name 'info.php' -o -name 'test.php' -o -name 'debug.php' -o -name 'adminer.php' -o \
                -name 'composer.json' -o -name 'composer.lock' -o -name 'config.php' -o -name 'config.inc.php' -o -name 'database.php' -o -name 'settings.php' -o \
                -name '*.bak' -o -name '*.backup' -o -name '*.old' -o -name '*.sql' -o -name '*.zip' -o -name '*.tar' -o -name '*.tar.gz' \
            \) \) -o \
            \( -type d \( -name '.git' -o -name 'vendor' -o -name 'storage' -o -name 'logs' -o -name 'config' -o -name 'database' -o -name 'phpmyadmin' \) \) \
            2>/dev/null | head -n 40 || true
    done
}

run_webroot_direct_exposure_checks() {
    local base_public_url="$1"
    local candidate rel_path code mode found_any=0 reachable_any=0 blocked_any=0

    [ -n "$base_public_url" ] || return 0

    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        rel_path="$(webroot_relative_path "$candidate" || true)"
        [ -n "$rel_path" ] || continue
        code="$(webroot_sensitive_http_probe "$base_public_url" "$candidate" || printf '000')"
        mode=""
        [ -f "$candidate" ] && mode="$(get_octal_mode "$candidate")"
        found_any=1

        case "$code" in
            200|301|302)
                reachable_any=1
                register_issue "EXP-010" "Sensible Webroot-Datei oder -Pfad direkt erreichbar" "KRITISCH" \
                    "Mindestens ein sensibler Pfad unter einem erkannten Webroot ist direkt ueber seinen echten relativen URL-Pfad erreichbar." \
                    "Datei oder Verzeichnis sofort per Webserver-Regel sperren, aus dem Webroot verschieben oder den Webroot enger schneiden." "GUIDED" "no"
                bad "Direkt erreichbar: ${rel_path} [HTTP ${code}]${mode:+ [Mode ${mode}]}"
                ;;
            403)
                blocked_any=1
                info "Geblockt: ${rel_path} [HTTP 403]${mode:+ [Mode ${mode}]}"
                ;;
            404|000)
                info "Nicht direkt sichtbar: ${rel_path} [HTTP ${code}]${mode:+ [Mode ${mode}]}"
                ;;
            *)
                blocked_any=1
                warn "Unklare Antwort fuer ${rel_path}: HTTP ${code}${mode:+ [Mode ${mode}]}"
                ;;
        esac
    done < <(collect_sensitive_webroot_candidates)

    if [ "$found_any" -eq 0 ]; then
        ok "Keine weiteren sensiblen Einzelpfade im Webroot fuer Direktprobe gefunden."
        return 0
    fi

    if [ "$blocked_any" -eq 1 ]; then
        register_issue "EXP-011" "Sensible Webroot-Pfade vorhanden, aber direkt geblockt" "WARNUNG" \
            "Sensible Dateien oder Verzeichnisse liegen unter dem Webroot, wirken per HTTP aktuell aber blockiert." \
            "Block-Regeln beibehalten, Webroot-Struktur trotzdem weiter entschlacken und sensible Pfade moeglichst aus dem ausliefernden Bereich verschieben." "GUIDED" "no"
        warn "Sensible Webroot-Pfade wirken geblockt, liegen aber im ausliefernden Bereich."
    fi
}

run_exposure_checks() {
    section "Sensitive Exposure"

    local roots=("/var/www" "/srv" "/opt")
    local env_hits env_hits_in_webroot base_public_url env_http_code env_http_target
    detect_webroots
    print_webroot_summary
    base_public_url="$(printf '%s\n' "$PUBLIC_WEB_URL" | sed -E 's#^([a-zA-Z]+://[^/]+).*#\1#')"
    env_hits="$(find "${roots[@]}" -maxdepth 4 \( -name '.env' -o -name '.env.local' -o -name '.env.production' -o -name '.env.backup' \) 2>/dev/null | head -n 20 || true)"
    if [ -n "$env_hits" ]; then
        env_hits_in_webroot=""
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            if path_is_under_webroot "$file"; then
                env_hits_in_webroot="${env_hits_in_webroot}${file}"$'\n'
            fi
        done <<EOF
$env_hits
EOF
        env_http_target=""
        env_http_code=""
        if [ -n "$base_public_url" ]; then
            env_http_target="$base_public_url/.env"
            env_http_code="$(get_http_code "$env_http_target")"
        fi

        if [ -n "$env_hits_in_webroot" ]; then
            case "$env_http_code" in
                200)
                    register_issue "EXP-001" ".env ueber HTTP erreichbar" "KRITISCH" \
                        "Eine .env-Datei liegt unter einem erkannten Webroot und die Basis-URL liefert fuer /.env einen HTTP-200-Hinweis." \
                        "Webroot sofort absichern, Dotfiles blockieren und Inhalte niemals ausgeben." "GUIDED" "no"
                    bad ".env-Hinweis mit HTTP 200 erkannt."
                    ;;
                403)
                    register_issue "EXP-002" ".env im Webroot gefunden, Zugriff geblockt" "WARNUNG" \
                        "Eine .env-Datei liegt unter einem erkannten Webroot. HTTP liefert fuer /.env einen 403-Hinweis." \
                        "Block-Regeln und Webroot-Struktur trotzdem manuell pruefen." "GUIDED" "no"
                    warn ".env im Webroot gefunden, HTTP-Zugriff wirkt geblockt (403)."
                    ;;
                404)
                    register_issue "EXP-003" ".env liegt unter Webroot" "WARNUNG" \
                        "Eine .env-Datei liegt unter einem erkannten Webroot, auch wenn der Basischeck aktuell 404 liefert." \
                        "Datei aus dem Webroot entfernen oder Verzeichnisstruktur absichern." "GUIDED" "no"
                    warn ".env liegt unter einem erkannten Webroot."
                    ;;
                *)
                    register_issue "EXP-003" ".env liegt unter Webroot" "WARNUNG" \
                        "Eine .env-Datei liegt unter einem erkannten Webroot. Die HTTP-Erreichbarkeit ist nicht eindeutig." \
                        "Datei aus dem Webroot entfernen oder Verzeichnisstruktur absichern." "GUIDED" "no"
                    warn ".env liegt unter einem erkannten Webroot."
                    ;;
            esac
        else
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
                    register_issue "EXP-008" ".env Datei im Projektbereich gefunden" "WARNUNG" \
                        "Eine .env-Datei wurde ausserhalb erkannter Webroots in einem typischen Projektpfad gefunden. Inhalt wird nicht angezeigt." \
                        "Webroot und HTTP-Erreichbarkeit manuell pruefen." "GUIDED" "no"
                    warn ".env-Dateien im Projektbereich gefunden. Inhalte werden absichtlich nicht angezeigt."
                    ;;
            esac
        fi
        printf '%s\n' "$env_hits"
    else
        ok "Keine .env-Dateien in der Basispruefung gefunden."
    fi

    local risky_files risky_files_in_webroot
    risky_files="$(find "${roots[@]}" -maxdepth 5 -type f \( -name '*.sql' -o -name '*.bak' -o -name '*.old' -o -name '*.backup' -o -name '*.zip' -o -name '*.tar' -o -name '*.tar.gz' -o -name 'id_rsa' -o -name 'id_dsa' -o -name '*.pem' -o -name '*.key' -o -name 'wp-config.php.bak' \) 2>/dev/null | head -n 20 || true)"
    if [ -n "$risky_files" ]; then
        risky_files_in_webroot=""
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            if path_is_under_webroot "$file"; then
                risky_files_in_webroot="${risky_files_in_webroot}${file}"$'\n'
            fi
        done <<EOF
$risky_files
EOF
        register_issue "EXP-004" "Quarantaene-Kandidaten gefunden" "WARNUNG" \
            "Es wurden Backup-, Dump- oder Schluesseldateien in typischen Projektpfaden gefunden." \
            "Pruefen, ob diese Dateien aktiv benoetigt werden. Unnoetige Funde in Quarantaene verschieben." "GUIDED" "yes"
        register_fix "FIX-QUAR-001" "Gefaehrliche Altdateien in Quarantaene verschieben" \
            "Backup-, Dump- oder Schluesseldateien liegen im Projektbereich" "GUIDED" "QUARANTINE_DIR Zeitstempelordner" \
            "Dateien kontrolliert verschieben, nicht loeschen" "Existenz im Zielordner pruefen" "kein Reload" \
            "Suchpfade erneut pruefen" "fix_quarantine_sensitive_files" "WARNUNG"
        if [ -n "$risky_files_in_webroot" ]; then
            bad "Quarantaene-Kandidaten liegen direkt unter einem erkannten Webroot."
        else
            warn "Quarantaene-Kandidaten gefunden."
        fi
        printf '%s\n' "$risky_files"
    else
        ok "Keine typischen Quarantaene-Kandidaten gefunden."
    fi

    local exposed_markers exposed_markers_in_webroot
    exposed_markers="$(find "${roots[@]}" -maxdepth 4 \( -type f \( -name 'phpinfo.php' -o -name 'info.php' -o -name 'test.php' -o -name 'debug.php' -o -name 'adminer.php' -o -name 'composer.json' -o -name 'composer.lock' -o -name 'config.inc.php' -o -name 'database.php' -o -name 'settings.php' \) -o -type d \( -name '.git' -o -name 'phpmyadmin' -o -name 'vendor' -o -name 'storage' -o -name 'logs' -o -name 'config' -o -name 'database' \) \) 2>/dev/null | head -n 20 || true)"
    if [ -n "$exposed_markers" ]; then
        exposed_markers_in_webroot=""
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            if path_is_under_webroot "$file"; then
                exposed_markers_in_webroot="${exposed_markers_in_webroot}${file}"$'\n'
            fi
        done <<EOF
$exposed_markers
EOF
        if [ -n "$exposed_markers_in_webroot" ]; then
            register_issue "EXP-005" "Potenziell exponierte Dateien oder Verzeichnisse im Webroot gefunden" "KRITISCH" \
                "Im erkannten Webroot wurden Dateien oder Ordner gefunden, die bei direkter Auslieferung problematisch sein koennen." \
                "Webroot-Struktur sofort pruefen und sensible Pfade aus dem ausliefernden Bereich entfernen." "GUIDED" "no"
            bad "Potenziell exponierte Dateien oder Verzeichnisse im Webroot gefunden."
        else
            register_issue "EXP-009" "Potenziell exponierte Dateien oder Verzeichnisse im Projektbereich gefunden" "WARNUNG" \
                "Im Projektbereich wurden Dateien oder Ordner gefunden, die bei falschem Webroot problematisch sein koennen." \
                "HTTP-Erreichbarkeit und Webroot-Struktur manuell pruefen." "MANUAL" "no"
            warn "Potenziell exponierte Dateien oder Verzeichnisse im Projektbereich gefunden."
        fi
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

        run_webroot_direct_exposure_checks "$base_public_url"
    fi
}
