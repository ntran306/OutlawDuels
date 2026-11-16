import Core
import SwiftUI
import UIKit

/// Owns the screen flow (`Core.AppFlow`) and runs the transitions of docs/GUI.md §6.
/// Views read the published values; every change of screen goes through `send(_:)`.
@MainActor
final class AppModel: ObservableObject {
    let dev: DevServerClient
    let audio: AudioPlayer
    let fps = FpsMeter()
    /// Hand tracking, trigger and magazine; also the people the camera sees.
    let gun: FingerGunModel

    // What is on screen.
    @Published private(set) var screen: Screen = .launch
    @Published private(set) var previousScreen: Screen = .launch
    @Published private(set) var inTransition = false
    @Published private(set) var cameraActive = false

    // Sky layer.
    @Published private(set) var sun = SunPose(x: 0.50, y: 0.38, diameterPt: 200)
    @Published private(set) var launchRise: CGFloat = 0.45      // added to sun y, fraction of screen height
    @Published private(set) var skylineRisePt: CGFloat = 48
    @Published private(set) var skylineOpacity: Double = 1
    @Published private(set) var gunOpacity: Double = 1
    @Published private(set) var sunSet = false
    @Published private(set) var skyOpacity: Double = 1

    // Content layer.
    @Published private(set) var contentOpacity: Double = 1
    @Published private(set) var contentOffset: CGFloat = 0
    @Published private(set) var revealed = true
    @Published private(set) var revealDirection: CGFloat = 1

    // Launch screen.
    @Published private(set) var wordmarkShown = false
    @Published private(set) var captionShown = false

    // Settings.
    @Published var showLog = false
    @Published var debugOverlay: Bool {
        didSet { UserDefaults.standard.set(debugOverlay, forKey: Self.debugKey) }
    }
    /// The Practice Range's "3-2-1 count" toggle; it is the whole vote there (GUI.md §7.1).
    @Published var practiceCount: Bool {
        didSet {
            UserDefaults.standard.set(practiceCount, forKey: Self.practiceCountKey)
            _ = flow.handle(.setUseCount(practiceCount))
        }
    }

    var useCount: Bool { flow.useCount }

    private static let debugKey = "debugOverlay"
    private static let practiceCountKey = "practiceCount"

    private var flow = AppFlow()
    private var queued: FlowEvent?
    private var launchStarted = false
    private var launchTask: Task<Void, Never>?
    private var stingPlayed = false

    init() {
        let defaults = UserDefaults.standard
        let devClient = DevServerClient()
        let audioPlayer = AudioPlayer()
        let useCount = defaults.object(forKey: Self.practiceCountKey) as? Bool ?? true
        dev = devClient
        audio = audioPlayer
        gun = FingerGunModel(audio: audioPlayer, tuning: devClient.tuning)
        debugOverlay = defaults.object(forKey: Self.debugKey) as? Bool ?? true
        practiceCount = useCount
        _ = flow.handle(.setUseCount(useCount))

        var fonts: [String: Double] = [:]
        for name in Theme.fontNames {
            fonts[name] = UIFont(name: name, size: 12) == nil ? 0 : 1
        }
        Log.event("fonts_loaded", fonts)
        fps.start()
    }

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    // MARK: Events

    func send(_ event: FlowEvent) {
        if inTransition {
            queued = event   // at most one, newest wins (GUI.md §7)
            return
        }
        let from = flow.screen
        guard let step = flow.handle(event) else { return }
        playSound(for: event)

        if step.kind == .none {
            startCamera()
            return
        }
        inTransition = true
        Task { [weak self] in
            guard let self else { return }
            await self.run(step, from: from)
            self.inTransition = false
            if let next = self.queued {
                self.queued = nil
                self.send(next)
            }
        }
    }

    private func playSound(for event: FlowEvent) {
        switch event {
        case .launchFinished:
            audio.play(.uiWhoosh)
        case .tapPractice, .tapSettings, .tapHost, .tapJoin:
            audio.play(.uiTap)
            audio.play(.uiWhoosh)
        case .tapBack, .tapResume, .tapLeave, .tapMenu:
            audio.play(.uiBack)
        case .tapStart, .tapAgain:
            audio.play(.uiConfirm)
        case .tapPause:
            audio.play(.uiTap)
        default:
            break
        }
    }

    // MARK: Camera start (GUI.md §6 dusk: first frame or 1500 ms)

    private func startCamera() {
        gun.reset()
        gun.refill()
        cameraActive = true
        Log.event("camera_start")
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self?.send(.cameraReady)
        }
    }

    func cameraFrameArrived() {
        Log.event("camera_first_frame")
        send(.cameraReady)
    }

    // MARK: Launch (GUI.md §6)

    func startLaunch() {
        guard !launchStarted else { return }
        launchStarted = true
        Log.event("launch_start")
        let scale = max(0.1, dev.tuning.uiLaunchMs / 1600)

        if reduceMotion {
            instantly {
                launchRise = 0
                skylineRisePt = 0
                wordmarkShown = true
                captionShown = true
                contentOpacity = 0
            }
            withAnimation(.linear(duration: 0.3)) { contentOpacity = 1 }
        } else {
            let rise = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 1.0 * scale)
            withAnimation(rise) {
                launchRise = 0
                skylineRisePt = 0
            }
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.7 * scale).delay(0.6 * scale)) {
                wordmarkShown = true
            }
            withAnimation(.easeOut(duration: 0.4 * scale).delay(1.2 * scale)) {
                captionShown = true
            }
        }

        launchTask = Task { [weak self] in
            await AppModel.pause(100 * scale)
            guard let self, !Task.isCancelled else { return }
            self.playSting()
            await AppModel.pause(1500 * scale + 400)
            guard !Task.isCancelled else { return }
            self.send(.launchFinished)
        }
    }

    /// A tap on the launch screen: jump to the end state and go to the menu.
    func skipLaunch() {
        guard screen == .launch, !inTransition else { return }
        launchTask?.cancel()
        playSting()
        instantly {
            launchRise = 0
            skylineRisePt = 0
            wordmarkShown = true
            captionShown = true
        }
        send(.launchFinished)
    }

    private func playSting() {
        guard !stingPlayed else { return }
        stingPlayed = true
        audio.play(.stingLaunch)
    }

    // MARK: Transitions

    private func run(_ step: FlowStep, from: Screen) async {
        let fields = ["from": Double(from.rawValue), "to": Double(step.to.rawValue), "kind": Double(step.kind.rawValue)]
        Log.event("transition_start", fields)
        switch step.kind {
        case .sunSlide: await slide(to: step.to, back: false)
        case .sunSlideBack: await slide(to: step.to, back: true)
        case .dusk: await dusk(to: step.to)
        case .dawn: await dawn(to: step.to)
        case .scrimIn: await crossfade(to: step.to, outMs: 100, inMs: 200)
        case .scrimOut: await crossfade(to: step.to, outMs: 150, inMs: 150)
        case .cut, .none: instantly { setScreen(step.to) }
        }
        Log.event("transition_end", fields)
        if step.to == .menu { Log.event("menu_shown") }
    }

    private func setScreen(_ to: Screen) {
        previousScreen = screen
        screen = to
        gun.weaponsLive = (to == .match)
    }

    private func applySky(for s: Screen) {
        if let pose = sunPose(for: s) { sun = pose }
        gunOpacity = (s == .launch || s == .menu) ? 1 : 0
        skylineOpacity = hasSkyline(s) ? 1 : 0
        launchRise = 0
        skylineRisePt = 0
    }

    /// Menu-to-menu: old content fades up and out, the sun slides, new content fades in.
    private func slide(to: Screen, back: Bool) async {
        let t = dev.tuning
        if !to.isCameraScreen, cameraActive { cameraActive = false }   // Back while the camera was starting

        if reduceMotion {
            withAnimation(.linear(duration: 0.1)) { contentOpacity = 0 }
            await Self.pause(100)
            instantly {
                setScreen(to)
                applySky(for: to)
                revealed = true
                contentOffset = 0
            }
            withAnimation(.linear(duration: 0.1)) { contentOpacity = 1 }
            await Self.pause(100)
            return
        }

        let direction: CGFloat = back ? 1 : -1
        withAnimation(.timingCurve(0.4, 0, 1, 1, duration: t.uiFadeOutMs / 1000)) {
            contentOpacity = 0
            contentOffset = 8 * direction
        }
        withAnimation(.spring(response: t.uiTransitionMs / 1000, dampingFraction: 0.86)) {
            applySky(for: to)
        }
        await Self.pause(t.uiFadeOutMs)
        instantly {
            setScreen(to)
            revealDirection = -direction
            revealed = false
            contentOpacity = 1
            contentOffset = 0
        }
        await Self.pause(20)
        revealed = true   // each piece animates itself (`Reveal`)
        await Self.pause(max(0, t.uiTransitionMs - t.uiFadeOutMs - 20))
    }

    /// Sky to camera: the sun sets behind the skyline, the skyline drops, the sky fades.
    private func dusk(to: Screen) async {
        let ms = reduceMotion ? 300 : dev.tuning.uiDuskMs
        withAnimation(.easeInOut(duration: ms / 1000)) {
            if !reduceMotion { sunSet = true }
            skyOpacity = 0
            contentOpacity = 0
        }
        await Self.pause(ms)
        instantly {
            setScreen(to)
            revealed = true
            contentOffset = 0
            sunSet = true
        }
        withAnimation(.easeOut(duration: 0.15)) { contentOpacity = 1 }
    }

    /// Camera to sky: the reverse of dusk; the camera stops when it ends.
    private func dawn(to: Screen) async {
        let ms = reduceMotion ? 300 : dev.tuning.uiDuskMs
        withAnimation(.easeOut(duration: 0.15)) { contentOpacity = 0 }
        instantly {
            applySky(for: to)
            if reduceMotion { sunSet = false }
        }
        await Self.pause(20)
        withAnimation(.easeInOut(duration: ms / 1000)) {
            sunSet = false
            skyOpacity = 1
        }
        await Self.pause(150)
        instantly {
            setScreen(to)
            revealDirection = 1
            revealed = false
            contentOpacity = 1
            contentOffset = 0
        }
        await Self.pause(20)
        revealed = true
        await Self.pause(max(0, ms - 190))
        cameraActive = false
        gun.reset()
    }

    /// Scrims and other content-only changes over the camera.
    private func crossfade(to: Screen, outMs: Double, inMs: Double) async {
        withAnimation(.easeIn(duration: outMs / 1000)) { contentOpacity = 0 }
        await Self.pause(outMs)
        instantly {
            setScreen(to)
            revealed = true
        }
        withAnimation(.easeOut(duration: inMs / 1000)) { contentOpacity = 1 }
        await Self.pause(inMs)
    }

    // MARK: Helpers

    private func instantly(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }

    private static func pause(_ ms: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(max(0, ms) * 1_000_000))
    }
}
