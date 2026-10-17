# Recap fuer macOS

Native SwiftUI-App fuer Apple-Silicon-Macs. Audio, Bibliothek, Verarbeitung und
Upload-Empfang laufen innerhalb der App; Python und Docker sind dafuer nicht
erforderlich. macOS 14+ ist das Build-Ziel; die lokale Abnahme erfolgt auf
macOS 27 / M4 Pro / Swift 6.4. Andere OS-/Hardwarestaende sind nicht abgenommen.

## Benutzen

1. `~/Library/Developer/Recap/Builds/Recap.app` oeffnen oder das erzeugte ZIP auspacken.
2. In den Einstellungen unter **Audio** die lokalen Modelle einrichten.
   Bereits gepruefte Dateien aus dem bisherigen Experiment werden nach
   Hash-Pruefung uebernommen. Fehlende Modelle werden anonym von Hugging Face
   geladen (rund 654 MB). Keine Audiodatei wird dabei hochgeladen.
3. **Audio importieren** oder **Aufnehmen** waehlen. Ein Import bleibt als
   Originaldatei erhalten; der Zeitpunkt ist zunaechst der Importzeitpunkt
   und kann im Detail korrigiert werden.
4. Die App verarbeitet ausstehende Aufnahmen nacheinander. Nach einem Neustart
   werden unterbrochene Verarbeitungen erneut gestartet. Empfangene Watch-
   Aufnahmen warten auf das ausdrueckliche Abschlusskommando des Clients.
5. Im Transkript startet ein Klick auf die Zeitmarke die Audiowiedergabe dort.
   Namen unter **Sprecher und Referenzvergleich** selbst zuordnen. Optional
   eine Referenz nur der eigenen Stimme hinterlegen. Aehnlichkeiten sind
   noch keine bestaetigten Identitaeten; es gibt keine automatische Namensvergabe.

Bei einer erneuten Transkription werden Sprecherzuordnungen und die alte
Zusammenfassung zurueckgesetzt, weil Cluster-IDs und Text sich aendern koennen.
Die vorigen Ergebnisse bleiben erhalten, falls ein neuer Lauf fehlschlaegt.

## Watch und iPhone verbinden

In **Einstellungen → Verbindung** Token erzeugen beziehungsweise den fuer
deine Clients vorgesehenen Token eintragen, Port einstellen und **Empfang
starten**. Default: `0.0.0.0:8012`. Die App startet den Empfaenger nicht
unbemerkt beim Oeffnen. Token werden im macOS-Schluesselbund gespeichert.

Bestehende Clients muessen die Mac-Adresse und denselben Bearer-Token verwenden.
Der bisherige iOS-/Watch-Code konfiguriert dies in
`clients/ios/Shared/AppConstants.swift`. Eine neue Geraeteinstallation mit
Signierung/Provisionierung ist nicht Teil des macOS-Builds. Die Original-
Client-Dateien wurden fuer diesen App-Stand nicht gepatcht.

Unterstuetzte Owl-HTTP-Schnittstellen:

| Methode und Pfad | Verhalten |
| --- | --- |
| `GET /health` | Einfacher Erreichbarkeitstest ohne Inhalte |
| `GET /` | Authentifizierter App-Status |
| `POST /capture/upload_chunk` | Owl-Multipart: `file`, `capture_uuid`, `timestamp`, `device_type` |
| `POST /capture/process_capture` | Multipart-Abschluss mit `capture_uuid` |
| `POST /capture/location` | Standort zur vorhandenen Capture-ID speichern |
| `GET /conversations/` | Gespraechsliste im bisherigen iPhone-Antwortformat, derzeit die neuesten 100 |
| `GET /conversations/{id}` | Einzelnes Gespraech |
| `POST /conversations/{id}/retry` | Gespeichertes Audio erneut verarbeiten |
| `DELETE /conversations/{id}` | Inaktive Aufnahme und lokale Dateien loeschen |

Die Audioschnittstellen verlangen einen Bearer-Token. HTTP ist fuer das
vertrauenswuerdige lokale Netz vorgesehen; TLS/Public-Hosting wird nicht
automatisch eingerichtet. macOS kann eine Freigabe fuer das lokale Netz und
fuer eingehende Verbindungen verlangen. Fuer Mikrofonaufnahmen die
Mikrofonberechtigung der App erlauben.

Chunkdateien folgen dem vorhandenen Muster
`audio_<32-hex-UUID>_<yyyyMMdd-HHmmss.SSS>_<Nummer>.pcm|wav|aac`.
PCM bedeutet 16 kHz, mono, signed 16-bit little endian. Ein Chunk ist maximal
32 MiB gross. Identische Wiederholungen sind idempotent; abweichende
Wiederholungen liefern 409. Empfang wird erst nach Dateisynchronisation und
Metadaten-Commit bestaetigt. Zusammensetzen erfolgt numerisch, nicht nach
Ankunftsreihenfolge. Luecken zwischen Chunk 0 und der letzten vorhandenen
Nummer verhindern den Abschluss.

Der alte Client liefert keine erwartete letzte Chunknummer. Ein fehlender
letzter Chunk laesst sich daher durch dieses Protokoll allein nicht erkennen.
Zudem behandelt der bisherige Client HTTP-Fehler teilweise als Erfolg und
loescht lokale Dateien. Der native Empfaenger beseitigt diesen Clientfehler
nicht. Socket.IO/BLE-Livestreaming, automatische Gespraechssegmentierung und
Bild-Uploads sind in diesem Stand nicht portiert; die freigegebene erste
Verarbeitung erfolgt nach Aufnahmeende, eine Aufnahme entspricht einem Gespraech.

## Daten, Zusammenfassungen und Hindsight

Default: `~/Library/Application Support/Owl/`.

- `Library.store*`: SwiftData-Metadaten, Transkripte und Auftragszustaende.
- `Audio/`: Originalimporte, Mikrofonaufnahmen und zusammengesetzte Uploads.
- `Chunks/`: persistente Einzelteile und Grundlage fuer Wiederholungspruefung.
- `Models/`: festgelegte Modelle, Herkunftshinweise und SHA256-Manifest.
- `Reference.wav`: normalisierte, lokal gespeicherte Referenzstimme.

Den gesamten Datenordner bei geschlossener App sichern. Loeschen einer
Aufnahme entfernt deren Original und Chunks. Es gibt noch keine automatische
Aufbewahrungsregel, keinen Papierkorb und keine Migration einer alten
Python-Owl-SQLite-Datenbank. Fuer Importe kann vorhandenes Owl-Audio verwendet werden.

Optional konfiguriertes Ollama liefert auf Klick Zusammenfassungen. Dabei
wird das Transkript an die eingestellte URL gesendet. Standard ist das
vorhandene lokale Ollama mit `qwen3-vl:30b-a3b-instruct-q4_K_M`. Ausfaelle
blockieren die Transkriptspeicherung nicht.

Text-/JSON-Export ist in der Detailansicht vorhanden. JSON enthaelt stabile
Gespraechs-ID, Version, Aufnahmezeit, Zeitzone, Unsicherheit des Zeitpunkts,
Herkunft, relativen Originalverweis, Textzeiten und manuelle Sprecherzuordnung.
Rohe Stimmen-Embeddings werden dabei nicht exportiert. Die Zeitzone stammt
vom Mac bei Anlage des Eintrags; der alte Upload liefert keine Watch-Zeitzone.
Eine produktive Hindsight-Bank beziehungsweise Agenten-Authority wird nicht
automatisch gewaehlt. Der Export bereitet die spaetere freizugebende Anbindung vor.

## Bauen und pruefen

```bash
cd clients/macos
xcrun swift test -c release
bash build-app.sh
open "$HOME/Library/Developer/Recap/Builds/Recap.app"
```

Das Build-Skript erstellt das originale Owl-Icon, uebernimmt SwiftPM-Ressourcen
und Lizenztexte, signiert ad hoc und prueft die Signatur. Paketierung/Signierung
erfolgt ausserhalb von iCloud Documents. Das gepruefte Bundle liegt unter
`~/Library/Developer/Recap/Builds/Recap.app`, sein ZIP unter
`artifacts/Recap-macOS-arm64.zip`. `artifacts/app-path.txt` enthaelt den Bundle-Pfad.
Es wird keine Anwendung in `/Applications` ersetzt.
Der lokale Entwicklungsbuild ist nicht Developer-ID-signiert oder notarisiert.
Der GitHub-Workflow `macos-app.yml` baut und testet dasselbe Paket und stellt
ein App-ZIP als Actions-Artefakt bereit; er enthaelt keine Apple-Zertifikate.

`OwlDoctor` ist ein separates Entwicklungswerkzeug, kein erforderlicher
Laufzeitprozess der App:

```bash
xcrun swift build -c release --product OwlDoctor
.build/release/OwlDoctor install "/absoluter/datenordner"
.build/release/OwlDoctor process "/absoluter/datenordner" "/aufnahme.wav"
.build/release/OwlDoctor inspect "/absoluter/datenordner"
```

`serve ROOT PORT` stellt die HTTP-Schnittstelle fuer Integrationstests nur auf
Loopback bereit und liest einen nur im Prozess gesetzten `OWL_API_TOKEN`.
Der Tool-Modus verarbeitet die Warteschlange nicht selbst. Die normale App
uebernimmt Verarbeitung, Bedienung und Empfang gemeinsam. `OWL_DATA_DIR`
erlaubt fuer App-Pruefungen eine isolierte Bibliothek; normale Starts verwenden
den Default-Ordner.

## Herkunft und weitere Abnahme

Owl-Datenfelder, Zustandsnamen, Upload-Vertraege und Icon stammen aus dem
vorhandenen MIT-lizenzierten Owl-Projekt. Native Implementierung liegt in
`Sources/OwlCore/` und `Sources/OwlMac/`; bisherige Clients/Backend bleiben erhalten.
Die SwiftPM-Pakete sind exakt beziehungsweise ueber `Package.resolved` fixiert.
Modellrevisionen entsprechen der freigegebenen FluidAudio-Pruefung. SwiftPM
kann das optionale NeMo-Artefakt trotz abgewaehltem Trait herunterladen.
Modell-Lizenz-/Herkunftshinweise bleiben vor oeffentlichem Vertrieb zu klaeren.

[Umsetzungsstand und Pruefung](../../docs/MACOS-APP-UMSETZUNGSSTAND.md).
Eine native App ersetzt keinen echten Watch-/iPhone-Geraetetest und keine
Qualitaetsabnahme der Sprechererkennung. Der vorbereitete Komodo-Stack bleibt
erhalten und wird fuer diesen nativen Stand nicht gestartet.
