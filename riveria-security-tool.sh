#!/usr/bin/env bash
set -u

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
