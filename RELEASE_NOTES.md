# Release Notes

## 1.0.0-alpha

`Riveria Server Audit & Hardening Tool` ist jetzt als frueher Alpha-Stand verfuegbar.

### Highlights

- Modulare Bash-Struktur mit `lib/`, `checks/`, `fixes/`, `profiles/`, `docs/` und `tests/`
- Hauptmenue fuer Audit, Erkennung, Reports und gefuehrte Haertung
- Profil- und Komponenten-Erkennung fuer typische Ubuntu/Debian-Serverrollen
- Read-only Sicherheitschecks fuer System, Services, Webapps, Code, Permissions, Exposure, Docker, Mail und SSL/DNS
- Gefuehrter Fix-Assistent mit `AUTO-SAFE`, `GUIDED` und `MANUAL`
- Echte Fix-Flows fuer `SSH`, `Fail2ban`, `PHP`, `UFW`, `nginx`, `Permissions`, `Quarantaene` und Guided-Aktionen fuer `Apache`
- TXT-, JSON- und HTML-Reports
- Lokaler Smoke-Test und Demo-Report-Generator

### Wichtige Sicherheitsprinzipien

- Checks aendern nichts
- Fixes fragen immer mit `y/N`
- Standardantwort bleibt `Nein`
- Backups, Tests und Rollback sind in mehreren Fix-Flows bereits integriert
- Secrets, `.env`-Inhalte und private Keys werden nicht ausgegeben

### Enthaltene Audit-Bereiche

- System-Basispruefungen
- Port- und Service-Bewertung
- Webapp- und Kontaktformular-Hinweise
- Statische Code-Sicherheits-Heuristiken
- Sensitive-Exposure-Pruefungen
- Dateirechte- und Schluesselpruefungen
- Docker- und Mailcow-Hinweise
- Mailserver-, SPF-, DMARC- und MX-Hinweise
- SSL- und DNS-Basisdaten

### Noch Alpha

Dieser Stand ist breit nutzbar, aber noch nicht als vollstaendig abgeschlossenes `1.0`-Release zu verstehen.

Noch offen oder nur teilweise vertieft:

- komplexe Multi-vHost- und Reverse-Proxy-Sonderfaelle
- sehr tiefe Mailcow-Container- und Health-Auswertung
- vollstaendige DNS-Fallback-Strategien auf Minimal-Systemen
- CI/ShellCheck-Integration
- Report-Vergleich und optionales `install.sh`
- spaetere optionale Weboberflaeche

### Empfohlene Schnellpruefung

```bash
bash ./tests/smoke-test.sh
```

### Interner Status

Der aktuelle Soll-Ist-Abgleich zum Projektplan ist in [PROJECT_STATUS.md](./PROJECT_STATUS.md) dokumentiert.
