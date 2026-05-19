#!/usr/bin/env bash
set -u

fail_startup() {
    printf 'Fehler beim Start von Riveria: %s\n' "$1" >&2
    printf 'Erwarteter Projektordner: %s\n' "$BASE_DIR" >&2
    printf 'Bitte das Tool neu installieren und danach erneut starten.\n' >&2
    exit 1
}

require_file() {
    if [ ! -f "$1" ]; then
        fail_startup "Datei fehlt: $1"
    fi
}

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

require_file "$BASE_DIR/lib/core.sh"
require_file "$BASE_DIR/lib/ui.sh"
require_file "$BASE_DIR/lib/detection.sh"
require_file "$BASE_DIR/lib/report.sh"
require_file "$BASE_DIR/lib/scoring.sh"
require_file "$BASE_DIR/checks/system.sh"
require_file "$BASE_DIR/checks/services.sh"
require_file "$BASE_DIR/checks/apps.sh"
require_file "$BASE_DIR/checks/code_security.sh"
require_file "$BASE_DIR/checks/permissions.sh"
require_file "$BASE_DIR/checks/exposure.sh"
require_file "$BASE_DIR/checks/active_tests.sh"
require_file "$BASE_DIR/checks/docker.sh"
require_file "$BASE_DIR/checks/mail.sh"
require_file "$BASE_DIR/checks/ssl_dns.sh"
require_file "$BASE_DIR/fixes/fixes.sh"
require_file "$BASE_DIR/fixes/ssh.sh"
require_file "$BASE_DIR/fixes/ufw.sh"
require_file "$BASE_DIR/fixes/fail2ban.sh"
require_file "$BASE_DIR/fixes/php.sh"
require_file "$BASE_DIR/fixes/nginx.sh"
require_file "$BASE_DIR/fixes/apache.sh"
require_file "$BASE_DIR/fixes/permissions.sh"
require_file "$BASE_DIR/fixes/quarantine.sh"

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
