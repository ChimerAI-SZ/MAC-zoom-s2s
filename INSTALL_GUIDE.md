# BabelAI 安装指南

## 下载后的安全提示处理

由于 BabelAI 是独立开发的应用，未经过 Apple 公证，macOS 会显示安全提示。这是正常现象，请按以下方法操作：

### 方法1：系统设置允许（推荐）

1. **下载并解压应用**
   - 下载 DMG 或 ZIP 文件
   - DMG：双击打开，拖动 BabelAI 到 Applications 文件夹
   - ZIP：解压后运行 Install_BabelAI.command 或手动拖到 Applications

2. **首次打开遇到警告**
   - 当看到"Apple无法验证..."的提示时，点击"取消"或"完成"

3. **在系统设置中允许**
   - 打开 **系统设置** → **隐私与安全性**
   - 在"安全性"部分找到提示："'BabelAI'已被阻止..."
   - 点击 **"仍要打开"** 按钮
   - 输入密码确认

4. **再次打开应用**
   - 返回 Applications 文件夹
   - 双击 BabelAI
   - 在弹出的确认对话框中点击"打开"

### 方法2：右键打开（快速方法）

1. **找到应用**
   - 在 Applications 文件夹或下载位置找到 BabelAI

2. **右键打开**
   - **按住 Control 键点击应用**（或右键点击）
   - 选择 **"打开"**
   - 在警告对话框中再次点击 **"打开"**

### 方法3：命令行方法（技术用户）

```bash
# 清除隔离属性
xattr -cr /Applications/BabelAI.app

# 然后正常打开应用
open /Applications/BabelAI.app
```

## 常见问题

### Q: 为什么会有安全警告？
A: BabelAI 是独立开发者制作的免费软件，没有购买 Apple 开发者账号（$99/年）进行公证。这不影响软件的安全性和功能。

### Q: 这样操作安全吗？
A: 是的。BabelAI 是开源软件，代码公开透明，您可以在 GitHub 上查看所有源代码。

### Q: 每次更新都要这样操作吗？
A: 只需要在首次安装时进行此操作。一旦系统信任了应用，后续打开不会再有警告。

### Q: 看到"已损坏"的提示怎么办？
A: 这通常是下载不完整或签名问题导致的：
1. 重新下载文件
2. 使用 ZIP 版本而不是 DMG
3. 运行命令：`xattr -cr ~/Downloads/BabelAI.app`

## 安装成功标志

安装成功后，您将看到：
- BabelAI 图标出现在菜单栏
- 可以正常切换语言和设备
- 点击"开始翻译"功能正常

## 需要帮助？

- GitHub Issues: https://github.com/ChimerAI-SZ/zoom-meeting-tranlater/issues
- 邮件支持: support@babelai.app

---

*注：我们正在申请 Apple 开发者账号，未来版本将提供公证版本，彻底解决安全提示问题。*