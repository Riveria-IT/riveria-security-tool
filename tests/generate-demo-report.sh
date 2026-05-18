#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$BASE_DIR/lib/core.sh"
source "$BASE_DIR/lib/ui.sh"
source "$BASE_DIR/lib/report.sh"
source "$BASE_DIR/lib/scoring.sh"

load_config "$BASE_DIR"
reset_results

register_detected_profile "Webserver"
register_detected_profile "Reverse Proxy"
register_detected_component "nginx"
register_detected_component "php-fpm"
register_issue "DEMO-001" "Demo-Warnung" "WARNUNG" \
    "Dies ist ein kuenstlicher Testfund fuer die Report-Generierung." \
    "Nur als Smoke-Test verwenden." "AUTO-SAFE" "yes"
register_issue "DEMO-002" "Demo-Kritisch" "KRITISCH" \
    "Dies ist ein kuenstlicher kritischer Testfund fuer die HTML- und JSON-Ausgabe." \
    "Nur als Smoke-Test verwenden." "GUIDED" "no"
register_fix "FIX-DEMO-001" "Demo-Fix" \
    "Kuenstlicher Testfix fuer Reporting und Assistent" "AUTO-SAFE" "/tmp/demo.backup" \
    "echo demo" "true" "none" "demo-recheck" "" "KRITISCH"

recalculate_score
generate_txt_report >/dev/null
generate_json_report >/dev/null
generate_html_report >/dev/null
