# Native Owl-App: Umsetzungsstand

Stand: 2026-10-17. Der Nutzer hat die vollstaendige Swift-App beauftragt und
SwiftData sowie Hummingbird ausdruecklich freigegeben.

## Implementiert

Unter [`clients/macos/`](../clients/macos/README.md) liegt eine eigenstaendige
SwiftUI-App mit gemeinsamem nativem Kern. Sie verwendet zur Laufzeit weder
Python noch Docker und startet keinen separaten Transkriptionsdienst.

- Bibliothek mit Suche, editierbarem Titel, Status und Aufnahmezeit.
- Import vorhandener Audiodateien, Mikrofonaufnahme mit Berechtigungsabfrage,
  Wiedergabe/Pause und Sprung zu Transkript-Zeitmarken.
- FluidAudio mit lokalem Parakeet-v3-INT8-v2-Modell und Offline-Diarizer.
  Woerter werden nur bei eindeutiger zeitlicher Ueberlappung einem Sprecher
  zugeordnet. Ueberlappungen und Luecken bleiben unbekannt.
- Referenzaufnahme, Aehnlichkeitswerte und manuelle Sprecherbenennung.
  Keine ungetestete automatische Identitaetsentscheidung.
- Native Modellbereitstellung mit festen Revisionen und Dateihash-Pruefung;
  Wiederverwendung der geprueften Dateien aus dem bisherigen Experiment.
- SwiftData fuer Metadaten, Transkripte, Chunk-Identitaeten und Auftragszustaende;
  Originalaudio und einzelne Chunks bleiben auf dem lokalen Dateisystem.
- Dauerhafte Verarbeitung mit Wiederanlauf nach App-Neustart und sichtbaren
  Fehlern. Eine neue Transkription speichert zuerst das Ergebnis, bevor eine
  Zusammenfassung ueberhaupt angefordert werden muss.
- Eingebetteter, per Schalter aktivierter Hummingbird-Empfaenger fuer die
  vorhandenen HTTP-Chunk-, Abschluss-, Standort- und Gespraechs-APIs.
  Authentifizierung, numerische Chunk-Reihenfolge, Duplikatpruefung und
  Ablehnung von Upload-Luecken beziehungsweise widerspruechlichen Wiederholungen.
- Bearer-Token im macOS-Schluesselbund; kein Token im Quellcode.
- Optionale Zusammenfassungen ueber konfiguriertes Ollama, auf Nutzeraktion.
- Text-/JSON-Export mit Gespraechs-ID, Version und Herkunft. Rohe
  Sprecher-Embeddings werden nicht in den Gespraechsexport uebernommen.
- App-Bundle mit bestehendem Owl-Icon, Ressourcen, Lizenztexten und gepruefter
  lokaler Ad-hoc-Signatur. GitHub-Workflow fuer Tests und App-ZIP vorbereitet.

## Wiederverwendeter Owl-Vertrag

Grundlage sind `AudioFileWriter.swift`, `FileUploadTask.swift`, die bestehenden
iPhone-Modelle und Python-Routen. Die native Implementierung schreibt Chunks
zunaechst einzeln und setzt sie erst beim Abschluss zusammen. Das behebt
serverseitig die Abhaengigkeit von der Upload-Reihenfolge und den alten
rein fluechtigen Verarbeitungszustand.

Die alten Quellen wurden nicht in-place ersetzt. Die neue App ist ein
paralleler nativer Produktstand, auf den die vorhandenen Clients konfiguriert
werden koennen. Der Python-Server und der vorbereitete Komodo-Stack wurden
fuer diese Umsetzung weder gestartet noch geloescht.

## Verifikation auf macserver

M4 Pro, 24 GB RAM, macOS 27.0, Swift 6.4, ARM64-Release-Build.

- Acht native Tests erfolgreich: persistente Duplikaterkennung nach erneutem
  Oeffnen, Konflikte, fehlende Chunks, numerischer Zusammenbau, wiederholter
  Abschluss, Wiederanlauf, nicht wiederverwendete Gespraechs-IDs,
  Sprecherunsicherheit, ungueltige Pfade/Zeitpunkte, binaeres Multipart und
  sichtbarer Bibliothekseintrag bei fehlgeschlagener Audio-Loeschung.
- HTTP-Integration mit 17 erfolgreichen Pruefpunkten: Anmeldung, originale
  Pfade einschliesslich abschliessendem Slash, Upload ausser Reihenfolge,
  Luecken/409, Wiederholungen, widerspruechliche Wiederholungen/409,
  dauerhafter Abschluss, exakte PCM-Rekonstruktion und Warteschlange nach
  Beenden/Neustart des Empfaengerprozesses.
- Die Originaldateien `Conversation.swift`, `Transcript.swift`, `Location.swift`
  und `JSONDecoder+Extensions.swift` wurden unveraendert mit einem kleinen
  temporaeren Decoder kompiliert. Sie dekodieren die native API-Antwort korrekt.
- Native Modellbereitstellung einschliesslich Hash-Verifikation erfolgreich.
  Modelle liegen im Anwendungsdatenordner, ausserhalb des App-Bundles.
- Das signierte App-Bundle wurde als GUI-Anwendung gestartet. Die App hat den
  zuvor ueber HTTP empfangenen und dauerhaft vorgemerkten Upload aus ihrer
  eigenen Warteschlange verarbeitet. Erneutes Oeffnen der Bibliothek bestaetigt
  `completed` mit 53 Woertern. Ein sichtbares App-Fenster wurde ueber dessen
  eigene Prozess-ID ermittelt. Die Fensteraufnahme scheiterte an der fehlenden
  Bildschirmfreigabe; eine visuelle Screenshot-Abnahme wird nicht behauptet.
- Danach wurde die isolierte App-Instanz beendet und die normale App ueber
  LaunchServices geoeffnet. Die normale Bibliothek enthaelt keine synthetischen
  Gespraeche; die lokalen Modelle sind bereits eingerichtet.

Die HTTP-Pruefung nutzte synthetisches deutsches Audio und einen nur im
Prozessspeicher erzeugten Testtoken. Daten liegen unter
`~/Library/Application Support/Owl/ImplementationChecks/`, getrennt von der
normalen Bibliothek. Die bisherigen FluidAudio-Messungen sind im
[Laufzeittest](FLUIDAUDIO-TESTERGEBNISSE.md) dokumentiert.

## Bewusste Grenzen und offene Abnahme

- Die zwei synthetischen Stimmen wurden im bisherigen Test zusammengefasst.
  Nutzerstimme und echte deutsche Mehrpersonengespraeche sind nicht abgenommen.
  Die App zeigt daher Referenzwerte und laesst Namen manuell zuordnen.
- Watch-/iPhone-Signierung, URL-/Token-Konfiguration und Geraeteinstallation
  bleiben offen. Der alte Client behandelt HTTP-Fehler teilweise als Erfolg;
  die Mac-App kann diese clientseitige Loeschlogik nicht reparieren.
- Das alte Upload-Protokoll uebermittelt keine erwartete letzte Chunknummer;
  Verlust nur des letzten Chunks laesst sich damit nicht sicher erkennen.
- Live-/Socket.IO-/BLE-Verarbeitung, automatische Gespraechssegmentierung
  und Bild-Uploads sind nicht portiert. Im freigegebenen ersten Ablauf wird
  nach Aufnahmeende verarbeitet; eine Aufnahme entspricht einem Gespraech.
- Ollama-Anbindung ist implementiert, ein produktiver Zusammenfassungslauf
  mit dem vorhandenen grossen Modell ist hier noch nicht als bestanden gemeldet.
- Keine automatische Hindsight-Schreibverbindung: Bank, Authority und
  Agentenabgleich sind noch offen. Der Quellenexport ist vorhanden.
- Kein notarisiertes Vertriebsrelease, keine Migration der Python-Owl-Datenbank,
  keine automatische Backup-/Aufbewahrungsregel und kein unbeaufsichtigter
  Betrieb ohne laufende App. Datenpfade und manueller Sicherungsweg stehen im README.
- Modell-Lizenz-/Herkunftsbefunde aus der Vorauswahl bleiben vor Vertrieb offen.

## Betriebsort und Rueckbau

App auf macserver:
`~/Library/Developer/Owl/Builds/Owl.app`.
Normale Bibliothek: `~/Library/Application Support/Owl/`.
Die App ist zunaechst lokal gebaut; der neue GitHub-Workflow wird erst nach
seinem tatsaechlichen Lauf als CI-verifiziert bezeichnet.

Erster erfolgreicher GitHub-Lauf: [Native Mac app, 39058498168](https://github.com/MephistoJB/Owl/actions/runs/39058498168),
Code-Stand `229e064`. Tests, App-Build, Signaturpruefung und ZIP-Upload sind dort
erfolgreich. Die anschliessenden Korrekturen `0886060` wurden auf macserver mit
acht Tests und erneutem App-Build geprueft; ihr eigener
[GitHub-Lauf](https://github.com/MephistoJB/Owl/actions/runs/39059068429) zeigt den
jeweils aktuellen CI-Zustand.

Ausgeliefertes lokales ZIP: `clients/macos/artifacts/Owl-macOS-arm64.zip`,
10.565.190 Bytes. SHA256:
`e8a5435e09866263dde0684e5984eab7f5bd378e28b2ea305f727a33f719929f`.
Das ZIP ist ein lokaler Entwicklungsbuild, kein notarisiertes Vertriebsrelease.

Rueckbau: App beenden, erzeugtes App-Bundle entfernen und neue Bibliothek
separat sichern/erhalten. Bestehende iPhone-/Watch-Quellen und Python-Daten
bleiben nutzbar. Keine Fremdsoftware wurde gepatcht und keine bestehende
Infrastruktur dafuer deaktiviert.

## Recap-Rebranding

Das Projekt heisst seit 2026-10-17 Recap. Repository und Workflow liegen unter
https://github.com/MephistoJB/Recap. Der alte Fork wurde nach bereinigter
Uebertragung der Historie geloescht; oben verlinkte historische Actions-Laeufe
sind deshalb nicht mehr verfuegbar. Details: [Rebranding](REBRANDING.md).
Der Recap-Build und alle acht Swift-Tests wurden auf macserver erfolgreich
geprueft; Datenpfade und technische Kennungen bleiben erhalten.

Das Rebranding im Code ist ebenfalls umgesetzt: `RecapCore`, `RecapMac`,
`RecapDoctor` und `RecapCoreTests`; neues Icon gemaess freigegebenem Entwurf A.
Der Mac-Build mit diesen Modulnamen besteht alle acht Swift-Tests und liest die
bisherige Testbibliothek mit 53 Woertern. Das umbenannte iPhone-/Watch-Projekt
`clients/ios/Recap.xcodeproj` besteht den kombinierten Simulatorbuild.
