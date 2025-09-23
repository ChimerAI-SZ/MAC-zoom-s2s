import Foundation
import os.log

final class Logger {
    static let shared = Logger()
    private let log = OSLog(subsystem: "com.babelai.translator", category: "app")
    
    enum Level: Int { case debug = 0, info = 1, warn = 2, error = 3 }
    static var minLevel: Level = .info

    func info(_ message: String) {
        guard Logger.minLevel.rawValue <= Level.info.rawValue else { return }
        let msg = redact(message)
        // 避免 os_log 在某些系统上触发 NSXPCDecoder 警告，统一使用 NSLog/print
        NSLog("[INFO] \(msg)")
        print("[INFO] \(msg)")
    }

    func debug(_ message: String) {
        guard Logger.minLevel.rawValue <= Level.debug.rawValue else { return }
        let msg = redact(message)
        NSLog("[DEBUG] \(msg)")
        print("[DEBUG] \(msg)")
    }

    func warn(_ message: String) {
        guard Logger.minLevel.rawValue <= Level.warn.rawValue else { return }
        let msg = redact(message)
        NSLog("[WARN] \(msg)")
        print("[WARN] \(msg)")
    }

    func error(_ message: String) {
        guard Logger.minLevel.rawValue <= Level.error.rawValue else { return }
        let msg = redact(message)
        NSLog("[ERROR] \(msg)")
        print("[ERROR] \(msg)")
    }

    private func redact(_ message: String) -> String {
        let patterns = [
            "API_APP_KEY\\s*[:=]\\s*([^\\s,;]+)",
            "API_ACCESS_KEY\\s*[:=]\\s*([^\\s,;]+)",
            "X-Api-(App|Access|Resource)-Key\\s*[:=]\\s*([^\\s,;]+)"
        ]
        var redacted = message
        for p in patterns {
            if let regex = try? NSRegularExpression(pattern: p, options: .caseInsensitive) {
                redacted = regex.stringByReplacingMatches(in: redacted, options: [], range: NSRange(location: 0, length: redacted.utf16.count), withTemplate: "<REDACTED>")
            }
        }
        return redacted
    }
}
