//
//  ContentView.swift
//  Recap
//
//  Created by ethan on 1/13/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ConversationsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationView {
            ConversationsView(viewModel: viewModel)
                .navigationTitle("Conversations")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        NavigationLink(destination: ConnectionSettingsView()) {
                            Label("Verbindung", systemImage: "gearshape")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) { BadgeView() }
                }
                .overlay {
                    if !ConnectionSettings.isConfigured && viewModel.conversations.isEmpty {
                        VStack(spacing: 12) {
                            Text("Verbinde Recap mit deinem Mac").font(.headline)
                            NavigationLink("Verbindung einrichten", destination: ConnectionSettingsView())
                            Text("Watch-Aufnahmen erscheinen nach der Übertragung und Verarbeitung auf dem Mac.")
                                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }.padding()
                    }
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: ConnectionSettings.changed)) { _ in viewModel.fetchConversations() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.fetchConversations() }
        }
    }

}

struct BadgeView: View {
    @ObservedObject var captureManager = CaptureManager.shared
    @ObservedObject var bleManager = BLEManager.shared

    var body: some View {
        Group {
            if let deviceName = captureManager.currentCapture?.deviceName {
                DeviceBannerView(deviceName: deviceName, batteryLevel: bleManager.batteryLevel, isCharging: bleManager.isCharging, isAwaitingReconnection: captureManager.isAwaitingReconnection)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
