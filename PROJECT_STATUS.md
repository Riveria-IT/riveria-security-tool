# PROJECT STATUS

Version: `1.0.0-alpha`

Dieses Dokument spiegelt den aktuellem Umsetzungsstand gegen den Projektplan wider.

## Erfuellt

- Projektstruktur mit `lib/`, `checks/`, `fixes/`, `profiles/`, `docs/`, `tests/`
- Kleine Hauptdatei mit Modul-Loading und Menue
- Grundregeln: Checks sind read-only, Fixes fragen mit `y/N`, Backups/Tests/Rollback in mehreren echten Fix-Flows
- Issue-/Fix-Registrierung mit IDs, Kategorien und Report-Ausgabe
- Score-System mit `WARNUNG` und `KRITISCH`
- TXT-, JSON- und HTML-Reports
- Fix-Assistent mit Menue fuer kritisch, alle, Auswahl und Vorschau
- Echte Fix-Flows fuer `SSH`, `Fail2ban`, `PHP`, `UFW`, `nginx`, `Permissions`, `Quarantaene`
- Erweiterter Code-Security-Scanner
- Erweiterte Detection fuer Dienste, Projekte und mehrere Profile
- Lokaler Smoke-Test und Demo-Report-Generator

## Teilweise

- `checks/system.sh`
  Deckt OS, Reboot, Updates, Uptime, RAM, Auth-Logs und SSH-Fehllogins ab, aber nicht jede im Plan genannte Detailpruefung gleich tief.

- `checks/services.sh`
  Deckt mehrere profilabhaengige Portentscheidungen ab, aber die Portmatrix ist noch nicht fuer alle Spezialfaelle vollstaendig.

- `checks/apps.sh`
  Erkennt Formulare, Mailversand, CSRF-, Rate-Limit- und Captcha-Hinweise, aber nicht jede Technologie-/CMS-Heuristik aus dem Langplan.

- `checks/exposure.sh`
  Deckt `.env`, mehrere sensible Dateitypen, HTTP-Pfade und Quarantaene-Kandidaten ab, aber Webroot-zu-URL-Mapping kann in komplexen vHost-Setups noch ungenau sein.

- `checks/docker.sh`
  Erfasst Docker, Compose, Port-Mappings und Mailcow-Kerncontainer, aber keine tieferen Container-Health-Checks.

- `checks/mail.sh`
  Deckt Ports, Mailcow, Rspamd/SOGo sowie SPF/DMARC/MX-Hinweise ab, aber kein vollstaendiges Mailserver-Audit je Dienstrolle.

- `checks/ssl_dns.sh`
  Deckt HTTP-Status, Zertifikatsbasis, A/AAAA, CNAME, MX, SPF und DMARC-Hinweise ab, aber keine tiefere TLS-Bewertung.

- `fixes/apache.sh`
  Guided-Fix zum Stoppen/Deaktivieren ist vorhanden, aber noch keine tieferen Sicherheitsentscheidungen.

- `run_updates_install()`
  Fuehrt Updates aus, ist aber noch kein vollwertiger Patch-Management-Workflow.

## Offen

- Vollstaendige Multi-vHost- und Reverse-Proxy-Zuordnung von Webroot zu oeffentlicher URL
- Sehr tiefe Mailcow-Analyse pro Containerrolle und Health-Status
- Vollstaendige DNS-Auswertung mit mehr Fallback-Mechanismen auf sehr schlanken Zielsystemen
- Optionales `install.sh`
- Vergleich zwischen Reports
- Optionale Weboberflaeche
- Formale CI-Integration mit ShellCheck und zusaetzlichen Regressionstests

## Fazit

Der Stand ist aus Projektsicht kein reines Grundgeruest mehr, sondern ein frueher Alpha-Release mit breiter Funktionsabdeckung. Die groessten Restarbeiten liegen jetzt eher in Edge Cases, Tiefe und Qualitaetssicherung als in fehlender Grundarchitektur.
