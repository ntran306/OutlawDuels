import Core
import SwiftUI

/// Phase 0 screen: the rear camera full screen, a readout top left (frame rate for the
/// ">= 55 fps for 5 min" criterion of PLAN.md §17, tuning revision and dev-server state),
/// the menu top right (§1A.5), and the log overlay toggled by a three-finger tap (§1B.6).
struct RootView: View {
    @StateObject private var fps = FpsMeter()
    @StateObject private var dev = DevServerClient()
    @State private var showLog = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            ARCameraView(onThreeFingerTap: { showLog.toggle() })
                .ignoresSafeArea()

            if showLog {
                LogOverlay()
                    .allowsHitTesting(false)
            }

            VStack {
                HStack(alignment: .top) {
                    readout
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .accessibilityLabel("Menu")
                }
                Spacer()
            }
            .padding(8)
        }
        .statusBarHidden(true)
        .sheet(isPresented: $showSettings) {
            SettingsView(dev: dev)
        }
        .onAppear {
            fps.start()
            Log.event("app_started")
        }
        .onDisappear { fps.stop() }
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "%.0f fps", fps.fps))
            Text(String(format: "min %.0f", fps.minFps))
            Text(String(format: "%.0f s", fps.elapsedS))
            Text("tune r\(dev.tuning.revision)")
            Text("dev \(dev.status)")
        }
        .font(.system(size: 14, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// The newest 30 log lines, refreshed twice a second.
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
