#!/usr/bin/env bash

run_system_checks() {
    section "System Checks"

    if [ -f /etc/os-release ]; then
        ok "OS erkannt: $(. /etc/os-release && printf '%s %s' "$NAME" "$VERSION_ID")"
    else
        warn "OS-Version konnte nicht erkannt werden."
    fi

    if cmd_exists unattended-upgrade || dpkg -l unattended-upgrades >/dev/null 2>&1; then
        ok "unattended-upgrades ist installiert."
    else
        register_issue "SYS-001" "unattended-upgrades fehlt" "WARNUNG" \
            "Automatische Sicherheitsupdates sind nicht erkennbar." \
            "Paket unattended-upgrades pruefen und bei Bedarf aktivieren." "GUIDED" "no"
        warn "unattended-upgrades ist nicht erkennbar."
    fi

    if [ -f /var/run/reboot-required ]; then
        register_issue "SYS-002" "Reboot erforderlich" "WARNUNG" \
            "Das System meldet einen ausstehenden Neustart." \
            "Wartungsfenster fuer Reboot einplanen." "MANUAL" "no"
        warn "Reboot erforderlich."
    else
        ok "Kein ausstehender Reboot erkannt."
    fi

    cmd_exists uname && info "Kernel: $(uname -r)"
    cmd_exists uname && info "Architektur: $(uname -m)"

    if cmd_exists systemd-detect-virt; then
        info "Virtualisierung: $(systemd-detect-virt 2>/dev/null || printf 'keine erkannt')"
    fi

    if [ -r /proc/uptime ]; then
        info "Uptime-Sekunden: $(cut -d. -f1 /proc/uptime 2>/dev/null)"
    fi

    if cmd_exists df; then
        info "Root-Dateisystem: $(df -h / 2>/dev/null | awk 'NR==2{print $3" belegt von "$2" ("$5")"}')"
    fi

    if [ -r /proc/meminfo ]; then
        info "RAM gesamt: $(awk '/MemTotal/ {printf "%.0f MB", $2/1024}' /proc/meminfo 2>/dev/null)"
    fi

    if cmd_exists apt; then
        local pending_updates security_updates
        pending_updates="$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
        info "Offene Updates: ${pending_updates:-0}"
        security_updates="$(apt list --upgradable 2>/dev/null | grep -ci security || true)"
        if [ "${security_updates:-0}" -gt 0 ]; then
            register_issue "SYS-003" "Sicherheitsupdates verfuegbar" "WARNUNG" \
                "Es wurden moegliche Sicherheitsupdates erkannt." \
                "Paketliste pruefen und Updates in einem Wartungsfenster einspielen." "MANUAL" "no"
            warn "Moegliche Sicherheitsupdates verfuegbar: $security_updates"
        fi
    fi

    if [ -f /var/log/auth.log ] || cmd_exists journalctl; then
        ok "Authentifizierungs-Logs sind verfuegbar."
    else
        register_issue "SYS-004" "Keine Auth-Logs erkennbar" "WARNUNG" \
            "Weder /var/log/auth.log noch journalctl konnten fuer Auth-Logs verifiziert werden." \
            "Logging-Konfiguration und SSH-Auditing pruefen." "MANUAL" "no"
        warn "Keine klaren Auth-Logs erkennbar."
    fi

    local failed_ssh=0
    if [ -f /var/log/auth.log ]; then
        failed_ssh="$(grep -ci 'Failed password' /var/log/auth.log 2>/dev/null || true)"
    elif cmd_exists journalctl; then
        failed_ssh="$(journalctl -u ssh -u sshd --since '7 days ago' 2>/dev/null | grep -ci 'Failed password' || true)"
    fi

    if [ "${failed_ssh:-0}" -ge 20 ]; then
        register_issue "SYS-005" "Viele fehlgeschlagene SSH-Logins" "WARNUNG" \
            "Es wurden auffaellig viele fehlgeschlagene SSH-Logins erkannt." \
            "SSH-Haertung, Fail2ban und Logins manuell pruefen." "GUIDED" "no"
        warn "Viele fehlgeschlagene SSH-Logins erkannt: $failed_ssh"
    else
        info "Fehlgeschlagene SSH-Logins: ${failed_ssh:-0}"
    fi
}
