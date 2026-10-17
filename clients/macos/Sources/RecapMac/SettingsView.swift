import SwiftUI
import RecapCore

struct SettingsView: View {
    @Bindable var model: AppModel
    @AppStorage("owl.receiverHost") private var host = "0.0.0.0"
    @AppStorage("owl.receiverPort") private var port = 8012
    @AppStorage("owl.ollamaURL") private var ollamaURL = "http://127.0.0.1:11434"
    @AppStorage("owl.ollamaModel") private var ollamaModel = "qwen3-vl:30b-a3b-instruct-q4_K_M"
    @State private var token = ""
    @State private var tokenLoaded = false
    var body: some View {
        TabView {
            Form {
                Section("Lokale Spracherkennung") {
                    LabeledContent("Engine", value: "FluidAudio · Parakeet v3 INT8-v2")
                    Text(model.modelStatus).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                    if model.installing { ProgressView() }
                    Button(model.modelsReady ? "Modelle prüfen und vervollständigen" : "Modelle einrichten (ca. 654 MB)") { model.installModels() }
                        .disabled(model.installing)
                    Text("Vorhandene geprüfte Modelle werden übernommen. Fehlende Dateien werden von Hugging Face ohne Login geladen. Audio bleibt auf dem Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Deine Stimme") {
                    LabeledContent("Referenz", value: model.referencePresent ? "Aufnahme hinterlegt" : "Keine Aufnahme hinterlegt")
                    Button("Referenzaufnahme auswählen …") { model.chooseReference() }
                    Text("Wähle eine Aufnahme nur deiner Stimme. Neue Transkriptionen zeigen Ähnlichkeitswerte; die Namenszuordnung bestätigst du selbst.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).tabItem { Label("Audio", systemImage: "waveform") }
            Form {
                Section("Empfang von Watch und iPhone") {
                    TextField("Bind-Adresse", text: $host).disabled(model.receiverRunning || model.receiverStarting)
                    TextField("Port", value: $port, format: .number.grouping(.never)).disabled(model.receiverRunning || model.receiverStarting)
                    SecureField("Zugriffstoken", text: $token).disabled(model.receiverRunning || model.receiverStarting)
                    HStack {
                        Button("Neuen Token erzeugen") {
                            do { token = try Keychain.makeToken(); try Keychain.write(token, account: "uploadToken") }
                            catch { model.error = error.localizedDescription }
                        }.disabled(model.receiverRunning || model.receiverStarting)
                        Button("Token kopieren") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(token, forType: .string) }.disabled(token.isEmpty)
                    }
                    HStack {
                        Text(model.receiverStatus).foregroundStyle(.secondary)
                        Spacer()
                        if model.receiverRunning || model.receiverStarting {
                            Button("Empfang beenden") { model.stopReceiver() }
                        } else {
                            Button("Empfang starten") {
                                do { try Keychain.write(token, account: "uploadToken"); model.startReceiver(host: host, port: port, token: token) }
                                catch { model.error = error.localizedDescription }
                            }.disabled(!tokenLoaded || token.isEmpty)
                        }
                    }
                    Text("Die App muss geöffnet und der Mac erreichbar sein. Trage die Mac-Adresse und denselben Token im Recap-Client ein. HTTP-Empfang ist für dein vertrauenswürdiges lokales Netz vorgesehen.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Beispiel: http://macserver:\(String(port))").font(.caption.monospaced())
                }
            }.formStyle(.grouped).tabItem { Label("Verbindung", systemImage: "network") }
            Form {
                Section("Zusammenfassungen mit Ollama") {
                    TextField("Adresse", text: $ollamaURL)
                    TextField("Modellname", text: $ollamaModel)
                    Text("Zusammenfassungen werden nur auf deinen Klick angefordert. Dabei wird das Transkript an diese Adresse gesendet. Ein Ausfall beeinträchtigt das gespeicherte Transkript nicht.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Recap") {
                    Link("Basiert auf Owl · MIT-Lizenz", destination: URL(string: "https://github.com/OwlAIProject/Owl")!)
                }
                Section("Bibliothek") {
                    Text(model.paths.root.path).font(.caption).textSelection(.enabled)
                    Button("Datenordner öffnen") { NSWorkspace.shared.open(model.paths.root) }
                    Text("Originalaudio und Transkripte liegen lokal. Den gesamten Datenordner bei geschlossener App sichern. JSON-Export enthält Gesprächs-ID, Version, Quelle und Sprecherzuordnung für die spätere Hindsight-Anbindung.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).tabItem { Label("Daten & Modelle", systemImage: "externaldrive") }
        }.padding()
        .task {
            do {
                if let existing = try Keychain.read("uploadToken") { token = existing }
                else { token = try Keychain.makeToken(); try Keychain.write(token, account: "uploadToken") }
                tokenLoaded = true
            } catch { model.error = error.localizedDescription }
        }
    }
}
