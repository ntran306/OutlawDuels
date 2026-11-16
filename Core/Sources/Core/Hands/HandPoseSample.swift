import Foundation

/// MediaPipe landmark order, also used for Apple Vision results (PLAN.md §7.2).
public enum HandLandmark {
    public static let wrist = 0
    public static let thumbTip = 4
    public static let indexMcp = 5
    public static let indexPip = 6
    public static let indexDip = 7
    public static let indexTip = 8
    public static let middleMcp = 9
    public static let ringMcp = 13
    public static let ringTip = 16
    public static let pinkyMcp = 17
    public static let pinkyTip = 20
    public static let count = 21
}

/// One hand-tracker result (PLAN.md §12).
public struct HandPoseSample: Sendable, Equatable {
    /// `ARFrame.timestamp` of the camera frame, seconds since boot.
    public var captureTimeSec: Double
    /// Camera pose of that frame; local frame, metres.
    public var worldFromCamera: Pose
    public var isRightHand: Bool
    /// Tracker confidence 0...1.
    public var score: Float
    /// 21 points, viewport units 0...1, origin bottom-left.
    public var viewport: [Vec2]
    /// 21 points used for the shape measures of §7.2, which are ratios of distances.
    /// MediaPipe: hand-centred world landmarks in metres. Apple Vision has no 3D hand
    /// landmarks, so its tracker fills this with the 2D points in isotropic screen units
    /// (x * viewAspect, y, 0); the ratios then depend on the viewing angle.
    public var worldM: [Vec3]

    public init(
        captureTimeSec: Double, worldFromCamera: Pose, isRightHand: Bool, score: Float,
        viewport: [Vec2], worldM: [Vec3]
    ) {
        self.captureTimeSec = captureTimeSec
        self.worldFromCamera = worldFromCamera
        self.isRightHand = isRightHand
        self.score = score
        self.viewport = viewport
        self.worldM = worldM
    }
}

/// Maps a point of the upright camera image onto the screen when the image is drawn
/// aspect-fill, the way the AR view draws it. Both spaces are 0...1, origin bottom-left.
public enum ViewportMapping {
    /// - Parameters:
    ///   - imageAspect: width / height of the upright image.
    ///   - viewAspect: width / height of the screen.
    public static func aspectFill(_ p: Vec2, imageAspect: Float, viewAspect: Float) -> Vec2 {
        guard imageAspect > 0, viewAspect > 0 else { return p }
        if imageAspect > viewAspect {
            // Image is wider than the screen: full height shown, sides cropped.
            return Vec2(0.5 + (p.x - 0.5) * imageAspect / viewAspect, p.y)
        }
        return Vec2(p.x, 0.5 + (p.y - 0.5) * viewAspect / imageAspect)
    }

    /// The 2D stand-in for `HandPoseSample.worldM`: isotropic units of one screen height.
    public static func isotropic(_ p: Vec2, viewAspect: Float) -> Vec3 {
        Vec3(p.x * viewAspect, p.y, 0)
    }
}
