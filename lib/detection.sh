#!/usr/bin/env bash

detect_services() {
    section "Server-Erkennung"

    if cmd_exists systemctl; then
        systemctl is-active --quiet nginx 2>/dev/null && register_detected_component "nginx"
        systemctl is-active --quiet apache2 2>/dev/null && register_detected_component "apache"
        systemctl list-units 'php*-fpm.service' --no-legend 2>/dev/null | grep -q 'running' && register_detected_component "php-fpm"
        systemctl is-active --quiet mariadb 2>/dev/null && register_detected_component "mariadb"
        systemctl is-active --quiet mysql 2>/dev/null && register_detected_component "mysql"
        systemctl is-active --quiet postgresql 2>/dev/null && register_detected_component "postgresql"
        systemctl is-active --quiet redis-server 2>/dev/null && register_detected_component "redis"
        systemctl is-active --quiet mongod 2>/dev/null && register_detected_component "mongodb"
        systemctl is-active --quiet docker 2>/dev/null && register_detected_component "docker"
        systemctl is-active --quiet fail2ban 2>/dev/null && register_detected_component "fail2ban"
        systemctl is-active --quiet ufw 2>/dev/null && register_detected_component "ufw"
        systemctl is-active --quiet postfix 2>/dev/null && register_detected_component "postfix"
        systemctl is-active --quiet dovecot 2>/dev/null && register_detected_component "dovecot"
        systemctl is-active --quiet rspamd 2>/dev/null && register_detected_component "rspamd"
        systemctl is-active --quiet sogo 2>/dev/null && register_detected_component "sogo"
    fi

    cmd_exists docker && register_detected_component "docker"
    cmd_exists docker-compose && register_detected_component "docker-compose"
    cmd_exists php && register_detected_component "php"
    cmd_exists node && register_detected_component "nodejs"
    cmd_exists python3 && register_detected_component "python"
    cmd_exists ruby && register_detected_component "ruby"
    cmd_exists certbot && register_detected_component "certbot"
    cmd_exists iptables && register_detected_component "iptables"
    cmd_exists nft && register_detected_component "nftables"

    [ -d /opt/mailcow-dockerized ] && register_detected_component "mailcow"

    detect_projects
    detect_profiles

    if [ "${#DETECTED_COMPONENTS[@]}" -eq 0 ]; then
        info "Noch keine typischen Komponenten erkannt."
    else
        print_array_lines "${DETECTED_COMPONENTS[@]}"
    fi
}

detect_projects() {
    local roots=("/var/www" "/srv" "/opt")
    local root
    for root in "${roots[@]}"; do
        [ -d "$root" ] || continue

        while IFS= read -r path; do
            register_detected_project "$path"
            case "$(basename "$path")" in
                composer.json) register_detected_profile "PHP Backend" ;;
                package.json) register_detected_profile "Node.js App" ;;
                requirements.txt|pyproject.toml) register_detected_profile "Python App" ;;
                Gemfile) register_detected_profile "Ruby App" ;;
                artisan) register_detected_profile "Laravel" ;;
                console) register_detected_profile "Symfony" ;;
                wp-config.php) register_detected_profile "WordPress" ;;
                .env) register_detected_component "env-config" ;;
                config.php) register_detected_component "custom-php-config" ;;
            esac
        done < <(find "$root" -maxdepth 3 \( -name composer.json -o -name package.json -o -name requirements.txt -o -name pyproject.toml -o -name Gemfile -o -name artisan -o -path '*/bin/console' -o -name wp-config.php -o -name .env -o -name config.php \) 2>/dev/null | head -n 80)

        find "$root" -maxdepth 3 -type d \( -name vendor -o -name node_modules -o -name storage -o -name public \) 2>/dev/null | while IFS= read -r path; do
            case "$(basename "$path")" in
                vendor) register_detected_component "php-dependencies" ;;
                node_modules) register_detected_component "node-dependencies" ;;
                storage) register_detected_component "laravel-storage" ;;
                public) register_detected_component "public-webroot" ;;
            esac
        done
    done
}

detect_profiles() {
    [ "${#DETECTED_PROJECTS[@]}" -gt 0 ] && register_detected_profile "Webserver"
    detect_proxy_backends

    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -qx "docker"; then
        register_detected_profile "Docker Host"
    fi
    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -qx "mailcow"; then
        register_detected_profile "Mailcow Server"
    fi
    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -Eq 'postfix|dovecot'; then
        register_detected_profile "Mailserver"
    fi
    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -Eq 'nginx' && printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -Eq 'postfix|dovecot|sogo'; then
        register_detected_profile "Webmail Server"
    fi
    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -Eq 'mariadb|mysql|postgresql'; then
        register_detected_profile "Datenbankserver"
    fi
    if printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -Eq 'nginx' && [ -n "$LOCAL_WEB_URL" ] && [ -n "$WEB_PORT" ] && [ "$WEB_PORT" != "80" ] && [ "$WEB_PORT" != "443" ]; then
        register_detected_profile "Reverse Proxy"
    fi
    if [ -n "$PUBLIC_WEB_URL" ] && [ -n "$LOCAL_WEB_URL" ] && printf '%s\n' "$LOCAL_WEB_URL" | grep -Eq '127\.0\.0\.1|localhost'; then
        register_detected_profile "Reverse Proxy"
    fi
    if [ "${#PROXY_BACKEND_TARGETS[@]}" -gt 0 ] && printf '%s\n' "${DETECTED_COMPONENTS[@]}" | grep -Eq 'nginx|apache'; then
        register_detected_profile "Reverse Proxy"
    fi
    if printf '%s\n' "${DETECTED_PROJECTS[@]-}" | grep -Eqi '(contact|kontakt|mailer|mail)'; then
        register_detected_profile "Kontaktformular/Mailversand"
    fi
    if [ "${#DETECTED_PROFILES[@]}" -eq 0 ]; then
        register_detected_profile "Minimal Server"
    fi
}
