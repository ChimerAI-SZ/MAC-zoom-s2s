# Babel AI 安装指南

## 系统要求
- macOS 10.13 或更高版本
- 麦克风访问权限
- 网络连接

## 🚀 快速安装（推荐）

### 1. 下载并打开DMG
下载 `Babel AI-v1.0.0.dmg` 并双击打开

### 2. 运行安装脚本
在打开的DMG窗口中：
1. **双击 `install.command`** 
2. 在终端窗口中按提示操作
3. 脚本会自动：
   - 复制应用到 Applications
   - 修复签名问题
   - 清除安全隔离属性
   - 设置正确的权限

### 3. 首次启动
⚠️ **重要**: 首次启动必须按以下步骤操作：
1. 打开 **应用程序** 文件夹
2. 找到 **Babel AI** 图标
3. **右键点击** Babel AI，选择 **"打开"**
4. 在弹出的对话框中点击 **"打开"** 按钮
5. 允许麦克风权限（如果提示）

## 📖 手动安装（备选）

如果自动安装脚本失败，可尝试手动安装：

### 方法一：手动复制并签名
```bash
# 1. 从DMG复制应用到Applications
cp -R /Volumes/Babel\ AI/BabelAI.app /Applications/

# 2. 重新签名应用（解决签名失效问题）
sudo codesign --force --deep --sign - /Applications/BabelAI.app

# 3. 清除隔离属性
xattr -cr /Applications/BabelAI.app
```

### 方法二：直接从DMG测试运行
在DMG窗口中双击 `test_run.command` 可以无需安装直接运行（仅供测试）

## 🔑 权限设置

### Gatekeeper安全提示
如果macOS提示"无法打开应用，因为无法验证开发者"：
1. **首次必须右键打开**（绕过Gatekeeper）
2. 或在 **系统设置** → **隐私与安全性** 中点击 **"仍要打开"**

### 麦克风权限
应用需要麦克风权限才能正常工作：
1. 首次启动会自动请求权限
2. 如果错过了对话框：
   - 打开 **系统设置** → **隐私与安全性** → **麦克风**
   - 找到 **Babel AI** 并勾选启用
   - 重新启动应用

## 使用说明

### 基本功能
1. **启动翻译**：点击菜单栏图标，选择 **Start**
2. **查看字幕**：选择 **Show Subtitles** 显示实时字幕窗口
3. **停止翻译**：选择 **Stop** 停止翻译

### 语言设置
- 默认：中文 → 英文
- 切换：Settings → Language Direction

### 会议模式
适用于 Zoom、Teams 等在线会议：
1. 首次使用会提示安装 BlackHole 虚拟音频
2. 在会议软件中设置：
   - 麦克风：BlackHole 2ch
   - 扬声器：系统默认
3. 在 Babel AI 中启用 Conference Mode

## 常见问题

### Q: 应用无法启动？
A: 检查系统安全性设置，确保已允许打开此应用

### Q: 没有声音输出？
A: 
- 检查麦克风权限是否已授予
- 确认菜单栏显示运行状态（●）
- 查看 Settings 中的音频设备设置

### Q: 翻译不准确？
A:
- 确保网络连接稳定
- 说话清晰，避免背景噪音
- 适当放慢语速

## 完全卸载

如需完全卸载 Babel AI：
```bash
# 1. 删除应用
rm -rf /Applications/BabelAI.app

# 2. 清理配置文件
rm -rf ~/Library/Preferences/com.babelai.translator.plist
rm -rf ~/.config/babel-ai

# 3. 清理日志
rm -rf ~/Library/Logs/BabelAI

# 4. （可选）卸载 BlackHole
sudo rm -rf /Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver
sudo launchctl kickstart -kp system/com.apple.audio.coreaudiod
```

## 技术支持
- 日志位置：`~/Library/Logs/BabelAI/babel-ai.log`
- 重置设置：Settings → Reset to Defaults

---
Babel AI - 让世界听懂你！