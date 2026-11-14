import Core
import SwiftUI

/// Phase 0 step 0c screen: the rear camera full screen with a frame-rate readout,
/// used to measure the ">= 55 fps for 5 min" criterion of PLAN.md §17.
struct RootView: View {
    @StateObject private var fps = FpsMeter()

    var body: some View {
        ZStack(alignment: .topLeading) {
            ARCameraView()
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.0f fps", fps.fps))
                Text(String(format: "min %.0f", fps.minFps))
                Text(String(format: "%.0f s", fps.elapsedS))
                // Proves the Core package is linked into the app.
                Text(String(format: "core %.0f", Vec3(3, 4, 0).length))
            }
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(8)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            .padding(8)
        }
        .statusBarHidden(true)
        .onAppear { fps.start() }
        .onDisappear { fps.stop() }
    }
}
