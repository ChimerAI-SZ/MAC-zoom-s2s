import Foundation
import AVFoundation

final class AudioPlayer: ObservableObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let renderFormat: AVAudioFormat
    private let sampleRate: Double = 48_000
    private let channels: AVAudioChannelCount = 1

    @Published private(set) var isRunning = false

    init() {
        renderFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: renderFormat)
        // 显式将主混音器连接到输出，避免某些系统上未自动连通
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
    }

    func start() {
        guard !isRunning else { return }
        do {
            try engine.start()
            player.play()
            isRunning = true
        } catch {
            Logger.shared.error("AudioPlayer start failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard isRunning else { return }
        player.stop()
        engine.stop()
        isRunning = false
    }

    // 入参：48kHz mono PCM S16LE
    func enqueuePCM16(_ data: Data) {
        let frameCount = UInt32(data.count / 2) // 2 bytes per sample
        guard frameCount > 0 else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: renderFormat, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        // 将 Int16 转为 Float32，并做 2ms 余弦淡出防爆音
        let samples = data.withUnsafeBytes { ptr -> [Int16] in
            Array(UnsafeBufferPointer(start: ptr.baseAddress!.assumingMemoryBound(to: Int16.self), count: Int(frameCount)))
        }
        var floats = samples.map { Float($0) / 32768.0 }

        let fadeSamples = min(96, floats.count) // 2ms @ 48kHz ≈ 96 samples
        if fadeSamples > 0 {
            for i in 0..<fadeSamples {
                let t = Double(i) / Double(fadeSamples - 1)
                let gain = Float(cos((.pi / 2.0) * t)) // 1 -> 0
                floats[floats.count - fadeSamples + i] *= gain
            }
        }

        buffer.floatChannelData!.pointee.update(from: floats, count: Int(frameCount))
        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}
