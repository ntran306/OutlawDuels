import Testing
@testable import Core

@Suite struct AppFlowTests {
    /// Drives a fresh flow through `events` and returns it.
    private func flow(_ events: FlowEvent...) -> AppFlow {
        var f = AppFlow()
        for e in events { _ = f.handle(e) }
        return f
    }

    private func step(_ f: AppFlow, _ e: FlowEvent) -> FlowStep? {
        var copy = f
        return copy.handle(e)
    }

    private var menu: AppFlow { flow(.launchFinished) }
    private var briefing: AppFlow { flow(.launchFinished, .tapPractice) }
    private var lobby: AppFlow { flow(.launchFinished, .tapHost) }
    private var match: AppFlow { flow(.launchFinished, .tapPractice, .tapStart, .cameraReady) }
    private var pause: AppFlow { flow(.launchFinished, .tapPractice, .tapStart, .cameraReady, .tapPause) }
    private var results: AppFlow { flow(.launchFinished, .tapPractice, .tapStart, .cameraReady, .roundEnded) }

    @Test func startsAtLaunch() {
        let f = AppFlow()
        #expect(f.screen == .launch)
        #expect(f.settingsReturn == .menu)
        #expect(!f.useCount)
    }

    // One test per row of the GUI.md §7 table.

    @Test func launchToMenu() {
        #expect(step(AppFlow(), .launchFinished) == FlowStep(to: .menu, kind: .sunSlide))
    }

    @Test func menuToPractice() {
        #expect(step(menu, .tapPractice) == FlowStep(to: .practiceBriefing, kind: .sunSlide))
    }

    @Test func menuToSettings() {
        #expect(step(menu, .tapSettings) == FlowStep(to: .settings, kind: .sunSlide))
    }

    @Test(arguments: [FlowEvent.tapHost, .tapJoin])
    func menuToLobby(e: FlowEvent) {
        #expect(step(menu, e) == FlowStep(to: .lobby, kind: .sunSlide))
    }

    @Test func settingsBackToMenu() {
        let f = flow(.launchFinished, .tapSettings)
        #expect(step(f, .tapBack) == FlowStep(to: .menu, kind: .sunSlideBack))
    }

    @Test func settingsBackToPause() {
        var f = pause
        #expect(f.handle(.tapSettings) == FlowStep(to: .settings, kind: .sunSlide))
        #expect(f.settingsReturn == .pause)
        #expect(f.handle(.tapBack) == FlowStep(to: .pause, kind: .scrimIn))
    }

    @Test func briefingBackToMenu() {
        #expect(step(briefing, .tapBack) == FlowStep(to: .menu, kind: .sunSlideBack))
    }

    @Test func briefingStartWithCountGoesToCountdown() {
        var f = briefing
        _ = f.handle(.setUseCount(true))
        #expect(f.handle(.tapStart) == FlowStep(to: .practiceBriefing, kind: .none))
        #expect(f.awaitingCamera)
        #expect(f.handle(.cameraReady) == FlowStep(to: .countdown, kind: .dusk))
        #expect(!f.awaitingCamera)
    }

    @Test func briefingStartWithoutCountGoesToMatch() {
        var f = briefing
        _ = f.handle(.setUseCount(false))
        _ = f.handle(.tapStart)
        #expect(f.handle(.cameraReady) == FlowStep(to: .match, kind: .dusk))
    }

    @Test func lobbyBackToMenu() {
        #expect(step(lobby, .tapBack) == FlowStep(to: .menu, kind: .sunSlideBack))
    }

    @Test func lobbyStartToSync() {
        #expect(step(lobby, .tapStart) == FlowStep(to: .sync, kind: .dusk))
    }

    @Test func syncToCountdownWithCount() {
        var f = lobby
        _ = f.handle(.setUseCount(true))
        _ = f.handle(.tapStart)
        #expect(f.handle(.allSynced) == FlowStep(to: .countdown, kind: .cut))
    }

    @Test func syncToMatchWithoutCount() {
        var f = lobby
        _ = f.handle(.tapStart)
        #expect(f.handle(.allSynced) == FlowStep(to: .match, kind: .cut))
    }

    @Test func countdownToMatch() {
        var f = briefing
        _ = f.handle(.setUseCount(true))
        _ = f.handle(.tapStart)
        _ = f.handle(.cameraReady)
        #expect(f.handle(.countdownFinished) == FlowStep(to: .match, kind: .cut))
    }

    @Test func matchToPause() {
        #expect(step(match, .tapPause) == FlowStep(to: .pause, kind: .scrimIn))
    }

    @Test func pauseResume() {
        #expect(step(pause, .tapResume) == FlowStep(to: .match, kind: .scrimOut))
    }

    @Test func pauseToSettings() {
        #expect(step(pause, .tapSettings) == FlowStep(to: .settings, kind: .sunSlide))
    }

    @Test func pauseLeave() {
        #expect(step(pause, .tapLeave) == FlowStep(to: .menu, kind: .dawn))
    }

    @Test func matchToResults() {
        #expect(step(match, .roundEnded) == FlowStep(to: .results, kind: .scrimIn))
    }

    @Test func matchToDeadAndBack() {
        var f = match
        #expect(f.handle(.died) == FlowStep(to: .dead, kind: .scrimIn))
        #expect(f.handle(.respawned) == FlowStep(to: .match, kind: .scrimOut))
    }

    @Test func resultsAgainWithCount() {
        var f = results
        _ = f.handle(.setUseCount(true))
        #expect(f.handle(.tapAgain) == FlowStep(to: .countdown, kind: .scrimOut))
    }

    @Test func resultsAgainWithoutCount() {
        #expect(step(results, .tapAgain) == FlowStep(to: .match, kind: .scrimOut))
    }

    @Test func resultsToMenu() {
        #expect(step(results, .tapMenu) == FlowStep(to: .menu, kind: .dawn))
    }

    @Test func hostLostFromEveryCameraScreenGoesToMenu() {
        var dead = match
        _ = dead.handle(.died)
        var sync = lobby
        _ = sync.handle(.tapStart)
        var countdown = lobby
        _ = countdown.handle(.setUseCount(true))
        _ = countdown.handle(.tapStart)
        _ = countdown.handle(.allSynced)
        for f in [match, pause, results, dead, sync, countdown] {
            #expect(f.screen.isCameraScreen)
            #expect(step(f, .hostLost) == FlowStep(to: .menu, kind: .dawn))
        }
    }

    @Test func hostLostIsIgnoredOnSkyScreens() {
        for f in [AppFlow(), menu, briefing, lobby, flow(.launchFinished, .tapSettings)] {
            #expect(step(f, .hostLost) == nil)
        }
    }

    // Events not in the table return nil and change nothing.

    @Test func eventsNotInTheTableAreIgnored() {
        let all: [FlowEvent] = [
            .launchFinished, .tapPractice, .tapHost, .tapJoin, .tapSettings, .tapBack, .tapStart, .cameraReady,
            .countdownFinished, .roundEnded, .tapAgain, .tapMenu, .tapPause, .tapResume, .tapLeave, .allSynced,
            .died, .respawned, .hostLost,
        ]
        let allowed: [(AppFlow, [FlowEvent])] = [
            (AppFlow(), [.launchFinished]),
            (menu, [.tapPractice, .tapHost, .tapJoin, .tapSettings]),
            (flow(.launchFinished, .tapSettings), [.tapBack]),
            (briefing, [.tapBack, .tapStart]),
            (lobby, [.tapBack, .tapStart]),
            (match, [.tapPause, .roundEnded, .died, .hostLost]),
            (pause, [.tapResume, .tapSettings, .tapLeave, .hostLost]),
            (results, [.tapAgain, .tapMenu, .hostLost]),
        ]
        for (f, ok) in allowed {
            for e in all where !ok.contains(e) {
                var copy = f
                #expect(copy.handle(e) == nil, "\(f.screen) should ignore \(e)")
                #expect(copy == f)
            }
        }
    }

    @Test func cameraReadyWithoutStartIsIgnoredAndStartIsNotRepeated() {
        var f = briefing
        #expect(f.handle(.cameraReady) == nil)
        _ = f.handle(.tapStart)
        #expect(f.handle(.tapStart) == nil)
    }

    @Test func backWhileWaitingForTheCameraCancelsTheStart() {
        var f = briefing
        _ = f.handle(.tapStart)
        #expect(f.handle(.tapBack) == FlowStep(to: .menu, kind: .sunSlideBack))
        #expect(!f.awaitingCamera)
    }

    @Test func setUseCountAppliesAnywhereAndReturnsNil() {
        var f = AppFlow()
        #expect(f.handle(.setUseCount(true)) == nil)
        #expect(f.useCount)
        #expect(f.screen == .launch)
    }

    @Test func sunPosesMatchTheSpec() {
        #expect(sunPose(for: .launch) == SunPose(x: 0.50, y: 0.38, diameterPt: 200))
        #expect(sunPose(for: .menu) == SunPose(x: 0.50, y: 0.14, diameterPt: 96))
        #expect(sunPose(for: .settings) == SunPose(x: 0.86, y: 0.08, diameterPt: 56))
        #expect(sunPose(for: .practiceBriefing) == SunPose(x: 0.18, y: 0.12, diameterPt: 72))
        #expect(sunPose(for: .lobby) == SunPose(x: 0.82, y: 0.12, diameterPt: 72))
        for s in Screen.allCases {
            #expect((sunPose(for: s) == nil) == s.isCameraScreen)
        }
        #expect(hasSkyline(.menu))
        #expect(!hasSkyline(.settings))
    }
}
