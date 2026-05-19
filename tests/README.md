# Tests

## Schnellpruefung

```bash
bash ./tests/smoke-test.sh
```

Der Smoke-Test prueft:

- Bash-Syntax aller Shell-Dateien
- Menue-Start des Hauptskripts
- CLI-Snapshots fuer Root-Hinweis, Hauptmenue und Fix-Assistent
- CLI-Snapshots fuer Fix-Auswahlmenue, Bestaetigungsdialoge und Stub-Fixablauf
- Fixture-basierte Handler-Tests fuer UFW-Planung und nginx-Snippet-Fix
- Fixture-basierte Handler-Tests fuer SSH-Haertung und sensible Dateirechte
- Low-Level-Parser-Test fuer `set_config_directive` und `set_ini_directive`
- Dry-Run-Test, der prueft, dass wichtige Fixes im Vorschau-Modus nichts veraendern
- Snapshot-Test fuer den vereinfachten Einsteiger-Fix-Assistenten
- Snapshot-Test fuer die einfache Ergebnis-Sprache
- Demo-Report-Generierung fuer TXT, JSON und HTML
- Existenz der erzeugten Report-Dateien
- einfache Integration der Webroot-/Pfadlogik fuer Expositionschecks
- Fixture-basierte Integration fuer Proxy-/vHost- und Docker-Mapping-Logik
- mehrere feste Serverprofil-Fixtures fuer Webserver, Reverse Proxy, Apache-only und Docker-Mappings
- deterministische Report-Snapshots fuer typische Fixture-Szenarien

## Demo-Reports

```bash
bash ./tests/generate-demo-report.sh
```

Die Demo-Reports werden in `.riveria-runtime/reports/` erzeugt und enthalten nur kuenstliche Testdaten.

## Webroot-Integration

```bash
bash ./tests/integration-webroot-checks.sh
```

Der Test erzeugt lokale Fixture-Pfade unter `.riveria-runtime/` und prueft die neue Webroot-Zuordnung ohne echte Systempfade oder produktive Konfigurationen zu veraendern.

## Proxy- und Docker-Integration

```bash
bash ./tests/integration-proxy-docker.sh
```

Der Test verwendet lokale nginx-/Apache-vHost-Fixtures, kuenstliche Listener und simulierte Docker-Port-Mappings. Damit wird geprueft, dass Reverse-Proxy-Backends erkannt und erwartbare Ports nicht faelschlich wie Fremdports behandelt werden.

## Profil-Fixtures

```bash
bash ./tests/integration-profile-fixtures.sh
```

Der Test laedt feste Fixtures aus `tests/fixtures/` und prueft mehrere typische Profilklassen mit klaren Erwartungen:

- nginx Reverse Proxy mit lokalen Backends
- klassischer nginx-Webserver ohne Proxy
- Apache-only-vHost ohne Proxy
- Docker-Host mit erwartbaren und unerwarteten oeffentlichen Port-Mappings

## Report-Snapshots

```bash
bash ./tests/integration-report-snapshots.sh
```

Der Test erzeugt deterministische TXT-/JSON-Reports fuer ausgewaehlte Fixture-Szenarien und vergleicht sie gegen gespeicherte Snapshots in `tests/fixtures/report-snapshots/`. Dynamische Pfade in TXT-Reports werden dabei vor dem Vergleich normalisiert.
