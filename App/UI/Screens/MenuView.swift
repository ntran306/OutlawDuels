import SwiftUI

/// Main menu (GUI.md §4): title at y 0.24, buttons from y 0.36, version at the bottom.
struct MenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            VStack(spacing: 0) {
                Text("OUTLAW DUELS")
                    .font(Theme.title)
                    .tracking(28 * 0.02)
                    .foregroundStyle(Theme.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: 40)
                    .padding(.top, h * 0.24 - 20)
                    .reveal(model, 0)

                VStack(spacing: Theme.s3) {
                    Button("PRACTICE RANGE") { model.send(.tapPractice) }
                        .buttonStyle(ThemeButtonStyle(kind: .primary))
                        .reveal(model, 1)
                    // Host and Join arrive with multiplayer in Phase 3.
                    Button("HOST A DUEL") {}
                        .buttonStyle(ThemeButtonStyle(kind: .secondary))
                        .opacity(0.4)
                        .allowsHitTesting(false)
                        .accessibilityHint("Not available yet")
                        .reveal(model, 2)
                    Button("JOIN A DUEL") {}
                        .buttonStyle(ThemeButtonStyle(kind: .secondary))
                        .opacity(0.4)
                        .allowsHitTesting(false)
                        .accessibilityHint("Not available yet")
                        .reveal(model, 3)
                    // Below y 0.45, so text on the sky is night (GUI.md §9).
                    Button("SETTINGS") { model.send(.tapSettings) }
                        .buttonStyle(ThemeButtonStyle(kind: .tertiary(Theme.night)))
                        .reveal(model, 4)
                }
                .padding(.horizontal, Theme.sideMargin)
                .padding(.top, h * 0.36 - (h * 0.24 + 20))

                Spacer(minLength: 0)

                Text(Self.versionText)
                    .font(Theme.caption)
                    .tracking(13 * 0.20)
                    .foregroundStyle(Theme.cream)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 24) + 8)
                    .reveal(model, 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "V\(version) (BUILD \(build))"
    }
}
