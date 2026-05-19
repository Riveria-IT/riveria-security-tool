# Einsteiger-Anleitung

Diese Anleitung ist fuer normale Nutzer gedacht, die ihren Server sicher pruefen wollen, ohne jede technische Einzelheit kennen zu muessen.

## Ziel

Riveria soll dir helfen:

- Probleme auf dem Server zu finden
- die Ergebnisse einfach zu verstehen
- sichere Fixes gefuehrt anzuwenden
- produktive Setups nicht blind kaputt zu machen

## Sicher starten

Starte das Tool immer mit Root-Rechten:

```bash
sudo bash ./riveria-security-tool.sh
```

Wenn du besonders vorsichtig starten willst:

```bash
DRY_RUN_MODE=1 RESULT_VIEW_MODE=simple sudo -E bash ./riveria-security-tool.sh
```

Das bedeutet:

- `DRY_RUN_MODE=1`
  Riveria zeigt nur, was es tun wuerde
- `RESULT_VIEW_MODE=simple`
  Riveria erklaert die Ergebnisse einfacher

## Empfohlener Ablauf

1. Starte Riveria.
2. Waehle im Menue `20) Einsteiger-Modus (einfach gefuehrt)`.
3. Aktiviere auf Wunsch zuerst den Vorschau-Modus.
4. Lass den Server automatisch pruefen.
5. Lies die einfache Zusammenfassung und die Ampel:
   - `ROT` = sofort wichtig
   - `GELB` = bald pruefen
   - `GRUEN` = okay
6. Lies danach die Abschlussliste:
   - Jetzt sofort tun
   - Heute noch pruefen
   - Spaeter verbessern
7. Wenn Riveria sichere Fixes gefunden hat, kannst du sie direkt Schritt fuer Schritt starten.

## Was du zuerst tun solltest

Wenn du unsicher bist, nutze immer zuerst:

- Vorschau-Modus
- einfache Ergebnis-Sprache
- Einsteiger-Modus

So kannst du erst alles lesen, bevor irgendetwas geaendert wird.

## Wann du vorsichtig sein solltest

Auch mit gefuehrtem Ablauf solltest du bei diesen Bereichen besonders aufpassen:

- `SSH`
- `Apache` oder `nginx`
- `Docker`
- `Mailserver`
- `Quarantaene`

Dort kann es sein, dass dein Server ein spezielles Setup hat. Dann solltest du die vorgeschlagenen Schritte kurz pruefen, bevor du sie bestaetigst.

## Gute Reihenfolge fuer echte Server

Empfohlener Minimal-Ablauf:

1. Erst Vorschau:

```bash
DRY_RUN_MODE=1 RESULT_VIEW_MODE=simple sudo -E bash ./riveria-security-tool.sh
```

2. Ergebnisse lesen.
3. Nur passende sichere Fixes bestaetigen.
4. Danach pruefen:
   - Webseite erreichbar?
   - SSH Login noch moeglich?
   - Docker-Container laufen?
   - Mail funktioniert noch?

## Wenn du nur schnell starten willst

Der kuerzeste sichere Weg ist:

```bash
sudo bash ./riveria-security-tool.sh
```

Dann im Menue:

1. `20) Einsteiger-Modus (einfach gefuehrt)`
2. Vorschau aktivieren
3. Server pruefen lassen
4. Sichere Fixes nur bestaetigen, wenn die Erklaerung fuer dich plausibel klingt

## Wenn du unsicher bist

Dann gilt:

- erst Vorschau
- nichts ueberhastet bestaetigen
- lieber nur sichere Auto-Fixes nutzen
- bei SSH, Proxy, Docker und Mail lieber doppelt hinschauen
