# Recap: Verbindung und Upload der Apple-Clients

Stand 2026-10-18. Der signierte Geraetebuild wird auf dem MacBook vorbereitet;
der native Mac auf macserver bleibt Empfaenger und Transkriptionsort.

## Vor der ersten Aufnahme

Die vorhandenen Clients haben keine ausgefuellte Serveradresse und keinen
Token. Sie bieten dafuer bislang keine Bedienoberflaeche. Ausserdem behandelt
FileUploadTask HTTP-Fehler als Erfolg und loescht daraufhin Dateien; beim
App-Start werden unvollstaendige PCM-Dateien geloescht. Die Chunk-Sortierung
vergleicht Zahlen als Text. Socket.IO wird vom nativen Mac nicht angeboten.

## Empfohlener konkreter Umfang

- `clients/ios/Shared/ConnectionSettings.swift` neu: Serveradresse in UserDefaults,
  Token im jeweiligen Apple-Schluesselbund; keine Secrets in Git/Build-Quellen.
- `clients/ios/Shared/AppConstants.swift`: liest diese Einstellungen statt leerer
  Konstanten. Bestehende BLE-IDs bleiben erhalten.
- `clients/ios/Recap/Views/ConnectionSettingsView.swift` neu und
  `clients/ios/Recap/ContentView.swift`: Einstellungen fuer Adresse/Token,
  Speichern und eine ausdrueckliche Aktion zum Uebertragen an die eigene Watch.
- Die vorhandenen `WatchConnectivityManager.swift` beider Apps: verwenden die
  bestehende WatchConnectivity-Verbindung fuer die Konfiguration. Auf der Watch
  wird der Token im Schluesselbund gespeichert. Keine Payload-/Token-Ausgaben.
- `clients/ios/Recap Watch App/Views/SettingsView.swift`: Verbindungsstatus;
  Live-Streaming bleibt im vereinbarten ersten Ablauf deaktiviert.
- `clients/ios/Recap/RecapApp.swift` und `Services/SocketManager.swift`:
  kein automatischer Socket.IO-Aufbau beim Start gegen den nativen Mac und
  kein erzwungenes Auspacken einer leeren/ungueltigen Serveradresse.
- `clients/ios/Shared/Files/FileUploadTask.swift`: Chunks und Abschlussmarker
  nur nach HTTP-2xx-Antwort entfernen; Fehler wiederholen, numerische Reihenfolge,
  unvollstaendige PCM-Dateien nach Neustart erhalten und kontrolliert behandeln.
- `clients/ios/Recap/Info.plist` und `Recap-Watch-App-Info.plist`: Beschreibung
  fuer lokalen Netzwerkzugriff und gezielte Freigabe lokaler HTTP-Verbindungen.
- Xcode-Projekt: die zwei neuen Swift-Dateien in die benoetigten Targets einbinden.

Keine neue Serverkomponente, keine App Group, kein neuer Upload-Vertrag und
keine Token-Uebergabe ueber Git, Kommandozeilenargumente oder Logdateien.
Die sichere Schluesselbundspeicherung und der Konfigurationstransfer ueber die
vorhandene WatchConnectivity-Verbindung werden zur Freigabe vorgeschlagen.
Alternative: Adresse/Token auf beiden Geraeten getrennt eingeben; das vermeidet
den Transfer, ist auf der Watch aber deutlich umstaendlicher.

## Risiken, Pruefung und Rueckweg

Nur die eigene gekoppelte Watch erhaelt die Konfiguration, nach ausdruecklicher
Aktion in der iPhone-App. Falsche Adresse/Token fuehren zu einem sichtbaren
Verbindungsfehler und duerfen lokale Audiodateien nicht entfernen.
Gespeicherte Zugangsdaten bleiben ueber einen Tokenwechsel widerrufbar.

Gezielte Pruefungen: HTTP 401/409/500 und Netzausfall erhalten Audio/Endmarker;
2xx bestaetigt das Entfernen, Chunks 2/10 bleiben numerisch sortiert,
Neustart verliert keine unvollstaendige Aufnahme. Danach Build fuer beide
Geraete und eine vom Benutzer gestartete kurze Aufnahme bis zum Mac-Transkript.

Rueckweg: Quellcodeaenderungen als eigenen Commit zuruecknehmen, signiert neu
bauen; Konfiguration auf dem Geraet entfernen bzw. Token auf dem Mac wechseln.
Bestehende Aufnahmen und serverseitige Bibliothek bleiben erhalten. Eine
Deinstallation der App ist fuer diesen Rueckweg nicht vorgesehen.
