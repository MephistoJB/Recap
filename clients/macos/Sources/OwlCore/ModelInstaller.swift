import Foundation
import CryptoKit

public actor ModelInstaller {
    public static let selections: [(String, String, String, [String])] = [
        ("asr", "parakeet-tdt-0.6b-v3-coreml", "7dd20fe6b1797d35f5e3307e8b1732d9a178edfe",
         ["Preprocessor.mlmodelc/", "Encoder_v2.mlmodelc/", "Decoder.mlmodelc/", "JointDecisionv3.mlmodelc/", "parakeet_vocab.json"]),
        ("diarizer", "speaker-diarization-coreml", "df2625ac79a7ac6b65ad868fee6d80f320da4232",
         ["Segmentation.mlmodelc/", "Embedding.mlmodelc/", "FBank.mlmodelc/", "PldaRho.mlmodelc/", "plda-parameters.json"])
    ]
    struct HubModel: Decodable { var sha: String; var siblings: [HubFile] }
    struct HubFile: Decodable {
        struct LFS: Decodable { var sha256: String }
        var rfilename: String; var size: Int; var blobId: String; var lfs: LFS?
    }
    public struct ManifestEntry: Codable, Sendable {
        public var repository: String; public var revision: String; public var file: String
        public var bytes: Int; public var sha256: String
    }
    public init() {}
    public static func isReady(_ root: URL) -> Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent("owl-model-manifest.json").path)
    }
    static func fileSHA256(_ url: URL) throws -> String {
        let input = try FileHandle(forReadingFrom: url); defer { try? input.close() }
        var hash = SHA256()
        while let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    static func valid(_ url: URL, file: HubFile) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue == file.size else { return false }
        if let lfs = file.lfs { return try fileSHA256(url) == lfs.sha256 }
        var hash = Insecure.SHA1(); hash.update(data: Data("blob \(file.size)\0".utf8))
        hash.update(data: try Data(contentsOf: url))
        return hash.finalize().map { String(format: "%02x", $0) }.joined() == file.blobId
    }
    public func install(to root: URL, reuse: URL? = nil,
                        progress: @Sendable (String) async -> Void) async throws {
        var entries: [ManifestEntry] = []
        for (folder, repo, revision, prefixes) in Self.selections {
            let url = URL(string: "https://huggingface.co/api/models/FluidInference/\(repo)/revision/\(revision)?blobs=true")!
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw OwlError.invalid("Modell-Metadaten konnten nicht geladen werden.") }
            let metadata = try JSONDecoder().decode(HubModel.self, from: data)
            guard metadata.sha == revision else { throw OwlError.invalid("Modellrevision stimmt nicht überein.") }
            let notices: Set<String> = ["README.md", "NOTICE.md", "LICENSE", "LICENSE.md", "PROVENANCE.md", "provenance.json"]
            let files = metadata.siblings.filter { file in prefixes.contains { file.rfilename.hasPrefix($0) } || notices.contains(file.rfilename) }
            guard prefixes.allSatisfy({ prefix in files.contains { $0.rfilename.hasPrefix(prefix) } }) else { throw OwlError.missing("Modell-Snapshot ist unvollständig.") }
            for file in files {
                try Task.checkCancellation()
                guard !file.rfilename.hasPrefix("/"), !file.rfilename.components(separatedBy: "/").contains("..") else { throw OwlError.invalid("Ungültiger Modellpfad.") }
                let relative = folder + "/" + file.rfilename
                await progress("\(folder): \(file.rfilename)")
                let target = root.appendingPathComponent(relative)
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                       attributes: [.posixPermissions: 0o700])
                if !(try Self.valid(target, file: file)) {
                    if let reuse, try Self.valid(reuse.appendingPathComponent(relative), file: file) {
                        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
                        try FileManager.default.copyItem(at: reuse.appendingPathComponent(relative), to: target)
                    } else {
                        let source = URL(string: "https://huggingface.co/FluidInference/\(repo)/resolve/\(revision)/\(file.rfilename)")!
                        let (temporary, response) = try await URLSession.shared.download(from: source)
                        defer { try? FileManager.default.removeItem(at: temporary) }
                        guard (response as? HTTPURLResponse)?.statusCode == 200,
                              try Self.valid(temporary, file: file) else { throw OwlError.invalid("Modell-Download oder Integritätsprüfung fehlgeschlagen.") }
                        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
                        try FileManager.default.moveItem(at: temporary, to: target)
                    }
                }
                entries.append(ManifestEntry(repository: "FluidInference/" + repo, revision: revision,
                                             file: relative, bytes: file.size, sha256: try Self.fileSHA256(target)))
            }
        }
        try JSONEncoder().encode(entries).write(to: root.appendingPathComponent("owl-model-manifest.json"), options: .atomic)
        await progress("Modelle sind bereit.")
    }
    public func verify(_ root: URL) throws {
        let data = try Data(contentsOf: root.appendingPathComponent("owl-model-manifest.json"))
        let entries = try JSONDecoder().decode([ManifestEntry].self, from: data)
        guard !entries.isEmpty else { throw OwlError.missing("Modellmanifest ist leer.") }
        for (folder, repo, revision, prefixes) in Self.selections {
            let selected = entries.filter { $0.repository == "FluidInference/" + repo && $0.revision == revision }
            guard prefixes.allSatisfy({ prefix in selected.contains { $0.file.hasPrefix(folder + "/" + prefix) } }) else {
                throw OwlError.missing("Modellmanifest ist unvollständig.")
            }
        }
        for entry in entries {
            guard !entry.file.hasPrefix("/"), !entry.file.components(separatedBy: "/").contains(".."),
                  Self.selections.contains(where: { "FluidInference/" + $0.1 == entry.repository && $0.2 == entry.revision }),
                  try Self.fileSHA256(root.appendingPathComponent(entry.file)) == entry.sha256 else {
                throw OwlError.invalid("Modellprüfung fehlgeschlagen: \(entry.file)")
            }
        }
    }
}
