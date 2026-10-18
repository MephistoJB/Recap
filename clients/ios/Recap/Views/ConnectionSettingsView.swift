import SwiftUI

struct ConnectionSettingsView: View {
    @State private var address = ConnectionSettings.address
    @State private var token = ConnectionSettings.token
    @State private var status = ""
    @State private var checking = false
    @ObservedObject private var watch = WatchConnectivityManager.shared

    var body: some View {
        Form {
            Section("Mac-Verbindung") {
                TextField("http://macserver.local:8012", text: $address)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("serverAddress")
                SecureField("Zugriffstoken vom Mac", text: $token)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("serverToken")
                Button("Speichern") {
                    do { try ConnectionSettings.save(address: address, token: token); status = "Auf dem iPhone gespeichert" }
                    catch { status = error.localizedDescription }
                }
                Button("Verbindung prüfen") { Task { await checkConnection() } }.disabled(checking)
                if checking { ProgressView() }
                if !status.isEmpty { Text(status).font(.footnote) }
            }
            Section("Apple Watch") {
                Button("Gespeicherte Verbindung an Watch senden") {
                    do { try watch.sendConnectionSettings() }
                    catch { watch.configurationStatus = error.localizedDescription }
                }.disabled(!ConnectionSettings.isConfigured)
                Text(watch.configurationStatus).font(.footnote)
                Text("Öffne Recap auf der Watch. Die Einstellungen werden über die gekoppelte Verbindung übertragen. Die Watch zeigt an, sobald sie gespeichert sind.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Text("Starte in Recap auf dem Mac den Empfang. Übernimm dessen Adresse und Zugriffstoken. Lokales HTTP ist nur für dein vertrauenswürdiges Heimnetz vorgesehen.")
                Text("Die Watch bewahrt Aufnahmen bis zur bestätigten Übertragung auf. Nach Aufnahmeende verarbeitet der Mac das Gespräch; aktualisiere danach die Gesprächsliste.")
            }.font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Verbindung")
    }

    @MainActor private func checkConnection() async {
        checking = true
        defer { checking = false }
        do {
            try ConnectionSettings.save(address: address, token: token)
            guard let url = ConnectionSettings.endpoint("conversations") else { return }
            var request = URLRequest(url: url)
            request.addCommonHeaders()
            request.timeoutInterval = 15
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            status = (200...299).contains(code) ? "Mac erreichbar · Zugriff bestätigt" : "Verbindung fehlgeschlagen (HTTP \(code)). Adresse und Token prüfen."
        } catch { status = "Verbindung fehlgeschlagen. Adresse, Token, Mac-Empfang und lokalen Netzwerkzugriff prüfen." }
    }
}
