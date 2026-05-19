#!/usr/bin/env bash

nginx_security_snippet_path() {
    printf '/etc/nginx/snippets/riveria-security-headers.conf'
}

nginx_find_candidate_files() {
    local files=()
    local file

    for file in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
        [ -f "$file" ] || continue
        grep -q 'server[[:space:]]*{' "$file" 2>/dev/null || continue
        files+=("$file")
    done

    printf '%s\n' "${files[@]}"
}

nginx_choose_target_file() {
    local host="${1:-}"
    local candidates=()
    local matched=()
    local file

    while IFS= read -r file; do
        [ -n "$file" ] && candidates+=("$file")
    done < <(nginx_find_candidate_files)

    if [ -n "$host" ]; then
        for file in "${candidates[@]}"; do
            if grep -Eq "server_name[^;]*\\b${host//./\\.}\\b" "$file" 2>/dev/null; then
                matched+=("$file")
            fi
        done
        if [ "${#matched[@]}" -eq 1 ]; then
            printf '%s' "${matched[0]}"
            return 0
        fi
    fi

    if [ "${#candidates[@]}" -eq 1 ]; then
        printf '%s' "${candidates[0]}"
        return 0
    fi

    return 1
}

nginx_server_block_count() {
    local file="$1"
    grep -c 'server[[:space:]]*{' "$file" 2>/dev/null
}

nginx_insert_include_once() {
    local file="$1"
    local snippet="$2"
    local tmp_file

    if grep -Fq "include $snippet;" "$file" 2>/dev/null; then
        return 0
    fi

    tmp_file="$(mktemp)"
    awk -v snippet="$snippet" '
        BEGIN { inserted=0 }
        /^[[:space:]]*server[[:space:]]*\{/ && inserted == 0 {
            print
            print "    include " snippet ";"
            inserted=1
            next
        }
        { print }
        END {
            if (inserted == 0) {
                exit 1
            }
        }
    ' "$file" >"$tmp_file" && mv "$tmp_file" "$file"
}

nginx_write_security_snippet() {
    local snippet_file="$1"
    local snippet_dir
    snippet_dir="$(dirname "$snippet_file")"

    mkdir -p "$snippet_dir" || return 1
    cat >"$snippet_file" <<'EOF'
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

location ~ /\.(?!well-known).* {
    deny all;
    return 404;
}
EOF
}

rollback_nginx_changes() {
    local snippet_file="$1"
    local snippet_backup="$2"
    local target_file="$3"
    local target_backup="$4"
    local snippet_created="${5:-0}"

    if [ -n "$target_backup" ] && [ -n "$target_file" ]; then
        restore_backup "$target_backup" "$target_file" && info "Backup wiederhergestellt: $target_file"
    fi

    if [ -n "$snippet_backup" ]; then
        restore_backup "$snippet_backup" "$snippet_file" && info "Backup wiederhergestellt: $snippet_file"
    elif [ "$snippet_created" -eq 1 ] && [ -f "$snippet_file" ]; then
        rm -f "$snippet_file"
        info "Neu erzeugtes Snippet entfernt: $snippet_file"
    fi
}

fix_create_nginx_security_headers() {
    section "nginx Security Header"
    need_root

    if [ "${#DETECTED_COMPONENTS[@]}" -eq 0 ]; then
        detect_services >/dev/null 2>&1
    fi

    if ! cmd_exists nginx; then
        bad "nginx ist nicht installiert."
        return
    fi

    local snippet_file target_file host server_blocks
    local snippet_backup="" target_backup="" snippet_created=0

    snippet_file="$(nginx_security_snippet_path)"
    host=""
    [ -n "$PUBLIC_WEB_URL" ] && host="$(extract_host_from_url "$PUBLIC_WEB_URL")"

    if ! target_file="$(nginx_choose_target_file "$host")"; then
        warn "Keine eindeutig passende nginx-Serverdatei gefunden."
        info "Snippet kann trotzdem erstellt werden. Include muss dann manuell in den passenden server-Block."
        target_file=""
    else
        server_blocks="$(nginx_server_block_count "$target_file")"
        if [ "${server_blocks:-0}" -ne 1 ]; then
            warn "Die erkannte Datei enthaelt mehrere server-Bloecke: $target_file"
            info "Automatische Einfuegung wird aus Sicherheitsgruenden uebersprungen."
            target_file=""
        fi
    fi

    print_key_value "Snippet" "$snippet_file"
    print_key_value "Zieldatei" "${target_file:-manuell erforderlich}"
    confirm_fix_action "nginx-Security-Snippet erstellen und wenn sicher moeglich einbinden?" || {
        info "nginx-Haertung abgebrochen."
        return
    }

    if dry_run_enabled; then
        dry_run_info "Snippet wuerde geschrieben: $snippet_file"
        if [ -n "$target_file" ]; then
            dry_run_info "Include wuerde eingefuegt: $target_file"
        else
            dry_run_info "Include muesste manuell gesetzt werden: include $snippet_file;"
        fi
        dry_run_info "Anschliessend wuerde 'nginx -t' und ein Reload von nginx erfolgen."
        return
    fi

    if [ -f "$snippet_file" ]; then
        snippet_backup="$(safe_backup "$snippet_file")" || {
            bad "Backup fehlgeschlagen: $snippet_file"
            return
        }
        ok "Backup erstellt: $snippet_backup"
    else
        snippet_created=1
    fi

    if [ -n "$target_file" ]; then
        target_backup="$(safe_backup "$target_file")" || {
            bad "Backup fehlgeschlagen: $target_file"
            rollback_nginx_changes "$snippet_file" "$snippet_backup" "$target_file" "$target_backup" "$snippet_created"
            return
        }
        ok "Backup erstellt: $target_backup"
    fi

    nginx_write_security_snippet "$snippet_file" || {
        bad "Snippet konnte nicht geschrieben werden."
        rollback_nginx_changes "$snippet_file" "$snippet_backup" "$target_file" "$target_backup" "$snippet_created"
        return
    }
    ok "Snippet geschrieben: $snippet_file"

    if [ -n "$target_file" ]; then
        nginx_insert_include_once "$target_file" "$snippet_file" || {
            bad "Include konnte nicht in $target_file eingefuegt werden."
            rollback_nginx_changes "$snippet_file" "$snippet_backup" "$target_file" "$target_backup" "$snippet_created"
            return
        }
        ok "Include eingefuegt: $target_file"
    else
        info "Bitte manuell in einen passenden server-Block einfuegen:"
        info "include $snippet_file;"
    fi

    if ! validate_command "nginx-Konfigurationstest" nginx -t; then
        rollback_nginx_changes "$snippet_file" "$snippet_backup" "$target_file" "$target_backup" "$snippet_created"
        return
    fi

    if cmd_exists systemctl; then
        if systemctl reload nginx >/dev/null 2>&1; then
            ok "nginx wurde neu geladen."
        else
            bad "nginx konnte nicht neu geladen werden."
            rollback_nginx_changes "$snippet_file" "$snippet_backup" "$target_file" "$target_backup" "$snippet_created"
            systemctl reload nginx >/dev/null 2>&1 || true
            return
        fi
    fi
}
