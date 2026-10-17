# FluidAudio: Laufzeittest auf macserver

Stand: 2026-10-17. Der Nutzer hat den begrenzten Swift-Test einschliesslich
Modelldownload ausdruecklich freigegeben. Testprogramm:
[`experiments/fluid-audio`](../experiments/fluid-audio/README.md).

## Ergebnis und Entscheidungslage

Native Transkription mit deutschen Wortzeitmarken und die Offline-Diarizer-Pipeline
funktionieren technisch auf macserver, auch bei gesperrtem Netzwerk. FluidAudio
bleibt ein geeigneter Testkandidat. Eine Produktentscheidung zugunsten dieser
Engine ist noch nicht getroffen.

Die zwei synthetischen Stimmen wurden als **ein** Sprecher zusammengefasst.
Damit ist die Anforderung Sprechertrennung noch nicht erfuellt beziehungsweise
abgenommen. Es wurde keine Sprecherzahl erzwungen und kein Schwellwert passend
zum Test zurechtgelegt. Die Erkennung der Nutzerstimme ist ebenfalls offen:
Es liegt keine als Nutzerreferenz bestaetigte Aufnahme vor.

## Umgebung und Reproduzierbarkeit

- Apple M4 Pro, 12 CPU-Kerne, 24 GB physischer RAM, macOS 27.0.
- Swift 6.4, ARM64-Release-Build ohne Warnungen im abschliessenden Build.
- FluidAudio `0.17.7`, Commit `503b4bd1bbf7220882de39fe8ae6716aae4132da`,
  `Package.resolved` im Experiment hinterlegt.
- Parakeet v3 explizit mit `.int8V2` / `Encoder_v2.mlmodelc`;
  HF-Revision `7dd20fe6b1797d35f5e3307e8b1732d9a178edfe`.
- Offline-Community-1-Diarizer, HF-Revision
  `df2625ac79a7ac6b65ad868fee6d80f320da4232`.
- 47 Modell-/Begleitdateien, 653.813.376 Bytes, anonym heruntergeladen und
  vollstaendig gegen LFS-SHA256 beziehungsweise Git-Blob-SHA1 geprueft.
  Ein zusaetzliches SHA256-Manifest liegt bei den lokalen Modellen.
- Keine Paketinstallation am Betriebssystem, kein Bibliothekspatch und kein
  Hintergrunddienst. Das Experiment wurde ueber den bereits freigegebenen
  SSH-Zugang gebaut und ausgefuehrt. Komodo-Stack unveraendert.

## Gemessene Laeufe

Alle folgenden Audio-Laeufe waren netzwerkgesperrt. Ladezeit und Verarbeitung
sind getrennt; Reihenfolge ASR, Diarisierung, optional Referenzvergleich.
GB/MB sind dezimale Einheiten.

| Eingabe | Audiolaenge | Modellladen | ASR | Diarisierung | Max. Prozess-RSS | Peak Memory Footprint |
| --- | --- | --- | --- | --- | --- | --- |
| Deutsch, zwei synthetische Stimmen, erster erfolgreicher Inferenzlauf | 25,94 s | 10,01 s | 0,126 s | 2,751 s | 680 MB | 509 MB |
| Dieselbe Datei, weiterer Prozess nach Aufwaermen der System-Caches | 25,94 s | 0,151 s | 0,117 s | 0,173 s | 237 MB | 498 MB |
| Dieselbe synthetische Aufnahme wiederholt und auf 30 Minuten zugeschnitten | 1.800 s | 0,163 s | 3,721 s | 4,751 s | 603 MB | 941 MB |
| Vorhandene englische Repository-Testaufnahme | 13,50 s | 0,150 s | 0,132 s | 0,170 s | 187 MB | 487 MB |

Die zweite Zeile enthaelt zusaetzlich 0,204 s fuer einen synthetischen
Referenzvergleich; die Speicherwerte umfassen diesen Schritt. Insgesamt
brauchte dieser Prozess etwa 0,73 s einschliesslich Start und Ergebnisausgabe.
Der 30-Minuten-Prozess brauchte insgesamt etwa 8,80 s.

RSS und macOS Memory Footprint sind unterschiedliche Betriebssystem-Metriken;
sie duerfen nicht addiert oder als gesamter Speicherverbrauch des Macs
interpretiert werden. Geteilte System-/ANE-Caches sind nicht vollstaendig
erfasst. Es erfolgte keine Messung von Stromaufnahme oder GPU-/ANE-Auslastung.
Die Konfiguration erlaubt Apple-Beschleunigung, belegt aber nicht den
Ausfuehrungsort jedes einzelnen Operators.

## Inhaltliche und technische Befunde

- Kurzer deutscher Funktionstest: 53 Woerter mit Zeitmarken, sinnvoller Text
  einschliesslich Umlauten und Umwandlung von „neun Uhr“ in „9 Uhr“.
  Keine formale WER-Messung und kein Nachweis fuer Dialekte oder Watch-Mikrofone.
- Zwei synthetische Stimmen (`Anna`, `Eddy (Deutsch (Deutschland))` via macOS
  `say`): 2 Sprechersegmente, aber nur 1 Sprecher-ID. Die Segmentanzahl ist
  keine Sprecheranzahl. Das bleibt ein negativer Testbefund.
- 30-Minuten-Belastungstest: 3.681 Woerter, 139 Sprechersegmente, 1 Sprecher-ID;
  letzte Wortzeit bis 1.799,92 s. Wiederholtes Audio ist leichter als ein echtes
  30-Minuten-Gespraech. Vollstaendige wortgetreue Erkennung aller Wiederholungen
  wurde nicht abgenommen; erfolgreiche Verarbeitung bis Dateiende ist belegt.
- Wortzeiten sind endlich, innerhalb des erlaubten Zeitbereichs und nach
  Startzeit monoton. Genauigkeit von Wort-/Sprechergrenzen gegen annotierte
  echte Gespraeche steht aus.
- Synthetische Referenz: Kosinusaehnlichkeit zum einzigen gemischten Cluster
  ca. 0,979. Das beweist keine korrekte Personenidentifizierung; die beiden
  synthetischen Stimmen waren bereits zusammengefasst.
- Separater Vergleich der beiden englischen Repository-Dateien ergab ca.
  0,465. Deren Sprecheridentitaeten sind nicht annotiert; daraus folgt weder
  „gleiche Person“ noch „andere Person“. Keine Zuordnung zum Nutzer.
- Das Testprogramm exportiert Roh-Textzeiten und Sprechersegmente getrennt.
  Die produktive Zuordnung von Woertern zu Sprechern ist noch zu implementieren.

## Offline- und Fehlerpruefung

`sandbox-exec` mit `(deny network*)` sperrte einen TCP-Verbindungsversuch zu
`127.0.0.1:11434` mit `Operation not permitted`. Unter demselben Profil liefen
die Audio-Tests erfolgreich. Die Sperre galt nur fuer die Testprozesse;
Netzwerkdienste und Systemeinstellungen wurden nicht veraendert.

| Fall | Beobachtung |
| --- | --- |
| Modellverzeichnis fehlt | Exit 1, kein Ergebnis; kein automatischer Download |
| Datei enthaelt ungueltiges Audio | Exit 1, kein Erfolgsergebnis |
| Ergebnisdatei existiert bereits | Exit 1, SHA256 der vorhandenen Datei danach unveraendert |
| Neustart als separater Prozess | Weitere Transkription mit denselben lokalen Modellen erfolgreich |

Ein erzwungener Prozessabbruch waehrend Inferenz und eine persistente
Auftragswarteschlange wurden nicht getestet; diese gehoeren zur spaeteren App.

## Korrekturen gegenueber der Vorauswahl

Der erste Ladeversuch verwendete den Release-Default `.int8` und scheiterte
korrekt an der fehlenden `Encoder.mlmodelc`. Fuer den bereits ausgewaehlten
INT8-v2-Encoder muss explizit `.int8V2` gesetzt werden. Dies wurde im eigenen
Testprogramm korrigiert; keine Modell-Umbenennung und kein FluidAudio-Patch.

Trotz abgewaehltem NeMo-Trait lud SwiftPM dessen Binaerartefakt bei der
Paketaufloesung herunter (87,3 MB zusaetzlich). Die Erwartung, der abgewaehlte
Trait verhindere bereits den Download, hat sich in diesem Build nicht
bestaetigt. Daraus wird kein Eingriff in den Bibliotheks-Manifest abgeleitet.

## Ablage, Grenzen und naechster Schritt

Auf macserver:

- Quellcode: `~/Documents/Programmierung/Owl/experiments/fluid-audio/`.
- Modelle und SHA256-Manifest: `~/Library/Application Support/Owl/Experiments/FluidAudio/models/`.
- Audio und Ergebnis-JSON/Logs: benachbarte Unterordner `audio/` und `results/`.
- Teststatus: `test-status.json` und `extended-status.json` im Testdatenordner.

Ergebnisdateien enthalten Text und Stimmen-Embeddings und bleiben ausserhalb
des Repositories. Es wurde kein neues Produktionsbackend gestartet.

Als Naechstes eine echte deutsche Gespraechsaufnahme mit zwei bekannten
Sprechern und eine separate Nutzerreferenz durch denselben Test schicken.
Zusaetzlich ein echtes laengeres Gespraech fuer die Qualitaetsabnahme pruefen.
Erst dann entscheiden: FluidAudio als Produkt-Engine, weitere unterstuetzte
Einstellungen vergleichen oder die vorbereitete Apple-Alternative testen.
Die bestehenden Lizenz-/Herkunftsbefunde vor Weitergabe bleiben offen.
