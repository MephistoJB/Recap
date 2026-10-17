import Foundation
import RecapCore

@main struct RecapDoctor {
    @MainActor static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            guard args.count >= 2 else { throw RecapError.invalid("Usage: RecapDoctor install|process|serve|inspect ROOT [AUDIO|PORT]") }
            let paths = try RecapPaths(root: URL(fileURLWithPath: args[1], isDirectory: true))
            switch args[0] {
            case "install":
                let reuse = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Owl/Experiments/FluidAudio/models")
                let installer = ModelInstaller()
                try await installer.install(to: paths.models, reuse: reuse) { status in print(status) }
                try await installer.verify(paths.models)
                print("MODELS_VERIFIED")
            case "process":
                guard args.count == 3 else { throw RecapError.invalid("Audio path required") }
                let store = try LibraryStore(paths: paths)
                let item = try store.importAudio(URL(fileURLWithPath: args[2]))
                item.state = .processing; try store.save()
                do {
                    let transcript = try await TranscriptionEngine().process(audio: paths.audio.appendingPathComponent(item.audioName),
                        modelRoot: paths.models, reference: nil)
                    item.transcript = transcript; item.duration = transcript.duration; item.state = .completed
                    try store.save()
                    print("COMPLETED words=\(transcript.words.count) duration=\(transcript.duration) uuid=\(item.uuid)")
                } catch { item.state = .failed; item.errorMessage = error.localizedDescription; try store.save(); throw error }
            case "serve":
                guard args.count == 3, let port = Int(args[2]), let token = ProcessInfo.processInfo.environment["RECAP_API_TOKEN"] else {
                    throw RecapError.invalid("Port and RECAP_API_TOKEN required")
                }
                let store = try LibraryStore(paths: paths); try store.recover()
                try await UploadServer.run(store: store, host: "127.0.0.1", port: port, token: token,
                                          onRunning: { FileHandle.standardOutput.write(Data("LISTENING\n".utf8)) }, onChange: {})
            case "inspect":
                let store = try LibraryStore(paths: paths)
                for item in try store.all() { print("\(item.uuid) \(item.state.rawValue) words=\(item.transcript?.words.count ?? 0)") }
            default: throw RecapError.invalid("Unknown command")
            }
        } catch { FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1) }
    }
}
