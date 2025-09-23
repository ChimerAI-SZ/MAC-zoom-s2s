#!/bin/bash
# Babel AI 终端启动器 - 用于首次启动时请求权限

clear
echo "======================================="
echo "     Babel AI 权限配置助手"
echo "======================================="
echo ""
echo "从终端启动Babel AI可以更可靠地触发麦克风权限请求。"
echo ""
echo "即将启动Babel AI..."
echo "如果看到权限对话框，请点击【允许】"
echo ""
echo "准备中..."
sleep 2

# 检查Babel AI是否已安装
if [ ! -d "/Applications/BabelAI.app" ]; then
    echo "❌ 错误：Babel AI未安装"
    echo "请先运行安装脚本"
    read -p "按回车键退出..."
    exit 1
fi

# 从终端启动Babel AI（保持前台运行以确保权限对话框显示）
echo "启动Babel AI..."
/Applications/BabelAI.app/Contents/MacOS/Babel AI &

# 等待几秒让权限对话框显示
sleep 5

echo ""
echo "======================================="
echo "如果您："
echo ""
echo "✅ 看到了权限对话框并点击了【允许】"
echo "   太好了！Babel AI现在可以正常使用了。"
echo ""
echo "❌ 没有看到权限对话框"
echo "   请手动设置："
echo "   1. 打开系统设置"
echo "   2. 选择【隐私与安全性】→【麦克风】"
echo "   3. 找到Babel AI并勾选"
echo ""
echo "======================================="
echo ""
read -p "按回车键关闭此窗口..."