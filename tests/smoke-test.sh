#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE_DIR"

printf '[1/4] Bash-Syntax pruefen...\n'
bash -n \
    riveria-security-tool.sh \
    lib/core.sh lib/ui.sh lib/detection.sh lib/report.sh lib/scoring.sh \
    checks/system.sh checks/services.sh checks/apps.sh checks/code_security.sh checks/permissions.sh checks/exposure.sh checks/docker.sh checks/mail.sh checks/ssl_dns.sh \
    fixes/fixes.sh fixes/ssh.sh fixes/ufw.sh fixes/fail2ban.sh fixes/php.sh fixes/nginx.sh fixes/apache.sh fixes/permissions.sh fixes/quarantine.sh

printf '[2/4] Menue-Start pruefen...\n'
menu_output="$(bash ./riveria-security-tool.sh 2>&1 || true)"
printf '%s' "$menu_output" | grep -q 'Bitte mit sudo oder als root ausfuehren'

printf '[3/4] Demo-Reports erzeugen...\n'
bash ./tests/generate-demo-report.sh >/dev/null

printf '[4/4] Report-Dateien pruefen...\n'
latest_txt="$(find ./.riveria-runtime/reports -type f -name 'report_*.txt' | sort | tail -n 1)"
latest_json="$(find ./.riveria-runtime/reports -type f -name 'report_*.json' | sort | tail -n 1)"
latest_html="$(find ./.riveria-runtime/reports -type f -name 'report_*.html' | sort | tail -n 1)"

[ -n "${latest_txt:-}" ] && [ -f "$latest_txt" ]
[ -n "${latest_json:-}" ] && [ -f "$latest_json" ]
[ -n "${latest_html:-}" ] && [ -f "$latest_html" ]

printf 'Smoke-Test erfolgreich.\n'
