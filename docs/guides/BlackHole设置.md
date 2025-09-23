# BlackHole 配置指南 - 用于Zoom会议实时翻译

## ⚠️ 重要说明

**macOS限制**：afplay和ffplay都无法直接指定输出设备。必须通过系统设置来路由音频。

## 1. 安装 BlackHole

```bash
# 使用 Homebrew 安装
brew install blackhole-2ch

# 或从官网下载
# https://existential.audio/blackhole/
```

## 2. 配置音频路由（必须）

### 最简单方法（推荐）

1. **系统设置** → **声音** → **输出**
2. 选择 **"BlackHole 2ch"** 作为输出设备
3. 这样所有音频都会发送到BlackHole（你将听不到声音）
4. 使用耳机监听原始麦克风

### 高级方法：创建聚合设备（可同时听到）

1. 打开"音频MIDI设置"（Audio MIDI Setup）
2. 点击左下角"+"，选择"创建多输出设备"
3. 勾选：
   - BlackHole 2ch（用于Zoom输入）
   - 内建扬声器（用于自己听）
4. 将此多输出设备设为系统默认输出

## 3. Zoom 设置

1. 打开Zoom设置 → 音频
2. 麦克风：选择"BlackHole 2ch"
3. 扬声器：选择你的耳机或扬声器
4. 关闭"自动调节麦克风音量"

## 4. 使用流程

```bash
# 1. 启动翻译系统
python test_opus_file.py

# 系统会自动检测并使用BlackHole
# 看到：✅ 发现BlackHole设备: BlackHole 2ch

# 2. 加入Zoom会议
# 确保麦克风选择了BlackHole

# 3. 开始说中文
# 翻译的英文会通过BlackHole传到Zoom
```

## 5. 测试检查

### 测试BlackHole是否工作
```bash
# 播放测试音频到BlackHole
ffplay -f lavfi -i "sine=frequency=1000:duration=5" -audio_device "BlackHole 2ch"

# 同时在另一个终端录制
ffmpeg -f avfoundation -i ":BlackHole 2ch" -t 5 test.wav
```

### 检查Zoom是否接收音频
1. 在Zoom会议中点击"测试扬声器和麦克风"
2. 运行翻译程序，说几句中文
3. 应该能看到麦克风音量条有反应

## 6. 常见问题

### Q: Zoom听不到翻译的声音
A: 检查：
- Zoom麦克风是否选择了BlackHole
- 翻译程序是否显示"输出设备: BlackHole 2ch"
- 尝试重启Zoom

### Q: 自己听不到翻译结果
A: 使用多输出设备，或者戴耳机听原始麦克风

### Q: 有回声或反馈
A: 确保：
- 使用耳机而非扬声器
- Zoom中关闭"自动调节麦克风音量"
- 关闭Zoom的回声消除

## 7. 优化建议

- **延迟**：当前延迟约1.5-2秒，适合会议使用
- **音质**：BlackHole支持高质量音频传输
- **稳定性**：建议会议前先测试5分钟

## 8. 完整工作流程

```
麦克风(中文) → 翻译系统 → BlackHole → Zoom → 其他参会者听到英文
     ↓
   耳机(可选：听自己说话)
```