import Foundation
import AVFoundation
import os.lock

// Minimal, safe AEC bridge.
// - Far path: tap mainMixer, convert to 16k mono, slice to 10ms frames (160 samples), push to ring.
// - Near path: for each 80ms (1280 @16k) frame, split into 8x10ms; align far by delay; currently pass-through (no Speex yet).
// - Single tuning knob: delayMs (default 30), read from .env (AEC_DELAY_MS), can be overridden via setDelay(ms:).
// - Enable via setEnabled(_:) on start; disable on stop.

// C function declarations for SpeexDSP
typealias speex_echo_state_t = OpaquePointer
typealias speex_echo_state_init_t = @convention(c) (Int32, Int32) -> OpaquePointer?
typealias speex_echo_cancellation_t = @convention(c) (OpaquePointer, UnsafePointer<Int16>, UnsafePointer<Int16>, UnsafeMutablePointer<Int16>) -> Void
typealias speex_echo_state_destroy_t = @convention(c) (OpaquePointer) -> Void
typealias speex_echo_ctl_t = @convention(c) (OpaquePointer, Int32, UnsafeMutableRawPointer) -> Int32

// Speex Preprocess (optional residual echo suppression / denoise)
typealias speex_preprocess_state_t = OpaquePointer
typealias speex_preprocess_state_init_t = @convention(c) (Int32, Int32) -> OpaquePointer?
typealias speex_preprocess_state_destroy_t = @convention(c) (OpaquePointer) -> Void
typealias speex_preprocess_ctl_t = @convention(c) (OpaquePointer, Int32, UnsafeMutableRawPointer) -> Int32
typealias speex_preprocess_run_t = @convention(c) (OpaquePointer, UnsafeMutablePointer<Int16>) -> Int32

final class AECBridge {
    static let shared = AECBridge()

    // Public controls
    private(set) var enabled: Bool = false
    private(set) var delayMs: Int = 30 { didSet { computeDelayFrames() } }
    
    // SpeexDSP handle and function pointers
    private var libHandle: UnsafeMutableRawPointer?
    private var speex_echo_state_init: speex_echo_state_init_t?
    private var speex_echo_cancellation: speex_echo_cancellation_t?
    private var speex_echo_state_destroy: speex_echo_state_destroy_t?
    private var speex_echo_ctl: speex_echo_ctl_t?
    private var echoState: speex_echo_state_t?
    // Preprocess symbols/state
    private var speex_preprocess_state_init: speex_preprocess_state_init_t?
    private var speex_preprocess_state_destroy: speex_preprocess_state_destroy_t?
    private var speex_preprocess_ctl: speex_preprocess_ctl_t?
    private var speex_preprocess_run: speex_preprocess_run_t?
    private var preState: speex_preprocess_state_t?
    
    // Constants
    private let workSampleRate: Double = 16_000
    private let frame10ms: Int = 160 // 10ms @ 16kHz

    // Far path state
    private var farConverter: AVAudioConverter?
    private var farAccFloats: [Float] = []

    // 10ms ring buffer (stores Int16[160])
    private let ringCapacity = 2048 // ~20.48s
    private var ring: [[Int16]]
    private var ringHead: Int = 0
    private var ringInitialized = false
    private var ringLock = os_unfair_lock()

    // Derived alignment
    private var delayFrames10ms: Int = 3 // 30ms default
    // Hysteresis hold for far-dominant gating (in 10ms subframes)
    private var gateHoldSubframes: Int = 0
    private let gateHoldDefault: Int = 50 // 500ms - 更长的静音保持时间确保尾音完全消除
    
    // 舒适噪声生成器
    private var comfortNoiseLevel: Float = 0.0001 // -80dB 极低级噪声
    
    // 双讲检测状态跟踪（用于调试）
    private enum TalkState {
        case silence
        case farEndOnly
        case nearEndOnly
        case doubleTalk
    }
    private var currentTalkState: TalkState = .silence
    private var stateChangeCounter: Int = 0
    

    private init() {
        NSLog("[AEC] AECBridge init() called")
        self.ring = Array(repeating: Array(repeating: 0, count: frame10ms), count: ringCapacity)
        // Load default delay from env if present
        if let s = ConfigStore.shared.envValue("AEC_DELAY_MS"), let v = Int(s), v >= 0, v <= 200 {
            delayMs = v
            NSLog("[AEC] Loaded delay from env: \(v)ms")
        }
        computeDelayFrames()
        NSLog("[AEC] About to load SpeexDSP...")
        loadSpeexDSP()
    }
    
    private func loadSpeexDSP() {
        NSLog("[AEC] loadSpeexDSP() called")
        let candidates = [
            "@rpath/libspeexdsp.dylib", // Embedded library (priority)
            Bundle.main.privateFrameworksPath.map { "\($0)/libspeexdsp.dylib" } ?? "",
            Bundle.main.bundlePath.appending("/Contents/Frameworks/libspeexdsp.dylib"),
            "/opt/homebrew/lib/libspeexdsp.dylib" // Fallback for development
        ]
        NSLog("[AEC] Candidates to try: \(candidates)")
        
        for path in candidates {
            if path.isEmpty { continue }
            libHandle = dlopen(path, RTLD_NOW)
            if libHandle != nil {
                NSLog("[AEC] Successfully loaded SpeexDSP from: \(path)")
                Logger.shared.info("[AEC] Loaded SpeexDSP from: \(path)")
                break
            } else {
                NSLog("[AEC] Failed to load from: \(path)")
            }
        }
        
        guard let handle = libHandle else {
            NSLog("[AEC] SpeexDSP not loaded (will use pass-through)")
            Logger.shared.warn("[AEC] SpeexDSP not loaded (will use pass-through)")
            return
        }
        
        // Bind functions (echo)
        speex_echo_state_init = unsafeBitCast(dlsym(handle, "speex_echo_state_init"), to: speex_echo_state_init_t?.self)
        speex_echo_cancellation = unsafeBitCast(dlsym(handle, "speex_echo_cancellation"), to: speex_echo_cancellation_t?.self)
        speex_echo_state_destroy = unsafeBitCast(dlsym(handle, "speex_echo_state_destroy"), to: speex_echo_state_destroy_t?.self)
        speex_echo_ctl = unsafeBitCast(dlsym(handle, "speex_echo_ctl"), to: speex_echo_ctl_t?.self)
        
        // Bind functions (preprocess)
        speex_preprocess_state_init = unsafeBitCast(dlsym(handle, "speex_preprocess_state_init"), to: speex_preprocess_state_init_t?.self)
        speex_preprocess_state_destroy = unsafeBitCast(dlsym(handle, "speex_preprocess_state_destroy"), to: speex_preprocess_state_destroy_t?.self)
        speex_preprocess_ctl = unsafeBitCast(dlsym(handle, "speex_preprocess_ctl"), to: speex_preprocess_ctl_t?.self)
        speex_preprocess_run = unsafeBitCast(dlsym(handle, "speex_preprocess_run"), to: speex_preprocess_run_t?.self)

        if speex_echo_state_init != nil && speex_echo_cancellation != nil {
            NSLog("[AEC] ✅ SpeexDSP functions bound successfully")
            Logger.shared.info("[AEC] SpeexDSP functions bound successfully")
        } else {
            NSLog("[AEC] ❌ SpeexDSP functions not bound - init: \(speex_echo_state_init != nil), cancel: \(speex_echo_cancellation != nil)")
            Logger.shared.warn("[AEC] SpeexDSP functions not bound")
        }
    }

    func setEnabled(_ flag: Bool) {
        NSLog("[AEC] setEnabled(\(flag))")
        Logger.shared.info("[AEC] setEnabled(\(flag))")
        enabled = flag
    }

    func setDelay(ms: Int) {
        delayMs = max(0, min(200, ms))
    }

    func activate() {
        NSLog("[AEC] activate() called")
        // Reload delay from .env whenever the pipeline starts
        if let s = ConfigStore.shared.envValue("AEC_DELAY_MS"), let v = Int(s), v >= 0, v <= 200 {
            delayMs = v
        }
        reset()
        initializeEchoState()
    }
    
    private func initializeEchoState() {
        guard let init_func = speex_echo_state_init else {
            NSLog("[AEC] No speex_echo_state_init, using pass-through")
            Logger.shared.debug("[AEC] No speex_echo_state_init, using pass-through")
            return
        }
        
        // Destroy old state if exists
        if let state = echoState {
            speex_echo_state_destroy?(state)
            echoState = nil
        }
        
        // Create new echo state: frame=160 (10ms), tail≈3200 (200ms)
        NSLog("[AEC] Creating echo state with frame=\(frame10ms), tail=3200 (200ms)")
        echoState = init_func(Int32(frame10ms), Int32(3200))
        if echoState != nil {
            NSLog("[AEC] ✅ Echo state initialized successfully")
            Logger.shared.info("[AEC] Echo state initialized (frame=160, tail=3200)")
            // Set sampling rate to 16k for proper internal scaling
            if let ctl = speex_echo_ctl, let st = echoState {
                var sr: Int32 = 16000
                _ = withUnsafeMutablePointer(to: &sr) { ptr in
                    ctl(st, 24 /* SPEEX_ECHO_SET_SAMPLING_RATE */, UnsafeMutableRawPointer(ptr))
                }
            }
            // Initialize preprocess and bind echo state (if symbols available)
            if let pinit = speex_preprocess_state_init {
                preState = pinit(Int32(frame10ms), Int32(16000))
                if let p = preState, let pctl = speex_preprocess_ctl {
                    // 启用降噪
                    var one: Int32 = 1
                    _ = withUnsafeMutablePointer(to: &one) { pctl(p, 0 /* DENOISE */, UnsafeMutableRawPointer($0)) }
                    
                    // 激进的残留回声抑制（-60 dB，专业级强度）
                    var sup: Int32 = -60
                    _ = withUnsafeMutablePointer(to: &sup) { pctl(p, 8 /* ECHO_SUPPRESS */, UnsafeMutableRawPointer($0)) }
                    
                    // 双讲时的激进抑制（-40 dB，防止任何回声泄露）
                    var supAct: Int32 = -40
                    _ = withUnsafeMutablePointer(to: &supAct) { pctl(p, 9 /* ECHO_SUPPRESS_ACTIVE */, UnsafeMutableRawPointer($0)) }
                    
                    // 启用VAD（语音活动检测）
                    _ = withUnsafeMutablePointer(to: &one) { pctl(p, 2 /* VAD */, UnsafeMutableRawPointer($0)) }
                    
                    // 设置VAD概率起始值（更保守的起始）
                    var prob: Int32 = 20
                    _ = withUnsafeMutablePointer(to: &prob) { pctl(p, 21 /* PROB_START */, UnsafeMutableRawPointer($0)) }
                    
                    // 设置VAD概率继续值
                    var probCont: Int32 = 10
                    _ = withUnsafeMutablePointer(to: &probCont) { pctl(p, 22 /* PROB_CONTINUE */, UnsafeMutableRawPointer($0)) }
                    
                    if let st = echoState {
                        var est = st
                        _ = withUnsafeMutablePointer(to: &est) { pctl(p, 7 /* SET_ECHO_STATE */, UnsafeMutableRawPointer($0)) }
                    }
                    NSLog("[AEC] Preprocess configured with professional settings: suppress=-60dB, suppress_active=-40dB")
                    Logger.shared.info("[AEC] Professional double-talk detection enabled with correlation threshold=0.7")
                }
            }
        } else {
            NSLog("[AEC] ❌ Failed to initialize echo state")
            Logger.shared.warn("[AEC] Failed to initialize echo state")
        }
    }

    func deactivate() {
        reset()
        enabled = false
        if let p = preState { speex_preprocess_state_destroy?(p); preState = nil }
        if let state = echoState {
            speex_echo_state_destroy?(state)
            echoState = nil
        }
    }

    private func reset() {
        os_unfair_lock_lock(&ringLock)
        ringHead = 0
        ringInitialized = true
        for i in 0..<ringCapacity { ring[i].withUnsafeMutableBufferPointer { ptr in ptr.initialize(repeating: 0) } }
        os_unfair_lock_unlock(&ringLock)
        farConverter = nil
        farAccFloats.removeAll(keepingCapacity: false)
        gateHoldSubframes = 0
    }

    private func computeDelayFrames() { delayFrames10ms = delayMs / 10 }

    // MARK: - Far path ingest (48k/any fmt -> 16k mono -> 10ms frames into ring)
    func ingestFar(buffer: AVAudioPCMBuffer) {
        guard enabled else { return }
        // Prepare converter once per format
        if farConverter == nil || farConverter!.inputFormat != buffer.format {
            let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: workSampleRate, channels: 1, interleaved: false)!
            farConverter = AVAudioConverter(from: buffer.format, to: target)
            farAccFloats.removeAll(keepingCapacity: false)
        }
        guard let converter = farConverter else { return }

        // Convert this buffer chunk to 16k mono float
        let inFrames = buffer.frameLength
        if inFrames == 0 { return }
        let targetFormat = converter.outputFormat
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outCap = AVAudioFrameCount(Double(inFrames) * ratio + 32)
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCap) else { return }

        var local: AVAudioPCMBuffer? = buffer
        let status = converter.convert(to: outBuf, error: nil) { _, outStatus -> AVAudioBuffer? in
            if let b = local { local = nil; outStatus.pointee = .haveData; return b }
            outStatus.pointee = .noDataNow; return nil
        }
        if status == .error || outBuf.frameLength == 0 { return }
        guard let p = outBuf.floatChannelData?.pointee else { return }

        let frames = Int(outBuf.frameLength)
        farAccFloats.reserveCapacity(farAccFloats.count + frames)
        for i in 0..<frames { farAccFloats.append(p[i]) }

        // Emit 10ms frames
        while farAccFloats.count >= frame10ms {
            var s16 = [Int16](repeating: 0, count: frame10ms)
            for i in 0..<frame10ms {
                let v = max(-1.0, min(1.0, Double(farAccFloats[i])))
                s16[i] = Int16(v * 32767.0)
            }
            farAccFloats.removeFirst(frame10ms)
            pushRingFrame(s16)
        }
    }

    // MARK: - Near path process (80ms -> 8x10ms), with AEC if available
    func processNear80ms(_ pcm16_80ms: Data) -> Data {
        guard enabled else { 
            return pcm16_80ms 
        }
        // Slice into 8x10ms
        let expectedBytes = frame10ms * 8 * 2
        if pcm16_80ms.count != expectedBytes { return pcm16_80ms }

        var processed = Data(capacity: expectedBytes)
        pcm16_80ms.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) in
            let base = rawPtr.bindMemory(to: Int16.self).baseAddress!
            for f in 0..<8 {
                let off = f * frame10ms
                let nearPtr = base.advanced(by: off)
                var out = [Int16](repeating: 0, count: frame10ms)
                
                // Get far-end reference frame with delay alignment
                let farFrame = pullRingFrameDelayed(offsetFrames10ms: delayFrames10ms + f)
                
                // Apply AEC if available: cancel(near, far, out)
                var didAec = false
                if let state = echoState, let cancel = speex_echo_cancellation {
                    farFrame.withUnsafeBufferPointer { farPtr in
                        out.withUnsafeMutableBufferPointer { outPtr in
                            cancel(state, nearPtr, farPtr.baseAddress!, outPtr.baseAddress!)
                        }
                    }
                    didAec = true
                }
                // Residual echo suppression / denoise with VAD + hysteresis gate
                if didAec, let pre = preState, let run = speex_preprocess_run {
                    var vadSpeech: Int32 = 1
                    out.withUnsafeMutableBufferPointer { outPtr in
                        vadSpeech = run(pre, outPtr.baseAddress!)
                    }
                    // 专业级双讲检测（支持全双工通信）
                    let farR = rms(of: farFrame)
                    let outR = rms(ofInt16Ptr: out)
                    let corr = correlation(out: out, far: farFrame)
                    
                    // 三态检测系统
                    let energyRatio = outR / (farR + 0.0001)
                    
                    // 1. 纯回声检测：高相关性 + 低能量比 = 扬声器播放的声音
                    let isEcho = corr > 0.7 && farR > 0.01 && energyRatio < 0.5
                    
                    // 2. 本地语音检测：VAD检测到语音 + 低相关性 = 真实说话
                    let isLocalSpeech = vadSpeech == 1 && corr < 0.3
                    
                    // 3. 双讲检测：中等相关性 + VAD有语音 = 同时说话
                    let isDoubleTalk = vadSpeech == 1 && corr >= 0.3 && corr <= 0.7
                    
                    // 决策逻辑与状态跟踪
                    var newState: TalkState = .silence
                    
                    if isEcho && !isLocalSpeech {
                        // 纯回声（扬声器声音），需要抑制
                        gateHoldSubframes = gateHoldDefault
                        newState = .farEndOnly
                    } else if isDoubleTalk {
                        // 双讲状态，让AEC自适应滤波器处理
                        // 不额外门控，允许双方同时说话
                        // gateHoldSubframes 保持当前值，自然衰减
                        newState = .doubleTalk
                    } else if isLocalSpeech {
                        // 本地语音，完全保留
                        newState = .nearEndOnly
                    } else if vadSpeech == 0 && farR > 0.005 && corr > 0.5 {
                        // 无VAD但有明显相关的远端信号，也要抑制
                        gateHoldSubframes = gateHoldDefault
                        newState = .farEndOnly
                    }
                    
                    // 状态变化日志（仅在状态改变时）
                    if newState != currentTalkState {
                        currentTalkState = newState
                        stateChangeCounter += 1
                        if stateChangeCounter % 10 == 0 {
                            Logger.shared.debug("[AEC] Talk state: \(newState), corr=\(String(format: "%.2f", corr)), energyRatio=\(String(format: "%.2f", energyRatio))")
                        }
                    }
                    if gateHoldSubframes > 0 {
                        // 生成舒适噪声而非完全静音（专业系统的做法）
                        out.withUnsafeMutableBufferPointer { ob in
                            for i in 0..<frame10ms {
                                // 生成极低级的粉红噪声（-80dB）
                                let noise = Int16(Float.random(in: -1...1) * comfortNoiseLevel * 32768.0)
                                ob[i] = noise
                            }
                        }
                        gateHoldSubframes -= 1
                    }
                } else if !didAec {
                    // Pass-through if no AEC
                    out.withUnsafeMutableBufferPointer { dst in
                        dst.baseAddress!.update(from: nearPtr, count: frame10ms)
                    }
                }

                let chunk = out.withUnsafeBufferPointer { Data(buffer: $0) }
                processed.append(chunk)
            }
        }
        return processed
    }

    // MARK: - Ring buffer helpers
    private func pushRingFrame(_ frame: [Int16]) {
        os_unfair_lock_lock(&ringLock)
        ring[ringHead] = frame
        ringHead = (ringHead + 1) % ringCapacity
        os_unfair_lock_unlock(&ringLock)
    }

    private func pullRingFrameDelayed(offsetFrames10ms: Int) -> [Int16] {
        os_unfair_lock_lock(&ringLock)
        defer { os_unfair_lock_unlock(&ringLock) }
        if !ringInitialized { return Array(repeating: 0, count: frame10ms) }
        let idx = (ringHead - 1 - offsetFrames10ms) % ringCapacity
        let safeIdx = idx < 0 ? idx + ringCapacity : idx
        if safeIdx >= 0 && safeIdx < ringCapacity { return ring[safeIdx] }
        return Array(repeating: 0, count: frame10ms)
    }
    
    deinit {
        if let p = preState { speex_preprocess_state_destroy?(p) }
        preState = nil
        if let state = echoState { speex_echo_state_destroy?(state) }
        if let handle = libHandle {
            dlclose(handle)
        }
    }
}

// MARK: - Helpers: energy and correlation
private extension AECBridge {
    func rms(of frame: [Int16]) -> Double {
        if frame.isEmpty { return 0 }
        var acc: Double = 0
        let scale = 1.0 / 32768.0
        for s in frame { let v = Double(s) * scale; acc += v * v }
        return sqrt(acc / Double(frame.count))
    }
    func rms(ofInt16Ptr buf: [Int16]) -> Double { return rms(of: buf) }
    func correlation(out: [Int16], far: [Int16]) -> Double {
        let n = min(out.count, far.count)
        if n == 0 { return 0 }
        var dot: Double = 0, ao: Double = 0, af: Double = 0
        let scale = 1.0 / 32768.0
        for i in 0..<n {
            let x = Double(out[i]) * scale
            let y = Double(far[i]) * scale
            dot += x * y; ao += x * x; af += y * y
        }
        let denom = sqrt(ao * af) + 1e-12
        return max(-1.0, min(1.0, dot / denom))
    }
}
