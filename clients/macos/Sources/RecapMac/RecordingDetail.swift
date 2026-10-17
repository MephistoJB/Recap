import SwiftUI
import RecapCore

struct RecordingDetail: View {
    var model: AppModel
    @Bindable var item: Recording
    @AppStorage("owl.ollamaURL") private var ollamaURL = "http://127.0.0.1:11434"
    @AppStorage("owl.ollamaModel") private var ollamaModel = "qwen3-vl:30b-a3b-instruct-q4_K_M"

    private struct Paragraph: Identifiable {
        var id: Int; var speaker: String?; var start: Double; var text: String
    }
    private var paragraphs: [Paragraph] {
        var result: [Paragraph] = []
        var count = 0
        for word in item.transcript?.words ?? [] {
            if let previous = result.last, previous.speaker == word.speaker, count < 45 {
                result[result.count - 1].text += " " + word.text; count += 1
            } else {
                result.append(Paragraph(id: word.id, speaker: word.speaker, start: word.start, text: word.text)); count = 1
            }
        }
        return result
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Titel", text: $item.title).textFieldStyle(.plain).font(.largeTitle.bold())
                        .onSubmit { model.save() }
                        .onChange(of: item.title) { _, _ in item.revision += 1; model.save() }
                    HStack {
                        Label(item.startedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        Text("·")
                        Text(item.source == "apple_watch" ? "Apple Watch" : item.source == "mac_microphone" ? "Mac-Mikrofon" : "Import")
                        Spacer()
                        Text(item.state.label)
                    }.font(.subheadline).foregroundStyle(.secondary)
                    if item.source == "import" {
                        DatePicker("Aufnahmezeit", selection: $item.startedAt)
                            .onChange(of: item.startedAt) { _, _ in item.timeIsEstimated = false; item.revision += 1; model.save() }
                        if item.timeIsEstimated {
                            Text("Zeitpunkt beim Import gesetzt. Passe ihn an die tatsächliche Aufnahmezeit an.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Button { model.togglePlayback(item) } label: {
                            Label(model.playingID == item.uuid ? "Pause" : "Anhören", systemImage: model.playingID == item.uuid ? "pause.fill" : "play.fill")
                        }.disabled(item.audioName.isEmpty || item.state == .receiving)
                        if item.duration > 0 { Text(AppModel.time(item.duration)).monospacedDigit().foregroundStyle(.secondary) }
                        Spacer()
                        Menu("Exportieren", systemImage: "square.and.arrow.up") {
                            Button("Transkript als Text …") { model.export(item, json: false) }
                            Button("Gespräch mit Herkunft als JSON …") { model.export(item, json: true) }
                        }.disabled(item.transcript == nil)
                    }
                }
                if let error = item.errorMessage { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).textSelection(.enabled) }
                if item.state == .queued && !model.modelsReady {
                    GroupBox("Für die Verarbeitung fehlen die Modelle") {
                        VStack(alignment: .leading) {
                            Text("Deine Aufnahme ist gespeichert. Richte die lokalen Modelle ein, um sie zu transkribieren.")
                            Button("Modelle einrichten") { model.installModels() }.disabled(model.installing)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                    }
                }
                if item.state == .processing { ProgressView("Text und Sprecher werden lokal verarbeitet …").frame(maxWidth: .infinity).padding() }
                if let transcript = item.transcript {
                    summarySection
                    speakerSection(transcript)
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Transkript").font(.title2.bold())
                            Spacer()
                            Button("Erneut verarbeiten") { model.retry(item) }.disabled(item.state == .processing)
                        }
                        Text("\(transcript.engine) · \(String(format: "%.1f", transcript.elapsed)) Sekunden Verarbeitung")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(paragraphs) { paragraph in
                            HStack(alignment: .top, spacing: 16) {
                                Button(AppModel.time(paragraph.start)) { model.togglePlayback(item, at: paragraph.start) }
                                    .buttonStyle(.plain).font(.caption.monospacedDigit()).foregroundStyle(.tint).frame(width: 48)
                                    .accessibilityLabel("Audio ab \(AppModel.time(paragraph.start)) abspielen")
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(paragraph.speaker.map { item.speakerNames[$0] ?? "Sprecher \($0)" } ?? "Sprecher unbekannt")
                                        .font(.caption.bold()).foregroundStyle(.secondary)
                                    Text(paragraph.text).textSelection(.enabled).lineSpacing(5)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                } else if item.state == .failed || item.state == .interrupted {
                    Button("Verarbeitung erneut starten") { model.retry(item) }.buttonStyle(.borderedProminent)
                } else if item.state == .receiving {
                    Label("Audio wird gespeichert. Die Verarbeitung beginnt nach Abschluss der Aufnahme.", systemImage: "waveform")
                        .foregroundStyle(.secondary)
                }
            }.padding(32).frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
    private var summarySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Zusammenfassung", systemImage: "text.alignleft").font(.headline)
                    Spacer()
                    if model.summaryBusy.contains(item.uuid) { ProgressView().controlSize(.small) }
                    Button(item.summary == nil ? "Erstellen" : "Aktualisieren") { model.summarize(item, baseURL: ollamaURL, model: ollamaModel) }
                        .disabled(model.summaryBusy.contains(item.uuid))
                }
                Text(item.summary ?? "Auf Wunsch mit deinem konfigurierten Ollama-Modell erstellen.").textSelection(.enabled)
                    .foregroundStyle(item.summary == nil ? .secondary : .primary)
                if let error = item.summaryError { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func speakerSection(_ transcript: Transcript) -> some View {
        DisclosureGroup("Sprecher und Referenzvergleich") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Stimmenähnlichkeit ist keine bestätigte Identität. Namen werden nur durch deine Zuordnung vergeben.")
                    .font(.caption).foregroundStyle(.secondary)
                if let issue = transcript.speakerIssue { Text(issue).font(.caption).foregroundStyle(.orange) }
                ForEach(transcript.embeddings.keys.sorted(), id: \.self) { speaker in
                    HStack {
                        Text(speaker).font(.body.monospaced()).frame(width: 50)
                        TextField("Name zuordnen", text: Binding(get: { item.speakerNames[speaker] ?? "" }, set: { name in
                            var names = item.speakerNames
                            if name.trimmingCharacters(in: .whitespaces).isEmpty { names.removeValue(forKey: speaker) } else { names[speaker] = name }
                            item.speakerNames = names; item.revision += 1; model.save()
                        }))
                        if let score = transcript.referenceScores[speaker] { Text(String(format: "Ähnlichkeit %.3f", score)).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if transcript.referenceScores.isEmpty { Text("Kein verwendbarer Referenzvergleich vorhanden.").font(.caption).foregroundStyle(.secondary) }
                if let issue = transcript.referenceIssue { Text(issue).font(.caption).foregroundStyle(.orange) }
            }.padding(.top, 12)
        }
    }
}
