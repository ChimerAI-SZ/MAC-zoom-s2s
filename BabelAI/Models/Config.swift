import Foundation
import Security

struct APIConfig {
    var appKey: String
    var accessKey: String
    var resourceId: String
    var wsURL: String
    var sourceLanguage: String
    var targetLanguage: String
}

enum KeychainError: Error { case unexpectedStatus(OSStatus) }

final class ConfigStore {
    static let shared = ConfigStore()
    private let service = "BabelAI"
    private var envCache: [String: String]?

    func readAPI() -> APIConfig? {
        // Try to read from .env file first, then fallback to Keychain
        loadEnvFile()
        
        NSLog("[BabelAI Config] readAPI: envCache has \(envCache?.count ?? 0) entries")
        
        // Try .env first, then Keychain
        let appKey = envCache?["API_APP_KEY"] ?? (try? read(key: "API_APP_KEY"))
        let accessKey = envCache?["API_ACCESS_KEY"] ?? (try? read(key: "API_ACCESS_KEY"))
        
        NSLog("[BabelAI Config] API Keys - AppKey: \(appKey != nil ? "✓ Found" : "✗ Missing"), AccessKey: \(accessKey != nil ? "✓ Found" : "✗ Missing")")
        
        guard let finalAppKey = appKey,
              let finalAccessKey = accessKey else { 
            NSLog("[BabelAI Config] ⚠️ ERROR: Missing API credentials!")
            return nil 
        }
        
        let resourceId = envCache?["API_RESOURCE_ID"] ?? (try? read(key: "API_RESOURCE_ID")) ?? "volc.service_type.10053"
        let wsURL = envCache?["WS_URL"] ?? (try? read(key: "WS_URL")) ?? "wss://openspeech.bytedance.com/api/v4/ast/v2/translate"
        let sourceLanguage = envCache?["SOURCE_LANGUAGE"] ?? "zh"
        let targetLanguage = envCache?["TARGET_LANGUAGE"] ?? "en"
        
        NSLog("[BabelAI Config] ✅ API Config created - URL: \(wsURL), Languages: \(sourceLanguage) -> \(targetLanguage)")
        
        return APIConfig(
            appKey: finalAppKey,
            accessKey: finalAccessKey,
            resourceId: resourceId,
            wsURL: wsURL,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }
    
    private func loadEnvFile() {
        guard envCache == nil else { return }
        // 1) 优先从 App Bundle 的 app_secrets.json 读取（发行版）
        if let url = Bundle.main.url(forResource: "app_secrets", withExtension: "json"),
           let dict = try? loadJSON(url), dict.values.contains(where: { !$0.isEmpty }) {
            envCache = dict
            Logger.shared.info("Loaded API config from app bundle app_secrets.json")
            return
        }
        // 2) 开发环境：兼容 .env（本地调试使用），不在发行版暴露 UI 输入
        let alternativePaths = [
            Bundle.main.path(forResource: ".env", ofType: nil) ?? "",
            (NSHomeDirectory() as NSString).appendingPathComponent(".env"),
            "/Users/zoharhuang/Desktop/DEEP LEARNING/Coding learning/s2s/.env",
            "/Users/zoharhuang/Desktop/DEEP LEARNING/Coding learning/s2s/BabelAI/.env",
            (NSHomeDirectory() as NSString).appendingPathComponent("Desktop/DEEP LEARNING/Coding learning/s2s/.env")
        ]
        for path in alternativePaths where !path.isEmpty {
            if loadEnvFromPath(path) { Logger.shared.info("Loaded .env from: \(path)"); return }
        }
        // 3) 最后从 Keychain 读取（若已存过）
        Logger.shared.warn("No bundled app_secrets.json or .env found; will rely on Keychain if available")
    }

    private func loadJSON(_ url: URL) throws -> [String: String] {
        let data = try Data(contentsOf: url)
        if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var out: [String: String] = [:]
            for (k, v) in dict { if let s = v as? String { out[k] = s } }
            return out
        }
        return [:]
    }
    
    private func loadEnvFromPath(_ path: String) -> Bool {
        guard let contents = try? String(contentsOfFile: path) else { return false }
        
        var env = [String: String]()
        contents.split(separator: "\n").forEach { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { return }
            
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { return }
            
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            env[key] = value
        }
        
        if !env.isEmpty {
            envCache = env
            return true
        }
        return false
    }

    func writeAPI(_ cfg: APIConfig) {
        try? write(key: "API_APP_KEY", value: cfg.appKey)
        try? write(key: "API_ACCESS_KEY", value: cfg.accessKey)
        try? write(key: "API_RESOURCE_ID", value: cfg.resourceId)
        try? write(key: "WS_URL", value: cfg.wsURL)
    }

    private func read(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedStatus(status)
        }
        return str
    }

    private func write(key: String, value: String) throws {
        let data = value.data(using: .utf8) ?? Data()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }
}
