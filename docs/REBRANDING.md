# Recap – Rebranding

Seit 2026-10-17 wird das Projekt als Recap eigenstaendig weiterentwickelt.
Herkunft: https://github.com/OwlAIProject/Owl (MIT; siehe LICENSE und NOTICE).

App-Anzeigenamen auf Mac, iPhone und Watch, Mac-Bundle-Dateiname, Exporte,
Repository und kuenftige CI-Artefakte verwenden Recap. Das freigegebene Recap-Icon zeigt eine Sprechblase mit Rueckblick-Pfeil
auf einem petrolfarbenen Verlauf. Editierbare Quellen liegen in `design/recap/`.

Technische Kontinuitaet: Bundle-IDs, HTTP-Vertraege, Keychain-Service, UserDefaults-Schluessel, Modellmanifest
und `~/Library/Application Support/Owl/` bleiben erhalten. So benoetigt das
Rebranding keine Datenmigration und verliert keine bestehenden Einstellungen.
Der Projektordner kann weiterhin Owl heissen; der Git-Remote zeigt auf Recap.

Das native Build liegt unter `~/Library/Developer/Recap/Builds/Recap.app`.
Der vorherige Owl-Build bleibt fuer einen Rueckweg bestehen. Beide verwenden
dieselbe Bibliothek und duerfen nicht gleichzeitig darauf schreiben.

Der historische Docker-Release behaelt seinen Tag und Image-Digest. Neue
Container-Releases verwenden `ghcr.io/mephistojb/recap`; bestehende Komodo-
Deployments werden durch das Rebranding nicht umgestellt.

## Pruefung und Repository-Uebertragung

Der Recap-Build wurde auf macserver gebaut, ad hoc signiert und mit codesign
verifiziert. Alle acht Swift-Tests bestanden. Das ZIP wurde auf Integritaet
und enthaltenen Herkunftshinweis geprueft.

Die Uebertragung ist abgeschlossen. Recap ist unter
https://github.com/MephistoJB/Recap ein eigenstaendiges Repository (`fork: false`).
Der bisherige Fork `MephistoJB/Owl` wurde nach verifizierter Uebertragung geloescht;
das Original `OwlAIProject/Owl` bleibt unveraendert.

Mit ausdruecklicher Freigabe wurden geerbte Hugging-Face-Tokens aus der
Git-Historie entfernt (zehn Vorkommen im Export). Alle 3.603 erreichbaren
Git-Objekte wurden auf dieses Tokenmuster geprueft. Die Commit-Anzahlen je Ref,
Dateipfade, Dateimodi und Inhalte aller Ref-Spitzen wurden mit dem Original
verglichen; ausschliesslich die Tokenwerte wurden ersetzt. Dadurch aendern sich
Commit-IDs. Alle sechs Branches, ein Tag und der historische Release wurden auf
GitHub erneut gelesen und verifiziert. Alte Commit-IDs in historischen Berichten
bezeichnen den Stand vor der Bereinigung.

Ein Git-Bundle des vorherigen Stands, Release-Metadaten und ein Bericht zur
SHA-Zuordnung liegen ausserhalb des Repositorys in einem privaten Backupordner.
Actions-Ausfuehrungen sind nicht als Git-Historie uebertragbar; alte Lauf-Links
sind durch Loeschung des Forks nicht mehr verfuegbar. Neue Builds stehen im
[Recap-Mac-Workflow](https://github.com/MephistoJB/Recap/actions/workflows/macos-app.yml).
Der historische Container und seine Versionen wurden nach der Loeschung erneut
geprueft und sind unveraendert. Bestehende Komodo-Konfigurationen bleiben erhalten.

`origin` dieser Arbeitskopie und der Mac-Quellkopie zeigt auf Recap. Diese
Arbeitskopie verwendet die bereinigten Branches und Tags. Die Mac-Quellkopie
behaelt ihre vorhandenen Arbeitsdateien und alte lokale Git-Historie; vor einem
spaeteren Push von dort muss sie auf die bereinigte Historie abgeglichen werden.

## Rebranding im Code und eigenes Icon

Freigegebener Entwurf: A, Sprechblase mit Rueckblick-Pfeil. Der gemeinsame
Vektor-Master `design/recap/Recap.svg` ergibt ein deckendes 1024-px-Icon fuer
iOS/watchOS. `Recap-mac.svg` verwendet denselben Entwurf mit abgerundeter
Kachel und transparentem Rand fuer den Mac. Die PNGs wurden aus SVG mit
Chromium gerendert und visuell geprueft; keine externe Bildbibliothek ist
zur Laufzeit erforderlich. Ungewaehlte Entwuerfe bleiben als Entwurfsreferenz.

Native Module/Produkte: `RecapCore`, `RecapMac`, `RecapDoctor`,
`RecapCoreTests`. Typen: `RecapPaths`, `RecapError`, `RecapMultipart`.
Das Xcode-Projekt heisst `clients/ios/Recap.xcodeproj`; Targets, Schemes,
Swift-App-Typen und Tests verwenden Recap. Die drei Apple-App-Iconsets
enthalten das eigene Recap-Icon.

Die nativen Entwicklungsvariablen heissen jetzt `RECAP_DATA_DIR` und
`RECAP_API_TOKEN`. Es gibt keine neue Fallback- oder Migrationsschicht.

Auch das alte Python-Backend wird im Quellcode als Paket `recap` und CLI
`recap` gebaut. Dockerfile, Alembic-Import, CI-Smoke-Checks und Unit-Tests
zeigen auf dieses Paket. Bestehende Docker-Releases bleiben unveraendert.
Historische Anleitungen und Experimente dokumentieren weiterhin den damaligen
Owl-Stand. Die alte Web-Image-Vorlage `docker-compose.yml` ist ebenfalls
historisch; sie wird fuer die native App nicht verwendet.

Bewusst erhaltene technische Werte: `org.owl.local.mac`, iOS/watchOS-Bundle-IDs
und deren Verknuepfungen, Widget-Kind, Bluetooth-Restore-ID, `owl.*`-Defaults,
Keychain-Service, `owl-model-manifest.json`, bisheriger Application-Support-
Pfad und `OWL_*`-Server-/Komodo-Konfiguration. Ihre Umstellung wuerde eine
separate Migration benoetigen. Die SwiftData-Modelltypen und Eigenschaften
bleiben erhalten; die alte Testbibliothek wurde nach dem Modulwechsel erfolgreich geoeffnet.
Die gespeicherte Aufnahme ist weiterhin als abgeschlossen mit 53 Woertern lesbar.

Abnahme: Mac-App gebaut und Signatur geprueft; acht Swift-Tests und fuenf
Python-Unit-Tests bestanden. Xcode baute `Recap` einschliesslich Watch-App
fuer die Simulatoren erfolgreich (ohne Codesign/Provisionierung). Assetkatalog-
Verweise, Plist-Syntax und die deckenden 1024-px-iPhone-/Watch-Icons sind geprueft.

Geprueftes App-ZIP: `clients/macos/artifacts/Recap-macOS-arm64.zip`
(11,145,247 Bytes; SHA256 `5dbcb46f3889114d67ce01d81910106950dbb7f132c55ee0d7d4a47e84915c82`).

## Eigene Apple-App-Kennungen (2026-10-18)

Beim ersten signierten Geraetebuild hat Apple die alten `com.owl.Owl`-
Kennungen fuer das eigene Entwicklerteam abgelehnt. iPhone und Watch
verwenden deshalb `org.bechara.recap`, `org.bechara.recap.watchkitapp`
und `org.bechara.recap.watchkitapp.extension`; Testtargets sind entsprechend
zugeordnet. Companion-Verweise wurden mit umgestellt. Das Xcode-Projekt
verwendet das vorhandene eigene Entwicklerteam. Die Mac-App behaelt ihre
bisherige Kennung und Bibliothek. Vorhandene Apps unter anderen Kennungen
werden durch eine Installation unter den neuen Kennungen nicht ersetzt.

Die Profile fuer die drei neuen App-Kennungen wurden auf dem MacBook geladen.
Der Geraetebuild besteht ohne Signierung; die Signierung wird gerade im lokalen
Terminal-Kontext geprueft, weil der SSH-Aufruf den privaten Signierschluessel
noch nicht verwenden konnte. Eine erfolgreiche Installation wird erst nach
Ruecklesen der installierten App bestaetigt.
