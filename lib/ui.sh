#!/usr/bin/env bash

header() {
    printf '\n%s%s%s\n' "$COLOR_BOLD" "$APP_NAME" "$COLOR_RESET"
    printf '%sVersion:%s %s\n\n' "$COLOR_DIM" "$COLOR_RESET" "$APP_VERSION"
}

section() {
    printf '\n%s== %s ==%s\n' "$COLOR_BOLD" "$1" "$COLOR_RESET"
}

ok() {
    printf '%s[OK]%s %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$1"
}

info() {
    printf '%s[INFO]%s %s\n' "$COLOR_BLUE" "$COLOR_RESET" "$1"
}

warn() {
    printf '%s[WARNUNG]%s %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$1"
}

bad() {
    printf '%s[KRITISCH]%s %s\n' "$COLOR_RED" "$COLOR_RESET" "$1"
}

pause() {
    printf '\nEnter druecken zum Fortfahren... '
    read -r _
}

print_fix_step_header() {
    local current="$1"
    local total="$2"
    local title="$3"
    printf '\n%sSchritt %s von %s: %s%s\n' "$COLOR_BOLD" "$current" "$total" "$title" "$COLOR_RESET"
}

print_key_value() {
    printf '%-16s %s\n' "$1:" "$2"
}

print_status_box() {
    printf '\n%sScore:%s %s/100\n' "$COLOR_BOLD" "$COLOR_RESET" "$SCORE"
    printf '%sStatus:%s %s\n' "$COLOR_BOLD" "$COLOR_RESET" "$STATUS_LABEL"
    printf '%sOK:%s %s  %sWarnungen:%s %s  %sKritisch:%s %s\n' \
        "$COLOR_BOLD" "$COLOR_RESET" "$OK_COUNT" \
        "$COLOR_BOLD" "$COLOR_RESET" "$WARN_COUNT" \
        "$COLOR_BOLD" "$COLOR_RESET" "$CRIT_COUNT"
}
