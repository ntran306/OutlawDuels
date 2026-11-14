import Foundation

/// One log line. Serialised as one JSON object per line:
/// `{"e":"name","f":{"k":1.5},"m":"text","seq":7,"t":12.345}`.
public struct LogLine: Codable, Sendable, Equatable {
    /// 1-based sequence number, never reused; gaps appear only if lines were overwritten.
    public var seq: UInt64
    /// `ProcessInfo.systemUptime` at the event, seconds.
    public var t: Double
    /// Event name.
    public var e: String
    /// Numeric fields.
    public var f: [String: Double]
    /// Optional free text.
    public var m: String?

    public func jsonLine() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        guard let data = try? encoder.encode(self), let text = String(data: data, encoding: .utf8) else {
            return "{\"e\":\"log_encode_failed\",\"seq\":\(seq)}"
        }
        return text
    }
}

/// A thread-safe ring of the most recent `capacity` log lines (PLAN.md §1B.6).
public final class LogRing: @unchecked Sendable {
    public let capacity: Int
    private let lock = NSLock()
    private var lines: [LogLine] = []
    private var nextSeq: UInt64 = 1

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        lines.reserveCapacity(self.capacity)
    }

    public func append(_ name: String, _ fields: [String: Double] = [:], message: String? = nil, t: Double) {
        lock.lock()
        defer { lock.unlock() }
        if lines.count == capacity { lines.removeFirst() }
        lines.append(LogLine(seq: nextSeq, t: t, e: name, f: fields, m: message))
        nextSeq += 1
    }

    /// The newest `count` lines, oldest first.
    public func tail(_ count: Int) -> [LogLine] {
        lock.lock()
        defer { lock.unlock() }
        return Array(lines.suffix(max(0, count)))
    }

    /// Lines with `seq > after`, oldest first; used to upload only what is new.
    public func lines(after seq: UInt64) -> [LogLine] {
        lock.lock()
        defer { lock.unlock() }
        return lines.filter { $0.seq > seq }
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return lines.count
    }
}

/// The app-wide log: a ring of 2,000 lines, shown in the overlay and uploaded to the
/// dev server.
public enum Log {
    public static let shared = LogRing(capacity: 2000)

    public static func event(_ name: String, _ fields: [String: Double] = [:]) {
        shared.append(name, fields, t: ProcessInfo.processInfo.systemUptime)
    }

    public static func message(_ name: String, _ text: String) {
        shared.append(name, message: text, t: ProcessInfo.processInfo.systemUptime)
    }
}
