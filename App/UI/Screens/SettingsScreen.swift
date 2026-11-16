import SwiftUI

/// Settings (GUI.md §4). Pass 1 holds the debug toggle and the dev-server rows of
/// PLAN.md §1B.6; volume, haptics and marker-shape rows arrive in pass 2.
struct SettingsScreen: View {
    @ObservedObject var model: AppModel
    @ObservedObject var dev: DevServerClient
    @State private var draft = ""
    @FocusState private var addressFocused: Bool

    var body: some View {
        GeometryReader { geo in
            let top = max(geo.safeAreaInsets.top, 44)
            VStack(alignment: .leading, spacing: Theme.s3) {
                Button("BACK") {
                    addressFocused = false
                    model.send(.tapBack)
                }
                .buttonStyle(ThemeButtonStyle(kind: .tertiary(Theme.cream)))
                .padding(.leading, -Theme.s4)
                .reveal(model, 0)

                Text("SETTINGS")
                    .font(Theme.title)
                    .tracking(28 * 0.02)
                    .foregroundStyle(Theme.cream)
                    .padding(.bottom, Theme.s2)
                    .reveal(model, 1)

                row {
                    Toggle(isOn: $model.debugOverlay) { label("DEBUG READOUT") }
                        .tint(Theme.sun)
                }
                .reveal(model, 2)

                row {
                    VStack(alignment: .leading, spacing: Theme.s1) {
                        label("DEV SERVER")
                        HStack(spacing: Theme.s2) {
                            TextField("http://192.168.1.20:8765", text: $draft)
                                .font(Theme.body)
                                .foregroundStyle(Theme.cream)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .focused($addressFocused)
                                .onSubmit { dev.setAddress(draft) }
                            Button("SAVE") {
                                addressFocused = false
                                dev.setAddress(draft)
                            }
                            .font(Theme.button)
                            .foregroundStyle(Theme.sun)
                            .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                    .padding(.vertical, Theme.s2)
                }
                .reveal(model, 3)

                row {
                    HStack {
                        label("STATUS")
                        Spacer()
                        Text(dev.status).font(Theme.body).foregroundStyle(Theme.cream)
                    }
                }
                .reveal(model, 4)

                row {
                    HStack {
                        label("TUNING REVISION")
                        Spacer()
                        Text("\(dev.tuning.revision)").font(Theme.body).foregroundStyle(Theme.cream)
                    }
                }
                .reveal(model, 5)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.sideMargin)
            .padding(.top, top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea(.container)
        .onAppear { draft = dev.address }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption)
            .tracking(13 * 0.20)
            .foregroundStyle(Theme.cream)
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, Theme.s4)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(Theme.night.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
}
