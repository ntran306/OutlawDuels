import ARKit
import Core
import Vision
import simd

/// Converts ARKit and simd types to `Core` types at the boundary (PLAN.md §3.1).
enum CoreBridging {
    static func pose(_ m: simd_float4x4) -> Pose {
        let q = simd_quatf(m)
        let p = m.columns.3
        return Pose(
            position: Vec3(p.x, p.y, p.z),
            rotation: Quat(x: q.imag.x, y: q.imag.y, z: q.imag.z, w: q.real))
    }
}

/// A camera frame's pixels, handed from the AR callback to a worker queue.
private struct PixelBufferBox: @unchecked Sendable {
    let buffer: CVPixelBuffer
}

/// Runs Apple Vision on the AR camera frames: one hand at 30 Hz (every 2nd frame) and
/// body poses at 10 Hz (PLAN.md §1B.5, §1B.7 `BODY_POSE_HZ`). A frame is skipped, never
/// queued, while the previous result of that detector has not returned.
///
/// It is the `ARSession` delegate; frames arrive on `delegateQueue`. Results are handed
/// to the two callbacks on worker queues, so the callbacks must hop to the main actor.
final class VisionPipeline: NSObject, ARSessionDelegate, @unchecked Sendable {
    typealias HandCallback = @Sendable (_ sample: HandPoseSample?, _ frameTimeSec: Double) -> Void
    typealias BodyCallback = @Sendable (_ sightings: [PlayerSighting], _ frameTimeSec: Double) -> Void

    let delegateQueue = DispatchQueue(label: "outlawduels.arframes", qos: .userInteractive)
    private let handQueue = DispatchQueue(label: "outlawduels.hand", qos: .userInitiated)
    private let bodyQueue = DispatchQueue(label: "outlawduels.body", qos: .utility)

    private static let bodyIntervalSec = 0.1          // BODY_POSE_HZ 10
    private static let jointMinConfidence: Float = 0.3   // BODY_JOINT_MIN_CONF, also for the hand's key joints

    /// Vision joints in MediaPipe landmark order 0...20.
    private static let handJoints: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip,
    ]
    /// Landmarks that must be confidently seen: wrist, the whole index finger, middle MCP.
    /// The curled fingers are hidden behind the hand, so their estimates are accepted as given.
    private static let requiredLandmarks = [0, 5, 6, 7, 8, 9]

    private let lock = NSLock()
    private var viewAspect: Float = 390.0 / 844.0
    private var frameIndex = 0
    private var handBusy = false
    private var bodyBusy = false
    private var lastBodyTime = 0.0
    private var onHand: HandCallback?
    private var onBodies: BodyCallback?

    // Each request is used only on its own serial queue.
    private let handRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()
    private let bodyRequest = VNDetectHumanBodyPoseRequest()

    func setHandlers(onHand: @escaping HandCallback, onBodies: @escaping BodyCallback) {
        lock.lock()
        self.onHand = onHand
        self.onBodies = onBodies
        lock.unlock()
    }

    /// Width / height of the screen the camera picture fills.
    func setViewAspect(_ aspect: Float) {
        guard aspect > 0 else { return }
        lock.lock()
        viewAspect = aspect
        lock.unlock()
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let time = frame.timestamp
        let pose = CoreBridging.pose(frame.camera.transform)
        let box = PixelBufferBox(buffer: frame.capturedImage)

        lock.lock()
        frameIndex += 1
        let aspect = viewAspect
        let runHand = frameIndex % 2 == 0 && !handBusy
        if runHand { handBusy = true }
        let runBody = !bodyBusy && time - lastBodyTime >= Self.bodyIntervalSec
        if runBody {
            bodyBusy = true
            lastBodyTime = time
        }
        let handCallback = onHand
        let bodyCallback = onBodies
        lock.unlock()

        if runHand {
            handQueue.async { [self] in
                let sample = detectHand(box.buffer, time: time, pose: pose, viewAspect: aspect)
                lock.lock()
                handBusy = false
                lock.unlock()
                handCallback?(sample, time)
            }
        }
        if runBody {
            bodyQueue.async { [self] in
                let sightings = detectBodies(box.buffer, viewAspect: aspect)
                lock.lock()
                bodyBusy = false
                lock.unlock()
                bodyCallback?(sightings, time)
            }
        }
    }

    /// Upright image width / height: the rear camera's buffer is landscape, shown in portrait.
    private func uprightAspect(_ buffer: CVPixelBuffer) -> Float {
        Float(CVPixelBufferGetHeight(buffer)) / Float(max(1, CVPixelBufferGetWidth(buffer)))
    }

    private func detectHand(_ buffer: CVPixelBuffer, time: Double, pose: Pose, viewAspect: Float) -> HandPoseSample? {
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right, options: [:])
        do {
            try handler.perform([handRequest])
        } catch {
            return nil
        }
        guard let observation = handRequest.results?.first,
              let points = try? observation.recognizedPoints(.all)
        else { return nil }

        let imageAspect = uprightAspect(buffer)
        var viewport: [Vec2] = []
        var world: [Vec3] = []
        var confidenceSum: Float = 0
        viewport.reserveCapacity(HandLandmark.count)
        world.reserveCapacity(HandLandmark.count)

        for (index, joint) in Self.handJoints.enumerated() {
            guard let point = points[joint] else { return nil }
            if Self.requiredLandmarks.contains(index), point.confidence < Self.jointMinConfidence { return nil }
            // Vision points are 0...1 of the upright image, origin bottom-left.
            let image = Vec2(Float(point.location.x), Float(point.location.y))
            let p = ViewportMapping.aspectFill(image, imageAspect: imageAspect, viewAspect: viewAspect)
            viewport.append(p)
            world.append(ViewportMapping.isotropic(p, viewAspect: viewAspect))
            confidenceSum += point.confidence
        }

        return HandPoseSample(
            captureTimeSec: time, worldFromCamera: pose, isRightHand: observation.chirality == .right,
            score: confidenceSum / Float(HandLandmark.count), viewport: viewport, worldM: world)
    }

    private func detectBodies(_ buffer: CVPixelBuffer, viewAspect: Float) -> [PlayerSighting] {
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right, options: [:])
        do {
            try handler.perform([bodyRequest])
        } catch {
            return []
        }
        let imageAspect = uprightAspect(buffer)
        var sightings: [PlayerSighting] = []
        for observation in bodyRequest.results ?? [] {
            guard let points = try? observation.recognizedPoints(.all) else { continue }
            func joint(_ name: VNHumanBodyPoseObservation.JointName) -> BodyJoint? {
                guard let point = points[name] else { return nil }
                let image = Vec2(Float(point.location.x), Float(point.location.y))
                return BodyJoint(
                    point: ViewportMapping.aspectFill(image, imageAspect: imageAspect, viewAspect: viewAspect),
                    confidence: point.confidence)
            }
            if let sighting = BodyAnchor.sighting(
                neck: joint(.neck), leftShoulder: joint(.leftShoulder), rightShoulder: joint(.rightShoulder),
                minConfidence: Self.jointMinConfidence)
            {
                sightings.append(sighting)
            }
        }
        return sightings
    }
}
