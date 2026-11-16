import Core
import SwiftUI

/// The one root of docs/GUI.md §6: camera (while a match runs), the persistent sky layer,
/// then the content of the current screen. No `NavigationStack`.
struct RootView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()

            if model.cameraActive {
                GeometryReader { geo in
                    ARCameraView(
                        onThreeFingerTap: { model.showLog.toggle() },
                        onFirstFrame: { model.cameraFrameArrived() },
                        pipeline: model.gun.pipeline)
                        .onAppear {
                            model.gun.pipeline.setViewAspect(Float(geo.size.width / max(1, geo.size.height)))
                        }
                }
                .ignoresSafeArea()
            }

            SkyLayer(model: model)

            content
                .opacity(model.contentOpacity)
                .offset(y: model.contentOffset)
                .allowsHitTesting(!model.inTransition)

            if model.showLog {
                LogOverlay().allowsHitTesting(false)
            }
            if model.debugOverlay {
                DebugReadout(fps: model.fps, dev: model.dev)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .statusBarHidden(true)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .preferredColorScheme(.dark)
        .onAppear { Log.event("app_started") }
    }

    @ViewBuilder private var content: some View {
        switch model.screen {
        case .launch: LaunchView(model: model)
        case .menu: MenuView(model: model)
        case .settings: SettingsScreen(model: model, dev: model.dev)
        case .practiceBriefing: PracticeBriefingView(model: model)
        case .countdown: CountdownView(model: model)
        case .match: MatchView(model: model, gun: model.gun)
        case .pause: PauseView(model: model)
        case .results, .lobby, .sync, .dead: EmptyView()   // pass 2 and Phase 3
        }
    }
}

/// Frame rate (for the ">= 55 fps" criteria), tuning revision and dev-server state.
/// Shown while the Debug readout setting is on.
private struct DebugReadout: View {
    @ObservedObject var fps: FpsMeter
    @ObservedObject var dev: DevServerClient

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(String(format: "%.0f fps  min %.0f  %.0f s", fps.fps, fps.minFps, fps.elapsedS))
            Text("tune r\(dev.tuning.revision)  dev \(dev.status)")
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(6)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// The newest 30 log lines, refreshed twice a second. Toggled by a three-finger tap on
/// the camera view (PLAN.md §1B.6).
private struct LogOverlay: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            VStack(alignment: .leading, spacing: 1) {
                Spacer()
                ForEach(Log.shared.tail(30), id: \.seq) { line in
                    Text(Self.text(line))
                        .lineLimit(1)
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .padding(.bottom, 44)
            .background(.black.opacity(0.45))
        }
    }

    private static func text(_ line: LogLine) -> String {
        var parts = [String(format: "%.2f", line.t), line.e]
        for key in line.f.keys.sorted() {
            parts.append("\(key)=\(String(format: "%.3g", line.f[key] ?? 0))")
        }
        if let message = line.m { parts.append(message) }
        return parts.joined(separator: " ")
    }
}
