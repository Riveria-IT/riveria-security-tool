#!/usr/bin/env bash

app_scan_roots() {
    detect_webroots
    if [ "${#DETECTED_WEBROOTS[@]}" -gt 0 ]; then
        printf '%s\n' "${DETECTED_WEBROOTS[@]}"
        return
    fi

    if [ "${#DETECTED_PROJECTS[@]}" -gt 0 ]; then
        local marker root roots=()
        for marker in "${DETECTED_PROJECTS[@]}"; do
            root="$(dirname "$marker")"
            append_unique "$root" "${roots[@]}" || roots+=("$root")
        done
        printf '%s\n' "${roots[@]}"
        return
    fi

    local root
    for root in /var/www /srv /opt; do
        [ -d "$root" ] && printf '%s\n' "$root"
    done
}

app_grep_hits() {
    local pattern="$1"
    local roots=()
    local root
    while IFS= read -r root; do
        [ -n "$root" ] && roots+=("$root")
    done < <(app_scan_roots)

    [ "${#roots[@]}" -gt 0 ] || return 0

    grep -RInE \
        --include='*.php' \
        --include='*.html' \
        --include='*.twig' \
        --include='*.js' \
        --include='*.ts' \
        --include='*.env' \
        --exclude-dir=.git \
        --exclude-dir=vendor \
        --exclude-dir=node_modules \
        --exclude-dir=storage \
        --exclude-dir=logs \
        "$pattern" "${roots[@]}" 2>/dev/null | head -n 20 || true
}

run_app_checks() {
    section "Webapp Checks"

    if [ "${#DETECTED_PROJECTS[@]}" -eq 0 ]; then
        info "Keine Webprojekte in den Standardsuchpfaden erkannt."
        return
    fi

    info "Gefundene Projektmarker:"
    print_array_lines "${DETECTED_PROJECTS[@]}"

    local form_hits mail_hits csrf_hits rate_hits captcha_hits
    local found_forms=0

    form_hits="$(app_grep_hits '(<form|method=["'"'"']post["'"'"']|contact|kontakt)')"
    if [ -n "$form_hits" ]; then
        found_forms=1
        info "Hinweise auf Formulare oder Kontaktseiten gefunden."
        printf '%s\n' "$form_hits"
    fi

    mail_hits="$(app_grep_hits '(PHPMailer|Symfony Mailer|mail[[:space:]]*\(|SMTP|MAIL_HOST|MAIL_PASSWORD)')"
    if [ -n "$mail_hits" ]; then
        register_issue "APP-001" "Mailversand- oder Kontaktlogik erkannt" "WARNUNG" \
            "Es wurden Hinweise auf Formulare oder Mailversand gefunden." \
            "Spam-Schutz, Eingabevalidierung und Versandlogik manuell pruefen." "MANUAL" "no"
        warn "Mailversand- oder Kontaktlogik erkannt."
        printf '%s\n' "$mail_hits"
    fi

    if [ "$found_forms" -eq 1 ]; then
        csrf_hits="$(app_grep_hits '(csrf|CSRF|token)')"
        if [ -n "$csrf_hits" ]; then
            ok "CSRF-Hinweise gefunden."
        else
            register_issue "APP-002" "Keine klaren CSRF-Hinweise gefunden" "WARNUNG" \
                "Es wurden Formularhinweise gefunden, aber keine klaren CSRF-Marker erkannt." \
                "Formulare manuell auf CSRF-Schutz pruefen." "MANUAL" "no"
            warn "Keine klaren CSRF-Hinweise gefunden. Manuell pruefen."
        fi

        rate_hits="$(app_grep_hits '(rate.limit|ratelimit|throttle)')"
        if [ -n "$rate_hits" ]; then
            ok "Rate-Limit-Hinweise gefunden."
        else
            register_issue "APP-003" "Keine klaren Rate-Limit-Hinweise gefunden" "WARNUNG" \
                "Bei Formular- oder Loginlogik wurden keine klaren Rate-Limit-Marker erkannt." \
                "Bruteforce- und Spam-Schutz manuell pruefen." "MANUAL" "no"
            warn "Keine klaren Rate-Limit-Hinweise gefunden. Manuell pruefen."
        fi

        captcha_hits="$(app_grep_hits '(captcha|recaptcha|hcaptcha)')"
        if [ -n "$captcha_hits" ]; then
            ok "Captcha-Hinweise gefunden."
        else
            register_issue "APP-004" "Keine klaren Captcha-Hinweise gefunden" "WARNUNG" \
                "Bei Formular- oder Mailversandlogik wurden keine klaren Captcha-Hinweise erkannt." \
                "Captcha nur nach fachlicher Pruefung ergaenzen." "MANUAL" "no"
            warn "Keine klaren Captcha-Hinweise gefunden. Manuell pruefen."
        fi
    fi
}
