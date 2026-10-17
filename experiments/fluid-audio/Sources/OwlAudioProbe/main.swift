import Foundation
import CoreML
import FluidAudio

enum ProbeError: Error { case usage, invalidParameters, invalidReference, invalidTimings }

struct Segment: Codable {
    let speaker: String
    let start: Float
    let end: Float
    let quality: Float
}
struct Similarity: Codable {
    let speaker: String
    let cosine: Double
}
struct Report: Encodable {
    let schemaVersion = 1
    let engine = "FluidAudio 0.17.7 / Parakeet v3 INT8-v2 / Offline Community-1"
    let inputFile: String
    let audioSeconds: Double
    let modelLoadSeconds: Double
    let asrSeconds: Double
    let diarizationSeconds: Double
    let referenceSeconds: Double?
    let asr: ASRResult
    let words: [WordTiming]
    let segments: [Segment]
    let speakerEmbeddings: [String: [Float]]
    let referenceSimilarities: [Similarity]?
    let identityDecision = "No identity assigned; cosine scores are uncalibrated."
}

func log(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func cosine(_ a: [Float], _ b: [Float]) throws -> Double {
    guard !a.isEmpty, a.count == b.count else { throw ProbeError.invalidReference }
    let aa = a.reduce(0.0) { $0 + Double($1) * Double($1) }
    let bb = b.reduce(0.0) { $0 + Double($1) * Double($1) }
    guard aa > 0, bb > 0 else { throw ProbeError.invalidReference }
    return zip(a, b).reduce(0.0) { $0 + Double($1.0) * Double($1.1) } / sqrt(aa * bb)
}

// Load only files explicitly staged by prepare_models.py. This deliberately
// avoids SDK loaders that can fetch missing models over the network.
func loadDiarizer(_ directory: URL) throws -> OfflineDiarizerModels {
    let start = Date()
    func model(_ name: String, units: MLComputeUnits = .all) throws -> MLModel {
        let config = MLModelConfiguration()
        config.computeUnits = units
        return try MLModel(contentsOf: directory.appendingPathComponent(name + ".mlmodelc"), configuration: config)
    }
    let data = try Data(contentsOf: directory.appendingPathComponent("plda-parameters.json"))
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tensors = root["tensors"] as? [String: Any],
          let psi = tensors["psi"] as? [String: Any],
          let encoded = psi["data_base64"] as? String,
          let bytes = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters),
          !bytes.isEmpty, bytes.count % 4 == 0 else { throw ProbeError.invalidParameters }
    // The published tensor is float32 little endian. Avoid unaligned loads.
    let values = stride(from: 0, to: bytes.count, by: 4).map { offset -> Double in
        let bits = (0..<4).reduce(UInt32(0)) { $0 | UInt32(bytes[offset + $1]) << ($1 * 8) }
        return Double(Float(bitPattern: bits))
    }
    guard values.allSatisfy({ $0.isFinite && $0 > 0 }) else { throw ProbeError.invalidParameters }
    let segmentation = try model("Segmentation")
    let fbank = try model("FBank", units: .cpuOnly)
    let embedding = try model("Embedding")
    let plda = try model("PldaRho")
    return OfflineDiarizerModels(segmentationModel: segmentation, fbankModel: fbank,
        embeddingModel: embedding, pldaRhoModel: plda, pldaPsi: values,
        compilationDuration: Date().timeIntervalSince(start))
}

@main
struct OwlAudioProbe {
    static func main() async {
        do {
            try await run()
        } catch {
            log("Probe failed: \(error)")
            exit(1)
        }
    }

    static func run() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count == 3 || args.count == 4 else {
            log("Usage: OwlAudioProbe MODEL_ROOT AUDIO_FILE NEW_REPORT_JSON [SINGLE_SPEAKER_REFERENCE]")
            throw ProbeError.usage
        }
        let root = URL(fileURLWithPath: args[0], isDirectory: true)
        let input = URL(fileURLWithPath: args[1])
        let output = URL(fileURLWithPath: args[2])
        guard FileManager.default.fileExists(atPath: input.path) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        guard !FileManager.default.fileExists(atPath: output.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        log("Loading local models")
        let start = Date()
        let asrModels = try AsrModels.loadLocal(from: root.appendingPathComponent("asr"),
                                               version: .v3, encoderPrecision: .int8V2)
        let asrManager = AsrManager()
        try await asrManager.loadModels(asrModels)
        let diarizer = OfflineDiarizerManager()
        diarizer.initialize(models: try loadDiarizer(root.appendingPathComponent("diarizer")))
        let loadSeconds = Date().timeIntervalSince(start)

        log("Transcribing")
        let asrStart = Date()
        var decoderState = try TdtDecoderState()
        let asr = try await asrManager.transcribe(input, decoderState: &decoderState)
        let asrSeconds = Date().timeIntervalSince(asrStart)
        let words = buildWordTimings(from: asr.tokenTimings ?? [])
        guard !asr.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !words.isEmpty,
              words.allSatisfy({ $0.startTime.isFinite && $0.endTime.isFinite &&
                  $0.startTime >= 0 && $0.endTime >= $0.startTime && $0.endTime <= asr.duration + 1 })
        else { throw ProbeError.invalidTimings }

        log("Diarizing")
        let diarStart = Date()
        let diar = try await diarizer.process(input)
        let diarSeconds = Date().timeIntervalSince(diarStart)
        var similarities: [Similarity]?
        var referenceSeconds: Double?
        if args.count == 4 {
            log("Comparing a separate reference; no identity assignment")
            let refStart = Date()
            let reference = try await diarizer.process(URL(fileURLWithPath: args[3]))
            guard let database = reference.speakerDatabase, database.count == 1,
                  let embedding = database.values.first else { throw ProbeError.invalidReference }
            similarities = try (diar.speakerDatabase ?? [:]).map { key, value in
                Similarity(speaker: key, cosine: try cosine(value, embedding))
            }.sorted { $0.cosine > $1.cosine }
            referenceSeconds = Date().timeIntervalSince(refStart)
        }
        let report = Report(inputFile: input.lastPathComponent, audioSeconds: asr.duration,
            modelLoadSeconds: loadSeconds, asrSeconds: asrSeconds,
            diarizationSeconds: diarSeconds, referenceSeconds: referenceSeconds,
            asr: asr, words: words, segments: diar.segments.map {
                Segment(speaker: $0.speakerId, start: $0.startTimeSeconds,
                        end: $0.endTimeSeconds, quality: $0.qualityScore)
            }, speakerEmbeddings: diar.speakerDatabase ?? [:], referenceSimilarities: similarities)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try data.write(to: output, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
        log("Completed: audio=\(asr.duration)s ASR=\(asrSeconds)s diarization=\(diarSeconds)s words=\(words.count) speakers=\(Set(diar.segments.map(\.speakerId)).count)")
    }
}
