import Foundation

/// Screen flow of docs/GUI.md §7. Pure state: the app draws what this decides.

public enum Screen: UInt8, Sendable, Equatable, CaseIterable {
    case launch, menu, settings, practiceBriefing, countdown, match, results, pause, lobby, sync, dead

    /// True when the live camera, not the sky, is the background.
    public var isCameraScreen: Bool {
        switch self {
        case .countdown, .match, .results, .pause, .sync, .dead: return true
        case .launch, .menu, .settings, .practiceBriefing, .lobby: return false
        }
    }
}

public enum FlowEvent: Sendable, Equatable {
    case launchFinished, setUseCount(Bool), tapPractice, tapHost, tapJoin, tapSettings, tapBack, tapStart,
         cameraReady, countdownFinished, roundEnded, tapAgain, tapMenu, tapPause, tapResume, tapLeave,
         allSynced, died, respawned, hostLost
}

public enum TransitionKind: UInt8, Sendable, Equatable {
    case none, sunSlide, sunSlideBack, dusk, dawn, scrimIn, scrimOut, cut
}

public struct FlowStep: Sendable, Equatable {
    public var to: Screen
    public var kind: TransitionKind

    public init(to: Screen, kind: TransitionKind) {
        self.to = to
        self.kind = kind
    }
}

public struct AppFlow: Sendable, Equatable {
    public private(set) var screen: Screen = .launch
    /// Where Back on the settings screen leads: `.menu` or `.pause`.
    public private(set) var settingsReturn: Screen = .menu
    /// Result of the count vote (GUI.md §7.1); set by `.setUseCount`.
    public private(set) var useCount: Bool = false
    /// True between `tapStart` on the practice briefing and `cameraReady`.
    public private(set) var awaitingCamera: Bool = false

    public init() {}

    /// Applies one event. Returns the step to animate, or nil when the event is ignored in
    /// this state. Two special cases: `.setUseCount` always applies and returns nil, and
    /// `.tapStart` on the practice briefing returns a step of kind `.none` to the same
    /// screen, meaning "start the camera and send `.cameraReady`".
    public mutating func handle(_ e: FlowEvent) -> FlowStep? {
        if case .setUseCount(let value) = e {
            useCount = value
            return nil
        }
        if e == .hostLost {
            return screen.isCameraScreen ? go(.menu, .dawn) : nil
        }
        let liveStart: Screen = useCount ? .countdown : .match

        switch (screen, e) {
        case (.launch, .launchFinished): return go(.menu, .sunSlide)

        case (.menu, .tapPractice): return go(.practiceBriefing, .sunSlide)
        case (.menu, .tapSettings):
            settingsReturn = .menu
            return go(.settings, .sunSlide)
        case (.menu, .tapHost), (.menu, .tapJoin): return go(.lobby, .sunSlide)

        case (.settings, .tapBack):
            return settingsReturn == .pause ? go(.pause, .scrimIn) : go(.menu, .sunSlideBack)

        case (.practiceBriefing, .tapBack): return go(.menu, .sunSlideBack)
        case (.practiceBriefing, .tapStart):
            guard !awaitingCamera else { return nil }
            awaitingCamera = true
            return FlowStep(to: .practiceBriefing, kind: .none)
        case (.practiceBriefing, .cameraReady):
            guard awaitingCamera else { return nil }
            return go(liveStart, .dusk)

        case (.lobby, .tapBack): return go(.menu, .sunSlideBack)
        case (.lobby, .tapStart): return go(.sync, .dusk)

        case (.sync, .allSynced): return go(liveStart, .cut)

        case (.countdown, .countdownFinished): return go(.match, .cut)

        case (.match, .tapPause): return go(.pause, .scrimIn)
        case (.match, .roundEnded): return go(.results, .scrimIn)
        case (.match, .died): return go(.dead, .scrimIn)

        case (.pause, .tapResume): return go(.match, .scrimOut)
        case (.pause, .tapSettings):
            settingsReturn = .pause
            return go(.settings, .sunSlide)
        case (.pause, .tapLeave): return go(.menu, .dawn)

        case (.dead, .respawned): return go(.match, .scrimOut)

        case (.results, .tapAgain): return go(liveStart, .scrimOut)
        case (.results, .tapMenu): return go(.menu, .dawn)

        default: return nil
        }
    }

    private mutating func go(_ to: Screen, _ kind: TransitionKind) -> FlowStep {
        screen = to
        awaitingCamera = false
        return FlowStep(to: to, kind: kind)
    }
}

/// Sun centre as fractions of the screen (x right, y down) and diameter in points.
public struct SunPose: Sendable, Equatable {
    public var x: Float
    public var y: Float
    public var diameterPt: Float

    public init(x: Float, y: Float, diameterPt: Float) {
        self.x = x
        self.y = y
        self.diameterPt = diameterPt
    }
}

/// The sun's place on each sky screen (GUI.md §4); nil on camera screens.
public func sunPose(for s: Screen) -> SunPose? {
    switch s {
    case .launch: return SunPose(x: 0.50, y: 0.38, diameterPt: 200)
    case .menu: return SunPose(x: 0.50, y: 0.14, diameterPt: 96)
    case .settings: return SunPose(x: 0.86, y: 0.08, diameterPt: 56)
    case .practiceBriefing: return SunPose(x: 0.18, y: 0.12, diameterPt: 72)
    case .lobby: return SunPose(x: 0.82, y: 0.12, diameterPt: 72)
    case .countdown, .match, .results, .pause, .sync, .dead: return nil
    }
}

/// Whether the skyline silhouette is drawn on a sky screen (GUI.md §4).
public func hasSkyline(_ s: Screen) -> Bool {
    switch s {
    case .launch, .menu, .practiceBriefing, .lobby: return true
    default: return false
    }
}
