import SwiftUI
import OwlCore
import AVFoundation
import UniformTypeIdentifiers

@MainActor @Observable final class AppModel: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    let store: LibraryStore
    let paths: OwlPaths
    var recordings: [Recording] = []
    var selection: String?
    var search = ""
    var error: String?
    var modelStatus = "Modelle noch nicht eingerichtet"
    var modelsReady = false
    var installing = false
    var receiverStatus = "Ausgeschaltet"
    var receiverRunning = false
    var receiverStarting = false
    var microphoneRecording: Recording?
    var player: AVAudioPlayer?
    var playingID: String?
    var summaryBusy: Set<String> = []
    var referencePresent = false
    private var recorder: AVAudioRecorder?
    private var loadedAudioID: String?
    private let engine = TranscriptionEngine()
    private let installer = ModelInstaller()
    private var worker: Task<Void, Never>?
    private var receiver: Task<Void, Never>?

    init(root: URL? = nil) throws {
        paths = try OwlPaths(root: root)
        store = try LibraryStore(paths: paths)
        super.init()
        try store.recover()
        referencePresent = FileManager.default.fileExists(atPath: paths.reference.path)
        refresh()
        selection = recordings.first?.uuid
    }
    var selected: Recording? { recordings.first { $0.uuid == selection } }
    var filtered: [Recording] {
        recordings.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
            || ($0.transcript?.text.localizedCaseInsensitiveContains(search) ?? false) }
    }
    func start() async {
        do {
            if ModelInstaller.isReady(paths.models) {
                modelStatus = "Modelle werden geprüft …"
                try await installer.verify(paths.models)
                modelsReady = true; modelStatus = "Lokale Modelle bereit"
                processPending()
            }
        } catch { self.error = error.localizedDescription; modelStatus = "Modellprüfung fehlgeschlagen" }
    }
    func refresh() {
        do { recordings = try store.all() } catch { self.error = error.localizedDescription }
    }
    func save() { do { try store.save(); refresh() } catch { self.error = error.localizedDescription } }
    func processPending() {
        refresh()
        guard worker == nil, modelsReady else { return }
        worker = Task {
            defer { worker = nil }
            while !Task.isCancelled {
                guard let item = recordings.last(where: { $0.state == .queued }) else { return }
                do {
                    item.state = .processing; item.errorMessage = nil; try store.save(); refresh()
                    let result = try await engine.process(audio: paths.audio.appendingPathComponent(item.audioName),
                        modelRoot: paths.models, reference: referencePresent ? paths.reference : nil)
                    try Task.checkCancellation()
                    item.transcript = result; item.duration = result.duration
                    item.speakerNames = [:] // Cluster IDs can change between transcription runs.
                    item.summary = nil; item.summaryModel = nil; item.summaryError = nil
                    item.state = .completed; item.errorMessage = nil; item.revision += 1
                    try store.save()
                } catch is CancellationError {
                    item.state = .queued; try? store.save(); refresh(); return
                } catch {
                    item.state = .failed; item.errorMessage = error.localizedDescription
                    do { try store.save() } catch { self.error = error.localizedDescription; refresh(); return }
                }
                refresh()
            }
        }
    }
    func retry(_ item: Recording) {
        guard item.state != .processing, item.state != .receiving else { return }
        item.state = .queued; item.errorMessage = nil; save(); processPending()
    }
    func importFiles(_ urls: [URL]) {
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do { let item = try store.importAudio(url); selection = item.uuid }
            catch { self.error = error.localizedDescription }
        }
        processPending()
    }
    func chooseImport() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.audio]; panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { importFiles(panel.urls) }
    }
    func installModels() {
        guard !installing else { return }; installing = true
        Task {
            defer { installing = false }
            do {
                let previous = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support/Owl/Experiments/FluidAudio/models")
                try await installer.install(to: paths.models, reuse: previous) { [weak self] status in
                    await MainActor.run { self?.modelStatus = status }
                }
                try await installer.verify(paths.models)
                modelsReady = true; modelStatus = "Lokale Modelle bereit"; processPending()
            } catch { self.error = error.localizedDescription; modelStatus = "Einrichtung fehlgeschlagen – erneuter Versuch möglich" }
        }
    }
    func startMicrophone() async {
        guard recorder == nil else { return }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            error = "Mikrofonzugriff ist nicht erlaubt. Bitte unter Systemeinstellungen → Datenschutz → Mikrofon freigeben."
            return
        }
        var pending: Recording?
        do {
            let uuid = UUID().uuidString.lowercased(), name = UUID().uuidString + ".m4a"
            let item = try store.insert(title: "Mac-Aufnahme", source: "mac_microphone", uuid: uuid,
                                        state: .receiving, audioName: name)
            pending = item
            let recording = try AVAudioRecorder(url: paths.audio.appendingPathComponent(name), settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            recording.delegate = self
            guard recording.record() else { throw OwlError.invalid("Mikrofonaufnahme konnte nicht gestartet werden.") }
            recorder = recording; microphoneRecording = item; selection = item.uuid; refresh()
        } catch {
            pending?.state = .failed; pending?.errorMessage = error.localizedDescription
            self.error = error.localizedDescription; save()
        }
    }
    func stopMicrophone() {
        guard let recording = recorder, let item = microphoneRecording else { return }
        item.duration = recording.currentTime
        recording.stop(); recorder = nil; microphoneRecording = nil
        item.state = .queued; save(); processPending()
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        let message = error?.localizedDescription ?? "Audioaufnahme wurde unterbrochen."
        let recorderID = ObjectIdentifier(recorder)
        Task { @MainActor in
            guard let active = self.recorder, ObjectIdentifier(active) == recorderID else { return }
            if let item = self.microphoneRecording {
                item.state = .interrupted; item.errorMessage = message
            }
            self.recorder?.stop(); self.recorder = nil; self.microphoneRecording = nil
            self.error = message; self.save()
        }
    }
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let recorderID = ObjectIdentifier(recorder)
        Task { @MainActor in
            guard let active = self.recorder, ObjectIdentifier(active) == recorderID,
                  let item = self.microphoneRecording else { return }
            item.state = .interrupted
            item.errorMessage = flag ? "Die Mikrofonaufnahme wurde beendet. Vorhandenes Audio kann verarbeitet werden." : "Die Mikrofonaufnahme wurde unterbrochen."
            self.recorder = nil; self.microphoneRecording = nil; self.save()
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let playerID = ObjectIdentifier(player)
        Task { @MainActor in
            guard let active = self.player, ObjectIdentifier(active) == playerID else { return }
            self.playingID = nil; self.player = nil; self.loadedAudioID = nil
        }
    }
    func togglePlayback(_ item: Recording, at seconds: Double? = nil) {
        do {
            if playingID == item.uuid, let player, player.isPlaying, seconds == nil { player.pause(); playingID = nil; return }
            if loadedAudioID != item.uuid || player == nil {
                player?.stop()
                player = try AVAudioPlayer(contentsOf: paths.audio.appendingPathComponent(item.audioName))
                loadedAudioID = item.uuid
            }
            player?.delegate = self
            if let seconds { player?.currentTime = seconds }
            guard player?.play() == true else { throw OwlError.invalid("Audio kann nicht abgespielt werden.") }
            playingID = item.uuid
        } catch { self.error = error.localizedDescription }
    }
    func delete(_ item: Recording) {
        guard item.state != .processing, item.state != .receiving else { return }
        do {
            if loadedAudioID == item.uuid { player?.stop(); player = nil; playingID = nil; loadedAudioID = nil }
            try store.remove(item); if selection == item.uuid { selection = nil }; refresh()
        } catch { self.error = error.localizedDescription }
    }
    func chooseReference() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.audio]
        guard panel.runModal() == .OK, let source = panel.url else { return }
        do {
            let access = source.startAccessingSecurityScopedResource(); defer { if access { source.stopAccessingSecurityScopedResource() } }
            try AudioFiles.assemble([source], format: "wav", to: paths.reference)
            referencePresent = true
        } catch { self.error = error.localizedDescription }
    }
    func startReceiver(host: String, port: Int, token: String) {
        guard receiver == nil, (1024...65535).contains(port), !token.isEmpty else {
            error = "Bitte einen Zugriffstoken und einen Port zwischen 1024 und 65535 einstellen."; return
        }
        receiverStarting = true; receiverStatus = "Empfang wird gestartet …"
        receiver = Task { [self] in
            defer { receiver = nil; receiverRunning = false; receiverStarting = false }
            do {
                try await UploadServer.run(store: store, host: host, port: port, token: token,
                    onRunning: { [weak self] in await MainActor.run {
                        self?.receiverRunning = true; self?.receiverStarting = false
                        self?.receiverStatus = "Empfang aktiv · Port \(port)"
                    } }, onChange: { [weak self] in self?.processPending() })
                receiverStatus = "Ausgeschaltet"
            } catch is CancellationError { receiverStatus = "Ausgeschaltet" }
            catch { receiverStatus = "Empfang fehlgeschlagen"; self.error = error.localizedDescription }
        }
    }
    func stopReceiver() { receiver?.cancel(); receiverStatus = "Empfang wird beendet …" }
    func export(_ item: Recording, json: Bool) {
        guard let transcript = item.transcript else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = json ? [.json] : [.plainText]
        panel.nameFieldStringValue = "Recap-\(item.uuid).\(json ? "json" : "txt")"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if json {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(ConversationExport(recording: item, transcript: transcript))
                try data.write(to: url, options: .atomic)
            } else {
                let content = transcript.words.map { "[\(Self.time($0.start))] \($0.speaker.map { item.speakerNames[$0] ?? $0 } ?? "Unbekannt"): \($0.text)" }.joined(separator: "\n")
                try (item.title + "\n\n" + content).write(to: url, atomically: true, encoding: .utf8)
            }
        } catch { self.error = error.localizedDescription }
    }
    func summarize(_ item: Recording, baseURL: String, model: String) {
        guard let transcript = item.transcript, !summaryBusy.contains(item.uuid) else { return }
        let uuid = item.uuid
        let revision = item.revision
        summaryBusy.insert(uuid)
        Task {
            defer { summaryBusy.remove(uuid) }
            do {
                let result = try await SummaryService.summarize(transcript.text, baseURL: baseURL, model: model)
                guard let current = try store.find(uuid), current.revision == revision else { return }
                current.summary = result; current.summaryModel = model; current.summaryError = nil; save()
            } catch {
                guard let current = try? store.find(uuid), current.revision == revision else { return }
                current.summaryError = error.localizedDescription; save()
            }
        }
    }
    static func time(_ seconds: Double) -> String { String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
}

struct ConversationExport: Encodable {
    var schemaVersion = 1
    var conversationID: String; var revision: Int; var startedAt: Date
    var timezone: String; var timeIsEstimated: Bool; var source: String; var title: String; var summary: String?
    var speakerNames: [String: String]; var transcript: Transcript
    var originalAudio: String
    init(recording: Recording, transcript: Transcript) {
        conversationID = recording.uuid; revision = recording.revision; startedAt = recording.startedAt
        timezone = recording.timezoneID; timeIsEstimated = recording.timeIsEstimated
        source = recording.source; title = recording.title
        summary = recording.summary; speakerNames = recording.speakerNames
        originalAudio = recording.audioName
        var portable = transcript
        portable.embeddings = [:] // Exports contain provenance, not raw voice profiles.
        self.transcript = portable
    }
}
