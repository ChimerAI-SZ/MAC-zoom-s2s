import Foundation
import Combine
import AVFoundation

final class TranslationService: ObservableObject {
    enum State: Equatable { 
        case idle, connecting, connected, reconnecting, error(String)
        
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.connecting, .connecting), 
                 (.connected, .connected), (.reconnecting, .reconnecting):
                return true
            case let (.error(msg1), .error(msg2)):
                return msg1 == msg2
            default:
                return false
            }
        }
    }

    @Published private(set) var state: State = .idle

    // 发送节拍：80ms
    private let frameInterval: TimeInterval = 0.08
    private var baseTime: TimeInterval = CACurrentMediaTime()
    private var frameCount: Int = 0

    // 队列与心跳
    private let queue = DispatchQueue(label: "com.babelai.ws", qos: .userInitiated)
    private var sendTimer: DispatchSourceTimer?
    private var heartbeatTimer: DispatchSourceTimer?
    private var receiveLoopActive = false

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession!
    private var reconnectAttempts = 0

    // 发送队列（容量 300，满时丢弃最旧）
    private var audioQueue = [Data]()
    private let maxQueue = 300

    // 会话 id
    private var sessionID = UUID().uuidString
    private var connectID = UUID().uuidString
    
    // 断连跟踪
    private var userDisconnected = false
    private var lastRealAudioTime: TimeInterval = 0

    // 指标
    private var pingSamples: [Double] = []
    // 句子缓冲，避免逐字弹出
    private var sourceSentenceBuffer: String = ""
    private var translationSentenceBuffer: String = ""

    // 依赖注入：由 App 注入共享实例
    private let config = ConfigStore.shared
    private weak var healthRef: HealthMonitor?
    private weak var playerRef: AudioPlayer?
    private weak var transcriptRef: TranscriptModel?

    func setDependencies(player: AudioPlayer, health: HealthMonitor, transcript: TranscriptModel? = nil) {
        self.playerRef = player
        self.healthRef = health
        self.transcriptRef = transcript
    }

    // MARK: Public API

    func enqueueAudio(_ data: Data) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.audioQueue.count >= self.maxQueue { self.audioQueue.removeFirst() }
            self.audioQueue.append(data)
            
            // 跟踪真实音频（非静音）
            if data.count > 0 && !self.isAllSilent(data) {
                self.lastRealAudioTime = CACurrentMediaTime()
            }
            
            let queueSize = self.audioQueue.count
            DispatchQueue.main.async {
                self.healthRef?.updateQueueSize(queueSize)
            }
        }
    }

    func connect() {
        NSLog("[BabelAI WS] TranslationService.connect() called, current state: \(state)")
        
        // 防止重复连接
        switch state {
        case .connecting, .connected, .reconnecting:
            NSLog("[BabelAI WS] Already connecting/connected (state: \(state)), ignoring duplicate connect")
            return
        case .idle, .error:
            // 允许从空闲或错误状态开始连接
            break
        }
        
        guard let api = config.readAPI() else {
            NSLog("[BabelAI WS] ⚠️ ERROR: Failed to read API config")
            DispatchQueue.main.async { [weak self] in
                self?.state = .error("未配置 API 密钥")
            }
            return
        }
        
        NSLog("[BabelAI WS] ✅ API Config loaded successfully")
        NSLog("[BabelAI WS] AppKey: \(api.appKey.prefix(10))..., URL: \(api.wsURL)")
        
        DispatchQueue.main.async { [weak self] in
            self?.state = .connecting
        }
        reconnectAttempts = 0
        userDisconnected = false
        lastRealAudioTime = CACurrentMediaTime()
        startSession(api: api)
    }

    func disconnect() {
        NSLog("[BabelAI WS] Disconnect requested, current state: \(state)")
        
        // 标记为用户主动断连
        userDisconnected = true
        
        // 立即设置状态，防止新的连接尝试
        DispatchQueue.main.async { [weak self] in
            self?.state = .idle
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            NSLog("[BabelAI WS] Performing disconnect cleanup...")
            self.stopTimers()
            self.receiveLoopActive = false
            self.webSocket?.cancel(with: .goingAway, reason: nil)
            self.webSocket = nil
            self.audioQueue.removeAll()
            DispatchQueue.main.async {
                self.healthRef?.updateQueueSize(0)
                NSLog("[BabelAI WS] Disconnect cleanup completed")
            }
        }
    }

    // MARK: Private

    private func startSession(api: APIConfig) {
        NSLog("[BabelAI WS] Starting WebSocket session...")
        NSLog("[BabelAI WS] URL: \(api.wsURL)")
        NSLog("[BabelAI WS] Headers - AppKey: \(api.appKey.prefix(10))..., ResourceId: \(api.resourceId)")
        
        Logger.shared.info("Starting WebSocket session with URL: \(api.wsURL)")
        Logger.shared.info("API Config - AppKey: \(api.appKey.prefix(10))..., ResourceId: \(api.resourceId)")
        
        let url = URL(string: api.wsURL)!
        var req = URLRequest(url: url)
        req.setValue(api.appKey, forHTTPHeaderField: "X-Api-App-Key")
        req.setValue(api.accessKey, forHTTPHeaderField: "X-Api-Access-Key")
        req.setValue(api.resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        connectID = UUID().uuidString
        req.setValue(connectID, forHTTPHeaderField: "X-Api-Connect-Id")

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.waitsForConnectivity = true
        cfg.connectionProxyDictionary = [:] // 尽量绕过系统代理
        session = URLSession(configuration: cfg)
        webSocket = session.webSocketTask(with: req)

        webSocket?.resume()
        
        // 等待WebSocket真正连接后再发送StartSession
        queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            let wsState = self.webSocket?.state
            NSLog("[BabelAI WS] WebSocket state after resume: \(String(describing: wsState))")
            Logger.shared.info("WebSocket state after resume: ready=\(wsState == .running)")
            
            if wsState == .running {
                NSLog("[BabelAI WS] ✅ WebSocket connected! Sending StartSession...")
                self.sendStartSession()
                self.startTimers()
                self.receiveLoop()
            } else {
                NSLog("[BabelAI WS] ❌ WebSocket failed to connect! State: \(String(describing: wsState))")
                Logger.shared.error("WebSocket not ready after resume, state=\(String(describing: wsState))")
                self.handleSocketError(NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebSocket failed to connect"]))
            }
        }
    }

    private func receiveLoop() {
        guard let ws = webSocket else { 
            Logger.shared.error("receiveLoop: webSocket is nil")
            return 
        }
        if receiveLoopActive { 
            Logger.shared.debug("receiveLoop already active, skipping")
            return 
        }
        receiveLoopActive = true
        Logger.shared.info("Starting receive loop")
        
        ws.receive { [weak self] result in
            guard let self = self else { return }
            
            // Check if we're disconnecting before processing
            guard !self.userDisconnected else {
                self.receiveLoopActive = false
                Logger.shared.debug("Receive loop stopped due to user disconnect")
                return
            }
            
            switch result {
            case .failure(let err):
                // Only log non-disconnection errors
                if !self.userDisconnected {
                    Logger.shared.error("WebSocket receive error: \(err)")
                    self.handleSocketError(err)
                }
                self.receiveLoopActive = false
            case .success(let message):
                switch message {
                case .data(let data):
                    Logger.shared.info("Received WebSocket data: \(data.count) bytes")
                    self.handleIncomingData(data)
                    DispatchQueue.main.async { 
                        self.healthRef?.recordEvent() 
                    }
                case .string(let text):
                    Logger.shared.warn("Received unexpected string message: \(text)")
                @unknown default: 
                    Logger.shared.warn("Received unknown message type")
                }
                self.receiveLoopActive = false
                // Continue loop only if not disconnecting
                if !self.userDisconnected {
                    self.receiveLoop()
                }
            }
        }
    }

    private func handleIncomingData(_ data: Data) {
        // 解码译文文本与 48kHz PCM 并播放
        let payload = WireCodec.shared.decodeResponse(data)
        if payload.event == .sessionStarted {
            DispatchQueue.main.async { self.state = .connected }
            Logger.shared.info("Session started successfully")
        }
        if let pcm48k = payload.pcm48k {
            DispatchQueue.main.async { [weak self] in
                self?.playerRef?.enqueuePCM16(pcm48k)
            }
            Logger.shared.debug("Received TTS audio: \(pcm48k.count) bytes")
        }
        // 句子组装逻辑：仅在 End 事件时输出整句
        if let event = payload.event {
            switch event {
            case .sourceSubtitleStart:
                sourceSentenceBuffer = ""
            case .sourceSubtitleResponse:
                if let t = payload.sourceText { sourceSentenceBuffer += (sourceSentenceBuffer.isEmpty ? "" : " ") + t }
            case .sourceSubtitleEnd:
                if !sourceSentenceBuffer.isEmpty {
                    let out = sourceSentenceBuffer
                    DispatchQueue.main.async { [weak self] in
                        self?.transcriptRef?.append(source: out, target: nil)
                    }
                    sourceSentenceBuffer = ""
                }
            case .translationSubtitleStart:
                translationSentenceBuffer = ""
            case .translationSubtitleResponse:
                if let t = payload.targetText { translationSentenceBuffer += (translationSentenceBuffer.isEmpty ? "" : " ") + t }
            case .translationSubtitleEnd:
                if !translationSentenceBuffer.isEmpty {
                    let out = translationSentenceBuffer
                    DispatchQueue.main.async { [weak self] in
                        self?.transcriptRef?.append(source: nil, target: out)
                    }
                    translationSentenceBuffer = ""
                }
            default:
                break
            }
        }
    }

    private func sendStartSession() {
        sessionID = UUID().uuidString
        // Get language settings from config
        let sourceLanguage = config.readAPI()?.sourceLanguage ?? "zh"
        let targetLanguage = config.readAPI()?.targetLanguage ?? "en"
        Logger.shared.info("StartSession: sid=\(sessionID), src=\(sourceLanguage), tgt=\(targetLanguage)")
        let startData = WireCodec.shared.encodeStartSession(
            sessionID: sessionID,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        sendRaw(startData)
        resetPacing()
    }

    private func sendAudioFrame(_ data: Data) {
        let msg = WireCodec.shared.encodeAudioChunk(sessionID: sessionID, pcm16: data, sequence: Int32(frameCount))
        sendRaw(msg)
    }

    private func sendRaw(_ data: Data) {
        Logger.shared.debug("Sending data: \(data.count) bytes")
        webSocket?.send(.data(data)) { error in
            if let error = error {
                Logger.shared.error("WebSocket send error: \(error)")
                self.handleSocketError(error)
            } else {
                Logger.shared.debug("WebSocket send success")
            }
        }
    }

    private func startTimers() {
        stopTimers()

        // 精确 80ms 发送；空队列时发送静音维持节拍
        sendTimer = DispatchSource.makeTimerSource(queue: queue)
        sendTimer?.schedule(deadline: .now(), repeating: frameInterval)
        sendTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let now = CACurrentMediaTime()
            let ideal = self.baseTime + Double(self.frameCount) * self.frameInterval
            let drift = now - ideal
            if drift > 0.5 {
                self.resetPacing()
            }

            let chunk: Data
            if self.audioQueue.isEmpty {
                // 智能静音处理：只在真实音频后 500ms 内发送静音
                let timeSinceRealAudio = CACurrentMediaTime() - self.lastRealAudioTime
                if timeSinceRealAudio < 0.5 {
                    // 保持时序同步
                    chunk = WireCodec.shared.silentFrame16k80ms
                } else {
                    // 不发送任何内容，防止 API 处理静音
                    return
                }
            } else {
                chunk = self.audioQueue.removeFirst()
                let queueSize = self.audioQueue.count
                DispatchQueue.main.async {
                    self.healthRef?.updateQueueSize(queueSize)
                }
            }
            self.sendAudioFrame(chunk)
            self.frameCount += 1
            if self.frameCount % 50 == 0 {
                Logger.shared.debug("sent frames=\(self.frameCount), queue=\(self.audioQueue.count)")
            }
        }
        sendTimer?.resume()

        // 30s 心跳，测 RTT
        heartbeatTimer = DispatchSource.makeTimerSource(queue: queue)
        heartbeatTimer?.schedule(deadline: .now() + 30, repeating: 30)
        heartbeatTimer?.setEventHandler { [weak self] in
            guard let self = self, let ws = self.webSocket else { return }
            let start = Date()
            ws.sendPing { error in
                if let error = error {
                    self.handleSocketError(error)
                    return
                }
                let rtt = Date().timeIntervalSince(start) * 1000
                self.pingSamples.append(rtt)
                if self.pingSamples.count > 50 { self.pingSamples.removeFirst() }
                let avg = self.pingSamples.reduce(0, +) / Double(max(1, self.pingSamples.count))
                DispatchQueue.main.async {
                    self.healthRef?.updatePing(avg)
                }
            }
        }
        heartbeatTimer?.resume()
    }

    private func stopTimers() {
        sendTimer?.cancel(); sendTimer = nil
        heartbeatTimer?.cancel(); heartbeatTimer = nil
    }

    private func resetPacing() {
        baseTime = CACurrentMediaTime()
        frameCount = 0
    }

    private func handleSocketError(_ error: Error) {
        Logger.shared.warn("WebSocket error: \(error.localizedDescription)")
        healthRef?.recordError()
        
        // 如果是用户主动断连，不要自动重连
        guard !userDisconnected else {
            Logger.shared.debug("User-initiated disconnect, skipping reconnect")
            return
        }
        
        reconnect()
    }

    private func reconnect() {
        stopTimers()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        DispatchQueue.main.async { [weak self] in
            self?.state = .reconnecting
        }
        reconnectAttempts += 1
        healthRef?.recordReconnect()
        let delay = min(pow(2.0, Double(reconnectAttempts - 1)), 16.0)
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, let api = self.config.readAPI() else { return }
            self.startSession(api: api)
        }
    }
    
    // MARK: - Helper Functions
    
    private func isAllSilent(_ data: Data) -> Bool {
        // 检查 PCM16 数据是否全为静音（接近零值）
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            guard let base = ptr.bindMemory(to: Int16.self).baseAddress else { return true }
            let count = data.count / 2
            for i in 0..<count {
                if abs(base[i]) > 50 { // 允许极小的噪声（约 -60dB）
                    return false
                }
            }
            return true
        }
    }
}
