import Foundation
import AVFoundation
import FluidAudio

public enum AudioFiles {
    public static func assemble(_ chunks: [URL], format: String, to destination: URL) throws {
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: temporary) }
        if format == "pcm" {
            let bytes = try chunks.reduce(UInt64(0)) { value, url in
                value + ((try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value ?? 0)
            }
            guard bytes > 0, bytes % 2 == 0, bytes <= UInt32.max - 36 else { throw OwlError.invalid("PCM-Aufnahme ist leer oder zu groß.") }
            var header = Data("RIFF".utf8)
            func append<T: FixedWidthInteger>(_ n: T) { var x = n.littleEndian; withUnsafeBytes(of: &x) { header.append(contentsOf: $0) } }
            append(UInt32(bytes + 36)); header.append(Data("WAVEfmt ".utf8)); append(UInt32(16))
            append(UInt16(1)); append(UInt16(1)); append(UInt32(16000)); append(UInt32(32000))
            append(UInt16(2)); append(UInt16(16)); header.append(Data("data".utf8)); append(UInt32(bytes))
            try header.write(to: temporary)
            let out = try FileHandle(forWritingTo: temporary); defer { try? out.close() }
            try out.seekToEnd()
            for chunk in chunks {
                let input = try FileHandle(forReadingFrom: chunk)
                do {
                    while let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty { try out.write(contentsOf: data) }
                    try input.close()
                } catch { try? input.close(); throw error }
            }
            try out.synchronize()
        } else {
            guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1) else { throw OwlError.invalid("Audioformat fehlt.") }
            let output = try AVAudioFile(forWriting: temporary, settings: audioFormat.settings)
            let converter = AudioConverter()
            for url in chunks {
                let samples = try converter.resampleAudioFile(url)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(samples.count)),
                      let channel = buffer.floatChannelData?[0] else { throw OwlError.invalid("Audio kann nicht konvertiert werden.") }
                buffer.frameLength = AVAudioFrameCount(samples.count)
                samples.withUnsafeBufferPointer { pointer in channel.update(from: pointer.baseAddress!, count: samples.count) }
                try output.write(from: buffer)
            }
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        } else { try FileManager.default.moveItem(at: temporary, to: destination) }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }
}
