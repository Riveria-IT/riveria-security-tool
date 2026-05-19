#!/usr/bin/env bash

run_fix_handler() {
    local handler="$1"
    if [ -n "$handler" ] && declare -F "$handler" >/dev/null 2>&1; then
        FIX_ASSISTANT_MODE=1
        "$handler"
        FIX_ASSISTANT_MODE=0
    else
        warn "Kein technischer Handler fuer diesen Fix hinterlegt."
    fi
}

run_fix_by_index() {
    local index="$1"
    print_fix_step_header "$((index + 1))" "${#FIX_IDS[@]}" "${FIX_TITLES[$index]}"
    print_key_value "Problem" "${FIX_RISKS[$index]}"
    print_key_value "Kategorie" "${FIX_CATEGORIES[$index]}"
    print_key_value "Backup" "${FIX_BACKUPS[$index]}"
    print_key_value "Test" "${FIX_TESTS[$index]}"
    print_key_value "Reload" "${FIX_RELOADS[$index]}"
    print_key_value "Nachpruefung" "${FIX_RECHECKS[$index]}"
    if ask_yes_no "Fortfahren?"; then
        run_fix_handler "${FIX_HANDLERS[$index]}"
    else
        info "Fix uebersprungen."
    fi
}

run_fix_subset() {
    local mode="$1"
    local i matched=0

    for ((i=0; i<${#FIX_IDS[@]}; i++)); do
        case "$mode" in
            critical)
                [ "${FIX_LEVELS[$i]}" = "KRITISCH" ] || continue
                ;;
            all)
                ;;
        esac
        matched=1
        run_fix_by_index "$i"
    done

    [ "$matched" -eq 0 ] && info "Keine passenden Fixes fuer diese Auswahl."
}

run_fix_subset_by_category() {
    local category="$1"
    local i matched=0

    for ((i=0; i<${#FIX_IDS[@]}; i++)); do
        [ "${FIX_CATEGORIES[$i]}" = "$category" ] || continue
        matched=1
        run_fix_by_index "$i"
    done

    [ "$matched" -eq 0 ] && info "Keine passenden Fixes fuer diese Auswahl."
}

count_fixes_by_category() {
    local category="$1"
    local i count=0

    for ((i=0; i<${#FIX_IDS[@]}; i++)); do
        [ "${FIX_CATEGORIES[$i]}" = "$category" ] || continue
        count=$((count + 1))
    done

    printf '%s' "$count"
}

run_fix_selection_menu() {
    local choice

    while true; do
        section "Fix-Auswahl"
        local i
        for ((i=0; i<${#FIX_IDS[@]}; i++)); do
            printf '%s) %s [%s]\n' "$((i + 1))" "${FIX_TITLES[$i]}" "${FIX_CATEGORIES[$i]}"
        done
        printf '0) Zurueck\n'
        printf '\nAuswahl: '
        read -r choice

        case "$choice" in
            0) break ;;
            ''|*[!0-9]*) warn "Ungueltige Auswahl." ;;
            *)
                if [ "$choice" -ge 1 ] && [ "$choice" -le "${#FIX_IDS[@]}" ]; then
                    run_fix_by_index "$((choice - 1))"
                else
                    warn "Ungueltige Auswahl."
                fi
                ;;
        esac
    done
}

show_fix_suggestions() {
    section "Fix-Vorschlaege"
    if [ "${#FIX_IDS[@]}" -eq 0 ]; then
        info "Keine Fix-Vorschlaege registriert."
        return
    fi

    local i
    for ((i=0; i<${#FIX_IDS[@]}; i++)); do
        print_fix_step_header "$((i + 1))" "${#FIX_IDS[@]}" "${FIX_TITLES[$i]}"
        print_key_value "Problem" "${FIX_RISKS[$i]}"
        print_key_value "Kategorie" "${FIX_CATEGORIES[$i]}"
        print_key_value "Backup" "${FIX_BACKUPS[$i]}"
        print_key_value "Test" "${FIX_TESTS[$i]}"
        print_key_value "Reload" "${FIX_RELOADS[$i]}"
        print_key_value "Nachpruefung" "${FIX_RECHECKS[$i]}"
    done
}

show_beginner_fix_suggestions() {
    local i

    section "Einfache Fix-Hilfe"
    if [ "${#FIX_IDS[@]}" -eq 0 ]; then
        info "Keine vorbereiteten Fixes vorhanden."
        return
    fi

    for ((i=0; i<${#FIX_IDS[@]}; i++)); do
        printf '%s) %s [%s]\n' "$((i + 1))" "${FIX_TITLES[$i]}" "${FIX_CATEGORIES[$i]}"
        printf '   Warum: %s\n' "$(beginner_fix_reason_text "${FIX_IDS[$i]}" "${FIX_RISKS[$i]}")"
        printf '   Danach pruefen: %s\n' "${FIX_TESTS[$i]}"
    done
}

run_fix_assistant() {
    ensure_fix_context

    section "Fix-Assistent"
    if [ "${#FIX_IDS[@]}" -eq 0 ]; then
        info "Keine automatisch vorbereiteten Fixes vorhanden."
        return
    fi

    local choice
    while true; do
        cat <<'EOF'
1) Alle kritischen Probleme Schritt fuer Schritt beheben
2) Alle gefundenen Probleme Schritt fuer Schritt beheben
3) Einzelne Fixes auswaehlen
4) Nur Fix-Vorschlaege anzeigen
0) Zurueck
EOF
        printf '\nAuswahl: '
        read -r choice

        case "$choice" in
            1) run_fix_subset "critical" ;;
            2) run_fix_subset "all" ;;
            3) run_fix_selection_menu ;;
            4) show_fix_suggestions ;;
            0) break ;;
            *) warn "Ungueltige Auswahl." ;;
        esac
    done
}

run_beginner_fix_assistant() {
    ensure_fix_context

    section "Einfacher Fix-Assistent"
    if [ "${#FIX_IDS[@]}" -eq 0 ]; then
        info "Keine vorbereiteten Fixes vorhanden."
        return
    fi

    local choice
    while true; do
        cat <<'EOF'
1) Nur sichere automatische Fixes anwenden (empfohlen)
2) Alle Fix-Vorschlaege einfach erklaert anzeigen
3) Erweiterten Fix-Assistenten oeffnen
0) Zurueck
EOF
        printf '\nAuswahl: '
        read -r choice

        case "$choice" in
            1) run_fix_subset_by_category "AUTO-SAFE" ;;
            2) show_beginner_fix_suggestions ;;
            3) run_fix_assistant ;;
            0) break ;;
            *) warn "Ungueltige Auswahl." ;;
        esac
    done
}

run_updates_install() {
    section "Systemupdates"
    need_root

    if ! cmd_exists apt-get; then
        warn "apt-get ist nicht verfuegbar."
        return
    fi

    confirm_fix_action "Systemupdates ueber apt-get update && apt-get upgrade ausfuehren?" || {
        info "Systemupdates abgebrochen."
        return
    }

    if dry_run_enabled; then
        dry_run_info "Es wuerde 'apt-get update' und danach 'apt-get upgrade -y' ausgefuehrt."
        return
    fi

    if ! apt-get update; then
        bad "apt-get update fehlgeschlagen."
        return
    fi
    if ! apt-get upgrade -y; then
        bad "apt-get upgrade fehlgeschlagen."
        return
    fi

    ok "Systemupdates wurden ausgefuehrt."
}
