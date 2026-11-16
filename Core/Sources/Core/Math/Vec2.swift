import Foundation

/// A 2D vector. In viewport use: units 0...1 of the screen, origin bottom-left (PLAN.md §12).
public struct Vec2: Sendable, Equatable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    public init(_ x: Float, _ y: Float) {
        self.init(x: x, y: y)
    }

    public static let zero = Vec2(0, 0)

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (a: Vec2, s: Float) -> Vec2 { Vec2(a.x * s, a.y * s) }

    public var length: Float { (x * x + y * y).squareRoot() }
}

/// Unit quaternion, (x, y, z) imaginary and w real.
public struct Quat: Sendable, Equatable {
    public var x: Float
    public var y: Float
    public var z: Float
    public var w: Float

    public init(x: Float, y: Float, z: Float, w: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    public static let identity = Quat(x: 0, y: 0, z: 0, w: 1)
}

/// Position in metres and rotation, ARKit axes (PLAN.md §5).
public struct Pose: Sendable, Equatable {
    public var position: Vec3
    public var rotation: Quat

    public init(position: Vec3, rotation: Quat) {
        self.position = position
        self.rotation = rotation
    }

    public static let identity = Pose(position: .zero, rotation: .identity)
}
