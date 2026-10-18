# Recap – iPhone und Apple Watch

[Startseite](../README.md) · [Verbindung zum nativen Mac](CLIENT-VERBINDUNG.md)

## Xcode und Geraete vorbereiten

1. Xcode installieren, einmal oeffnen und die Erststart-/Lizenzdialoge abschliessen.
   In den Xcode-Account-Einstellungen mit dem eigenen Apple-Account anmelden.
2. iPhone und Watch koppeln und den
   [Entwicklermodus auf den Geraeten aktivieren](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
3. Die Geraete entsperrt in Reichweite des Build-Mac halten. In Xcode unter
   **Window → Devices and Simulators** pruefen, ob beide erreichbar sind.
4. `clients/ios/Recap.xcodeproj` oeffnen. Unter **Signing & Capabilities** fuer
   alle App-/Erweiterungs-/Testtargets das eigene Team und automatische
   Signierung waehlen. Bei einer eigenen Projektkopie gegebenenfalls eigene
   eindeutige Bundle-IDs samt Watch-Companion-Verweisen verwenden.

## Bauen und installieren

- Fuer das iPhone das Scheme **Recap** und das echte iPhone als Ziel waehlen.
- Fuer die Watch **Recap Watch App** und die echte Watch als Ziel waehlen.
  Die Watch und ihre Erweiterung brauchen Entwicklungsprofile, die die
  Watch-Geraetekennung enthalten. Ein erfolgreicher reiner iPhone-Build mit
  eingebetteter Watch-App beweist das noch nicht.
- Build in Xcode ausfuehren und die App auf dem jeweiligen Geraet installieren.
  Die native Freigabe des privaten Signierschluessels kann beim ersten Build
  einen Schluesselbunddialog ausloesen.
- Meldet das iPhone einen nicht vertrauenswuerdigen Entwickler, unter
  **Einstellungen → Allgemein → VPN und Geraeteverwaltung** dem eigenen
  Entwicklungszertifikat vertrauen. Danach Recap oeffnen.
- Entwicklungsprofile sind befristet. Den Ablauf im jeweiligen Profil pruefen
  und bei Bedarf erneut signiert bauen. Ein Update unter derselben App-Kennung
  erfordert keine Deinstallation; vorher vorhandene Aufnahmedateien sichern.

## Mac-Verbindung einrichten

Serveradresse und Zugriffstoken werden **in der iPhone-App** unter
**Verbindung** eingestellt. Keine Zugangsdaten in `AppConstants.swift`, Git
oder Build-Argumente eintragen. Der Token liegt im jeweiligen Schluesselbund.

1. Recap auf dem Mac oeffnen und unter **Einstellungen → Verbindung** den Empfang
   starten. Die Mac-App muss waehrend Empfang und Verarbeitung laufen.
2. In der iPhone-App die Mac-Adresse und denselben Token speichern und
   **Verbindung pruefen** waehlen. Lokalen Netzwerkzugriff erlauben.
3. Recap auf der Watch oeffnen und auf dem iPhone ausdruecklich
   **Gespeicherte Verbindung an Watch senden** antippen. Die Rueckmeldung
   bestaetigt das Speichern auf der Watch.
4. Eine bewusst gestartete Watch-Aufnahme mit **Stop** beenden, Upload zulassen
   und fuer den ersten Test die Watch-App geoeffnet halten. Danach die
   Gespraechsliste auf dem iPhone aktualisieren.

Die Plists erlauben gezielt lokale HTTP-Verbindungen; die alte Platzhalter-IP
und die frueheren fest eingebauten Zugangsdaten werden nicht mehr verwendet.
Live-Streaming ist fuer diesen Ablauf deaktiviert. Ein oeffentlicher Proxy
ist nicht Teil der nativen Einrichtung.

Bei Upload-Fehlern bleiben unbestaetigte Dateien erhalten. Weitere Hinweise zu
Wiederholung, unterbrochenen PCM-Dateien und Sicherungen stehen in der
[Verbindungsanleitung](CLIENT-VERBINDUNG.md).
