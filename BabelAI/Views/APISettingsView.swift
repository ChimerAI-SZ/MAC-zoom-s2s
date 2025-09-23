import SwiftUI

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appKey: String = ""
    @State private var accessKey: String = ""
    @State private var resourceId: String = "volc.service_type.10053"
    @State private var wsURL: String = "wss://openspeech.bytedance.com/api/v4/ast/v2/translate"
    @State private var notice: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("API 密钥配置").font(.title2).bold()
            if !notice.isEmpty {
                Text(notice).font(.footnote).foregroundColor(.secondary)
            }
            Form {
                TextField("API_APP_KEY", text: $appKey)
                TextField("API_ACCESS_KEY", text: $accessKey)
                TextField("API_RESOURCE_ID", text: $resourceId)
                TextField("WS_URL", text: $wsURL)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") { save() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 320)
        .onAppear { load() }
    }

    private func load() {
        if let cfg = ConfigStore.shared.readAPI() {
            appKey = cfg.appKey
            accessKey = cfg.accessKey
            resourceId = cfg.resourceId
            wsURL = cfg.wsURL
            notice = "已从 Keychain/.env 读取当前配置。保存后将写入 Keychain。"
        } else {
            notice = "未检测到有效配置，请填写。保存后将写入 Keychain。"
        }
    }

    private func save() {
        let cfg = APIConfig(appKey: appKey, accessKey: accessKey, resourceId: resourceId, wsURL: wsURL, sourceLanguage: "zh", targetLanguage: "en")
        ConfigStore.shared.writeAPI(cfg)
        dismiss()
    }
}

