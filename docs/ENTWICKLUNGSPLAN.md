# Entwicklungsplan fuer Recap und Hindsight

Stand: 2026-10-17

Status: Arbeitsplan zur schrittweisen Umsetzung. Die Ablage und das schrittweise Vorgehen sind beauftragt. Architekturentscheidungen und konkrete Patches werden vor ihrer Umsetzung entsprechend den Projektregeln freigegeben.

## Ziel und erster Release

Owl erfasst bewusst gestartete Gespraeche auf der Apple Watch und transkribiert sie. Hindsight ordnet die Gespraeche zeitlich ein, bildet Tagesrueckblicke und gewinnt langfristige, belegbare Erkenntnisse. Der persoenliche Agent macht diese Inhalte abfragbar.

Der erste Release umfasst deutsche Aufnahmen, Offline-Uebertragung, nachvollziehbare Verarbeitung und die verlaessliche Uebergabe abgeschlossener Gespraeche. Ganztaegige automatische Aufnahme folgt erst nach erfolgreicher Abnahme dieses Weges.

Zielbild seit Nutzerentscheidung vom 2026-10-17: Eine vollstaendige native
Swift-App auf dem Mac uebernimmt Empfang, Speicherung, Verarbeitung und
Bedienung. Audioumfang ebenfalls freigegeben: deutsches Transkript mit Zeitmarken,
Sprechertrennung und Erkennung der eigenen Stimme, schrittweise umgesetzt.
Zunaechst Verarbeitung nach Aufnahmeende, Live-Text spaeter. Engine und konkrete Umsetzung werden einzeln festgelegt;
siehe [macOS-Entscheidungsvorlage](proposals/MACOS-ENTSCHEIDUNGSPLAN.md).

Inzwischen ist die Umsetzung beauftragt: SwiftData und ein eingebetteter
Hummingbird-Empfaenger sind freigegeben. Die native App unter `clients/macos/`
verwendet FluidAudio als erste implementierte Engine. [Umsetzungsstand,
Pruefungen und Grenzen](MACOS-APP-UMSETZUNGSSTAND.md) sind getrennt von der
noch offenen Geraete-/Sprecherqualitaetsabnahme dokumentiert.

## Bestehende Architektur und Abgleich

Das benachbarte Nexus-Projekt unter `../watch` dokumentiert Hermes als einzige produktive Agent Runtime und Hindsight als dessen Memory-Backend. Laut [ADR-009](../../watch/docs/adr/ADR-009-hindsight-memory-backend.md) wurde Hindsight 0.10.0 auf dem Hermes Pi mit PostgreSQL auf NAS1 und Modellinferenz auf dem Macserver abgenommen. Diese Angaben beschreiben den dokumentierten Stand vom 2026-09-23; die aktuelle Installation ist vor Umsetzung zu pruefen.

Im Gespraech zu Owl wurde OpenClaw als Abfrageoberflaeche genannt. Vor Agentenanbindung ist ausdruecklich zu klaeren, ob OpenClaw zusaetzlich vorgesehen ist oder Hermes gemeint ist. Der Owl-Plan ersetzt keine bestehende ADR und autorisiert keinen Runtime-Wechsel, keine zweite autoritative Memory-Schicht und keine neue produktive Bank.

Die Quelle fuer Originalaudio und vollstaendige Transkripte bleibt Owl. Hindsight ist fuer abgeleitetes Wissen und Abfragen zustaendig; eine originalgetreue Archivierung allein durch Hindsight wird nicht vorausgesetzt.

## Vorgeschlagene Aufgabenverteilung

| Bestandteil | Aufgabe |
| --- | --- |
| Owl auf Watch und iPhone | Aufnahme, lokale Zwischenspeicherung und Uebertragung |
| Owl-Backend | Segmentierung, Transkription und Originaldateien |
| Uebergabe an Hindsight | Vollstaendige Gespraeche samt Identitaet, Version und Herkunft uebermitteln |
| Hindsight | Faktenextraktion, Observations und Mental Models |
| Persoenlicher Agent | Rueckfragen und Bereitstellung der Rueckblicke |

Owl-eigene Zusammenfassungen sind fuer diesen Ablauf optional. Das Transkript bleibt die Quelle fuer die Hindsight-Extraktion.

## Phase 1 Bestand und Aufnahmeweg pruefen

- [x] Bestehende Projektarchitektur und Hindsight-Entscheidung lokal gelesen.
- [x] Owl-Fork `MephistoJB/Owl` angelegt und unter `/root/Documents/Programmierung/Owl` geklont; Ausgangscommit `91922655c3cbf0e5f3282c22806b5ac0cf30063e`. Weitere Installationen bleiben bei Bedarf zu pruefen.
- [ ] Aktuelle Watch-, iPhone- und Xcode-Version sowie Testgeraete erfassen. Teilstand: Nutzer nennt „Ultra 12“ und iOS 27; Xcode erkennt ein echtes iPhone 12 Pro Max. Watch-Modell/watchOS noch eindeutig zu erfassen; keine echte Watch in der Geraeteliste. macserver: Xcode 27.0 (27A266a), macOS 27.0, iOS-/watchOS-27-SDKs verifiziert.
- [ ] Ist-Zustand der bestehenden Hindsight-Anbindung und unterstuetzte API-Funktionen pruefen.
- [x] Ohne Installationsaenderungen ermitteln, welche Voraussetzungen fuer einen Owl-Build fehlen. Quellen- und Umgebungspruefung siehe [Phase-1-Bestandsaufnahme](PHASE-1-BESTANDSAUFNAHME.md). Die anfaengliche Xcode-Lizenzblockade ist inzwischen behoben; Mac-Arbeitskopie und unsignierter Build sind vorhanden. Signierung, echte Watch und Backend-Konfiguration bleiben offen.
- [ ] Build und Testbereitstellung nach Freigabe des konkreten Umfangs vorbereiten. Teilstand: Xcode-Nutzung auf macserver freigegeben; unsignierter iOS-Build einschliesslich Watch-App und Erweiterung erfolgreich. Keine Installation auf Geraeten.
- [ ] Deutsche Aufnahme bei gesperrtem Display testen.
- [ ] Netzwerk trennen, weiter aufnehmen und spaeter hochladen.
- [ ] Anrufunterbrechung und Wiederaufnahme pruefen.
- [ ] Backend-Neustart waehrend Upload und Verarbeitung pruefen.

Ergebnis: Fehlerliste mit Einordnung in vorhandene Einstellung, erforderlichen Patch und Plattformgrenze. Beobachtungen mit Versionen und Testbedingungen dokumentieren.

Zwischenstand vom 2026-10-16: [Quellenbefunde, erfolgreicher unsignierter Build und erster Testumfang](PHASE-1-BESTANDSAUFNAHME.md). Kritisch sind die lokale Loeschung von Chunks trotz HTTP-Fehlern, fehlende Chunk-Deduplizierung, Zustandsverlust bei Backend-Neustart sowie Token-Logging und englisches WhisperX-Alignment. Keine Quellcode-Patches oder produktiven Installationen vorgenommen; Phase 1 ist noch nicht abgenommen.

Abnahme: Eine etwa 30-minuetige deutsche Aufnahme kommt vollstaendig an und ergibt ein brauchbares Transkript. Unterbrechungen und Verluste werden erkannt.

## Phase 2 Notwendige Owl-Korrekturen

| Pruefpunkt | Gewuenschtes Verhalten |
| --- | --- |
| Hugging-Face-Token im Log | Keine Ausgabe des Tokens |
| Englisches WhisperX-Alignment | Sprachbehandlung passt zum deutschen Transkript |
| Aufnahmeunterbrechung | Wiederaufnahme oder sichtbarer Hinweis auf Aufnahmeende |
| Upload nach Aufnahmeende | Ausstehende Dateien werden verlaesslich uebertragen |
| Serverneustart | Ausstehende Verarbeitung bleibt erkennbar und wiederholbar |

Zuerst unterstuetzte Einstellungen und bestehende Mechanismen nutzen. Fuer jeden notwendigen Sourcecode-Patch vorab exakte Datei, Wirkung, Risiken, Updatefolgen und Rollback benennen und freigeben lassen.

Bereits identifizierter Kandidat: `owl/services/stt/asynchronous/async_whisper/async_whisper_transcription_server.py` protokolliert im geprueften Upstream-Stand den HF-Token und laedt ein englisches Alignment-Modell. Vor Aenderung den ausgewaehlten Commit erneut pruefen.

Serverarbeit kann unabhaengig von der Watch fortgesetzt werden. Der erste
[konkrete Freigabevorschlag](proposals/SERVER-TRANSKRIPTION-FREIGABE.md) umfasst
Token-Logging, sprachabhaengiges WhisperX-Alignment und die Weitergabe der
vorhandenen Deepgram-Spracheinstellung. Das Paket wurde ausdruecklich freigegeben, angewendet und mit fuenf
Unit-Tests geprueft. Dockerisierung und GitHub-Release wurden beauftragt;
[die freigegebene Build-Korrektur](proposals/DOCKER-BUILD-FREIGABE.md) ist umgesetzt.
Das ARM64-Image hat den GitHub-Build und die Image-Smoke-Tests bestanden und
wurde ueber Komodo auf den macserver heruntergeladen. Der Backend-Start und
die echte Transkriptionspruefung des vorbereiteten WhisperX-Wegs warten auf den HF-Zugang; siehe
[Bereitstellungsstand](../deploy/README.md). Danach folgen gesondert
Verarbeitungsabschluss, Wiederaufnahme und Hindsight-Uebergabe.

Inzwischen werden native macOS-Transkription und eine moegliche vollstaendige
Mac-App geprueft. Die [Entscheidungsvorlage fuer macOS](proposals/MACOS-ENTSCHEIDUNGSPLAN.md)
ordnet Zielbild, Funktionsumfang, Engine-Test und anschliessende Umsetzung.
Das Ziel einer vollstaendigen Swift-App ist inzwischen ausdruecklich gewaehlt;
Engine und konkrete Umsetzung bleiben offen. HF-Zugang ist eine
Voraussetzung des vorbereiteten Deployment-Wegs, keine allgemeine Voraussetzung
fuer jede moegliche Owl-Transkription.

## Phase 3 Uebergabe entwerfen und implementieren

### Integrationsentscheidung

| Variante | Vorteil | Nachteil |
| --- | --- | --- |
| Kleine Integration im Owl-Backend | Kennt Gespraechs-ID und Verarbeitungsabschluss direkt | Eigener Owl-Patch muss gepflegt werden |
| Externe Verarbeitung von Owl-Exporten | Weniger Eingriff in Owl | Zusaetzlicher Prozess und Erkennung fertiger beziehungsweise geaenderter Exporte |

Empfehlung: Kleine Integration im Owl-Backend, falls Phase 1 einen geeigneten Abschluss der Verarbeitung bestaetigt. Vor Implementierung konkrete Dateien und Persistenz fuer ausstehende Uebertragungen zur Freigabe vorlegen. Kein neuer Dienst wird vorausgesetzt.

### Gespraechsformat

| Feld | Bedeutung |
| --- | --- |
| Stabile Gespraechs-ID | Grundlage einer wiederholbaren Hindsight-Dokumentidentitaet |
| Beginn und Ende | Tatsaechlicher Aufnahmezeitraum, nicht Uploadzeit |
| Zeitzone und lokaler Tag | Tageszuordnung einschliesslich Sommerzeit |
| Transkript mit Sprecherkennzeichnungen | Vollstaendige Quelle fuer die Extraktion |
| Quelle und Geraetekennung | Herkunft und Aufnahmeweg |
| Version oder Inhaltspruefsumme | Geaenderte Transkripte erkennen |
| Originalverweis | Audio und Transkript in Owl wiederfinden |
| Sprecherunsicherheit | Unbekannte Stimmen nicht als Nutzer identifizieren |

Die konkrete Zeitzone und die Regel fuer Gespraeche ueber Mitternacht werden vor Implementierung festgelegt. Vorgeschlagene Regel: Ein Gespraech bleibt zusammenhaengend; Tagesrueckblicke beruecksichtigen seinen tatsaechlichen Zeitraum. Datumstags und Tagesgrenzen werden dazu konsistent definiert.

### Zuverlaessigkeit

- [ ] Erst nach erfolgreicher Transkription uebertragen.
- [ ] Stabile Hindsight-`document_id` verwenden.
- [ ] Unveraenderten Inhalt bei Wiederholungen nicht erneut verarbeiten.
- [ ] Korrigierte Transkripte anhand der API-Semantik gezielt aktualisieren.
- [ ] Fehlgeschlagene Uebertragungen dauerhaft als ausstehend fuehren.
- [ ] Annahme, abgeschlossene Verarbeitung und Fehler unterscheiden.
- [ ] Begrenzte Wiederholungen mit nachvollziehbarem Fehlerstatus vorsehen.
- [ ] Originaltranskripte und Audio nach festgelegter Aufbewahrungsregel erhalten.

Abnahme: Ein Hindsight-Ausfall verliert keine fertigen Gespraeche. Nach Wiederherstellung werden sie nachgeholt. Wiederholte Uebermittlung erzeugt keine zusaetzlichen Dokumente. Korrekturen bleiben quellengebunden.

## Phase 4 Tagesrueckblicke und langfristige Erkenntnisse

### Organisation in Hindsight

Eine gemeinsame Gespraechssicht innerhalb der freigegebenen Memory-Architektur verwenden. Quellen- und Datumstags dienen der Auswahl; eine Bank pro Tag ist nicht vorgesehen. Vor Schreibzugriffen Bank, Authority, Sichtbarkeit und Observation Scopes abstimmen. Datumstags duerfen langfristige Observations nicht unbeabsichtigt pro Tag isolieren.

Gespraeche als vollstaendige Transkripte mit Aufnahmezeitpunkt und Herkunft importieren. Zusammenfassungen nicht ungeprueft als neue urspruengliche Fakten behalten. Aussagen anderer Sprecher sind keine autoritativen Selbstaussagen des Nutzers.

### Tagesrueckblicke

- [ ] Je Datum einen eigenen Rueckblick mit stabiler Kennung anlegen.
- [ ] Themen und Gespraechsquellen auffuehren.
- [ ] Entscheidungen, Zusagen, Verantwortliche und Fristen erfassen.
- [ ] Offene Fragen, Widersprueche und unsichere Zuordnungen kennzeichnen.
- [ ] Spaete Uploads dem Aufnahmetag zuordnen und betroffene Rueckblicke aktualisieren.
- [ ] Korrekturen und Loeschungen in abgeleiteten Rueckblicken beruecksichtigen.

Beispiel fuer eine Quellfrage: „Fasse die Gespraeche vom 16. Oktober 2026 zusammen. Nenne Entscheidungen, Zusagen und offene Fragen mit den jeweiligen Gespraechsquellen. Kennzeichne Unsicherheiten.“

### Langfristige Mental Models

| Modell | Inhalt |
| --- | --- |
| Offene Verpflichtungen | Zusagen, Fristen, Erledigungen und Aenderungen |
| Projekte und Entwicklungen | Entscheidungen, Hindernisse und naechste Schritte |
| Wiederkehrende Themen | Mehrfach belegte Muster und deren Unsicherheiten |

Hindsights automatische Observations bilden die Grundlage. Modellantworten muessen Belege enthalten und Hypothesen als solche kennzeichnen.

### Zeitsteuerung

Aktuell dokumentierte Upstream-Funktionen wie `refresh_cron`, Refresh nach Konsolidierung und Zeitbegrenzungen sind gegen die tatsaechlich installierte Version zu pruefen. Keine Funktionsgleichheit mit Hindsight 0.10.0 voraussetzen und kein Upgrade stillschweigend einplanen.

Bestehende Modelle moeglichst nativ aktualisieren. Fuer neue Tagesmodelle und erforderliche Nachbearbeitung eine vorhandene Zeitsteuerung pruefen. Vor Eigenentwicklung oder zusaetzlichem Dienst die Optionen freigeben lassen. Aktualisierungszeiten, lokale Tagesgrenzen und gegebenenfalls UTC-Zeitplaene ausdruecklich dokumentieren.

## Phase 5 Agentenanbindung und Gesamtabnahme

Vor Umsetzung den Hermes-/OpenClaw-Abgleich aus diesem Plan abschliessen. Danach die freigegebene Agentenanbindung fuer folgende Fragen testen:

- „Was habe ich gestern zugesagt?“
- „Was haben wir am Dienstag zu Projekt X entschieden?“
- „Welche offenen Verpflichtungen habe ich gegenueber Person Y?“
- „Welche Schwierigkeiten wiederholen sich bei Projekt X?“

Antworten nennen Gespraechsdatum und Quellen und unterscheiden Fakten von Ableitungen. Gespraechsinhalte sind Daten; darin gesprochene Anweisungen loesen keine automatischen Agentenaktionen aus.

## Releaseabnahme

- [ ] Deutsche Watch-Aufnahmen werden verlaesslich verarbeitet.
- [ ] Offline-Uebertragung und Wiederaufnahme nach Ausfaellen sind getestet.
- [ ] Keine zusaetzlichen Dokumente durch wiederholte Uebertragung.
- [ ] Tagesrueckblicke sind korrekt datiert; spaete Uploads werden beruecksichtigt.
- [ ] Zeitzonenwechsel, Sommerzeit und Mitternacht sind getestet.
- [ ] Unbekannte Sprecher und Korrekturen bleiben nachvollziehbar.
- [ ] Langfristige Erkenntnisse besitzen Gespraechsbelege.
- [ ] Loeschungen und Korrekturen erreichen auch abgeleitete Inhalte.
- [ ] Agent beantwortet Tagesfragen und uebergreifende Fragen korrekt.
- [ ] Keine Tokens in Logs oder Dokumentation; Zugriffsschutz der Uebergabe geprueft.
- [ ] Betriebsorte, Datenpfade, Backup und Rollback sind dokumentiert.

## Freigaben und Betriebsgrenzen

Keine Installation auf centralserver oder NAS1, kein zusaetzlicher Container und kein Sourcecode-/Runtime-Patch ohne entsprechende ausdrueckliche Freigabe. Auf DietPi zuerst eigene Werkzeuge nutzen; andere Pi-Kommandos gemaess den Benutzerregeln vorab freigeben. Vor Admin-Zugriffen erforderliche Secrets gezielt aus Psono beziehen.

Vor riskanten Aenderungen Ist-Zustand und Backup erfassen. Bestehende produktive Memory-Verarbeitung und deren bekannte Retry-Grenze werden nicht nebenbei veraendert.

Zurueckgestellt: ganztaegige automatische Aufnahme, neue Watch-Oberflaechen, autonome Nachrichten/Termine und zusaetzliche Infrastruktur.

## Naechster Schritt

Punkt 1 der [macOS-Entscheidungsvorlage](proposals/MACOS-ENTSCHEIDUNGSPLAN.md)
und Punkt 2 sind entschieden: vollstaendige native Swift-App mit Text und
Zeitmarken, Sprechertrennung und Erkennung der eigenen Stimme, schrittweise
umgesetzt; zunaechst nach Aufnahmeende. Punkt 3: FluidAudio ist als erster
Pruefkandidat gewaehlt. Die [Quellen- und Kompatibilitaetspruefung](proposals/FLUIDAUDIO-PRUEFUNG.md)
ist abgeschlossen. Der begrenzte Mac-Test aus Punkt 4 wurde freigegeben und
technisch ausgefuehrt: [Messwerte und offene Abnahme](FLUIDAUDIO-TESTERGEBNISSE.md).
Der Nutzer hat danach den Wechsel von der Testphase zur vollstaendigen nativen
App beauftragt und SwiftData/Hummingbird freigegeben. Der erste native App-Stand
ist implementiert; siehe [Umsetzungsstand](MACOS-APP-UMSETZUNGSSTAND.md).
Als Naechstes den durchgaengigen App-Start und anschliessend die Verbindung
mit signierten Watch-/iPhone-Clients abnehmen. Echte Sprecherqualitaet und
Nutzeridentifizierung bleiben offen, blockieren den App-Bau aber nicht.

Der bisher freigegebene Docker-/Komodo-Weg bleibt als vorbereitete Option
erhalten. Bei seiner Fortsetzung HF-Zugang in Psono bereitstellen, ueber eine
geheime Komodo-Variable einbinden und erst dann das Image starten sowie Health,
authentifizierte API und deutsche Audioverarbeitung pruefen. Parallel bleiben
Signierung, echte Watch und Watch-Version offen. Vor der Hindsight-Uebergabe
den heutigen Agenten-/Memory-Bestand abgleichen.

## Arbeitskopie und Git Remotes

- Arbeitskopie: `/root/Documents/Programmierung/Owl`
- Eigenstaendiges Zielrepository seit Rebranding: https://github.com/MephistoJB/Recap (Fork geloescht; bereinigte Historie uebertragen).
- Original und `upstream`: https://github.com/OwlAIProject/Owl
- Ausgangscommit: `91922655c3cbf0e5f3282c22806b5ac0cf30063e`
- Plan aus dem Nexus-Projekt verschoben am 2026-10-16.

## Quellen und Projektbezug

- [Owl Repository](https://github.com/OwlAIProject/Owl)
- [Owl Watch-Anleitung](https://github.com/OwlAIProject/Owl/blob/main/docs/apple_watch_setup.md)
- [Owl Issue 39 zur Aufnahmeunterbrechung](https://github.com/OwlAIProject/Owl/issues/39)
- [Owl Issue 38 zum Upload nach Aufnahmeende](https://github.com/OwlAIProject/Owl/issues/38)
- [Hindsight Retain](https://github.com/vectorize-io/hindsight/blob/main/hindsight-docs/docs/developer/api/retain.mdx)
- [Hindsight Mental Models API](https://github.com/vectorize-io/hindsight/blob/main/hindsight-docs/docs/developer/api/mental-models.mdx)
- [Bestehende Memory-Entscheidung](../../watch/docs/09-memory-decision-and-handoff.md)
- [ADR-009 Hindsight](../../watch/docs/adr/ADR-009-hindsight-memory-backend.md)
