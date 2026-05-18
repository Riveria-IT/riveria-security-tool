#!/usr/bin/env bash

code_security_scan_roots() {
    if [ "${#DETECTED_PROJECTS[@]}" -gt 0 ]; then
        local marker
        for marker in "${DETECTED_PROJECTS[@]}"; do
            dirname "$marker"
        done
        return
    fi

    local root
    for root in /var/www /srv /opt; do
        [ -d "$root" ] && printf '%s\n' "$root"
    done
}

code_security_unique_roots() {
    local roots=()
    local root
    while IFS= read -r root; do
        [ -n "$root" ] || continue
        append_unique "$root" "${roots[@]}" || roots+=("$root")
    done < <(code_security_scan_roots)

    printf '%s\n' "${roots[@]}"
}

code_security_grep() {
    local pattern="$1"
    shift || true
    local roots=()
    local root
    while IFS= read -r root; do
        [ -n "$root" ] && roots+=("$root")
    done < <(code_security_unique_roots)

    [ "${#roots[@]}" -gt 0 ] || return 0

    grep -RInE \
        --include='*.php' \
        --include='*.phtml' \
        --include='*.inc' \
        --include='*.js' \
        --include='*.ts' \
        --include='*.jsx' \
        --include='*.tsx' \
        --include='*.py' \
        --include='*.rb' \
        --include='*.sh' \
        --exclude-dir=.git \
        --exclude-dir=vendor \
        --exclude-dir=node_modules \
        --exclude-dir=storage \
        --exclude-dir=logs \
        --exclude-dir=cache \
        --exclude-dir=dist \
        --exclude-dir=build \
        "$pattern" "${roots[@]}" 2>/dev/null | head -n 20 || true
}

code_security_print_hits() {
    local label="$1"
    local hits="$2"
    [ -n "$hits" ] || return 0
    info "$label"
    printf '%s\n' "$hits"
}

run_code_security_checks() {
    section "Code Security"

    if ! cmd_exists grep; then
        warn "grep ist nicht verfuegbar."
        return
    fi

    local sql_direct_hits sql_query_hits prepared_hits command_hits include_hits eval_hits upload_hits debug_hits
    local found_any=0

    sql_direct_hits="$(code_security_grep '(SELECT|INSERT|UPDATE|DELETE).*(\$_GET|\$_POST|\$_REQUEST)|(\$_GET|\$_POST|\$_REQUEST).*(SELECT|INSERT|UPDATE|DELETE)')"
    if [ -n "$sql_direct_hits" ]; then
        register_issue "CODE-001" "SQL-Hinweise mit direkter User-Eingabe" "KRITISCH" \
            "Es wurden statische Muster gefunden, bei denen SQL und User-Eingaben in derselben Zeile vorkommen." \
            "Fundstellen manuell pruefen und Prepared Statements einsetzen." "MANUAL" "no"
        bad "Kritische SQL-Hinweise gefunden."
        code_security_print_hits "Fundstellen SQL + User-Eingabe:" "$sql_direct_hits"
        found_any=1
    fi

    sql_query_hits="$(code_security_grep '(mysqli_query|mysql_query|PDO::query|->query[[:space:]]*\().*(\$_GET|\$_POST|\$_REQUEST)|(\$_GET|\$_POST|\$_REQUEST).*(mysqli_query|mysql_query|PDO::query|->query[[:space:]]*\()')"
    if [ -n "$sql_query_hits" ]; then
        register_issue "CODE-002" "Rohe SQL-Query-Aufrufe mit User-Eingabe" "KRITISCH" \
            "Query-Aufrufe mit direkter User-Eingabe koennen auf SQL-Injection-Risiken hinweisen." \
            "Prepared Statements oder Framework-ORM konsequent einsetzen." "MANUAL" "no"
        bad "Query-Aufrufe mit direkter User-Eingabe gefunden."
        code_security_print_hits "Fundstellen Query-Aufrufe mit User-Eingabe:" "$sql_query_hits"
        found_any=1
    fi

    prepared_hits="$(code_security_grep 'prepare[[:space:]]*\(|bind_param[[:space:]]*\(|bindValue[[:space:]]*\(|bindParam[[:space:]]*\(|execute[[:space:]]*\(')"
    if [ -n "$prepared_hits" ]; then
        ok "Prepared-Statement-Hinweise gefunden."
    else
        register_issue "CODE-003" "Keine klaren Prepared-Statement-Hinweise gefunden" "WARNUNG" \
            "Im geprueften Code wurden keine eindeutigen Hinweise auf vorbereitete Statements erkannt." \
            "Datenbankzugriffe manuell pruefen, besonders Login-, Formular- und Suchlogik." "MANUAL" "no"
        warn "Keine klaren Prepared-Statement-Hinweise gefunden."
        found_any=1
    fi

    command_hits="$(code_security_grep '(shell_exec|exec|system|passthru|proc_open|popen)[[:space:]]*\(')"
    if [ -n "$command_hits" ]; then
        register_issue "CODE-004" "Command-Execution-Funktionen gefunden" "WARNUNG" \
            "Es wurden Funktionen gefunden, die Shell- oder Prozessaufrufe ausfuehren." \
            "Auf User-Eingaben, Escaping und Noetigkeit manuell pruefen." "MANUAL" "no"
        warn "Command-Execution-Funktionen gefunden."
        code_security_print_hits "Fundstellen Command-Execution:" "$command_hits"
        found_any=1
    fi

    include_hits="$(code_security_grep '(include|include_once|require|require_once)[[:space:]]*(\(|)[[:space:]]*(\$_GET|\$_POST|\$_REQUEST|\$_SERVER)')"
    if [ -n "$include_hits" ]; then
        register_issue "CODE-005" "Dynamische Includes mit User-Eingabe gefunden" "KRITISCH" \
            "Includes oder Requires mit User-Eingaben koennen zu LFI/RFI-Risiken fuehren." \
            "Nur feste Allowlists oder statische Includes verwenden." "MANUAL" "no"
        bad "Dynamische Includes mit User-Eingabe gefunden."
        code_security_print_hits "Fundstellen Include/Require mit User-Eingabe:" "$include_hits"
        found_any=1
    fi

    eval_hits="$(code_security_grep 'eval[[:space:]]*\(|assert[[:space:]]*\(|unserialize[[:space:]]*\(.*(\$_GET|\$_POST|\$_REQUEST)|base64_decode[[:space:]]*\(.*eval[[:space:]]*\(')"
    if [ -n "$eval_hits" ]; then
        register_issue "CODE-006" "Gefaehrliche Ausfuehrungs- oder Parsing-Funktionen gefunden" "KRITISCH" \
            "eval, assert oder unserialize mit User-Eingaben koennen schwerwiegende Risiken bedeuten." \
            "Fundstellen priorisiert manuell pruefen und sichere Alternativen verwenden." "MANUAL" "no"
        bad "Gefaehrliche Parsing-/Ausfuehrungsfunktionen gefunden."
        code_security_print_hits "Fundstellen eval/assert/unserialize:" "$eval_hits"
        found_any=1
    fi

    upload_hits="$(code_security_grep 'move_uploaded_file[[:space:]]*\(|\$_FILES|UPLOAD|upload')"
    if [ -n "$upload_hits" ]; then
        register_issue "CODE-007" "Upload-Logik erkannt" "WARNUNG" \
            "Es wurde Upload-Logik erkannt. Fehlende Pruefungen waeren manuell zu bewerten." \
            "Dateityp, Zielpfad, Dateiendung und Zugriffsschutz der Uploads pruefen." "MANUAL" "no"
        warn "Upload-Logik erkannt."
        code_security_print_hits "Fundstellen Upload-Logik:" "$upload_hits"
        found_any=1
    fi

    debug_hits="$(code_security_grep 'phpinfo[[:space:]]*\(|var_dump[[:space:]]*\(|print_r[[:space:]]*\(|\bdd[[:space:]]*\(|die[[:space:]]*\(|display_errors')"
    if [ -n "$debug_hits" ]; then
        register_issue "CODE-008" "Debug- oder Diagnose-Ausgaben gefunden" "WARNUNG" \
            "Im Projekt wurden Debug-Funktionen oder Hinweise auf offene Fehlerausgaben gefunden." \
            "Produktionscode auf versehentliche Debug-Ausgaben und display_errors pruefen." "MANUAL" "no"
        warn "Debug- oder Diagnose-Ausgaben gefunden."
        code_security_print_hits "Fundstellen Debug/Diagnose:" "$debug_hits"
        found_any=1
    fi

    if [ "$found_any" -eq 0 ]; then
        ok "Keine auffaelligen statischen Code-Sicherheitsmuster in der Basispruefung gefunden."
    fi
}
