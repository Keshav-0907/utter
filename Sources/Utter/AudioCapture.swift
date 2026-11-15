import Accelerate
import AVFoundation

/// Converts arbitrary PCM buffers to a target format, one buffer at a time.
final class BufferConverter {
    private let converter: AVAudioConverter
    private let source: AVAudioFormat
    private let target: AVAudioFormat

    init?(from source: AVAudioFormat, to target: AVAudioFormat) {
        guard let converter = AVAudioConverter(from: source, to: target) else { return nil }
        converter.primeMethod = .none
        self.converter = converter
        self.source = source
        self.target = target
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let ratio = target.sampleRate / source.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil && out.frameLength > 0 ? out : nil
    }
}

/// Microphone capture that delivers buffers already converted to the engine's format.
final class AudioCapture {
    /// A new engine for every recording: a reused one can keep the previous microphone's
    /// format after the input device changes (AirPods connected, etc.) and then fail or crash.
    private var engine: AVAudioEngine?

    /// `onLevel` receives a 0...1 loudness value per buffer (audio thread).
    func start(
        format target: AVAudioFormat,
        onBuffer: @escaping (AVAudioPCMBuffer) -> Void,
        onLevel: @escaping (Float) -> Void
    ) throws {
        stop()
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let source = input.outputFormat(forBus: 0)
        guard source.sampleRate > 0, source.channelCount > 0 else {
            throw EngineError("No microphone input available")
        }
        guard let converter = BufferConverter(from: source, to: target) else {
            throw EngineError("Cannot convert microphone audio to \(target)")
        }
        // Passing nil lets the tap use whatever format the hardware is delivering right now.
        input.installTap(onBus: 0, bufferSize: 2048, format: nil) { buffer, _ in
            if buffer.format == source {
                if let converted = converter.convert(buffer) { onBuffer(converted) }
            } else if let adapted = BufferConverter(from: buffer.format, to: target)?.convert(buffer) {
                onBuffer(adapted)
            }
            onLevel(Self.level(of: buffer))
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        self.engine = engine
    }

    func stop() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
    }

    /// RMS mapped from roughly -50 dB (silence) ... -12 dB (loud speech) to 0...1.
    private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(buffer.frameLength))
        let db = 20 * log10(max(rms, 1e-6))
        return min(max((db + 50) / 38, 0), 1)
    }
}
