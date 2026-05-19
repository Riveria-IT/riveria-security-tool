#!/usr/bin/env bash

REPORT_RUN_ID=""
REPORT_RUN_DATE_HUMAN=""
REPORT_RUN_DATE_ISO=""
REPORT_RUN_SERVER=""

report_timestamp() {
    date '+%Y-%m-%d_%H-%M-%S'
}

ensure_report_context() {
    if [ -z "$REPORT_RUN_ID" ]; then
        REPORT_RUN_ID="$(report_timestamp)"
        REPORT_RUN_DATE_HUMAN="$(date '+%F %T %Z')"
        REPORT_RUN_DATE_ISO="$(date '+%FT%T%z')"
        REPORT_RUN_SERVER="$(hostname 2>/dev/null || printf 'unknown')"
    fi
}

reset_report_context() {
    REPORT_RUN_ID=""
    REPORT_RUN_DATE_HUMAN=""
    REPORT_RUN_DATE_ISO=""
    REPORT_RUN_SERVER=""
}

report_base_path() {
    ensure_report_context
    printf '%s/report_%s' "$REPORT_DIR" "$REPORT_RUN_ID"
}

json_escape() {
    local input="${1:-}"
    input="${input//\\/\\\\}"
    input="${input//\"/\\\"}"
    input="${input//$'\n'/\\n}"
    input="${input//$'\r'/\\r}"
    input="${input//$'\t'/\\t}"
    printf '%s' "$input"
}

html_escape() {
    local input="${1:-}"
    input="${input//&/&amp;}"
    input="${input//</&lt;}"
    input="${input//>/&gt;}"
    input="${input//\"/&quot;}"
    printf '%s' "$input"
}

status_css_class() {
    case "$1" in
        KRITISCH|Kritisch) printf 'critical' ;;
        WARNUNG|Mittel) printf 'warning' ;;
        OK|Gut) printf 'good' ;;
        *) printf 'neutral' ;;
    esac
}

json_array_from_lines() {
    local first=1 item
    printf '['
    for item in "$@"; do
        [ -n "$item" ] || continue
        [ $first -eq 0 ] && printf ','
        printf '"%s"' "$(json_escape "$item")"
        first=0
    done
    printf ']'
}

issue_id_has_prefix() {
    local issue_id="$1"
    local prefix="$2"
    case "$issue_id" in
        "$prefix"*) return 0 ;;
        *) return 1 ;;
    esac
}

count_issues_by_prefix() {
    local prefix="$1"
    local count=0 i
    for ((i=0; i<${#ISSUE_IDS[@]}; i++)); do
        issue_id_has_prefix "${ISSUE_IDS[$i]}" "$prefix" && count=$((count + 1))
    done
    printf '%s' "$count"
}

print_test_mode_status_lines() {
    printf -- '- Vollaudit: %s\n' "$AUDIT_MODE_FULL_STATUS"
    printf -- '- Aktive Sicherheitspruefung (safe): %s\n' "$AUDIT_MODE_ACTIVE_SAFE_STATUS"
    printf -- '- Lab-Validierungsmodus (lokal): %s\n' "$AUDIT_MODE_LAB_LOCAL_STATUS"
}

generate_txt_report() {
    ensure_report_context
    local file
    file="$(report_base_path).txt"

    {
        printf '%s\n' "$APP_NAME"
        printf 'Version: %s\n' "$APP_VERSION"
        printf 'Report-ID: %s\n' "$REPORT_RUN_ID"
        printf 'Datum: %s\n' "$REPORT_RUN_DATE_HUMAN"
        printf 'Server: %s\n' "$REPORT_RUN_SERVER"
        printf 'Score: %s/100\n' "$SCORE"
        printf 'Status: %s\n' "$STATUS_LABEL"
        printf 'Zusammenfassung: %s OK, %s Warnungen, %s kritisch\n' "$OK_COUNT" "$WARN_COUNT" "$CRIT_COUNT"
        printf '\nPruefarten:\n'
        print_test_mode_status_lines
        printf '\nErkannte Profile:\n'
        if [ "${#DETECTED_PROFILES[@]}" -gt 0 ]; then
            print_array_lines "${DETECTED_PROFILES[@]}"
        else
            printf -- '- Keine Profile erkannt\n'
        fi
        printf '\nErkannte Komponenten:\n'
        if [ "${#DETECTED_COMPONENTS[@]}" -gt 0 ]; then
            print_array_lines "${DETECTED_COMPONENTS[@]}"
        else
            printf -- '- Keine Komponenten erkannt\n'
        fi
        printf '\nAktive Listener:\n'
        if [ "${#ACTIVE_LISTENER_PROTOCOLS[@]}" -gt 0 ]; then
            local k process_suffix
            for ((k=0; k<${#ACTIVE_LISTENER_PROTOCOLS[@]}; k++)); do
                process_suffix=""
                [ -n "${ACTIVE_LISTENER_PROCESSES[$k]}" ] && process_suffix=" (${ACTIVE_LISTENER_PROCESSES[$k]})"
                printf -- '- %s %s [%s]%s\n' \
                    "${ACTIVE_LISTENER_PROTOCOLS[$k]}" \
                    "${ACTIVE_LISTENER_BINDS[$k]}" \
                    "${ACTIVE_LISTENER_EXPOSURES[$k]}" \
                    "$process_suffix"
            done
        else
            printf -- '- Keine Listener erkannt\n'
        fi
        printf '\nProbleme:\n'
        if [ "${#ISSUE_IDS[@]}" -eq 0 ] || [ "${#ISSUE_IDS[@]}" -eq "$(count_issues_by_prefix 'ACT-')" ]; then
            printf -- '- Keine Probleme registriert\n'
        else
            local i
            for ((i=0; i<${#ISSUE_IDS[@]}; i++)); do
                issue_id_has_prefix "${ISSUE_IDS[$i]}" 'ACT-' && continue
                printf '[%s] %s - %s\n' "${ISSUE_LEVELS[$i]}" "${ISSUE_IDS[$i]}" "${ISSUE_TITLES[$i]}"
                printf '  Beschreibung: %s\n' "${ISSUE_DESCRIPTIONS[$i]}"
                printf '  Empfehlung: %s\n' "${ISSUE_RECOMMENDATIONS[$i]}"
                printf '  Fix-Kategorie: %s\n' "${ISSUE_FIX_CATEGORIES[$i]}"
                printf '  Automatisch behebbar: %s\n' "${ISSUE_CAN_FIX[$i]}"
            done
        fi
        if [ "$(count_issues_by_prefix 'ACT-')" -gt 0 ]; then
            printf '\nAktive Tests:\n'
            local a
            for ((a=0; a<${#ISSUE_IDS[@]}; a++)); do
                issue_id_has_prefix "${ISSUE_IDS[$a]}" 'ACT-' || continue
                printf '[%s] %s - %s\n' "${ISSUE_LEVELS[$a]}" "${ISSUE_IDS[$a]}" "${ISSUE_TITLES[$a]}"
                printf '  Beschreibung: %s\n' "${ISSUE_DESCRIPTIONS[$a]}"
                printf '  Empfehlung: %s\n' "${ISSUE_RECOMMENDATIONS[$a]}"
            done
        fi
        printf '\nFix-Vorschlaege:\n'
        if [ "${#FIX_IDS[@]}" -eq 0 ]; then
            printf -- '- Keine Fix-Vorschlaege registriert\n'
        else
            local j
            for ((j=0; j<${#FIX_IDS[@]}; j++)); do
                printf '[%s] %s - %s\n' "${FIX_CATEGORIES[$j]}" "${FIX_IDS[$j]}" "${FIX_TITLES[$j]}"
                printf '  Risiko: %s\n' "${FIX_RISKS[$j]}"
                printf '  Backup: %s\n' "${FIX_BACKUPS[$j]}"
                printf '  Geplanter Befehl: %s\n' "${FIX_COMMANDS[$j]}"
                printf '  Test: %s\n' "${FIX_TESTS[$j]}"
                printf '  Reload: %s\n' "${FIX_RELOADS[$j]}"
                printf '  Nachpruefung: %s\n' "${FIX_RECHECKS[$j]}"
            done
        fi
        printf '\nReport-Pfade:\n'
        printf -- '- TXT:  %s\n' "$(report_base_path).txt"
        printf -- '- JSON: %s\n' "$(report_base_path).json"
        printf -- '- HTML: %s\n' "$(report_base_path).html"
    } >"$file"

    printf '%s' "$file"
}

generate_json_report() {
    ensure_report_context
    local file
    file="$(report_base_path).json"

    {
        printf '{\n'
        printf '  "tool": "%s",\n' "$(json_escape "$APP_NAME")"
        printf '  "version": "%s",\n' "$(json_escape "$APP_VERSION")"
        printf '  "report_id": "%s",\n' "$(json_escape "$REPORT_RUN_ID")"
        printf '  "date": "%s",\n' "$(json_escape "$REPORT_RUN_DATE_ISO")"
        printf '  "server": "%s",\n' "$(json_escape "$REPORT_RUN_SERVER")"
        printf '  "score": %s,\n' "$SCORE"
        printf '  "status": "%s",\n' "$(json_escape "$STATUS_LABEL")"
        printf '  "summary": {"ok": %s, "warnings": %s, "critical": %s},\n' "$OK_COUNT" "$WARN_COUNT" "$CRIT_COUNT"
        printf '  "test_modes": {"full_audit":"%s","active_safe":"%s","lab_local":"%s"},\n' \
            "$(json_escape "$AUDIT_MODE_FULL_STATUS")" \
            "$(json_escape "$AUDIT_MODE_ACTIVE_SAFE_STATUS")" \
            "$(json_escape "$AUDIT_MODE_LAB_LOCAL_STATUS")"
        printf '  "profiles": %s,\n' "$(json_array_from_lines "${DETECTED_PROFILES[@]-}")"
        printf '  "components": %s,\n' "$(json_array_from_lines "${DETECTED_COMPONENTS[@]-}")"
        printf '  "active_listeners": [\n'
        local l
        for ((l=0; l<${#ACTIVE_LISTENER_PROTOCOLS[@]}; l++)); do
            printf '    {"protocol":"%s","bind":"%s","exposure":"%s","process":"%s"}' \
                "$(json_escape "${ACTIVE_LISTENER_PROTOCOLS[$l]}")" \
                "$(json_escape "${ACTIVE_LISTENER_BINDS[$l]}")" \
                "$(json_escape "${ACTIVE_LISTENER_EXPOSURES[$l]}")" \
                "$(json_escape "${ACTIVE_LISTENER_PROCESSES[$l]}")"
            [ "$l" -lt $((${#ACTIVE_LISTENER_PROTOCOLS[@]} - 1)) ] && printf ','
            printf '\n'
        done
        printf '  ],\n'
        printf '  "active_tests": [\n'
        local a active_test_written=0
        for ((a=0; a<${#ISSUE_IDS[@]}; a++)); do
            issue_id_has_prefix "${ISSUE_IDS[$a]}" 'ACT-' || continue
            [ "$active_test_written" -eq 1 ] && printf ',\n'
            printf '    {"id":"%s","title":"%s","level":"%s","description":"%s","recommendation":"%s"}' \
                "$(json_escape "${ISSUE_IDS[$a]}")" \
                "$(json_escape "${ISSUE_TITLES[$a]}")" \
                "$(json_escape "${ISSUE_LEVELS[$a]}")" \
                "$(json_escape "${ISSUE_DESCRIPTIONS[$a]}")" \
                "$(json_escape "${ISSUE_RECOMMENDATIONS[$a]}")"
            active_test_written=1
        done
        printf '\n  ],\n'
        printf '  "issues": [\n'
        local i
        for ((i=0; i<${#ISSUE_IDS[@]}; i++)); do
            printf '    {"id":"%s","title":"%s","level":"%s","description":"%s","recommendation":"%s","fix_category":"%s","can_fix":"%s"}' \
                "$(json_escape "${ISSUE_IDS[$i]}")" \
                "$(json_escape "${ISSUE_TITLES[$i]}")" \
                "$(json_escape "${ISSUE_LEVELS[$i]}")" \
                "$(json_escape "${ISSUE_DESCRIPTIONS[$i]}")" \
                "$(json_escape "${ISSUE_RECOMMENDATIONS[$i]}")" \
                "$(json_escape "${ISSUE_FIX_CATEGORIES[$i]}")" \
                "$(json_escape "${ISSUE_CAN_FIX[$i]}")"
            [ "$i" -lt $((${#ISSUE_IDS[@]} - 1)) ] && printf ','
            printf '\n'
        done
        printf '  ],\n'
        printf '  "fix_suggestions": [\n'
        local j
        for ((j=0; j<${#FIX_IDS[@]}; j++)); do
            printf '    {"id":"%s","title":"%s","risk":"%s","category":"%s","backup":"%s","command":"%s","test":"%s","reload":"%s","recheck":"%s"}' \
                "$(json_escape "${FIX_IDS[$j]}")" \
                "$(json_escape "${FIX_TITLES[$j]}")" \
                "$(json_escape "${FIX_RISKS[$j]}")" \
                "$(json_escape "${FIX_CATEGORIES[$j]}")" \
                "$(json_escape "${FIX_BACKUPS[$j]}")" \
                "$(json_escape "${FIX_COMMANDS[$j]}")" \
                "$(json_escape "${FIX_TESTS[$j]}")" \
                "$(json_escape "${FIX_RELOADS[$j]}")" \
                "$(json_escape "${FIX_RECHECKS[$j]}")"
            [ "$j" -lt $((${#FIX_IDS[@]} - 1)) ] && printf ','
            printf '\n'
        done
        printf '  ]\n'
        printf '}\n'
    } >"$file"

    printf '%s' "$file"
}

generate_html_report() {
    ensure_report_context
    local txt_file html_file
    txt_file="$(generate_txt_report)"
    html_file="$(report_base_path).html"

    {
        printf '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
        printf '<title>%s</title>' "$(html_escape "$APP_NAME")"
        printf '<style>'
        printf 'body{margin:0;font-family:Georgia,"Times New Roman",serif;background:linear-gradient(180deg,#f4efe7 0%%,#e6edf4 100%%);color:#1f2933;padding:32px;}'
        printf '.wrap{max-width:1180px;margin:0 auto;}'
        printf '.hero{background:#13212f;color:#f8fafc;border-radius:24px;padding:28px 30px;box-shadow:0 18px 60px rgba(19,33,47,.18);margin-bottom:24px;}'
        printf '.hero h1{margin:0 0 8px;font-size:34px;line-height:1.1;}'
        printf '.meta{opacity:.82;font-size:14px;}'
        printf '.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:16px;margin:20px 0 24px;}'
        printf '.card{background:rgba(255,255,255,.8);backdrop-filter:blur(6px);border:1px solid rgba(19,33,47,.08);border-radius:20px;padding:18px;box-shadow:0 12px 34px rgba(31,41,51,.08);}'
        printf '.card h2{margin:0 0 12px;font-size:18px;}'
        printf '.score{font-size:48px;font-weight:700;line-height:1;color:#13212f;}'
        printf '.pill{display:inline-block;padding:6px 10px;border-radius:999px;font-size:12px;font-weight:700;letter-spacing:.03em;text-transform:uppercase;}'
        printf '.good{background:#d9f7e8;color:#106b45;}.warning{background:#fff2cc;color:#8a5a00;}.critical{background:#ffd9d6;color:#a12622;}.neutral{background:#e7edf3;color:#405261;}'
        printf '.list{margin:0;padding-left:18px;}.list li{margin:6px 0;}'
        printf '.finding{border-left:6px solid #c5d0da;padding:14px 16px;border-radius:14px;background:#fff;margin-bottom:14px;}'
        printf '.finding.good{border-left-color:#2a8f61;}.finding.warning{border-left-color:#c68a00;}.finding.critical{border-left-color:#c73b33;}'
        printf '.finding h3{margin:0 0 8px;font-size:18px;}'
        printf '.finding p{margin:6px 0 0;}'
        printf '.mono{font-family:"SFMono-Regular",Consolas,monospace;font-size:13px;white-space:pre-wrap;background:#0f1720;color:#d8e3ee;padding:18px;border-radius:18px;}'
        printf '@media (max-width:720px){body{padding:16px;}.hero{padding:22px 20px;}.hero h1{font-size:28px;}}'
        printf '</style></head><body><div class="wrap">'
        printf '<section class="hero"><h1>%s</h1>' "$(html_escape "$APP_NAME")"
        printf '<div class="pill %s">%s</div>' "$(status_css_class "$STATUS_LABEL")" "$(html_escape "$STATUS_LABEL")"
        printf '<div class="meta">Version %s · Report %s · %s · %s</div></section>' \
            "$(html_escape "$APP_VERSION")" "$(html_escape "$REPORT_RUN_ID")" "$(html_escape "$REPORT_RUN_DATE_HUMAN")" "$(html_escape "$REPORT_RUN_SERVER")"
        printf '<section class="grid">'
        printf '<div class="card"><h2>Score</h2><div class="score">%s</div><div>von 100 Punkten</div></div>' "$(html_escape "$SCORE")"
        printf '<div class="card"><h2>Zusammenfassung</h2><ul class="list"><li>OK: %s</li><li>Warnungen: %s</li><li>Kritisch: %s</li></ul></div>' "$OK_COUNT" "$WARN_COUNT" "$CRIT_COUNT"
        printf '<div class="card"><h2>Pruefarten</h2><ul class="list"><li>Vollaudit: %s</li><li>Aktive Sicherheitspruefung: %s</li><li>Lab-Validierungsmodus: %s</li></ul></div>' \
            "$(html_escape "$AUDIT_MODE_FULL_STATUS")" \
            "$(html_escape "$AUDIT_MODE_ACTIVE_SAFE_STATUS")" \
            "$(html_escape "$AUDIT_MODE_LAB_LOCAL_STATUS")"
        printf '<div class="card"><h2>Profile</h2><ul class="list">'
        local item
        if [ "${#DETECTED_PROFILES[@]}" -eq 0 ]; then
            printf '<li>Keine Profile erkannt</li>'
        else
            for item in "${DETECTED_PROFILES[@]}"; do
                printf '<li>%s</li>' "$(html_escape "$item")"
            done
        fi
        printf '</ul></div>'
        printf '<div class="card"><h2>Komponenten</h2><ul class="list">'
        if [ "${#DETECTED_COMPONENTS[@]}" -eq 0 ]; then
            printf '<li>Keine Komponenten erkannt</li>'
        else
            for item in "${DETECTED_COMPONENTS[@]}"; do
                printf '<li>%s</li>' "$(html_escape "$item")"
            done
        fi
        printf '</ul></div>'
        printf '<div class="card"><h2>Aktive Listener</h2><ul class="list">'
        if [ "${#ACTIVE_LISTENER_PROTOCOLS[@]}" -eq 0 ]; then
            printf '<li>Keine Listener erkannt</li>'
        else
            local k process_suffix
            for ((k=0; k<${#ACTIVE_LISTENER_PROTOCOLS[@]}; k++)); do
                process_suffix=""
                [ -n "${ACTIVE_LISTENER_PROCESSES[$k]}" ] && process_suffix=" (${ACTIVE_LISTENER_PROCESSES[$k]})"
                printf '<li>%s %s [%s]%s</li>' \
                    "$(html_escape "${ACTIVE_LISTENER_PROTOCOLS[$k]}")" \
                    "$(html_escape "${ACTIVE_LISTENER_BINDS[$k]}")" \
                    "$(html_escape "${ACTIVE_LISTENER_EXPOSURES[$k]}")" \
                    "$(html_escape "$process_suffix")"
            done
        fi
        printf '</ul></div></section>'

        if [ "$(count_issues_by_prefix 'ACT-')" -gt 0 ]; then
            printf '<section class="card"><h2>Aktive Tests</h2>'
            local a
            for ((a=0; a<${#ISSUE_IDS[@]}; a++)); do
                issue_id_has_prefix "${ISSUE_IDS[$a]}" 'ACT-' || continue
                printf '<article class="finding %s">' "$(status_css_class "${ISSUE_LEVELS[$a]}")"
                printf '<div class="pill %s">%s</div>' "$(status_css_class "${ISSUE_LEVELS[$a]}")" "$(html_escape "${ISSUE_LEVELS[$a]}")"
                printf '<h3>%s · %s</h3>' "$(html_escape "${ISSUE_IDS[$a]}")" "$(html_escape "${ISSUE_TITLES[$a]}")"
                printf '<p><strong>Beschreibung:</strong> %s</p>' "$(html_escape "${ISSUE_DESCRIPTIONS[$a]}")"
                printf '<p><strong>Empfehlung:</strong> %s</p>' "$(html_escape "${ISSUE_RECOMMENDATIONS[$a]}")"
                printf '</article>'
            done
            printf '</section>'
        fi

        printf '<section class="card"><h2>Probleme</h2>'
        if [ "${#ISSUE_IDS[@]}" -eq 0 ]; then
            printf '<p>Keine Probleme registriert.</p>'
        else
            local i
            for ((i=0; i<${#ISSUE_IDS[@]}; i++)); do
                issue_id_has_prefix "${ISSUE_IDS[$i]}" 'ACT-' && continue
                printf '<article class="finding %s">' "$(status_css_class "${ISSUE_LEVELS[$i]}")"
                printf '<div class="pill %s">%s</div>' "$(status_css_class "${ISSUE_LEVELS[$i]}")" "$(html_escape "${ISSUE_LEVELS[$i]}")"
                printf '<h3>%s · %s</h3>' "$(html_escape "${ISSUE_IDS[$i]}")" "$(html_escape "${ISSUE_TITLES[$i]}")"
                printf '<p><strong>Beschreibung:</strong> %s</p>' "$(html_escape "${ISSUE_DESCRIPTIONS[$i]}")"
                printf '<p><strong>Empfehlung:</strong> %s</p>' "$(html_escape "${ISSUE_RECOMMENDATIONS[$i]}")"
                printf '<p><strong>Fix-Kategorie:</strong> %s</p>' "$(html_escape "${ISSUE_FIX_CATEGORIES[$i]}")"
                printf '</article>'
            done
        fi
        printf '</section>'

        printf '<section class="card"><h2>Fix-Vorschlaege</h2>'
        if [ "${#FIX_IDS[@]}" -eq 0 ]; then
            printf '<p>Keine Fix-Vorschlaege registriert.</p>'
        else
            local j
            for ((j=0; j<${#FIX_IDS[@]}; j++)); do
                printf '<article class="finding %s">' "$(status_css_class "${FIX_CATEGORIES[$j]}")"
                printf '<div class="pill %s">%s</div>' "$(status_css_class "${FIX_CATEGORIES[$j]}")" "$(html_escape "${FIX_CATEGORIES[$j]}")"
                printf '<h3>%s · %s</h3>' "$(html_escape "${FIX_IDS[$j]}")" "$(html_escape "${FIX_TITLES[$j]}")"
                printf '<p><strong>Risiko:</strong> %s</p>' "$(html_escape "${FIX_RISKS[$j]}")"
                printf '<p><strong>Backup:</strong> %s</p>' "$(html_escape "${FIX_BACKUPS[$j]}")"
                printf '<p><strong>Befehl:</strong> %s</p>' "$(html_escape "${FIX_COMMANDS[$j]}")"
                printf '<p><strong>Test:</strong> %s</p>' "$(html_escape "${FIX_TESTS[$j]}")"
                printf '<p><strong>Reload:</strong> %s</p>' "$(html_escape "${FIX_RELOADS[$j]}")"
                printf '</article>'
            done
        fi
        printf '</section>'

        printf '<section class="card"><h2>Eingebetteter TXT-Report</h2><div class="mono">'
        while IFS= read -r line; do
            printf '%s\n' "$(html_escape "$line")"
        done <"$txt_file"
        printf '</div></section></div></body></html>'
    } >"$html_file"

    printf '%s' "$html_file"
}

show_reports() {
    ensure_report_context
    section "Reports"
    info "TXT:  $(generate_txt_report)"
    info "JSON: $(generate_json_report)"
    info "HTML: $(generate_html_report)"
}
