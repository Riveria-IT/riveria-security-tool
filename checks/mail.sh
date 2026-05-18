#!/usr/bin/env bash

run_mail_checks() {
    section "Mailserver"

    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -Eq 'postfix|dovecot'; then
        ok "Mailserver-Komponenten erkannt."
    else
        info "Keine klassischen Mailserver-Komponenten erkannt."
        return
    fi

    if cmd_exists ss; then
        local mail_ports
        mail_ports="$(ss -tulpen 2>/dev/null | grep -E ':(25|465|587|993|995|4190)\b' || true)"
        if [ -n "$mail_ports" ]; then
            info "Mail-Port-Hinweise:"
            printf '%s\n' "$mail_ports"

            printf '%s\n' "$mail_ports" | grep -Eq ':(587)\b' && ok "SMTP Submission 587 erkannt." || warn "Port 587 nicht klar erkannt."
            printf '%s\n' "$mail_ports" | grep -Eq ':(993)\b' && ok "IMAPS 993 erkannt." || warn "Port 993 nicht klar erkannt."
            printf '%s\n' "$mail_ports" | grep -Eq ':(995)\b' && info "POP3S 995 erkannt." || true
        else
            warn "Keine typischen Mail-Ports in der Basispruefung gefunden."
        fi
    fi

    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -qx "rspamd"; then
        ok "Rspamd erkannt."
    fi
    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -qx "sogo"; then
        ok "SOGo erkannt."
    fi

    if printf '%s\n' "${DETECTED_PROFILES[@]}" | grep -qx "Mailcow Server"; then
        ok "Mailcow-Profil erkannt."
    fi

    if [ -d /opt/mailcow-dockerized ]; then
        if [ -f /opt/mailcow-dockerized/mailcow.conf ]; then
            info "Mailcow-Pfad und Konfiguration vorhanden."
        fi
    fi

    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -Eq 'postfix'; then
        ok "Postfix erkannt."
    fi
    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -Eq 'dovecot'; then
        ok "Dovecot erkannt."
    fi

    if [ -n "$PUBLIC_WEB_URL" ]; then
        local base_public_url rspamd_code sogo_code
        base_public_url="$(printf '%s\n' "$PUBLIC_WEB_URL" | sed -E 's#^([a-zA-Z]+://[^/]+).*#\1#')"
        if [ -n "$base_public_url" ]; then
            rspamd_code="$(get_http_code "$base_public_url/rspamd/")"
            sogo_code="$(get_http_code "$base_public_url/SOGo/")"

            if [ "$rspamd_code" = "200" ]; then
                register_issue "MAIL-001" "Rspamd Webinterface wirkt oeffentlich" "WARNUNG" \
                    "Die Basispruefung liefert fuer /rspamd/ einen HTTP-200-Hinweis." \
                    "Zugriffsschutz und Reverse-Proxy-Regeln pruefen." "MANUAL" "no"
                warn "Rspamd-Webinterface wirkt oeffentlich."
            fi

            if [ "$sogo_code" = "200" ]; then
                info "SOGo liefert HTTP 200. Oeffentlichkeit ist profilabhaengig zu pruefen."
            fi
        fi
    fi

    local mail_domain mx_records spf_records dmarc_records
    mail_domain="$(extract_host_from_url "$PUBLIC_WEB_URL")"
    mail_domain="${mail_domain#www.}"
    if [ -n "$mail_domain" ]; then
        if cmd_exists dig; then
            mx_records="$(dig +short MX "$mail_domain" 2>/dev/null | head -n 10 || true)"
            spf_records="$(dig +short TXT "$mail_domain" 2>/dev/null | grep 'v=spf1' | head -n 5 || true)"
            dmarc_records="$(dig +short TXT "_dmarc.$mail_domain" 2>/dev/null | head -n 5 || true)"
        elif cmd_exists nslookup; then
            mx_records="$(nslookup -type=MX "$mail_domain" 2>/dev/null | grep 'mail exchanger' | head -n 10 || true)"
            spf_records="$(nslookup -type=TXT "$mail_domain" 2>/dev/null | grep 'v=spf1' | head -n 5 || true)"
            dmarc_records="$(nslookup -type=TXT "_dmarc.$mail_domain" 2>/dev/null | head -n 5 || true)"
        fi

        if [ -n "$mx_records" ]; then
            info "MX-Hinweise:"
            printf '%s\n' "$mx_records"
        else
            warn "Keine klaren MX-Hinweise gefunden."
        fi

        if [ -n "$spf_records" ]; then
            ok "SPF-Hinweise gefunden."
            printf '%s\n' "$spf_records"
        else
            register_issue "MAIL-002" "Keine klaren SPF-Hinweise gefunden" "WARNUNG" \
                "Fuer die erkannte Domain wurden keine klaren SPF-TXT-Hinweise gefunden." \
                "SPF fuer Mailversand-Domain manuell pruefen." "MANUAL" "no"
            warn "Keine klaren SPF-Hinweise gefunden."
        fi

        if [ -n "$dmarc_records" ]; then
            ok "DMARC-Hinweise gefunden."
            printf '%s\n' "$dmarc_records"
        else
            register_issue "MAIL-003" "Keine klaren DMARC-Hinweise gefunden" "WARNUNG" \
                "Fuer die erkannte Domain wurden keine klaren DMARC-TXT-Hinweise gefunden." \
                "DMARC-Eintrag fuer die Mail-Domain manuell pruefen." "MANUAL" "no"
            warn "Keine klaren DMARC-Hinweise gefunden."
        fi
    fi
}
