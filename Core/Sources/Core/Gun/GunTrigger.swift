import Foundation

/// Shape measures of one hand (PLAN.md §7.2); ratios of distances, so unit-free.
public struct GunMeasures: Sendable, Equatable {
    /// Thumb tip to the index segment, over the palm length. Cocked ~0.68, pulled ~0.18.
    public var trigger: Float
    /// Index finger straightness; 1.0 = straight.
    public var straight: Float
    /// Ring and pinky curl; curled ~0.9, open ~1.9.
    public var curl: Float

    public init(trigger: Float, straight: Float, curl: Float) {
        self.trigger = trigger
        self.straight = straight
        self.curl = curl
    }
}

public enum GunGesture {
    /// Returns nil when the sample has no 21 points or the palm length is below 1e-4.
    public static func measure(_ sample: HandPoseSample) -> GunMeasures? {
        let w = sample.worldM
        guard w.count == HandLandmark.count else { return nil }
        let wrist = w[HandLandmark.wrist]
        let ref = (wrist - w[HandLandmark.middleMcp]).length
        guard ref >= 1e-4 else { return nil }

        let mcp = w[HandLandmark.indexMcp]
        let pip = w[HandLandmark.indexPip]
        let dip = w[HandLandmark.indexDip]
        let tip = w[HandLandmark.indexTip]
        let trigger = distance(w[HandLandmark.thumbTip], toSegmentFrom: mcp, to: tip) / ref

        let chain = (pip - mcp).length + (dip - pip).length + (tip - dip).length
        guard chain >= 1e-6 else { return nil }
        let straight = (tip - mcp).length / chain

        let ringBase = (w[HandLandmark.ringMcp] - wrist).length
        let pinkyBase = (w[HandLandmark.pinkyMcp] - wrist).length
        guard ringBase >= 1e-6, pinkyBase >= 1e-6 else { return nil }
        let curl = ((w[HandLandmark.ringTip] - wrist).length / ringBase
            + (w[HandLandmark.pinkyTip] - wrist).length / pinkyBase) / 2

        return GunMeasures(trigger: trigger, straight: straight, curl: curl)
    }

    /// Distance from `p` to the segment a-b, with the parameter clamped to [0, 1].
    static func distance(_ p: Vec3, toSegmentFrom a: Vec3, to b: Vec3) -> Float {
        let ab = b - a
        let lengthSquared = ab.lengthSquared
        guard lengthSquared > 0 else { return (p - a).length }
        let t = max(0, min(1, (p - a).dot(ab) / lengthSquared))
        return (p - (a + ab * t)).length
    }
}

/// Constants of PLAN.md §7.3 (ported from FletchFlow `config.py`). Frame counts assume a
/// 30 Hz tracker.
public struct GunTriggerConfig: Sendable, Equatable {
    public var triggerPull: Float = 0.30
    public var triggerReset: Float = 0.42
    public var triggerGlitch: Float = 2.0
    public var straightOn: Float = 0.85
    public var straightOff: Float = 0.72
    public var curlOn: Float = 1.40
    public var curlOff: Float = 1.65
    public var armFrames = 3
    public var pullFrames = 2
    public var recockFrames = 2
    public var minRefireSec = 0.150
    public var shapeLostFrames = 6
    public var handLostSec = 0.300
    public var aimHistory = 15
    public var aimLookbackMaxSec = 0.250

    public init() {}
}

public enum GunState: UInt8, Sendable, Equatable { case none, cocked, fired }

public enum GunEvent: UInt8, Sendable, Equatable { case cock, shot, lost }

/// What `GunTrigger.update` reports for one tracker frame.
public struct GunSnapshot: Sendable, Equatable {
    public var state: GunState
    /// Events of this frame, in order; usually empty.
    public var events: [GunEvent]
    /// Measures of this frame; nil when there was no hand or the frame was rejected.
    public var measures: GunMeasures?
    /// Trigger travel for the HUD, 0 (cocked) ... 1 (pulled).
    public var triggerTravel: Float
    /// True when no hand has been seen for more than `handLostSec` (also before the first
    /// hand). The magazine reloads on this (PLAN.md §1A.3).
    public var handAbsent: Bool
    /// On a `shot` event: the aim point chosen by the lookback rule. Otherwise nil.
    public var shotAim: Vec2?
}

/// Thumb-drop trigger state machine (PLAN.md §7.3).
public struct GunTrigger: Sendable {
    public var config: GunTriggerConfig
    public private(set) var state: GunState = .none

    private var armCount = 0
    private var pullCount = 0
    private var recockCount = 0
    private var shapeLostCount = 0
    private var lastSeenSec: Double?
    private var lastShotSec = -Double.infinity
    private var history: [(timeSec: Double, aim: Vec2, trigger: Float)] = []

    public init(config: GunTriggerConfig = GunTriggerConfig()) {
        self.config = config
    }

    /// Call once per tracker result. `sample` is nil when the tracker saw no hand.
    /// `aim` is the (filtered) fingertip to remember for the lookback rule; it defaults
    /// to the sample's raw index fingertip.
    public mutating func update(_ sample: HandPoseSample?, nowSec: Double, aim: Vec2? = nil) -> GunSnapshot {
        var events: [GunEvent] = []

        guard let sample else {
            let absent = lastSeenSec.map { nowSec - $0 > config.handLostSec } ?? true
            if absent, state != .none {
                toNone()
                events.append(.lost)
            }
            return GunSnapshot(
                state: state, events: events, measures: nil, triggerTravel: 0, handAbsent: absent, shotAim: nil)
        }
        lastSeenSec = nowSec

        guard let m = GunGesture.measure(sample), m.trigger <= config.triggerGlitch else {
            // Rejected frame or tracking spike: the hand counts as seen, no counter moves.
            return GunSnapshot(
                state: state, events: [], measures: nil, triggerTravel: 0, handAbsent: false, shotAim: nil)
        }

        let fingertip = aim ?? (sample.viewport.count == HandLandmark.count ? sample.viewport[HandLandmark.indexTip] : .zero)
        history.append((nowSec, fingertip, m.trigger))
        if history.count > config.aimHistory { history.removeFirst(history.count - config.aimHistory) }

        let shapeOn = m.straight >= config.straightOn && m.curl <= config.curlOn
        let shapeOff = m.straight < config.straightOff || m.curl > config.curlOff
        var shotAim: Vec2?

        if state != .none {
            shapeLostCount = shapeOff ? shapeLostCount + 1 : 0
            if shapeLostCount >= config.shapeLostFrames {
                toNone()
                events.append(.lost)
            }
        }

        switch state {
        case .none:
            if events.isEmpty {
                armCount = (shapeOn && m.trigger >= config.triggerReset) ? armCount + 1 : 0
                if armCount >= config.armFrames {
                    state = .cocked
                    resetCounters()
                    events.append(.cock)
                }
            }
        case .cocked:
            pullCount = m.trigger <= config.triggerPull ? pullCount + 1 : 0
            if pullCount >= config.pullFrames {
                state = .fired
                resetCounters()
                lastShotSec = nowSec
                shotAim = lookbackAim(nowSec: nowSec, current: fingertip)
                events.append(.shot)
            }
        case .fired:
            recockCount = m.trigger >= config.triggerReset ? recockCount + 1 : 0
            if recockCount >= config.recockFrames, nowSec - lastShotSec >= config.minRefireSec {
                state = .cocked
                resetCounters()
                events.append(.cock)
            }
        }

        let span = config.triggerReset - config.triggerPull
        let travel = span > 0 ? max(0, min(1, (config.triggerReset - m.trigger) / span)) : 0
        return GunSnapshot(
            state: state, events: events, measures: m, triggerTravel: state == .none ? 0 : travel,
            handAbsent: false, shotAim: shotAim)
    }

    /// Lookback rule: the newest sample in the last 250 ms whose trigger is fully cocked
    /// (in [reset, glitch]); failing that the oldest sample in the window; failing that
    /// the current one. Dropping the thumb jerks the hand, so the firing frame is not used.
    private func lookbackAim(nowSec: Double, current: Vec2) -> Vec2 {
        let window = history.filter { nowSec - $0.timeSec <= config.aimLookbackMaxSec }
        if let cocked = window.last(where: { $0.trigger >= config.triggerReset && $0.trigger <= config.triggerGlitch }) {
            return cocked.aim
        }
        return window.first?.aim ?? current
    }

    private mutating func toNone() {
        state = .none
        resetCounters()
        history.removeAll()
    }

    private mutating func resetCounters() {
        armCount = 0
        pullCount = 0
        recockCount = 0
        shapeLostCount = 0
    }
}

/// Six-round magazine (PLAN.md §1A.3). Taking the hand out of view reloads it.
public struct Magazine: Sendable, Equatable {
    public enum FireResult: Sendable, Equatable {
        /// A shot left; `remaining` rounds are loaded afterwards (0 = now empty).
        case fired(remaining: Int)
        /// Empty: no shot, click.
        case dry
    }

    public let size: Int
    public private(set) var rounds: Int

    public init(size: Int = 6) {
        self.size = max(1, size)
        rounds = self.size
    }

    public mutating func fire() -> FireResult {
        guard rounds > 0 else { return .dry }
        rounds -= 1
        return .fired(remaining: rounds)
    }

    /// Fills the magazine. Returns false when it was already full (no reload event).
    public mutating func reload() -> Bool {
        guard rounds < size else { return false }
        rounds = size
        return true
    }
}
