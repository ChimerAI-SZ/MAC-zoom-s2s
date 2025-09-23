import SwiftUI
import AVFoundation

@main
struct BabelAIApp: App {
    @StateObject private var transcript = TranscriptModel()
    @StateObject private var health = HealthMonitor()
    @StateObject private var audio = AudioManager()
    @StateObject private var player = AudioPlayer()
    @StateObject private var prefs = Preferences()
    @StateObject private var ws = TranslationService()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(transcript)
                .environmentObject(health)
                .environmentObject(audio)
                .environmentObject(player)
                .environmentObject(prefs)
                .environmentObject(ws)
                .onAppear {
                    // 应用日志级别
                    switch prefs.logLevel {
                    case .debug: Logger.minLevel = .debug
                    case .info: Logger.minLevel = .info
                    case .error: Logger.minLevel = .error
                    }
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.automatic)

        // 字幕浮窗窗口（可选打开）
        .commands {
            CommandMenu("Babel AI") {
                Button("显示/隐藏字幕窗口 (⌘T)") {
                    NotificationCenter.default.post(name: .toggleSubtitleWindow, object: nil)
                }.keyboardShortcut("t", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let toggleSubtitleWindow = Notification.Name("toggleSubtitleWindow")
}
