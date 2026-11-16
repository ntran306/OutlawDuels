import Core
import SwiftUI

/// Match HUD (GUI.md §5) over the camera, driven by the finger gun: the reticle follows
/// the smoothed fingertip, the pips are the magazine, and every person the camera sees
/// gets a colour marker. HP is still a fixed 72 until damage exists.
struct MatchView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var gun: FingerGunModel
    @State private var drawOpacity = 0.0
    @State private var drawScale = 1.2
    @State private var flashScale = 2.2
    @State private var flashOpacity = 0.0

    private let hp = 72.0
    private let colorIndex = 0
    /// Until multiplayer assigns colours, everyone seen is drawn in colour 1 (orange).
    private let otherColorIndex = 1

    var body: some View {
        ZStack {
            trackingLayer
            if !model.useCount {
                GeometryReader { geo in
                    Text("FIRE WHEN READY")
                        .font(Theme.caption)
                        .tracking(13 * 0.20)
                        .foregroundStyle(Theme.hudWhite)
                        .hudShadow()
                        .opacity(gun.shotCount == 0 ? 1 : 0)
                        .animation(.easeOut(duration: 0.15), value: gun.shotCount == 0)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.16)
                }
                .allowsHitTesting(false)
            }
            Text("DRAW")
                .font(Theme.countdownDraw)
                .foregroundStyle(Theme.cream)
                .outlined()
                .scaleEffect(drawScale)
                .opacity(drawOpacity)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            status.padding(.leading, 12).padding(.top, 12)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                model.send(.tapPause)
            } label: {
                VStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(Theme.hudWhite).frame(width: 20, height: 2.5)
                    }
                }
                .hudShadow()
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Menu")
            .padding(8)
        }
        .overlay(alignment: .bottomTrailing) {
            // Self view placeholder until F5 decides its drawing (GUI.md §12 #4).
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.night.opacity(0.45))
                .frame(width: 90, height: 120)
                .padding(12)
                .accessibilityHidden(true)
        }
        .onAppear {
            guard model.previousScreen == .countdown else { return }
            drawOpacity = 1
            withAnimation(.easeOut(duration: 0.12)) { drawScale = 1.0 }
            withAnimation(.easeIn(duration: 0.30).delay(0.12)) { drawOpacity = 0 }
        }
        .onChange(of: gun.shotCount) { _, _ in
            Task {
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) {
                    flashScale = 0.6
                    flashOpacity = 1
                }
                try? await Task.sleep(nanoseconds: 16_000_000)
                withAnimation(.easeOut(duration: 0.18)) {
                    flashScale = 2.2
                    flashOpacity = 0
                }
            }
        }
    }

    /// Everything placed in camera-picture coordinates: full screen, origin bottom-left.
    private var trackingLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let aim = gun.aim ?? Vec2(0.5, 0.5)
            let ring = 26 - 14 * CGFloat(gun.triggerTravel)
            ZStack {
                // People: a disc in the player colour above each neck (PLAN.md §1B.8).
                ForEach(Array(gun.sightings.enumerated()), id: \.offset) { _, sighting in
                    PlayerMarker(sighting: sighting, color: Theme.playerColors[otherColorIndex], width: w, height: h)
                }

                // Hand landmarks, only with the debug readout on.
                if model.debugOverlay, !gun.hand.isEmpty {
                    HandDots(points: gun.hand)
                        .fill(Theme.hudWhite.opacity(0.7))
                }

                // Shot flash where the shot was aimed.
                Circle()
                    .stroke(Theme.sun, lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .scaleEffect(flashScale)
                    .opacity(flashOpacity)
                    .position(x: CGFloat(gun.lastShotAim.x) * w, y: (1 - CGFloat(gun.lastShotAim.y)) * h)

                // Reticle at the smoothed fingertip; the sun ring closes as the thumb drops.
                ZStack {
                    Circle()
                        .stroke(Theme.sun, lineWidth: 1.5)
                        .frame(width: ring, height: ring)
                        .opacity(gun.gunState == .cocked ? 1 : 0)
                    Circle()
                        .stroke(Theme.night.opacity(0.55), lineWidth: 1.5)
                        .frame(width: 9, height: 9)
                    Circle()
                        .fill(Theme.hudWhite)
                        .frame(width: 6, height: 6)
                }
                .opacity(gun.aim == nil ? 0.35 : 1)
                .position(x: CGFloat(aim.x) * w, y: (1 - CGFloat(aim.y)) * h)
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.playerColors[colorIndex])
                    .frame(width: 12, height: 12)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hudWhite.opacity(0.35)).frame(width: 120, height: 6)
                    Capsule().fill(hp <= 25 ? Theme.danger : Theme.sun).frame(width: 120 * hp / 100, height: 6)
                }
                Text("\(Int(hp))")
                    .font(Theme.hudNumber)
                    .foregroundStyle(Theme.hudWhite)
            }
            HStack(spacing: 5) {
                ForEach(0..<gun.magazineSize, id: \.self) { index in
                    if index < gun.rounds {
                        Circle().fill(Theme.hudWhite).frame(width: 9, height: 9)
                    } else {
                        Circle().strokeBorder(Theme.hudWhite, lineWidth: 1.5).frame(width: 9, height: 9)
                    }
                }
            }
            .padding(.leading, 20)

            if model.debugOverlay {
                VStack(alignment: .leading, spacing: 1) {
                    Text(trackingLine)
                    Text(measuresLine)
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.hudWhite)
            }
        }
        .hudShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Health \(Int(hp)), rounds \(gun.rounds)")
    }

    private var trackingLine: String {
        let state: String
        switch gun.gunState {
        case .none: state = "none"
        case .cocked: state = "cocked"
        case .fired: state = "fired"
        }
        return "hand \(Int(gun.handRateHz.rounded())) Hz  \(state)  people \(gun.sightings.count)"
    }

    private var measuresLine: String {
        guard let m = gun.measures else { return "no hand" }
        return String(format: "trig %.2f  str %.2f  curl %.2f", m.trigger, m.straight, m.curl)
    }
}

/// A disc in the player's colour above a person's neck. Sizes follow the shoulder width
/// on screen, within 16–44 pt.
private struct PlayerMarker: View {
    let sighting: PlayerSighting
    let color: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let shoulders = CGFloat(sighting.shoulderWidth) * width
        let size = min(44, max(16, shoulders * 0.5))
        let lift = max(34, shoulders * 0.9)
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .hudShadow()
            .position(x: CGFloat(sighting.anchor.x) * width, y: (1 - CGFloat(sighting.anchor.y)) * height - lift)
    }
}

/// The 21 hand landmarks as 4 pt dots; `points` are viewport units, origin bottom-left.
private struct HandDots: Shape {
    let points: [Vec2]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for point in points {
            path.addEllipse(in: CGRect(
                x: rect.minX + CGFloat(point.x) * rect.width - 2,
                y: rect.minY + (1 - CGFloat(point.y)) * rect.height - 2,
                width: 4, height: 4))
        }
        return path
    }
}
