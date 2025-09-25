#!/bin/bash
# BabelAI Smart Installer with Security Guide
# This script helps users install BabelAI and handle macOS security warnings

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Clear screen for better presentation
clear

echo -e "${BLUE}${BOLD}"
echo "╔════════════════════════════════════════╗"
echo "║       BabelAI 智能安装助手 v1.0.5      ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME="BabelAI.app"
APP_PATH="$SCRIPT_DIR/$APP_NAME"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ 错误: 未找到 BabelAI.app${NC}"
    echo "请确保此脚本与 BabelAI.app 在同一目录"
    exit 1
fi

echo -e "${GREEN}✅ 检测到 BabelAI.app${NC}"
echo ""

# Step 1: Copy to Applications
echo -e "${YELLOW}📦 步骤 1: 安装应用到 Applications 文件夹${NC}"
echo -e "   正在复制应用..."

if [ -d "/Applications/$APP_NAME" ]; then
    echo -e "${YELLOW}   发现已存在的版本，是否替换? (y/n)${NC}"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "/Applications/$APP_NAME"
    else
        echo -e "${YELLOW}   跳过安装${NC}"
        APP_INSTALLED=false
    fi
fi

if [ "$APP_INSTALLED" != "false" ]; then
    cp -R "$APP_PATH" /Applications/ 2>/dev/null || {
        echo -e "${YELLOW}   需要管理员权限...${NC}"
        sudo cp -R "$APP_PATH" /Applications/
    }
    echo -e "${GREEN}   ✅ 应用已安装到 /Applications${NC}"
fi

# Step 2: Remove quarantine
echo ""
echo -e "${YELLOW}🔓 步骤 2: 清除安全隔离属性${NC}"
echo -e "   正在处理..."

xattr -cr "/Applications/$APP_NAME" 2>/dev/null || {
    echo -e "${YELLOW}   需要管理员权限...${NC}"
    sudo xattr -cr "/Applications/$APP_NAME" 2>/dev/null || true
}
echo -e "${GREEN}   ✅ 安全属性已清除${NC}"

# Step 3: Instructions
echo ""
echo -e "${BLUE}${BOLD}════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}🎉 安装完成！${NC}"
echo -e "${BLUE}${BOLD}════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}${BOLD}⚠️  首次打开 BabelAI 的重要说明：${NC}"
echo ""
echo -e "${BOLD}如果看到 \"Apple无法验证\" 的安全提示：${NC}"
echo ""
echo -e "${GREEN}方法 1: 系统设置（推荐）${NC}"
echo "  1. 点击对话框中的 \"取消\" 或 \"完成\""
echo "  2. 打开 系统设置 → 隐私与安全性"
echo "  3. 找到 \"BabelAI已被阻止\" 的提示"
echo "  4. 点击 \"仍要打开\" 按钮"
echo "  5. 再次打开 BabelAI"
echo ""
echo -e "${GREEN}方法 2: 右键打开${NC}"
echo "  1. 在 Applications 文件夹找到 BabelAI"
echo "  2. 按住 Control 键点击（或右键点击）"
echo "  3. 选择 \"打开\""
echo "  4. 在对话框中点击 \"打开\""
echo ""

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Ask if user wants to open the app now
echo -e "${YELLOW}是否现在打开 BabelAI？(y/n)${NC}"
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}正在打开 BabelAI...${NC}"
    open "/Applications/$APP_NAME" 2>/dev/null || {
        echo ""
        echo -e "${YELLOW}${BOLD}看到安全提示了吗？${NC}"
        echo -e "请按照上述说明操作，这是正常现象。"
        echo ""
        echo -e "${BLUE}打开系统设置的快捷方式：${NC}"
        echo "  按 Command+空格，输入 \"隐私与安全性\""
    }
else
    echo -e "${GREEN}您可以稍后在 Applications 文件夹中找到 BabelAI${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${GREEN}感谢使用 BabelAI！${NC}"
echo -e "${BLUE}如需帮助: https://github.com/ChimerAI-SZ/zoom-meeting-tranlater${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""
echo "按 Enter 键退出..."
read