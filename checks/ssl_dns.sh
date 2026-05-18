#!/usr/bin/env bash

run_ssl_dns_checks() {
    section "SSL / DNS"

    if [ -z "$PUBLIC_WEB_URL" ]; then
        info "PUBLIC_WEB_URL ist nicht gesetzt."
        return
    fi

    local code host
    host="$(extract_host_from_url "$PUBLIC_WEB_URL")"
    code="$(get_http_code "$PUBLIC_WEB_URL")"
    info "HTTP-Status fuer PUBLIC_WEB_URL: $code"

    if [ -n "$host" ]; then
        info "Host: $host"
    fi

    if cmd_exists openssl && [ -n "$host" ]; then
        local cert_info
        cert_info="$(printf '' | openssl s_client -connect "${host}:443" -servername "$host" 2>/dev/null | openssl x509 -noout -issuer -subject -dates 2>/dev/null || true)"
        if [ -n "$cert_info" ]; then
            info "Zertifikatsdaten:"
            printf '%s\n' "$cert_info"
        else
            warn "Zertifikatsdaten konnten nicht gelesen werden."
        fi
    fi

    if cmd_exists getent && [ -n "$host" ]; then
        local a_records
        a_records="$(getent ahosts "$host" 2>/dev/null | awk '{print $1}' | sort -u | head -n 10 || true)"
        if [ -n "$a_records" ]; then
            info "A/AAAA Hinweise:"
            printf '%s\n' "$a_records"
        fi
    fi

    if [ -n "$host" ]; then
        local dns_domain mx_records txt_spf dmarc_txt cname_records
        dns_domain="${host#www.}"
        if cmd_exists dig; then
            mx_records="$(dig +short MX "$dns_domain" 2>/dev/null | head -n 10 || true)"
            txt_spf="$(dig +short TXT "$dns_domain" 2>/dev/null | grep 'v=spf1' | head -n 5 || true)"
            dmarc_txt="$(dig +short TXT "_dmarc.$dns_domain" 2>/dev/null | head -n 5 || true)"
            cname_records="$(dig +short CNAME "$host" 2>/dev/null | head -n 5 || true)"
        elif cmd_exists nslookup; then
            mx_records="$(nslookup -type=MX "$dns_domain" 2>/dev/null | grep 'mail exchanger' | head -n 10 || true)"
            txt_spf="$(nslookup -type=TXT "$dns_domain" 2>/dev/null | grep 'v=spf1' | head -n 5 || true)"
            dmarc_txt="$(nslookup -type=TXT "_dmarc.$dns_domain" 2>/dev/null | head -n 5 || true)"
        fi

        if [ -n "$cname_records" ]; then
            info "CNAME-Hinweise:"
            printf '%s\n' "$cname_records"
        fi
        if [ -n "$mx_records" ]; then
            info "MX-Hinweise:"
            printf '%s\n' "$mx_records"
        fi
        if [ -n "$txt_spf" ]; then
            info "SPF-Hinweise:"
            printf '%s\n' "$txt_spf"
        fi
        if [ -n "$dmarc_txt" ]; then
            info "DMARC-Hinweise:"
            printf '%s\n' "$dmarc_txt"
        fi
    fi
}
