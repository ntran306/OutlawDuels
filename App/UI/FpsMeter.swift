import QuartzCore
import SwiftUI

/// Counts display refreshes on the main run loop. A main-thread stall or a slow frame
/// shows as a lower number. `fps` is the mean over the last 1.0 s window; `minFps` is
/// the lowest window since start, ignoring the first 3 s while ARKit starts up.
@MainActor
final class FpsMeter: NSObject, ObservableObject {
    @Published private(set) var fps: Double = 0
    @Published private(set) var minFps: Double = 0
    @Published private(set) var elapsedS: Double = 0

    private static let windowS: Double = 1.0
    private static let warmupS: Double = 3.0

    private var link: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var windowStart: CFTimeInterval = 0
    private var framesInWindow = 0
    private var hasMin = false

    func start() {
        guard link == nil else { return }
        startTime = 0
        windowStart = 0
        framesInWindow = 0
        hasMin = false
        let newLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        newLink.add(to: .main, forMode: .common)
        link = newLink
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ sender: CADisplayLink) {
        let now = sender.timestamp
        if startTime == 0 {
            startTime = now
            windowStart = now
            return
        }
        framesInWindow += 1
        let span = now - windowStart
        guard span >= Self.windowS else { return }

        let value = Double(framesInWindow) / span
        fps = value
        elapsedS = now - startTime
        if elapsedS >= Self.warmupS, !hasMin || value < minFps {
            minFps = value
            hasMin = true
        }
        framesInWindow = 0
        windowStart = now
    }
}
