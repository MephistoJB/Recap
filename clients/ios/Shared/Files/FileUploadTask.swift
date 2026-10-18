// Upload completed recordings in order; retain every file until HTTP acknowledgement.
import Foundation
import os

private var uploadAllowed = true
private var taskRunning = false
private var didRecover = false
private let logger = Logger()
private func log(_ message: String) { logger.notice("[FileUploadTask] \(message, privacy: .public)") }

@MainActor
func runFileUploadTask(fileExtension: String) async {
    guard !taskRunning else { return }
    taskRunning = true
    defer { taskRunning = false }
    if !didRecover {
        recoverInterruptedCaptures(fileExtension: fileExtension)
        didRecover = true
    }
    while !Task.isCancelled {
        await runFileUploadPass(fileExtension: fileExtension)
        do { try await Task.sleep(for: .seconds(5)) } catch { return }
    }
}

func setUploadAllowed(to allowed: Bool) { uploadAllowed = allowed }

func markCaptureComplete(_ captureUUID: String, directory: URL = .documents) {
    let url = directory.appendingPathComponent("\(captureUUID).end")
    if !FileManager.default.fileExists(atPath: url.path) {
        if !FileManager.default.createFile(atPath: url.path, contents: nil) {
            log("Abschlussmarker konnte nicht gespeichert werden")
        }
    }
}

// Only called once when the process starts, before a new capture is started.
// PCM contains complete 16-bit mono samples. Preserve unaligned/empty fragments for recovery.
func recoverInterruptedCaptures(fileExtension: String, directory: URL = .documents) {
    let unfinished = audioFiles(fileExtension: "\(fileExtension)-wip", directory: directory)
    for url in unfinished where fileExtension == "pcm" {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size.isMultiple(of: 2) else { continue }
        let final = url.deletingPathExtension().appendingPathExtension(fileExtension)
        guard !FileManager.default.fileExists(atPath: final.path) else { continue }
        do { try FileManager.default.moveItem(at: url, to: final) }
        catch { log("Unterbrochene Aufnahme bleibt zur Wiederherstellung erhalten") }
    }
    for url in audioFiles(fileExtension: fileExtension, directory: directory) + unfinished {
        if let id = AudioFileWriter.getCaptureUUID(from: url) { markCaptureComplete(id, directory: directory) }
    }
}

@MainActor
func runFileUploadPass(fileExtension: String, directory: URL = .documents, session: URLSession = .shared) async {
    let chunks = audioFiles(fileExtension: fileExtension, directory: directory)
    let partials = audioFiles(fileExtension: "\(fileExtension)-wip", directory: directory)
    UploadStatus.shared.pendingChunks = chunks.count + partials.count
    guard uploadAllowed else { UploadStatus.shared.message = "Upload pausiert · Dateien bleiben auf der Watch"; return }
    guard ConnectionSettings.isConfigured else { UploadStatus.shared.message = "Verbindung auf dem iPhone einrichten"; return }
    let completed = completedIDs(directory: directory)
    let groups = Dictionary(grouping: chunks, by: { AudioFileWriter.getCaptureUUID(from: $0)! })
    var failed = false
    for id in completed {
        guard !Task.isCancelled else { return }
        // A partial chunk must be recovered before processing. Do not discard it.
        guard !partials.contains(where: { AudioFileWriter.getCaptureUUID(from: $0) == id }) else {
            UploadStatus.shared.message = "Unterbrochene Aufnahme erhalten · Wiederherstellung erforderlich"
            failed = true
            continue
        }
        var allUploaded = true
        for url in groups[id] ?? [] {
            UploadStatus.shared.message = "Aufnahme wird zum Mac übertragen …"
            if await uploadFile(url, contentType: "audio/\(fileExtension)", session: session) {
                do { try FileManager.default.removeItem(at: url) }
                catch { allUploaded = false; failed = true; break }
            } else { allUploaded = false; failed = true; break }
        }
        if allUploaded {
            UploadStatus.shared.message = "Verarbeitung auf dem Mac anfordern …"
            if await processCapture(id, session: session) {
                do { try FileManager.default.removeItem(at: directory.appendingPathComponent("\(id).end")) }
                catch { failed = true }
            } else { failed = true }
        }
    }
    let pending = audioFiles(fileExtension: fileExtension, directory: directory).count + partials.count
    UploadStatus.shared.pendingChunks = pending
    if !failed {
        UploadStatus.shared.message = pending == 0 ? "Übertragung abgeschlossen · Gespräche auf dem iPhone aktualisieren" : "Aufnahme lokal gespeichert · Upload nach Aufnahmeende"
    }
}

private func acknowledged(_ request: URLRequest, body: Data, session: URLSession) async -> Bool {
    do {
        let (_, response) = try await session.upload(for: request, from: body)
        guard let response = response as? HTTPURLResponse else {
            await reportFailure("Keine gültige Serverantwort · Dateien bleiben gespeichert")
            return false
        }
        guard (200...299).contains(response.statusCode) else {
            await reportFailure("HTTP \(response.statusCode) · Dateien bleiben gespeichert, erneuter Versuch folgt")
            return false
        }
        return true
    } catch {
        // Do not log request URLs or credentials from errors.
        await reportFailure("Mac nicht erreichbar · Dateien bleiben gespeichert, erneuter Versuch folgt")
        return false
    }
}

@MainActor private func reportFailure(_ message: String) { UploadStatus.shared.message = message }

private func uploadFile(_ file: URL, contentType: String, session: URLSession) async -> Bool {
    guard AudioFileWriter.isValid(url: file), let fileData = try? Data(contentsOf: file),
          let capture = AudioFileWriter.getCaptureUUID(from: file),
          let timestamp = AudioFileWriter.getTimestamp(from: file),
          let url = ConnectionSettings.endpoint("capture/upload_chunk") else { return false }
    let form = MultipartForm(fields: [
        .init(name: "file", filename: file.lastPathComponent, contentType: contentType, data: fileData),
        .init(name: "capture_uuid", text: capture), .init(name: "timestamp", text: timestamp),
        .init(name: "device_type", text: "apple_watch")
    ])
    return await acknowledged(request(url, form: form), body: form.serialize(), session: session)
}

private func processCapture(_ id: String, session: URLSession) async -> Bool {
    guard let url = ConnectionSettings.endpoint("capture/process_capture") else { return false }
    let form = MultipartForm(fields: [.init(name: "capture_uuid", text: id)])
    return await acknowledged(request(url, form: form), body: form.serialize(), session: session)
}

private func request(_ url: URL, form: MultipartForm) -> URLRequest {
    var request = URLRequest(url: url)
    request.addCommonHeaders()
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.setValue("multipart/form-data;boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
    return request
}

private func completedIDs(directory: URL) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension == "end" }
        .map { $0.deletingPathExtension().lastPathComponent }
        .filter { $0.count == 32 && $0.allSatisfy(\.isHexDigit) }.sorted()
}

func audioFiles(fileExtension: String, directory: URL = .documents) -> [URL] {
    ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension == fileExtension && AudioFileWriter.isValid(url: $0) }
        .sorted {
            let a = AudioFileWriter.getTimestamp(from: $0)!
            let b = AudioFileWriter.getTimestamp(from: $1)!
            if a != b { return a < b }
            let ca = AudioFileWriter.getCaptureUUID(from: $0)!
            let cb = AudioFileWriter.getCaptureUUID(from: $1)!
            if ca != cb { return ca < cb }
            return AudioFileWriter.getChunkNumber(from: $0)! < AudioFileWriter.getChunkNumber(from: $1)!
        }
}
