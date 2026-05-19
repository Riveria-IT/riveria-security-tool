#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$BASE_DIR/.riveria-runtime/test-fixtures-webroot"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/public" "$TMP_DIR/app/config"
touch "$TMP_DIR/public/.env" "$TMP_DIR/public/phpinfo.php" "$TMP_DIR/app/config/settings.php"
mkdir -p "$TMP_DIR/public/vendor"
chmod 644 "$TMP_DIR/public/.env"

source "$BASE_DIR/lib/core.sh"
source "$BASE_DIR/lib/ui.sh"
source "$BASE_DIR/lib/report.sh"
source "$BASE_DIR/lib/scoring.sh"
source "$BASE_DIR/checks/exposure.sh"

load_config "$BASE_DIR"
reset_results

DETECTED_WEBROOTS=("$TMP_DIR/public")
DETECTED_WEBROOT_SOURCES=("fixture")
PUBLIC_WEB_URL="https://example.com/app"

exposure_http_probe() {
    case "$2" in
        "/.env"|"/vendor")
            printf '403'
            ;;
        "/phpinfo.php")
            printf '200'
            ;;
        *)
            printf '404'
            ;;
    esac
}

path_is_under_webroot "$TMP_DIR/public/.env"
! path_is_under_webroot "$TMP_DIR/app/config/settings.php"
test "$(webroot_relative_path "$TMP_DIR/public/phpinfo.php")" = "/phpinfo.php"

scan_roots=("$TMP_DIR")
env_hits="$(find "${scan_roots[@]}" -maxdepth 4 \( -name '.env' -o -name '.env.local' -o -name '.env.production' -o -name '.env.backup' \) 2>/dev/null | head -n 20 || true)"
printf '%s\n' "$env_hits" | grep -q "$TMP_DIR/public/.env"

markers="$(find "${scan_roots[@]}" -maxdepth 4 \( -type f \( -name 'phpinfo.php' -o -name 'info.php' -o -name 'test.php' -o -name 'debug.php' -o -name 'adminer.php' -o -name 'composer.json' -o -name 'composer.lock' -o -name 'config.inc.php' -o -name 'database.php' -o -name 'settings.php' \) -o -type d \( -name '.git' -o -name 'phpmyadmin' -o -name 'vendor' -o -name 'storage' -o -name 'logs' -o -name 'config' -o -name 'database' \) \) 2>/dev/null | head -n 20 || true)"
printf '%s\n' "$markers" | grep -q "$TMP_DIR/public/phpinfo.php"
printf '%s\n' "$markers" | grep -q "$TMP_DIR/app/config/settings.php"

reset_results
DETECTED_WEBROOTS=("$TMP_DIR/public")
DETECTED_WEBROOT_SOURCES=("fixture")
run_webroot_direct_exposure_checks "https://example.com"
printf '%s\n' "${ISSUE_IDS[@]-}" | grep -qx 'EXP-010'
printf '%s\n' "${ISSUE_IDS[@]-}" | grep -qx 'EXP-011'

printf 'Integration-Webroot-Test erfolgreich.\n'
