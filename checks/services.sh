#!/usr/bin/env bash

run_service_checks() {
    section "Service Checks"

    if cmd_exists ss; then
        info "Offene Ports werden ueber ss ermittelt."
        local port_output
        port_output="$(ss -tulpen 2>/dev/null || true)"

        if printf '%s\n' "$port_output" | grep -Eq ':(3306|5432|6379|27017)\b'; then
            register_issue "SVC-001" "Datenbank-Port offen" "KRITISCH" \
                "Mindestens ein typischer Datenbank-Port lauscht auf dem System." \
                "Pruefen, ob Bind-Adresse oder Firewall angepasst werden muss." "GUIDED" "no"
            bad "Typischer Datenbank-Port gefunden."
        else
            ok "Keine typischen DB-Ports in Basispruefung gefunden."
        fi

        if printf '%s\n' "$port_output" | grep -Eq ':(22)\b'; then
            register_issue "SVC-010" "SSH-Port aktiv" "WARNUNG" \
                "SSH ist aktiv. Das ist normal, sollte aber gehaertet und geschuetzt werden." \
                "SSH-Konfiguration, Fail2ban und Firewall-Regeln pruefen." "AUTO-SAFE" "yes"
            warn "SSH-Port 22 erkannt."
        fi

        if printf '%s\n' "${DETECTED_PROFILES[@]}" | grep -Eq 'Webserver|PHP Backend|Laravel|Symfony|WordPress|Reverse Proxy|Webmail Server'; then
            if printf '%s\n' "$port_output" | grep -Eq ':(80|443)\b'; then
                ok "Web-Port 80/443 passend zum Webprofil erkannt."
            else
                info "Kein direkter 80/443-Listener erkannt. Reverse-Proxy- oder Offload-Szenario moeglich."
            fi
        fi

        if printf '%s\n' "$port_output" | grep -Eq ':(25)\b'; then
            if printf '%s\n' "${DETECTED_PROFILES[@]}" | grep -Eq 'Mailcow Server|Mailserver'; then
                ok "Port 25 passt zum Mailprofil."
            else
                register_issue "SVC-011" "Port 25 ohne klares Mailprofil aktiv" "WARNUNG" \
                    "SMTP Port 25 ist offen, aber es wurde kein klares Mailprofil erkannt." \
                    "Pruefen, ob ein Maildienst absichtlich aktiv ist oder Altlasten entfernt werden koennen." "GUIDED" "no"
                warn "Port 25 aktiv ohne klares Mailprofil."
            fi
        fi

        if printf '%s\n' "$port_output" | grep -Eq ':(8088)\b'; then
            if printf '%s\n' "${DETECTED_PROFILES[@]}" | grep -Eq 'Webmail Server|Reverse Proxy'; then
                info "Port 8088 erkannt und wirkt profilbedingt plausibel."
            else
                register_issue "SVC-012" "Port 8088 aktiv" "WARNUNG" \
                    "Port 8088 ist aktiv und sollte kontextabhaengig geprueft werden." \
                    "Reverse-Proxy-, Webmail- oder Spezialdienst-Zweck manuell pruefen." "MANUAL" "no"
                warn "Port 8088 aktiv."
            fi
        fi
    else
        warn "ss ist nicht verfuegbar."
    fi

    if ! cmd_exists ufw; then
        register_issue "SVC-005" "UFW nicht installiert" "WARNUNG" \
            "Die einfache Host-Firewall UFW ist nicht verfuegbar." \
            "UFW installieren oder bewusst ein alternatives Firewall-Konzept dokumentieren." "GUIDED" "no"
        warn "UFW ist nicht installiert."
    elif ! ufw status 2>/dev/null | grep -q '^Status: active'; then
        register_issue "SVC-006" "UFW nicht aktiv" "WARNUNG" \
            "UFW ist installiert, aber aktuell nicht aktiv." \
            "Basisregeln setzen und Firewall bewusst aktivieren." "AUTO-SAFE" "yes"
        register_fix "FIX-UFW-001" "UFW Basisregeln anwenden" \
            "Firewall ist installiert, aber nicht aktiv oder nicht gehaertet" "AUTO-SAFE" "/etc/default/ufw, /etc/ufw/user.rules, /etc/ufw/user6.rules" \
            "UFW Defaults setzen und profilbasierte Ports erlauben" "ufw status" "ufw enable" \
            "UFW-Status erneut pruefen" "fix_setup_ufw" "WARNUNG"
        warn "UFW ist installiert, aber nicht aktiv."
    else
        ok "UFW ist aktiv."
    fi

    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -qx "fail2ban"; then
        ok "Fail2ban erkannt."
    else
        register_issue "SVC-002" "Fail2ban fehlt" "WARNUNG" \
            "SSH- und Service-Bruteforce-Schutz ist nicht erkennbar." \
            "Fail2ban Installation pruefen." "AUTO-SAFE" "yes"
        register_fix "FIX-F2B-001" "Fail2ban installieren" \
            "Kein Brute-Force-Schutz erkannt" "AUTO-SAFE" "/etc/fail2ban/jail.local" \
            "apt-get install -y fail2ban" "systemctl is-active fail2ban" "systemctl restart fail2ban" \
            "Fail2ban erneut erkennen" "fix_install_fail2ban" "WARNUNG"
        warn "Fail2ban wurde nicht erkannt."
    fi

    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -qx "apache" && printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -qx "nginx"; then
        register_issue "SVC-009" "Apache und nginx gleichzeitig erkannt" "WARNUNG" \
            "Beide Webserver-Komponenten wurden erkannt. Das kann gewollt sein, ist aber haeufig auf Altlasten zurueckzufuehren." \
            "Pruefen, ob Apache noch benoetigt wird. Sonst deaktivieren." "GUIDED" "yes"
        register_fix "FIX-APACHE-001" "Apache deaktivieren falls ungenutzt" \
            "Apache wirkt moeglicherweise wie eine unnoetige Altlast" "GUIDED" "systemctl stop/disable apache2" \
            "Apache stoppen und deaktivieren, Ports danach pruefen" "apache2ctl configtest" "systemctl stop apache2" \
            "Portstatus erneut pruefen" "fix_disable_apache_if_unused" "WARNUNG"
        warn "Apache und nginx wurden gleichzeitig erkannt."
    fi

    if [ -f /etc/ssh/sshd_config ] && grep -Eq '^[[:space:]]*#?[[:space:]]*PermitRootLogin[[:space:]]+yes\b' /etc/ssh/sshd_config; then
        register_issue "SVC-003" "SSH Root-Login aktiv" "KRITISCH" \
            "Direkte Root-Anmeldung per SSH ist aktiv." \
            "PermitRootLogin auf no setzen und regulaeren Admin-User verwenden." "AUTO-SAFE" "yes"
        register_fix "FIX-SSH-001" "SSH Root-Login deaktivieren" \
            "Direkte Root-Anmeldung ueber SSH ist aktiv" "AUTO-SAFE" "/etc/ssh/sshd_config" \
            "PermitRootLogin no und SSH-Basiswerte setzen" "sshd -t -f /etc/ssh/sshd_config" "systemctl reload ssh" \
            "SSH-Konfiguration erneut pruefen" "fix_harden_ssh" "KRITISCH"
        bad "SSH Root-Login ist aktiv."
    fi

    local php_ini
    for php_ini in /etc/php/*/fpm/php.ini /etc/php/*/apache2/php.ini; do
        [ -f "$php_ini" ] || continue
        if grep -Eq '^[[:space:]]*expose_php[[:space:]]*=[[:space:]]*On\b' "$php_ini"; then
            register_issue "SVC-004" "PHP expose_php aktiv" "WARNUNG" \
                "PHP verrät seine Version ueber HTTP-Header oder Ausgaben." \
                "expose_php deaktivieren und Session-Defaults haerten." "AUTO-SAFE" "yes"
            register_fix "FIX-PHP-001" "PHP-Konfiguration haerten" \
                "Unsichere oder unnötig gesprächige PHP-Defaults erkannt" "AUTO-SAFE" "$php_ini" \
                "php.ini absichern und Dienste neu laden" "php -c <php.ini> -m" "php-fpm/nginx/apache reload" \
                "PHP-Einstellungen erneut pruefen" "fix_harden_php" "WARNUNG"
            warn "PHP expose_php ist aktiv: $php_ini"
            break
        fi
    done

    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -qx "nginx"; then
        local nginx_snippet="/etc/nginx/snippets/riveria-security-headers.conf"
        if [ ! -f "$nginx_snippet" ]; then
            register_issue "SVC-007" "nginx Security-Snippet fehlt" "WARNUNG" \
                "Ein zentrales Riveria-Snippet fuer Security-Header und Dotfile-Schutz ist nicht vorhanden." \
                "Snippet erstellen und in einen passenden server-Block einbinden." "AUTO-SAFE" "yes"
            register_fix "FIX-NGX-001" "nginx Security-Snippet erstellen" \
                "Sicherheitsheader oder Dotfile-Schutz sind nicht zentral hinterlegt" "AUTO-SAFE" "$nginx_snippet" \
                "Snippet schreiben, sicher einbinden und nginx testen" "nginx -t" "systemctl reload nginx" \
                "nginx-Konfiguration erneut pruefen" "fix_create_nginx_security_headers" "WARNUNG"
            warn "nginx Security-Snippet fehlt."
        elif ! grep -RqsF "include $nginx_snippet;" /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null; then
            register_issue "SVC-008" "nginx Snippet nicht eingebunden" "WARNUNG" \
                "Das Security-Snippet existiert, ist aber in den geprueften server-Dateien nicht eingebunden." \
                "Include in einen passenden server-Block einfuegen und nginx testen." "AUTO-SAFE" "yes"
            register_fix "FIX-NGX-002" "nginx Security-Snippet einbinden" \
                "Vorhandenes Security-Snippet wird noch nicht genutzt" "AUTO-SAFE" "/etc/nginx/sites-enabled/* oder /etc/nginx/conf.d/*.conf" \
                "Include sicher in passende Serverdatei einfuegen" "nginx -t" "systemctl reload nginx" \
                "nginx-Konfiguration erneut pruefen" "fix_create_nginx_security_headers" "WARNUNG"
            warn "nginx Security-Snippet ist noch nicht eingebunden."
        else
            ok "nginx Security-Snippet ist vorhanden und eingebunden."
        fi
    fi
}
