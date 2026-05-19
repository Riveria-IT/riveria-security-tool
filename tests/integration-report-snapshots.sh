#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$BASE_DIR/tests/fixtures"
SNAPSHOT_DIR="$FIXTURE_DIR/report-snapshots"
TMP_DIR="$BASE_DIR/.riveria-runtime/test-report-snapshots"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR"

source "$BASE_DIR/lib/core.sh"
source "$BASE_DIR/lib/ui.sh"
source "$BASE_DIR/lib/report.sh"
source "$BASE_DIR/lib/scoring.sh"
source "$BASE_DIR/checks/services.sh"
source "$BASE_DIR/checks/docker.sh"

load_config "$BASE_DIR"

cmd_exists() {
    case "$1" in
        ufw) return 0 ;;
        fail2ban-client) return 1 ;;
        docker|docker-compose) return 0 ;;
        ss) return 1 ;;
        *)
            command -v "$1" >/dev/null 2>&1
            ;;
    esac
}

ufw() {
    if [ "${1:-}" = "status" ]; then
        printf 'Status: inactive\n'
        return 0
    fi
    return 0
}

normalize_txt_report() {
    local file="$1"
    sed -E 's#(TXT:|JSON:|HTML:)[[:space:]]+/.*test-report-snapshots/[^ ]+/report_[^ ]+#\1 __REPORT_PATH__#g' "$file"
}

normalize_html_report() {
    local html_file="$1"
    tr '\n' ' ' <"$html_file" | sed -E \
        -e 's/Version 1\.0\.0-alpha · Report [^·]+ · [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8} [A-Z]+ · [^<]+/Version 1.0.0-alpha · Report __REPORT_ID__ · __REPORT_DATE__ · __REPORT_SERVER__/g' \
        -e 's#<div class="mono">.*</div></section>#<div class="mono">__EMBEDDED_TXT__</div></section>#g'
    printf '\n'
}

assert_file_matches() {
    local actual="$1"
    local expected="$2"
    cmp -s "$actual" "$expected"
}

generate_reverse_proxy_snapshot() {
    local scenario_dir="$TMP_DIR/reverse-proxy"
    local webroot="$scenario_dir/public"
    local nginx_dir="$scenario_dir/nginx/sites-enabled"
    local apache_dir="$scenario_dir/apache/sites-enabled"
    local txt_file json_file html_file normalized_txt normalized_html

    reset_results
    mkdir -p "$webroot" "$nginx_dir" "$scenario_dir/nginx/conf.d" "$apache_dir" "$scenario_dir/apache/sites-available" "$scenario_dir/reports"
    sed "s#__WEBROOT__#$webroot#g" \
        "$FIXTURE_DIR/reverse-proxy/nginx/sites-enabled/reverse-proxy.conf" \
        > "$nginx_dir/reverse-proxy.conf"
    sed "s#__WEBROOT__#$webroot#g" \
        "$FIXTURE_DIR/reverse-proxy/apache/sites-enabled/app.conf" \
        > "$apache_dir/app.conf"

    NGINX_SITES_ENABLED_DIR="$nginx_dir"
    NGINX_CONF_D_DIR="$scenario_dir/nginx/conf.d"
    APACHE_SITES_ENABLED_DIR="$apache_dir"
    APACHE_SITES_AVAILABLE_DIR="$scenario_dir/apache/sites-available"
    REPORT_DIR="$scenario_dir/reports"
    LOCAL_WEB_URL="http://127.0.0.1:8088/login"
    WEB_PORT="8088"
    REPORT_RUN_ID="SNAPSHOT-REVERSE-PROXY"
    REPORT_RUN_DATE_HUMAN="2026-01-01 12:00:00 UTC"
    REPORT_RUN_DATE_ISO="2026-01-01T12:00:00+0000"
    REPORT_RUN_SERVER="snapshot-host"

    register_detected_component "nginx"
    register_detected_component "apache"
    register_detected_profile "Webserver"
    register_detected_profile "Reverse Proxy"
    register_active_listener "tcp" "0.0.0.0:8088" "users:((\"docker-proxy\",pid=1,fd=1))"
    register_active_listener "tcp" "127.0.0.1:8088" "users:((\"node\",pid=2,fd=1))"
    register_active_listener "tcp" "127.0.0.1:9090" "users:((\"apache2\",pid=3,fd=1))"

    run_service_checks >/dev/null
    recalculate_score

    txt_file="$(generate_txt_report)"
    json_file="$(generate_json_report)"
    html_file="$(generate_html_report)"
    normalized_txt="$scenario_dir/reverse-proxy.normalized.txt"
    normalized_html="$scenario_dir/reverse-proxy.normalized.html"
    normalize_txt_report "$txt_file" >"$normalized_txt"
    normalize_html_report "$html_file" >"$normalized_html"

    assert_file_matches "$normalized_txt" "$SNAPSHOT_DIR/reverse-proxy.txt"
    assert_file_matches "$json_file" "$SNAPSHOT_DIR/reverse-proxy.json"
    assert_file_matches "$normalized_html" "$SNAPSHOT_DIR/reverse-proxy.html"
}

generate_docker_snapshot() {
    local scenario_dir="$TMP_DIR/docker-unexpected"
    local json_file

    reset_results
    mkdir -p "$scenario_dir/reports"
    REPORT_DIR="$scenario_dir/reports"
    DOCKER_INFO_OK="1"
    DOCKER_PS_OUTPUT="$(cat "$FIXTURE_DIR/docker-host/docker-ps-unexpected.txt")"
    WEB_PORT="8088"
    REPORT_RUN_ID="SNAPSHOT-DOCKER-UNEXPECTED"
    REPORT_RUN_DATE_HUMAN="2026-01-01 12:05:00 UTC"
    REPORT_RUN_DATE_ISO="2026-01-01T12:05:00+0000"
    REPORT_RUN_SERVER="snapshot-host"

    run_docker_checks >/dev/null
    recalculate_score
    json_file="$(generate_json_report)"
    assert_file_matches "$json_file" "$SNAPSHOT_DIR/docker-unexpected.json"
}

generate_webserver_snapshot() {
    local scenario_dir="$TMP_DIR/webserver"
    local webroot="$scenario_dir/public"
    local nginx_dir="$scenario_dir/nginx/sites-enabled"
    local json_file

    reset_results
    mkdir -p "$webroot" "$nginx_dir" "$scenario_dir/nginx/conf.d" "$scenario_dir/apache/sites-enabled" "$scenario_dir/apache/sites-available" "$scenario_dir/reports"
    sed "s#__WEBROOT__#$webroot#g" \
        "$FIXTURE_DIR/webserver/nginx/sites-enabled/web.conf" \
        > "$nginx_dir/web.conf"

    NGINX_SITES_ENABLED_DIR="$nginx_dir"
    NGINX_CONF_D_DIR="$scenario_dir/nginx/conf.d"
    APACHE_SITES_ENABLED_DIR="$scenario_dir/apache/sites-enabled"
    APACHE_SITES_AVAILABLE_DIR="$scenario_dir/apache/sites-available"
    REPORT_DIR="$scenario_dir/reports"
    LOCAL_WEB_URL=""
    WEB_PORT="443"
    REPORT_RUN_ID="SNAPSHOT-WEBSERVER"
    REPORT_RUN_DATE_HUMAN="2026-01-01 12:10:00 UTC"
    REPORT_RUN_DATE_ISO="2026-01-01T12:10:00+0000"
    REPORT_RUN_SERVER="snapshot-host"

    register_detected_component "nginx"
    register_detected_profile "Webserver"

    run_service_checks >/dev/null
    recalculate_score
    json_file="$(generate_json_report)"
    assert_file_matches "$json_file" "$SNAPSHOT_DIR/webserver.json"
}

generate_apache_only_snapshot() {
    local scenario_dir="$TMP_DIR/apache-only"
    local webroot="$scenario_dir/public"
    local apache_dir="$scenario_dir/apache/sites-enabled"
    local json_file

    reset_results
    mkdir -p "$webroot" "$scenario_dir/nginx/sites-enabled" "$scenario_dir/nginx/conf.d" "$apache_dir" "$scenario_dir/apache/sites-available" "$scenario_dir/reports"
    sed "s#__WEBROOT__#$webroot#g" \
        "$FIXTURE_DIR/apache-only/apache/sites-enabled/site.conf" \
        > "$apache_dir/site.conf"

    NGINX_SITES_ENABLED_DIR="$scenario_dir/nginx/sites-enabled"
    NGINX_CONF_D_DIR="$scenario_dir/nginx/conf.d"
    APACHE_SITES_ENABLED_DIR="$apache_dir"
    APACHE_SITES_AVAILABLE_DIR="$scenario_dir/apache/sites-available"
    REPORT_DIR="$scenario_dir/reports"
    LOCAL_WEB_URL=""
    WEB_PORT="443"
    REPORT_RUN_ID="SNAPSHOT-APACHE-ONLY"
    REPORT_RUN_DATE_HUMAN="2026-01-01 12:15:00 UTC"
    REPORT_RUN_DATE_ISO="2026-01-01T12:15:00+0000"
    REPORT_RUN_SERVER="snapshot-host"

    register_detected_component "apache"
    register_detected_profile "Webserver"

    run_service_checks >/dev/null
    recalculate_score
    json_file="$(generate_json_report)"
    assert_file_matches "$json_file" "$SNAPSHOT_DIR/apache-only.json"
}

generate_reverse_proxy_broken_snapshot() {
    local scenario_dir="$TMP_DIR/reverse-proxy-broken"
    local webroot="$scenario_dir/public"
    local nginx_dir="$scenario_dir/nginx/sites-enabled"
    local apache_dir="$scenario_dir/apache/sites-enabled"
    local txt_file json_file html_file normalized_html

    reset_results
    mkdir -p "$webroot" "$nginx_dir" "$scenario_dir/nginx/conf.d" "$apache_dir" "$scenario_dir/apache/sites-available" "$scenario_dir/reports"
    sed "s#__WEBROOT__#$webroot#g" \
        "$FIXTURE_DIR/reverse-proxy/nginx/sites-enabled/reverse-proxy.conf" \
        > "$nginx_dir/reverse-proxy.conf"
    sed "s#__WEBROOT__#$webroot#g" \
        "$FIXTURE_DIR/reverse-proxy/apache/sites-enabled/app.conf" \
        > "$apache_dir/app.conf"

    NGINX_SITES_ENABLED_DIR="$nginx_dir"
    NGINX_CONF_D_DIR="$scenario_dir/nginx/conf.d"
    APACHE_SITES_ENABLED_DIR="$apache_dir"
    APACHE_SITES_AVAILABLE_DIR="$scenario_dir/apache/sites-available"
    REPORT_DIR="$scenario_dir/reports"
    LOCAL_WEB_URL="http://127.0.0.1:9090/login"
    WEB_PORT="8088"
    REPORT_RUN_ID="SNAPSHOT-REVERSE-PROXY-BROKEN"
    REPORT_RUN_DATE_HUMAN="2026-01-01 12:20:00 UTC"
    REPORT_RUN_DATE_ISO="2026-01-01T12:20:00+0000"
    REPORT_RUN_SERVER="snapshot-host"

    register_detected_component "nginx"
    register_detected_component "apache"
    register_detected_profile "Webserver"
    register_detected_profile "Reverse Proxy"
    register_active_listener "tcp" "0.0.0.0:8088" "users:((\"docker-proxy\",pid=1,fd=1))"

    run_service_checks >/dev/null
    recalculate_score
    txt_file="$(generate_txt_report)"
    json_file="$(generate_json_report)"
    html_file="$(generate_html_report)"
    normalized_html="$scenario_dir/reverse-proxy-broken.normalized.html"
    normalize_html_report "$html_file" >"$normalized_html"
    assert_file_matches "$json_file" "$SNAPSHOT_DIR/reverse-proxy-broken.json"
    assert_file_matches "$normalized_html" "$SNAPSHOT_DIR/reverse-proxy-broken.html"
}

generate_reverse_proxy_snapshot
generate_docker_snapshot
generate_webserver_snapshot
generate_apache_only_snapshot
generate_reverse_proxy_broken_snapshot

printf 'Integration-Report-Snapshots-Test erfolgreich.\n'
