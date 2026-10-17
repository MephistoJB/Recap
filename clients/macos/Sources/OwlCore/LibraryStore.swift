import Foundation
import SwiftData
import CryptoKit

@MainActor public final class LibraryStore {
    public let container: ModelContainer
    public let context: ModelContext
    public let paths: OwlPaths

    public init(paths: OwlPaths, inMemory: Bool = false) throws {
        self.paths = paths
        let schema = Schema([Recording.self, UploadChunk.self, LibraryCounter.self])
        let config = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: paths.root.appendingPathComponent("Library.store"), cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }
    public func save() throws { try context.save() }
    public func all() throws -> [Recording] {
        try context.fetch(FetchDescriptor<Recording>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
    }
    public func find(_ uuid: String) throws -> Recording? {
        try context.fetch(FetchDescriptor<Recording>(predicate: #Predicate { $0.uuid == uuid })).first
    }
    public func find(apiID: Int) throws -> Recording? {
        try context.fetch(FetchDescriptor<Recording>(predicate: #Predicate { $0.apiID == apiID })).first
    }
    public func nextID() throws -> Int {
        let counter: LibraryCounter
        if let existing = try context.fetch(FetchDescriptor<LibraryCounter>()).first { counter = existing }
        else { counter = LibraryCounter(); counter.nextValue = (try all().map(\.apiID).max() ?? 0) + 1; context.insert(counter) }
        let value = counter.nextValue; counter.nextValue += 1; return value
    }
    public func recover() throws {
        for item in try all() where item.state == .processing {
            item.state = .queued
            item.errorMessage = "Die vorherige Verarbeitung wurde unterbrochen und wird erneut gestartet."
        }
        for item in try all() where item.state == .receiving && item.source == "mac_microphone" {
            item.state = .interrupted
            item.errorMessage = "Die App wurde während der Aufnahme beendet. Vorhandenes Audio prüfen und erneut verarbeiten."
        }
        try save()
    }
    public func insert(title: String, source: String, uuid: String = UUID().uuidString.lowercased(),
                       startedAt: Date = .now, state: ProcessingState = .queued,
                       audioName: String = "") throws -> Recording {
        let item = Recording(uuid: uuid, apiID: try nextID(), title: title,
                             startedAt: startedAt, source: source, state: state, audioName: audioName)
        context.insert(item)
        do { try save(); return item } catch { context.rollback(); throw error }
    }
    public func importAudio(_ source: URL) throws -> Recording {
        let uuid = UUID().uuidString.lowercased()
        let ext = source.pathExtension.lowercased()
        guard ["wav", "m4a", "aac", "aiff", "aif", "mp3", "caf", "flac"].contains(ext) else {
            throw OwlError.invalid("Dieses Audioformat wird nicht unterstützt.")
        }
        let name = uuid + "." + ext
        let destination = paths.audio.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        do {
            return try insert(title: source.deletingPathExtension().lastPathComponent, source: "import", uuid: uuid,
                              audioName: name)
        } catch { try? FileManager.default.removeItem(at: destination); throw error }
    }
    public func chunks(_ uuid: String) throws -> [UploadChunk] {
        try context.fetch(FetchDescriptor<UploadChunk>(predicate: #Predicate { $0.captureUUID == uuid },
                                                    sortBy: [SortDescriptor(\.number)]))
    }
    @discardableResult public func receive(filename: String, uuid: String, timestamp: String,
                                           source: String, data: Data) throws -> Bool {
        let parsed = try ChunkName(filename: filename, uuid: uuid, timestamp: timestamp)
        guard !data.isEmpty, data.count <= 32 * 1024 * 1024 else { throw OwlError.invalid("Ungültige Chunk-Größe.") }
        if parsed.ext == "pcm" && data.count % 2 != 0 { throw OwlError.invalid("PCM-Chunk enthält ein unvollständiges Sample.") }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let existing = try chunks(uuid)
        if let duplicate = existing.first(where: { $0.number == parsed.number }) {
            guard duplicate.digest == digest else { throw OwlError.conflict("Chunk wurde mit anderem Inhalt bereits empfangen.") }
            return false
        }
        let item: Recording
        if let found = try find(uuid) {
            guard found.state == .receiving,
                  (found.uploadFormat == parsed.ext && found.uploadTimestamp == timestamp) ||
                  (found.uploadFormat == nil && found.uploadTimestamp == nil && existing.isEmpty) else {
                throw OwlError.conflict("Aufnahme ist abgeschlossen oder Format/Zeitstempel widersprechen sich.")
            }
            item = found
        } else {
            item = try insert(title: "Watch-Aufnahme", source: source, uuid: uuid,
                              startedAt: parsed.startedAt, state: .receiving)
        }
        item.uploadFormat = parsed.ext; item.uploadTimestamp = timestamp; try save()
        let directory = paths.chunks.appendingPathComponent(uuid, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let file = directory.appendingPathComponent("\(parsed.number).\(parsed.ext)")
        if FileManager.default.fileExists(atPath: file.path) {
            // Recover an orphan written before a database save/crash, only if identical.
            guard try Data(contentsOf: file) == data else { throw OwlError.conflict("Vorhandener Chunk widerspricht dem Upload.") }
        } else {
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            let handle = try FileHandle(forWritingTo: file)
            try handle.synchronize(); try handle.close()
        }
        context.insert(UploadChunk(captureUUID: uuid, number: parsed.number, digest: digest,
                                  fileName: "\(uuid)/\(parsed.number).\(parsed.ext)"))
        do { try save() } catch { context.rollback(); throw error }
        return true
    }
    public func finish(_ uuid: String) throws -> Recording {
        guard let item = try find(uuid) else { throw OwlError.missing("Aufnahme nicht gefunden.") }
        if item.state != .receiving { return item }
        let parts = try chunks(uuid)
        guard !parts.isEmpty, parts.enumerated().allSatisfy({ $0.offset == $0.element.number }) else {
            throw OwlError.conflict("Chunks fehlen. Der Upload muss ab Chunk 0 vollständig sein.")
        }
        let destination = paths.audio.appendingPathComponent(uuid + ".wav")
        try AudioFiles.assemble(parts.map { paths.chunks.appendingPathComponent($0.fileName) },
                                format: item.uploadFormat ?? "", to: destination)
        item.audioName = destination.lastPathComponent
        item.state = .queued; item.errorMessage = nil
        try save()
        return item
    }
    public func remove(_ item: Recording) throws {
        let audioName = item.audioName
        let audio = paths.audio.appendingPathComponent(audioName)
        let chunkDirectory = paths.chunks.appendingPathComponent(item.uuid)
        for part in try chunks(item.uuid) { context.delete(part) }
        context.delete(item); try save()
        if !audioName.isEmpty { try? FileManager.default.removeItem(at: audio) }
        try? FileManager.default.removeItem(at: chunkDirectory)
    }
}

public struct ChunkName: Sendable {
    public let number: Int
    public let ext: String
    public let startedAt: Date
    public init(filename: String, uuid: String, timestamp: String) throws {
        guard uuid.count == 32, uuid.allSatisfy({ $0.isHexDigit && $0.isASCII }),
              filename == (filename as NSString).lastPathComponent else { throw OwlError.invalid("Ungültiger Aufnahmename.") }
        let url = URL(fileURLWithPath: filename)
        let parts = url.deletingPathExtension().lastPathComponent.components(separatedBy: "_")
        guard parts.count == 4, parts[0] == "audio", parts[1] == uuid, parts[2] == timestamp,
              let n = Int(parts[3]), n >= 0, n <= 100_000,
              ["pcm", "wav", "aac"].contains(url.pathExtension.lowercased()) else {
            throw OwlError.invalid("Chunkname oder Audioformat ist ungültig.")
        }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyyMMdd-HHmmss.SSS"
        formatter.isLenient = false
        guard timestamp.count == 19, let date = formatter.date(from: timestamp), formatter.string(from: date) == timestamp else {
            throw OwlError.invalid("Ungültiger Aufnahmezeitpunkt.")
        }
        number = n; ext = url.pathExtension.lowercased(); startedAt = date
    }
}
