# OwlAudioProbe

Isolierter, freigegebener macOS-Test fuer die spaetere native Swift-App.
FluidAudio `0.17.7`, Commit `503b4bd1bbf7220882de39fe8ae6716aae4132da`.
Kein Server, keine UI und keine Aenderung bestehender Owl-Aufnahmen.

## Vorbereitung auf macserver

Erfordert Xcode/Swift 6.2+, macOS 14+; getestet wird auf M4 Pro / macOS 27.
Python 3 wird ausschliesslich fuer den Download mit Standardbibliothek verwendet,
nicht fuer die native Inferenz. Keine Python-Pakete installieren.

```bash
cd ~/Documents/Programmierung/Owl/experiments/fluid-audio
swift build -c release
OWL_PROBE_ROOT="$HOME/Library/Application Support/Owl/Experiments/FluidAudio"
mkdir -p "$OWL_PROBE_ROOT"
chmod 700 "$OWL_PROBE_ROOT"
python3 prepare_models.py "$OWL_PROBE_ROOT/models"
```

`prepare_models.py` laedt feste HF-Snapshots ohne Token, prueft Groessen sowie
LFS-SHA256/Git-Blob-SHA1 und legt ein SHA256-Manifest ab. Vorhandene abweichende
Dateien werden nicht ueberschrieben. Der Download enthaelt Attribution/Herkunft.
Die Auswahl umfasst rund 654 MB einschliesslich dieser Begleitdateien.

- ASR: `FluidInference/parakeet-tdt-0.6b-v3-coreml`
  @ `7dd20fe6b1797d35f5e3307e8b1732d9a178edfe`.
- Diarizer: `FluidInference/speaker-diarization-coreml`
  @ `df2625ac79a7ac6b65ad868fee6d80f320da4232`.
- Encoder: explizit `.int8V2` / `Encoder_v2.mlmodelc`. Der Release-Default
  `.int8` erwartet stattdessen die nicht ausgewaehlte Originaldatei.

Das Paket waehlt den NeMo-Textnormalisierungs-Trait ab. SwiftPM kann den
optionalen Binaerartefakt trotzdem waehrend der Aufloesung herunterladen;
der beobachtete Build tat dies (87,3 MB). Das ist zusaetzlich zum Modelldownload.
Ein abgewaehlter Trait ist daher keine Garantie fuer einen downloadfreien Build.

## Lauf

```bash
umask 077
.build/release/OwlAudioProbe \
  "$OWL_PROBE_ROOT/models" \
  /absoluter/pfad/aufnahme.wav \
  "$OWL_PROBE_ROOT/neues-ergebnis.json"
```

Optional vierter Parameter: separate Aufnahme mit genau einer Referenzstimme.
Dann werden Kosinusaehnlichkeiten zu den Gespraechs-Clustern exportiert. Es
erfolgt keine automatische Namensvergabe und keine behauptete Identitaetspruefung.

Das Programm verwendet ausschliesslich lokale Core-ML-Dateien und bricht bei
fehlenden Komponenten ab. ASR sowie Diarisierung laufen nacheinander; die
Messwerte enthalten keinen HTTP-Server oder Python-Inferenzprozess. ASR nutzt
die Bibliotheksvorgaben, Diarisierung `.all`, FBank `.cpuOnly`. Das ist eine
Konfiguration, kein Nachweis, welche Hardware jeden einzelnen Operator ausfuehrt.

Ergebnis: Text, Token-/Wortzeitmarken, Sprechersegmente, Embeddings,
Lade-/Verarbeitungszeiten und optional Referenzvergleich. Das Ergebnis enthaelt
Gespraechsinhalte und Stimmenprofile: ausserhalb von Git aufbewahren. Bereits
vorhandene Ergebnisdateien werden nicht ueberschrieben. Eine fertige Zuordnung
jedes Wortes zu einem Sprecher ist noch kein Teil des Testprogramms.

## Netzwerkgesperrter Test und Speicherbedarf

Auf dem Test-Mac ist `sandbox-exec` vorhanden. Es wird nur pro Testprozess
verwendet; Netzwerk-/Systemeinstellungen werden nicht geaendert:

```bash
/usr/bin/sandbox-exec -p '(version 1)(allow default)(deny network*)' \
  /usr/bin/time -l .build/release/OwlAudioProbe \
  "$OWL_PROBE_ROOT/models" /absoluter/pfad/aufnahme.wav \
  "$OWL_PROBE_ROOT/neues-offline-ergebnis.json"
```

Vor dem Test muss derselbe Sandbox-Aufruf einen TCP-Verbindungsversuch mit
`Operation not permitted` ablehnen. Bei fehlender Sandbox ist ein erfolgreicher
lokaler Lauf allein kein Nachweis fuer den netzwerkgesperrten Betrieb.
`time -l` liefert das maximale RSS des Prozesses; gemeinsam genutzte
System-/ANE-Caches sind damit nicht vollstaendig erfasst.

## Attribution, Ergebnisse und Rueckbau

[Quellen-/Lizenzbefunde](../../docs/proposals/FLUIDAUDIO-PRUEFUNG.md) beachten.
Insbesondere die uneinheitlichen ASR-Lizenzangaben vor einer Weitergabe klaeren.
[Tatsaechliche Testergebnisse](../../docs/FLUIDAUDIO-TESTERGEBNISSE.md) unterscheiden
synthetische Funktionspruefung und echte Qualitaetsabnahme.

Rueckbau: Nach Sichtung nur dieses Experimentverzeichnis und seine eindeutig
zugeordneten Testdaten unter `~/Library/Application Support/Owl/Experiments/FluidAudio/`
entfernen. Keine globalen Swift-/Core-ML-Caches pauschal loeschen und keine
bestehenden Dienste oder den vorbereiteten Komodo-Stack veraendern.
