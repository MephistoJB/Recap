import Foundation
import SwiftData

public enum ProcessingState: String, Codable, Sendable {
    case receiving, queued, processing, completed, failed, interrupted
    public var label: String {
        switch self {
        case .receiving: "Empfang läuft"
        case .queued: "Wartet auf Verarbeitung"
        case .processing: "Wird transkribiert"
        case .completed: "Fertig"
        case .failed: "Verarbeitung fehlgeschlagen"
        case .interrupted: "Aufnahme unterbrochen"
        }
    }
}

public struct TranscriptWord: Codable, Sendable, Identifiable {
    public var id: Int
    public var text: String
    public var start: Double
    public var end: Double
    public var speaker: String?
}
public struct SpeakerSegment: Codable, Sendable {
    public var speaker: String
    public var start: Double
    public var end: Double
}
public struct Transcript: Codable, Sendable {
    public var engine = "FluidAudio 0.17.7 · Parakeet v3 INT8-v2"
    public var text: String
    public var duration: Double
    public var words: [TranscriptWord]
    public var speakers: [SpeakerSegment]
    public var embeddings: [String: [Float]]
    public var elapsed: Double
    public var referenceScores: [String: Double] = [:]
    public var referenceRevision: String? = nil
    public var referenceIssue: String? = nil
    public var speakerIssue: String? = nil
}

@Model public final class Recording {
    @Attribute(.unique) public var uuid: String
    public var apiID: Int
    public var title: String
    public var startedAt: Date
    public var timezoneID: String = "UTC"
    public var timeIsEstimated: Bool = true
    public var createdAt: Date
    public var source: String
    public var stateRaw: String
    public var audioName: String
    public var duration: Double
    public var transcriptData: Data?
    public var speakerNamesData: Data?
    public var locationData: Data?
    public var errorMessage: String?
    public var summary: String?
    public var summaryModel: String?
    public var summaryError: String?
    public var uploadTimestamp: String?
    public var uploadFormat: String?
    public var revision: Int

    public init(uuid: String = UUID().uuidString.lowercased(), apiID: Int,
                title: String, startedAt: Date = .now, source: String,
                state: ProcessingState = .queued, audioName: String = "") {
        self.uuid = uuid; self.apiID = apiID; self.title = title
        self.startedAt = startedAt; self.createdAt = .now; self.source = source
        self.timezoneID = TimeZone.current.identifier; self.timeIsEstimated = source == "import"
        self.stateRaw = state.rawValue; self.audioName = audioName
        self.duration = 0; self.revision = 1
    }
    public var state: ProcessingState {
        get { ProcessingState(rawValue: stateRaw) ?? .failed }
        set { stateRaw = newValue.rawValue }
    }
    public var transcript: Transcript? {
        get { transcriptData.flatMap { try? JSONDecoder().decode(Transcript.self, from: $0) } }
        set { transcriptData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }
    public var speakerNames: [String: String] {
        get { speakerNamesData.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:] }
        set { speakerNamesData = try? JSONEncoder().encode(newValue) }
    }
}

@Model public final class UploadChunk {
    @Attribute(.unique) public var key: String
    public var captureUUID: String
    public var number: Int
    public var digest: String
    public var fileName: String
    public init(captureUUID: String, number: Int, digest: String, fileName: String) {
        self.key = "\(captureUUID):\(number)"; self.captureUUID = captureUUID
        self.number = number; self.digest = digest; self.fileName = fileName
    }
}

@Model public final class LibraryCounter {
    @Attribute(.unique) public var name: String
    public var nextValue: Int
    public init() { name = "conversationID"; nextValue = 1 }
}

public enum RecapError: LocalizedError {
    case invalid(String), conflict(String), missing(String)
    public var errorDescription: String? {
        switch self { case .invalid(let s), .conflict(let s), .missing(let s): s }
    }
}

public struct RecapPaths: Sendable {
    public let root: URL
    public var audio: URL { root.appendingPathComponent("Audio", isDirectory: true) }
    public var chunks: URL { root.appendingPathComponent("Chunks", isDirectory: true) }
    public var models: URL { root.appendingPathComponent("Models", isDirectory: true) }
    public var reference: URL { root.appendingPathComponent("Reference.wav") }
    public init(root: URL? = nil) throws {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Owl", isDirectory: true)
        for dir in [self.root, audio, chunks, models] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                   attributes: [.posixPermissions: 0o700])
        }
    }
}

public enum SpeakerAttribution {
    // Overlapping voices and uncovered words remain unassigned. Never force a name.
    public static func speaker(start: Double, end: Double, segments: [SpeakerSegment]) -> String? {
        let active = Set(segments.filter { min(end, $0.end) > max(start, $0.start) }.map(\.speaker))
        return active.count == 1 ? active.first : nil
    }
    public static func cosine(_ a: [Float], _ b: [Float]) -> Double? {
        guard !a.isEmpty, a.count == b.count else { return nil }
        let aa = a.reduce(0.0) { $0 + Double($1) * Double($1) }
        let bb = b.reduce(0.0) { $0 + Double($1) * Double($1) }
        guard aa > 0, bb > 0 else { return nil }
        let score = zip(a, b).reduce(0.0) { $0 + Double($1.0) * Double($1.1) } / sqrt(aa * bb)
        return score.isFinite ? score : nil
    }
}

public struct LocationUpdate: Codable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var address: String?
    public var capture_uuid: String?
}
