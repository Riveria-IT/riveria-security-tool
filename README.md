# Riveria Server Audit & Hardening Tool

Modulare Bash-Basis fuer Server-Audit, Security-Checks, Profil-Erkennung und gefuehrte Haertung auf Ubuntu/Debian.

Aktueller Stand: `1.0.0-alpha`

Fuer normale Nutzer:
[BEGINNER_GUIDE.md](/Users/michaelberger/Desktop/riveria-security-tool/docs/BEGINNER_GUIDE.md:1)

## 3-Minuten-Start

Wenn du das Tool zum ersten Mal benutzt, nimm diesen Weg:

1. Installieren

```bash
wget -O install.sh https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh && chmod +x install.sh && ./install.sh
```

2. Starten

```bash
sudo riveria-security-tool
```

3. Im Menue `20) Einsteiger-Modus (einfach gefuehrt)` waehlen

4. Bei der Frage zur Vorschau am besten zuerst `Ja` waehlen

Dann passiert Folgendes:

- der Server wird geprueft
- die Ergebnisse werden einfach erklaert
- `ROT`, `GELB` und `GRUEN` zeigen die Prioritaet
- sichere empfohlene Fixes koennen danach direkt gefuehrt gestartet werden

Wenn du direkt ohne Aenderungen testen willst:

```bash
DRY_RUN_MODE=1 RESULT_VIEW_MODE=simple sudo -E riveria-security-tool
```

## Fuer Einsteiger

Empfohlener erster Ablauf:

- immer zuerst Vorschau nutzen
- danach die Ampel und die Abschlussliste lesen
- erst dann sichere Fixes bestaetigen

Wichtige Menuepunkte:

- `20) Einsteiger-Modus (einfach gefuehrt)`
- `19) Dry-Run-Modus umschalten`
- `21) Ergebnis-Sprache umschalten`

## Start

Direkter Start aus dem Projektordner:

```bash
sudo bash ./riveria-security-tool.sh
```

Optional mit lokaler Konfiguration:

```bash
cp config.example.conf config.conf
sudo -E bash ./riveria-security-tool.sh
```

Nur Vorschau ohne echte Aenderungen:

```bash
DRY_RUN_MODE=1 sudo -E bash ./riveria-security-tool.sh
```

Einfachere Ergebnis-Texte:

```bash
RESULT_VIEW_MODE=simple sudo -E bash ./riveria-security-tool.sh
```

## Direkt Installieren

Direkt per `wget` herunterladen und installieren:

```bash
wget -O install.sh https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh && chmod +x install.sh && ./install.sh
```

Der Installer ersetzt eine vorhandene Installation im Zielordner automatisch. Falls dort bereits eine `config.conf` liegt, wird sie vor dem Ersetzen gesichert und danach wiederhergestellt.

Optional mit eigenem Zielordner:

```bash
wget -O install.sh https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh && chmod +x install.sh && ./install.sh "$HOME/riveria-security-tool"
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
- Mit `DRY_RUN_MODE=1` zeigen Fixes nur geplante Aenderungen und schreiben nichts.
- Mit `RESULT_VIEW_MODE=simple` werden Findings einfacher erklaert.
- Secrets werden nicht ausgegeben.
- `.env`-Inhalte und private Keys werden nicht angezeigt.
- Vor produktiven Aenderungen sollen Backups, Tests und Rollback greifen.

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

## Qualitaet

```bash
bash ./tests/smoke-test.sh
```

Damit werden Syntax, Menue-Start und Demo-Report-Erzeugung lokal geprueft.

## Naechste Ausbaustufen

- Edge Cases fuer Reverse Proxy, Mailcow und Multi-vHost weiter verfeinern
- mehr reale Beispielpfade und Testfaelle aufnehmen
- ShellCheck und spaetere CI-Anbindung ergaenzen
