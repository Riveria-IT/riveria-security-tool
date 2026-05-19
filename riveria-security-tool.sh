#!/usr/bin/env bash
set -u

SCRIPT_PATH="${BASH_SOURCE[0]}"

while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    case "$SCRIPT_PATH" in
        /*) ;;
        *) SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH" ;;
    esac
done

BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

source "$BASE_DIR/lib/core.sh"
source "$BASE_DIR/lib/ui.sh"
source "$BASE_DIR/lib/detection.sh"
source "$BASE_DIR/lib/report.sh"
source "$BASE_DIR/lib/scoring.sh"

source "$BASE_DIR/checks/system.sh"
source "$BASE_DIR/checks/services.sh"
source "$BASE_DIR/checks/apps.sh"
source "$BASE_DIR/checks/code_security.sh"
source "$BASE_DIR/checks/permissions.sh"
source "$BASE_DIR/checks/exposure.sh"
source "$BASE_DIR/checks/active_tests.sh"
source "$BASE_DIR/checks/docker.sh"
source "$BASE_DIR/checks/mail.sh"
source "$BASE_DIR/checks/ssl_dns.sh"

source "$BASE_DIR/fixes/fixes.sh"
source "$BASE_DIR/fixes/ssh.sh"
source "$BASE_DIR/fixes/ufw.sh"
source "$BASE_DIR/fixes/fail2ban.sh"
source "$BASE_DIR/fixes/php.sh"
source "$BASE_DIR/fixes/nginx.sh"
source "$BASE_DIR/fixes/apache.sh"
source "$BASE_DIR/fixes/permissions.sh"
source "$BASE_DIR/fixes/quarantine.sh"

main_menu "$@"
