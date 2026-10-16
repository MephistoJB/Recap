# Freigabevorschlag: deutsche Server-Transkription

Stand: 2026-10-16. Bezug: Phase 2, Befunde F08 und F09.

Status: **Vom Nutzer am 2026-10-16 freigegeben und lokal angewendet.**
Der Nutzer hat zusaetzlich Dockerisierung, GitHub-Image-Release und Einrichtung
auf macserver beauftragt; die Bereitstellung soll ueber Komodo erfolgen.

Der konkrete Diff steht in [server-transkription.patch](server-transkription.patch).

## Umfang

1. `owl/services/stt/asynchronous/async_whisper/async_whisper_transcription_server.py`:
   HF-Token aus dem Startlog entfernen. Alignment-Modell erst nach Transkription
   passend zur erkannten Sprache laden; zuletzt verwendetes Modell wiederverwenden.
   Der fest eingebaute englische Alignment-Start entfällt.
2. `owl/services/stt/asynchronous/async_deepgram_transcription_service.py`:
   vorhandene Einstellung `deepgram.language` an den Dateitranskriptions-Aufruf
   weiterreichen. Kein neuer Anbieter und kein Anbieterwechsel.

## Optionen und Empfehlung

Nur das Token-Logging zu entfernen ist kleiner, laesst aber die beiden
Sprachfehler bestehen. Empfohlen ist das gemeinsame Paket oben: vorhandene
Transkriptionswege korrigieren, bevor ein deutscher Backend-Test stattfindet.
Eine neue Transkriptionsintegration oder ein zusaetzlicher Dienst ist dafuer
nicht erforderlich und nicht Teil dieser Freigabe.

## Risiken und Updatefolgen

- Erstes Alignment einer Sprache kann Modelldownload und hoehere Latenz ausloesen.
  Downloadfehler oder nicht unterstuetzte Sprachen bleiben Verarbeitungsfehler;
  es wird nicht still auf englisches Alignment ausgewichen.
- Sprachwechsel laden das jeweilige Alignment-Modell neu; kein unbegrenzter
  Cache fuer alle Sprachen. Beim Austausch kann kurzzeitig zusaetzlicher
  Modellspeicher benoetigt werden.
- Die automatische Spracherkennung bleibt eine moegliche Fehlerquelle.
- Deepgram beachtet danach die konfigurierte Sprache. Eine falsch gesetzte
  Sprache wirkt sich somit auch auf Dateiaufnahmen aus.
- Zwei lokale Fork-Aenderungen muessen bei Upstream-Updates abgeglichen werden.
  Abhaengigkeitsversionen, Datenbankschema und vorhandene Audiodaten bleiben
  durch diesen Patch unveraendert.

## Verifikation

Erledigt: Syntaxpruefung, `git apply --check`, Anwendung des freigegebenen
Diffs und fuenf erfolgreiche gezielte Unit-Tests ohne Modell-/API-Zugriffe.

Die Unit-Tests pruefen Token-Abwesenheit im Log, deutsches/englisches
Alignment, Wiederverwendung und Modellwechsel, fehlgeschlagenes Modellladen
und Weitergabe der Deepgram-Sprache. SDK-/Modellaufrufe im Unit-Test ersetzen;
keine echten Secrets oder kostenpflichtigen API-Aufrufe dafuer verwenden.
Ein echter deutscher Audio-Test folgt nach Freigabe von Laufzeit/Betriebsort
und Provider-Konfiguration. Mock-Tests ersetzen diese Abnahme nicht.

Die Sprachkennung im WhisperX-Ergebnis wurde gegen den im Lockfile gebundenen
[WhisperX-Quellstand](https://github.com/m-bain/whisperX/blob/78dcfaab51005aa703ee21375f81ed31bc248560/whisperx/asr.py)
geprueft.

## Rollback und Grenze

Rollback: ausschliesslich den freigegebenen Diff rueckwaerts anwenden, nach
Pruefung auf zwischenzeitliche Aenderungen. Kein pauschales Git-Reset. Das
wuerde auch das unsichere Token-Logging wiederherstellen; daher vor Neustart
die Logkorrektur beibehalten oder Whisper bis zur Korrektur nicht starten.

Diese Freigabe betrifft die lokale Entwicklung samt gezielten Tests. Installation,
Deployment, Infrastruktur, Queue-Persistenz, Hindsight-Integration und Aenderungen
an Watch-/iPhone-Dateien sind eigene nachfolgende Schritte.
