#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE_DIR"

source "./lib/core.sh"
source "./lib/ui.sh"
source "./lib/report.sh"
source "./lib/scoring.sh"
source "./checks/active_tests.sh"

curl() {
    local method="GET"
    local headers_only=0
    local url="${*: -1}"
    local arg

    for arg in "$@"; do
        case "$arg" in
            -I)
                headers_only=1
                ;;
            TRACE|GET|POST|HEAD|OPTIONS)
                method="$arg"
                ;;
        esac
    done

    if [ "$headers_only" -eq 1 ]; then
        cat <<'EOF'
HTTP/1.1 200 OK
Server: nginx/1.24.0
X-Powered-By: PHP/8.2.0
Via: 1.1 reverse-proxy
Set-Cookie: session=abc123; Path=/
EOF
        return 0
    fi

    case "${method}:${url}" in
        TRACE:https://example.com/app)
            printf '200'
            ;;
        GET:https://example.com/login\?riveria-rate-test=1|GET:https://example.com/login\?riveria-rate-test=2|GET:https://example.com/login\?riveria-rate-test=3)
            printf '200'
            ;;
        GET:https://example.com/server-status)
            printf '200'
            ;;
        GET:https://example.com/server-info)
            printf '403'
            ;;
        GET:https://example.com/login)
            printf '200'
            ;;
        GET:https://example.com/admin)
            printf '302'
            ;;
        GET:https://example.com/admin/login)
            printf '404'
            ;;
        GET:https://example.com/wp-login.php)
            printf '404'
            ;;
        GET:https://example.com/wp-admin/)
            printf '404'
            ;;
        GET:https://example.com/phpmyadmin/)
            printf '403'
            ;;
        GET:https://example.com/adminer.php)
            printf '404'
            ;;
        GET:https://example.com/upload)
            printf '405'
            ;;
        GET:https://example.com/uploads/)
            printf '404'
            ;;
        GET:https://example.com/api/upload)
            printf '401'
            ;;
        GET:https://example.com/file-upload)
            printf '404'
            ;;
        GET:https://example.com/media/upload)
            printf '404'
            ;;
        GET:https://example.com/.git/HEAD)
            printf '404'
            ;;
        GET:https://example.com/.env.bak)
            printf '404'
            ;;
        GET:https://example.com/backup.zip)
            printf '404'
            ;;
        GET:https://example.com/dump.sql)
            printf '404'
            ;;
        GET:https://example.com/actuator/env)
            printf '404'
            ;;
        GET:https://example.com/actuator/heapdump)
            printf '404'
            ;;
        GET:https://example.com/..%2f..%2fetc/passwd)
            printf '200'
            ;;
        GET:https://example.com/%2e%2e/%2e%2e/etc/passwd)
            printf '404'
            ;;
        GET:https://example.com/static/..%2f..%2fetc/passwd)
            printf '403'
            ;;
        *)
            printf '404'
            ;;
    esac
}

reset_results
PUBLIC_WEB_URL="https://example.com/app"

run_active_security_checks
recalculate_score

REPORT_DIR="$BASE_DIR/.riveria-runtime/reports"
txt_report="$(generate_txt_report)"
json_report="$(generate_json_report)"

printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-001'
printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-002'
printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-003'
printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-004'
printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-005'
printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-006'
printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-007'
printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-008'
printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-009'
[ "$CRIT_COUNT" -ge 1 ]
[ "$WARN_COUNT" -ge 8 ]
grep -q '^Pruefarten:$' "$txt_report"
grep -q '^- Vollaudit: nicht getestet$' "$txt_report"
grep -q '^- Aktive Sicherheitspruefung (safe): ausgefuehrt$' "$txt_report"
grep -q '^- Lab-Validierungsmodus (lokal): nicht getestet$' "$txt_report"
grep -q '^Aktive Tests:$' "$txt_report"
grep -q '"active_tests": \[' "$json_report"
grep -q '"id":"ACT-009"' "$json_report"
grep -q '"test_modes": {"full_audit":"nicht getestet","active_safe":"ausgefuehrt","lab_local":"nicht getestet"}' "$json_report"

printf 'Integration-Active-Tests erfolgreich.\n'
