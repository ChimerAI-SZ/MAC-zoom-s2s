# 实时中英语音翻译系统

一个基于 ByteDance AST API 的实时语音翻译系统，支持中文语音到英文语音的实时转换。

## 特性

- 🎤 **实时翻译**：中文语音实时翻译为英文语音
- 🔊 **高质量音频**：使用 PCM 格式，避免解码失真
- ⚡ **低延迟**：1.5-2 秒内完成翻译
- 🔄 **自动重连**：网络断开时自动重连
- 📝 **同步字幕**：显示原文和译文

## 快速开始

### 1. 克隆仓库

```bash
git clone <repository-url>
cd s2s
```

### 2. 配置 API

复制配置文件模板：
```bash
cp .env.example .env
```

编辑 `.env` 文件，填入您的 ByteDance API 凭证：
```
API_APP_KEY=your_actual_app_key
API_ACCESS_KEY=your_actual_access_key
API_RESOURCE_ID=your_actual_resource_id
```

> 💡 从 [ByteDance 控制台](https://console.volcengine.com/) 获取 API 凭证

### 3. 运行程序

```bash
python start.py
```

程序会自动：
- 检查 Python 版本（需要 3.8+）
- 验证 API 配置
- 安装依赖包
- 检测音频设备
- 启动翻译系统

## 系统要求

- **Python**: 3.8 或更高版本
- **操作系统**: macOS / Linux / Windows
- **硬件**: 麦克风和扬声器
- **网络**: 稳定的互联网连接

## 手动安装

如果 `start.py` 无法运行，可以手动安装：

```bash
# 1. 安装依赖
pip install -r requirements.txt

# 2. 配置 API（见上文）

# 3. 直接运行
python realtime_simple.py
```

## 文件说明

```
s2s/
├── realtime_simple.py   # 主程序
├── config.py           # 配置加载器
├── start.py           # 一键启动脚本
├── .env.example       # 配置文件模板
├── requirements.txt   # Python 依赖
└── ast_python/       # ByteDance API Protobuf 定义
```

## 使用说明

1. **启动程序**后，系统会自动开始监听麦克风
2. **说中文**，系统会实时翻译成英文语音
3. **翻译结果**会从扬声器播放，同时显示原文和译文
4. 按 **Ctrl+C** 退出程序

## 常见问题

### Q: 提示找不到麦克风？
A: 请确保麦克风已连接并在系统设置中授予权限。

### Q: 音频有杂音或延迟？
A: 
- 确保网络连接稳定
- 检查 CPU 使用率是否过高
- 尝试关闭其他占用音频的程序

### Q: API 连接失败？
A: 
- 检查 `.env` 文件中的凭证是否正确
- 确认 API 服务可用且有足够配额
- 检查防火墙是否阻止 WebSocket 连接

### Q: Windows 用户无法运行？
A: 确保使用 PowerShell 或 CMD，不要使用 Git Bash。

## 技术栈

- **API**: ByteDance AST v2 (Automatic Speech Translation)
- **协议**: WebSocket + Protobuf
- **音频**: PCM 16kHz 输入，PCM 48kHz 输出
- **Python包**: sounddevice, websockets, numpy

## 许可证

本项目仅供学习和研究使用。使用 ByteDance API 需遵守其服务条款。

## 支持

遇到问题？请提交 Issue 或查看上述常见问题。