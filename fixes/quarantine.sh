#!/usr/bin/env bash

quarantine_collect_candidates() {
    local roots=("/var/www" "/srv" "/opt")
    local patterns=("*.sql" "*.bak" "*.old" "*.backup" "*.zip" "*.tar" "*.tar.gz" "wp-config.php.bak")
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

quarantine_collect_sensitive_key_candidates() {
    local roots=("/var/www" "/srv" "/opt")
    local patterns=("id_rsa" "*.pem" "*.key")
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

quarantine_timestamp_dir() {
    date '+%Y-%m-%d_%H-%M-%S'
}

quarantine_target_for_file() {
    local source_file="$1"
    local target_dir="$2"
    local base target counter

    base="$(basename "$source_file")"
    target="$target_dir/$base"
    counter=1

    while [ -e "$target" ]; do
        target="$target_dir/${counter}_$base"
        counter=$((counter + 1))
    done

    printf '%s' "$target"
}

quarantine_move_file() {
    local source_file="$1"
    local target_dir="$2"
    local target_file

    [ -f "$source_file" ] || return 0
    mkdir -p "$target_dir" || return 1
    target_file="$(quarantine_target_for_file "$source_file" "$target_dir")"

    mv "$source_file" "$target_file" || return 1
    ok "Verschoben: $source_file -> $target_file"
}

fix_quarantine_sensitive_files() {
    section "Quarantaene"
    need_root

    local files=()
    local key_files=()
    local file target_dir
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        append_unique "$file" "${files[@]}" || files+=("$file")
    done < <(quarantine_collect_candidates)
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        append_unique "$file" "${key_files[@]}" || key_files+=("$file")
    done < <(quarantine_collect_sensitive_key_candidates)

    if [ "${#files[@]}" -eq 0 ]; then
        info "Keine automatisch verschiebbaren Quarantaene-Kandidaten gefunden."
        if [ "${#key_files[@]}" -eq 0 ]; then
            return
        fi
    fi

    if [ "${#key_files[@]}" -gt 0 ]; then
        warn "Private Keys oder PEM-Dateien wurden erkannt und werden nicht automatisch verschoben."
        print_array_lines "${key_files[@]}"
        info "Diese Dateien koennen produktiv genutzt sein und muessen manuell geprueft werden."
        [ "${#files[@]}" -gt 0 ] || return
    fi

    target_dir="$QUARANTINE_DIR/$(quarantine_timestamp_dir)"
    print_key_value "Zielordner" "$target_dir"
    info "Gefundene Quarantaene-Kandidaten:"
    print_array_lines "${files[@]}"

    confirm_fix_action "Diese Dateien in die Quarantaene verschieben?" || {
        info "Quarantaene abgebrochen."
        return
    }

    if dry_run_enabled; then
        for file in "${files[@]}"; do
            dry_run_info "Datei wuerde in die Quarantaene verschoben: $file -> $target_dir/$(basename "$file")"
        done
        return
    fi

    mkdir -p "$target_dir" || {
        bad "Quarantaene-Ordner konnte nicht erstellt werden: $target_dir"
        return
    }

    for file in "${files[@]}"; do
        quarantine_move_file "$file" "$target_dir" || {
            bad "Verschieben fehlgeschlagen: $file"
            return
        }
    done

    info "Quarantaene abgeschlossen: $target_dir"
}
