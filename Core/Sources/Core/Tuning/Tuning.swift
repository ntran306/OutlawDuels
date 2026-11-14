import Foundation

/// Every named scalar (T) constant of PLAN.md, with the plan's starting value as default.
/// JSON keys in `tools/tuning.json` are the property names. The plan's SCREAMING_CASE
/// names map to camelCase here (`GUN_BASE_DAMAGE` -> `gunBaseDamage`).
/// Units are in the name suffix: M metres, S seconds, Ms milliseconds, Deg degrees,
/// Rad radians, Hz per second, Px pixels, Pct percent; a `...SpeedMs` is metres/second.
/// Unnamed or non-scalar (T) values (haptic patterns, enums, calibration fractions) are
/// added by the phase that first uses them.
public struct Tuning: Codable, Sendable, Equatable {
    /// Revision of the tuning file in use; shown on the HUD. 0 = built-in defaults.
    public var revision: Int = 0

    // §1B.6 dev tools
    public var devTuningPollS: Double = 2.0
    public var devLogUploadS: Double = 5.0

    // §1A.3 health, damage, ammunition; §10.3 life state
    public var gunBaseDamage: Double = 10
    public var resistFloor: Double = 0.5
    public var gunMagSize: Int = 6
    public var reloadHandOffMs: Double = 300
    public var maxHp: Double = 100
    public var respawnWaitS: Double = 3.0
    public var spawnProtectS: Double = 2.0

    // §1A.4 bow accuracy circle; §9 bow
    public var bowSpreadMaxDeg: Double = 6.0
    public var bowFullAccuracyS: Double = 1.2
    public var bowGoldDeg: Double = 0.5
    public var drawFullM: Double = 0.35
    public var minFirePower: Double = 0.10

    // §1B.2 aim filter in room space
    public var aimSigmaZRad: Double = 0.004
    public var aimSigmaARadS2: Double = 12
    public var aimV0RadS: Double = 1.5
    public var reticlePredictMaxMs: Double = 80

    // §5.1 Kalman filters: measurement sigma and acceleration sigma per signal
    public var fingertipSigmaZ: Double = 0.004      // viewport units
    public var fingertipSigmaA: Double = 8          // viewport units / s^2
    public var remoteSigmaZM: Double = 0.01
    public var remoteSigmaAMs2: Double = 4          // m / s^2
    public var palmSigmaZM: Double = 0.02
    public var palmSigmaAMs2: Double = 6            // m / s^2
    public var gateSigma: Double = 5
    public var gateMaxSkips: Int = 3
    public var predictMaxMs: Double = 250

    // §1B.3 shot effects
    public var muzzleDistM: Double = 0.45
    public var tracerMaxM: Double = 30
    public var tracerSpeedMs: Double = 80           // m / s
    public var tracerFadeS: Double = 0.08
    public var tracerPool: Int = 12
    public var impactPool: Int = 8

    // §1B.4 bot opponent and loopback transport
    public var loopbackDelayMs: Double = 20
    public var loopbackJitterMs: Double = 10
    public var loopbackLossPct: Double = 2
    public var botFireIntervalS: Double = 2.0
    public var botHitChance: Double = 0.30

    // §1B.7 camera-based correction
    public var bodyPoseHz: Double = 10
    public var bodyPoseMaxRangeM: Double = 12
    public var bodyJointMinConf: Double = 0.3
    public var assocGateDeg: Double = 15
    public var assocAmbiguityRatio: Double = 0.6
    public var assocMaxResidualM: Double = 0.75
    public var neckBelowPhoneM: Double = 0.20
    public var headAboveNeckM: Double = 0.20
    public var driftQM2PerS: Double = 0.0004
    public var driftRM: Double = 0.10
    public var driftP0M: Double = 0.30
    public var driftMaxM: Double = 1.0
    public var snapMaxAgeMs: Double = 150
    public var hostCheckRadiusM: Double = 1.25

    // §6 sync marker
    public var syncWindowS: Double = 1.0
    public var syncMinSamples: Int = 20
    public var syncMaxYawStdDeg: Double = 1.0
    public var syncMaxPosStdM: Double = 0.01
    public var syncHostMaxSpeedMs: Double = 0.05    // m / s
    public var syncMarkerMaxTiltDeg: Double = 30
    public var syncRangeMinM: Double = 0.3
    public var syncRangeMaxM: Double = 0.8

    // §8 hit test
    public var hitSphereRadiusM: Double = 0.25
    public var headBackOffsetM: Double = 0.15
    public var minRangeM: Double = 1.0
    public var maxRangeM: Double = 30
    public var maskMinFraction: Double = 0.30
    public var maskMinRadiusPx: Double = 3
    public var ownHandMaxM: Double = 1.0
    public var depthTolMinM: Double = 0.75
    public var depthTolFrac: Double = 0.25
    public var obscuredMinFraction: Double = 0.20
    public var obscuredRetryFrames: Int = 3

    // §10.2 match flow; §17 Phase 3 duel
    public var tdmTimeLimitS: Double = 300
    public var duelKillTarget: Int = 5
    public var duelTimeLimitS: Double = 180

    // §11 killcam
    public var clipFps: Double = 15
    public var clipJpegQuality: Double = 0.60
    public var clipChunkBytes: Int = 32_000

    public init() {}
}

/// Holds the tuning in use and applies override files to it (PLAN.md §1B.6).
public struct TuningStore: Sendable {
    public struct ApplyResult: Sendable, Equatable {
        /// False when the file was rejected; `current` is then unchanged.
        public var applied: Bool
        /// Keys in the file that are not `Tuning` properties. Logged, not fatal.
        public var unknownKeys: [String]
        /// Why the file was rejected, or nil.
        public var error: String?
    }

    public private(set) var current = Tuning()

    public init() {}

    /// Replaces `current` with the built-in defaults overridden by every known key in
    /// `json` (a JSON object). A key absent from the file is back at its default.
    /// A file that is not a JSON object, or that gives a known key a value of the wrong
    /// type (e.g. 2.5 for an integer field), is rejected whole.
    public mutating func apply(json: Data) -> ApplyResult {
        do {
            guard let overrides = try JSONSerialization.jsonObject(with: json) as? [String: Any] else {
                return ApplyResult(applied: false, unknownKeys: [], error: "top level is not a JSON object")
            }
            let defaultsData = try JSONEncoder().encode(Tuning())
            guard var merged = try JSONSerialization.jsonObject(with: defaultsData) as? [String: Any] else {
                return ApplyResult(applied: false, unknownKeys: [], error: "defaults did not encode to an object")
            }
            var unknown: [String] = []
            for (key, value) in overrides {
                if merged[key] == nil {
                    unknown.append(key)
                } else {
                    merged[key] = value
                }
            }
            let mergedData = try JSONSerialization.data(withJSONObject: merged)
            current = try JSONDecoder().decode(Tuning.self, from: mergedData)
            return ApplyResult(applied: true, unknownKeys: unknown.sorted(), error: nil)
        } catch {
            return ApplyResult(applied: false, unknownKeys: [], error: String(describing: error))
        }
    }
}
