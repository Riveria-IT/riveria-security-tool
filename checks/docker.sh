#!/usr/bin/env bash

run_docker_checks() {
    section "Docker / Mailcow"

    if ! cmd_exists docker; then
        info "Docker ist nicht installiert."
        return
    fi

    ok "Docker CLI erkannt."
    if docker info >/dev/null 2>&1; then
        ok "Docker-Daemon antwortet."
    else
        warn "Docker CLI vorhanden, aber Daemon antwortet nicht klar."
        return
    fi

    if cmd_exists docker-compose || docker compose version >/dev/null 2>&1; then
        ok "Docker Compose erkannt."
    else
        warn "Docker Compose nicht erkannt."
    fi

    local ps_output
    ps_output="$(docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' 2>/dev/null | head -n 20 || true)"
    if [ -n "$ps_output" ]; then
        info "Container / Images / Ports:"
        printf '%s\n' "$ps_output"
    else
        info "Keine laufenden Container erkannt."
    fi

    if printf '%s\n' "$ps_output" | grep -Eq '0\.0\.0\.0:|\[::\]:'; then
        register_issue "DOCKER-001" "Oeffentliche Docker-Port-Mappings erkannt" "WARNUNG" \
            "Mindestens ein Container ist ueber 0.0.0.0 oder [::] nach aussen gemappt." \
            "Port-Mappings und Reverse-Proxy-Design manuell pruefen." "MANUAL" "no"
        warn "Oeffentliche Docker-Port-Mappings erkannt."
    fi

    if [ -d /opt/mailcow-dockerized ] || printf '%s\n' "$ps_output" | grep -qi 'mailcow'; then
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

        if [ -f /opt/mailcow-dockerized/mailcow.conf ]; then
            ok "mailcow.conf gefunden."
        else
            warn "Mailcow-Profil erkannt, aber mailcow.conf nicht gefunden."
        fi
    fi
}
