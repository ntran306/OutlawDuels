import SwiftUI

/// Practice Range briefing (GUI.md §4): three steps, the count toggle, Start.
struct PracticeBriefingView: View {
    @ObservedObject var model: AppModel

    private let steps = [
        "Point your finger gun at a target, thumb up.",
        "Drop your thumb to fire.",
        "Take your hand out of view to reload.",
    ]

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let top = max(geo.safeAreaInsets.top, 44)
            VStack(alignment: .leading, spacing: 0) {
                // Back sits right of the sun, which is top left on this screen.
                HStack {
                    Spacer()
                    Button("BACK") { model.send(.tapBack) }
                        .buttonStyle(ThemeButtonStyle(kind: .tertiary(Theme.cream)))
                }
                .padding(.top, top)
                .reveal(model, 0)

                Text("PRACTICE RANGE")
                    .font(Theme.title)
                    .tracking(28 * 0.02)
                    .foregroundStyle(Theme.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, max(Theme.s4, h * 0.22 - top - 44))
                    .reveal(model, 1)

                VStack(alignment: .leading, spacing: Theme.s3) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.s3) {
                            Text("\(index + 1)")
                                .font(Theme.title)
                                .foregroundStyle(Theme.cream)
                            Text(text)
                                .font(Theme.body)
                                .foregroundStyle(Theme.cream)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .reveal(model, 2 + index)
                    }
                }
                .padding(.top, Theme.s6)

                Spacer(minLength: Theme.s4)

                Toggle(isOn: $model.practiceCount) {
                    Text("3-2-1 COUNT")
                        .font(Theme.button)
                        .tracking(20 * 0.12)
                        .foregroundStyle(Theme.cream)
                }
                .tint(Theme.sun)
                .padding(.horizontal, Theme.s4)
                .frame(minHeight: 56)
                .background(Theme.night.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                .reveal(model, 5)

                Button("START") { model.send(.tapStart) }
                    .buttonStyle(ThemeButtonStyle(kind: .primary))
                    .padding(.top, Theme.s3)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 24) + 24)
                    .reveal(model, 6)
            }
            .padding(.horizontal, Theme.sideMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea()
    }
}
