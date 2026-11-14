import Core
import Foundation
import SwiftUI

/// Talks to `tools/devserver.py` on the laptop (PLAN.md §1B.6). While an address is set
/// it polls `/tuning.json` every `Tuning.devTuningPollS` seconds and uploads new log lines
/// to `/log` every `Tuning.devLogUploadS` seconds.
@MainActor
final class DevServerClient: ObservableObject {
    /// e.g. `http://192.168.1.20:8765`; empty = off. Persisted in UserDefaults.
    @Published private(set) var address: String
    /// The tuning in use: built-in defaults until a file has been applied.
    @Published private(set) var tuning = Tuning()
    /// "off", "bad address", "ok", "unreachable", "http <code>" or "bad file".
    @Published private(set) var status = "off"

    private static let addressKey = "devServerAddress"
    private var store = TuningStore()
    private var task: Task<Void, Never>?
    private var lastTuningData: Data?
    private var uploadedSeq: UInt64 = 0
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
        address = UserDefaults.standard.string(forKey: Self.addressKey) ?? ""
        restart()
    }

    func setAddress(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != address else { return }
        address = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.addressKey)
        restart()
    }

    private func restart() {
        task?.cancel()
        task = nil
        lastTuningData = nil
        guard !address.isEmpty else {
            status = "off"
            return
        }
        guard let base = URL(string: address), let scheme = base.scheme,
              scheme == "http" || scheme == "https", base.host != nil else {
            status = "bad address"
            return
        }
        status = "connecting"
        Log.message("dev_server_set", address)
        task = Task { [weak self] in
            var lastUpload = 0.0
            while !Task.isCancelled {
                guard let self else { return }
                await self.pollTuning(base)
                let now = ProcessInfo.processInfo.systemUptime
                if now - lastUpload >= self.tuning.devLogUploadS {
                    await self.uploadLogs(base)
                    lastUpload = now
                }
                let waitS = max(0.5, self.tuning.devTuningPollS)
                try? await Task.sleep(nanoseconds: UInt64(waitS * 1_000_000_000))
            }
        }
    }

    private func pollTuning(_ base: URL) async {
        do {
            let (data, response) = try await session.data(from: base.appendingPathComponent("tuning.json"))
            if Task.isCancelled { return }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else {
                status = "http \(code)"
                return
            }
            guard data != lastTuningData else {
                if status != "bad file" { status = "ok" }
                return
            }
            lastTuningData = data
            let result = store.apply(json: data)
            guard result.applied else {
                status = "bad file"
                Log.message("tuning_rejected", result.error ?? "")
                return
            }
            for key in result.unknownKeys { Log.message("tuning_unknown_key", key) }
            tuning = store.current
            status = "ok"
            Log.event("tuning_applied", ["revision": Double(tuning.revision)])
        } catch {
            if Task.isCancelled { return }
            status = "unreachable"
        }
    }

    private func uploadLogs(_ base: URL) async {
        let lines = Log.shared.lines(after: uploadedSeq)
        guard let last = lines.last else { return }
        var request = URLRequest(url: base.appendingPathComponent("log"))
        request.httpMethod = "POST"
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Content-Type")
        let body = Data((lines.map { $0.jsonLine() }.joined(separator: "\n") + "\n").utf8)
        do {
            let (_, response) = try await session.upload(for: request, from: body)
            if Task.isCancelled { return }
            if (response as? HTTPURLResponse)?.statusCode == 200 {
                uploadedSeq = last.seq
            }
        } catch {
            // Keep the lines; the next upload retries them while they are still in the ring.
        }
    }
}
