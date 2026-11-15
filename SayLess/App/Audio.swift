import AVFoundation
import SayLessEngine

/// Microphone capture for push-to-talk. The tap uses the input node's native format
/// (anything else crashes on some routes) and converts to 16 kHz mono Float for Whisper.
final class Recorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var samples: [Float] = []
    private(set) var isRecording = false
    /// Input level 0...1, smoothed, for the capsule's breathing ring.
    var onLevel: ((Float) -> Void)?

    static let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

    static func configureSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try? s.setActive(true)
    }

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    static var permissionGranted: Bool { AVAudioApplication.shared.recordPermission == .granted }

    func start() throws {
        guard !isRecording else { return }
        Self.configureSession()
        lock.lock(); samples.removeAll(keepingCapacity: true); lock.unlock()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw EngineError.failed("No microphone input") }
        converter = AVAudioConverter(from: format, to: Self.target)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.ingest(buffer)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
    }

    /// Stops and returns everything captured since `start()`.
    @discardableResult
    func stop() -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        return snapshot()
    }

    func snapshot() -> [Float] {
        lock.lock(); defer { lock.unlock() }
        return samples
    }

    private func ingest(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = Self.target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 64)
        guard let out = AVAudioPCMBuffer(pcmFormat: Self.target, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let ch = out.floatChannelData?[0] else { return }
        let n = Int(out.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: ch, count: n))
        var peak: Float = 0
        for s in chunk { peak = max(peak, abs(s)) }
        lock.lock(); samples.append(contentsOf: chunk); lock.unlock()
        onLevel?(min(1, peak * 2.2))
    }
}

/// Plays synthesized speech. Keeps the last clip so a card can be replayed, or replayed slower.
@MainActor
final class Player {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private var attachedFormat: AVAudioFormat?

    func play(_ samples: [Float], sampleRate: Int, rate: Float = 1) {
        guard !samples.isEmpty,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }
        Recorder.configureSession()
        if attachedFormat != format {
            engine.stop()
            if attachedFormat == nil { engine.attach(node); engine.attach(pitch) }
            engine.disconnectNodeOutput(node)
            engine.disconnectNodeOutput(pitch)
            engine.connect(node, to: pitch, format: format)
            engine.connect(pitch, to: engine.mainMixerNode, format: format)
            attachedFormat = format
        }
        pitch.rate = rate
        if !engine.isRunning { try? engine.start() }
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        node.play()
    }

    func stop() { node.stop() }
}
