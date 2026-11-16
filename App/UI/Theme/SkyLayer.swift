import SwiftUI

/// Sunset gradient of GUI.md §2: plum 0.00, ember 0.58, sun 1.00, top to bottom.
struct SkyBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Theme.plum, location: 0.00),
                .init(color: Theme.ember, location: 0.58),
                .init(color: Theme.sun, location: 1.00),
            ],
            startPoint: .top, endPoint: .bottom)
    }
}

/// The sun, drawn at a fixed 200 pt and scaled by its parent so the gradient scales with it.
/// The finger gun sits on it at 56 % of the diameter (logo use only).
struct SunDisc: View {
    static let baseDiameter: CGFloat = 200
    var gunOpacity: Double

    var body: some View {
        ZStack {
            Circle().fill(
                RadialGradient(
                    colors: [Theme.sunCore, Theme.sun], center: .center,
                    startRadius: 0, endRadius: Self.baseDiameter / 2 * 0.7))
            FingerGunShape()
                .fill(Theme.night)
                .frame(width: Self.baseDiameter * 0.56, height: Self.baseDiameter * 0.56 * 44 / 64)
                .opacity(gunOpacity)
        }
        .frame(width: Self.baseDiameter, height: Self.baseDiameter)
    }
}

/// Finger-gun silhouette in a 64 x 44 box, pointing right (GUI.md §3).
struct FingerGunShape: Shape {
    func path(in rect: CGRect) -> Path {
        func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
            Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
        }
        func rotated(_ p: Path, degrees: CGFloat, about c: CGPoint) -> Path {
            let t = CGAffineTransform(translationX: c.x, y: c.y)
                .rotated(by: degrees * .pi / 180)
                .translatedBy(x: -c.x, y: -c.y)
            return p.applying(t)
        }

        var path = Path()
        path.addPath(rr(24, 12, 39, 9, 4.5))                                              // index finger
        path.addPath(rotated(rr(13, 1, 9, 20, 4.5), degrees: -12, about: CGPoint(x: 17, y: 20)))  // thumb
        path.addPath(rr(6, 12, 27, 27, 7))                                                // palm
        path.addPath(rr(27, 20, 14, 7, 3))                                                // curled fingers
        path.addPath(rr(27, 26.5, 12, 7, 3))
        path.addPath(rr(27, 33, 9, 6, 3))
        path.addPath(rotated(rr(0, 23, 12, 19, 3), degrees: 8, about: CGPoint(x: 6, y: 32.5)))    // wrist

        let scale = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / 64, y: rect.height / 44)
        return path.applying(scale)
    }
}

/// Town-and-cactus silhouette in a 210 x 90 box, stretched to the given rect (GUI.md §3).
struct SkylineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // M0 90 V62 H70 V46 H112 V58 H150 L158 50 H186 V64 H210 V90 Z
        path.move(to: CGPoint(x: 0, y: 90))
        path.addLine(to: CGPoint(x: 0, y: 62))
        path.addLine(to: CGPoint(x: 70, y: 62))
        path.addLine(to: CGPoint(x: 70, y: 46))
        path.addLine(to: CGPoint(x: 112, y: 46))
        path.addLine(to: CGPoint(x: 112, y: 58))
        path.addLine(to: CGPoint(x: 150, y: 58))
        path.addLine(to: CGPoint(x: 158, y: 50))
        path.addLine(to: CGPoint(x: 186, y: 50))
        path.addLine(to: CGPoint(x: 186, y: 64))
        path.addLine(to: CGPoint(x: 210, y: 64))
        path.addLine(to: CGPoint(x: 210, y: 90))
        path.closeSubpath()

        // Cactus on the left ledge.
        path.addPath(Path(roundedRect: CGRect(x: 26, y: 19, width: 10, height: 46), cornerRadius: 5))      // trunk
        path.addPath(Path(roundedRect: CGRect(x: 34, y: 46, width: 17, height: 7), cornerRadius: 3.5))     // right arm, out
        path.addPath(Path(roundedRect: CGRect(x: 44, y: 31.5, width: 7, height: 21.5), cornerRadius: 3.5)) // right arm, up
        path.addPath(Path(roundedRect: CGRect(x: 11, y: 52, width: 17, height: 7), cornerRadius: 3.5))     // left arm, out
        path.addPath(Path(roundedRect: CGRect(x: 11, y: 35.5, width: 7, height: 23.5), cornerRadius: 3.5)) // left arm, up

        let scale = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / 210, y: rect.height / 90)
        return path.applying(scale)
    }
}

/// Sky, sun and skyline: one instance under every menu screen. Only the sun's pose, the
/// skyline's offset and the layer's opacity change (GUI.md §6).
struct SkyLayer: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let skylineH = h * 0.21
            let sunY = model.sunSet ? 1.10 : CGFloat(model.sun.y) + model.launchRise
            ZStack {
                SkyBackground()
                SunDisc(gunOpacity: model.gunOpacity)
                    .scaleEffect(CGFloat(model.sun.diameterPt) / SunDisc.baseDiameter)
                    .position(x: CGFloat(model.sun.x) * w, y: sunY * h)
                SkylineShape()
                    .fill(Theme.night)
                    .frame(width: w, height: skylineH)
                    .position(x: w / 2, y: h - skylineH / 2)
                    .offset(y: model.skylineRisePt + (model.sunSet ? skylineH : 0))
                    .opacity(model.skylineOpacity)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .ignoresSafeArea()
        .opacity(model.skyOpacity)
        .allowsHitTesting(false)
    }
}
