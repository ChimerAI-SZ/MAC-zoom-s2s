# Babel AI - 实时语音翻译系统

[![Version](https://img.shields.io/badge/version-1.0.0-blue)]()
[![Platform](https://img.shields.io/badge/platform-macOS-green)]()
[![Language](https://img.shields.io/badge/language-Python%203.10%2B-orange)]()

Babel AI 是一个高性能的实时语音翻译系统，支持中英双向语音翻译，适用于会议、学习和日常交流场景。

## ✨ 核心特性

- 🎤 **实时语音识别** - 低延迟的语音捕获和处理
- 🔄 **双向翻译** - 支持中文↔英文实时互译
- 🎯 **高精度** - 基于字节跳动AST API的专业翻译
- 🖥 **macOS菜单栏应用** - 简洁的原生界面
- 🎧 **会议模式** - 支持Zoom等会议软件（通过BlackHole）
- 📊 **健康监控** - 实时监控系统状态

## 🚀 快速开始

### 系统要求
- macOS 11.0+
- Python 3.10+
- 麦克风权限

### 安装方法

#### 方法一：DMG 安装包（推荐）
1. 下载 `BabelAI-Installer.dmg`
2. 双击打开并运行"安装 Babel AI.command"
3. 按提示完成安装

#### 方法二：源码运行
```bash
# 1. 克隆项目
git clone <repository-url>
cd s2s

# 2. 安装依赖
pip install -r requirements.txt

# 3. 配置API密钥（创建 .env 文件）
API_APP_KEY=your_app_key
API_ACCESS_KEY=your_access_key
API_RESOURCE_ID=volc.service_type.10053

# 4. 运行应用
python app_menu.py
```

## 📁 项目结构

```
.
├── app_menu.py           # 主应用程序（菜单栏UI）
├── realtime_simple.py    # 实时翻译引擎
├── config.py            # 配置管理
├── logger.py            # 日志系统
├── preferences.py       # 用户偏好设置
├── requirements.txt     # Python依赖
│
├── docs/               # 文档目录
│   ├── guides/        # 用户指南
│   │   ├── 安装指南.md
│   │   ├── 用户手册.md
│   │   └── BlackHole设置.md
│   └── development/   # 开发文档
│       └── CHANGELOG.md
│
├── packaging/         # 打包相关
│   ├── build_app.sh  # 构建应用脚本
│   ├── build_dmg.sh  # 构建DMG脚本
│   └── dist/         # 构建输出
│
├── tests/            # 测试文件
│   └── test_*.py
│
├── resources/        # 资源文件
│   └── BlackHole2ch.pkg
│
├── website/          # 官网源码
│
└── archive/          # 归档文件
    ├── old_branding/ # 旧品牌资源
    ├── reports/      # 测试报告
    └── legacy_docs/  # 旧文档
```

## 🎮 使用说明

### 基本操作
1. **启动应用**: 点击菜单栏的 Babel AI 图标
2. **开始翻译**: 选择 Start 开始实时翻译
3. **查看字幕**: 自动显示原文和译文窗口
4. **停止翻译**: 选择 Stop 结束翻译

### 高级功能
- **设备选择**: Preferences → Audio 选择输入/输出设备
- **会议模式**: 需要先安装 BlackHole（详见 [BlackHole设置指南](docs/guides/BlackHole设置.md)）
- **日志级别**: Preferences → Debug 调整日志详细程度

## 📖 详细文档

- [安装指南](docs/guides/安装指南.md) - 详细的安装和配置说明
- [用户手册](docs/guides/用户手册.md) - 完整的功能介绍
- [BlackHole设置](docs/guides/BlackHole设置.md) - 会议模式配置
- [更新日志](docs/development/CHANGELOG.md) - 版本历史

## 🛠 开发相关

### 构建应用
```bash
# 构建 .app 文件
cd packaging
bash build_app.sh

# 构建 DMG 安装包
bash build_dmg.sh
```

### 运行测试
```bash
# 运行所有测试
python -m pytest tests/

# 运行特定测试
python tests/test_robustness.py
```

## ⚠️ 注意事项

1. **首次运行**: 需要授予麦克风权限
2. **会议模式**: 需要先安装 BlackHole 虚拟音频设备
3. **API密钥**: 需要有效的字节跳动 AST API 密钥

## 🤝 贡献指南

请参阅 [CLAUDE.md](CLAUDE.md) 了解开发规范和贡献流程。

## 📄 许可证

本项目采用专有许可证。详见项目根目录的许可文件。

## 🔗 相关链接

- [官方网站](website/)
- [问题反馈](https://github.com/your-repo/issues)
- [API文档](https://www.volcengine.com/)

---

**Babel AI** - 打破语言障碍，连接世界对话