import Foundation
import Combine

final class Preferences: ObservableObject {
    enum LanguageDirection: String, CaseIterable, Identifiable { case zhToEn, enToZh; var id: String { rawValue } }
    enum LogLevel: String, CaseIterable, Identifiable { case info, debug, error; var id: String { rawValue } }

    @Published var startOnLaunch: Bool {
        didSet { UserDefaults.standard.set(startOnLaunch, forKey: Keys.startOnLaunch) }
    }
    @Published var languageDirection: LanguageDirection {
        didSet { UserDefaults.standard.set(languageDirection.rawValue, forKey: Keys.languageDirection) }
    }
    @Published var logLevel: LogLevel {
        didSet { UserDefaults.standard.set(logLevel.rawValue, forKey: Keys.logLevel) }
    }
    @Published var subtitleOpacity: Double {
        didSet { UserDefaults.standard.set(subtitleOpacity, forKey: Keys.subtitleOpacity) }
    }
    @Published var alwaysOnTop: Bool {
        didSet { UserDefaults.standard.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }
    @Published var meetingMode: Bool {
        didSet { UserDefaults.standard.set(meetingMode, forKey: Keys.meetingMode) }
    }

    init() {
        let defaults = UserDefaults.standard
        startOnLaunch = defaults.object(forKey: Keys.startOnLaunch) as? Bool ?? true
        languageDirection = LanguageDirection(rawValue: defaults.string(forKey: Keys.languageDirection) ?? "zhToEn") ?? .zhToEn
        logLevel = LogLevel(rawValue: defaults.string(forKey: Keys.logLevel) ?? "info") ?? .info
        subtitleOpacity = defaults.object(forKey: Keys.subtitleOpacity) as? Double ?? 0.95
        alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? true
        meetingMode = defaults.object(forKey: Keys.meetingMode) as? Bool ?? false
        blackholeHintShown = defaults.object(forKey: Keys.blackholeHintShown) as? Bool ?? false
    }

    private enum Keys {
        static let startOnLaunch = "s2s_start_on_launch"
        static let languageDirection = "s2s_language_direction"
        static let logLevel = "s2s_log_level"
        static let subtitleOpacity = "s2s_subtitle_opacity"
        static let alwaysOnTop = "s2s_always_on_top"
        static let meetingMode = "s2s_meeting_mode"
        static let blackholeHintShown = "s2s_blackhole_hint_shown"
    }

    // 非常驻提示状态（如“会议模式”首次提示）
    @Published var blackholeHintShown: Bool {
        didSet { UserDefaults.standard.set(blackholeHintShown, forKey: Keys.blackholeHintShown) }
    }
}
