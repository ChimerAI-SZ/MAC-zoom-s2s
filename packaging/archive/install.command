#!/bin/bash

# Babel AI 智能安装脚本
# 解决签名和权限问题，确保应用正常运行

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取脚本所在目录（DMG挂载点）
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME="BabelAI.app"
APP_SOURCE="${SCRIPT_DIR}/${APP_NAME}"
APP_DEST="/Applications/${APP_NAME}"

clear
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   Babel AI 安装向导${NC}"
echo -e "${BLUE}================================${NC}\n"

# 1. 检查应用是否存在于DMG中
if [ ! -d "${APP_SOURCE}" ]; then
    echo -e "${RED}错误: 在DMG中未找到 ${APP_NAME}${NC}"
    echo "请确保您正确挂载了DMG镜像"
    exit 1
fi

# 2. 检查是否已安装
if [ -d "${APP_DEST}" ]; then
    echo -e "${YELLOW}检测到已安装的Babel AI${NC}"
    read -p "是否要覆盖现有安装？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}安装已取消${NC}"
        exit 0
    fi
    echo -e "${YELLOW}删除旧版本...${NC}"
    rm -rf "${APP_DEST}"
fi

# 3. 复制应用到Applications
echo -e "${GREEN}[1/5] 正在安装应用...${NC}"
cp -R "${APP_SOURCE}" "${APP_DEST}"

# 4. 修复签名问题
echo -e "${GREEN}[2/5] 修复应用签名...${NC}"

# 移除现有的无效签名
echo "  移除旧签名..."
codesign --remove-signature "${APP_DEST}" 2>/dev/null || true
find "${APP_DEST}" -name "*.dylib" -o -name "*.so" | while read lib; do
    codesign --remove-signature "$lib" 2>/dev/null || true
done

# 重新进行ad-hoc签名
echo "  应用新签名..."
codesign --force --deep --sign - "${APP_DEST}"

# 5. 清除隔离属性（Gatekeeper）
echo -e "${GREEN}[3/5] 清除安全隔离属性...${NC}"
xattr -cr "${APP_DEST}"
xattr -d com.apple.quarantine "${APP_DEST}" 2>/dev/null || true

# 6. 设置可执行权限
echo -e "${GREEN}[4/5] 设置执行权限...${NC}"
chmod +x "${APP_DEST}/Contents/MacOS/BabelAI"

# 7. 验证签名
echo -e "${GREEN}[5/5] 验证安装...${NC}"
if codesign -dv "${APP_DEST}" 2>&1 | grep -q "adhoc"; then
    echo -e "  ${GREEN}✓ 签名验证成功${NC}"
else
    echo -e "  ${YELLOW}⚠ 签名验证警告（这是正常的）${NC}"
fi

# 8. 安装完成
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}✅ 安装完成！${NC}"
echo -e "${GREEN}================================${NC}\n"

echo -e "${BLUE}如何启动 Babel AI:${NC}"
echo -e "  1. 打开 Finder，进入 应用程序 文件夹"
echo -e "  2. 找到 Babel AI 应用"
echo -e "  3. ${YELLOW}右键点击${NC} Babel AI，选择 ${YELLOW}\"打开\"${NC}"
echo -e "  4. 在弹出的对话框中点击 ${YELLOW}\"打开\"${NC} 按钮"
echo -e "  5. 允许麦克风权限（如果提示）"
echo ""
echo -e "${GREEN}注意:${NC} 首次启动必须通过右键\"打开\"方式，之后可以正常双击启动"
echo ""
echo -e "${BLUE}需要帮助？${NC}"
echo -e "  • 查看日志: ~/Library/Logs/BabelAI/babel-ai.log"
echo -e "  • 如遇问题，请在系统设置→隐私与安全性中检查权限"
echo ""

# 询问是否立即启动
read -p "是否现在启动 Babel AI？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${GREEN}正在启动 Babel AI...${NC}"
    open -a "BabelAI"
    echo -e "${GREEN}应用已启动！请查看菜单栏的巴别塔图标。${NC}"
fi

echo -e "\n${BLUE}感谢使用 Babel AI - 让世界听懂你！${NC}"
echo ""
echo "按 Enter 键退出安装程序..."
read