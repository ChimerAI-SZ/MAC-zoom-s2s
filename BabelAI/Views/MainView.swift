import SwiftUI
import AppKit
#if canImport(CoreAudio)
import CoreAudio
#endif
import Combine

struct MainView: View {
    @State private var animateAppear = false
    @EnvironmentObject var transcript: TranscriptModel
    @EnvironmentObject var health: HealthMonitor
    @EnvironmentObject var audio: AudioManager
    @EnvironmentObject var player: AudioPlayer
    @EnvironmentObject var prefs: Preferences
    @EnvironmentObject var ws: TranslationService

    @State private var showingSettings = false
    @State private var showingSubtitle = false
    @State private var subtitleWC: SubtitleWindowController?
    @State private var cancellable: Any?
    @State private var showingHealth = false
    @State private var showingPermissionAlert = false
    @State private var autoStarted = false
    @State private var blackholeAlertShownThisRun = false
    @State private var isToggling = false  // 防止重复点击

    var body: some View {
        VStack(spacing: Design.Spacing.xl) {
            // Header
            VStack(spacing: Design.Spacing.sm) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 26))
                    .foregroundColor(Design.Colors.secondary)
                    .opacity(animateAppear ? 0.8 : 0.3)
                    .animation(Design.Animation.smooth.delay(0.2), value: animateAppear)
                
                Text("Babel AI")
                    .font(Design.Typography.largeTitle)
                    .foregroundColor(Design.Colors.textPrimary)
                
                Text("实时语音翻译系统")
                    .font(Design.Typography.body)
                    .foregroundColor(Design.Colors.textSecondary)
            }
            .opacity(animateAppear ? 1 : 0)
            .offset(y: animateAppear ? 0 : -10)
            .animation(Design.Animation.smooth.delay(0.1), value: animateAppear)
            
            // Main Controls
            VStack(spacing: Design.Spacing.lg) {
                // Primary button
                Button(action: onToggle) {
                    HStack(spacing: Design.Spacing.sm) {
                        Image(systemName: audio.isRunning ? "stop.circle" : "play.circle")
                            .font(.system(size: 18))
                        Text(audio.isRunning ? "停止翻译" : "开始翻译")
                            .font(Design.Typography.headline)
                    }
                }
                .buttonStyle(ModernButton(isPrimary: true))
                .opacity(animateAppear ? 1 : 0)
                .scaleEffect(animateAppear ? 1 : 0.8)
                .animation(Design.Animation.bounce.delay(0.3), value: animateAppear)
                
                // Status indicator
                HStack(spacing: Design.Spacing.sm) {
                    StatusIndicator(
                        isActive: ws.state == .connecting || ws.state == .reconnecting,
                        color: statusColor
                    )
                    Text(statusText)
                        .font(Design.Typography.body)
                        .foregroundColor(Design.Colors.textSecondary)
                }
                .opacity(animateAppear ? 1 : 0)
                .animation(Design.Animation.smooth.delay(0.4), value: animateAppear)
            }
            
            Divider()
                .opacity(0.3)
            
            // Secondary controls
            HStack(spacing: Design.Spacing.lg) {
                Button(action: { showingSettings = true }) {
                    HStack(spacing: Design.Spacing.xs) {
                        Image(systemName: "gearshape")
                        Text("设置")
                    }
                }
                .buttonStyle(ModernButton(isPrimary: false))
                
                Button(action: { showingHealth = true }) {
                    HStack(spacing: Design.Spacing.xs) {
                        Image(systemName: "heart.text.square")
                        Text("健康")
                    }
                }
                .buttonStyle(ModernButton(isPrimary: false))
                
                Button(action: { toggleSubtitle() }) {
                    HStack(spacing: Design.Spacing.xs) {
                        Image(systemName: "captions.bubble")
                        Text("字幕")
                    }
                }
                .buttonStyle(ModernButton(isPrimary: false))
            }
            .opacity(animateAppear ? 1 : 0)
            .animation(Design.Animation.smooth.delay(0.5), value: animateAppear)
            
            // Audio level indicator (dB scale)
            if audio.isRunning {
                HStack(spacing: Design.Spacing.sm) {
                    Image(systemName: "waveform")
                        .foregroundColor(Design.Colors.secondary.opacity(0.6))
                        .font(.system(size: 11))
                    
                    // Visual level bars
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(levelBarColor(index: index, rms: audio.inputLevelRMS))
                                .frame(width: 3, height: CGFloat(8 + index * 2))
                                .opacity(levelBarOpacity(index: index, rms: audio.inputLevelRMS))
                        }
                    }
                    
                    Text(formatDecibels(audio.inputLevelRMS))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Design.Colors.textSecondary)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.horizontal, Design.Spacing.md)
                .padding(.vertical, Design.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Design.Radius.sm)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(Design.Spacing.xxl)
        .frame(minWidth: 480, minHeight: 380)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(prefs)
        }
        .sheet(isPresented: $showingHealth) {
            HealthView().environmentObject(health)
        }
        .alert("需要麦克风权限", isPresented: $showingPermissionAlert) {
            Button("打开设置") { audio.openMicrophoneSettings() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在系统设置 → 隐私与安全性 → 麦克风 中允许 Babel AI 访问麦克风")
        }
        .onAppear {
            // Trigger animations
            withAnimation {
                animateAppear = true
            }
            
            // 注入依赖，保持与全局实例一致
            ws.setDependencies(player: player, health: health, transcript: transcript)
            // 启动即开始（仅第一次出现时）
            if prefs.startOnLaunch && !autoStarted && !audio.isRunning {
                autoStarted = true
                onToggle()
            }
            // 检测 BlackHole 并给出一次性快捷提示（不打断主流程）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                maybeShowBlackHoleHint()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSubtitleWindow)) { _ in
            toggleSubtitle()
        }
        .onReceive(audio.$lastError) { newValue in
            if let msg = newValue {
                let alert = NSAlert()
                alert.messageText = "音频引擎启动失败"
                alert.informativeText = msg
                alert.addButton(withTitle: "确定")
                alert.runModal()
            }
        }
        .onReceive(prefs.$subtitleOpacity) { _ in
            subtitleWC?.apply(opacity: prefs.subtitleOpacity, alwaysOnTop: prefs.alwaysOnTop)
        }
        .onReceive(prefs.$alwaysOnTop) { _ in
            subtitleWC?.apply(opacity: prefs.subtitleOpacity, alwaysOnTop: prefs.alwaysOnTop)
        }
        .onReceive(ws.$state) { newValue in
            if case .error(let msg) = newValue {
                let alert = NSAlert()
                alert.messageText = "配置缺失或无效"
                alert.informativeText = msg + "\n请在 .env 或 Keychain 配置 API_APP_KEY / API_ACCESS_KEY / API_RESOURCE_ID"
                alert.addButton(withTitle: "确定")
                alert.runModal()
            }
        }
    }

    
    private var statusColor: Color {
        switch ws.state {
        case .connected: return Design.Colors.statusConnected
        case .connecting: return Design.Colors.statusConnecting
        case .reconnecting: return Design.Colors.statusConnecting
        case .error: return Design.Colors.statusError
        default: return Design.Colors.statusIdle
        }
    }
    
    private var statusText: String {
        switch ws.state {
        case .connected: return "已连接"
        case .connecting: return "连接中..."
        case .reconnecting: return "重连中..."
        case .error(let msg): return "错误: \(msg)"
        case .idle: return audio.isRunning ? "已就绪" : "未启动"
        }
    }

    private func onToggle() {
        NSLog("[BabelAI UI] Toggle button clicked, isRunning: \(audio.isRunning), isToggling: \(isToggling)")
        
        // 防止重复点击
        guard !isToggling else {
            NSLog("[BabelAI UI] Already toggling, ignoring duplicate click")
            return
        }
        isToggling = true
        
        if audio.isRunning {
            NSLog("[BabelAI UI] Stopping services...")
            (cancellable as? AnyCancellable)?.cancel()
            ws.disconnect()
            player.stop()
            audio.stop()
            AECBridge.shared.deactivate()
            // 延迟重置标志，确保操作完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isToggling = false
                NSLog("[BabelAI UI] Toggle reset after stop")
            }
        } else {
            NSLog("[BabelAI UI] Starting services...")
            audio.requestMicrophonePermission { granted in
                NSLog("[BabelAI UI] Microphone permission: \(granted ? "✓ Granted" : "✗ Denied")")
                guard granted else {
                    showingPermissionAlert = true
                    self.isToggling = false  // 重置标志
                    return
                }
                // 启动链路
                NSLog("[BabelAI UI] Starting audio pipeline...")
                // 在所有模式下启用 AEC 桥（当前实现为安全透传；后续可切换 SpeexDSP 而不改接线）
                NSLog("[BabelAI UI] About to access AECBridge.shared...")
                let aec = AECBridge.shared
                NSLog("[BabelAI UI] Got AECBridge instance, calling setEnabled...")
                aec.setEnabled(true)
                NSLog("[BabelAI UI] Called setEnabled, calling activate...")
                aec.activate()
                NSLog("[BabelAI UI] AEC activated")
                player.start()
                ws.connect()
                audio.start()
                // 将 80ms 帧入队到 WS 发送队列
                let c = audio.chunkPublisher.sink { data in
                    ws.enqueueAudio(data)
                }
                self.cancellable = c
                NSLog("[BabelAI UI] Audio pipeline started")
                // 延迟重置标志，确保操作完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isToggling = false
                    NSLog("[BabelAI UI] Toggle reset after start")
                }
            }
        }
    }

    private func toggleSubtitle() {
        if let w = subtitleWC?.window, w.isVisible {
            w.orderOut(nil)
        } else {
            subtitleWC = SubtitleWindowController(transcript: transcript)
            subtitleWC?.showWindow(nil)
            subtitleWC?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // 应用当前偏好设置
            subtitleWC?.apply(opacity: prefs.subtitleOpacity, alwaysOnTop: prefs.alwaysOnTop)
        }
    }
    
    private func maybeShowBlackHoleHint() {
        guard !blackholeAlertShownThisRun, !prefs.blackholeHintShown else { return }
        if hasBlackHoleDevice() {
            blackholeAlertShownThisRun = true
            // 高级化但简洁的提示
            let alert = NSAlert()
            alert.messageText = "检测到 BlackHole 设备"
            alert.informativeText = "建议启用会议模式：\n1) 在应用内启用会议模式用于同步处理；\n2) 在会议软件中选择 BlackHole 作为“麦克风”；\n3) 在系统声音中选择你的耳机/扬声器作为“输出”。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "启用会议模式")
            alert.addButton(withTitle: "打开声音设置")
            alert.addButton(withTitle: "查看指南")
            alert.addButton(withTitle: "不再提示")
            let resp = alert.runModal()
            switch resp {
            case .alertFirstButtonReturn:
                prefs.meetingMode = true
                prefs.blackholeHintShown = true
            case .alertSecondButtonReturn:
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") { NSWorkspace.shared.open(url) }
                prefs.blackholeHintShown = true
            case .alertThirdButtonReturn:
                openBlackHoleGuide()
                prefs.blackholeHintShown = true
            default:
                prefs.blackholeHintShown = true
            }
        }
    }

    private func openBlackHoleGuide() {
        // 优先打开项目自带文档，其次打开官网
        let fm = FileManager.default
        let bundle = Bundle.main
        if let resURL = bundle.url(forResource: "setup_blackhole", withExtension: "md", subdirectory: "docs") {
            NSWorkspace.shared.open(resURL)
            return
        }
        // 尝试仓库相对路径（开发环境）
        let repoDoc = URL(fileURLWithPath: "../docs/setup_blackhole.md")
        if fm.fileExists(atPath: repoDoc.path) {
            NSWorkspace.shared.open(repoDoc)
            return
        }
        // 打开官网
        if let url = URL(string: "https://existential.audio/blackhole/") {
            NSWorkspace.shared.open(url)
        }
    }

    private func hasBlackHoleDevice() -> Bool {
        // Delegate to AudioEnv which handles the Core Audio APIs
        return AudioEnv.hasBlackHole()
    }
    
    private func alert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        if alert.runModal() == .alertFirstButtonReturn {}
    }
    
    // MARK: - Audio Level Helpers
    
    private func formatDecibels(_ rms: Float) -> String {
        guard rms > 0 else { return "-∞ dB" }
        let db = 20 * log10(rms)
        let clamped = max(-60, min(0, db))
        return String(format: "%.0f dB", clamped)
    }
    
    private func levelBarColor(index: Int, rms: Float) -> Color {
        let db = rms > 0 ? 20 * log10(rms) : -60
        let threshold = -48 + (index * 12) // Thresholds: -48, -36, -24, -12, 0
        return db > Float(threshold) ? Design.Colors.accent : Color.gray.opacity(0.2)
    }
    
    private func levelBarOpacity(index: Int, rms: Float) -> Double {
        let db = rms > 0 ? 20 * log10(rms) : -60
        let threshold = -48 + (index * 12)
        return db > Float(threshold) ? 1.0 : 0.3
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(TranscriptModel())
            .environmentObject(HealthMonitor())
            .environmentObject(AudioManager())
            .environmentObject(Preferences())
            .frame(width: 420, height: 280)
    }
}
