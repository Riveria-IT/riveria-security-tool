#!/usr/bin/env bash

active_test_http_code() {
    local url="$1"
    local method="${2:-GET}"

    if cmd_exists curl; then
        curl -k -s -o /dev/null -w '%{http_code}' -X "$method" "$url" 2>/dev/null
    else
        printf '000'
    fi
}

active_test_find_first_responsive_path() {
    local base_url="$1"
    shift
    local path code

    for path in "$@"; do
        code="$(active_test_http_code "${base_url}${path}")"
        case "$code" in
            200|301|302|401|403|405)
                printf '%s' "$path"
                return 0
                ;;
        esac
    done
    return 1
}

active_test_target_is_local() {
    local host
    [ -n "${PUBLIC_WEB_URL:-}" ] || return 1
    host="$(extract_host_from_url "$PUBLIC_WEB_URL")"
    case "$host" in
        localhost|127.0.0.1|::1)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

run_active_security_checks() {
    section "Aktive Sicherheitspruefung (safe)"
    AUDIT_MODE_ACTIVE_SAFE_STATUS="ausgefuehrt"

    if ! cmd_exists curl; then
        warn "curl ist fuer aktive Sicherheitspruefungen nicht verfuegbar."
        return
    fi

    if [ -z "$PUBLIC_WEB_URL" ]; then
        info "PUBLIC_WEB_URL ist nicht gesetzt. Aktive Sicherheitspruefung wird uebersprungen."
        return
    fi

    local base_public_url headers trace_code path code missing_headers cookies insecure_cookies
    local exposed_sensitive_paths=() traversal_hits=() admin_hits=() upload_hits=() header_leaks=()
    local login_probe_target="" login_rate_codes=() login_rate_slowdown=0
    local probe_paths=(
        "/server-status"
        "/server-info"
        "/.git/HEAD"
        "/.env.bak"
        "/backup.zip"
        "/dump.sql"
        "/actuator/env"
        "/actuator/heapdump"
        "/debug/default/view"
        "/_profiler/"
        "/console/"
        "/.well-known/security.txt.bak"
    )
    local traversal_paths=(
        "/..%2f..%2fetc/passwd"
        "/%2e%2e/%2e%2e/etc/passwd"
        "/static/..%2f..%2fetc/passwd"
    )
    local admin_probe_paths=(
        "/login"
        "/signin"
        "/user/login"
        "/admin"
        "/admin/login"
        "/dashboard/login"
        "/wp-login.php"
        "/wp-admin/"
        "/phpmyadmin/"
        "/adminer.php"
    )
    local upload_probe_paths=(
        "/upload"
        "/uploads/"
        "/api/upload"
        "/file-upload"
        "/media/upload"
    )

    base_public_url="$(printf '%s\n' "$PUBLIC_WEB_URL" | sed -E 's#^([a-zA-Z]+://[^/]+).*#\1#')"
    info "Es werden nur kontrollierte Lese-Requests gesendet."
    info "Keine Schreibzugriffe, keine Exploits, keine Brute-Force-Last."

    for path in "${probe_paths[@]}"; do
        code="$(active_test_http_code "${base_public_url}${path}")"
        case "$code" in
            200)
                exposed_sensitive_paths+=("${path} (${code})")
                bad "Aktiver Probe-Treffer: $path"
                ;;
            401|403)
                info "Sensitiver Pfad reagiert, wirkt aber geschuetzt: $path ($code)"
                ;;
        esac
    done

    if [ "${#exposed_sensitive_paths[@]}" -gt 0 ]; then
        register_issue "ACT-001" "Aktive Probe fand offen reagierende Sensitiv-Pfade" "KRITISCH" \
            "Mindestens ein sensibler Standardpfad antwortete in der aktiven Sicherheitspruefung direkt mit HTTP 200." \
            "Betroffene Pfade sofort absichern, entfernen oder ueber den Reverse Proxy blockieren." "GUIDED" "no"
    else
        ok "Keine offen reagierenden Sensitiv-Pfade in der aktiven Sicherheitspruefung erkannt."
    fi

    for path in "${traversal_paths[@]}"; do
        code="$(active_test_http_code "${base_public_url}${path}")"
        case "$code" in
            000|400|403|404)
                ;;
            *)
                traversal_hits+=("${path} (${code})")
                warn "Traversal-Probe reagiert ungewoehnlich: $path ($code)"
                ;;
        esac
    done

    if [ "${#traversal_hits[@]}" -gt 0 ]; then
        register_issue "ACT-002" "Traversal-Probe reagiert ungewoehnlich" "WARNUNG" \
            "Eine kontrollierte Pfad-Traversal-Probe wurde nicht sauber mit 400, 403 oder 404 beantwortet." \
            "Rewrite-Regeln, App-Routing und Upstream-Validierung fuer Traversal-Schutz pruefen." "MANUAL" "no"
    else
        ok "Traversal-Probes wurden unauffaellig beantwortet."
    fi

    for path in "${admin_probe_paths[@]}"; do
        code="$(active_test_http_code "${base_public_url}${path}")"
        case "$code" in
            200|301|302)
                admin_hits+=("${path} (${code})")
                info "Admin-/Login-Pfad reagiert direkt: $path ($code)"
                ;;
            401|403)
                info "Admin-/Login-Pfad wirkt geschuetzt: $path ($code)"
                ;;
        esac
    done

    if [ "${#admin_hits[@]}" -gt 0 ]; then
        register_issue "ACT-006" "Admin- oder Login-Pfade reagieren direkt" "WARNUNG" \
            "Mindestens ein typischer Login- oder Admin-Pfad reagierte in der aktiven Probe direkt mit einer offenen Antwort oder Weiterleitung." \
            "Pruefen, ob Rate-Limits, MFA, Fail2ban, IP-Schutz oder Reverse-Proxy-Regeln passend gesetzt sind." "MANUAL" "no"
    else
        ok "Keine direkt reagierenden Standard-Adminpfade in der Basispruefung erkannt."
    fi

    login_probe_target="$(active_test_find_first_responsive_path "$base_public_url" \
        "/login" "/signin" "/user/login" "/admin/login" "/dashboard/login" "/wp-login.php" || true)"
    if [ -n "$login_probe_target" ]; then
        local probe_no
        for probe_no in 1 2 3; do
            code="$(active_test_http_code "${base_public_url}${login_probe_target}?riveria-rate-test=${probe_no}")"
            login_rate_codes+=("$code")
            case "$code" in
                401|403|429)
                    login_rate_slowdown=1
                    ;;
            esac
        done

        if [ "$login_rate_slowdown" -eq 0 ]; then
            register_issue "ACT-009" "Kein klares Login-Rate-Limit in Basisprobe sichtbar" "WARNUNG" \
                "Drei sehr kleine kontrollierte Login-Probes auf einen reagierenden Login-Pfad zeigten keine erkennbare Bremswirkung wie 401, 403 oder 429." \
                "Login-Schutz, WAF, Reverse-Proxy-Limits und Fail2ban fuer Login-Endpunkte gezielt pruefen." "MANUAL" "no"
            warn "Login-Probe zeigt keine klare Bremswirkung: $login_probe_target (${login_rate_codes[*]})"
        else
            ok "Login-Probe zeigt eine erkennbare Schutzreaktion."
        fi
    else
        info "Kein passender Login-Pfad fuer eine vorsichtige Rate-Limit-Probe erkannt."
    fi

    for path in "${upload_probe_paths[@]}"; do
        code="$(active_test_http_code "${base_public_url}${path}")"
        case "$code" in
            200|201|301|302|401|403|405)
                upload_hits+=("${path} (${code})")
                info "Moeglicher Upload-Pfad reagiert: $path ($code)"
                ;;
        esac
    done

    if [ "${#upload_hits[@]}" -gt 0 ]; then
        register_issue "ACT-007" "Moegliche Upload-Endpunkte reagieren" "WARNUNG" \
            "Ein oder mehrere typische Upload-Pfade reagierten in der aktiven Probe." \
            "Upload-Validierung, Dateiendungen, Speicherpfade und Web-Zugriff auf Uploads manuell pruefen." "MANUAL" "no"
    else
        ok "Keine typischen Upload-Pfade in der aktiven Basispruefung erkannt."
    fi

    headers="$(get_headers "$PUBLIC_WEB_URL")"
    missing_headers=()
    if [ -n "$headers" ]; then
        printf '%s\n' "$headers" | grep -qi '^x-frame-options:' || missing_headers+=("X-Frame-Options")
        printf '%s\n' "$headers" | grep -qi '^x-content-type-options:' || missing_headers+=("X-Content-Type-Options")
        printf '%s\n' "$headers" | grep -qi '^referrer-policy:' || missing_headers+=("Referrer-Policy")
        if ! printf '%s\n' "$headers" | grep -qi '^content-security-policy:' \
            && ! printf '%s\n' "$headers" | grep -qi '^content-security-policy-report-only:'; then
            missing_headers+=("Content-Security-Policy")
        fi
        if printf '%s\n' "$headers" | grep -Eqi '^server:[[:space:]].*[0-9]+\.[0-9]+'; then
            header_leaks+=("Server-Header mit Versionsangabe")
        fi
        if printf '%s\n' "$headers" | grep -Eqi '^x-powered-by:'; then
            header_leaks+=("X-Powered-By")
        fi
        if printf '%s\n' "$headers" | grep -Eqi '^via:'; then
            header_leaks+=("Via")
        fi
        if printf '%s\n' "$headers" | grep -Eqi '^x-aspnet-version:|^x-runtime:|^x-generator:'; then
            header_leaks+=("Framework-/Runtime-Header")
        fi
    fi

    if [ "${#missing_headers[@]}" -gt 0 ]; then
        register_issue "ACT-003" "Wichtige Sicherheitsheader fehlen in aktiver Probe" "WARNUNG" \
            "Die aktive Header-Pruefung fand fehlende Sicherheitsheader in der HTTP-Antwort." \
            "Webserver-Header, Reverse-Proxy-Snippets und App-Antworten auf konsistente Schutzheader pruefen." "GUIDED" "no"
        warn "Fehlende Sicherheitsheader erkannt: $(printf '%s, ' "${missing_headers[@]}" | sed 's/, $//')"
    else
        ok "Wichtige Sicherheitsheader reagieren in der Basispruefung unauffaellig."
    fi

    insecure_cookies=()
    if [ -n "$headers" ]; then
        while IFS= read -r cookies; do
            [ -n "$cookies" ] || continue
            if ! printf '%s\n' "$cookies" | grep -qi ';[[:space:]]*HttpOnly\b'; then
                insecure_cookies+=("HttpOnly fehlt")
            fi
            if printf '%s\n' "$PUBLIC_WEB_URL" | grep -qi '^https://' && ! printf '%s\n' "$cookies" | grep -qi ';[[:space:]]*Secure\b'; then
                insecure_cookies+=("Secure fehlt")
            fi
            if ! printf '%s\n' "$cookies" | grep -qi ';[[:space:]]*SameSite='; then
                insecure_cookies+=("SameSite fehlt")
            fi
        done < <(printf '%s\n' "$headers" | grep -i '^set-cookie:' || true)
    fi

    if [ "${#insecure_cookies[@]}" -gt 0 ]; then
        register_issue "ACT-004" "Unsichere Cookie-Flags in aktiver Probe" "WARNUNG" \
            "Mindestens ein per HTTP sichtbares Cookie fehlt bei den erwartbaren Schutzflags." \
            "Session-Cookies auf HttpOnly, Secure und SameSite pruefen und zentral haerten." "GUIDED" "no"
        warn "Unsichere Cookie-Flags erkannt."
    else
        ok "Keine auffaelligen Cookie-Flags in der aktiven Basispruefung erkannt."
    fi

    if [ "${#header_leaks[@]}" -gt 0 ]; then
        register_issue "ACT-008" "Antwort-Header verraten technische Details" "WARNUNG" \
            "Die aktive Probe fand Header, die unnoetig Backend-, Proxy- oder Runtime-Details preisgeben." \
            "Server-, Proxy- und Framework-Header pruefen und unnoetige Details unterdruecken." "GUIDED" "no"
        warn "Technische Header-Leaks erkannt: $(printf '%s, ' "${header_leaks[@]}" | sed 's/, $//')"
    else
        ok "Keine auffaelligen technischen Header-Leaks in der Basispruefung erkannt."
    fi

    trace_code="$(active_test_http_code "$PUBLIC_WEB_URL" "TRACE")"
    case "$trace_code" in
        200|204)
            register_issue "ACT-005" "TRACE-Methode reagiert erfolgreich" "WARNUNG" \
                "Die aktive Probe erhielt auf einen TRACE-Request eine erfolgreiche Antwort." \
                "TRACE am Webserver oder Reverse Proxy deaktivieren." "GUIDED" "no"
            warn "TRACE reagiert erfolgreich: HTTP $trace_code"
            ;;
        *)
            ok "TRACE reagiert nicht erfolgreich."
            ;;
    esac
}

run_lab_validation_checks() {
    section "Lab-Validierungsmodus (lokal)"
    AUDIT_MODE_LAB_LOCAL_STATUS="ausgefuehrt"

    if ! cmd_exists curl; then
        warn "curl ist fuer den Lab-Validierungsmodus nicht verfuegbar."
        return
    fi

    if [ -z "$PUBLIC_WEB_URL" ]; then
        info "PUBLIC_WEB_URL ist nicht gesetzt. Lab-Validierungsmodus wird uebersprungen."
        return
    fi

    if ! active_test_target_is_local; then
        warn "Lab-Validierungsmodus ist nur fuer localhost, 127.0.0.1 oder ::1 erlaubt."
        warn "Fuer externe Ziele bitte den normalen Safe-Modus verwenden."
        return
    fi

    case "${LAB_VALIDATION_AUTO_CONFIRM:-0}" in
        1|true|TRUE|yes|YES|on|ON)
            ;;
        *)
            warn "Dieser Modus ist nur fuer lokale Testziele gedacht."
            warn "Er sendet mehr lokale Validierungs-Requests als der normale Safe-Modus."
            if ! ask_yes_no "Lokalen Lab-Validierungsmodus jetzt wirklich starten?"; then
                info "Lab-Validierungsmodus abgebrochen."
                return
            fi
            ;;
    esac

    local base_public_url method_code path code
    local method_hits=() debug_hits=() error_hits=()
    local local_probe_paths=(
        "/debug"
        "/__debug__/"
        "/_debugbar/"
        "/_ignition/"
        "/actuator/"
        "/swagger/"
        "/openapi.json"
    )
    local error_probe_paths=(
        "/this-should-not-exist-riveria"
        "/.git/this-should-not-exist"
        "/broken%2f..%2f..%2fetc/passwd"
    )

    base_public_url="$(printf '%s\n' "$PUBLIC_WEB_URL" | sed -E 's#^([a-zA-Z]+://[^/]+).*#\1#')"
    info "Lokaler Lab-Modus aktiv. Es werden nur nicht-destruktive Requests gesendet."
    info "Keine Passwortversuche, keine Schreibzugriffe, keine Payload-Ausfuehrung."

    for path in "${local_probe_paths[@]}"; do
        code="$(active_test_http_code "${base_public_url}${path}")"
        case "$code" in
            200|301|302)
                debug_hits+=("${path} (${code})")
                warn "Lokaler Debug-/Hilfspfad reagiert: $path ($code)"
                ;;
        esac
    done

    if [ "${#debug_hits[@]}" -gt 0 ]; then
        register_issue "ACT-010" "Lokale Debug- oder Hilfspfade reagieren im Lab-Modus" "WARNUNG" \
            "Im lokalen Lab-Modus reagierten typische Debug-, Actuator- oder Doku-Pfade direkt." \
            "Debug-Werkzeuge, Swagger, Actuator oder Entwicklerhilfen fuer Produktion und Reverse Proxy bewusst absichern." "MANUAL" "no"
    else
        ok "Keine lokalen Debug- oder Hilfspfade mit direkter Reaktion erkannt."
    fi

    method_code="$(active_test_http_code "$PUBLIC_WEB_URL" "OPTIONS")"
    case "$method_code" in
        200|204)
            method_hits+=("OPTIONS (${method_code})")
            warn "OPTIONS reagiert erfolgreich: HTTP $method_code"
            ;;
    esac

    method_code="$(active_test_http_code "$PUBLIC_WEB_URL" "HEAD")"
    case "$method_code" in
        200|204|301|302)
            ;;
        *)
            error_hits+=("HEAD (${method_code})")
            warn "HEAD reagiert ungewoehnlich: HTTP $method_code"
            ;;
    esac

    if [ "${#method_hits[@]}" -gt 0 ]; then
        register_issue "ACT-011" "Zusatzmethoden reagieren im lokalen Lab-Modus" "WARNUNG" \
            "Im lokalen Lab-Modus antworteten zusaetzliche HTTP-Methoden wie OPTIONS erfolgreich." \
            "Erlaubte Methoden, CORS, Reverse-Proxy-Weiterleitung und App-Router bewusst pruefen." "MANUAL" "no"
    else
        ok "Keine auffaelligen Zusatzmethoden im lokalen Lab-Modus erkannt."
    fi

    for path in "${error_probe_paths[@]}"; do
        code="$(active_test_http_code "${base_public_url}${path}")"
        case "$code" in
            500|502|503)
                error_hits+=("${path} (${code})")
                warn "Fehlerantwort auf lokalen Sonderpfad: $path ($code)"
                ;;
        esac
    done

    if [ "${#error_hits[@]}" -gt 0 ]; then
        register_issue "ACT-012" "Lokaler Lab-Modus erzeugt unerwartete Fehlerantworten" "WARNUNG" \
            "Einige lokale Sonderpfade oder Methoden fuehrten zu 5xx-Antworten statt zu einer sauberen Ablehnung." \
            "Error-Handling, Router-Schutz und Reverse-Proxy-Regeln fuer Sonderpfade pruefen." "MANUAL" "no"
    else
        ok "Lokale Sonderpfade und Zusatzmethoden wurden ohne 5xx-Fehler beantwortet."
    fi
}
