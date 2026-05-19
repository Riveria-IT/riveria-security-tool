#!/usr/bin/env bash

run_docker_checks() {
    section "Docker / Mailcow"

    if [ -z "$DOCKER_PS_OUTPUT" ] && ! cmd_exists docker; then
        info "Docker ist nicht installiert."
        return
    fi

    ok "Docker CLI erkannt."
    if [ -n "$DOCKER_INFO_OK" ] || docker info >/dev/null 2>&1; then
        ok "Docker-Daemon antwortet."
    else
        warn "Docker CLI vorhanden, aber Daemon antwortet nicht klar."
        return
    fi

    if [ -n "$DOCKER_PS_OUTPUT" ] || cmd_exists docker-compose || docker compose version >/dev/null 2>&1; then
        ok "Docker Compose erkannt."
    else
        warn "Docker Compose nicht erkannt."
    fi

    local ps_output
    if [ -n "$DOCKER_PS_OUTPUT" ]; then
        ps_output="$DOCKER_PS_OUTPUT"
    else
        ps_output="$(docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' 2>/dev/null | head -n 20 || true)"
    fi
    if [ -n "$ps_output" ]; then
        info "Container / Images / Ports:"
        printf '%s\n' "$ps_output"
    else
        info "Keine laufenden Container erkannt."
    fi

    local public_mappings expected_public_mappings unexpected_public_mappings line host_port
    public_mappings="$(printf '%s\n' "$ps_output" | grep -E '0\.0\.0\.0:|\[::\]:' || true)"
    if [ -n "$public_mappings" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            host_port="$(printf '%s\n' "$line" | sed -nE 's#.*(0\.0\.0\.0:|\[::\]:)([0-9]+)->.*#\2#p' | head -n 1)"
            if [ -n "$WEB_PORT" ] && [ "$host_port" = "$WEB_PORT" ]; then
                expected_public_mappings="${expected_public_mappings}${line}\n"
                continue
            fi
            case "$host_port" in
                80|443|25|110|143|465|587|993|995|4190)
                    expected_public_mappings="${expected_public_mappings}${line}\n"
                    ;;
                *)
                    unexpected_public_mappings="${unexpected_public_mappings}${line}\n"
                    ;;
            esac
        done <<EOF
$public_mappings
EOF

        if [ -n "$expected_public_mappings" ]; then
            info "Erwartbare oeffentliche Docker-Port-Mappings erkannt:"
            printf '%b' "$expected_public_mappings"
        fi
        if [ -n "$unexpected_public_mappings" ]; then
            register_issue "DOCKER-001" "Unerwartete oeffentliche Docker-Port-Mappings erkannt" "WARNUNG" \
                "Mindestens ein Container ist ueber einen unerwarteten Host-Port oeffentlich gemappt." \
                "Port-Mappings und Reverse-Proxy-Design manuell pruefen." "MANUAL" "no"
            warn "Unerwartete oeffentliche Docker-Port-Mappings erkannt."
            printf '%b' "$unexpected_public_mappings"
        fi
    fi

    if [ -d "$MAILCOW_PATH" ] || printf '%s\n' "$ps_output" | grep -qi 'mailcow'; then
        register_detected_profile "Mailcow Server"
        ok "Mailcow-Container erkannt."

        local mailcow_expected missing_mailcow=0 container_name
        mailcow_expected="$(printf '%s\n' "$ps_output" | grep -E 'nginx-mailcow|postfix-mailcow|dovecot-mailcow|rspamd-mailcow|sogo-mailcow|mysql-mailcow|redis-mailcow' || true)"
        if [ -n "$mailcow_expected" ]; then
            info "Mailcow-Container-Hinweise:"
            printf '%s\n' "$mailcow_expected"
        fi

        for container_name in nginx-mailcow postfix-mailcow dovecot-mailcow rspamd-mailcow sogo-mailcow mysql-mailcow redis-mailcow; do
            if ! printf '%s\n' "$ps_output" | grep -q "$container_name"; then
                missing_mailcow=1
                warn "Mailcow-Kerncontainer nicht klar erkannt: $container_name"
            fi
        done
        if [ "$missing_mailcow" -eq 1 ]; then
            register_issue "DOCKER-002" "Mailcow-Kerncontainer unvollstaendig erkannt" "WARNUNG" \
                "Mindestens ein typischer Mailcow-Kerncontainer wurde nicht in den laufenden Containern erkannt." \
                "Mailcow-Stack, docker ps und Service-Status manuell pruefen." "MANUAL" "no"
        else
            ok "Typische Mailcow-Kerncontainer wurden erkannt."
        fi

        if [ -f "$MAILCOW_PATH/mailcow.conf" ]; then
            ok "mailcow.conf gefunden."
        else
            warn "Mailcow-Profil erkannt, aber mailcow.conf nicht gefunden."
        fi
    fi
}
