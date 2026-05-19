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
    local url="${*: -1}"
    local arg

    for arg in "$@"; do
        case "$arg" in
            TRACE|GET|POST|HEAD|OPTIONS)
                method="$arg"
                ;;
        esac
    done

    case "${method}:${url}" in
        GET:http://127.0.0.1/debug)
            printf '200'
            ;;
        GET:http://127.0.0.1/swagger/)
            printf '302'
            ;;
        GET:http://127.0.0.1/openapi.json)
            printf '404'
            ;;
        GET:http://127.0.0.1/actuator/)
            printf '404'
            ;;
        OPTIONS:http://127.0.0.1/app)
            printf '200'
            ;;
        HEAD:http://127.0.0.1/app)
            printf '200'
            ;;
        GET:http://127.0.0.1/this-should-not-exist-riveria)
            printf '404'
            ;;
        GET:http://127.0.0.1/.git/this-should-not-exist)
            printf '404'
            ;;
        GET:http://127.0.0.1/broken%2f..%2f..%2fetc/passwd)
            printf '500'
            ;;
        *)
            printf '404'
            ;;
    esac
}

reset_results
PUBLIC_WEB_URL="http://127.0.0.1/app"
LAB_VALIDATION_AUTO_CONFIRM="1"

run_lab_validation_checks
recalculate_score

REPORT_DIR="$BASE_DIR/.riveria-runtime/reports"
txt_report="$(generate_txt_report)"
json_report="$(generate_json_report)"

printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-010'
printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-011'
printf '%s\n' "${ISSUE_IDS[@]}" | grep -qx 'ACT-012'
[ "$WARN_COUNT" -ge 3 ]
grep -q '^- Vollaudit: nicht getestet$' "$txt_report"
grep -q '^- Aktive Sicherheitspruefung (safe): nicht getestet$' "$txt_report"
grep -q '^- Lab-Validierungsmodus (lokal): ausgefuehrt$' "$txt_report"
grep -q '"test_modes": {"full_audit":"nicht getestet","active_safe":"nicht getestet","lab_local":"ausgefuehrt"}' "$json_report"

printf 'Integration-Lab-Validation-Test erfolgreich.\n'
