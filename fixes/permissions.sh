#!/usr/bin/env bash

permissions_collect_sensitive_files() {
    local roots=("/var/www" "/srv" "/opt")
    local patterns=(
        ".env"
        "wp-config.php"
        "config.php"
        "config.inc.php"
        "database.php"
        "settings.php"
        "id_rsa"
        "*.pem"
        "*.key"
    )
    local root pattern file

    for root in "${roots[@]}"; do
        [ -d "$root" ] || continue
        for pattern in "${patterns[@]}"; do
            while IFS= read -r file; do
                [ -n "$file" ] && printf '%s\n' "$file"
            done < <(find "$root" -maxdepth 5 -type f -name "$pattern" 2>/dev/null | head -n 50)
        done
    done
}

permissions_collect_sensitive_files_in_webroot() {
    local file
    detect_webroots
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        path_is_under_webroot "$file" || continue
        printf '%s\n' "$file"
    done < <(permissions_collect_sensitive_files)
}

permissions_desired_mode() {
    local file="$1"
    case "$(basename "$file")" in
        .env|wp-config.php|config.php|config.inc.php|database.php|settings.php)
            printf '640'
            ;;
        id_rsa|*.pem|*.key)
            printf '600'
            ;;
        *)
            printf '640'
            ;;
    esac
}

permissions_is_sensitive_world_writable() {
    local file="$1"
    case "$(basename "$file")" in
        .env|wp-config.php|config.php|config.inc.php|database.php|settings.php|id_rsa|*.pem|*.key)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

permissions_fix_mode_for_file() {
    local file="$1"
    local desired current backup

    [ -f "$file" ] || return 0

    desired="$(permissions_desired_mode "$file")"
    current="$(get_octal_mode "$file")"
    [ -n "$current" ] || current="unknown"

    if [ "$current" = "$desired" ]; then
        info "Bereits passend: $file ($current)"
        return 0
    fi

    backup="$(safe_backup "$file")" || {
        bad "Backup fehlgeschlagen: $file"
        return 1
    }
    ok "Backup erstellt: $backup"

    if ! chmod "$desired" "$file" >/dev/null 2>&1; then
        bad "chmod fehlgeschlagen: $file"
        restore_backup "$backup" "$file" || true
        return 1
    fi

    current="$(get_octal_mode "$file")"
    if [ "$current" != "$desired" ]; then
        bad "Modus nach Aenderung unerwartet: $file ($current statt $desired)"
        restore_backup "$backup" "$file" || true
        return 1
    fi

    ok "Rechte gehaertet: $file -> $desired"
}

permissions_fix_sensitive_world_writable() {
    local file="$1"
    local backup current

    [ -f "$file" ] || return 0
    permissions_is_sensitive_world_writable "$file" || return 0

    backup="$(safe_backup "$file")" || {
        bad "Backup fehlgeschlagen: $file"
        return 1
    }
    ok "Backup erstellt: $backup"

    if ! chmod o-w "$file" >/dev/null 2>&1; then
        bad "o-w fehlgeschlagen: $file"
        restore_backup "$backup" "$file" || true
        return 1
    fi

    current="$(get_octal_mode "$file")"
    info "Other-write entfernt: $file ($current)"
}

fix_permissions_basics() {
    section "Rechte-Fixes"
    need_root

    local files=()
    local webroot_files=()
    local file
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        append_unique "$file" "${files[@]}" || files+=("$file")
    done < <(permissions_collect_sensitive_files)
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        append_unique "$file" "${webroot_files[@]}" || webroot_files+=("$file")
    done < <(permissions_collect_sensitive_files_in_webroot)

    if [ "${#files[@]}" -eq 0 ]; then
        info "Keine sensiblen Dateien in den Standardsuchpfaden gefunden."
        return
    fi

    info "Gepruefte sensible Dateien:"
    print_array_lines "${files[@]}"
    if [ "${#webroot_files[@]}" -gt 0 ]; then
        warn "Ein Teil der sensiblen Dateien liegt im erkannten Webroot."
        print_array_lines "${webroot_files[@]}"
        info "Der Fix haertet nur Dateirechte. Fuer Webroot-Dateien sollte zusaetzlich die Verzeichnisstruktur bereinigt werden."
    fi

    confirm_fix_action "Sensible Dateirechte gezielt haerten?" || {
        info "Rechte-Fix abgebrochen."
        return
    }

    if dry_run_enabled; then
        for file in "${files[@]}"; do
            dry_run_info "Dateirechte wuerden angepasst: $file -> $(permissions_desired_mode "$file")"
        done
        return
    fi

    for file in "${files[@]}"; do
        permissions_fix_mode_for_file "$file" || return
    done

    info "Gezielte Rechte-Haertung abgeschlossen."
}

fix_permissions_world_writable_configs() {
    section "World-writable Konfigs"
    need_root

    local files=()
    local webroot_files=()
    local file
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        permissions_is_sensitive_world_writable "$file" || continue
        append_unique "$file" "${files[@]}" || files+=("$file")
    done < <(find /var/www /srv /opt -xdev -type f -perm -0002 2>/dev/null | head -n 100)

    if [ "${#files[@]}" -eq 0 ]; then
        info "Keine sensiblen world-writable Dateien gefunden."
        return
    fi

    info "Betroffene sensible Dateien:"
    print_array_lines "${files[@]}"
    for file in "${files[@]}"; do
        path_is_under_webroot "$file" || continue
        append_unique "$file" "${webroot_files[@]}" || webroot_files+=("$file")
    done
    if [ "${#webroot_files[@]}" -gt 0 ]; then
        warn "World-writable Dateien im Webroot erkannt."
        print_array_lines "${webroot_files[@]}"
    fi

    confirm_fix_action "Other-write auf sensiblen Dateien entfernen?" || {
        info "World-writable-Fix abgebrochen."
        return
    }

    if dry_run_enabled; then
        for file in "${files[@]}"; do
            dry_run_info "Other-write wuerde entfernt: $file"
        done
        return
    fi

    for file in "${files[@]}"; do
        permissions_fix_sensitive_world_writable "$file" || return
    done

    info "Other-write auf sensiblen Dateien entfernt."
}
