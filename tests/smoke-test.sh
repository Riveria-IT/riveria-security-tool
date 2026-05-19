#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE_DIR"

printf '[1/16] Bash-Syntax pruefen...\n'
bash -n \
    riveria-security-tool.sh \
    lib/core.sh lib/ui.sh lib/detection.sh lib/report.sh lib/scoring.sh \
    checks/system.sh checks/services.sh checks/apps.sh checks/code_security.sh checks/permissions.sh checks/exposure.sh checks/active_tests.sh checks/docker.sh checks/mail.sh checks/ssl_dns.sh \
    fixes/fixes.sh fixes/ssh.sh fixes/ufw.sh fixes/fail2ban.sh fixes/php.sh fixes/nginx.sh fixes/apache.sh fixes/permissions.sh fixes/quarantine.sh \
    tests/integration-cli-snapshots.sh tests/integration-fix-handlers.sh tests/integration-core-directives.sh tests/integration-dry-run.sh tests/integration-beginner-mode.sh tests/integration-result-view.sh tests/integration-active-tests.sh tests/integration-lab-validation.sh

printf '[2/16] Menue-Start pruefen...\n'
menu_output="$(bash ./riveria-security-tool.sh 2>&1 || true)"
printf '%s' "$menu_output" | grep -q 'Bitte mit sudo oder als root ausfuehren'

printf '[3/16] Demo-Reports erzeugen...\n'
bash ./tests/generate-demo-report.sh >/dev/null

printf '[4/16] Report-Dateien pruefen...\n'
latest_txt="$(find ./.riveria-runtime/reports -type f -name 'report_*.txt' | sort | tail -n 1)"
latest_json="$(find ./.riveria-runtime/reports -type f -name 'report_*.json' | sort | tail -n 1)"
latest_html="$(find ./.riveria-runtime/reports -type f -name 'report_*.html' | sort | tail -n 1)"

[ -n "${latest_txt:-}" ] && [ -f "$latest_txt" ]
[ -n "${latest_json:-}" ] && [ -f "$latest_json" ]
[ -n "${latest_html:-}" ] && [ -f "$latest_html" ]

printf '[5/16] Webroot-Integration pruefen...\n'
bash ./tests/integration-webroot-checks.sh >/dev/null

printf '[6/16] Proxy-Docker-Integration pruefen...\n'
bash ./tests/integration-proxy-docker.sh >/dev/null

printf '[7/16] Profil-Fixtures pruefen...\n'
bash ./tests/integration-profile-fixtures.sh >/dev/null

printf '[8/16] Report-Snapshots pruefen...\n'
bash ./tests/integration-report-snapshots.sh >/dev/null

printf '[9/16] CLI-Snapshots pruefen...\n'
bash ./tests/integration-cli-snapshots.sh >/dev/null

printf '[10/16] Fix-Handler pruefen...\n'
bash ./tests/integration-fix-handlers.sh >/dev/null

printf '[11/16] Core-Directive-Parser pruefen...\n'
bash ./tests/integration-core-directives.sh >/dev/null

printf '[12/16] Dry-Run-Modus pruefen...\n'
bash ./tests/integration-dry-run.sh >/dev/null

printf '[13/16] Einsteiger-Modus pruefen...\n'
bash ./tests/integration-beginner-mode.sh >/dev/null

printf '[14/16] Ergebnis-Sprache pruefen...\n'
bash ./tests/integration-result-view.sh >/dev/null

printf '[15/16] Aktive Sicherheitspruefung pruefen...\n'
bash ./tests/integration-active-tests.sh >/dev/null

printf '[16/16] Lokalen Lab-Modus pruefen...\n'
bash ./tests/integration-lab-validation.sh >/dev/null

printf 'Smoke-Test erfolgreich.\n'
