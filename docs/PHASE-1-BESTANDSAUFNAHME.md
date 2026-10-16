# Phase 1: Bestand und Aufnahmeweg

Stand: 2026-10-16. Gepruefte Owl-Quelle: `91922655c3cbf0e5f3282c22806b5ac0cf30063e`.

Die folgenden Befunde stammen aus der Quellenpruefung und einem unsignierten
Build auf dem macserver. Sie sind keine Abnahme auf echten Geraeten. Es wurden
keine Anwendungsdateien gepatcht oder produktiven Dienste veraendert. Der Build
hat die vorhandenen Swift-Package-Abhaengigkeiten auf dem Mac bezogen.

## Geraete und Build-Stand

- Nutzerangabe: „Ultra 12 und iPhone 12 Pro mit iOS 27 und aktuellster Xcode
  Version“. Watch-Modell und watchOS-Version sind noch eindeutig zu erfassen;
  „Ultra 12“ wird nicht als verifizierte Modellbezeichnung behandelt.
- Xcode auf dem macserver ist vom Nutzer fuer diese Aufgabe freigegeben.
  Per SSH verifiziert: macOS 27.0 (26A428), Xcode 27.0 (27A266a), aktiver
  Entwicklerpfad `/Applications/Xcode.app/Contents/Developer`.
  Nach Rueckmeldung des Nutzers ist die Lizenzblockade behoben:
  `xcodebuild -checkFirstLaunchStatus` und `-showsdks` funktionieren. SDKs fuer
  iOS 27.0 und watchOS 27.0 sowie die zugehoerigen Simulatoren sind vorhanden.
  Der Fork wurde nach `/Users/johnsmacminiserver/Documents/Programmierung/Owl`
  geklont; HEAD entspricht dem oben genannten Commit. Git-Status nach Build leer.
- `devicectl list devices` erkennt ein echtes, verfuegbares und gepaartes
  iPhone 12 Pro Max (`iPhone13,4`). Dies praezisiert die Nutzerangabe „Pro“.
  Eine echte Watch erscheint nicht in dieser Liste; die angezeigte Ultra 3 ist
  ein ausgeschalteter Simulator und kein Nachweis fuer das reale Watch-Modell.
  Der Schluesselbund meldet eine gueltige Code-Signing-Identitaet; passende
  Team-/Provisioning-Zuordnung wurde noch nicht geprueft.
- Die gepruefte Pi-Umgebung ist Linux ARM64 mit Python 3.13.5. `xcodebuild`,
  Swift, Poetry und FFmpeg sind nicht im aktiven PATH. Keine der in
  `pyproject.toml` aufgefuehrten Python-Distributionen wurde im aktiven
  Python gefunden. Das schliesst andere Installationen/Environments nicht aus.
- Das Xcode-Projekt verlangt iOS 17.2 und watchOS 10.2; Swift-Sprachmodus 5.
  Diese Mindestwerte belegen keine Kompatibilitaet mit den aktuellen Geraeten.
- Alle Targets enthalten das Upstream-Development-Team und Upstream-Bundle-IDs.
  Eigene Signierung, Provisioning und Developer Mode sind vor Installation
  zu pruefen. Der Server und sein Client-Token werden ueber
  `clients/ios/Shared/AppConstants.swift` konfiguriert. Keine echten Secrets
  in Git uebernehmen.
- Socket.IO wird im Xcode-Projekt vom Branch `master` bezogen. Aufgeloester
  Build-Stand: `socket.io-client-swift` bei
  `42da871d9369f290d6ec4930636c40672143905b`, Starscream 4.0.8 bei
  `c6bfd1af48efcc9a9ad203665db12375ba6b145a`. Das generierte `Package.resolved`
  liegt auf dem Mac unter dem ignorierten `project.xcworkspace/xcshareddata/swiftpm`.
- Das Backend verlangt laut Projekt Python ab 3.11. Der Lockfile bindet
  WhisperX 3.1.1 an Commit `78dcfaab51005aa703ee21375f81ed31bc248560`.
  Eine Aufloesung alter ML-Abhaengigkeiten auf Python 3.13/ARM64 wurde nicht
  getestet. Kein Lockfile-Refresh und kein Upgrade durchgefuehrt.
- `config.yaml` fehlt im Projektroot; die vorhandene Vorlage liegt unter
  `owl/sample_config.yaml` und ist zugleich der CLI-Default. Eine fehlende
  eigene Konfiguration ist daher kein nachgewiesener Startfehler; die Vorlage
  ist aber keine betriebsfertige Konfiguration.

## Tatsaechlicher Aufnahmeweg

Die Watch nimmt ueber `AVAudioEngine` auf und wandelt auf 16-kHz-Mono-PCM mit
16 Bit um. Im Dateimodus schreibt `AudioFileWriter` etwa alle 30 Sekunden einen
Chunk. Dateien tragen Capture-UUID, UTC-Startzeit und Chunknummer.

`FileUploadTask` sendet fertige Chunks direkt an `/capture/upload_chunk`.
Das Backend haengt sie an eine WAV-Datei an, erkennt Gespraechssegmente und
startet deren Verarbeitung. Nach Aufnahmeende dient eine `.end`-Datei auf
der Watch als Auftrag fuer `/capture/process_capture`.

WatchConnectivity uebermittelt Statusnachrichten an das iPhone. Eine
Audio-Dateiuebertragung mittels `transferFile` oder eine Hintergrund-Upload-
Session ist im geprueften Watch-Pfad nicht implementiert. Der Dateimodus ist
die vorhandene Grundlage fuer Offline-Aufnahmen. Live-Streaming speichert
auf der Watch keine Offline-Kopie.

## Befunde und Einordnung

| ID | Befund und Beleg | Einordnung und Konsequenz |
| --- | --- | --- |
| F01 | `Shared/Files/FileUploadTask.swift`: `uploadFile` liefert auch bei Nicht-2xx-Antworten `true`; die Schleife loescht danach den Chunk. `processCapture` bestaetigt ebenfalls HTTP-Fehler als Erfolg. | Kritischer Patchkandidat: moeglicher Audioverlust und Verlust des Abschlussauftrags, z.B. bei 401/500. Keine Einstellung zur Korrektur gefunden. |
| F02 | Dieselbe Datei: bei Start werden alle `pcm-wip`-Dateien geloescht. | Patchkandidat: letzter noch offener Chunk kann nach Absturz verloren gehen; Chunkrotation erfolgt nach etwa 30 Sekunden. Reale Verlustdauer messen. |
| F03 | `docs/apple_watch_setup.md`: Upload nur waehrend Aufnahme oder bei sichtbarer App. Implementierung verwendet `URLSession.shared`, keine Hintergrund-Dateiuebertragung. | Dokumentierte Plattform-/Implementierungsgrenze. Fuer den Diagnosetest App nach Stop im Vordergrund lassen; automatische Offline-Nachlieferung damit noch nicht abgenommen. |
| F04 | Watch-`CaptureManager.swift` behandelt keine Audio-Session-Unterbrechungen oder Engine-Konfigurationswechsel; Startfehler werden nur geloggt. `ContentView` setzt den Aufnahmestatus unabhaengig vom Starterfolg. | Patchkandidat; moegliche Abweichung zwischen Anzeige und Aufnahme. Anruf- und Displaytests auf echten Geraeten erforderlich. |
| F05 | `Owl-Watch-App-Info.plist` und die erzeugte Watch-App enthalten eine leere `UIBackgroundModes`-Liste; `WKBackgroundModes` ist im erzeugten Bundle nicht gesetzt. | Konfigurationskandidat, keine bestaetigte Laufzeitursache. Verhalten bei gesperrtem Display auf der echten Watch pruefen. |
| F06 | `owl/server/app_state.py`: Queue und Detektoren im RAM. `routes/capture.py` dokumentiert selbst den Zustandsverlust nach Neustart; Abschluss ohne Detektor scheitert. | Patch-/Persistenzentscheidung erforderlich. Start setzt laufende Gespraeche auf `FAILED_PROCESSING`; keine automatische Wiederaufnahme der Queue gefunden. |
| F07 | `routes/capture.py`: Upload haengt Inhalt an die Audiodatei an; keine persistente Deduplizierung nach Chunknummer gefunden. | Patchkandidat: erneuter Upload nach verlorener HTTP-Antwort kann Audio duplizieren. Reihenfolge auf der Watch allein verhindert das nicht. |
| F08 | `async_whisper/async_whisper_transcription_server.py`: HF-Token wird beim Modellladen geloggt; Alignment-Sprache fest `en`. | Bestaetigte Patchkandidaten. Whisper-Pfad vor Nutzung mit echtem HF-Token korrigieren lassen; deutsche Alignment-Qualitaet derzeit nicht abgesichert. |
| F09 | `async_deepgram_transcription_service.py`: `PrerecordedOptions` uebernimmt `config.language` nicht. | Eine reine Aenderung von `deepgram.language` garantiert fuer den Watch-Dateipfad keine deutsche Transkription. Patchkandidat; kein Providerwechsel beschlossen. |
| F10 | `conversation_service.py`: zwei LLM-Zusammenfassungen laufen vor Persistierung des finalen Transkripts und `COMPLETED`. | Planpraezisierung: Zusammenfassungen sind fachlich optional, im aktuellen Ablauf aber verpflichtend. Ausfall des LLM kann den Gespraechsabschluss verhindern. Entkopplung waere freigabepflichtiger Patch. |
| F11 | `tests/test_whisper_transcription_service.py` importiert den nicht vorhandenen Pfad `owl.services.transcription.whisper_transcription_service`. | Bestehender Test passt nicht zur Quellstruktur. Keine belastbare Regressionstest-Abdeckung des Watch-Dateipfads vorhanden. |

## Hindsight und Agentenbestand

Die lokalen Nexus-Dokumente und ADR-009 beschreiben den Stand vom 2026-09-23:
Hermes, Hindsight 0.10.0, Bank `hermes-primary-v2`, API lokal auf dem Hermes Pi
an Port 8888. Dies ist kein aktueller Laufzeitnachweis.

Psono ist registriert und ueber seinen konfigurierten MCP-Endpunkt erreichbar;
`list_keys` wurde erfolgreich ausgefuehrt. Die Schluesselnamen enthalten auch
Hinweise auf eine spaetere Hermes/OpenClaw-Migration und OpenClaw-Hindsight-
Konfiguration. Namen allein belegen weder einen abgeschlossenen Wechsel noch
Version, aktive Bank oder API-Semantik. Die alte ADR darf deshalb nicht ohne
Live-Abgleich als heutiger Ist-Zustand verwendet werden.

Offen sind eine rein lesende Pruefung der laufenden Agenten-/Memory-Konfiguration,
Hindsight-Version, Health und installierten OpenAPI-Spezifikation. Zu pruefen:
`document_id`, Wiederholung/Ersetzen/Append, Auftragsstatus, Loeschung,
Mental-Model-Refresh und Zeitsteuerung. Keine Test-Retains in die produktive Bank.
Host-Kommandos ausserhalb der DietPi-Werkzeuge brauchen die vorgegebene Freigabe.

## Kleinster erster Testumfang

1. Erledigt: Mac-Arbeitskopie, SDK-Pruefung und unsignierter Build inklusive
   Watch-App/Erweiterung. Offen: richtige Team-/Provisioning-Zuordnung, Erkennung
   der echten Watch und konkrete Installation auf die Testgeraete.
2. Vor Backend-Bereitstellung Betriebsort und STT-/LLM-Anbindung abstimmen.
   Weder diese Wahl noch zusaetzliche Container sind durch diesen Bericht freigegeben.
3. F01 und F08 vor einem Test mit wertvollen Aufnahmen beziehungsweise echtem
   HF-Token zur Patchfreigabe vorlegen. Fuer einen aussagekraeftigen deutschen
   Test ist ausserdem F08 oder F09 je nach freigegebenem Provider zu loesen.
4. Zunaechst kurze deutsche Testaufnahme im Dateimodus, danach etwa 30 Minuten.
   Bei Stop fuer den Diagnosetest die Watch-App sichtbar lassen. Aufnahmebeginn,
   Ende, lokale Restdateien, Capture-/Gespraechs-IDs, WAV-Dauer und Transkript
   vergleichen; die Aufnahme kann mehrere Gespraechssegmente ergeben.
5. Gesperrtes Display, Offline-Aufnahme mit spaeterem Upload, Anrufunterbrechung,
   App-Abbruch sowie Backend-Neustart getrennt pruefen. Auch HTTP-Fehler und
   Wiederholung nach verlorener Antwort gezielt mit Testaudio untersuchen.

Pro Test festhalten: Commit, Build, OS-Versionen, Netzweg, Start/Stop in UTC,
erwartete und beobachtete Audiodauer, Segment-IDs, Restdateien, Fehlerstatus
und Ergebnis. Offen gebliebene oder verlorene Teile duerfen nicht als
erfolgreicher Abschluss gewertet werden.

## Bisherige Verifikation

Alle Python-Dateien unter `owl/` wurden ohne Importieren der Anwendung per AST
auf lesbare Python-Syntax geprueft. Projektvorgaben, Upload-, Aufnahme-,
Verarbeitungs- und Konfigurationspfade wurden statisch verglichen.
Backend-Laufzeittests und Hardware-Abnahme sind noch offen.
Erfolgreicher Build auf dem macserver am 2026-10-16, etwa 22:08 UTC:

```sh
cd /Users/johnsmacminiserver/Documents/Programmierung/Owl
xcodebuild -project clients/ios/Owl.xcodeproj -scheme Owl \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/owl-phase1-derived-20261016 \
  CODE_SIGNING_ALLOWED=NO build
```

Ergebnis: Exit 0, `BUILD SUCCEEDED`, einschliesslich eingebetteter Watch-App und
Watch-Erweiterung. Build-Log auf dem Mac:
`/tmp/owl-phase1-ios-build-20261016.log`. Produkte liegen in
`/tmp/owl-phase1-derived-20261016/Build/Products/Debug-iphoneos` und `Debug-watchos`.
Die temporaeren Artefakte sind nicht als dauerhaftes Releasearchiv vorgesehen.

Warnungen betreffen fehlenden expliziten Combine-Import in `ConversationsView`,
veraltete Map-/onChange-APIs und Sendable-Zugriffe in `LinkMetadataView`;
keine Compile-Fehler. AppIntents-Metadaten wurden mangels Framework uebersprungen.
Kein Warnungs-Patch vorgenommen.

Die erzeugten Plists bestaetigen iOS 17.2/watchOS 10.2 als Mindestversionen,
leere Watch-Hintergrundmodi und eine Watch-Mikrofonbeschreibung. Die iPhone-App
enthaelt keine Mikrofonbeschreibung; eine Mikrofonaufnahme auf dem iPhone ist
damit nicht abgenommen. `AppConstants` enthaelt weiterhin leere Server-/Tokenwerte.
Die unsignierten Apps wurden weder installiert noch gestartet; dieser Build
bestaetigt keine Aufnahme-, Netzwerk- oder Hintergrundfunktion auf echten Geraeten.
