# Freigabeentscheidung: reproduzierbarer Docker-Build

Stand: 2026-10-17. Vom Nutzer freigegeben und umgesetzt. Der native ARM64-Build inklusive
Image-Smoke-Tests ist erfolgreich; siehe [Betriebsstand](../../deploy/README.md).

Bisheriger Commit: `8da5bab92de56d11ae845c6e258008aca4a4009e`.

## Verifizierter Blocker

Der erste [GitHub-Build](https://github.com/MephistoJB/Owl/actions/runs/38980864407)
endet bei `poetry install`. Die fuenf Unit-Tests waren erfolgreich.

1. `litellm==1.21.1` aus dem vorhandenen Lockfile ist nicht mehr auf PyPI
   verfuegbar: Version-API HTTP 404, kein Releaseeintrag in der aktuellen
   Paketliste. Die alten Lockfile-Hashes koennen dort nicht mehr bezogen werden.
2. Ein Legacy-Paketbuild scheitert mit `ModuleNotFoundError: pkg_resources`:
   die isolierte Build-Umgebung verwendet neuere Build-Werkzeuge als das alte
   Projekt erwartet. Paketquellen wurden nicht gepatcht.

## Optionen

- **Empfehlung:** LiteLLM bei Version 1.21.1 belassen, aber den offiziellen
  GitHub-Quellstand des Tags `v1.21.1` fest an Commit
  `5fc6081b60d04c789cad96bb237ddf87f9f708c4` binden. Dessen `pyproject.toml`
  bestaetigt Version 1.21.1 und die bisherigen direkten Abhaengigkeiten.
  Zusaetzlich passende Build-Werkzeuge pinnen. Dies ist ein Wechsel der
  Paketquelle und benoetigt gemaess Projektvorgaben ausdrueckliche Freigabe.
- Alternativ LiteLLM und betroffene Abhaengigkeiten auf einen verfuegbaren
  neueren Stand aktualisieren. Das ist breiter und verlangt eine neue
  Kompatibilitaetspruefung der LLM-Anbindung.
- Beim alten Lockfile bleiben: kein Image veroeffentlichen und Bereitstellung
  bis zur Verfuegbarkeit der urspruenglichen Distributionen anhalten.

## Exakter empfohlener Aenderungsumfang

- `pyproject.toml`: LiteLLM-Quelle auf
  `litellm = {git = "https://github.com/BerriAI/litellm.git", rev = "5fc6081b60d04c789cad96bb237ddf87f9f708c4"}`
  festlegen.
- `poetry.lock`: nur den LiteLLM-Eintrag auf diese Quelle umstellen und den
  Projekthash aktualisieren; andere Laufzeitversionen erhalten. Validierung
  durch Poetry und den folgenden echten Image-Build.
- `deploy/build-constraints.txt` neu: `setuptools==69.0.3` und
  `poetry-core==1.9.1` fuer die Legacy-Builds pinnen.
- `Dockerfile`: Constraint-Datei vor Paketinstallation kopieren und mit
  `PIP_CONSTRAINT` an die isolierten Paketbuilds weitergeben. Dafuer das
  gepruefte Poetry-Lockfile exportieren und mit pip `--no-deps` installieren;
  Poetry 1.8s eigener Build-Installer ignoriert pip-Constraints.

Kein Patch an LiteLLM, WhisperX oder installierten Bibliotheksdateien;
kein zusaetzlicher Dienst. Falls weitere Laufzeit- oder Sourcecode-Aenderungen
noetig werden, werden diese separat eingegrenzt.

## Wirkung, Risiken, Updates und Rollback

Die PyPI-Distribution wird durch einen Build aus dem offiziellen Quellcommit
ersetzt. Gleiche Versionsnummer bedeutet keine nachgewiesene Bytegleichheit
mit den alten Distributionsdateien. GitHub-Erreichbarkeit wird zusaetzliche
Build-Voraussetzung. Die festen Pins brauchen bei spaeteren Updates Pflege.
Ein breit aufgeloestes Abhaengigkeitsupgrade wird vermieden.

Verifikation: Unit-Tests, Poetry-Lockpruefung, nativer ARM64-Image-Build,
CLI-/Server-Importtest und anschliessend Modell-/API-Smoke-Test, sobald der
HF-Zugang vorliegt. Erst nach erfolgreichem Image-Test veroeffentlichen.

Rollback: nur diesen abgegrenzten Commit rueckgaengig machen. Es gibt bisher
kein erfolgreich veroeffentlichtes Owl-Image und keine Owl-Nutzerdaten, die
migriert werden muessten. Der Komodo-Stack ist angelegt, aber nicht deployt.

## Weiterer fehlender Zugang

Fuer die vorhandene Sprechererkennung fehlt der HF-Token in Psono sowie die
Bestaetigung der Modellfreigaben. Der API-Client-Token ist separat in Psono
unter `OWL_USER_CLIENT_TOKEN` angelegt und als geheime Komodo-Variable
`OWL_CLIENT_TOKEN` hinterlegt. Keine Secret-Werte in dieser Dokumentation.

## Aktueller Bereitstellungsstand

- GitHub-Workflow angelegt; erster Lauf nach manueller Ausloesung ausgefuehrt.
- Komodo-Stack `owl`, ID `6ad2b0f3c3b21f6d142d12cc`, Server `Macserver`.
- Hostport 8012 bei Pruefung frei.
- Nicht geheime Konfiguration auf macserver unter
  `/Users/johnsmacminiserver/.config/komodo/stacks/owl/config/config.yaml`.
- Docker-/OrbStack-Laufzeit erreichbar; Komodo-Containerliste funktioniert.
  Komodo-Server-Terminal ist auf diesem Host nicht verfuegbar. Die notwendige
  Hostdatei-Vorbereitung erfolgte deshalb per SSH; Stackverwaltung erfolgt
  ueber Komodo.
