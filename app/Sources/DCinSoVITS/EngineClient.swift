import Foundation

/// Python 엔진(dcin_engine)이 stdout으로 보내는 JSON-lines 한 줄.
struct EngineEvent: @unchecked Sendable {
    let type: String
    let stage: String?
    let pct: Double?
    let msg: String?
    let payload: [String: Any]

    init?(line: String) {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return nil }
        self.type = type
        self.stage = obj["stage"] as? String
        self.pct = (obj["pct"] as? NSNumber)?.doubleValue
        self.msg = obj["msg"] as? String
        self.payload = obj
    }
}

struct EngineError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// 엔진 런타임은 앱 번들 밖(~/Library/Application Support/DCinSoVITS)에 설치되어 앱 용량을 작게 유지한다.
final class EngineClient: @unchecked Sendable {
    static let shared = EngineClient()

    let root: URL = {
        if let custom = ProcessInfo.processInfo.environment["DCIN_ROOT"] {
            return URL(fileURLWithPath: custom)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppInfo.name)
    }()

    var python: URL { root.appendingPathComponent("venv/bin/python") }
    var jobsDir: URL { root.appendingPathComponent("jobs") }
    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: root.appendingPathComponent(".ready").path)
            && FileManager.default.isExecutableFile(atPath: python.path)
    }

    /// 번들 Resources/engine → 환경변수 → 개발 중(swift run) 상위 폴더 탐색 순으로 찾는다.
    let engineDir: URL? = {
        let fm = FileManager.default
        if let res = Bundle.main.resourceURL?.appendingPathComponent("engine"),
           fm.fileExists(atPath: res.appendingPathComponent("dcin_engine").path) { return res }
        if let env = ProcessInfo.processInfo.environment["DCIN_ENGINE_DIR"] { return URL(fileURLWithPath: env) }
        var dir = Bundle.main.executableURL?.deletingLastPathComponent()
        for _ in 0..<8 {
            guard let d = dir else { break }
            let cand = d.appendingPathComponent("engine")
            if fm.fileExists(atPath: cand.appendingPathComponent("dcin_engine").path) { return cand }
            dir = d.deletingLastPathComponent()
        }
        return nil
    }()

    private var current: Process?
    private let lock = NSLock()

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        current?.terminate()
    }

    /// 설치 스크립트 실행
    func install() -> AsyncThrowingStream<EngineEvent, Error> {
        guard let dir = engineDir else { return .failed(tr(.errEngineSource)) }
        return launch(URL(fileURLWithPath: "/bin/bash"), [dir.appendingPathComponent("setup.sh").path])
    }

    /// python -m dcin_engine <args>
    func run(_ args: [String]) -> AsyncThrowingStream<EngineEvent, Error> {
        guard let dir = engineDir else { return .failed(tr(.errEngineSource)) }
        guard isInstalled else { return .failed(tr(.errNotInstalled)) }
        return launch(python, ["-m", "dcin_engine"] + args, extraEnv: ["PYTHONPATH": dir.path])
    }

    private func launch(_ exe: URL, _ args: [String], extraEnv: [String: String] = [:]) -> AsyncThrowingStream<EngineEvent, Error> {
        AsyncThrowingStream { cont in
            let p = Process()
            p.executableURL = exe
            p.arguments = args
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "\(NSHomeDirectory())/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            env["DCIN_ROOT"] = root.path
            env["PYTHONUNBUFFERED"] = "1"
            env["DCIN_LANG"] = Loc.shared.lang.rawValue  // 엔진 메시지 언어
            extraEnv.forEach { env[$0.key] = $0.value }
            p.environment = env

            let out = Pipe(), err = Pipe()
            p.standardOutput = out
            p.standardError = err
            let state = StreamState()

            out.fileHandleForReading.readabilityHandler = { h in
                let data = h.availableData
                guard !data.isEmpty else { return }
                for line in state.feed(data) {
                    if let ev = EngineEvent(line: line) {
                        if ev.type == "error" { state.setError(ev.msg ?? tr(.errUnknown)) }
                        cont.yield(ev)
                    }
                }
            }
            err.fileHandleForReading.readabilityHandler = { h in
                let data = h.availableData
                if !data.isEmpty { state.appendStderr(data) }
            }
            p.terminationHandler = { proc in
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                if let rest = try? out.fileHandleForReading.readToEnd() {
                    for line in state.feed(rest) { if let ev = EngineEvent(line: line) { cont.yield(ev) } }
                }
                if proc.terminationReason == .uncaughtSignal {
                    cont.finish(throwing: EngineError(message: tr(.cancelled)))
                } else if proc.terminationStatus != 0 {
                    cont.finish(throwing: EngineError(message: state.errorMessage()))
                } else {
                    cont.finish()
                }
            }
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                p.currentDirectoryURL = root
                try p.run()
                lock.lock(); current = p; lock.unlock()
            } catch {
                cont.finish(throwing: error)
            }
            cont.onTermination = { @Sendable _ in if p.isRunning { p.terminate() } }
        }
    }
}

private final class StreamState: @unchecked Sendable {
    private var buffer = Data()
    private var stderrTail = ""
    private var engineError: String?
    private let lock = NSLock()

    func feed(_ data: Data) -> [String] {
        lock.lock(); defer { lock.unlock() }
        buffer.append(data)
        var lines: [String] = []
        while let nl = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            if let s = String(data: lineData, encoding: .utf8), !s.isEmpty { lines.append(s) }
        }
        return lines
    }

    func appendStderr(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        stderrTail += String(decoding: data, as: UTF8.self)
        if stderrTail.count > 4000 { stderrTail = String(stderrTail.suffix(4000)) }
    }

    func setError(_ msg: String) {
        lock.lock(); engineError = msg; lock.unlock()
    }

    func errorMessage() -> String {
        lock.lock(); defer { lock.unlock() }
        if let e = engineError { return e }
        let tail = stderrTail.split(separator: "\n").suffix(6).joined(separator: "\n")
        return tail.isEmpty ? tr(.errEngineFailed) : tail
    }
}

extension AsyncThrowingStream where Element == EngineEvent, Failure == Error {
    static func failed(_ msg: String) -> Self {
        AsyncThrowingStream { $0.finish(throwing: EngineError(message: msg)) }
    }
}
