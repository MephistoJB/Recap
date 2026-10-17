import Foundation
import Hummingbird
import MultipartKit
import CryptoKit

public struct OwlMultipart {
    public struct Part: Sendable { public var name: String; public var filename: String?; public var data: Data }
    public static func parse(contentType: String, data: Data) throws -> [Part] {
        let parameters = contentType.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parameters.first?.lowercased() == "multipart/form-data",
              let field = parameters.dropFirst().first(where: { $0.lowercased().hasPrefix("boundary=") }) else {
            throw HTTPError(.badRequest, message: "multipart/form-data erwartet.")
        }
        let boundary = String(field.dropFirst(9)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard !boundary.isEmpty, boundary.utf8.count <= 70, !boundary.contains("\r"), !boundary.contains("\n") else {
            throw HTTPError(.badRequest, message: "Ungültige Multipart-Grenze.")
        }
        guard data.suffix(Data("--\(boundary)--\r\n".utf8).count) == Data("--\(boundary)--\r\n".utf8) ||
              data.suffix(Data("--\(boundary)--".utf8).count) == Data("--\(boundary)--".utf8) else {
            throw HTTPError(.badRequest, message: "Unvollständiges Multipart-Formular.")
        }
        let parser = MultipartParser(boundary: boundary)
        var parts: [MultipartPart] = []
        var current = MultipartPart(body: Data())
        parser.onHeader = { name, value in current.headers.add(name: name, value: value) }
        parser.onBody = { buffer in current.body.writeBuffer(&buffer) }
        parser.onPartComplete = { parts.append(current); current = MultipartPart(body: Data()) }
        do { try parser.execute(Array(data)) } catch { throw HTTPError(.badRequest, message: "Ungültiges Multipart-Formular.") }
        guard parts.count <= 12 else { throw HTTPError(.badRequest) }
        var names = Set<String>()
        return try parts.map { part in
            guard let name = part.name, names.insert(name).inserted else { throw HTTPError(.badRequest, message: "Doppeltes Formularfeld.") }
            let disposition = part.headers.first(name: "Content-Disposition") ?? ""
            let filename = disposition.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
                .first(where: { $0.hasPrefix("filename=") }).map { String($0.dropFirst(9)).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            return Part(name: name, filename: filename, data: Data(part.body.readableBytesView))
        }
    }
}

public enum UploadServer {
    static func json(_ value: Any) throws -> Response {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        return response(data)
    }
    static func response(_ data: Data) -> Response {
        return Response(status: .ok, headers: [.contentType: "application/json"], body: .init(byteBuffer: .init(bytes: data)))
    }
    public static func run(store: LibraryStore, host: String, port: Int, token: String,
                           onRunning: @escaping @Sendable () async -> Void,
                           onChange: @escaping @MainActor @Sendable () -> Void) async throws {
        guard !token.isEmpty else { throw OwlError.invalid("Empfang benötigt einen Zugriffstoken.") }
        let expected = Array(SHA256.hash(data: Data("Bearer \(token)".utf8)))
        @Sendable func authorize(_ request: Request) throws {
            let actual = Array(SHA256.hash(data: Data((request.headers[.authorization] ?? "").utf8)))
            guard zip(expected, actual).reduce(UInt8(0), { $0 | ($1.0 ^ $1.1) }) == 0 else { throw HTTPError(.unauthorized) }
        }
        @Sendable func form(_ request: Request) async throws -> [OwlMultipart.Part] {
            try authorize(request)
            let body = try await request.body.collect(upTo: 33 * 1024 * 1024)
            return try OwlMultipart.parse(contentType: request.headers[.contentType] ?? "", data: Data(body.readableBytesView))
        }
        @Sendable func text(_ parts: [OwlMultipart.Part], _ key: String) throws -> String {
            guard let part = parts.first(where: { $0.name == key }), part.data.count <= 256,
                  let value = String(data: part.data, encoding: .utf8), !value.isEmpty else { throw HTTPError(.badRequest, message: "Formularfeld fehlt: \(key)") }
            return value
        }
        @Sendable func translated<T: Sendable>(_ operation: @MainActor @Sendable () throws -> T) async throws -> T {
            do { return try await operation() }
            catch OwlError.invalid(let message) { throw HTTPError(.badRequest, message: message) }
            catch OwlError.conflict(let message) { throw HTTPError(.conflict, message: message) }
            catch OwlError.missing(let message) { throw HTTPError(.notFound, message: message) }
        }
        let router = Router()
        router.get("/") { request, _ in try authorize(request); return try json(["service": "Recap Mac", "version": "0.2.0"]) }
        router.get("/health") { _, _ in try json(["status": "ok"]) }
        router.post("/capture/upload_chunk") { request, _ in
            let parts = try await form(request)
            guard let file = parts.first(where: { $0.name == "file" }), let filename = file.filename else { throw HTTPError(.badRequest, message: "Audiodatei fehlt.") }
            let uuid = try text(parts, "capture_uuid"), timestamp = try text(parts, "timestamp")
            let source = try text(parts, "device_type")
            let inserted = try await translated {
                try store.receive(filename: filename, uuid: uuid, timestamp: timestamp, source: source, data: file.data)
            }
            await onChange()
            return try json(["message": "Chunk dauerhaft gespeichert", "duplicate": !inserted])
        }
        router.post("/capture/process_capture") { request, _ in
            let uuid = try text(await form(request), "capture_uuid")
            _ = try await translated { try store.finish(uuid).uuid }
            await onChange()
            return try json(["message": "Aufnahme zur Verarbeitung vorgemerkt"])
        }
        router.get("/conversations") { request, _ in
            try authorize(request)
            let data = try await translated {
                try JSONSerialization.data(withJSONObject: ["conversations": try store.all().prefix(100).map { try conversationJSON($0) }])
            }
            return response(data)
        }
        router.get("/conversations/{id}") { request, context in
            try authorize(request)
            guard let id = context.parameters.get("id", as: Int.self) else { throw HTTPError(.badRequest) }
            let item = try await translated {
                guard let item = try store.find(apiID: id) else { throw OwlError.missing("Gespräch nicht gefunden.") }
                return try JSONSerialization.data(withJSONObject: conversationJSON(item))
            }
            return response(item)
        }
        router.post("/conversations/{id}/retry") { request, context in
            try authorize(request)
            guard let id = context.parameters.get("id", as: Int.self) else { throw HTTPError(.badRequest) }
            let value = try await translated {
                guard let item = try store.find(apiID: id), !item.audioName.isEmpty else { throw OwlError.missing("Audiodatei fehlt.") }
                guard item.state != .processing, item.state != .receiving else { throw OwlError.conflict("Aufnahme wird noch verarbeitet oder empfangen.") }
                item.state = .queued; item.errorMessage = nil; try store.save()
                return try JSONSerialization.data(withJSONObject: conversationJSON(item))
            }
            await onChange(); return response(value)
        }
        router.delete("/conversations/{id}") { request, context in
            try authorize(request)
            guard let id = context.parameters.get("id", as: Int.self) else { throw HTTPError(.badRequest) }
            try await translated {
                guard let item = try store.find(apiID: id) else { throw OwlError.missing("Gespräch nicht gefunden.") }
                guard item.state != .processing, item.state != .receiving else { throw OwlError.conflict("Aktive Aufnahme kann nicht gelöscht werden.") }
                try store.remove(item)
            }
            await onChange(); return try json(["success": true])
        }
        router.post("/capture/location") { request, _ in
            try authorize(request)
            let data = Data(try await request.body.collect(upTo: 16 * 1024).readableBytesView)
            let location = try JSONDecoder().decode(LocationUpdate.self, from: data)
            guard (-90...90).contains(location.latitude), (-180...180).contains(location.longitude),
                  let uuid = location.capture_uuid else { throw HTTPError(.badRequest) }
            let id = try await translated {
                guard let item = try store.find(uuid) else { throw OwlError.missing("Aufnahme nicht gefunden.") }
                item.locationData = data; try store.save(); return item.apiID
            }
            return try json(["message": "Standort gespeichert", "location_id": id])
        }
        let app = Application(router: router, configuration: .init(address: .hostname(host, port: port)),
                              onServerRunning: { _ in await onRunning() })
        try await app.run()
    }
    @MainActor static func conversationJSON(_ item: Recording) throws -> [String: Any] {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.string(from: item.startedAt)
        let transcript = item.transcript
        let utterances = (transcript?.words ?? []).map { word -> [String: Any] in
            ["id": word.id, "start": word.start, "end": word.end, "text": word.text,
             "speaker": word.speaker.map { item.speakerNames[$0] ?? $0 } ?? "Unbekannt",
             "spoken_at": formatter.string(from: item.startedAt.addingTimeInterval(word.start))]
        }
        let state: String = switch item.state {
        case .receiving: "CAPTURING"
        case .queued, .processing: "PROCESSING"
        case .completed: "COMPLETED"
        case .failed, .interrupted: "FAILED_PROCESSING"
        }
        return ["id": item.apiID, "conversation_uuid": item.uuid, "start_time": date,
                "end_time": formatter.string(from: item.startedAt.addingTimeInterval(item.duration)),
                "device_type": item.source, "state": state,
                "summary": item.summary as Any? ?? NSNull(), "short_summary": item.title,
                "summarization_model": item.summaryModel as Any? ?? NSNull(),
                "primary_location": item.locationData.flatMap { try? JSONSerialization.jsonObject(with: $0) } ?? NSNull(), "suggested_links": [],
                "capture_segment_file": ["id": item.apiID, "filepath": item.audioName, "duration": item.duration,
                    "source_capture": ["id": item.apiID, "filepath": item.audioName, "start_time": date, "device_type": item.source]],
                "transcriptions": transcript.map { [["id": item.apiID, "model": $0.engine, "realtime": false,
                    "transcription_time": $0.elapsed, "utterances": utterances]] } ?? []]
    }
}
