# Owl auf macOS: Entscheidungen und Testplan

Stand: 2026-10-17

Status: Zielbild B (vollstaendige native Swift-App) vom Nutzer am 2026-10-17
ausdruecklich gewaehlt. Audioumfang ebenfalls freigegeben: Stufe 3 als Ziel,
schrittweise Umsetzung nach Aufnahmeende; Live-Text spaeter. Transkriptionsanbieter
und konkrete Implementierungspakete werden als Naechstes einzeln festgelegt. Die bestehende
Docker-Bereitstellung ist vorbereitet; der Backend-Dienst wurde noch nicht gestartet.

## Vorgehen

Wir gehen die Punkte in der folgenden Reihenfolge einzeln durch. Pro Punkt
halten wir Auswahl, Begruendung und Freigabe fest. Offene spaetere Punkte
werden nicht als stillschweigende Zustimmung behandelt. Nach einer Entscheidung
wird der naechste konkrete Vorschlag vorbereitet.

Der Entwicklungsplan fuer Watch, iPhone und Hindsight gilt weiterhin. Diese
Vorlage klaert, wie der Mac die bisherige Backend-Aufgabe uebernehmen soll.

## 1. Zielbild festlegen — entschieden

| Option | Umfang | Vorteil | Aufwand und Grenze |
| --- | --- | --- | --- |
| A: Bestehendes Owl erweitern | Python-Backend behalten, native Transkription anbinden; Docker oder native Python-Laufzeit anschliessend festlegen | Am meisten bestehende Serverlogik wiederverwenden | Schnittstelle zur nativen Verarbeitung und deren Betrieb erforderlich |
| B: Vollstaendige native Mac-App | Swift-App uebernimmt Empfang, Speicherung, Verarbeitung und Bedienung | Direkte macOS-Integration, eine native Anwendung als Ziel | Serverlogik muss uebertragen oder neu umgesetzt werden; groesster Gesamtaufwand |
| C: Mac-App mit bestehendem Backend | Native Oberflaeche, Python-Backend bleibt Bestandteil | Fruehe Mac-Oberflaeche mit Wiederverwendung | Zwei Laufzeiten, Paketierung und Prozessverwaltung; geringerer Swift-Portierungsaufwand, mehr Betriebslogik |

Empfehlung: A, wenn der geringste Umbau ausschlaggebend ist. B, wenn eine
eigenstaendige native Mac-App das gewuenschte Produkt ist und der zusaetzliche
Aufwand akzeptiert wird. C nur waehlen, wenn die native Oberflaeche kurzfristig
wichtiger ist als die Vereinfachung des Betriebs.

Entscheidungsfrage: Soll Owl zuerst mit moeglichst wenig Umbau funktionieren,
oder soll eine vollstaendige native Mac-App das Ziel der weiteren Arbeit sein?

Auswahl/Freigabe: **B, vollstaendige native Swift-App**, am 2026-10-17.
Nutzerentscheidung: „Ich will eine vollständige Swift App“.

Die Mac-App soll Empfang, Speicherung, Verarbeitung und Bedienung uebernehmen.
Ein dauerhaft eingebettetes Python-Backend ist damit nicht das Ziel. Bestehende
Watch-/iPhone-Clients und deren Aufnahmeweg werden im weiteren Entwurf
beruecksichtigt; ein Neuaufbau dieser Clients folgt daraus nicht automatisch.
Die Engine-Auswahl und die Betriebsverwaltung sind weiterhin offen. Der
vorbereitete Komodo-Stack wird durch diese Entscheidung nicht geloescht.

## 2. Audioumfang fuer den ersten Stand festlegen — entschieden

| Stufe | Ergebnis | Bedeutung fuer die Umsetzung |
| --- | --- | --- |
| 1 | Deutscher Text mit Zeitmarken nach Aufnahmeende | Kleinster Transkriptionsumfang |
| 2 | Zusaetzlich wechselnde Sprecher als A/B/… | Diarisierung und Zuordnung zu Textstellen erforderlich |
| 3 | Zusaetzlich eigene Stimme anhand einer Referenz erkennen | Stimmenvergleich, Schwellenwerte und Unsicherheitsbehandlung erforderlich |

Freigegebenes Ziel: Stufe 3, schrittweise umsetzen und abnehmen. Zuerst Text
mit Zeitmarken, danach Sprechertrennung, anschliessend Erkennung der eigenen
Stimme anhand einer Referenz. Ein Sprecherlabel bedeutet noch keine bekannte
Person. Unsichere Zuordnungen bleiben unbekannt.

Zunaechst Verarbeitung nach Aufnahmeende; Live-Text folgt spaeter. Die Uebergabe
an Hindsight muss spaeter klar erkennen koennen,
welche Aussagen dem Nutzer zugeordnet sind und welche nicht.

Auswahl/Freigabe: **Stufe 3 als Ziel, schrittweise Umsetzung; Verarbeitung nach
Aufnahmeende, Live-Text spaeter**, bestaetigt vom Nutzer am 2026-10-17.

## 3. Transkriptionskandidaten auswaehlen — Pruefrichtung entschieden

Die Auswahl haengt von Punkt 1 und 2 ab. Nicht alle Kandidaten implementieren.

| Kandidat | Eignung | Was wir integrieren muessen |
| --- | --- | --- |
| Apple SpeechAnalyzer / SpeechTranscriber | Wenige externe Abhaengigkeiten fuer native Transkription; System verwaltet Sprachmodelle | Audiozufuhr, Ergebnisse und Zeitmarken; fuer Sprecherfunktionen weitere Bausteine |
| FluidAudio | Swift-Bibliothek mit Transkription, Sprechertrennung und Stimmenvergleich als Bausteinen | Passende Modelle auswaehlen, Ergebnisse zusammenfuehren und Owl-Datenmodell bedienen |
| whisper.cpp | Nativer Whisper-Weg mit Apple-Beschleunigung und vorhandenem HTTP-Server | Owl-API anpassen; Sprecherfunktionen gesondert loesen |

Empfehlung fuer das freigegebene Ziel: FluidAudio zuerst als zusammenhaengenden
Kandidaten pruefen. Seine Swift-Bausteine decken Transkription, Sprechertrennung
und Stimmenvergleich ab; die Zuordnungslogik und Qualitaetsabnahme bleiben unsere
Aufgabe. Vorteil: weniger verschiedene Bibliotheken fuer den Zielumfang.
Nachteil: externe Bibliotheks- und Modellabhaengigkeit sowie deren Updatepflege.

Alternative: Apple SpeechAnalyzer fuer Text und Zeitmarken plus FluidAudio fuer
die Sprecherfunktionen. Vorteil: Apples Systemmodelle fuer Transkription.
Nachteil: zwei Verarbeitungspfade, deren Zeitmarken und Ergebnisse zusammengefuehrt
werden muessen. Diese Alternative nur zusaetzlich testen, wenn sie gewaehlt wird
oder der erste Kandidat die Abnahme verfehlt. Ein doppelter Test ist keine Pflicht.

Die Kandidatenentscheidung waehlt die Pruefrichtung, nicht bereits die endgueltige
Produkt-Engine. Vor Testimplementierung folgt der konkrete Umfang aus Punkt 4.

Diese Einschaetzung ist eine Integrationsbewertung, kein Qualitaetsbenchmark.
Deutsch, lange Aufnahmen, Wortzeitmarken und Modellverfuegbarkeit muessen auf
macserver geprueft werden. Bei Apple entscheidet das Framework ueber die
Hardwareausfuehrung; eine ausdrueckliche GPU-Steuerung wird nicht vorausgesetzt.
FluidAudio zielt auf Core ML und die Neural Engine. Externe Modelle und deren
Lizenz-/Zugangsbedingungen werden fuer den gewaehlten Stand konkret geprueft;
ein fehlender HF-Login darf nicht pauschal als Blockade aller Wege gelten.

Auswahl/Freigabe der Testkandidaten: **FluidAudio zuerst pruefen**, vom Nutzer
am 2026-10-17 bestaetigt. [Quellenpruefung und konkreter Testvorschlag](FLUIDAUDIO-PRUEFUNG.md)
sind vorbereitet. Quellenpruefung, Build, Modelldownload und technische
Audioverarbeitung sind erfolgt; siehe [Testergebnisse](../FLUIDAUDIO-TESTERGEBNISSE.md).
Produkt-Engine weiterhin offen.

Fortschreibung: Der Nutzer hat anschliessend die Umsetzung einer vollstaendigen
App beauftragt. FluidAudio ist die erste implementierte Engine; SwiftData und
Hummingbird wurden ausdruecklich freigegeben. Die offene Sprecherqualitaet
wird weiterhin sichtbar gehalten. Siehe [App-Umsetzungsstand](../MACOS-APP-UMSETZUNGSSTAND.md).

## 4. Begrenzten Mac-Test freigeben und auswerten — technische Tests ausgefuehrt

Der Nutzer hat den konkreten Testumfang einschliesslich Downloads am 2026-10-17
freigegeben. Native Release-Builds und netzwerkgesperrte Laeufe sind erfolgreich.
Die synthetischen deutschen Stimmen wurden jedoch zu einer Sprecher-ID
zusammengefasst. Sprechertrennung und Nutzeridentifizierung sind noch nicht
abgenommen. Als Naechstes dieselben Tests mit echten deutschen Gespraechen und
separater Nutzerreferenz fortsetzen; derzeit fehlen bestaetigte Dateien.

Vor Umsetzung einen eigenen konkreten Freigabevorschlag vorlegen: exakte neue
und geaenderte Dateien, Bibliotheks-/Modellversionen, Downloads, Wirkung,
Risiken, Updatefolgen und Rueckbau. Einen Test nicht stillschweigend zu einem
dauerhaften Dienst oder einer vollstaendigen App ausweiten.

Vorgeschlagene Testfolge mit denselben Audiodateien fuer alle Kandidaten:

1. Kurze deutsche Aufnahme: korrekter Text, Umlaute, Namen und Zeitmarken.
2. Gespraech mit mindestens zwei Sprechern, falls Stufe 2 gewaehlt wurde.
3. Etwa 30 Minuten Audio: Vollstaendigkeit, Laufzeit und maximaler Speicherbedarf.
4. Verarbeitung ohne Netzwerk nach Bereitstellung der erforderlichen Modelle.
5. Fehlerfaelle: ungueltige Datei, fehlende Modelle, Abbruch und erneuter Start.

Pro Lauf Hardware, OS, Kandidaten-/Modellversion, Audiolaenge, Laufzeit,
Speicherbedarf, Textfehler und Sprecherfehler festhalten. synthetisches Audio
allenfalls fuer den Funktionstest verwenden; die Abnahme braucht echte Aufnahmen.
Keine Cloud-Transkription oder Uebertragung von Testaudio an Dritte voraussetzen.

Ergebnis: Einen Kandidaten anhand der Messungen auswaehlen. Ein erfolgreicher
Transkriptionstest ist noch keine Abnahme des gesamten Aufnahmewegs.

Testumfang/Freigabe: **erteilt und technisch ausgefuehrt**.
Echte deutsche Qualitaetsabnahme und anschliessende Engine-Entscheidung: **offen**.

## 5. Einen vollstaendigen Aufnahmeweg implementieren

Erst nach Auswahl der Laufzeit und Engine das konkrete Implementierungspaket
freigeben. Kleinster durchgaengiger Ablauf:

Watch-Aufnahme → iPhone-Uebertragung → Mac-Empfang → dauerhaft gespeichertes
Audio → Transkription → gespeichertes, sichtbares Ergebnis.

Dabei bestehende Client-API und Dateiformate zuerst erfassen und moeglichst
beibehalten. Bei nativer Neuimplementierung insbesondere nicht nur die
Transkription portieren: Uploadabschluss, Authentifizierung, Datenhaltung und
Fehlerstatus gehoeren dazu. Zusammenfassungen duerfen die Speicherung eines
fertigen Transkripts im vorgeschlagenen Zielverhalten nicht blockieren; das
erfordert gegebenenfalls einen separat benannten Patch am bestehenden Owl.

Fuer diesen Schritt eigener Vorschlag mit Dateien, Datenformaten und Migration.
Abnahme: Eine reale Watch-Aufnahme laesst sich auf dem Mac wiederfinden,
abspielen und als Transkript lesen.

Freigabe: **offen**.

## 6. Zuverlaessigkeit und Betrieb festlegen

Danach Upload bei Netzausfall, doppelte Chunks, Neustart waehrend Verarbeitung,
Aufnahmeunterbrechung und nachvollziehbare Wiederholung abnehmen. Die bereits
dokumentierten Client-Fehler gelten durch einen Backend-Wechsel nicht als behoben.

Vor Dauerbetrieb separat festlegen: Start bei Anmeldung oder unbeaufsichtigter
Betrieb, Verhalten ohne angemeldeten Benutzer, Ruhezustand, Speicherorte,
Aufbewahrung, Backup, Zugriffsschutz, Updates und Rollback. Eine native App ist
nicht automatisch ein dauerhaft erreichbarer Server.

Komodo bleibt fuer den vorbereiteten Docker-Weg gesetzt. Falls eine native
App gewaehlt wird, muss ihr Deployment und ihre Startverwaltung ausdruecklich
abgestimmt werden; weder Komodo ersetzen noch einen neuen Dienst voraussetzen.
Vorbereitete Images und Stack bleiben bis zur Entscheidung erhalten.

Freigabe: **offen**.

## 7. Hindsight und Gesamtabnahme fortsetzen

Nach stabilem Aufnahmeweg die vorhandenen Phasen 3–5 des Entwicklungsplans
fortsetzen: aktuelle Agenten-/Memory-Architektur pruefen, vollstaendige
Gespraeche wiederholbar uebergeben, Quellen und Sprecherunsicherheit erhalten,
Tagesrueckblicke und langfristige Erkenntnisse testen.

Ein macOS-Wechsel autorisiert keine neue Memory-Schicht, keinen Agentenwechsel
und keine zusaetzliche Installation auf anderen Servern.

## Quellen fuer die Kandidaten

- [Apple: SpeechAnalyzer fuer Datei- und Live-Transkription](https://developer.apple.com/videos/play/wwdc2025/277/)
- [FluidAudio: Swift, Core ML, Transkription und Sprecherfunktionen](https://github.com/FluidInference/FluidAudio)
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
- [Vorhandener HTTP-Server von whisper.cpp](https://github.com/ggml-org/whisper.cpp/tree/master/examples/server)

Die Quellen dienen der Vorauswahl. Vor Implementierung einen konkreten
Quellstand und die zugehoerigen Modellbedingungen pruefen und dokumentieren.
