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
        // 使用稍大的缓冲减少回调频率（2048 样本 ≈ 42ms @ 48kHz）
        let tapBufferSize: AVAudioFrameCount = 2048
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

        // 按 1280 样本切片，输出 PCM16（若开启 AEC，则在此处进行近端处理）
        while sampleAcc.count >= Int(frameSamples) {
            let chunkFloats = Array(sampleAcc[0..<Int(frameSamples)])
            sampleAcc.removeFirst(Int(frameSamples))

            var s16 = [Int16](repeating: 0, count: Int(frameSamples))
            for i in 0..<Int(frameSamples) {
                let v = max(-1.0, min(1.0, Double(chunkFloats[i])))
                s16[i] = Int16(v * 32767.0)
            }
            var data = s16.withUnsafeBufferPointer { Data(buffer: $0) }
            
            // AEC处理：始终让 AEC 处理真实音频信号
            data = AECBridge.shared.processNear80ms(data)
            
            // 计算处理后音频的 RMS 电平（更准确）
            let processedRMS = calculateRMS(from: data)
            DispatchQueue.main.async { self.inputLevelRMS = Float(processedRMS) }
            
            // 专业级二元传输决策（类似Zoom/Teams）
            // 使用更宽容的阈值，减少语音被切断
            let hasSignificantAudio = processedRMS > 0.0001  // -80dB，更低的阈值
            
            // 二元决策：要么传输，要么不传输（没有中间状态）
            if hasSignificantAudio {
                // 有意义的音频信号，发送
                chunkPublisher.send(data)
            } else {
                // 无意义信号，完全不发送
                // 专业系统的做法：宁可丢失微弱语音，也要防止回声循环
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func calculateRMS(from pcm16Data: Data) -> Double {
        // 计算PCM16数据的RMS值
        let sampleCount = pcm16Data.count / 2
        guard sampleCount > 0 else { return 0.0 }
        
        var sumSquares: Double = 0.0
        pcm16Data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let samples = ptr.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                let normalizedSample = Double(samples[i]) / 32768.0
                sumSquares += normalizedSample * normalizedSample
            }
        }
        
        return sqrt(sumSquares / Double(sampleCount))
    }
}
