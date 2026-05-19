#!/usr/bin/env bash
set -eu

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$BASE_DIR/.riveria-runtime/test-fixtures-proxy"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/nginx/sites-enabled" "$TMP_DIR/nginx/conf.d" "$TMP_DIR/apache/sites-enabled" "$TMP_DIR/apache/sites-available" "$TMP_DIR/web/public"

cat >"$TMP_DIR/nginx/sites-enabled/reverse-proxy.conf" <<EOF
server {
    server_name proxy.test;
    root $TMP_DIR/web/public;
    location / {
        proxy_pass http://127.0.0.1:8088;
    }
}
EOF

cat >"$TMP_DIR/apache/sites-enabled/app.conf" <<EOF
<VirtualHost *:80>
    DocumentRoot "$TMP_DIR/web/public"
    ProxyPass /app http://127.0.0.1:9090/
</VirtualHost>
EOF

source "$BASE_DIR/lib/core.sh"
source "$BASE_DIR/lib/ui.sh"
source "$BASE_DIR/lib/report.sh"
source "$BASE_DIR/lib/scoring.sh"
source "$BASE_DIR/checks/services.sh"
source "$BASE_DIR/checks/docker.sh"

load_config "$BASE_DIR"
reset_results

NGINX_SITES_ENABLED_DIR="$TMP_DIR/nginx/sites-enabled"
NGINX_CONF_D_DIR="$TMP_DIR/nginx/conf.d"
APACHE_SITES_ENABLED_DIR="$TMP_DIR/apache/sites-enabled"
APACHE_SITES_AVAILABLE_DIR="$TMP_DIR/apache/sites-available"
LOCAL_WEB_URL="http://127.0.0.1:8088/login"
WEB_PORT="8088"
DOCKER_INFO_OK="1"
DOCKER_PS_OUTPUT=$'web nginx 0.0.0.0:8088->8088/tcp\nadmin adminer 0.0.0.0:9000->8080/tcp'

register_detected_component "nginx"
register_detected_component "apache"
register_detected_profile "Webserver"

register_active_listener "tcp" "0.0.0.0:8088" "users:((\"docker-proxy\",pid=1,fd=1))"
register_active_listener "tcp" "0.0.0.0:9000" "users:((\"adminer\",pid=4,fd=1))"
register_active_listener "tcp" "127.0.0.1:9090" "users:((\"apache2\",pid=2,fd=1))"
register_active_listener "tcp" "127.0.0.1:8088" "users:((\"node\",pid=3,fd=1))"

detect_proxy_backends
detect_webroots

[ "${#PROXY_BACKEND_TARGETS[@]}" -ge 2 ]
printf '%s\n' "${PROXY_BACKEND_TARGETS[@]}" | grep -q 'http://127.0.0.1:8088'
printf '%s\n' "${PROXY_BACKEND_TARGETS[@]}" | grep -q 'http://127.0.0.1:9090/'
printf '%s\n' "${DETECTED_WEBROOTS[@]}" | grep -q "$TMP_DIR/web/public"

run_service_checks >/tmp/riveria_proxy_service_test.log
printf '%s\n' "${ISSUE_IDS[@]}" | grep -q 'SVC-013'
! printf '%s\n' "${ISSUE_IDS[@]}" | grep -q 'SVC-014'
! printf '%s\n' "${ISSUE_IDS[@]}" | grep -q 'SVC-015'

reset_results
DOCKER_INFO_OK="1"
DOCKER_PS_OUTPUT=$'web nginx 0.0.0.0:8088->8088/tcp\nadmin adminer 0.0.0.0:9000->8080/tcp'
run_docker_checks >/tmp/riveria_proxy_docker_test.log
printf '%s\n' "${ISSUE_IDS[@]}" | grep -q 'DOCKER-001'

printf 'Integration-Proxy-Docker-Test erfolgreich.\n'
