# Recap auf iPhone und Watch mit dem Mac verbinden

Der native Mac ist Empfaenger und Verarbeitungsort. Die iPhone-Liste zeigt die
auf diesem Mac gespeicherten Gespraeche. Eine Watch-Aufnahme erscheint dort
erst nach ihrer Uebertragung; der Verarbeitungsstatus kann danach durch
Herunterziehen der Liste aktualisiert werden.

## Einrichtung

1. Recap auf dem Mac oeffnen. In den Einstellungen unter **Verbindung** den
   Empfang starten. Die App muss geoeffnet und der Mac erreichbar bleiben.
2. Die Mac-Adresse und den dort angezeigten Zugriffstoken uebernehmen.
   Im Heimnetz ist beispielsweise `http://macserver:8012` vorgesehen.
   `0.0.0.0` ist eine Bind-Adresse des Servers und keine Zieladresse fuer die Clients.
3. Auf dem iPhone in Recap **Verbindung** oeffnen, Adresse und Token eingeben
   und speichern. Der Token wird im Schluesselbund dieses Geraets gespeichert.
4. **Verbindung pruefen** antippen. Ein erfolgreicher Test bestaetigt die
   authentifizierte Gespraechsabfrage. Lokalen Netzwerkzugriff erlauben, wenn
   iOS danach fragt. Lokales HTTP nur im vertrauenswuerdigen Netz verwenden.
5. Recap auf der gekoppelten Watch oeffnen. Auf dem iPhone ausdruecklich
   **Gespeicherte Verbindung an Watch senden** antippen. Zunaechst erscheint
   eine Vormerkung; erst die Rueckmeldung der Watch bestaetigt das Speichern.
   Die Watch-Einstellungen zeigen Adresse, Konfigurations- und Uploadstatus.
6. Die Aufnahme auf der Watch ueber **Stop** beenden. Upload eingeschaltet
   lassen und Recap fuer den ersten Test auf der Watch geoeffnet halten.
   Danach die Gespraechsliste auf dem iPhone aktualisieren.

Die Verbindungseinstellungen werden ueber die vorhandene WatchConnectivity-
Verbindung uebertragen. Das ist keine Audio-Uebertragung ueber das iPhone;
die Watch muss den Mac selbst erreichen koennen. Live-Streaming ist in diesem
Ablauf deaktiviert. Die App kann daher schon vor dem Verbinden offline aufnehmen.

## Dateierhalt und Fehler

- Nur HTTP 2xx bestaetigt die Annahme eines Chunks oder Verarbeitungsauftrags.
  Bei HTTP 401/409/500 oder Netzausfall bleiben unbestaetigte Dateien erhalten.
- Fehlgeschlagene Uebertragungen werden bei laufender Upload-Aufgabe erneut
  versucht. Ist die Watch-App vom System angehalten, muss sie fuer den
  naechsten Versuch gegebenenfalls wieder geoeffnet werden.
- Erfolgreich angenommene Chunks liegen dauerhaft auf dem Mac und werden lokal
  entfernt. Bei fehlgeschlagener Verarbeitungsanfrage bleibt der Abschlussmarker
  erhalten; er wird erneut gesendet, ohne bereits bestaetigte Chunks zu wiederholen.
- Nach einem Neustart werden vollstaendige 16-Bit-PCM-Fragmente einer
  unterbrochenen Aufnahme erhalten und zur Uebertragung vorbereitet.
  Leere, ungerade oder kollidierende Fragmente bleiben unveraendert liegen und
  blockieren den Abschluss dieser Aufnahme fuer eine gezielte Wiederherstellung.
- Vor einem Update mit vorhandenen Aufnahmen: Aufnahme beenden, Watch-Dateien
  ueber Xcodes Geraetezugriff sichern und die Sicherung pruefen. Keine
  Deinstallation als Fehlerbehebung verwenden.

## Entwicklungsstand

Der vollstaendige Client-Umbau ist freigegeben und im Quellcode umgesetzt.
iPhone-/Watch-Simulator-Build und alle fuenf Client-Regressionstests am Stand
`e43399a` bestehen; auch die acht Mac-Tests sind erfolgreich. Die Installation
auf den realen Geraeten und die Pruefung der vorhandenen Aufnahme stehen noch
aus. Details und Build-Nachweise stehen im Entwicklungsplan. Die frueher installierte
Version hat diese Einstellungen und Upload-Korrekturen noch nicht.
