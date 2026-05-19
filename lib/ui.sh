#!/usr/bin/env bash

header() {
    printf '\n%s%s%s\n' "$COLOR_BOLD" "$APP_NAME" "$COLOR_RESET"
    printf '%sVersion:%s %s\n\n' "$COLOR_DIM" "$COLOR_RESET" "$APP_VERSION"
}

section() {
    printf '\n%s== %s ==%s\n' "$COLOR_BOLD" "$1" "$COLOR_RESET"
}

ok() {
    printf '%s[OK]%s %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$1"
}

info() {
    printf '%s[INFO]%s %s\n' "$COLOR_BLUE" "$COLOR_RESET" "$1"
}

warn() {
    printf '%s[WARNUNG]%s %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$1"
}

bad() {
    printf '%s[KRITISCH]%s %s\n' "$COLOR_RED" "$COLOR_RESET" "$1"
}

pause() {
    printf '\nEnter druecken zum Fortfahren... '
    read -r _
}

print_fix_step_header() {
    local current="$1"
    local total="$2"
    local title="$3"
    printf '\n%sSchritt %s von %s: %s%s\n' "$COLOR_BOLD" "$current" "$total" "$title" "$COLOR_RESET"
}

print_key_value() {
    printf '%-16s %s\n' "$1:" "$2"
}

print_status_box() {
    printf '\n%sScore:%s %s/100\n' "$COLOR_BOLD" "$COLOR_RESET" "$SCORE"
    printf '%sStatus:%s %s\n' "$COLOR_BOLD" "$COLOR_RESET" "$STATUS_LABEL"
    printf '%sOK:%s %s  %sWarnungen:%s %s  %sKritisch:%s %s\n' \
        "$COLOR_BOLD" "$COLOR_RESET" "$OK_COUNT" \
        "$COLOR_BOLD" "$COLOR_RESET" "$WARN_COUNT" \
        "$COLOR_BOLD" "$COLOR_RESET" "$CRIT_COUNT"
}

print_issue_summary() {
    local i

    section "Findings"
    if [ "${#ISSUE_IDS[@]}" -eq 0 ]; then
        ok "Keine Findings registriert."
        return
    fi

    for ((i=0; i<${#ISSUE_IDS[@]}; i++)); do
        if result_view_simple_enabled; then
            printf '%s[%s]%s %s\n' \
                "$COLOR_BOLD" "$(beginner_level_badge "${ISSUE_LEVELS[$i]}")" "$COLOR_RESET" "$(beginner_issue_text "${ISSUE_IDS[$i]}" "${ISSUE_TITLES[$i]}")"
            printf '  Prioritaet: %s\n' "$(beginner_level_text "${ISSUE_LEVELS[$i]}")"
            printf '  Naechster Schritt: %s\n' "$(beginner_recommendation_text "${ISSUE_IDS[$i]}" "${ISSUE_RECOMMENDATIONS[$i]}")"
            printf '  Fix-Typ: %s | Direkt machbar: %s\n' "$(beginner_fix_category_text "${ISSUE_FIX_CATEGORIES[$i]}")" "$(beginner_auto_fix_text "${ISSUE_CAN_FIX[$i]}")"
        else
            printf '%s[%s]%s %s - %s\n' \
                "$COLOR_BOLD" "${ISSUE_LEVELS[$i]}" "$COLOR_RESET" "${ISSUE_IDS[$i]}" "${ISSUE_TITLES[$i]}"
            printf '  %s\n' "${ISSUE_RECOMMENDATIONS[$i]}"
            printf '  Fix: %s | Auto: %s\n' "${ISSUE_FIX_CATEGORIES[$i]}" "${ISSUE_CAN_FIX[$i]}"
        fi
    done
}

print_fix_summary() {
    local i critical_count=0 warning_count=0

    section "Fix-Bereitschaft"
    if [ "${#FIX_IDS[@]}" -eq 0 ]; then
        info "Keine vorbereiteten Fixes verfuegbar."
        return
    fi

    for ((i=0; i<${#FIX_IDS[@]}; i++)); do
        case "${FIX_LEVELS[$i]}" in
            KRITISCH) critical_count=$((critical_count + 1)) ;;
            *) warning_count=$((warning_count + 1)) ;;
        esac
    done

    print_key_value "Vorbereitete Fixes" "${#FIX_IDS[@]}"
    print_key_value "Kritische Fixes" "$critical_count"
    print_key_value "Weitere Fixes" "$warning_count"
    info "Du kannst alle Fixes direkt ueber den Fix-Assistenten Schritt fuer Schritt anwenden."
}

beginner_level_badge() {
    local level="$1"
    case "$level" in
        KRITISCH) printf 'ROT' ;;
        WARNUNG) printf 'GELB' ;;
        OK) printf 'GRUEN' ;;
        *) printf '%s' "$level" ;;
    esac
}

beginner_level_text() {
    local level="$1"
    case "$level" in
        KRITISCH) printf 'sofort wichtig' ;;
        WARNUNG) printf 'bald pruefen' ;;
        OK) printf 'okay' ;;
        *) printf '%s' "$level" ;;
    esac
}

beginner_overall_badge() {
    if [ "$CRIT_COUNT" -gt 0 ]; then
        printf 'ROT'
    elif [ "$WARN_COUNT" -gt 0 ]; then
        printf 'GELB'
    else
        printf 'GRUEN'
    fi
}

beginner_overall_text() {
    if [ "$CRIT_COUNT" -gt 0 ]; then
        printf 'sofort wichtig'
    elif [ "$WARN_COUNT" -gt 0 ]; then
        printf 'bald pruefen'
    else
        printf 'okay'
    fi
}

beginner_issue_text() {
    local issue_id="$1"
    local title="$2"

    case "$issue_id" in
        SVC-001) printf 'Eine Datenbank ist direkt aus dem Internet erreichbar.' ;;
        SVC-002) printf 'Es gibt keinen erkennbaren Schutz gegen wiederholte Login-Angriffe.' ;;
        SVC-003) printf 'Root-Login ueber SSH ist noch erlaubt.' ;;
        SVC-004) printf 'PHP verraet zu viele technische Details.' ;;
        SVC-005) printf 'Die Firewall ist nicht installiert.' ;;
        SVC-006) printf 'Die Firewall ist vorhanden, aber noch nicht aktiv.' ;;
        SVC-007) printf 'Dem Webserver fehlen empfohlene Schutzregeln.' ;;
        SVC-008) printf 'Die Schutzregeln fuer den Webserver sind noch nicht eingebunden.' ;;
        SVC-009) printf 'Apache und nginx wurden gleichzeitig erkannt. Das sollte geprueft werden.' ;;
        SVC-010) printf 'SSH ist erreichbar. Das ist normal, sollte aber abgesichert sein.' ;;
        SVC-013) printf 'Ein unerwarteter Dienst ist von aussen erreichbar.' ;;
        SVC-014) printf 'Ein internes Web-Backend antwortet aktuell nicht.' ;;
        SVC-015) printf 'Ein erkanntes Proxy-Ziel ist aktuell nicht erreichbar.' ;;
        EXP-001) printf 'Eine sensible Datei ist direkt ueber das Web erreichbar.' ;;
        EXP-002|EXP-003) printf 'Eine sensible Datei liegt im Webbereich und sollte dort nicht liegen.' ;;
        EXP-004) printf 'Es wurden alte Backups oder Exportdateien gefunden.' ;;
        EXP-005|EXP-006|EXP-007|EXP-009|EXP-010) printf 'Im Webbereich liegen Dateien oder Ordner, die nicht offen sichtbar sein sollten.' ;;
        EXP-011) printf 'Sensible Pfade liegen im Webbereich, sind aktuell aber geblockt.' ;;
        PERM-001) printf 'Mindestens eine Datei oder ein Ordner ist zu offen freigegeben.' ;;
        PERM-002|PERM-003) printf 'Eine .env-Datei ist zu offen lesbar.' ;;
        PERM-004) printf 'Eine Konfigurationsdatei ist zu offen lesbar.' ;;
        PERM-005) printf 'Ein privater Schluessel ist zu offen freigegeben.' ;;
        PERM-006) printf 'Sensible Dateien sind fuer andere Benutzer beschreibbar.' ;;
        DOCKER-001) printf 'Ein Docker-Port ist oeffentlich erreichbar, obwohl er nicht erwartet wurde.' ;;
        MAIL-001) printf 'Ein Mail-Verwaltungsbereich wirkt von aussen erreichbar.' ;;
        MAIL-002) printf 'Es fehlen Hinweise auf SPF fuer E-Mails.' ;;
        MAIL-003) printf 'Es fehlen Hinweise auf DMARC fuer E-Mails.' ;;
        ACT-001) printf 'Ein sensibler Standardpfad ist ueber eine aktive Web-Probe direkt erreichbar.' ;;
        ACT-002) printf 'Eine harmlose Traversal-Probe wurde nicht sauber geblockt.' ;;
        ACT-003) printf 'Der Webserver liefert nicht alle wichtigen Sicherheitsheader.' ;;
        ACT-004) printf 'Mindestens ein sichtbares Cookie hat unsichere Schutzflags.' ;;
        ACT-005) printf 'Der Webserver antwortet auf die TRACE-Methode.' ;;
        ACT-006) printf 'Typische Admin- oder Login-Seiten reagieren direkt auf Web-Anfragen.' ;;
        ACT-007) printf 'Ein moeglicher Upload-Endpunkt reagiert auf eine harmlose Web-Probe.' ;;
        ACT-008) printf 'Antwort-Header verraten unnoetig technische Details ueber das System.' ;;
        ACT-009) printf 'Bei einer vorsichtigen Login-Probe war keine klare Bremswirkung sichtbar.' ;;
        ACT-010) printf 'Lokale Debug-, Swagger- oder Entwicklerpfade reagieren im Lab-Modus direkt.' ;;
        ACT-011) printf 'Zusaetzliche HTTP-Methoden reagieren im lokalen Lab-Modus erfolgreich.' ;;
        ACT-012) printf 'Einige lokale Sonderpfade fuehren im Lab-Modus zu Serverfehlern.' ;;
        SYS-001) printf 'Automatische Sicherheitsupdates sind nicht erkennbar.' ;;
        SYS-002) printf 'Ein Neustart des Servers ist wahrscheinlich noetig.' ;;
        SYS-003) printf 'Es sind Sicherheitsupdates verfuegbar.' ;;
        SYS-004) printf 'Es wurden keine klaren Authentifizierungsprotokolle gefunden.' ;;
        SYS-005) printf 'Es gab viele fehlgeschlagene SSH-Anmeldungen.' ;;
        APP-001) printf 'Es wurde eine Formular- oder Mail-Funktion erkannt und sollte abgesichert werden.' ;;
        APP-002) printf 'Es gibt keine klaren Hinweise auf CSRF-Schutz.' ;;
        APP-003) printf 'Es gibt keine klaren Hinweise auf Begrenzung vieler Anfragen.' ;;
        APP-004) printf 'Es gibt keine klaren Hinweise auf Schutz gegen Spam oder Bots.' ;;
        CODE-001|CODE-002|CODE-005|CODE-006) printf 'Im Code wurden moegliche sicherheitskritische Stellen gefunden.' ;;
        CODE-003|CODE-004|CODE-007|CODE-008) printf 'Im Code wurden Stellen gefunden, die genauer geprueft werden sollten.' ;;
        *) printf '%s' "$title" ;;
    esac
}

beginner_fix_reason_text() {
    local fix_id="$1"
    local risk="$2"

    case "$fix_id" in
        FIX-UFW-001) printf 'Die Firewall-Grundregeln sollen gesetzt werden, damit unnoetige Ports nicht offen bleiben.' ;;
        FIX-F2B-001) printf 'Es soll ein Schutz gegen wiederholte Login-Angriffe eingerichtet werden.' ;;
        FIX-SSH-001) printf 'Der SSH-Zugang soll sicherer werden, ohne bestehende Nutzer auszusperren.' ;;
        FIX-PHP-001) printf 'PHP soll weniger interne Details preisgeben und sichere Cookie-Regeln nutzen.' ;;
        FIX-NGX-001|FIX-NGX-002) printf 'Der Webserver soll empfohlene Schutzregeln bekommen.' ;;
        FIX-APACHE-001) printf 'Apache soll nur deaktiviert werden, wenn er wirklich nicht mehr gebraucht wird.' ;;
        FIX-PERM-001|FIX-PERM-002) printf 'Sensible Dateien sollen engere Rechte bekommen.' ;;
        FIX-QUAR-001) printf 'Alte Backups oder Exportdateien sollen aus dem normalen Webbereich verschwinden.' ;;
        *) printf '%s' "$risk" ;;
    esac
}

beginner_recommendation_text() {
    local issue_id="$1"
    local recommendation="$2"

    case "$issue_id" in
        SVC-001) printf 'Datenbank-Port absichern oder nur intern erreichbar machen.' ;;
        SVC-002) printf 'Login-Schutz wie Fail2ban einrichten.' ;;
        SVC-003) printf 'Root-Login fuer SSH abschalten.' ;;
        SVC-005|SVC-006) printf 'Firewall-Regeln pruefen und bewusst aktivieren.' ;;
        SVC-007|SVC-008) printf 'Empfohlene Webserver-Schutzregeln einbauen.' ;;
        SVC-009) printf 'Pruefen, ob wirklich beide Webserver gebraucht werden.' ;;
        SVC-013) printf 'Pruefen, ob dieser Dienst wirklich von aussen erreichbar sein soll.' ;;
        SVC-014|SVC-015) printf 'Internen Dienst oder Proxy-Ziel pruefen.' ;;
        EXP-001|EXP-002|EXP-003) printf 'Sensible Datei aus dem Webbereich entfernen oder blockieren.' ;;
        EXP-004) printf 'Alte Backups aus dem Webbereich entfernen oder in Quarantaene verschieben.' ;;
        EXP-010) printf 'Direkt erreichbare sensible Pfade sofort sperren oder aus dem Webroot verschieben.' ;;
        EXP-011) printf 'Geblockte sensible Pfade moeglichst ganz aus dem Webroot verschieben.' ;;
        PERM-001|PERM-002|PERM-003|PERM-004|PERM-005|PERM-006) printf 'Dateirechte enger setzen.' ;;
        DOCKER-001) printf 'Port-Mapping oder Firewall-Regeln pruefen.' ;;
        MAIL-001|MAIL-002|MAIL-003) printf 'Mail-Konfiguration und Schutzregeln pruefen.' ;;
        ACT-001) printf 'Direkt erreichbare sensible Pfade sofort absichern oder sperren.' ;;
        ACT-002) printf 'Webserver- und App-Regeln gegen Traversal pruefen.' ;;
        ACT-003) printf 'Fehlende Sicherheitsheader zentral am Webserver nachziehen.' ;;
        ACT-004) printf 'Cookie-Schutzflags zentral fuer Sessions und Logins nachziehen.' ;;
        ACT-005) printf 'TRACE am Webserver oder Proxy deaktivieren.' ;;
        ACT-006) printf 'Login-Schutz wie MFA, Rate-Limits und IP-Schutz pruefen.' ;;
        ACT-007) printf 'Upload-Regeln, Dateitypen und Speicherpfade gezielt pruefen.' ;;
        ACT-008) printf 'Unnoetige Versions- und Proxy-Header unterdruecken.' ;;
        ACT-009) printf 'Login-Rate-Limits, WAF-Regeln und Fail2ban fuer Login-Wege pruefen.' ;;
        ACT-010) printf 'Debug- und Entwicklerhilfen fuer Produktion bewusst sperren.' ;;
        ACT-011) printf 'Erlaubte HTTP-Methoden und CORS-Regeln bewusst begrenzen.' ;;
        ACT-012) printf 'Router- und Fehlerbehandlung fuer Sonderpfade stabilisieren.' ;;
        SYS-001|SYS-003) printf 'Sicherheitsupdates und automatische Updates pruefen.' ;;
        SYS-002) printf 'Neustart einplanen, wenn der Server dafuer bereit ist.' ;;
        APP-002|APP-003|APP-004) printf 'Formulare mit zusaetzlichem Schutz absichern.' ;;
        CODE-001|CODE-002|CODE-005|CODE-006) printf 'Code-Stellen mit hohem Risiko gezielt pruefen.' ;;
        *) printf '%s' "$recommendation" ;;
    esac
}

beginner_fix_category_text() {
    local category="$1"
    case "$category" in
        AUTO-SAFE) printf 'Sicherer Auto-Fix' ;;
        GUIDED) printf 'Gefuehrter Fix' ;;
        MANUAL) printf 'Manuelle Pruefung' ;;
        *) printf '%s' "$category" ;;
    esac
}

beginner_auto_fix_text() {
    local can_fix="$1"
    case "$can_fix" in
        yes|true) printf 'ja' ;;
        *) printf 'nein' ;;
    esac
}

print_beginner_action_plan() {
    local i
    local immediate_count=0
    local today_count=0
    local later_count=0

    section "Empfohlene Reihenfolge"

    info "Jetzt sofort tun:"
    for ((i=0; i<${#ISSUE_IDS[@]}; i++)); do
        [ "${ISSUE_LEVELS[$i]}" = "KRITISCH" ] || continue
        printf -- '- %s\n' "$(beginner_issue_text "${ISSUE_IDS[$i]}" "${ISSUE_TITLES[$i]}")"
        immediate_count=$((immediate_count + 1))
    done
    [ "$immediate_count" -gt 0 ] || printf -- '- Keine sofort kritischen Punkte.\n'

    info "Heute noch pruefen:"
    for ((i=0; i<${#ISSUE_IDS[@]}; i++)); do
        [ "${ISSUE_LEVELS[$i]}" = "WARNUNG" ] || continue
        printf -- '- %s\n' "$(beginner_issue_text "${ISSUE_IDS[$i]}" "${ISSUE_TITLES[$i]}")"
        today_count=$((today_count + 1))
        [ "$today_count" -lt 5 ] || break
    done
    [ "$today_count" -gt 0 ] || printf -- '- Keine offenen Warnungen.\n'

    info "Spaeter verbessern:"
    for ((i=0; i<${#FIX_IDS[@]}; i++)); do
        [ "${FIX_CATEGORIES[$i]}" = "GUIDED" ] || continue
        printf -- '- %s\n' "$(beginner_fix_reason_text "${FIX_IDS[$i]}" "${FIX_RISKS[$i]}")"
        later_count=$((later_count + 1))
        [ "$later_count" -lt 3 ] || break
    done
    [ "$later_count" -gt 0 ] || printf -- '- Keine groesseren spaeteren Baustellen erkannt.\n'
}

print_beginner_summary() {
    local i critical_fixes=0 safe_fixes=0

    section "Einfache Zusammenfassung"
    print_key_value "Sicherheitswert" "$SCORE/100"
    print_key_value "Status" "$STATUS_LABEL"
    print_key_value "Ampel" "$(beginner_overall_badge) - $(beginner_overall_text)"
    print_key_value "Kritische Probleme" "$CRIT_COUNT"
    print_key_value "Warnungen" "$WARN_COUNT"

    for ((i=0; i<${#FIX_IDS[@]}; i++)); do
        [ "${FIX_CATEGORIES[$i]}" = "AUTO-SAFE" ] && safe_fixes=$((safe_fixes + 1))
        [ "${FIX_LEVELS[$i]}" = "KRITISCH" ] && critical_fixes=$((critical_fixes + 1))
    done

    print_key_value "Sichere Auto-Fixes" "$safe_fixes"
    print_key_value "Fixes fuer kritisch" "$critical_fixes"

    if [ "${#ISSUE_IDS[@]}" -eq 0 ]; then
        ok "Es wurden keine direkten Probleme gefunden."
        return
    fi

    info "Wichtigste Punkte:"
    for ((i=0; i<${#ISSUE_IDS[@]} && i<5; i++)); do
        printf -- '- [%s] %s\n' "$(beginner_level_badge "${ISSUE_LEVELS[$i]}")" "$(beginner_issue_text "${ISSUE_IDS[$i]}" "${ISSUE_TITLES[$i]}")"
    done

    if [ "${#ISSUE_IDS[@]}" -gt 5 ]; then
        info "Weitere Punkte stehen im normalen Report."
    fi

    if dry_run_enabled; then
        warn "Aktuell ist nur Vorschau aktiv. Fixes zeigen nur, was gemacht wuerde."
    else
        info "Fixes koennen jetzt Schritt fuer Schritt bestaetigt werden."
    fi

    print_beginner_action_plan
}
