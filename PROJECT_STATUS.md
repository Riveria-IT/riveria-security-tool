# PROJECT STATUS

Version: `1.0.0-alpha`

Dieses Dokument beschreibt den aktuellen Alpha-Stand gegen den Projektplan. Es ist bewusst konservativ formuliert und keine Zusage fuer ein stabiles Production-Release.

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
- CI-Grundlage mit ShellCheck und Smoke-Test per GitHub Actions

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

- `install.sh`
  Der Installer ist jetzt defensiver, blockiert gefaehrliche Zielordner und unterstuetzt einen System-Launcher, bleibt aber bis zu sauberen Release-Tags bewusst Alpha-orientiert.

## Offen

- Vollstaendige Multi-vHost- und Reverse-Proxy-Zuordnung von Webroot zu oeffentlicher URL
- Sehr tiefe Mailcow-Analyse pro Containerrolle und Health-Status
- Vollstaendige DNS-Auswertung mit mehr Fallback-Mechanismen auf sehr schlanken Zielsystemen
- Gepflegte Release-Tags fuer reproduzierbare Installationen statt Alpha-Branch als Standardquelle
- Vergleich zwischen Reports
- Optionale Weboberflaeche
- Zusaetzliche Regressionstests fuer mehr Edge Cases und reale Fixtures

## Fazit

Der Stand ist kein reines Grundgeruest mehr, sondern ein fruehes Alpha-Release mit brauchbarer Kernfunktionalitaet. Was noch fehlt, sind vor allem reproduzierbare Releases, mehr Abdeckung fuer Sonderfaelle und weitere Qualitaetssicherung vor einem spaeteren stabilen Release.
