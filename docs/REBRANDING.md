# Recap – Rebranding

Seit 2026-10-17 wird das Projekt als Recap eigenstaendig weiterentwickelt.
Herkunft: https://github.com/OwlAIProject/Owl (MIT; siehe LICENSE und NOTICE).

App-Anzeigenamen auf Mac, iPhone und Watch, Mac-Bundle-Dateiname, Exporte,
Repository und kuenftige CI-Artefakte verwenden Recap. Das bisherige Owl-Icon
bleibt vorerst als aus Owl uebernommenes Asset mit Herkunftshinweis erhalten.

Technische Kontinuitaet: Bundle-IDs, Swift-Module/Xcode-Targets, Python-Modul
`owl`, HTTP-Vertraege, Keychain-Service, UserDefaults-Schluessel, Modellmanifest
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
