# Riveria Server Audit & Hardening Tool

Modulare Bash-Basis fuer Server-Audit, Security-Checks, Profil-Erkennung und gefuehrte Haertung auf Ubuntu/Debian.

Aktueller Stand: `1.0.0-alpha`

Fuer normale Nutzer: [docs/BEGINNER_GUIDE.md](docs/BEGINNER_GUIDE.md)

## 3-Minuten-Start

Wenn du das Tool zum ersten Mal benutzt, nimm diesen Weg:

1. Installieren

```bash
wget -O install.sh https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh && chmod +x install.sh && ./install.sh
```

2. Starten

```bash
sudo "$HOME/.local/bin/riveria-security-tool"
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
DRY_RUN_MODE=1 RESULT_VIEW_MODE=simple sudo -E "$HOME/.local/bin/riveria-security-tool"
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

Die Standard-Installation legt das Projekt nach `~/riveria-security-tool` und den Launcher nach `~/.local/bin/riveria-security-tool`.

Direkt per `wget` herunterladen und installieren:

```bash
wget -O install.sh https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh && chmod +x install.sh && sudo ./install.sh
```

Der Installer ersetzt eine vorhandene Installation im Zielordner automatisch. Falls dort bereits eine `config.conf` liegt, wird sie vor dem Ersetzen gesichert und danach wiederhergestellt. Gefaehrliche Zielordner wie `/`, `/root`, `/home`, `/usr`, `/var`, `/etc` und `/opt` werden blockiert.
Nach erfolgreicher Installation startet Riveria direkt automatisch. Falls du das nicht willst, setze `AUTO_START_AFTER_INSTALL=0`.

Optional mit eigenem Zielordner:

```bash
wget -O install.sh https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh && chmod +x install.sh && sudo ./install.sh /opt/riveria-security-tool
```

Falls `wget` nicht vorhanden ist, funktioniert auch `curl`:

```bash
curl -fsSL https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh -o install.sh && chmod +x install.sh && sudo ./install.sh
```

Fuer produktive Hosts wird standardmaessig ein System-Launcher unter `/usr/local/bin` angelegt, damit `sudo riveria-security-tool` zuverlaessig funktioniert:

```bash
wget -O install.sh https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh && chmod +x install.sh && sudo ./install.sh
```

Optional kannst du weiter einen lokalen Launcher erzwingen:

```bash
INSTALL_LAUNCHER_MODE=local AUTO_START_AFTER_INSTALL=0 sudo ./install.sh "$HOME/riveria-security-tool"
```

Der Installer unterstuetzt ausserdem:

- `RIVERIA_REF=main` und `RIVERIA_REF_TYPE=branch` fuer den aktuellen Alpha-Branch
- `RIVERIA_REF=v1.0.0-alpha` und `RIVERIA_REF_TYPE=tag` fuer einen konkreten Tag, sobald Releases vorhanden sind

Aktuell zeigt `main` auf den Alpha-Stand. Bis feste Releases gepflegt werden, sollte das klar als Alpha behandelt werden.

Raw-Installer: [install.sh](https://raw.githubusercontent.com/Riveria-IT/riveria-security-tool/main/install.sh)

## Sicherheitsregeln

- Checks aendern nichts.
- Fixes fragen immer vorher mit `y/N`.
- Mit `DRY_RUN_MODE=1` zeigen Fixes nur geplante Aenderungen und schreiben nichts.
- Mit `RESULT_VIEW_MODE=simple` werden Findings einfacher erklaert.
- Secrets werden nicht ausgegeben.
- `.env`-Inhalte und private Keys werden nicht angezeigt.
- Vor produktiven Aenderungen sollen Backups, Tests und Rollback greifen.

## Status

Diese Alpha-Version deckt bereits einen grossen Teil des geplanten Funktionsumfangs ab, ist aber noch kein stabiles Production-Release:

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

Den aktuellen Soll-Ist-Abgleich findest du in [PROJECT_STATUS.md](PROJECT_STATUS.md).
Release-Notizen findest du in [RELEASE_NOTES.md](RELEASE_NOTES.md).
Hinweise fuer Sicherheitsmeldungen stehen in [SECURITY.md](SECURITY.md).

## Qualitaet

```bash
bash ./tests/smoke-test.sh
```

Damit werden Syntax, Menue-Start, Fixture-Tests und Demo-Report-Erzeugung lokal geprueft.

Fuer CI gibt es ausserdem eine GitHub Action mit ShellCheck und Smoke-Test.

## Naechste Ausbaustufen

- Edge Cases fuer Reverse Proxy, Mailcow und Multi-vHost weiter verfeinern
- mehr reale Beispielpfade und Testfaelle aufnehmen
- Releases/Tags fuer reproduzierbare Installer-Staende pflegen
