# Tests

## Schnellpruefung

```bash
bash ./tests/smoke-test.sh
```

Der Smoke-Test prueft:

- Bash-Syntax aller Shell-Dateien
- Menue-Start des Hauptskripts
- Demo-Report-Generierung fuer TXT, JSON und HTML
- Existenz der erzeugten Report-Dateien

## Demo-Reports

```bash
bash ./tests/generate-demo-report.sh
```

Die Demo-Reports werden in `.riveria-runtime/reports/` erzeugt und enthalten nur kuenstliche Testdaten.
