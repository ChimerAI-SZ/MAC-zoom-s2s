import SwiftUI
import AppKit

struct MeetingModeWizardView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 1
    @State private var hasBlackHole: Bool = AudioEnv.hasBlackHole()
    @State private var outputName: String = AudioEnv.defaultOutputDeviceName() ?? ""
    @State private var showTips: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("会议模式向导").font(.title2).bold()
            GroupBox("步骤 \(step)/3") {
                VStack(alignment: .leading, spacing: 10) {
                    if step == 1 { stepDetectBlackHole }
                    if step == 2 { stepSystemOutput }
                    if step == 3 { stepAppConfig }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("上一步", action: prev).disabled(step == 1)
                Spacer()
                Button("下一步", action: next).disabled(nextDisabled)
                Button("完成") { dismiss() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 360)
        .onAppear { refresh() }
    }

    private var stepDetectBlackHole: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hasBlackHole ? "✅ 已检测到 BlackHole" : "⚠️ 未检测到 BlackHole")
            if !hasBlackHole {
                Text("请安装 BlackHole（虚拟音频设备），用于将应用音频送入会议软件。")
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Button("打开官网下载") { openURL("https://existential.audio/blackhole/") }
                    Button("打开 Audio MIDI 设置") { openApp("/System/Applications/Utilities/Audio MIDI Setup.app") }
                }
            } else {
                Text("你可以继续到下一步，配置系统输出设备。").foregroundColor(.secondary)
            }
            Button("重新检测") { refresh() }
        }
    }

    private var stepSystemOutput: some View {
        VStack(alignment: .leading, spacing: 8) {
            let onBlackHole = (outputName.localizedCaseInsensitiveContains("BlackHole") || outputName.localizedCaseInsensitiveContains("Multi"))
            Text(onBlackHole ? "✅ 系统输出：\(outputName)" : "⚠️ 系统输出：\(outputName.isEmpty ? "未知" : outputName)")
            Text("建议将系统输出临时设为 BlackHole（或包含 BlackHole 的聚合设备），或者使用 Audio MIDI 设置创建 Multi-Output 以同时听到本地声音。")
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Button("打开声音设置") { openURL("x-apple.systempreferences:com.apple.preference.sound") }
                Button("打开 Audio MIDI 设置") { openApp("/System/Applications/Utilities/Audio MIDI Setup.app") }
                Button("刷新状态") { refresh() }
            }
        }
    }

    private var stepAppConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("在会议软件中：")
            Text("1) 将“麦克风”选择为 BlackHole").foregroundColor(.secondary)
            Text("2) 将“扬声器/输出”选择为你的耳机或扬声器").foregroundColor(.secondary)
            Divider()
            Text("提示：点击下方播放系统提示音，确认能从你期望的输出设备听到声音。")
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                Button("播放系统提示音") { NSSound.beep() }
                Button("打开声音设置") { openURL("x-apple.systempreferences:com.apple.preference.sound") }
            }
        }
    }

    private var nextDisabled: Bool {
        if step == 1 { return !hasBlackHole }
        return false
    }

    private func prev() { if step > 1 { step -= 1 } }
    private func next() { if step < 3 { step += 1 } }
    private func refresh() {
        hasBlackHole = AudioEnv.hasBlackHole()
        outputName = AudioEnv.defaultOutputDeviceName() ?? ""
    }

    private func openURL(_ s: String) {
        if let url = URL(string: s) { NSWorkspace.shared.open(url) }
    }
    private func openApp(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}

