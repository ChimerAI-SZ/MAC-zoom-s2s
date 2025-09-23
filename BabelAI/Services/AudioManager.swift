import Foundation
import AVFoundation
import Combine
import AppKit

final class AudioManager: ObservableObject {
    private let engine = AVAudioEngine()
    #if os(iOS)
    private let session = AVAudioSession.sharedInstance()
    #endif

    @Published private(set) var isRunning = false
    @Published private(set) var hasPermission = false
    @Published private(set) var lastError: String? = nil
    @Published private(set) var inputLevelRMS: Float = 0.0

    // 发布 80ms 的 PCM S16LE 数据帧（16kHz mono）
    let chunkPublisher = PassthroughSubject<Data, Never>()

    // 目标采集设置：16kHz mono，80ms 分片（1280 样本）
    private let sampleRate: Double = 16_000
    private let frameSamples: AVAudioFrameCount = 1280
    private lazy var targetFormat: AVAudioFormat = {
        AVAudioFormat(commonFormat: .pcmFormatFloat32,
                      sampleRate: sampleRate,
                      channels: 1,
                      interleaved: false)!
    }()

    // 输入设备实际格式与转换器
    private var inputFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var sampleAcc = [Float]()

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    if !granted {
                        self?.lastError = "未授予麦克风权限"
                    }
                    completion(granted)
                }
            }
        case .authorized:
            hasPermission = true
            completion(true)
        case .denied, .restricted:
            hasPermission = false
            lastError = "麦克风权限被拒绝或受限"
            completion(false)
        @unknown default:
            hasPermission = false
            lastError = "未知的麦克风权限状态"
            completion(false)
        }
    }

    func openMicrophoneSettings() {
        // 打开系统设置的麦克风页面
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    func start() {
        guard !isRunning else { return }
        configureSession()

        let input = engine.inputNode
        // 使用设备原生格式安装 tap，避免强制设置导致崩溃（macOS 不支持修改 inputNode 格式）
        let inFmt = input.outputFormat(forBus: 0)
        self.inputFormat = inFmt
        self.converter = AVAudioConverter(from: inFmt, to: targetFormat)

        input.removeTap(onBus: 0)
        // 选择较小缓冲，频繁回调，由我们聚合成 80ms@16k
        let tapBufferSize: AVAudioFrameCount = 1024
        input.installTap(onBus: 0, bufferSize: tapBufferSize, format: inFmt) { [weak self] buffer, _ in
            self?.processThroughConverter(buffer: buffer)
        }

        do {
            try engine.start()
            isRunning = true
            lastError = nil
        } catch {
            let msg = "Audio engine start failed: \(error.localizedDescription)"
            Logger.shared.error(msg)
            lastError = msg
            isRunning = false
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func configureSession() {
        #if os(iOS)
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setPreferredSampleRate(sampleRate)
            try session.setActive(true)
        } catch {
            Logger.shared.warn("AVAudioSession configure failed: \(error.localizedDescription)")
        }
        #endif
    }

    // 将设备原生格式转换为 16kHz mono，并聚合为 80ms 帧后输出 PCM16
    private func processThroughConverter(buffer: AVAudioPCMBuffer) {
        guard let converter = self.converter else { return }

        // 估算转换后的容量（按采样率比例放大/缩小）
        let inSR = buffer.format.sampleRate
        let ratio = sampleRate / inSR
        let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else { return }

        var localBuffer: AVAudioPCMBuffer? = buffer
        let status = converter.convert(to: outBuf, error: nil) { _, outStatus -> AVAudioBuffer? in
            if let b = localBuffer {
                localBuffer = nil
                outStatus.pointee = .haveData
                return b
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }
        guard status != .error, let ptr = outBuf.floatChannelData?.pointee else { return }
        let frames = Int(outBuf.frameLength)
        if frames == 0 { return }

        // 追加到累积缓冲
        sampleAcc.reserveCapacity(sampleAcc.count + frames)
        for i in 0..<frames { sampleAcc.append(ptr[i]) }

        // 按 1280 样本切片，输出 PCM16
        while sampleAcc.count >= Int(frameSamples) {
            let chunkFloats = Array(sampleAcc[0..<Int(frameSamples)])
            sampleAcc.removeFirst(Int(frameSamples))

            var s16 = [Int16](repeating: 0, count: Int(frameSamples))
            for i in 0..<Int(frameSamples) {
                let v = max(-1.0, min(1.0, Double(chunkFloats[i])))
                s16[i] = Int16(v * 32767.0)
            }
            let data = s16.withUnsafeBufferPointer { Data(buffer: $0) }
            // 计算简单 RMS 电平供诊断
            let rms = sqrt(chunkFloats.reduce(0.0) { $0 + Double($1 * $1) } / Double(chunkFloats.count))
            DispatchQueue.main.async { self.inputLevelRMS = Float(rms) }
            chunkPublisher.send(data)
        }
    }
}
