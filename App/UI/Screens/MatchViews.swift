import SwiftUI

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
