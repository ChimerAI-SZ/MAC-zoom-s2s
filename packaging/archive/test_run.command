#!/bin/bash

# Babel AI 测试运行脚本
# 无需安装，直接从DMG运行

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_PATH="${SCRIPT_DIR}/BabelAI.app"

clear
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   Babel AI 测试运行${NC}"
echo -e "${BLUE}================================${NC}\n"

if [ ! -d "${APP_PATH}" ]; then
    echo "错误: 未找到 BabelAI.app"
    exit 1
fi

echo -e "${GREEN}准备运行 Babel AI（无需安装）...${NC}\n"
echo -e "${YELLOW}注意: 这是测试模式，某些功能可能受限${NC}"
echo -e "${YELLOW}如需完整功能，请使用 install.command 安装${NC}\n"

# 临时签名应用（仅本次运行）
echo "正在准备应用..."
codesign --force --deep --sign - "${APP_PATH}" 2>/dev/null
xattr -cr "${APP_PATH}"

echo -e "\n${GREEN}启动 Babel AI...${NC}"
open "${APP_PATH}"

echo -e "\n${GREEN}应用已启动！${NC}"
echo -e "请查看菜单栏的巴别塔图标"
echo -e "\n按 Enter 键关闭此窗口..."
read