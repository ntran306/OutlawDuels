import AVFoundation
import Core

/// Plays the synthesised sounds of docs/GUI.md §8. The session category is `.ambient`, so
/// the silent switch mutes everything and the user's own music keeps playing.
/// Pass 1: effects only; the ambience loop and volume sliders come in pass 2.
@MainActor
final class AudioPlayer {
    enum Sound: String, CaseIterable {
        case shot, ricochet, hit, bull, cock, dry, hurt
        case uiTap = "ui_tap"
        case uiConfirm = "ui_confirm"
        case uiBack = "ui_back"
        case uiWhoosh = "ui_whoosh"
        case countTick = "count_tick"
        case countDraw = "count_draw"
        case stingLaunch = "sting_launch"
        case stingResults = "sting_results"
        case stingDown = "sting_down"

        /// Playback gain, the "Vol" column of GUI.md §8.
        var volume: Float {
            switch self {
            case .shot: return 0.55
            case .ricochet: return 0.30
            case .hit: return 0.60
            case .bull: return 0.70
            case .cock: return 0.40
            case .dry: return 0.35
            case .hurt: return 0.60
            case .uiTap: return 0.50
            case .uiConfirm: return 0.50
            case .uiBack: return 0.45
            case .uiWhoosh: return 0.35
            case .countTick: return 0.60
            case .countDraw: return 0.70
            case .stingLaunch: return 0.60
            case .stingResults: return 0.60
            case .stingDown: return 0.55
            }
        }
    }

    private let engine = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var nextNode = 0

    init() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            Log.message("audio_session_failed", String(describing: error))
        }

        for sound in Sound.allCases {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(
                      pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil
            else {
                Log.message("audio_missing", sound.rawValue)
                continue
            }
            buffers[sound] = buffer
        }
        Log.event("audio_loaded", ["count": Double(buffers.count), "expected": Double(Sound.allCases.count)])

        guard let format = buffers.values.first?.format else { return }
        for _ in 0..<6 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            nodes.append(node)
        }
        startEngine()
    }

    private func startEngine() {
        do {
            try engine.start()
        } catch {
            Log.message("audio_engine_failed", String(describing: error))
        }
    }

    func play(_ sound: Sound) {
        guard let buffer = buffers[sound], !nodes.isEmpty else { return }
        if !engine.isRunning { startEngine() }
        guard engine.isRunning else { return }
        let node = nodes[nextNode]
        nextNode = (nextNode + 1) % nodes.count
        node.volume = sound.volume
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        node.play()
    }
}
