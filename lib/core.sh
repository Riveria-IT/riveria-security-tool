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
ENV_IMPORTED_NGINX_SITES_ENABLED_DIR="${NGINX_SITES_ENABLED_DIR-}"
ENV_IMPORTED_NGINX_CONF_D_DIR="${NGINX_CONF_D_DIR-}"
ENV_IMPORTED_APACHE_SITES_ENABLED_DIR="${APACHE_SITES_ENABLED_DIR-}"
ENV_IMPORTED_APACHE_SITES_AVAILABLE_DIR="${APACHE_SITES_AVAILABLE_DIR-}"
ENV_IMPORTED_MAILCOW_PATH="${MAILCOW_PATH-}"
ENV_IMPORTED_DOCKER_PS_OUTPUT="${DOCKER_PS_OUTPUT-}"
ENV_IMPORTED_DOCKER_INFO_OK="${DOCKER_INFO_OK-}"
ENV_IMPORTED_DRY_RUN_MODE="${DRY_RUN_MODE-}"
ENV_IMPORTED_RESULT_VIEW_MODE="${RESULT_VIEW_MODE-}"
ENV_IMPORTED_LAB_VALIDATION_AUTO_CONFIRM="${LAB_VALIDATION_AUTO_CONFIRM-}"

CURRENT_USER="${SUDO_USER:-${USER:-unknown}}"
HOME_DIR="${HOME:-/root}"
REPORT_DIR="$HOME_DIR/security-reports"
BACKUP_DIR="$HOME_DIR/security-backups"
QUARANTINE_DIR="$HOME_DIR/security-quarantine"
PUBLIC_WEB_URL=""
LOCAL_WEB_URL=""
WEB_PORT="443"
SSH_ALLOWED_USER="$CURRENT_USER"
NGINX_SITES_ENABLED_DIR="/etc/nginx/sites-enabled"
NGINX_CONF_D_DIR="/etc/nginx/conf.d"
APACHE_SITES_ENABLED_DIR="/etc/apache2/sites-enabled"
APACHE_SITES_AVAILABLE_DIR="/etc/apache2/sites-available"
MAILCOW_PATH="/opt/mailcow-dockerized"
DOCKER_PS_OUTPUT=""
DOCKER_INFO_OK=""
DRY_RUN_MODE="0"
RESULT_VIEW_MODE="technical"
LAB_VALIDATION_AUTO_CONFIRM="0"
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
declare -a ACTIVE_LISTENER_PROTOCOLS=()
declare -a ACTIVE_LISTENER_PORTS=()
declare -a ACTIVE_LISTENER_BINDS=()
declare -a ACTIVE_LISTENER_PROCESSES=()
declare -a ACTIVE_LISTENER_EXPOSURES=()
declare -a PROXY_BACKEND_TARGETS=()
declare -a PROXY_BACKEND_PORTS=()
declare -a PROXY_BACKEND_SOURCES=()
declare -a DETECTED_WEBROOTS=()
declare -a DETECTED_WEBROOT_SOURCES=()
AUDIT_MODE_FULL_STATUS="nicht getestet"
AUDIT_MODE_ACTIVE_SAFE_STATUS="nicht getestet"
AUDIT_MODE_LAB_LOCAL_STATUS="nicht getestet"

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
    [ -n "$ENV_IMPORTED_NGINX_SITES_ENABLED_DIR" ] && NGINX_SITES_ENABLED_DIR="$ENV_IMPORTED_NGINX_SITES_ENABLED_DIR"
    [ -n "$ENV_IMPORTED_NGINX_CONF_D_DIR" ] && NGINX_CONF_D_DIR="$ENV_IMPORTED_NGINX_CONF_D_DIR"
    [ -n "$ENV_IMPORTED_APACHE_SITES_ENABLED_DIR" ] && APACHE_SITES_ENABLED_DIR="$ENV_IMPORTED_APACHE_SITES_ENABLED_DIR"
    [ -n "$ENV_IMPORTED_APACHE_SITES_AVAILABLE_DIR" ] && APACHE_SITES_AVAILABLE_DIR="$ENV_IMPORTED_APACHE_SITES_AVAILABLE_DIR"
    [ -n "$ENV_IMPORTED_MAILCOW_PATH" ] && MAILCOW_PATH="$ENV_IMPORTED_MAILCOW_PATH"
    [ -n "$ENV_IMPORTED_DOCKER_PS_OUTPUT" ] && DOCKER_PS_OUTPUT="$ENV_IMPORTED_DOCKER_PS_OUTPUT"
    [ -n "$ENV_IMPORTED_DOCKER_INFO_OK" ] && DOCKER_INFO_OK="$ENV_IMPORTED_DOCKER_INFO_OK"
    [ -n "$ENV_IMPORTED_DRY_RUN_MODE" ] && DRY_RUN_MODE="$ENV_IMPORTED_DRY_RUN_MODE"
    [ -n "$ENV_IMPORTED_RESULT_VIEW_MODE" ] && RESULT_VIEW_MODE="$ENV_IMPORTED_RESULT_VIEW_MODE"
    [ -n "$ENV_IMPORTED_LAB_VALIDATION_AUTO_CONFIRM" ] && LAB_VALIDATION_AUTO_CONFIRM="$ENV_IMPORTED_LAB_VALIDATION_AUTO_CONFIRM"
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

dry_run_enabled() {
    case "${DRY_RUN_MODE:-0}" in
        1|true|TRUE|yes|YES|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

dry_run_label() {
    if dry_run_enabled; then
        printf 'aktiv'
    else
        printf 'inaktiv'
    fi
}

dry_run_info() {
    info "[DRY-RUN] $1"
}

toggle_dry_run_mode() {
    if dry_run_enabled; then
        DRY_RUN_MODE="0"
        info "Dry-Run-Modus deaktiviert."
    else
        DRY_RUN_MODE="1"
        warn "Dry-Run-Modus aktiviert. Fixes zeigen nur geplante Aenderungen und schreiben nichts."
    fi
}

result_view_simple_enabled() {
    case "${RESULT_VIEW_MODE:-technical}" in
        simple|einfach)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

result_view_label() {
    if result_view_simple_enabled; then
        printf 'einfach'
    else
        printf 'technisch'
    fi
}

toggle_result_view_mode() {
    if result_view_simple_enabled; then
        RESULT_VIEW_MODE="technical"
        info "Ergebnis-Sprache auf technisch gestellt."
    else
        RESULT_VIEW_MODE="simple"
        info "Ergebnis-Sprache auf einfach gestellt."
    fi
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
    ACTIVE_LISTENER_PROTOCOLS=()
    ACTIVE_LISTENER_PORTS=()
    ACTIVE_LISTENER_BINDS=()
    ACTIVE_LISTENER_PROCESSES=()
    ACTIVE_LISTENER_EXPOSURES=()
    PROXY_BACKEND_TARGETS=()
    PROXY_BACKEND_PORTS=()
    PROXY_BACKEND_SOURCES=()
    DETECTED_WEBROOTS=()
    DETECTED_WEBROOT_SOURCES=()
    AUDIT_MODE_FULL_STATUS="nicht getestet"
    AUDIT_MODE_ACTIVE_SAFE_STATUS="nicht getestet"
    AUDIT_MODE_LAB_LOCAL_STATUS="nicht getestet"
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

normalize_path() {
    local path="$1"
    if [ -d "$path" ] || [ -f "$path" ]; then
        (
            cd "$path" 2>/dev/null && pwd
        ) || (
            cd "$(dirname "$path")" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$(basename "$path")"
        )
    else
        printf '%s\n' "$path" | sed -E 's#/$##'
    fi
}

listener_port_from_bind() {
    local bind="$1"
    bind="${bind##*\]:}"
    bind="${bind##*:}"
    printf '%s' "$bind"
}

listener_host_from_bind() {
    local bind="$1"
    if printf '%s' "$bind" | grep -q '^\['; then
        bind="${bind#\[}"
        printf '%s' "${bind%%]*}"
        return 0
    fi

    if printf '%s' "$bind" | grep -q ':'; then
        printf '%s' "${bind%:*}"
        return 0
    fi

    printf '%s' "$bind"
}

listener_exposure_from_host() {
    local host="$1"
    case "$host" in
        127.0.0.1|::1|localhost)
            printf 'local'
            ;;
        0.0.0.0|::|\*)
            printf 'public'
            ;;
        "")
            printf 'unknown'
            ;;
        *)
            printf 'public'
            ;;
    esac
}

register_active_listener() {
    local protocol="$1"
    local bind="$2"
    local process="$3"
    local port host exposure
    local i

    [ -n "$protocol" ] || return 0
    [ -n "$bind" ] || return 0

    port="$(listener_port_from_bind "$bind")"
    host="$(listener_host_from_bind "$bind")"
    exposure="$(listener_exposure_from_host "$host")"

    for ((i=0; i<${#ACTIVE_LISTENER_PROTOCOLS[@]}; i++)); do
        if [ "${ACTIVE_LISTENER_PROTOCOLS[$i]}" = "$protocol" ] && [ "${ACTIVE_LISTENER_BINDS[$i]}" = "$bind" ]; then
            return 0
        fi
    done

    ACTIVE_LISTENER_PROTOCOLS+=("$protocol")
    ACTIVE_LISTENER_PORTS+=("$port")
    ACTIVE_LISTENER_BINDS+=("$bind")
    ACTIVE_LISTENER_PROCESSES+=("$process")
    ACTIVE_LISTENER_EXPOSURES+=("$exposure")
}

detect_active_listeners() {
    local listener_output line protocol bind process

    [ "${#ACTIVE_LISTENER_PROTOCOLS[@]}" -eq 0 ] || return 0
    cmd_exists ss || return 0

    listener_output="$(ss -H -lntuap 2>/dev/null || true)"
    [ -n "$listener_output" ] || return 0

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        protocol="$(printf '%s\n' "$line" | awk '{print $1}')"
        bind="$(printf '%s\n' "$line" | awk '{print $5}')"
        process="$(printf '%s\n' "$line" | awk '{$1=$2=$3=$4=$5=$6=""; sub(/^[[:space:]]+/, ""); print}')"
        register_active_listener "$protocol" "$bind" "$process"
    done <<EOF
$listener_output
EOF
}

active_listener_exists() {
    local port="$1"
    local exposure_filter="${2:-}"
    local i

    detect_active_listeners
    for ((i=0; i<${#ACTIVE_LISTENER_PORTS[@]}; i++)); do
        [ "${ACTIVE_LISTENER_PORTS[$i]}" = "$port" ] || continue
        if [ -n "$exposure_filter" ] && [ "${ACTIVE_LISTENER_EXPOSURES[$i]}" != "$exposure_filter" ]; then
            continue
        fi
        return 0
    done
    return 1
}

listener_process_matches() {
    local pattern="$1"
    local exposure_filter="${2:-}"
    local i

    detect_active_listeners
    for ((i=0; i<${#ACTIVE_LISTENER_PROCESSES[@]}; i++)); do
        if [ -n "$exposure_filter" ] && [ "${ACTIVE_LISTENER_EXPOSURES[$i]}" != "$exposure_filter" ]; then
            continue
        fi
        printf '%s\n' "${ACTIVE_LISTENER_PROCESSES[$i]}" | grep -Eiq "$pattern" && return 0
    done
    return 1
}

list_listener_binds_for_process() {
    local pattern="$1"
    local exposure_filter="${2:-}"
    local i

    detect_active_listeners
    for ((i=0; i<${#ACTIVE_LISTENER_PROCESSES[@]}; i++)); do
        if [ -n "$exposure_filter" ] && [ "${ACTIVE_LISTENER_EXPOSURES[$i]}" != "$exposure_filter" ]; then
            continue
        fi
        if printf '%s\n' "${ACTIVE_LISTENER_PROCESSES[$i]}" | grep -Eiq "$pattern"; then
            printf '%s\n' "${ACTIVE_LISTENER_BINDS[$i]}"
        fi
    done
}

proxy_target_port() {
    local target="$1"
    local host_port

    case "$target" in
        unix:*)
            printf 'unix'
            return 0
            ;;
    esac

    host_port="$(printf '%s\n' "$target" | sed -E 's#^[a-zA-Z]+://##')"
    host_port="${host_port%%/*}"
    host_port="${host_port##*@}"
    if printf '%s' "$host_port" | grep -q '^\['; then
        host_port="${host_port#\[}"
        host_port="${host_port%%]*:*}:${host_port##*\]:}"
    fi
    printf '%s' "${host_port##*:}"
}

register_proxy_backend_target() {
    local target="$1"
    local source="$2"
    local port
    local i

    [ -n "$target" ] || return 0
    port="$(proxy_target_port "$target")"
    [ -n "$port" ] || return 0

    for ((i=0; i<${#PROXY_BACKEND_TARGETS[@]}; i++)); do
        if [ "${PROXY_BACKEND_TARGETS[$i]}" = "$target" ] && [ "${PROXY_BACKEND_SOURCES[$i]}" = "$source" ]; then
            return 0
        fi
    done

    PROXY_BACKEND_TARGETS+=("$target")
    PROXY_BACKEND_PORTS+=("$port")
    PROXY_BACKEND_SOURCES+=("$source")
}

detect_proxy_backends() {
    local file line target

    [ "${#PROXY_BACKEND_TARGETS[@]}" -eq 0 ] || return 0

    for file in "$NGINX_SITES_ENABLED_DIR"/* "$NGINX_CONF_D_DIR"/*.conf; do
        [ -f "$file" ] || continue
        while IFS= read -r line; do
            target="$(printf '%s\n' "$line" | sed -E 's#.*proxy_pass[[:space:]]+([^;]+);.*#\1#')"
            [ -n "$target" ] && register_proxy_backend_target "$target" "$file"
        done < <(grep -E 'proxy_pass[[:space:]]+' "$file" 2>/dev/null || true)
        while IFS= read -r line; do
            target="$(printf '%s\n' "$line" | sed -E 's#.*fastcgi_pass[[:space:]]+([^;]+);.*#\1#')"
            [ -n "$target" ] && register_proxy_backend_target "$target" "$file"
        done < <(grep -E 'fastcgi_pass[[:space:]]+' "$file" 2>/dev/null || true)
    done

    for file in "$APACHE_SITES_ENABLED_DIR"/* "$APACHE_SITES_AVAILABLE_DIR"/*; do
        [ -f "$file" ] || continue
        while IFS= read -r line; do
            target="$(printf '%s\n' "$line" | sed -E 's#.*ProxyPass([[:space:]]+[^[:space:]]+)?[[:space:]]+([^[:space:]]+).*#\2#')"
            [ -n "$target" ] && register_proxy_backend_target "$target" "$file"
        done < <(grep -E '^[[:space:]]*ProxyPass([[:space:]]|$)' "$file" 2>/dev/null || true)
    done

    if [ -n "$LOCAL_WEB_URL" ]; then
        register_proxy_backend_target "$LOCAL_WEB_URL" "LOCAL_WEB_URL"
    fi
}

register_webroot() {
    local path="$1"
    local source="$2"
    local normalized
    local i

    [ -n "$path" ] || return 0
    [ -d "$path" ] || return 0
    normalized="$(normalize_path "$path")"

    for ((i=0; i<${#DETECTED_WEBROOTS[@]}; i++)); do
        if [ "${DETECTED_WEBROOTS[$i]}" = "$normalized" ]; then
            return 0
        fi
    done

    DETECTED_WEBROOTS+=("$normalized")
    DETECTED_WEBROOT_SOURCES+=("$source")
}

detect_webroots() {
    local file line path

    [ "${#DETECTED_WEBROOTS[@]}" -eq 0 ] || return 0

    for file in "$NGINX_SITES_ENABLED_DIR"/* "$NGINX_CONF_D_DIR"/*.conf; do
        [ -f "$file" ] || continue
        while IFS= read -r line; do
            path="$(printf '%s\n' "$line" | sed -E 's#^[[:space:]]*root[[:space:]]+([^;]+);.*#\1#')"
            [ -n "$path" ] && register_webroot "$path" "$file"
        done < <(grep -E '^[[:space:]]*root[[:space:]]+' "$file" 2>/dev/null || true)
    done

    for file in "$APACHE_SITES_ENABLED_DIR"/* "$APACHE_SITES_AVAILABLE_DIR"/*; do
        [ -f "$file" ] || continue
        while IFS= read -r line; do
            path="$(printf '%s\n' "$line" | sed -E 's#^[[:space:]]*DocumentRoot[[:space:]]+(.+)$#\1#')"
            path="${path%\"}"
            path="${path#\"}"
            [ -n "$path" ] && register_webroot "$path" "$file"
        done < <(grep -E '^[[:space:]]*DocumentRoot[[:space:]]+' "$file" 2>/dev/null || true)
    done

    if [ "${#DETECTED_WEBROOTS[@]}" -eq 0 ]; then
        [ -d /var/www/html ] && register_webroot "/var/www/html" "default"
    fi
}

print_webroot_summary() {
    local i

    detect_webroots
    [ "${#DETECTED_WEBROOTS[@]}" -gt 0 ] || return 0

    info "Erkannte Webroots:"
    for ((i=0; i<${#DETECTED_WEBROOTS[@]}; i++)); do
        printf -- '- %s [%s]\n' "${DETECTED_WEBROOTS[$i]}" "${DETECTED_WEBROOT_SOURCES[$i]}"
    done
}

path_is_under_webroot() {
    local file="$1"
    local normalized_file normalized_root
    local i

    detect_webroots
    normalized_file="$(normalize_path "$file")"
    for ((i=0; i<${#DETECTED_WEBROOTS[@]}; i++)); do
        normalized_root="${DETECTED_WEBROOTS[$i]}"
        case "$normalized_file" in
            "$normalized_root"/*|"$normalized_root")
                return 0
                ;;
        esac
    done
    return 1
}

webroot_for_path() {
    local file="$1"
    local normalized_file normalized_root
    local i

    detect_webroots
    normalized_file="$(normalize_path "$file")"
    for ((i=0; i<${#DETECTED_WEBROOTS[@]}; i++)); do
        normalized_root="${DETECTED_WEBROOTS[$i]}"
        case "$normalized_file" in
            "$normalized_root"/*|"$normalized_root")
                printf '%s' "$normalized_root"
                return 0
                ;;
        esac
    done
    return 1
}

webroot_relative_path() {
    local file="$1"
    local normalized_file normalized_root relative_path

    normalized_file="$(normalize_path "$file")"
    normalized_root="$(webroot_for_path "$file")" || return 1

    relative_path="${normalized_file#"$normalized_root"}"
    [ -n "$relative_path" ] || relative_path="/"
    case "$relative_path" in
        /*) printf '%s' "$relative_path" ;;
        *) printf '/%s' "$relative_path" ;;
    esac
}
proxy_backend_port_exists() {
    local port="$1"
    local i

    detect_proxy_backends
    for ((i=0; i<${#PROXY_BACKEND_PORTS[@]}; i++)); do
        [ "${PROXY_BACKEND_PORTS[$i]}" = "$port" ] && return 0
    done
    return 1
}

print_proxy_backend_summary() {
    local i

    detect_proxy_backends
    [ "${#PROXY_BACKEND_TARGETS[@]}" -gt 0 ] || return 0

    info "Erkannte Proxy-Backends:"
    for ((i=0; i<${#PROXY_BACKEND_TARGETS[@]}; i++)); do
        printf -- '- %s [%s]\n' "${PROXY_BACKEND_TARGETS[$i]}" "${PROXY_BACKEND_SOURCES[$i]}"
    done
}

print_active_listener_summary() {
    local i line

    detect_active_listeners
    if [ "${#ACTIVE_LISTENER_PROTOCOLS[@]}" -eq 0 ]; then
        info "Keine aktiven Listener erkannt."
        return
    fi

    info "Erkannte Listener:"
    for ((i=0; i<${#ACTIVE_LISTENER_PROTOCOLS[@]}; i++)); do
        line="${ACTIVE_LISTENER_PROTOCOLS[$i]} ${ACTIVE_LISTENER_BINDS[$i]} [${ACTIVE_LISTENER_EXPOSURES[$i]}]"
        if [ -n "${ACTIVE_LISTENER_PROCESSES[$i]}" ]; then
            line="$line ${ACTIVE_LISTENER_PROCESSES[$i]}"
        fi
        printf -- '- %s\n' "$line"
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

    awk -v directive="$directive" -v value="$value" -v escaped_directive="$escaped_directive" '
        BEGIN {
            changed=0
            pattern="^[[:space:]]*#?[[:space:]]*" escaped_directive "([[:space:]]+|$)"
        }
        $0 ~ pattern && changed == 0 {
            printf "%s %s\n", directive, value
            changed=1
            next
        }
        $0 ~ pattern {
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

    awk -v directive="$directive" -v value="$value" -v escaped_directive="$escaped_directive" '
        BEGIN {
            changed=0
            pattern="^[[:space:]]*;?[[:space:]]*" escaped_directive "[[:space:]]*="
        }
        $0 ~ pattern && changed == 0 {
            printf "%s = %s\n", directive, value
            changed=1
            next
        }
        $0 ~ pattern {
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
    print_key_value "DRY_RUN_MODE" "$(dry_run_label)"
    print_key_value "ERGEBNIS_SPRACHE" "$(result_view_label)"
}

run_full_audit() {
    local mode="${1:-interactive}"
    reset_results
    AUDIT_MODE_FULL_STATUS="ausgefuehrt"
    detect_services
    detect_active_listeners
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
    print_issue_summary
    print_fix_summary

    if [ "$mode" = "interactive" ] && [ "${#FIX_IDS[@]}" -gt 0 ]; then
        if ask_yes_no "Fix-Assistent jetzt oeffnen?"; then
            run_fix_assistant
        fi
    fi
}

ensure_fix_context() {
    if [ "${#FIX_IDS[@]}" -eq 0 ] && [ "${#ISSUE_IDS[@]}" -eq 0 ]; then
        run_full_audit "silent"
    fi
}

run_beginner_mode() {
    local safe_fix_count

    section "Einsteiger-Modus"
    info "Dieser Ablauf fuehrt dich sicher durch Pruefung, Vorschau und einfache Fixes."
    info "Empfohlen fuer normale Webserver, Mailserver und Docker-Hosts."

    if ! dry_run_enabled; then
        if ask_yes_no "Vorschau-Modus aktivieren, damit zuerst nichts veraendert wird?"; then
            DRY_RUN_MODE="1"
            warn "Vorschau-Modus wurde aktiviert."
        fi
    fi

    if ! ask_yes_no "Server jetzt automatisch pruefen?"; then
        info "Einsteiger-Modus abgebrochen."
        return
    fi

    run_full_audit "silent"
    print_beginner_summary

    if [ "${#FIX_IDS[@]}" -eq 0 ]; then
        info "Es gibt aktuell keine vorbereiteten Fixes."
        return
    fi

    safe_fix_count="$(count_fixes_by_category "AUTO-SAFE")"
    if [ "$safe_fix_count" -gt 0 ]; then
        if ask_yes_no "Empfohlene sichere Fixes jetzt direkt Schritt fuer Schritt starten?"; then
            run_fix_subset_by_category "AUTO-SAFE"
            return
        fi
    fi

    if ask_yes_no "Einfachen Fix-Assistenten jetzt oeffnen?"; then
        run_beginner_fix_assistant
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
        if dry_run_enabled; then
            warn "Dry-Run-Modus aktiv: Fixes zeigen nur geplante Aenderungen und fuehren nichts aus."
        fi
        info "Neu hier? Starte am besten mit 20) Einsteiger-Modus."
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
19) Dry-Run-Modus umschalten
    zeigt nur eine sichere Vorschau und aendert nichts
20) Einsteiger-Modus (einfach gefuehrt)
    empfohlen fuer neue Nutzer mit einfacher Sprache und Schritt-fuer-Schritt-Hilfe
21) Ergebnis-Sprache umschalten
    wechselt zwischen einfacher Erklaerung und technischer Ansicht
22) Aktive Sicherheitspruefung (safe)
    sendet nur kontrollierte Lese-Requests an die konfigurierte PUBLIC_WEB_URL
23) Lab-Validierungsmodus (nur lokal)
    erweitert die Web-Probes fuer localhost, aber weiterhin ohne destruktive Angriffe
0) Beenden
EOF
        printf '\nAuswahl: '
        read -r choice

        case "$choice" in
            1) run_full_audit "interactive"; pause ;;
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
            19) toggle_dry_run_mode; pause ;;
            20) run_beginner_mode; pause ;;
            21) toggle_result_view_mode; pause ;;
            22) reset_results; detect_services; run_active_security_checks; recalculate_score; print_status_box; print_issue_summary; pause ;;
            23) reset_results; detect_services; run_lab_validation_checks; recalculate_score; print_status_box; print_issue_summary; pause ;;
            0) break ;;
            *) warn "Ungueltige Auswahl." ;;
        esac
    done
}
