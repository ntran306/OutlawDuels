import ARKit
import RealityKit
import SwiftUI

/// The rear camera through RealityKit's `ARView`, with world tracking and
/// gravity-aligned axes (PLAN.md §5: +Y up on every phone). A three-finger tap
/// anywhere on it calls `onThreeFingerTap` (§1B.6: toggles the log overlay).
struct ARCameraView: UIViewRepresentable {
    var onThreeFingerTap: () -> Void = {}

    @MainActor
    final class Coordinator: NSObject {
        var onThreeFingerTap: () -> Void

        init(onThreeFingerTap: @escaping () -> Void) {
            self.onThreeFingerTap = onThreeFingerTap
        }

        @objc func handleThreeFingerTap(_ sender: UITapGestureRecognizer) {
            if sender.state == .ended { onThreeFingerTap() }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onThreeFingerTap: onThreeFingerTap)
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
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.onThreeFingerTap = onThreeFingerTap
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }
}
