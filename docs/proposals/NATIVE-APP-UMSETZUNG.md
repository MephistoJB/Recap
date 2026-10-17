# Native Owl-App: Umsetzungspaket

Stand: 2026-10-17. Der Nutzer beauftragt den Wechsel vom Experiment zur
vollstaendigen Swift-App. Arbeitsort: `clients/macos/`. Die bisherigen
Python-/iOS-/Watch-Quellen dienen als Referenz und bleiben vorerst erhalten.

## Vorgeschlagene Architektur

- SwiftUI-App fuer macOS 14+, mit Bibliothek, Suche, Transkriptdetail,
  Wiedergabe mit Zeitmarken, Import und Mikrofonaufnahme, Modellverwaltung,
  Sprecherreferenz und Einstellungen.
- FluidAudio 0.17.7 mit den geprueften lokalen Modell-Snapshots als erste
  implementierte Engine. Text, Diarisierung und Referenzvergleich bleiben
  getrennte Schritte; unsichere Sprecherzuordnungen bleiben unbenannt.
- SwiftData fuer lokale Metadaten und dauerhafte Verarbeitungszustaende.
  Audio/Modelle als Dateien unter Application Support/Owl. Keine Cloud-Datenbank.
- Hummingbird 2 als in die App eingebetteter HTTP-Empfaenger fuer die
  vorhandenen Chunk-Upload-/Abschluss- und Gespraechs-APIs. Kein weiterer
  Dienstprozess. Alternative: eigener HTTP-Parser auf Network.framework;
  mehr Protokoll-/Sicherheitscode und Pflege, daher nicht empfohlen.
- API im Auslieferungszustand aus. Nutzer startet Empfang in der App;
  Bearer-Token im Schluesselbund, Authentifizierung vor Audioannahme.
  Vorhandene Client-URL und Token muessen zum Mac-Empfaenger passen.
- Erst bestaetigen, wenn Chunks dauerhaft gespeichert sind. Doppelte identische
  Chunks erkennen, widerspruechliche Wiederholungen ablehnen, numerisch ordnen
  und Luecken beim Abschluss erkennen. Ausstehende Arbeit nach Neustart fortsetzen.
- Optional vorhandenes Ollama fuer Zusammenfassungen per konfigurierter URL
  nutzen. Transkripte werden unabhaengig von Zusammenfassungen gespeichert.
- Hindsight: quellengebundener Export vorbereiten. Produktive Bank/Authority
  und Hermes/OpenClaw bleiben gemaess Entwicklungsplan vor Schreibzugriff zu klaeren.

## Dateien und Grenzen

Neue Dateien unter `clients/macos/`: `Package.swift`, `Sources/OwlCore/`
(Modelle, Audio/Engine, persistente Verarbeitung, API), `Sources/OwlMac/`
(SwiftUI-App), `Tests/`, `Resources/Info.plist`, Build-/Paketierungsskript
und README. Dokumentation im bestehenden `docs/` aktualisieren.
Keine Quellcode-Patches in installierten Fremdprogrammen oder FluidAudio.
Der aktuelle Komodo-Stack wird weder gestartet noch entfernt.

Risiken: Modellqualitaet bei aehnlichen Stimmen, neue HTTP-Abhaengigkeiten,
lokales Datenschema, macOS-Berechtigungen fuer Mikrofon/LAN sowie Code-Signing
und notarisierten Vertrieb. Ein lokaler Entwicklungsbuild ersetzt keine
Vertriebsnotarisierung. Betrieb endet mit der App; Start bei Anmeldung wird
nur als explizite App-Einstellung vorbereitet, kein stiller Daemon.

Updates: Paket-/Modellstaende fixieren; Datenmigration bei Schemaaenderungen
testen. Rueckbau: neue App beenden und nur neue Build-Artefakte entfernen;
Anwendungsdaten separat sichern/erhalten. Vorhandenes Owl bleibt wieder nutzbar.

Pruefung: nativer Release-Build, Tests fuer Chunk-Reihenfolge/Duplikate,
Neustartzustand und Sprecherunsicherheit; API-Aufnahmeweg mit Testaudio,
lokale Inferenz und UI-Start auf macserver. Geraetetests bleiben gesondert
sichtbar, sofern Watch/iPhone nicht bereitstehen.

Freigabe der neuen Architekturbausteine SwiftData und eingebettetes
Hummingbird: **vom Nutzer am 2026-10-17 ausdruecklich erteilt**. Der Bau der
nativen App ist beauftragt. Konkrete Build-/Funktionspruefungen und Grenzen
werden im Umsetzungsstand dokumentiert.
