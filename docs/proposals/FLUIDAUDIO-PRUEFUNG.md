# FluidAudio fuer die native Owl-App

Stand: 2026-10-17. Quellen- und Kompatibilitaetspruefung abgeschlossen.
Ergebnis der Quellenpruefung: Geeigneter Kandidat fuer einen begrenzten Laufzeittest.
Die folgenden Bestandsangaben beschreiben diese Vorauswahl vor dem Laufzeittest.
Der Test wurde anschliessend freigegeben und ausgefuehrt; aktuelle Ergebnisse:
[FluidAudio-Laufzeittest](../FLUIDAUDIO-TESTERGEBNISSE.md). Engine-Abnahme noch offen.

## Gepruefter Stand

- FluidAudio Release `v0.17.7`, veroeffentlicht am 2026-10-08,
  Commit `503b4bd1bbf7220882de39fe8ae6716aae4132da`.
- macserver ueber SSH nur lesend geprueft: Apple M4 Pro, 24 GB physischer RAM,
  macOS 27.0, Apple Swift 6.4, Ziel `arm64-apple-macosx27.0.0`.
- Das Release verlangt mindestens Swift 6.0 und macOS 14. Fuer unseren Test
  steht der neuere Swift-6.2-Paketmanifest zur Verfuegung. Build auf Swift 6.4
  ist noch nicht verifiziert.
- Der Entwicklungszweig `main` unterscheidet sich bereits vom Release,
  insbesondere bei Package Traits. Anleitungen von `main` nicht ungeprueft
  mit dem Release mischen.

## Eignung fuer den beschlossenen Umfang

| Anforderung | Quellenbefund | Noch zu pruefen |
| --- | --- | --- |
| Deutsch | Parakeet TDT v3, 0.6 Milliarden Parameter, listet Deutsch unter 25 Sprachen | Echte Watch-Aufnahmen, Namen, Dialekt, Nebengeraeusche |
| Zeitmarken | `ASRResult.tokenTimings` und Hilfsfunktion zur Wortgruppierung vorhanden | Vollstaendigkeit, Praezision und korrekte Zeiten bei langen Dateien |
| Sprechertrennung | `OfflineDiarizerManager` verarbeitet komplette Dateien mit Segmentierung, Embeddings und VBx-Clustering | Sprecherwechsel, Ueberlappungen und aehnliche Stimmen |
| Eigene Stimme | Sprecher-Embeddings koennen ausgegeben und verglichen werden | Referenzprofil, Vergleich auf derselben Embedding-Basis, Schwellwert und Ablehnung unsicherer Treffer |
| Lange Dateien | ASR besitzt Chunk-Verarbeitung; Offline-Diarizer bietet dateibasierte Verarbeitung | 30-Minuten-Test, Speichermaximum und Abbruchverhalten |
| Lokalbetrieb | Core ML; manuelles Laden lokaler Modelle wird unterstuetzt | Ein Lauf ohne Netz nach Modellbereitstellung |

Fuer Stimme und Text sind weiterhin getrennte Verarbeitungsschritte und deren
Zusammenfuehrung erforderlich, auch innerhalb derselben Bibliothek. Sprecher-IDs
sind zunaechst nur fuer die jeweilige Aufnahme gueltig. Ein automatisch
vergebenes Label darf nicht ohne belastbaren Referenzvergleich als Nutzername
gespeichert werden. Ein Aehnlichkeitswert ist keine kalibrierte Wahrscheinlichkeit.

## Modelle und Download

Fuer einen nachvollziehbaren ersten Test wird Parakeet v3 INT8 statt eines
automatisch wechselnden Standardmodells vorgeschlagen. Ultra/Redux sind weitere
Kandidaten, werden fuer diesen Test nicht zusaetzlich geladen.

| Auswahl | Festgehaltener HF-Stand | Ausgewaehlte Dateien insgesamt |
| --- | --- | --- |
| `FluidInference/parakeet-tdt-0.6b-v3-coreml` | `7dd20fe6b1797d35f5e3307e8b1732d9a178edfe` | 632.169.729 Bytes, etwa 632 MB |
| `FluidInference/speaker-diarization-coreml` | `df2625ac79a7ac6b65ad868fee6d80f320da4232` | 21.599.417 Bytes, etwa 22 MB |

ASR-Auswahl: `Preprocessor.mlmodelc`, `Encoder_v2.mlmodelc`, `Decoder.mlmodelc`,
`JointDecisionv3.mlmodelc`, `parakeet_vocab.json`.
Offline-Diarizer: `Segmentation.mlmodelc`, `Embedding.mlmodelc`, `FBank.mlmodelc`,
`PldaRho.mlmodelc`, `plda-parameters.json`.

Die Groessen wurden ueber HF-Dateimetadaten ermittelt, nicht durch Download.
Anonyme HEAD-Aufrufe auf je eine echte Gewichtsdatei beider ausgewaehlter
Snapshots lieferten HTTP 200. Die Repositories sind laut HF-API nicht gated.
Somit ist fuer diese Auswahl derzeit kein HF-Login erforderlich. Vollstaendige
Downloads und Integritaetspruefung stehen aus. Rund 654 MB sind die ausgewaehlten
Downloadartefakte; Build, Core-ML-Caches, RAM und Audio kommen hinzu.

Das SDK pinnt den Diarizer bereits, verwendet fuer ASR jedoch `main`. Fuer den
Test die festgehaltenen Artefakte explizit bereitstellen und lokal laden, ueber
die unterstuetzte API; kein Patch der Bibliothek erforderlich.

## Abhaengigkeiten und Herkunft

- FluidAudio-Quellcode: Apache-2.0. Die Modelle haben eigene Bedingungen.
- ASR-Modellkarte: Metadaten nennen CC-BY-4.0, ein spaeterer Absatz nennt
  Apache-2.0. Diesen Widerspruch vor Weitergabe der App/Modelle klaeren;
  vorlaeufig die Attribution und genaue Herkunft mitfuehren.
- Community-1-Diarizer: abgegrenzter CC-BY-4.0-Artefaktsatz laut `NOTICE.md`.
  Legacy-WeSpeaker-Dateien sind nicht Teil der obigen Auswahl.
- Die Herkunftsdokumentation weist darauf hin, dass der urspruengliche
  Konvertierungsstand nicht vollstaendig reproduzierbar belegt ist. Revisionen
  und Dateihashes deshalb fuer unseren Test festhalten.
- Das Release bringt native C++-Wrapper mit. Optional wird ein vorgebautes
  NeMo/Rust-XCFramework geladen. Mit dem Swift-6.2-Manifest kann der Test
  `NemoTextProcessing` durch `traits: []` abwaehlen. Das entfernt im Release
  nicht automatisch den gesamten TTS-Quellcode; getrennte TTS-/Diarizer-Traits
  aus neueren README-Beispielen stehen dort noch nicht zur Verfuegung.
- Keine externe Paketinstallation, Python-Laufzeit oder separater
  Transkriptionsserver fuer diesen Test vorgesehen.

Diese Pruefung ist kein vollstaendiger Security-Audit aller Quellcodedateien.

## Konkreter naechster Test — zur Freigabe

Ein isoliertes Swift-Kommandozeilen-Testpaket ist der vorgeschlagene erste
Baustein zur App. Damit kann die Engine vor UI-, Netzwerk- und Datenbankbau
auf demselben Mac geprueft werden. Es ist kein zusaetzlicher Dauerdienst.

Vorgeschlagene neue Projektdateien:

- `experiments/fluid-audio/Package.swift`: festes FluidAudio-Release,
  NeMo-Binaerabhaengigkeit abwaehlen.
- `experiments/fluid-audio/Sources/OwlAudioProbe/main.swift`: lokale Audiodatei
  transkribieren, offline diarizieren, Zeitmarken und Roh-Ergebnisse exportieren;
  optional separate Referenzdatei mit derselben Embedding-Pipeline vergleichen.
- `experiments/fluid-audio/README.md`: Download-/Build-/Testbefehle, feste
  Modellrevisionen, Attribution und Rueckbau.
- `docs/FLUIDAUDIO-TESTERGEBNISSE.md`: tatsaechliche Messungen und offene Punkte.

Mac-Arbeitsort: `~/Documents/Programmierung/Owl/experiments/fluid-audio/`.
Modelle, Referenzaudio und Ergebnisse unter einem klar zugeordneten lokalen
Testdatenordner ausserhalb des Git-Repositories, vorgeschlagen
`~/Library/Application Support/Owl/Experiments/FluidAudio/`. Keine bestehenden
Audiodateien ueberschreiben; keine Aufnahmen oder Stimmenprofile committen.

Umfang: Build, Modellbereitstellung (rund 654 MB plus Caches), kurzer deutscher
Funktionstest, danach echte Zwei-Sprecher- und 30-Minuten-Aufnahme, Offline-Lauf.
Eine synthetische deutsche Aufnahme reicht fuer den Funktionstest, aber nicht
fuer die Qualitaetsabnahme oder Nutzerstimmenerkennung. Falls echte Testaufnahmen
oder eine Referenz fehlen, diesen Teil als offen dokumentieren.

Risiken: Build-/Core-ML-Inkompatibilitaet trotz passender Mindestversion,
Modellladefehler, falsche Sprecherzuordnung und hoher Speicherbedarf bei langen
Dateien. Ausgaben enthalten Gespraechsinhalte und gegebenenfalls Stimmenprofile.
Keine Namenszuordnung ohne Vergleich; ein allgemeiner Schwellwert wird nicht
als bereits verlaesslich dargestellt.

Updatefolgen: Release und Modelle bleiben fuer den Vergleich fixiert; spaetere
Updates brauchen Regression mit denselben Aufnahmen. Rueckbau: nur die neu
angelegten Experimentdateien und zugeordneten Testdaten nach Sichtung entfernen.
Watch-/iPhone-Quellen, bestehende Owl-Laufzeit, Komodo-Stack und Datenbank werden
durch diesen Test nicht geaendert.

Freigabe dieses Implementierungs-/Downloadumfangs: **vom Nutzer am 2026-10-17
ausdruecklich erteilt**. Umsetzung und technische Laufzeitpruefung sind erfolgt;
Ergebnisse stehen in `docs/FLUIDAUDIO-TESTERGEBNISSE.md`. Echte deutsche
Gespraechs- und Nutzerreferenztests stehen mangels bestaetigter Dateien aus. Der oben beschriebene
Stand der Quellenpruefung ist der Ausgangszustand vor Umsetzung.

## Quellen

- [Release v0.17.7](https://github.com/FluidInference/FluidAudio/releases/tag/v0.17.7)
- [Release-Manifest fuer Swift 6.2](https://github.com/FluidInference/FluidAudio/blob/v0.17.7/Package@swift-6.2.swift)
- [ASR-Einstieg im Release](https://github.com/FluidInference/FluidAudio/blob/v0.17.7/Documentation/ASR/GettingStarted.md)
- [Diarizer-Dokumentation im Release](https://github.com/FluidInference/FluidAudio/blob/v0.17.7/Documentation/Diarization/GettingStarted.md)
- [ASR-Modellkarte](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml/blob/7dd20fe6b1797d35f5e3307e8b1732d9a178edfe/README.md)
- [Diarizer-Hinweise](https://huggingface.co/FluidInference/speaker-diarization-coreml/blob/df2625ac79a7ac6b65ad868fee6d80f320da4232/NOTICE.md)
- [Diarizer-Herkunft](https://huggingface.co/FluidInference/speaker-diarization-coreml/blob/df2625ac79a7ac6b65ad868fee6d80f320da4232/PROVENANCE.md)
