import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var prefs: Preferences
    
    @State private var showSubtitleOnStart = true
    @State private var animateAppear = false
    @State private var showMeetingWizard = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background overlay for dismissing
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Content card
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: Design.Spacing.xl) {
                        // Header
                        HStack {
                            Image(systemName: "gearshape.2")
                                .font(.system(size: 24))
                                .foregroundColor(Design.Colors.primary)
                                .rotationEffect(.degrees(animateAppear ? 0 : -90))
                                .animation(Design.Animation.bounce.delay(0.1), value: animateAppear)
                            
                            Text("设置")
                                .font(Design.Typography.largeTitle)
                                .foregroundColor(Design.Colors.textPrimary)
                            
                            Spacer()
                        }
                        .padding(.bottom, Design.Spacing.md)
                        
                        // Translation Settings
                        SettingsGroup(title: "翻译设置", icon: "globe") {
                            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                                Text("翻译方向")
                                    .font(Design.Typography.caption)
                                    .foregroundColor(Design.Colors.textSecondary)
                                
                                Picker("", selection: $prefs.languageDirection) {
                                    HStack {
                                        Image(systemName: "flag.fill")
                                        Text("中文 → 英文")
                                    }.tag(Preferences.LanguageDirection.zhToEn)
                                    
                                    HStack {
                                        Image(systemName: "flag.fill")
                                        Text("英文 → 中文")
                                    }.tag(Preferences.LanguageDirection.enToZh)
                                }
                                .pickerStyle(.radioGroup)
                            }
                        }
                        .opacity(animateAppear ? 1 : 0)
                        .offset(y: animateAppear ? 0 : 20)
                        .animation(Design.Animation.smooth.delay(0.2), value: animateAppear)
                        
                        // Display Settings
                        SettingsGroup(title: "显示设置", icon: "display") {
                            VStack(spacing: Design.Spacing.lg) {
                                Toggle("启动时自动开始翻译", isOn: $prefs.startOnLaunch)
                                    .toggleStyle(ModernToggleStyle())
                                
                                Toggle("显示字幕窗口", isOn: $showSubtitleOnStart)
                                    .toggleStyle(ModernToggleStyle())
                                
                                Toggle("字幕窗口置顶", isOn: $prefs.alwaysOnTop)
                                    .toggleStyle(ModernToggleStyle())
                                
                                VStack(alignment: .leading, spacing: Design.Spacing.sm) {
                                    HStack {
                                        Text("字幕透明度")
                                            .font(Design.Typography.body)
                                        Spacer()
                                        Text(String(format: "%.0f%%", prefs.subtitleOpacity * 100))
                                            .font(Design.Typography.caption)
                                            .foregroundColor(Design.Colors.primary)
                                            .frame(width: 50, alignment: .trailing)
                                    }
                                    
                                    Slider(value: $prefs.subtitleOpacity, in: 0.4...1.0)
                                        .accentColor(Design.Colors.primary)
                                }
                            }
                        }
                        .opacity(animateAppear ? 1 : 0)
                        .offset(y: animateAppear ? 0 : 20)
                        .animation(Design.Animation.smooth.delay(0.3), value: animateAppear)
                        
                                // Debug Settings
                        SettingsGroup(title: "调试设置", icon: "ladybug") {
                            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                                Text("日志级别")
                                    .font(Design.Typography.caption)
                                    .foregroundColor(Design.Colors.textSecondary)
                                
                                Picker("", selection: $prefs.logLevel) {
                                    Text("INFO").tag(Preferences.LogLevel.info)
                                    Text("DEBUG").tag(Preferences.LogLevel.debug)
                                    Text("ERROR").tag(Preferences.LogLevel.error)
                                }
                                .pickerStyle(.segmented)
                            }
                                }
                        .opacity(animateAppear ? 1 : 0)
                        .offset(y: animateAppear ? 0 : 20)
                        .animation(Design.Animation.smooth.delay(0.4), value: animateAppear)
                        
                                // Meeting Mode
                        SettingsGroup(title: "会议模式", icon: "person.3") {
                            VStack(spacing: Design.Spacing.md) {
                                Toggle("启用会议模式（输出到 BlackHole）", isOn: $prefs.meetingMode)
                                    .toggleStyle(ModernToggleStyle())
                                
                                HStack(alignment: .top) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(Design.Colors.primary.opacity(0.7))
                                    
                                    Text("我们不会修改系统音频设备。启用后，请在会议软件选择 BlackHole 作为麦克风，在系统声音输出选择耳机/扬声器。")
                                        .font(Design.Typography.footnote)
                                        .foregroundColor(Design.Colors.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                HStack {
                                    Button("会议模式向导…") { showMeetingWizard = true }
                                    Spacer()
                                    Text(AudioEnv.defaultOutputDeviceName() ?? "")
                                        .font(Design.Typography.footnote)
                                        .foregroundColor(Design.Colors.textSecondary)
                                }
                            }
                        }
                        .opacity(animateAppear ? 1 : 0)
                        .offset(y: animateAppear ? 0 : 20)
                        .animation(Design.Animation.smooth.delay(0.5), value: animateAppear)
                        
                        // Close button
                                HStack {
                            Spacer()
                            Button("关闭") {
                                dismiss()
                            }
                            .buttonStyle(ModernButton(isPrimary: true))
                        }
                        .padding(.top, Design.Spacing.md)
                        .opacity(animateAppear ? 1 : 0)
                        .animation(Design.Animation.smooth.delay(0.6), value: animateAppear)
                    }
                    .padding(Design.Spacing.xxl)
                }
            }
            .frame(maxWidth: 600, maxHeight: 520)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(Design.Radius.md)
            .shadow(color: Color.black.opacity(0.1), radius: 10)
            .padding(40)
        }
        .frame(minWidth: 700, minHeight: 600)
        .background(Color.clear)
        .onAppear {
            showSubtitleOnStart = true
            withAnimation {
                animateAppear = true
            }
        }
        .sheet(isPresented: $showMeetingWizard) { MeetingModeWizardView() }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(Preferences())
    }
}
