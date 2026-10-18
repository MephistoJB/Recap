import XCTest
@testable import Recap

private final class UploadProtocol: URLProtocol {
    static var status: (URLRequest) -> Int = { _ in 200 }
    static var paths: [String] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.paths.append(request.url!.lastPathComponent)
        let code = Self.status(request)
        if code == -1 {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
final class RecapTests: XCTestCase {
    private let capture = String(repeating: "a", count: 32)
    private func directory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func chunk(_ dir: URL, number: Int = 0, ext: String = "pcm", bytes: Data = Data([1, 2, 3, 4])) throws -> URL {
        let path = dir.appendingPathComponent("audio_\(capture)_20261018-100000.000_\(number).\(ext)")
        try bytes.write(to: path)
        return path
    }
    private func session() throws -> URLSession {
        try ConnectionSettings.save(address: "http://recap-tests.invalid", token: "test-only-not-a-real-token")
        setUploadAllowed(to: true)
        UploadProtocol.paths = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UploadProtocol.self]
        return URLSession(configuration: config)
    }
    private func exists(_ path: URL) -> Bool { FileManager.default.fileExists(atPath: path.path) }

    func testHTTPFailuresRetainChunksAndCompletion() async throws {
        for code in [401, 409, 500, -1] {
            let dir = try directory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let file = try chunk(dir)
            markCaptureComplete(capture, directory: dir)
            let session = try session()
            defer { session.invalidateAndCancel() }
            UploadProtocol.status = { _ in code }
            await runFileUploadPass(fileExtension: "pcm", directory: dir, session: session)
            XCTAssertTrue(exists(file), "Chunk lost after \(code)")
            XCTAssertTrue(exists(dir.appendingPathComponent("\(capture).end")))
            XCTAssertEqual(UploadProtocol.paths, ["upload_chunk"])
        }
    }

    func testProcessFailureRetainsMarkerAndRetriesWithoutReuploading() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = try chunk(dir)
        markCaptureComplete(capture, directory: dir)
        let marker = dir.appendingPathComponent("\(capture).end")
        let session = try session()
        defer { session.invalidateAndCancel() }
        UploadProtocol.status = { $0.url!.lastPathComponent == "process_capture" ? 500 : 200 }
        await runFileUploadPass(fileExtension: "pcm", directory: dir, session: session)
        XCTAssertFalse(exists(file))
        XCTAssertTrue(exists(marker))
        UploadProtocol.status = { _ in 204 }
        await runFileUploadPass(fileExtension: "pcm", directory: dir, session: session)
        XCTAssertFalse(exists(marker))
        XCTAssertEqual(UploadProtocol.paths, ["upload_chunk", "process_capture", "process_capture"])
    }

    func testNoUploadUntilRecordingEndsAndNumericOrder() async throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try chunk(dir, number: 10)
        _ = try chunk(dir, number: 2)
        XCTAssertEqual(audioFiles(fileExtension: "pcm", directory: dir).compactMap { AudioFileWriter.getChunkNumber(from: $0) }, [2, 10])
        let session = try session()
        defer { session.invalidateAndCancel() }
        UploadProtocol.status = { _ in 200 }
        await runFileUploadPass(fileExtension: "pcm", directory: dir, session: session)
        XCTAssertTrue(UploadProtocol.paths.isEmpty)
        markCaptureComplete(capture, directory: dir)
        await runFileUploadPass(fileExtension: "pcm", directory: dir, session: session)
        XCTAssertEqual(UploadProtocol.paths, ["upload_chunk", "upload_chunk", "process_capture"])
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }

    func testInterruptedPCMRecoveryPreservesSamplesAndUnalignedFragment() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let bytes = Data([1, 2, 3, 4])
        let complete = try chunk(dir, ext: "pcm-wip", bytes: bytes)
        let unaligned = try chunk(dir, number: 1, ext: "pcm-wip", bytes: Data([5]))
        recoverInterruptedCaptures(fileExtension: "pcm", directory: dir)
        let final = complete.deletingPathExtension().appendingPathExtension("pcm")
        XCTAssertEqual(try Data(contentsOf: final), bytes)
        XCTAssertEqual(try Data(contentsOf: unaligned), Data([5]))
        XCTAssertTrue(exists(dir.appendingPathComponent("\(capture).end")))
        recoverInterruptedCaptures(fileExtension: "pcm", directory: dir)
        XCTAssertEqual(try Data(contentsOf: final), bytes)
    }

    func testConnectionValidation() {
        for text in ["", "/relative", "file:///tmp/test", "http://user:password@mac.local", "http://mac.local?token=secret"] {
            XCTAssertNil(ConnectionSettings.serverURL(text))
        }
        XCTAssertNotNil(ConnectionSettings.serverURL("http://macserver.local:8012"))
    }
}
