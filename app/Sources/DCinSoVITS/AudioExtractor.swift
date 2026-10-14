import AVFoundation
import Foundation

/// 영상에서 오디오 트랙만 44.1kHz/16bit/스테레오 WAV로 추출한다. 영상 자체는 복사·보관하지 않는다.
enum AudioExtractor {
    static let sampleRate = 44_100
    static let channels = 2

    static func extract(from video: URL, to wav: URL) async throws {
        do {
            try await extractWithAVFoundation(video, wav)
        } catch {
            // mkv/webm 등 AVFoundation 미지원 포맷은 설치된 ffmpeg가 있으면 사용
            guard let ffmpeg = findFFmpeg() else {
                throw EngineError(message: tr(.errUnsupportedFormat))
            }
            try runFFmpeg(ffmpeg, video, wav)
        }
    }

    private static func extractWithAVFoundation(_ video: URL, _ wav: URL) async throws {
        let asset = AVURLAsset(url: video)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw EngineError(message: tr(.errNoAudioTrack))
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? EngineError(message: tr(.errAudioRead)) }

        FileManager.default.createFile(atPath: wav.path, contents: nil)
        let fh = try FileHandle(forWritingTo: wav)
        defer { try? fh.close() }
        try fh.write(contentsOf: header(dataBytes: 0))
        var total: UInt32 = 0
        while let buf = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buf) else { continue }
            let len = CMBlockBufferGetDataLength(block)
            var data = Data(count: len)
            data.withUnsafeMutableBytes { ptr in
                _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: len, destination: ptr.baseAddress!)
            }
            try fh.write(contentsOf: data)
            total &+= UInt32(len)
        }
        if reader.status == .failed { throw reader.error ?? EngineError(message: tr(.errAudioRead)) }
        try fh.seek(toOffset: 0)
        try fh.write(contentsOf: header(dataBytes: total))
    }

    private static func header(dataBytes: UInt32) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let blockAlign = UInt16(channels * 2)
        d.append("RIFF".data(using: .ascii)!); u32(36 + dataBytes)
        d.append("WAVE".data(using: .ascii)!)
        d.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(UInt16(channels))
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate) * UInt32(blockAlign)); u16(blockAlign); u16(16)
        d.append("data".data(using: .ascii)!); u32(dataBytes)
        return d
    }

    private static func findFFmpeg() -> String? {
        ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func runFFmpeg(_ ffmpeg: String, _ video: URL, _ wav: URL) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffmpeg)
        p.arguments = ["-y", "-v", "error", "-i", video.path, "-vn", "-ac", "\(channels)", "-ar", "\(sampleRate)",
                       "-c:a", "pcm_s16le", wav.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw EngineError(message: tr(.errFFmpeg)) }
    }
}
