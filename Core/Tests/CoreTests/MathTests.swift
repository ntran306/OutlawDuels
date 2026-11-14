import Testing
@testable import Core

@Suite struct Vec3Tests {
    @Test func arithmetic() {
        let a = Vec3(1, 2, 3)
        let b = Vec3(4, -5, 6)
        #expect(a + b == Vec3(5, -3, 9))
        #expect(a - b == Vec3(-3, 7, -3))
        #expect(a * 2 == Vec3(2, 4, 6))
        #expect(2 * a == a * 2)
        #expect(a / 2 == Vec3(0.5, 1, 1.5))
        #expect(-a == Vec3(-1, -2, -3))
        #expect(a.dot(b) == 12)
    }

    @Test func crossIsRightHanded() {
        #expect(Vec3(1, 0, 0).cross(Vec3(0, 1, 0)) == Vec3(0, 0, 1))
        #expect(Vec3(0, 1, 0).cross(Vec3(0, 0, 1)) == Vec3(1, 0, 0))
    }

    @Test func lengthAndNormalized() {
        #expect(Vec3(3, 4, 0).length == 5)
        #expect(abs(Vec3(3, 4, 12).normalized.length - 1) < 1e-6)
        #expect(Vec3.zero.normalized == .zero)
    }

    /// PLAN.md §5: yaw(RotY(t) * (0, 0, -1)) = t.
    @Test(arguments: [-3.0, -1.5707964, -0.5, 0.0, 0.25, 1.0, 1.5707964, 3.0] as [Float])
    func yawRoundTrip(t: Float) {
        let forward = Vec3(0, 0, -1)
        #expect(abs(forward.rotatedY(t).yaw - t) < 1e-5)
    }

    /// PLAN.md §5: RotY is counter-clockwise seen from above, so a quarter turn
    /// takes "forward" (-Z) to "left" (-X).
    @Test func rotYQuarterTurnTurnsForwardToLeft() {
        let r = Vec3(0, 0, -1).rotatedY(.pi / 2)
        #expect(abs(r.x - -1) < 1e-6)
        #expect(abs(r.y) < 1e-6)
        #expect(abs(r.z) < 1e-6)
    }
}
