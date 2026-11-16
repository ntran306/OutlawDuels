import ARKit
import RealityKit
import SwiftUI

/// The rear camera through RealityKit's `ARView`, with world tracking and
/// gravity-aligned axes (PLAN.md §5: +Y up on every phone). A three-finger tap
/// anywhere on it calls `onThreeFingerTap` (§1B.6: toggles the log overlay).
/// `onFirstFrame` is called once, when the session has delivered its first frame.
struct ARCameraView: UIViewRepresentable {
    var onThreeFingerTap: () -> Void = {}
    var onFirstFrame: () -> Void = {}

    @MainActor
    final class Coordinator: NSObject {
        var onThreeFingerTap: () -> Void
        var onFirstFrame: () -> Void
        private var pollTask: Task<Void, Never>?

        init(onThreeFingerTap: @escaping () -> Void, onFirstFrame: @escaping () -> Void) {
            self.onThreeFingerTap = onThreeFingerTap
            self.onFirstFrame = onFirstFrame
        }

        @objc func handleThreeFingerTap(_ sender: UITapGestureRecognizer) {
            if sender.state == .ended { onThreeFingerTap() }
        }

        /// Checks every 50 ms for the first camera frame; no session delegate needed.
        func watchForFirstFrame(_ view: ARView) {
            pollTask?.cancel()
            pollTask = Task { [weak self, weak view] in
                while !Task.isCancelled {
                    guard let view else { return }
                    if view.session.currentFrame != nil {
                        self?.onFirstFrame()
                        return
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
        }

        func stop() {
            pollTask?.cancel()
            pollTask = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onThreeFingerTap: onThreeFingerTap, onFirstFrame: onFirstFrame)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        view.session.run(config)

        let tap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleThreeFingerTap(_:)))
        tap.numberOfTouchesRequired = 3
        view.addGestureRecognizer(tap)
        context.coordinator.watchForFirstFrame(view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.onThreeFingerTap = onThreeFingerTap
        context.coordinator.onFirstFrame = onFirstFrame
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.stop()
        uiView.session.pause()
    }
}
