import SwiftUI

/// Launch screen (GUI.md §4, §6): the wordmark and caption over the rising sun. The sun and
/// skyline themselves live in `SkyLayer`. A tap skips to the menu.
struct LaunchView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Tracking 0.40 em -> 0.04 em of the 44 pt wordmark.
            let spacing = Theme.wordmarkSize * (model.wordmarkShown ? 0.04 : 0.40)
            ZStack {
                Color.clear
                VStack(spacing: -8) {
                    SpacedWord(text: "OUTLAW", spacing: spacing)
                    SpacedWord(text: "DUELS", spacing: spacing)
                }
                .foregroundStyle(Theme.cream)
                .shadow(color: Theme.night.opacity(0.35), radius: 0, x: 0, y: 2)
                .opacity(model.wordmarkShown ? 1 : 0)
                .offset(y: model.wordmarkShown ? 0 : 14)
                .position(x: w / 2, y: h * 0.60)

                Text("DRAW AT HIGH NOON")
                    .font(Theme.caption)
                    .tracking(13 * 0.20)
                    .foregroundStyle(Theme.night)
                    .opacity(model.captionShown ? 1 : 0)
                    .position(x: w / 2, y: h * 0.74)
            }
            .frame(width: w, height: h)
            .contentShape(Rectangle())
            .onTapGesture { model.skipLaunch() }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Outlaw Duels")
        .onAppear { model.startLaunch() }
    }
}

/// A word laid out letter by letter so its letter spacing can animate smoothly
/// (`Text.tracking` does not interpolate).
struct SpacedWord: View {
    let text: String
    let spacing: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
            }
        }
        .font(Theme.wordmark)
        .fixedSize()
    }
}
