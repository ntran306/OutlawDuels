import Testing
@testable import Core

/// Builds a hand whose §7.2 measures are exactly the ones asked for (when `bent` is false,
/// straight = 1.0; when true, straight = 0.33).
func makeHand(
    trigger: Float, curl: Float = 0.9, bent: Bool = false, aim: Vec2 = Vec2(0.5, 0.5), t: Double = 0
) -> HandPoseSample {
    var w = [Vec3](repeating: .zero, count: 21)
    w[HandLandmark.middleMcp] = Vec3(0, 0.1, 0)                 // palm length 0.1
    w[HandLandmark.indexMcp] = Vec3(0.02, 0.10, 0)
    w[HandLandmark.indexPip] = Vec3(0.02, 0.13, 0)
    w[HandLandmark.indexDip] = bent ? Vec3(0.05, 0.13, 0) : Vec3(0.02, 0.15, 0)
    w[HandLandmark.indexTip] = bent ? Vec3(0.05, 0.10, 0) : Vec3(0.02, 0.17, 0)
    w[HandLandmark.thumbTip] = Vec3(0.02 + trigger * 0.1, 0.12, bent ? 0 : 0)
    w[HandLandmark.ringMcp] = Vec3(-0.02, 0.09, 0)
    w[HandLandmark.ringTip] = w[HandLandmark.ringMcp] * curl
    w[HandLandmark.pinkyMcp] = Vec3(-0.04, 0.08, 0)
    w[HandLandmark.pinkyTip] = w[HandLandmark.pinkyMcp] * curl
    var viewport = [Vec2](repeating: Vec2(0.5, 0.5), count: 21)
    viewport[HandLandmark.indexTip] = aim
    return HandPoseSample(
        captureTimeSec: t, worldFromCamera: .identity, isRightHand: true, score: 1, viewport: viewport, worldM: w)
}

@Suite struct GunGestureTests {
    @Test func canonicalCockedHand() throws {
        let m = try #require(GunGesture.measure(makeHand(trigger: 0.68)))
        #expect(abs(m.trigger - 0.68) < 1e-4)
        #expect(abs(m.straight - 1.0) < 1e-4)
        #expect(abs(m.curl - 0.9) < 1e-4)
    }

    @Test func bentIndexIsNotStraight() throws {
        let m = try #require(GunGesture.measure(makeHand(trigger: 0.68, bent: true)))
        #expect(abs(m.straight - 1.0 / 3.0) < 1e-3)
    }

    @Test func thumbIsMeasuredAgainstTheSegmentNotTheLine() {
        // Beyond the fingertip the nearest point is the tip itself.
        let d = GunGesture.distance(Vec3(0, 3, 0), toSegmentFrom: Vec3(0, 0, 0), to: Vec3(0, 1, 0))
        #expect(abs(d - 2) < 1e-6)
        let side = GunGesture.distance(Vec3(1, 0.5, 0), toSegmentFrom: Vec3(0, 0, 0), to: Vec3(0, 1, 0))
        #expect(abs(side - 1) < 1e-6)
    }

    @Test func rejectsDegenerateSamples() {
        var tiny = makeHand(trigger: 0.68)
        tiny.worldM = tiny.worldM.map { $0 * 1e-5 }
        #expect(GunGesture.measure(tiny) == nil)
        var short = makeHand(trigger: 0.68)
        short.worldM.removeLast()
        #expect(GunGesture.measure(short) == nil)
    }
}

@Suite struct GunTriggerTests {
    private let dt = 1.0 / 30.0

    /// Feeds `frames` identical frames starting at `time`, returns all events seen.
    private func feed(
        _ g: inout GunTrigger, _ time: inout Double, frames: Int, trigger: Float?, curl: Float = 0.9,
        bent: Bool = false, aim: Vec2 = Vec2(0.5, 0.5)
    ) -> [GunEvent] {
        var events: [GunEvent] = []
        for _ in 0..<frames {
            let sample = trigger.map { makeHand(trigger: $0, curl: curl, bent: bent, aim: aim, t: time) }
            events += g.update(sample, nowSec: time).events
            time += dt
        }
        return events
    }

    @Test func cocksAfterThreeFramesOfGunShape() {
        var g = GunTrigger()
        var t = 0.0
        #expect(feed(&g, &t, frames: 2, trigger: 0.68).isEmpty)
        #expect(g.state == .none)
        #expect(feed(&g, &t, frames: 1, trigger: 0.68) == [.cock])
        #expect(g.state == .cocked)
    }

    @Test func doesNotCockWithOpenHandOrBentIndexOrPulledThumb() {
        var g = GunTrigger()
        var t = 0.0
        #expect(feed(&g, &t, frames: 10, trigger: 0.68, curl: 1.9).isEmpty)
        #expect(feed(&g, &t, frames: 10, trigger: 0.68, bent: true).isEmpty)
        #expect(feed(&g, &t, frames: 10, trigger: 0.35).isEmpty)
        #expect(g.state == .none)
    }

    @Test func firesAfterTwoPulledFramesAndRecocks() {
        var g = GunTrigger()
        var t = 0.0
        _ = feed(&g, &t, frames: 3, trigger: 0.68)
        #expect(feed(&g, &t, frames: 1, trigger: 0.18).isEmpty)
        #expect(feed(&g, &t, frames: 1, trigger: 0.18) == [.shot])
        #expect(g.state == .fired)
        // Holding the thumb down fires nothing more.
        #expect(feed(&g, &t, frames: 10, trigger: 0.18).isEmpty)
        // Thumb back up: 2 frames re-cock (well past 150 ms since the shot).
        #expect(feed(&g, &t, frames: 2, trigger: 0.68) == [.cock])
        #expect(feed(&g, &t, frames: 2, trigger: 0.18) == [.shot])
    }

    @Test func recockWaitsForMinRefireTime() {
        var g = GunTrigger()
        var t = 0.0
        _ = feed(&g, &t, frames: 3, trigger: 0.68)
        _ = feed(&g, &t, frames: 2, trigger: 0.18)      // shot on the 2nd frame
        // 2 cocked frames arrive 33 and 67 ms after the shot: too early (< 150 ms).
        #expect(feed(&g, &t, frames: 2, trigger: 0.68).isEmpty)
        #expect(g.state == .fired)
        // By the 5th cocked frame 167 ms have passed.
        #expect(feed(&g, &t, frames: 3, trigger: 0.68) == [.cock])
    }

    @Test func betweenThresholdsNothingHappens() {
        var g = GunTrigger()
        var t = 0.0
        _ = feed(&g, &t, frames: 3, trigger: 0.68)
        #expect(feed(&g, &t, frames: 10, trigger: 0.36).isEmpty)
        #expect(g.state == .cocked)
    }

    @Test func onePulledFrameIsNotEnough() {
        var g = GunTrigger()
        var t = 0.0
        _ = feed(&g, &t, frames: 3, trigger: 0.68)
        _ = feed(&g, &t, frames: 1, trigger: 0.18)
        _ = feed(&g, &t, frames: 1, trigger: 0.68)
        #expect(feed(&g, &t, frames: 1, trigger: 0.18).isEmpty)
        #expect(g.state == .cocked)
    }

    @Test func shapeLostForSixFramesDropsToNone() {
        var g = GunTrigger()
        var t = 0.0
        _ = feed(&g, &t, frames: 3, trigger: 0.68)
        #expect(feed(&g, &t, frames: 5, trigger: 0.68, curl: 1.9).isEmpty)
        #expect(feed(&g, &t, frames: 1, trigger: 0.68, curl: 1.9) == [.lost])
        #expect(g.state == .none)
    }

    @Test func noHandForOver300msDropsToNoneAndReportsAbsent() {
        var g = GunTrigger()
        var t = 0.0
        let never = g.update(nil, nowSec: 0)
        #expect(never.handAbsent)      // never seen
        _ = feed(&g, &t, frames: 3, trigger: 0.68)
        let lastSeen = t - dt
        let early = g.update(nil, nowSec: lastSeen + 0.29)
        #expect(!early.handAbsent)
        #expect(g.state == .cocked)
        let snap = g.update(nil, nowSec: lastSeen + 0.31)
        #expect(snap.handAbsent)
        #expect(snap.events == [.lost])
        #expect(g.state == .none)
        let later = g.update(nil, nowSec: lastSeen + 0.40)
        #expect(later.events.isEmpty)
    }

    @Test func glitchFramesMoveNoCounter() {
        var g = GunTrigger()
        var t = 0.0
        _ = feed(&g, &t, frames: 3, trigger: 0.68)
        _ = feed(&g, &t, frames: 1, trigger: 0.18)
        #expect(feed(&g, &t, frames: 3, trigger: 2.5).isEmpty)   // spike: pull count kept
        #expect(feed(&g, &t, frames: 1, trigger: 0.18) == [.shot])
    }

    @Test func shotAimsFromTheLastFullyCockedSample() {
        var g = GunTrigger()
        var t = 0.0
        let steady = Vec2(0.40, 0.60)
        let jerked = Vec2(0.45, 0.50)
        _ = feed(&g, &t, frames: 5, trigger: 0.68, aim: steady)
        var snap = g.update(makeHand(trigger: 0.18, aim: jerked, t: t), nowSec: t)
        t += dt
        snap = g.update(makeHand(trigger: 0.18, aim: jerked, t: t), nowSec: t)
        #expect(snap.events == [.shot])
        #expect(snap.shotAim == steady)
    }

    @Test func filteredAimOverridesTheRawFingertip() {
        var g = GunTrigger()
        var t = 0.0
        let filtered = Vec2(0.1, 0.2)
        for _ in 0..<5 {
            _ = g.update(makeHand(trigger: 0.68, t: t), nowSec: t, aim: filtered)
            t += dt
        }
        _ = g.update(makeHand(trigger: 0.18, t: t), nowSec: t, aim: Vec2(0.9, 0.9))
        t += dt
        let snap = g.update(makeHand(trigger: 0.18, t: t), nowSec: t, aim: Vec2(0.9, 0.9))
        #expect(snap.shotAim == filtered)
    }

    @Test func triggerTravelRunsFromCockedToPulled() {
        var g = GunTrigger()
        var t = 0.0
        _ = feed(&g, &t, frames: 3, trigger: 0.68)
        let cocked = g.update(makeHand(trigger: 0.42, t: t), nowSec: t)
        let half = g.update(makeHand(trigger: 0.36, t: t + dt), nowSec: t + dt)
        let pulled = g.update(makeHand(trigger: 0.10, t: t + 2 * dt), nowSec: t + 2 * dt)
        #expect(cocked.triggerTravel == 0)
        #expect(abs(half.triggerTravel - 0.5) < 1e-4)
        #expect(pulled.triggerTravel == 1)
    }
}

@Suite struct MagazineTests {
    @Test func sixShotsThenDryThenReload() {
        var m = Magazine()
        for remaining in stride(from: 5, through: 0, by: -1) {
            let r = m.fire()
            #expect(r == .fired(remaining: remaining))
        }
        let dry = m.fire()
        #expect(dry == .dry)
        #expect(m.rounds == 0)
        let reloaded = m.reload()
        #expect(reloaded)
        #expect(m.rounds == 6)
    }

    @Test func reloadOfAFullMagazineIsNotAnEvent() {
        var m = Magazine()
        let first = m.reload()
        _ = m.fire()
        let second = m.reload()
        let third = m.reload()
        #expect(!first)
        #expect(second)
        #expect(!third)
    }
}
