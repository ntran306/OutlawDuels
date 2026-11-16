import SwiftUI

/// Match HUD (GUI.md §5) over the camera. Pass 1 draws fixed values: HP 72, 4 of 6 rounds,
/// player colour 0.
struct MatchView: View {
    @ObservedObject var model: AppModel
    @State private var drawOpacity = 0.0
    @State private var drawScale = 1.2

    private let hp = 72.0
    private let rounds = 4
    private let magazine = 6
    private let colorIndex = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Reticle: white dot 6 pt with a 1.5 pt night ring.
                Circle()
                    .fill(Theme.hudWhite)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(Theme.night.opacity(0.55), lineWidth: 1.5)
                            .frame(width: 9, height: 9))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                if !model.useCount {
                    Text("FIRE WHEN READY")
                        .font(Theme.caption)
                        .tracking(13 * 0.20)
                        .foregroundStyle(Theme.hudWhite)
                        .hudShadow()
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.16)
                }

                Text("DRAW")
                    .font(Theme.countdownDraw)
                    .foregroundStyle(Theme.cream)
                    .outlined()
                    .scaleEffect(drawScale)
                    .opacity(drawOpacity)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
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
                ForEach(0..<magazine, id: \.self) { index in
                    if index < rounds {
                        Circle().fill(Theme.hudWhite).frame(width: 9, height: 9)
                    } else {
                        Circle().strokeBorder(Theme.hudWhite, lineWidth: 1.5).frame(width: 9, height: 9)
                    }
                }
            }
            .padding(.leading, 20)
        }
        .hudShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Health \(Int(hp)), rounds \(rounds)")
    }
}

/// "3", "2", "1" at 0 / 800 / 1600 ms; weapons live and "DRAW" at 2400 ms (GUI.md §6).
struct CountdownView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var digit = ""
    @State private var scale = 1.4
    @State private var opacity = 0.0

    var body: some View {
        Text(digit)
            .font(Theme.countdown)
            .foregroundStyle(Theme.cream)
            .outlined()
            .scaleEffect(scale)
            .opacity(opacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task { await run() }
    }

    private func run() async {
        for text in ["3", "2", "1"] {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                digit = text
                scale = reduceMotion ? 1.0 : 1.4
                opacity = 0
            }
            model.audio.play(.countTick)
            try? await Task.sleep(nanoseconds: 20_000_000)
            withAnimation(.easeOut(duration: 0.18)) {
                scale = 1.0
                opacity = 1
            }
            try? await Task.sleep(nanoseconds: 630_000_000)
            withAnimation(.linear(duration: 0.15)) { opacity = 0 }
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
        }
        model.audio.play(.countDraw)
        model.send(.countdownFinished)
    }
}

/// Pause (GUI.md §4): a night 70 % scrim over the camera. Settings from here is pass 2.
struct PauseView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            Theme.night.opacity(0.70).ignoresSafeArea()
            VStack(spacing: Theme.s3) {
                Spacer()
                Text("PAUSED")
                    .font(Theme.title)
                    .tracking(28 * 0.02)
                    .foregroundStyle(Theme.cream)
                    .padding(.bottom, Theme.s6)
                Button("RESUME") { model.send(.tapResume) }
                    .buttonStyle(ThemeButtonStyle(kind: .primary))
                Button("LEAVE") { model.send(.tapLeave) }
                    .buttonStyle(ThemeButtonStyle(kind: .tertiary(Theme.danger)))
                Spacer().frame(height: 96)
            }
            .padding(.horizontal, Theme.sideMargin)
        }
    }
}

extension View {
    /// The one shadow every HUD item gets for legibility on any room (GUI.md §5).
    func hudShadow() -> some View {
        shadow(color: Theme.night.opacity(0.7), radius: 1.5, x: 0, y: 1)
    }

    /// A 2 pt hard outline in night, drawn as four offset copies.
    func outlined() -> some View {
        self
            .shadow(color: Theme.night, radius: 0, x: 2, y: 2)
            .shadow(color: Theme.night, radius: 0, x: -2, y: -2)
            .shadow(color: Theme.night, radius: 0, x: 2, y: -2)
            .shadow(color: Theme.night, radius: 0, x: -2, y: 2)
    }
}
