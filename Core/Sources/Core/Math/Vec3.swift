import Foundation

/// A 3D vector in metres unless a field name says otherwise (PLAN.md §5, §12).
/// Axes follow ARKit: right-handed, +X right, +Y up, a camera looks along -Z.
public struct Vec3: Sendable, Equatable {
    public var x: Float
    public var y: Float
    public var z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    public init(_ x: Float, _ y: Float, _ z: Float) {
        self.init(x: x, y: y, z: z)
    }

    public static let zero = Vec3(0, 0, 0)

    public static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    public static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    public static prefix func - (a: Vec3) -> Vec3 { Vec3(-a.x, -a.y, -a.z) }
    public static func * (a: Vec3, s: Float) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }
    public static func * (s: Float, a: Vec3) -> Vec3 { a * s }
    public static func / (a: Vec3, s: Float) -> Vec3 { Vec3(a.x / s, a.y / s, a.z / s) }

    public func dot(_ o: Vec3) -> Float { x * o.x + y * o.y + z * o.z }

    /// Right-handed cross product: (1,0,0) x (0,1,0) = (0,0,1).
    public func cross(_ o: Vec3) -> Vec3 {
        Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x)
    }

    public var lengthSquared: Float { dot(self) }
    public var length: Float { lengthSquared.squareRoot() }

    /// Unit vector in the same direction, or `.zero` when the length is below 1e-8 m.
    public var normalized: Vec3 {
        let len = length
        return len < 1e-8 ? .zero : self / len
    }

    /// `RotY(t) * self`: counter-clockwise rotation about +Y seen from above (§5).
    /// `x' = x cos t + z sin t`, `z' = -x sin t + z cos t`.
    public func rotatedY(_ yawRad: Float) -> Vec3 {
        let c = Float(cos(Double(yawRad)))
        let s = Float(sin(Double(yawRad)))
        return Vec3(x * c + z * s, y, -x * s + z * c)
    }

    /// Yaw of this vector's horizontal direction: `atan2(-x, -z)` (§5), so
    /// `Vec3(0, 0, -1).rotatedY(t).yaw == t` for t in (-pi, pi].
    public var yaw: Float { Float(atan2(Double(-x), Double(-z))) }
}
