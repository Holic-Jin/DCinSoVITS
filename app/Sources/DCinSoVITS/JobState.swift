import AVFoundation
import AppKit
import UniformTypeIdentifiers
import Foundation
import Observation

enum StepStatus: Equatable {
    case idle, running, done, failed
}

struct Speaker: Identifiable, Hashable {
    let id: String
    let duration: Double
    let count: Int
    let preview: URL
}

@MainActor
@Observable
final class AppModel {
    private let engine = EngineClient.shared

    // 엔진 설치
    var engineReady = EngineClient.shared.isInstalled
    var setupStatus: StepStatus = .idle

    // 작업
    var videoName: String?
    var loadStatus: StepStatus = .idle
    var separateStatus: StepStatus = .idle
    var convertStatus: StepStatus = .idle
    var sampleStatus: StepStatus = .idle
    var exportStatus: StepStatus = .idle

    var language: String?
    var speakers: [Speaker] = []
    var selectedSpeaker: String?

    var sovitsEpochs = 8
    var gptEpochs = 15

    var progress: Double = 0
    var message = ""
    var errorMessage: String?
    var playingID: String?
    var dropTargeted = false

    private var player: AVAudioPlayer?
    private var task: Task<Void, Never>?

    var busy: Bool {
        [setupStatus, loadStatus, separateStatus, convertStatus, sampleStatus, exportStatus].contains(.running)
    }

    var jobDir: URL { engine.jobsDir.appendingPathComponent("current") }
    var sampleURL: URL { jobDir.appendingPathComponent("sample_\(Loc.shared.lang.rawValue).wav") }

    /// 샘플 상태등: 현재 UI 언어의 샘플이 있으면 초록
    var sampleLight: StepStatus {
        if sampleStatus == .running || sampleStatus == .failed { return sampleStatus }
        return FileManager.default.fileExists(atPath: sampleURL.path) ? .done : .idle
    }

    static let languageNames = ["ko": "한국어", "ja": "日本語", "zh": "中文", "en": "English", "yue": "粵語"]

    // MARK: - 설치

    func installEngine() {
        setupStatus = .running
        errorMessage = nil
        stream(engine.install()) { [weak self] _ in
            guard let self else { return }
            self.engineReady = self.engine.isInstalled
            self.setupStatus = self.engineReady ? .done : .failed
        } onError: { [weak self] in self?.setupStatus = .failed }
    }

    // MARK: - 1. 불러오기

    func openVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .audiovisualContent]
        panel.allowsOtherFileTypes = true
        panel.message = tr(.openPanelMsg)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadVideo(url)
    }

    func loadVideo(_ url: URL) {
        resetJob()
        videoName = url.lastPathComponent
        loadStatus = .running
        message = tr(.extracting)
        let dir = jobDir
        task = Task {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                try await AudioExtractor.extract(from: url, to: dir.appendingPathComponent("source.wav"))
                loadStatus = .done
                message = tr(.extracted)
            } catch {
                fail(error, &loadStatus)
            }
        }
    }

    // MARK: - 2. 분리

    func separate() {
        separateStatus = .running
        convertStatus = .idle; sampleStatus = .idle; exportStatus = .idle
        speakers = []; selectedSpeaker = nil
        stream(engine.run(["separate", "--job", jobDir.path])) { [weak self] ev in
            guard let self else { return }
            self.language = ev.payload["language"] as? String
            let list = ev.payload["speakers"] as? [[String: Any]] ?? []
            self.speakers = list.compactMap { d in
                guard let id = d["id"] as? String, let prev = d["preview"] as? String else { return nil }
                return Speaker(id: id,
                               duration: (d["duration"] as? NSNumber)?.doubleValue ?? 0,
                               count: (d["count"] as? NSNumber)?.intValue ?? 0,
                               preview: self.jobDir.appendingPathComponent(prev))
            }
            self.selectedSpeaker = self.speakers.first?.id
            self.separateStatus = .done
        } onError: { [weak self] in self?.separateStatus = .failed }
    }

    // MARK: - 3. 변환

    func convert() {
        guard let spk = selectedSpeaker else { return }
        stopPlayback()
        convertStatus = .running
        sampleStatus = .idle; exportStatus = .idle
        stream(engine.run(["convert", "--job", jobDir.path, "--speaker", spk,
                           "--sovits-epochs", "\(sovitsEpochs)", "--gpt-epochs", "\(gptEpochs)"])) { [weak self] _ in
            self?.convertStatus = .done
        } onError: { [weak self] in self?.convertStatus = .failed }
    }

    // MARK: - 4. 샘플 재생

    func playSample() {
        let wav = sampleURL  // UI 언어별 샘플 (언어를 바꾸면 그 언어로 새로 합성)
        if FileManager.default.fileExists(atPath: wav.path) {
            play(wav, id: "sample")
            return
        }
        sampleStatus = .running
        stream(engine.run(["sample", "--job", jobDir.path])) { [weak self] ev in
            guard let self else { return }
            self.sampleStatus = .done
            self.play(wav, id: "sample")
        } onError: { [weak self] in self?.sampleStatus = .failed }
    }

    // MARK: - 5. 내보내기

    func export() {
        let panel = NSSavePanel()
        panel.title = tr(.exportTitle)
        panel.message = tr(.exportMsg)
        let base = (videoName as NSString?)?.deletingPathExtension ?? "voice"
        panel.nameFieldStringValue = "\(base)_\(selectedSpeaker ?? "SPK")"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let out = panel.url else { return }
        exportStatus = .running
        stream(engine.run(["export", "--job", jobDir.path, "--out", out.path, "--name", out.lastPathComponent])) { [weak self] _ in
            self?.exportStatus = .done
            NSWorkspace.shared.activateFileViewerSelecting([out])
        } onError: { [weak self] in self?.exportStatus = .failed }
    }

    /// 현재 UI 언어의 샘플 TTS를 WAV로 저장
    func exportSample() {
        let src = sampleURL
        guard FileManager.default.fileExists(atPath: src.path) else { return }
        let panel = NSSavePanel()
        panel.title = tr(.sampleExportTitle)
        panel.allowedContentTypes = [.wav]
        let base = (videoName as NSString?)?.deletingPathExtension ?? "voice"
        panel.nameFieldStringValue = "\(base)_\(selectedSpeaker ?? "SPK")_sample_\(Loc.shared.lang.rawValue).wav"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let out = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: out.path) { try FileManager.default.removeItem(at: out) }
            try FileManager.default.copyItem(at: src, to: out)
            message = tr(.sampleSaved, out.lastPathComponent)
            NSWorkspace.shared.activateFileViewerSelecting([out])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 재생

    func togglePreview(_ s: Speaker) {
        if playingID == s.id { stopPlayback() } else { play(s.preview, id: s.id) }
    }

    func play(_ url: URL, id: String) {
        stopPlayback()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.play()
            player = p
            playingID = id
            let dur = p.duration
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(dur + 0.1))
                if self?.playingID == id, self?.player?.isPlaying == false { self?.playingID = nil }
            }
        } catch {
            errorMessage = tr(.playFailed, error.localizedDescription)
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playingID = nil
    }

    // MARK: - 공통

    func cancel() {
        engine.cancel()
    }

    func resetJob() {
        stopPlayback()
        try? FileManager.default.removeItem(at: jobDir)
        videoName = nil
        loadStatus = .idle; separateStatus = .idle; convertStatus = .idle; sampleStatus = .idle; exportStatus = .idle
        speakers = []; selectedSpeaker = nil; language = nil
        progress = 0; message = ""; errorMessage = nil
    }

    private func fail(_ error: Error, _ status: inout StepStatus) {
        status = .failed
        errorMessage = error.localizedDescription
        message = tr(.error)
    }

    private func stream(_ s: AsyncThrowingStream<EngineEvent, Error>,
                        onDone: @escaping (EngineEvent) -> Void,
                        onError: @escaping () -> Void) {
        errorMessage = nil
        progress = 0
        task = Task {
            var finished: EngineEvent?
            do {
                for try await ev in s {
                    switch ev.type {
                    case "progress":
                        progress = ev.pct ?? progress
                        if let m = ev.msg, !m.isEmpty { message = m }
                    case "done":
                        finished = ev
                    case "error":
                        errorMessage = ev.msg
                    default:
                        break
                    }
                }
                if let ev = finished {
                    progress = 100
                    onDone(ev)
                } else {
                    throw EngineError(message: errorMessage ?? tr(.errNoResult))
                }
            } catch {
                errorMessage = errorMessage ?? error.localizedDescription
                message = tr(.error)
                onError()
            }
        }
    }
}
