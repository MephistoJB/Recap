import SwiftUI
import OwlCore

struct LibraryView: View {
    @Bindable var model: AppModel
    @State private var deletion: Recording?
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "waveform.circle.fill").font(.largeTitle).foregroundStyle(.tint)
                    VStack(alignment: .leading) {
                        Text("Owl").font(.title2.bold())
                        Text("Deine Gespräche auf dem Mac").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding()
                List(selection: $model.selection) {
                    ForEach(model.filtered) { item in
                        RecordingRow(item: item).tag(item.uuid)
                            .contextMenu {
                                Button("Erneut verarbeiten") { model.retry(item) }
                                    .disabled(item.state == .processing || item.state == .receiving)
                                Button("Im Finder anzeigen") { NSWorkspace.shared.activateFileViewerSelecting([model.paths.audio.appendingPathComponent(item.audioName)]) }
                                    .disabled(item.audioName.isEmpty)
                                Button("Löschen …", role: .destructive) { deletion = item }
                                    .disabled(item.state == .processing || item.state == .receiving)
                            }
                    }
                }.searchable(text: $model.search, prompt: "Gespräche durchsuchen")
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Label(model.modelsReady ? "Transkription bereit" : "Modelle einrichten", systemImage: model.modelsReady ? "checkmark.circle" : "arrow.down.circle")
                    Label(model.receiverStatus, systemImage: model.receiverRunning ? "network" : "network.slash")
                    if model.microphoneRecording != nil { Label("Mikrofonaufnahme läuft", systemImage: "record.circle.fill").foregroundStyle(.red) }
                    SettingsLink { Text("Einstellungen öffnen") }
                }.font(.caption).foregroundStyle(.secondary).padding().frame(maxWidth: .infinity, alignment: .leading)
            }.navigationSplitViewColumnWidth(min: 270, ideal: 310, max: 400)
        } detail: {
            if let item = model.selected { RecordingDetail(model: model, item: item) }
            else {
                ContentUnavailableView {
                    Label("Raum für deine Gespräche", systemImage: "waveform")
                } description: {
                    Text("Importiere eine Aufnahme, starte das Mikrofon oder verbinde deine Watch über den Empfang in den Einstellungen.")
                } actions: {
                    Button("Audio importieren …") { model.chooseImport() }.buttonStyle(.borderedProminent)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { model.chooseImport() } label: { Label("Importieren", systemImage: "square.and.arrow.down") }
                Button {
                    if model.microphoneRecording != nil { model.stopMicrophone() }
                    else { Task { await model.startMicrophone() } }
                } label: { Label(model.microphoneRecording == nil ? "Aufnehmen" : "Aufnahme beenden",
                                 systemImage: model.microphoneRecording == nil ? "mic" : "stop.circle.fill") }
                .tint(model.microphoneRecording == nil ? .accentColor : .red)
            }
        }
        .alert("Owl", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .confirmationDialog("Aufnahme und Transkript dauerhaft löschen?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) {
            Button("Löschen", role: .destructive) { if let deletion { model.delete(deletion) }; deletion = nil }
        } message: { Text("Das Originalaudio und die lokalen Ergebnisse werden entfernt.") }
    }
}

private struct RecordingRow: View {
    var item: Recording
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title).font(.headline).lineLimit(1)
            Text(item.startedAt, format: .dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary)
            HStack {
                if item.state == .processing { ProgressView().controlSize(.mini) }
                Text(item.state.label)
                Spacer()
                if item.duration > 0 { Text(AppModel.time(item.duration)).monospacedDigit() }
            }.font(.caption).foregroundStyle(item.state == .failed ? .red : .secondary)
        }.padding(.vertical, 6)
    }
}
