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
