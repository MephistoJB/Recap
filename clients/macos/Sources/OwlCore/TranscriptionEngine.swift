import Foundation
@preconcurrency import CoreML
import FluidAudio

public actor TranscriptionEngine {
    private var asr: AsrManager?
    private var diarizerModels: OfflineDiarizerModels?
    private var processing = false
    private var loadedRoot: URL?

    private func prepare(_ root: URL) async throws {
        if loadedRoot == root, asr != nil, diarizerModels != nil { return }
        let models = try AsrModels.loadLocal(from: root.appendingPathComponent("asr"),
                                             version: .v3, encoderPrecision: .int8V2)
        let manager = AsrManager()
        try await manager.loadModels(models)
        diarizerModels = try loadDiarizer(root.appendingPathComponent("diarizer"))
        asr = manager; loadedRoot = root
    }
    public init() {}
    public func releaseModels() { guard !processing else { return }; asr = nil; diarizerModels = nil; loadedRoot = nil }

    public func process(audio: URL, modelRoot: URL, reference: URL?) async throws -> Transcript {
        guard !processing else { throw OwlError.conflict("Es läuft bereits eine Transkription.") }
        processing = true; defer { processing = false }
        let started = Date()
        try await prepare(modelRoot)
        guard let asr, let diarizerModels else { throw OwlError.missing("Modelle sind nicht geladen.") }
        let diarizer = OfflineDiarizerManager()
        diarizer.initialize(models: diarizerModels)
        try Task.checkCancellation()
        var decoder = try TdtDecoderState()
        let result = try await asr.transcribe(audio, decoderState: &decoder)
        let wordTimes = buildWordTimings(from: result.tokenTimings ?? [])
        guard !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !wordTimes.isEmpty else {
            throw OwlError.invalid("Keine Sprache erkannt. Originalaudio bleibt erhalten.")
        }
        try Task.checkCancellation()
        let diar: DiarizationResult?
        var speakerIssue: String?
        do { diar = try await diarizer.process(audio) }
        catch is CancellationError { throw CancellationError() }
        catch { diar = nil; speakerIssue = "Sprecheranalyse fehlgeschlagen: " + error.localizedDescription }
        let segments = (diar?.segments ?? []).map { SpeakerSegment(speaker: $0.speakerId, start: Double($0.startTimeSeconds), end: Double($0.endTimeSeconds)) }
        let words = try wordTimes.enumerated().map { index, word in
            guard word.startTime.isFinite, word.endTime.isFinite, word.startTime >= 0,
                  word.endTime >= word.startTime, word.endTime <= result.duration + 1 else {
                throw OwlError.invalid("Die Engine lieferte ungültige Zeitmarken.")
            }
            return TranscriptWord(id: index, text: word.word, start: word.startTime, end: word.endTime,
                                  speaker: SpeakerAttribution.speaker(start: word.startTime, end: word.endTime, segments: segments))
        }
        var transcript = Transcript(text: result.text, duration: result.duration, words: words,
                                    speakers: segments, embeddings: diar?.speakerDatabase ?? [:],
                                    elapsed: Date().timeIntervalSince(started))
        transcript.speakerIssue = speakerIssue
        if let reference, diar != nil {
            try Task.checkCancellation()
            do {
                let ref = try await diarizer.process(reference)
                guard let known = ref.speakerDatabase, known.count == 1, let vector = known.values.first else {
                    transcript.referenceIssue = "Die Referenz muss genau eine erkennbare Stimme enthalten."
                    return transcript
                }
                transcript.referenceScores = transcript.embeddings.compactMapValues { SpeakerAttribution.cosine($0, vector) }
                let attrs = try FileManager.default.attributesOfItem(atPath: reference.path)
                transcript.referenceRevision = (attrs[.modificationDate] as? Date).map { ISO8601DateFormatter().string(from: $0) }
            } catch is CancellationError { throw CancellationError() }
            catch { transcript.referenceIssue = "Referenzvergleich fehlgeschlagen: " + error.localizedDescription }
        }
        return transcript
    }
}

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
          !bytes.isEmpty, bytes.count % 4 == 0 else { throw OwlError.invalid("Ungültige PLDA-Modellparameter.") }
    // The published tensor is float32 little endian. Avoid unaligned loads.
    let values = stride(from: 0, to: bytes.count, by: 4).map { offset -> Double in
        let bits = (0..<4).reduce(UInt32(0)) { $0 | UInt32(bytes[offset + $1]) << ($1 * 8) }
        return Double(Float(bitPattern: bits))
    }
    guard values.allSatisfy({ $0.isFinite && $0 > 0 }) else { throw OwlError.invalid("Ungültige PLDA-Modellparameter.") }
    let segmentation = try model("Segmentation")
    let fbank = try model("FBank", units: .cpuOnly)
    let embedding = try model("Embedding")
    let plda = try model("PldaRho")
    return OfflineDiarizerModels(segmentationModel: segmentation, fbankModel: fbank,
        embeddingModel: embedding, pldaRhoModel: plda, pldaPsi: values,
        compilationDuration: Date().timeIntervalSince(start))
}
