# Riveria Server Audit & Hardening Tool

Modulare Bash-Basis fuer Server-Audit, Security-Checks, Profil-Erkennung und gefuehrte Haertung auf Ubuntu/Debian.

Aktueller Stand: `1.0.0-alpha`

## Status

Diese Alpha-Version bildet den Projektplan bereits zu grossen Teilen ab:

- modulare Struktur in `lib/`, `checks/`, `fixes/`, `profiles/`
- Hauptmenue und Basis-Workflows
- Detection-Registry fuer Komponenten und Profile
- Issue-, Fix- und Score-Modell
- TXT-, JSON- und HTML-Report-Basis
- erste read-only Checks
- erste AUTO-SAFE-Fixes mit Backup, Test und Rollback fuer SSH, Fail2ban und PHP
- UFW-Automation mit profilbasierter Portplanung und Regel-Backups
- nginx-Security-Snippet mit vorsichtiger Auto-Einbindung, Test und Rollback
- gezielte Permission-Fixes fuer sensible Dateien und world-writable Configs
- Quarantaene-Flow fuer Dumps, Backups und Schluesseldateien mit Zeitstempel-Zielordner
- deutlich ausgebautes TXT-, JSON- und HTML-Reporting mit Score, Findings und Fix-Vorschlaegen
- erweiterter Code-Security-Scanner fuer SQL-, Command-, Include-, Upload- und Debug-Hinweise
- erweiterte Detection sowie App-, Exposure-, System-, Docker-, Mail- und SSL/DNS-Checks
- Fix-Assistent mit Untermenue fuer kritisch, alle, Auswahl und Vorschau

Den aktuellen Soll-Ist-Abgleich findest du in [PROJECT_STATUS.md](/Users/michaelberger/Desktop/riveria-security-tool/PROJECT_STATUS.md:1).
Release-Notizen findest du in [RELEASE_NOTES.md](/Users/michaelberger/Desktop/riveria-security-tool/RELEASE_NOTES.md:1).

## Start

```bash
sudo bash ./riveria-security-tool.sh
```

Optional:

```bash
cp config.example.conf config.conf
sudo -E bash ./riveria-security-tool.sh
```

## Direkt Installieren

Direkt per `wget` herunterladen und installieren:

```bash
wget -qO- https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh | bash
```

Optional mit eigenem Zielordner:

```bash
wget -qO- https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh | bash -s -- "$HOME/riveria-security-tool"
```

Falls `wget` nicht vorhanden ist:

```bash
curl -fsSL https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh | bash
```

Raw Installer:
[install.sh](https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh)

## Sicherheitsregeln

- Checks aendern nichts.
- Fixes fragen immer vorher mit `y/N`.
- Secrets werden nicht ausgegeben.
- `.env`-Inhalte und private Keys werden nicht angezeigt.
- Vor produktiven Aenderungen sollen Backups, Tests und Rollback greifen.

## Qualitaet

```bash
bash ./tests/smoke-test.sh
```

Damit werden Syntax, Menue-Start und Demo-Report-Erzeugung lokal geprueft.

## Naechste Ausbaustufen

- Edge Cases fuer Reverse Proxy, Mailcow und Multi-vHost weiter verfeinern
- mehr reale Beispielpfade und Testfaelle aufnehmen
- ShellCheck und spaetere CI-Anbindung ergaenzen
