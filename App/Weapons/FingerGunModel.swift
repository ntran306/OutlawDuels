import Core
import SwiftUI

/// The finger gun on the device: takes hand samples from a `HandTracker`, smooths the
/// fingertip (PLAN.md §5.1), runs the trigger state machine (§7.3) and the magazine
/// (§1A.3), and publishes what the HUD draws. Also holds the people the camera sees.
@MainActor
final class FingerGunModel: ObservableObject {
    /// 21 hand points in viewport units (origin bottom-left), or empty when no hand.
    @Published private(set) var hand: [Vec2] = []
    /// Smoothed index fingertip, viewport units, or nil when no hand.
    @Published private(set) var aim: Vec2?
    @Published private(set) var gunState: GunState = .none
    @Published private(set) var triggerTravel: Float = 0
    /// Shape measures of the latest frame (PLAN.md §7.2), for tuning on the device.
    @Published private(set) var measures: GunMeasures?
    @Published private(set) var rounds: Int
    /// Where the last shot was aimed and its running number; drives the shot flash.
    @Published private(set) var lastShotAim = Vec2(0.5, 0.5)
    @Published private(set) var shotCount = 0
    /// People seen by the body detector, anchors in viewport units.
    @Published private(set) var sightings: [PlayerSighting] = []
    /// Tracker results per second, measured over the last second.
    @Published private(set) var handRateHz = 0.0

    /// Shots count only while this is true (the match screen; not the countdown or pause).
    var weaponsLive = false

    let pipeline = VisionPipeline()
    let magazineSize: Int

    private let audio: AudioPlayer
    private let currentTuning: @MainActor () -> Tuning
    private var appliedTuning: Tuning
    private var trigger: GunTrigger
    private var magazine: Magazine
    private var filter: KalmanCv2D
    private var lastHandTime: Double?
    private var lastSightingTime = 0.0
    private var rateWindowStart = 0.0
    private var rateCount = 0

    /// `tuning` is read on every hand result, so a change in `tools/tuning.json` takes
    /// effect without a rebuild.
    init(audio: AudioPlayer, tuning currentTuning: @escaping @MainActor () -> Tuning) {
        self.audio = audio
        self.currentTuning = currentTuning
        let tuning = currentTuning()
        appliedTuning = tuning
        trigger = GunTrigger(config: GunTriggerConfig(tuning: tuning))
        magazineSize = tuning.gunMagSize
        magazine = Magazine(size: tuning.gunMagSize)
        rounds = magazine.rounds
        filter = KalmanCv2D(
            sigmaZ: tuning.fingertipSigmaZ, sigmaA: tuning.fingertipSigmaA, v0: 1,
            gateSigma: tuning.gateSigma, gateMaxSkips: tuning.gateMaxSkips)

        let hands: any HandTracker = pipeline
        hands.setHandHandler { [weak self] sample, time in
            Task { @MainActor in self?.handleHand(sample, time: time) }
        }
        pipeline.setBodyHandler { [weak self] sightings, time in
            Task { @MainActor in self?.handleBodies(sightings, time: time) }
        }
    }

    /// Called when the camera stops: forget the hand, keep the magazine.
    func reset() {
        hand = []
        aim = nil
        gunState = .none
        triggerTravel = 0
        measures = nil
        sightings = []
        trigger = GunTrigger(config: GunTriggerConfig(tuning: appliedTuning))
        filter.reset()
        lastHandTime = nil
    }

    func refill() {
        _ = magazine.reload()
        rounds = magazine.rounds
    }

    private func applyTuningIfChanged() {
        let tuning = currentTuning()
        guard tuning != appliedTuning else { return }
        appliedTuning = tuning
        trigger.config = GunTriggerConfig(tuning: tuning)
        filter.setNoise(
            sigmaZ: tuning.fingertipSigmaZ, sigmaA: tuning.fingertipSigmaA,
            gateSigma: tuning.gateSigma, gateMaxSkips: tuning.gateMaxSkips)
    }

    private func handleHand(_ sample: HandPoseSample?, time: Double) {
        applyTuningIfChanged()
        // Results can arrive out of order across the main-actor hop; drop stale ones.
        if let last = lastHandTime, sample != nil, time <= last { return }

        var filtered: Vec2?
        if let sample, sample.viewport.count == HandLandmark.count {
            filtered = filter.update(sample.viewport[HandLandmark.indexTip], at: time)
            lastHandTime = time
            rateCount += 1
        }
        if time - rateWindowStart >= 1 {
            handRateHz = Double(rateCount) / (time - rateWindowStart)
            rateWindowStart = time
            rateCount = 0
        }

        let snapshot = trigger.update(sample, nowSec: time, aim: filtered)

        for event in snapshot.events where event == .shot {
            fire(at: snapshot.shotAim ?? filtered ?? Vec2(0.5, 0.5), snapshot: snapshot)
        }
        if snapshot.handAbsent {
            filter.reset()
            if magazine.reload() {
                rounds = magazine.rounds
                audio.play(.cock)
                Log.event("reload")
            }
        }

        hand = sample?.viewport ?? []
        aim = filtered
        if gunState != snapshot.state { gunState = snapshot.state }
        triggerTravel = snapshot.triggerTravel
        measures = snapshot.measures
    }

    private func fire(at point: Vec2, snapshot: GunSnapshot) {
        guard weaponsLive else { return }
        switch magazine.fire() {
        case .fired(let remaining):
            rounds = remaining
            lastShotAim = point
            shotCount += 1
            audio.play(.shot)
            var fields: [String: Double] = ["x": Double(point.x), "y": Double(point.y), "rounds": Double(remaining)]
            if let m = snapshot.measures {
                fields["trigger"] = Double(m.trigger)
                fields["straight"] = Double(m.straight)
                fields["curl"] = Double(m.curl)
            }
            Log.event("shot", fields)
        case .dry:
            audio.play(.dry)
            Log.event("dry")
        }
    }

    private func handleBodies(_ found: [PlayerSighting], time: Double) {
        guard time >= lastSightingTime else { return }
        lastSightingTime = time
        if found != sightings { sightings = found }
    }
}
