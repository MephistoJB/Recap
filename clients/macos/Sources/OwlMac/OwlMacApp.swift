import SwiftUI
import OwlCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model?.stopMicrophone()
        model?.stopReceiver()
        return .terminateNow
    }
}

@main struct OwlMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: AppModel?
    private let startupError: String?
    init() {
        do {
            // Isolated paths are useful for development without touching the real library.
            let root = ProcessInfo.processInfo.environment["OWL_DATA_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            _model = State(initialValue: try AppModel(root: root)); startupError = nil
        } catch { startupError = error.localizedDescription }
    }
    var body: some Scene {
        WindowGroup("Recap") {
            if let model {
                LibraryView(model: model)
                    .frame(minWidth: 900, minHeight: 580)
                    .task { delegate.model = model; await model.start() }
            } else {
                ContentUnavailableView("Bibliothek konnte nicht geöffnet werden", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text(startupError ?? "Unbekannter Fehler"))
                    .frame(width: 600, height: 350)
            }
        }
        .defaultSize(width: 1150, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Audio importieren …") { model?.chooseImport() }.keyboardShortcut("o")
                Button(model?.microphoneRecording == nil ? "Aufnahme starten" : "Aufnahme beenden") {
                    guard let model else { return }
                    if model.microphoneRecording == nil { Task { await model.startMicrophone() } }
                    else { model.stopMicrophone() }
                }.keyboardShortcut("r")
            }
        }
        Settings {
            if let model { SettingsView(model: model).frame(width: 650, height: 570) }
        }
    }
}
