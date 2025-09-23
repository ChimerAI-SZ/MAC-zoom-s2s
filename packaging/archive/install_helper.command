#!/bin/bash
# S2S 安装助手
# 此脚本帮助用户正确安装S2S应用并配置权限

clear
echo "======================================"
echo "         S2S 安装助手 v1.0"
echo "======================================"
echo ""

# 切换到脚本所在目录
cd "$(dirname "$0")"

# 检查S2S.app是否存在
if [ ! -d "S2S.app" ]; then
    echo "❌ 错误：找不到S2S.app"
    echo "   请确保install_helper.command与S2S.app在同一目录"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi

echo "▶ 准备安装S2S同声传译系统..."
echo ""

# 1. 清理旧版本
echo "[1/5] 清理旧版本..."
pkill -f S2S 2>/dev/null
tccutil reset Microphone com.s2s.app 2>/dev/null
rm -rf ~/Library/Logs/S2S/ 2>/dev/null
defaults delete com.s2s.app 2>/dev/null || true

# 2. 签名应用（确保权限能正确请求）
echo "[2/5] 配置应用权限..."
codesign --force --deep --sign - S2S.app 2>/dev/null
xattr -cr S2S.app

# 3. 复制到Applications（需要管理员权限）
echo "[3/5] 安装S2S到应用程序文件夹..."
echo "      需要输入系统密码来完成安装"
sudo cp -R S2S.app /Applications/ || {
    echo "❌ 安装失败：无法复制到/Applications"
    echo "   您可以手动将S2S.app拖拽到应用程序文件夹"
    read -p "按回车键退出..."
    exit 1
}

# 4. 设置正确的权限
echo "[4/5] 设置应用权限..."
sudo chmod -R 755 /Applications/S2S.app
sudo xattr -cr /Applications/S2S.app

# 5. 启动应用
echo "[5/5] 启动S2S..."
open /Applications/S2S.app

echo ""
echo "======================================"
echo "✅ 安装完成！"
echo "======================================"
echo ""
echo "📌 重要提示："
echo ""
echo "1. 🎤 首次启动时会请求麦克风权限"
echo "   请在弹出的对话框中点击【允许】"
echo ""
echo "2. 🔧 如果没有弹出权限请求："
echo "   • 打开系统设置 → 隐私与安全性 → 麦克风"
echo "   • 找到S2S并勾选允许"
echo ""
echo "3. 📍 使用方法："
echo "   • 点击菜单栏的S2S图标"
echo "   • 选择Start开始翻译"
echo "   • 支持中译英实时同声传译"
echo ""
echo "======================================"
echo ""
read -p "按回车键关闭此窗口..."