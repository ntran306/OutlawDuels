import Foundation

/// Constant-velocity Kalman filter for one axis (PLAN.md §5.1).
/// State [p, v]; white-noise acceleration `sigmaA`; measurement noise `sigmaZ`.
public struct KalmanCv1D: Sendable {
    public var sigmaZ: Double
    public var sigmaA: Double
    public var v0: Double
    public var gateSigma: Double
    public var gateMaxSkips: Int

    public private(set) var p: Double = 0
    public private(set) var v: Double = 0
    public private(set) var isInitialised = false
    private var p00 = 0.0
    private var p01 = 0.0
    private var p11 = 0.0
    private var lastTime = 0.0
    private var skips = 0

    public init(sigmaZ: Double, sigmaA: Double, v0: Double, gateSigma: Double = 5, gateMaxSkips: Int = 3) {
        self.sigmaZ = sigmaZ
        self.sigmaA = sigmaA
        self.v0 = v0
        self.gateSigma = gateSigma
        self.gateMaxSkips = gateMaxSkips
    }

    public mutating func reset() {
        isInitialised = false
        skips = 0
    }

    private mutating func initialise(_ z: Double, _ t: Double) {
        p = z
        v = 0
        p00 = sigmaZ * sigmaZ
        p01 = 0
        p11 = v0 * v0
        lastTime = t
        skips = 0
        isInitialised = true
    }

    /// Feeds one measurement taken at `t` seconds and returns the filtered position.
    /// `dt` is the difference of measurement timestamps. A measurement outside the gate
    /// is skipped; after `gateMaxSkips` skips in a row the next one re-initialises.
    /// A measurement with `t` not after the previous one is ignored.
    @discardableResult
    public mutating func update(_ z: Double, at t: Double) -> Double {
        guard isInitialised else {
            initialise(z, t)
            return p
        }
        guard t > lastTime else { return p }
        if skips >= gateMaxSkips {
            initialise(z, t)
            return p
        }
        let dt = t - lastTime
        lastTime = t

        // Predict.
        p += v * dt
        let q = sigmaA * sigmaA
        let n00 = p00 + dt * (2 * p01 + dt * p11) + q * dt * dt * dt * dt / 4
        let n01 = p01 + dt * p11 + q * dt * dt * dt / 2
        let n11 = p11 + q * dt * dt
        p00 = n00
        p01 = n01
        p11 = n11

        // Update, with the outlier gate.
        let y = z - p
        let s = p00 + sigmaZ * sigmaZ
        if y * y > gateSigma * gateSigma * s {
            skips += 1
            return p
        }
        skips = 0
        let k0 = p00 / s
        let k1 = p01 / s
        p += k0 * y
        v += k1 * y
        let u00 = (1 - k0) * p00
        let u01 = (1 - k0) * p01
        let u11 = p11 - k1 * p01
        p00 = u00
        p01 = u01
        p11 = u11
        return p
    }

    /// Position extrapolated to `t` (no state change). Before any measurement returns 0.
    public func predicted(at t: Double) -> Double {
        isInitialised ? p + v * (t - lastTime) : 0
    }
}

/// Two independent `KalmanCv1D` filters for a `Vec2`.
public struct KalmanCv2D: Sendable {
    public private(set) var x: KalmanCv1D
    public private(set) var y: KalmanCv1D

    public init(sigmaZ: Double, sigmaA: Double, v0: Double, gateSigma: Double = 5, gateMaxSkips: Int = 3) {
        x = KalmanCv1D(sigmaZ: sigmaZ, sigmaA: sigmaA, v0: v0, gateSigma: gateSigma, gateMaxSkips: gateMaxSkips)
        y = x
    }

    public var isInitialised: Bool { x.isInitialised }

    public mutating func reset() {
        x.reset()
        y.reset()
    }

    public mutating func update(_ z: Vec2, at t: Double) -> Vec2 {
        Vec2(Float(x.update(Double(z.x), at: t)), Float(y.update(Double(z.y), at: t)))
    }

    public func predicted(at t: Double) -> Vec2 {
        Vec2(Float(x.predicted(at: t)), Float(y.predicted(at: t)))
    }
}
