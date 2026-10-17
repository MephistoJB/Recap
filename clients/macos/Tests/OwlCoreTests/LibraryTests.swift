import XCTest
@testable import OwlCore

final class LibraryTests: XCTestCase {
    @MainActor private func temporaryStore() throws -> LibraryStore {
        try LibraryStore(paths: OwlPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
    }
    @MainActor func testDuplicateSurvivesRestartAndConflictingContentIsRejected() throws {
        let store = try temporaryStore(); defer { try? FileManager.default.removeItem(at: store.paths.root) }
        let uuid = String(repeating: "a", count: 32), timestamp = "20261017-120000.000"
        let name = "audio_\(uuid)_\(timestamp)_0.pcm"
        XCTAssertTrue(try store.receive(filename: name, uuid: uuid, timestamp: timestamp, source: "apple_watch", data: Data([0, 1])))
        let reopened = try LibraryStore(paths: store.paths)
        XCTAssertFalse(try reopened.receive(filename: name, uuid: uuid, timestamp: timestamp, source: "apple_watch", data: Data([0, 1])))
        XCTAssertThrowsError(try reopened.receive(filename: name, uuid: uuid, timestamp: timestamp, source: "apple_watch", data: Data([2, 3])))
        XCTAssertThrowsError(try reopened.receive(filename: "audio_\(uuid)_20261018-120000.000_0.pcm", uuid: uuid,
                                                 timestamp: "20261018-120000.000", source: "apple_watch", data: Data([0, 1])))
        XCTAssertEqual(try reopened.chunks(uuid).count, 1)
    }
    @MainActor func testChunkGapsAndNumericAssembly() throws {
        let store = try temporaryStore(); defer { try? FileManager.default.removeItem(at: store.paths.root) }
        let uuid = String(repeating: "b", count: 32), timestamp = "20261017-120000.000"
        func put(_ index: Int) throws {
            try store.receive(filename: "audio_\(uuid)_\(timestamp)_\(index).pcm", uuid: uuid, timestamp: timestamp,
                              source: "apple_watch", data: Data([UInt8(index), 0]))
        }
        try put(1); XCTAssertThrowsError(try store.finish(uuid)); try put(0)
        let item = try store.finish(uuid)
        XCTAssertEqual(item.state, .queued)
        let data = try Data(contentsOf: store.paths.audio.appendingPathComponent(item.audioName))
        XCTAssertEqual(String(data: data.prefix(4), encoding: .utf8), "RIFF")
        XCTAssertEqual(Array(data.suffix(4)), [0, 0, 1, 0])
        XCTAssertEqual(data.count, 48)
        XCTAssertEqual(try store.finish(uuid).uuid, uuid)
        XCTAssertFalse(try store.receive(filename: "audio_\(uuid)_\(timestamp)_0.pcm", uuid: uuid, timestamp: timestamp,
                                        source: "apple_watch", data: Data([0, 0])))
    }
    @MainActor func testInterruptedProcessingResumesAndMetadataIsRetained() throws {
        let store = try temporaryStore(); defer { try? FileManager.default.removeItem(at: store.paths.root) }
        let item = try store.insert(title: "Bestehender Titel", source: "import", state: .processing, audioName: "saved.wav")
        let uuid = item.uuid
        try store.recover()
        let reopened = try LibraryStore(paths: store.paths)
        let found = try XCTUnwrap(reopened.find(uuid))
        XCTAssertEqual(found.state, .queued); XCTAssertEqual(found.audioName, "saved.wav")
        XCTAssertEqual(found.title, "Bestehender Titel")
    }
    func testAmbiguousSpeakerIsNotNamed() {
        let segments = [SpeakerSegment(speaker: "A", start: 0, end: 2), SpeakerSegment(speaker: "B", start: 1, end: 3)]
        XCTAssertEqual(SpeakerAttribution.speaker(start: 0.1, end: 0.9, segments: segments), "A")
        XCTAssertNil(SpeakerAttribution.speaker(start: 1.1, end: 1.9, segments: segments))
        XCTAssertNil(SpeakerAttribution.speaker(start: 4, end: 5, segments: segments))
        XCTAssertNil(SpeakerAttribution.cosine([0, 0], [1, 1]))
    }
    @MainActor func testConversationIDsAreNotReusedAfterDeletion() throws {
        let store = try temporaryStore(); defer { try? FileManager.default.removeItem(at: store.paths.root) }
        let first = try store.insert(title: "Erster Eintrag", source: "import")
        let id = first.apiID
        try store.remove(first)
        let second = try store.insert(title: "Zweiter Eintrag", source: "import")
        XCTAssertGreaterThan(second.apiID, id)
    }
    @MainActor func testFailedAudioDeletionKeepsLibraryEntryVisible() throws {
        let store = try temporaryStore()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: store.paths.audio.path)
            try? FileManager.default.removeItem(at: store.paths.root)
        }
        let item = try store.insert(title: "Geschützte Datei", source: "import", audioName: "protected.wav")
        let uuid = item.uuid
        let file = store.paths.audio.appendingPathComponent(item.audioName)
        try Data([0, 1]).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: store.paths.audio.path)
        XCTAssertThrowsError(try store.remove(item))
        XCTAssertNotNil(try store.find(uuid))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }
    func testTraversalAndInvalidTimestampAreRejected() {
        let uuid = String(repeating: "c", count: 32)
        XCTAssertThrowsError(try ChunkName(filename: "../audio_\(uuid)_20261017-120000.000_0.pcm", uuid: uuid, timestamp: "20261017-120000.000"))
        XCTAssertThrowsError(try ChunkName(filename: "audio_\(uuid)_20261399-120000.000_0.pcm", uuid: uuid, timestamp: "20261399-120000.000"))
    }
    func testMultipartRetainsBinaryBytesAndRejectsTruncation() throws {
        let boundary = "OwlBoundary"
        var data = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.pcm\"\r\n\r\n".utf8)
        data.append(contentsOf: [0, 255, 10, 13]); data.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let parts = try OwlMultipart.parse(contentType: "multipart/form-data; boundary=\(boundary)", data: data)
        XCTAssertEqual(parts.first?.data, Data([0, 255, 10, 13])); XCTAssertEqual(parts.first?.filename, "audio.pcm")
        XCTAssertThrowsError(try OwlMultipart.parse(contentType: "multipart/form-data; boundary=\(boundary)", data: data.dropLast(10)))
    }
}
