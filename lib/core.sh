#!/usr/bin/env bash

APP_NAME="Riveria Server Audit & Hardening Tool"
APP_VERSION="1.0.0-alpha"

ENV_IMPORTED_PUBLIC_WEB_URL="${PUBLIC_WEB_URL-}"
ENV_IMPORTED_LOCAL_WEB_URL="${LOCAL_WEB_URL-}"
ENV_IMPORTED_WEB_PORT="${WEB_PORT-}"
ENV_IMPORTED_SSH_ALLOWED_USER="${SSH_ALLOWED_USER-}"
ENV_IMPORTED_REPORT_DIR="${REPORT_DIR-}"
ENV_IMPORTED_BACKUP_DIR="${BACKUP_DIR-}"
ENV_IMPORTED_QUARANTINE_DIR="${QUARANTINE_DIR-}"

CURRENT_USER="${SUDO_USER:-${USER:-unknown}}"
HOME_DIR="${HOME:-/root}"
REPORT_DIR="$HOME_DIR/security-reports"
BACKUP_DIR="$HOME_DIR/security-backups"
QUARANTINE_DIR="$HOME_DIR/security-quarantine"
PUBLIC_WEB_URL=""
LOCAL_WEB_URL=""
WEB_PORT="443"
SSH_ALLOWED_USER="$CURRENT_USER"
CONFIG_FILE="${CONFIG_FILE:-}"

COLOR_RED="$(printf '\033[31m')"
COLOR_GREEN="$(printf '\033[32m')"
COLOR_YELLOW="$(printf '\033[33m')"
COLOR_BLUE="$(printf '\033[34m')"
COLOR_BOLD="$(printf '\033[1m')"
COLOR_DIM="$(printf '\033[2m')"
COLOR_RESET="$(printf '\033[0m')"

SCORE=100
STATUS_LABEL="Gut"
WARN_COUNT=0
CRIT_COUNT=0
OK_COUNT=0
FIX_ASSISTANT_MODE=0

declare -a ISSUE_IDS=()
declare -a ISSUE_TITLES=()
declare -a ISSUE_LEVELS=()
declare -a ISSUE_DESCRIPTIONS=()
declare -a ISSUE_RECOMMENDATIONS=()
declare -a ISSUE_FIX_CATEGORIES=()
declare -a ISSUE_CAN_FIX=()

declare -a FIX_IDS=()
declare -a FIX_TITLES=()
declare -a FIX_RISKS=()
declare -a FIX_CATEGORIES=()
declare -a FIX_BACKUPS=()
declare -a FIX_COMMANDS=()
declare -a FIX_TESTS=()
declare -a FIX_RELOADS=()
declare -a FIX_RECHECKS=()
declare -a FIX_HANDLERS=()
declare -a FIX_LEVELS=()

declare -a DETECTED_COMPONENTS=()
declare -a DETECTED_PROFILES=()
declare -a DETECTED_PROJECTS=()

load_config() {
    local base_dir="$1"
    local default_config="$base_dir/config.conf"

    if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    elif [ -f "$default_config" ]; then
        # shellcheck source=/dev/null
        source "$default_config"
    fi

    apply_env_overrides

    ensure_runtime_dir "$base_dir" REPORT_DIR "reports"
    ensure_runtime_dir "$base_dir" BACKUP_DIR "backups"
    ensure_runtime_dir "$base_dir" QUARANTINE_DIR "quarantine"
}

apply_env_overrides() {
    [ -n "$ENV_IMPORTED_PUBLIC_WEB_URL" ] && PUBLIC_WEB_URL="$ENV_IMPORTED_PUBLIC_WEB_URL"
    [ -n "$ENV_IMPORTED_LOCAL_WEB_URL" ] && LOCAL_WEB_URL="$ENV_IMPORTED_LOCAL_WEB_URL"
    [ -n "$ENV_IMPORTED_WEB_PORT" ] && WEB_PORT="$ENV_IMPORTED_WEB_PORT"
    [ -n "$ENV_IMPORTED_SSH_ALLOWED_USER" ] && SSH_ALLOWED_USER="$ENV_IMPORTED_SSH_ALLOWED_USER"
    [ -n "$ENV_IMPORTED_REPORT_DIR" ] && REPORT_DIR="$ENV_IMPORTED_REPORT_DIR"
    [ -n "$ENV_IMPORTED_BACKUP_DIR" ] && BACKUP_DIR="$ENV_IMPORTED_BACKUP_DIR"
    [ -n "$ENV_IMPORTED_QUARANTINE_DIR" ] && QUARANTINE_DIR="$ENV_IMPORTED_QUARANTINE_DIR"
    return 0
}

need_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        printf '%s[WARNUNG]%s Bitte mit sudo oder als root ausfuehren.\n' "$COLOR_YELLOW" "$COLOR_RESET"
        exit 1
    fi
}

cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

append_unique() {
    local value="$1"
    shift
    local item
    for item in "$@"; do
        [ "$item" = "$value" ] && return 0
    done
    return 1
}

ask_yes_no() {
    local prompt="${1:-Fortfahren?}"
    local reply
    printf '%s [y/N] ' "$prompt"
    read -r reply
    case "$reply" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

safe_backup() {
    local target="$1"
    [ -f "$target" ] || return 1

    local timestamp backup_target
    timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
    backup_target="$BACKUP_DIR/${timestamp}_$(basename "$target")"
    cp -a "$target" "$backup_target"
    printf '%s' "$backup_target"
}

restore_backup() {
    local backup_file="$1"
    local target_file="$2"
    [ -f "$backup_file" ] || return 1
    cp -a "$backup_file" "$target_file"
}

get_octal_mode() {
    local target="$1"
    if cmd_exists stat; then
        stat -f '%Lp' "$target" 2>/dev/null || stat -c '%a' "$target" 2>/dev/null
    fi
}

get_http_code() {
    local url="$1"
    if cmd_exists curl; then
        curl -k -L -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null
    else
        printf '000'
    fi
}

get_headers() {
    local url="$1"
    if cmd_exists curl; then
        curl -k -I -sL "$url" 2>/dev/null
    fi
}

extract_host_from_url() {
    local url="$1"
    printf '%s\n' "$url" | sed -E 's#^[a-zA-Z]+://([^/:]+).*#\1#'
}

reset_results() {
    reset_report_context
    ISSUE_IDS=()
    ISSUE_TITLES=()
    ISSUE_LEVELS=()
    ISSUE_DESCRIPTIONS=()
    ISSUE_RECOMMENDATIONS=()
    ISSUE_FIX_CATEGORIES=()
    ISSUE_CAN_FIX=()
    FIX_IDS=()
    FIX_TITLES=()
    FIX_RISKS=()
    FIX_CATEGORIES=()
    FIX_BACKUPS=()
    FIX_COMMANDS=()
    FIX_TESTS=()
    FIX_RELOADS=()
    FIX_RECHECKS=()
    FIX_HANDLERS=()
    FIX_LEVELS=()
    DETECTED_COMPONENTS=()
    DETECTED_PROFILES=()
    DETECTED_PROJECTS=()
    SCORE=100
    STATUS_LABEL="Gut"
    WARN_COUNT=0
    CRIT_COUNT=0
    OK_COUNT=0
}

register_issue() {
    local id="$1"
    local title="$2"
    local level="$3"
    local description="$4"
    local recommendation="$5"
    local fix_category="${6:-MANUAL}"
    local can_fix="${7:-no}"

    ISSUE_IDS+=("$id")
    ISSUE_TITLES+=("$title")
    ISSUE_LEVELS+=("$level")
    ISSUE_DESCRIPTIONS+=("$description")
    ISSUE_RECOMMENDATIONS+=("$recommendation")
    ISSUE_FIX_CATEGORIES+=("$fix_category")
    ISSUE_CAN_FIX+=("$can_fix")

    case "$level" in
        OK) OK_COUNT=$((OK_COUNT + 1)) ;;
        WARNUNG) WARN_COUNT=$((WARN_COUNT + 1)) ;;
        KRITISCH) CRIT_COUNT=$((CRIT_COUNT + 1)) ;;
    esac
}

register_fix() {
    FIX_IDS+=("$1")
    FIX_TITLES+=("$2")
    FIX_RISKS+=("$3")
    FIX_CATEGORIES+=("$4")
    FIX_BACKUPS+=("$5")
    FIX_COMMANDS+=("$6")
    FIX_TESTS+=("$7")
    FIX_RELOADS+=("$8")
    FIX_RECHECKS+=("$9")
    FIX_HANDLERS+=("${10}")
    FIX_LEVELS+=("${11:-WARNUNG}")
}

register_detected_component() {
    local component="$1"
    append_unique "$component" "${DETECTED_COMPONENTS[@]-}" || DETECTED_COMPONENTS+=("$component")
}

register_detected_profile() {
    local profile="$1"
    append_unique "$profile" "${DETECTED_PROFILES[@]-}" || DETECTED_PROFILES+=("$profile")
}

register_detected_project() {
    local project="$1"
    append_unique "$project" "${DETECTED_PROJECTS[@]-}" || DETECTED_PROJECTS+=("$project")
}

print_array_lines() {
    local item
    for item in "$@"; do
        [ -n "$item" ] && printf -- '- %s\n' "$item"
    done
}

ensure_runtime_dir() {
    local base_dir="$1"
    local var_name="$2"
    local fallback_name="$3"
    local current_value fallback_value

    current_value="${!var_name}"
    if mkdir -p "$current_value" 2>/dev/null; then
        return 0
    fi

    fallback_value="$base_dir/.riveria-runtime/$fallback_name"
    mkdir -p "$fallback_value"
    printf -v "$var_name" '%s' "$fallback_value"
}

confirm_fix_action() {
    local prompt="$1"
    if [ "$FIX_ASSISTANT_MODE" -eq 1 ]; then
        return 0
    fi
    ask_yes_no "$prompt"
}

set_config_directive() {
    local file="$1"
    local directive="$2"
    local value="$3"
    local escaped_directive tmp_file

    [ -f "$file" ] || return 1
    tmp_file="$(mktemp)"
    escaped_directive="$(printf '%s' "$directive" | sed 's/[][\/.^$*]/\\&/g')"

    awk -v directive="$directive" -v value="$value" -v pattern="^[[:space:]]*#?[[:space:]]*"'"$escaped_directive"'"[[:space:]]+" '
        BEGIN { changed=0 }
        $0 ~ pattern && changed == 0 {
            printf "%s %s\n", directive, value
            changed=1
            next
        }
        { print }
        END {
            if (changed == 0) {
                printf "%s %s\n", directive, value
            }
        }
    ' "$file" >"$tmp_file" && mv "$tmp_file" "$file"
}

set_ini_directive() {
    local file="$1"
    local directive="$2"
    local value="$3"
    local escaped_directive tmp_file

    [ -f "$file" ] || return 1
    tmp_file="$(mktemp)"
    escaped_directive="$(printf '%s' "$directive" | sed 's/[][\/.^$*]/\\&/g')"

    awk -v directive="$directive" -v value="$value" -v pattern="^[[:space:]]*;?[[:space:]]*"'"$escaped_directive"'"[[:space:]]*=" '
        BEGIN { changed=0 }
        $0 ~ pattern && changed == 0 {
            printf "%s = %s\n", directive, value
            changed=1
            next
        }
        { print }
        END {
            if (changed == 0) {
                printf "%s = %s\n", directive, value
            }
        }
    ' "$file" >"$tmp_file" && mv "$tmp_file" "$file"
}

validate_command() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        ok "$description erfolgreich."
        return 0
    fi
    bad "$description fehlgeschlagen."
    return 1
}

reload_service_if_active() {
    local service_name="$1"

    if ! cmd_exists systemctl; then
        return 0
    fi

    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        systemctl reload "$service_name" >/dev/null 2>&1 || systemctl restart "$service_name" >/dev/null 2>&1
    fi
}

show_settings() {
    section "Einstellungen"
    print_key_value "PUBLIC_WEB_URL" "${PUBLIC_WEB_URL:-nicht gesetzt}"
    print_key_value "LOCAL_WEB_URL" "${LOCAL_WEB_URL:-nicht gesetzt}"
    print_key_value "WEB_PORT" "$WEB_PORT"
    print_key_value "SSH_ALLOWED_USER" "$SSH_ALLOWED_USER"
    print_key_value "REPORT_DIR" "$REPORT_DIR"
    print_key_value "BACKUP_DIR" "$BACKUP_DIR"
    print_key_value "QUARANTINE_DIR" "$QUARANTINE_DIR"
}

run_full_audit() {
    reset_results
    detect_services
    run_system_checks
    run_service_checks
    run_app_checks
    run_code_security_checks
    run_permission_checks
    run_exposure_checks
    run_docker_checks
    run_mail_checks
    run_ssl_dns_checks
    recalculate_score
    print_status_box
}

ensure_fix_context() {
    if [ "${#FIX_IDS[@]}" -eq 0 ] && [ "${#ISSUE_IDS[@]}" -eq 0 ]; then
        run_full_audit
    fi
}

main_menu() {
    local base_dir
    base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    load_config "$base_dir"
    need_root

    local choice
    while true; do
        header
        cat <<'EOF'
1) Vollstaendigen Sicherheitscheck ausfuehren
2) Serverrolle automatisch erkennen
3) Gefundene Probleme direkt beheben
4) Webapps / Kontaktformulare pruefen
5) Code Security pruefen
6) Sensible Dateien / Leaks pruefen
7) Rechte & Besitzer pruefen
8) Docker / Mailcow pruefen
9) Mailserver pruefen
10) SSL / DNS pruefen
11) Systemupdates installieren
12) UFW Firewall Basis setzen
13) Fail2ban installieren/aktivieren
14) SSH vorsichtig haerten
15) PHP haerten
16) nginx Security-Header-Snippet erstellen
17) Reports anzeigen
18) Einstellungen anzeigen
0) Beenden
EOF
        printf '\nAuswahl: '
        read -r choice

        case "$choice" in
            1) run_full_audit; pause ;;
            2) reset_results; detect_services; pause ;;
            3) run_fix_assistant; pause ;;
            4) reset_results; detect_services; run_app_checks; pause ;;
            5) reset_results; run_code_security_checks; recalculate_score; print_status_box; pause ;;
            6) reset_results; run_exposure_checks; recalculate_score; print_status_box; pause ;;
            7) reset_results; run_permission_checks; recalculate_score; print_status_box; pause ;;
            8) reset_results; detect_services; run_docker_checks; pause ;;
            9) reset_results; detect_services; run_mail_checks; pause ;;
            10) reset_results; run_ssl_dns_checks; pause ;;
            11) run_updates_install; pause ;;
            12) fix_setup_ufw; pause ;;
            13) fix_install_fail2ban; pause ;;
            14) fix_harden_ssh; pause ;;
            15) fix_harden_php; pause ;;
            16) fix_create_nginx_security_headers; pause ;;
            17) show_reports; pause ;;
            18) show_settings; pause ;;
            0) break ;;
            *) warn "Ungueltige Auswahl." ;;
        esac
    done
}
