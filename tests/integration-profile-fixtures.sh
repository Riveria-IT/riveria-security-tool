#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$BASE_DIR/tests/fixtures"
TMP_DIR="$BASE_DIR/.riveria-runtime/test-fixtures-profiles"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

source "$BASE_DIR/lib/core.sh"
source "$BASE_DIR/lib/ui.sh"
source "$BASE_DIR/lib/report.sh"
source "$BASE_DIR/lib/scoring.sh"
source "$BASE_DIR/lib/detection.sh"
source "$BASE_DIR/checks/services.sh"
source "$BASE_DIR/checks/docker.sh"

load_config "$BASE_DIR"

assert_has_profile() {
    local expected="$1"
    printf '%s\n' "${DETECTED_PROFILES[@]}" | grep -qx "$expected"
}

assert_no_profile() {
    local unexpected="$1"
    ! printf '%s\n' "${DETECTED_PROFILES[@]}" | grep -qx "$unexpected"
}

assert_has_issue() {
    local expected="$1"
    printf '%s\n' "${ISSUE_IDS[@]-}" | grep -qx "$expected"
}

assert_no_issue() {
    local unexpected="$1"
    ! printf '%s\n' "${ISSUE_IDS[@]-}" | grep -qx "$unexpected"
}

run_reverse_proxy_fixture() {
    reset_results
    local webroot="$TMP_DIR/reverse-proxy/public"
    local nginx_dir="$TMP_DIR/reverse-proxy/nginx/sites-enabled"
    local apache_dir="$TMP_DIR/reverse-proxy/apache/sites-enabled"
    mkdir -p "$webroot" "$nginx_dir" "$TMP_DIR/reverse-proxy/nginx/conf.d" "$apache_dir" "$TMP_DIR/reverse-proxy/apache/sites-available"
    sed "s#__WEBROOT__#$webroot#g" \
        "$FIXTURE_DIR/reverse-proxy/nginx/sites-enabled/reverse-proxy.conf" \
        > "$nginx_dir/reverse-proxy.conf"
    sed "s#__WEBROOT__#$webroot#g" \
        "$FIXTURE_DIR/reverse-proxy/apache/sites-enabled/app.conf" \
        > "$apache_dir/app.conf"

    NGINX_SITES_ENABLED_DIR="$nginx_dir"
    NGINX_CONF_D_DIR="$TMP_DIR/reverse-proxy/nginx/conf.d"
    APACHE_SITES_ENABLED_DIR="$apache_dir"
    APACHE_SITES_AVAILABLE_DIR="$TMP_DIR/reverse-proxy/apache/sites-available"
    LOCAL_WEB_URL="http://127.0.0.1:8088/login"
    WEB_PORT="8088"

    register_detected_component "nginx"
    register_detected_component "apache"
    register_detected_profile "Webserver"
    register_active_listener "tcp" "0.0.0.0:8088" "users:((\"docker-proxy\",pid=1,fd=1))"
    register_active_listener "tcp" "127.0.0.1:8088" "users:((\"node\",pid=2,fd=1))"
    register_active_listener "tcp" "127.0.0.1:9090" "users:((\"apache2\",pid=3,fd=1))"

    detect_proxy_backends
    detect_webroots
    detect_profiles

    assert_has_profile "Reverse Proxy"
    printf '%s\n' "${PROXY_BACKEND_TARGETS[@]}" | grep -q 'http://127.0.0.1:8088'
    printf '%s\n' "${PROXY_BACKEND_TARGETS[@]}" | grep -q 'http://127.0.0.1:9090/'

    run_service_checks >/dev/null
    assert_no_issue "SVC-014"
    assert_no_issue "SVC-015"
}

run_webserver_fixture() {
    reset_results
    local webroot="$TMP_DIR/webserver/public"
    local nginx_dir="$TMP_DIR/webserver/nginx/sites-enabled"
    mkdir -p "$webroot" "$nginx_dir" "$TMP_DIR/webserver/nginx/conf.d" "$TMP_DIR/webserver/apache/sites-enabled" "$TMP_DIR/webserver/apache/sites-available"
    sed "s#__WEBROOT__#$webroot#g" \
        "$FIXTURE_DIR/webserver/nginx/sites-enabled/web.conf" \
        > "$nginx_dir/web.conf"

    NGINX_SITES_ENABLED_DIR="$nginx_dir"
    NGINX_CONF_D_DIR="$TMP_DIR/webserver/nginx/conf.d"
    APACHE_SITES_ENABLED_DIR="$TMP_DIR/webserver/apache/sites-enabled"
    APACHE_SITES_AVAILABLE_DIR="$TMP_DIR/webserver/apache/sites-available"
    LOCAL_WEB_URL=""
    WEB_PORT="443"

    register_detected_component "nginx"
    register_detected_profile "Webserver"
    detect_webroots
    detect_proxy_backends
    detect_profiles

    assert_has_profile "Webserver"
    assert_no_profile "Reverse Proxy"
    [ "${#DETECTED_WEBROOTS[@]}" -ge 1 ]
}

run_apache_only_fixture() {
    reset_results
    local webroot="$TMP_DIR/apache-only/public"
    local apache_dir="$TMP_DIR/apache-only/apache/sites-enabled"
    mkdir -p "$webroot" "$TMP_DIR/apache-only/nginx/sites-enabled" "$TMP_DIR/apache-only/nginx/conf.d" "$apache_dir" "$TMP_DIR/apache-only/apache/sites-available"
    sed "s#__WEBROOT__#$webroot#g" \
        "$FIXTURE_DIR/apache-only/apache/sites-enabled/site.conf" \
        > "$apache_dir/site.conf"

    NGINX_SITES_ENABLED_DIR="$TMP_DIR/apache-only/nginx/sites-enabled"
    NGINX_CONF_D_DIR="$TMP_DIR/apache-only/nginx/conf.d"
    APACHE_SITES_ENABLED_DIR="$apache_dir"
    APACHE_SITES_AVAILABLE_DIR="$TMP_DIR/apache-only/apache/sites-available"
    LOCAL_WEB_URL=""
    WEB_PORT="443"

    register_detected_component "apache"
    register_detected_profile "Webserver"
    detect_webroots
    detect_proxy_backends
    detect_profiles

    assert_has_profile "Webserver"
    assert_no_profile "Reverse Proxy"
    [ "${#PROXY_BACKEND_TARGETS[@]}" -eq 0 ]
}

run_docker_fixture() {
    reset_results
    DOCKER_INFO_OK="1"
    WEB_PORT="8088"

    DOCKER_PS_OUTPUT="$(cat "$FIXTURE_DIR/docker-host/docker-ps-expected.txt")"
    run_docker_checks >/dev/null
    assert_no_issue "DOCKER-001"

    reset_results
    DOCKER_INFO_OK="1"
    WEB_PORT="8088"
    DOCKER_PS_OUTPUT="$(cat "$FIXTURE_DIR/docker-host/docker-ps-unexpected.txt")"
    run_docker_checks >/dev/null
    assert_has_issue "DOCKER-001"
}

run_reverse_proxy_fixture
run_webserver_fixture
run_apache_only_fixture
run_docker_fixture

printf 'Integration-Profile-Fixtures-Test erfolgreich.\n'
