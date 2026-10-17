# Owl auf macserver mit Komodo

## Verifizierter Stand vom 2026-10-17

- [Vorschau-Release v0.1.0-owl.1](https://github.com/MephistoJB/Owl/releases/tag/v0.1.0-owl.1).
- [Erfolgreicher Main-Build](https://github.com/MephistoJB/Owl/actions/runs/39022140586)
  fuer Commit `63103110e069ba9f7fb3ee901cbeb147ff3ab5ef`.
- Getestetes Image: `ghcr.io/mephistojb/owl:sha-63103110e069ba9f7fb3ee901cbeb147ff3ab5ef`.
- Komodo ist auf den unveraenderlichen Digest
  `ghcr.io/mephistojb/owl@sha256:b7a9cf37faa9fd3e11dd8afdeeb0ac200c837036633bdbe898bbb056eb4933cf`
  eingestellt.
- Komodo-Stack `owl` auf `Macserver`; Image-Pull erfolgreich (Update
  `6ad344eac3b21f6d142d5840`). Kein Backend-Container gestartet.
- Image auf Mac als `linux/arm64` geprueft; die tatsaechliche Mac-Konfiguration
  laesst sich darin erfolgreich einlesen. Registry-Zugriff ist ohne Login
  moeglich; das GHCR-Paket ist oeffentlich.
- HF-Zugang fehlt weiterhin. Das entsprechende Komodo-Umgebungsfeld ist leer;
  Compose verlangt einen Wert und verhindert so einen versehentlichen Start.
- Nach Hinterlegung von `OWL_ASYNC_WHISPER_HF_TOKEN` in Psono und Modellfreigaben:
  als geheime Komodo-Variable `OWL_HF_TOKEN` uebernehmen, den Stack auf deren
  Referenz umstellen, ueber Komodo deployen und Modell-/API-Tests abschliessen.
  Kein Ersatz-Token und kein Wechsel des Transkriptionsanbieters ist eingerichtet.

## Bereitstellungsumfang

Ein ARM64-Backend-Image aus dem Fork wird ueber GHCR veroeffentlicht. Komodo
verwaltet den Compose-Stack `owl` auf dem Server `Macserver`. Der bestehende
Ollama-Dienst auf macOS wird ueber `host.docker.internal:11434` angesprochen.
Die lokale WhisperX-Transkription im Linux-Container verwendet CPU/int8.
Die Watch-/iPhone-App nutzt die Backend-API; ein Webfrontend ist in diesem
Server-Release nicht enthalten. Es wird keine neue Datenbank-App benoetigt.

## Release

`.github/workflows/docker-image.yml` testet bei Main-Push, Pull Request und
manuellem Start. Das Image wird auf einem nativen ARM64-Runner gebaut und erst
nach CLI-/Server-Import-Smoke-Tests veroeffentlicht. Pull Requests publizieren
keine Images. GitHub Actions verwendet `GITHUB_TOKEN` mit `packages: write`;
kein separater Docker-Hub-Schluessel ist erforderlich.

- Jeder erfolgreiche Main-/manuelle Build: `ghcr.io/mephistojb/owl:sha-<commit>`.
- Tag `vX.Y.Z`: zusaetzlich `:vX.Y.Z` und `:latest`.
- Tags mit Bindestrich wie `v0.1.0-rc.1`: Versionstag ohne Aktualisierung von `latest`.
- Das Image ist `linux/arm64`. Andere Architekturen sind nicht Bestandteil
  dieser ersten Mac-Bereitstellung.

Release-Tags erst auf den erfolgreich geprueften Commit setzen. Komodo soll
zum gezielten Rollout einen konkreten Tag oder Digest verwenden; kein
ungeprueftes Auto-Update von `latest`.

## Komodo-Konfiguration

`compose.yaml` wird als Compose-Inhalt des Stacks hinterlegt. Die benoetigten
Variablen sind:

| Variable | Inhalt |
| --- | --- |
| `OWL_IMAGE` | Getesteter GHCR-Tag oder Digest |
| `OWL_CONFIG_DIR` | Absoluter Mac-Pfad zum Verzeichnis mit `config.yaml` |
| `OWL_USER_CLIENT_TOKEN` | Privater API-Token aus Psono |
| `OWL_ASYNC_WHISPER_HF_TOKEN` | HF-Token mit Modellfreigaben aus Psono |
| `OWL_PORT` | Freier Hostport; Vorlage 8012 |
| `OWL_LLM_API_BASE_URL` | Standard `http://host.docker.internal:11434` |
| `OWL_LLM_MODEL` | Vorhandenes Modell: `ollama/qwen3-vl:30b-a3b-instruct-q4_K_M` |

`config.example.yaml` wird als nicht geheime Konfiguration nach `config.yaml`
kopiert. Secrets werden zur Laufzeit aus einer geschuetzten Umgebungsdatei
bezogen; sie werden weder ins Image noch ins Repository geschrieben. Die
Compose-Datei enthaelt keine Quellcode-/Entrypoint-Overrides.

Das Docker-Volume `owl_owl-data` (bei Compose-Projektname `owl`) enthaelt
Originalaufnahmen, SQLite-Datenbank und heruntergeladene Modelle unter `/data`.
Dieses Volume und die geschuetzte Laufzeitkonfiguration sind die zu sichernden
Daten. Eine neue Backup-Automation ist nicht Bestandteil des Releases.

## Verifikation und Grenzen

1. Komodo-Deploy muss erfolgreich sein, Container muss laufen und gesund werden.
2. Der Healthcheck prueft die authentifizierte Owl-API und die OpenAPI des
   lokalen asynchronen Whisper-Workers. Die Modellinitialisierung kann beim
   ersten Start mehrere Minuten dauern.
3. Von macOS und einem zweiten LAN-Geraet API-Erreichbarkeit pruefen.
4. Danach deutsche Testaufnahme und Neustart-/Offline-Tests aus dem
   Entwicklungsplan durchfuehren.

Ohne HF-Token und akzeptierte Modellbedingungen ist die Modellinitialisierung
nicht abgenommen. Ein Image-Import-Smoke-Test beweist keine Transkription.
Die bekannten Grenzen von Queue-Persistenz und Chunk-Deduplizierung bleiben
bis zu ihrem eigenen freigegebenen Aenderungspaket bestehen.

## Rollback

Den vorherigen Image-Digest im Komodo-Stack setzen und dort erneut deployen.
Datenvolume nicht loeschen. Bei der Erstbereitstellung kann der Stack gestoppt
werden; keine bestehenden Mac-Stacks oder Dienste werden dafuer entfernt.
Vor spaeteren Aenderungen an Datenbankschema oder Datenformat gesonderte
Backup-/Rollback-Pruefung vornehmen.

## Build-Werkzeuge und Lockfile

LiteLLM 1.21.1 wird aus dem fest gebundenen offiziellen GitHub-Quellcommit
bezogen, weil die alten PyPI-Dateien nicht mehr verfuegbar sind. Poetry prueft
und exportiert das Lockfile; pip installiert den vollstaendig gepinnten Export
mit `--no-deps`, damit keine Laufzeitversionen neu aufgeloest werden.
Dieser unterstuetzte Exportweg sorgt dafuer, dass `PIP_CONSTRAINT` auch bei
isolierten Legacy-Paketbuilds greift. Poetry 1.8s eigener Build-Installer
uebernimmt diese pip-Einstellung nicht. Es werden keine Bibliotheken gepatcht.
Der Export enthaelt wegen der Git-Quellen keine pip-Hashpflicht; Versions- und
Quellcommit-Pins bleiben erhalten. Dies ist kein Nachweis fuer Bytegleichheit
mit den inzwischen entfernten LiteLLM-Distributionsdateien.
