import ARKit
import RealityKit
import SwiftUI

/// The rear camera through RealityKit's `ARView`, with world tracking and
/// gravity-aligned axes (PLAN.md §5: +Y up on every phone).
struct ARCameraView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        view.session.run(config)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}
