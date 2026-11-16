import Testing
@testable import Core

@Suite struct KalmanTests {
    private func fingertip() -> KalmanCv1D { KalmanCv1D(sigmaZ: 0.004, sigmaA: 8, v0: 1) }

    @Test func firstMeasurementInitialises() {
        var k = fingertip()
        #expect(!k.isInitialised)
        let first = k.update(0.3, at: 10)
        #expect(first == 0.3)
        #expect(k.isInitialised)
        #expect(k.v == 0)
    }

    @Test func constantValueStaysPut() {
        var k = fingertip()
        for i in 0..<60 { k.update(0.5, at: Double(i) / 30) }
        #expect(abs(k.p - 0.5) < 1e-9)
        #expect(abs(k.v) < 1e-9)
    }

    @Test func tracksConstantVelocityAndLearnsIt() {
        var k = fingertip()
        for i in 0..<90 {
            let t = Double(i) / 30
            k.update(0.2 + 0.3 * t, at: t)
        }
        let t = 89.0 / 30
        #expect(abs(k.p - (0.2 + 0.3 * t)) < 0.002)
        #expect(abs(k.v - 0.3) < 0.02)
        #expect(abs(k.predicted(at: t + 0.08) - (0.2 + 0.3 * (t + 0.08))) < 0.004)
    }

    @Test func reducesMeasurementNoise() {
        // Deterministic +/- 0.004 jitter around 0.5: the filtered error must be smaller.
        var k = fingertip()
        var worst = 0.0
        for i in 0..<120 {
            let noise = (i % 2 == 0 ? 1.0 : -1.0) * 0.004
            let out = k.update(0.5 + noise, at: Double(i) / 30)
            if i > 30 { worst = max(worst, abs(out - 0.5)) }
        }
        #expect(worst < 0.004 * 0.8)
    }

    @Test func outlierIsGatedThenFilterReinitialises() {
        var k = fingertip()
        for i in 0..<30 { k.update(0.5, at: Double(i) / 30) }
        // One wild sample: skipped.
        let wild = k.update(0.9, at: 30.0 / 30)
        #expect(abs(wild - 0.5) < 1e-6)
        // Back to normal: accepted, still at 0.5.
        let normal = k.update(0.5, at: 31.0 / 30)
        #expect(abs(normal - 0.5) < 1e-6)
        // Three skips in a row (GATE_MAX_SKIPS), then the next measurement re-initialises.
        for i in 32..<35 {
            let skipped = k.update(0.9, at: Double(i) / 30)
            #expect(abs(skipped - 0.5) < 1e-6)
        }
        let reinit = k.update(0.9, at: 35.0 / 30)
        #expect(reinit == 0.9)
    }

    @Test func staleTimestampIsIgnoredAndResetWorks() {
        var k = fingertip()
        k.update(0.5, at: 1.0)
        let same = k.update(0.7, at: 1.0)
        let older = k.update(0.7, at: 0.5)
        k.reset()
        let fresh = k.update(0.7, at: 0.5)
        #expect(same == 0.5)
        #expect(older == 0.5)
        #expect(fresh == 0.7)
    }

    @Test func twoAxesAreIndependent() {
        var k = KalmanCv2D(sigmaZ: 0.004, sigmaA: 8, v0: 1)
        for i in 0..<60 {
            let t = Double(i) / 30
            _ = k.update(Vec2(0.5, Float(0.1 + 0.2 * t)), at: t)
        }
        let out = k.predicted(at: 59.0 / 30)
        #expect(abs(out.x - 0.5) < 1e-4)
        #expect(abs(Double(out.y) - (0.1 + 0.2 * 59.0 / 30)) < 0.003)
    }
}

@Suite struct ViewportMappingTests {
    @Test func widerImageIsCroppedAtTheSides() {
        // 4:3 camera upright (0.75) on an iPhone 12 screen (390 / 844 = 0.462).
        let view: Float = 390.0 / 844.0
        let centre = ViewportMapping.aspectFill(Vec2(0.5, 0.5), imageAspect: 0.75, viewAspect: view)
        #expect(centre == Vec2(0.5, 0.5))
        let p = ViewportMapping.aspectFill(Vec2(0.6, 0.2), imageAspect: 0.75, viewAspect: view)
        #expect(abs(p.x - (0.5 + 0.1 * 0.75 / view)) < 1e-6)
        #expect(p.y == 0.2)
        // The visible part of the image maps onto exactly 0...1.
        let half = view / 0.75 / 2
        let edge = ViewportMapping.aspectFill(Vec2(0.5 + half, 0), imageAspect: 0.75, viewAspect: view)
        #expect(abs(edge.x - 1) < 1e-5)
    }

    @Test func tallerImageIsCroppedTopAndBottom() {
        let p = ViewportMapping.aspectFill(Vec2(0.3, 0.6), imageAspect: 0.4, viewAspect: 0.5)
        #expect(p.x == 0.3)
        #expect(abs(p.y - (0.5 + 0.1 * 0.5 / 0.4)) < 1e-6)
    }

    @Test func isotropicUnitsKeepDistancesEqualInBothAxes() {
        let a = ViewportMapping.isotropic(Vec2(0, 0), viewAspect: 0.5)
        let b = ViewportMapping.isotropic(Vec2(0.2, 0), viewAspect: 0.5)   // 0.2 of the width
        let c = ViewportMapping.isotropic(Vec2(0, 0.1), viewAspect: 0.5)   // 0.1 of the height
        #expect(abs((b - a).length - (c - a).length) < 1e-6)
    }
}

@Suite struct BodyAnchorTests {
    private func joint(_ x: Float, _ y: Float, _ c: Float) -> BodyJoint { BodyJoint(point: Vec2(x, y), confidence: c) }

    @Test func neckWinsWhenConfident() {
        let s = BodyAnchor.sighting(neck: joint(0.5, 0.7, 0.9), leftShoulder: joint(0.6, 0.68, 0.9), rightShoulder: joint(0.4, 0.68, 0.9))
        #expect(s?.anchor == Vec2(0.5, 0.7))
        #expect(abs((s?.shoulderWidth ?? 0) - 0.2) < 1e-6)
    }

    @Test func shoulderMidpointWhenNeckIsWeak() {
        let s = BodyAnchor.sighting(neck: joint(0.9, 0.9, 0.29), leftShoulder: joint(0.6, 0.6, 0.3), rightShoulder: joint(0.4, 0.7, 0.3))
        #expect(abs((s?.anchor.x ?? 0) - 0.5) < 1e-6)
        #expect(abs((s?.anchor.y ?? 0) - 0.65) < 1e-6)
    }

    @Test func ignoredWhenNeckAndOneShoulderAreWeak() {
        #expect(BodyAnchor.sighting(neck: joint(0.5, 0.5, 0.1), leftShoulder: joint(0.6, 0.6, 0.9), rightShoulder: joint(0.4, 0.6, 0.2)) == nil)
        #expect(BodyAnchor.sighting(neck: nil, leftShoulder: nil, rightShoulder: nil) == nil)
    }

    @Test func neckAloneGivesZeroWidth() {
        let s = BodyAnchor.sighting(neck: joint(0.5, 0.7, 0.5), leftShoulder: nil, rightShoulder: joint(0.4, 0.68, 0.9))
        #expect(s == PlayerSighting(anchor: Vec2(0.5, 0.7), shoulderWidth: 0))
    }
}
