import Foundation

/// Called once per processed camera frame, on any thread. `sample` is nil when no hand was
/// seen in that frame; `frameTimeSec` is the frame's capture time (seconds since boot).
public typealias HandResultHandler = @Sendable (_ sample: HandPoseSample?, _ frameTimeSec: Double) -> Void

/// A source of hand results (PLAN.md §7.1, §12): the Apple Vision tracker on the device,
/// later MediaPipe and a replay of recorded files. Results are pushed, and frames without
/// a hand are reported too, because the reload and hand-lost timers count them.
public protocol HandTracker: AnyObject {
    func setHandHandler(_ handler: HandResultHandler?)
}

/// Reports nothing. For menus and tests.
public final class NullHandTracker: HandTracker {
    public init() {}
    public func setHandHandler(_ handler: HandResultHandler?) {}
}
