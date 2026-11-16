import Foundation

/// One body-pose joint: a point and the detector's confidence 0...1.
public struct BodyJoint: Sendable, Equatable {
    public var point: Vec2
    public var confidence: Float

    public init(point: Vec2, confidence: Float) {
        self.point = point
        self.confidence = confidence
    }
}

/// A person seen by the camera: the anchor used to place them (PLAN.md §1B.7 step 1).
public struct PlayerSighting: Sendable, Equatable {
    /// Neck, or the midpoint of the shoulders; same units as the joints given.
    public var anchor: Vec2
    /// Distance between the shoulders, 0 when either is missing; a rough size on screen.
    public var shoulderWidth: Float

    public init(anchor: Vec2, shoulderWidth: Float) {
        self.anchor = anchor
        self.shoulderWidth = shoulderWidth
    }
}

public enum BodyAnchor {
    /// §1B.7 step 1: the neck if its confidence >= `minConfidence`; else the midpoint of
    /// both shoulders if both reach it; else nil (the person is ignored).
    public static func sighting(
        neck: BodyJoint?, leftShoulder: BodyJoint?, rightShoulder: BodyJoint?, minConfidence: Float = 0.3
    ) -> PlayerSighting? {
        let left = leftShoulder.flatMap { $0.confidence >= minConfidence ? $0.point : nil }
        let right = rightShoulder.flatMap { $0.confidence >= minConfidence ? $0.point : nil }
        var width: Float = 0
        if let left, let right { width = (left - right).length }

        if let neck, neck.confidence >= minConfidence {
            return PlayerSighting(anchor: neck.point, shoulderWidth: width)
        }
        if let left, let right {
            return PlayerSighting(anchor: (left + right) * 0.5, shoulderWidth: width)
        }
        return nil
    }
}
