import SwiftUI

struct SettingsView: View {
    @Binding var isStreaming: Bool
    @Binding var isUploading: Bool
    @AppStorage(ConnectionSettings.addressKey) private var address = ""
    @ObservedObject private var upload = UploadStatus.shared

    var body: some View {
        Form {
            Section("Mac-Verbindung") {
                Text(address.isEmpty ? "Auf dem iPhone einrichten und an Watch senden" : address)
                    .font(.footnote)
                Text(ConnectionSettings.isConfigured ? "Verbindung gespeichert" : "Verbindung fehlt")
                    .font(.footnote)
            }
            Section("Übertragung") {
                Toggle("Upload nach Aufnahmeende", isOn: $isUploading)
                Text(upload.message).font(.footnote)
                Text("Lokale Audiodateien: \(upload.pendingChunks)").font(.footnote)
                Text("Live-Streaming ist für diesen Ablauf deaktiviert.").font(.footnote).foregroundStyle(.secondary)
            }
        }.onAppear { isStreaming = false }
    }
}

#Preview {
    SettingsView(isStreaming: .constant(false), isUploading: .constant(true))
}
