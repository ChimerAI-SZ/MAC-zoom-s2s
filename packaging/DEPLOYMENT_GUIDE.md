# BabelAI Swift 版本部署指南

## 概述
本文档描述了 BabelAI Swift 版本的构建、签名和分发流程。由于没有 Apple 开发者账号，我们使用 ad-hoc 签名策略，并提供清晰的用户引导来绕过 Gatekeeper。

## 构建流程

### 1. 构建 Swift App
```bash
cd packaging
./build_swift_release.sh
```
- 使用 xcodebuild 构建 Release 版本
- 采用 ad-hoc 签名 (CODE_SIGN_IDENTITY="-")
- 自动清除扩展属性
- 输出到 `dist/BabelAI.app`

### 2. 创建分发包

#### PKG 安装包（推荐）
```bash
./build_swift_pkg.sh
```
- 包含自动安装脚本
- 安装到 /Applications
- 自动清除隔离属性
- 输出：`dist/BabelAI-1.0.0.pkg`

#### DMG 镜像
```bash
./create_swift_dmg.sh
```
- 拖拽式安装界面
- 包含安装说明文档
- 输出：`dist/BabelAI-1.0.0.dmg`

#### ZIP 压缩包
```bash
./create_swift_zip.sh
```
- 包含一键安装脚本
- 便于手动安装
- 输出：`dist/BabelAI-1.0.0.zip`

## 签名策略

### 无开发者账号的处理方案
1. **Ad-hoc 签名**：使用 `-` 作为签名标识，允许本地运行
2. **禁用硬化运行时**：ENABLE_HARDENED_RUNTIME=NO
3. **清除隔离属性**：xattr -cr 移除下载标记
4. **用户引导**：提供明确的 Gatekeeper 绕过说明

### 用户首次运行指引
用户下载后需要：
1. **方法一**：右键点击应用 → 打开 → 在弹窗中点击"打开"
2. **方法二**：系统设置 → 隐私与安全性 → 仍要打开
3. **方法三**（ZIP包）：双击 Install_BabelAI.command 自动安装

## 部署检查清单

### 构建前
- [ ] 更新版本号（VERSION 文件）
- [ ] 检查 Info.plist 配置
- [ ] 确认 entitlements 设置正确
- [ ] 更新图标（如需要）

### 构建后
- [ ] 测试本地运行（open dist/BabelAI.app）
- [ ] 验证签名（codesign -dv）
- [ ] 检查包大小（应 < 10MB）
- [ ] 测试各种安装方式

### 发布
- [ ] 上传到 website/downloads/
- [ ] 更新网站下载链接
- [ ] 测试下载和安装流程
- [ ] 更新文档和说明

## 文件结构
```
packaging/
├── build_swift_release.sh    # 主构建脚本
├── build_swift_pkg.sh        # PKG 创建脚本
├── create_swift_dmg.sh       # DMG 创建脚本
├── create_swift_zip.sh       # ZIP 创建脚本
├── README_FIRST.txt          # 用户安装说明
└── dist/                     # 输出目录
    ├── BabelAI.app          # 应用程序
    ├── BabelAI-1.0.0.pkg    # PKG 安装包
    ├── BabelAI-1.0.0.dmg    # DMG 镜像
    └── BabelAI-1.0.0.zip    # ZIP 压缩包
```

## 故障排除

### 签名失败
- 确保 Xcode Command Line Tools 已安装
- 检查 entitlements 文件是否存在
- 尝试不带 entitlements 签名

### 用户无法打开
- 确认已提供安装说明
- 检查是否正确清除了隔离属性
- 建议用户使用 PKG 或 DMG 安装

### 构建失败
- 清理派生数据：rm -rf ~/Library/Developer/Xcode/DerivedData
- 检查 Swift 版本兼容性
- 确认所有依赖已安装

## 未来改进
- 申请 Apple 开发者账号进行正式签名和公证
- 实现自动更新机制
- 添加 Sparkle 框架支持
- 考虑 Mac App Store 发布