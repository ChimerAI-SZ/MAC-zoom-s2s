#!/bin/bash

# Babel AI 一键安装脚本 - 完全自动化
# 自动处理所有签名、权限和安装问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 动画函数
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# 获取脚本所在目录（DMG挂载点）
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME="BabelAI.app"
APP_SOURCE="${SCRIPT_DIR}/${APP_NAME}"
APP_DEST="/Applications/${APP_NAME}"

clear
cat << EOF
${CYAN}╔══════════════════════════════════════╗
║                                      ║
║       ${BLUE}Babel AI${CYAN} 一键安装程序         ║
║         实时同声传译系统             ║
║                                      ║
╚══════════════════════════════════════╝${NC}

EOF

# 1. 检查应用是否存在于DMG中
if [ ! -d "${APP_SOURCE}" ]; then
    echo -e "${RED}❌ 错误: 在DMG中未找到 ${APP_NAME}${NC}"
    echo "请确保您正确挂载了DMG镜像"
    exit 1
fi

# 2. 显示安装信息
echo -e "${GREEN}准备安装 Babel AI...${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  📍 安装位置: /Applications"
echo -e "  🎯 版本: 1.0.0"
echo -e "  🔧 自动处理权限和签名"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 3. 检查是否已安装
if [ -d "${APP_DEST}" ]; then
    echo -e "${YELLOW}⚠️  检测到已安装的Babel AI${NC}"
    echo -n "是否覆盖现有安装？[y/N]: "
    read -r REPLY
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}安装已取消${NC}"
        echo "按任意键退出..."
        read -n 1
        exit 0
    fi
    echo -e "${YELLOW}删除旧版本...${NC}"
    rm -rf "${APP_DEST}" &
    show_spinner $!
    echo -e "${GREEN}✓ 已删除旧版本${NC}"
fi

# 4. 复制应用到Applications
echo -e "\n${GREEN}[1/4] 正在安装应用...${NC}"
(cp -R "${APP_SOURCE}" "${APP_DEST}") &
show_spinner $!
echo -e "${GREEN}✓ 应用已安装${NC}"

# 5. 修复签名问题
echo -e "${GREEN}[2/4] 优化应用签名...${NC}"

# 移除旧签名并重新签名
(
    # 静默处理签名
    codesign --remove-signature "${APP_DEST}" 2>/dev/null || true
    
    # 移除所有动态库的签名
    find "${APP_DEST}" \( -name "*.dylib" -o -name "*.so" \) -exec codesign --remove-signature {} \; 2>/dev/null || true
    
    # 重新进行ad-hoc签名
    codesign --force --deep --sign - "${APP_DEST}" 2>/dev/null
) &
show_spinner $!
echo -e "${GREEN}✓ 签名优化完成${NC}"

# 6. 清除隔离属性
echo -e "${GREEN}[3/4] 配置系统权限...${NC}"
(
    xattr -cr "${APP_DEST}"
    xattr -d com.apple.quarantine "${APP_DEST}" 2>/dev/null || true
    chmod +x "${APP_DEST}/Contents/MacOS/BabelAI"
) &
show_spinner $!
echo -e "${GREEN}✓ 权限配置完成${NC}"

# 7. 验证安装
echo -e "${GREEN}[4/4] 验证安装...${NC}"
sleep 1
if [ -d "${APP_DEST}" ]; then
    echo -e "${GREEN}✓ 安装验证成功${NC}"
else
    echo -e "${RED}❌ 安装验证失败${NC}"
    exit 1
fi

# 8. 成功提示
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 安装成功！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 9. 使用说明
cat << EOF
${BLUE}如何启动 Babel AI:${NC}
  1. 在应用程序文件夹找到 Babel AI
  2. ${YELLOW}首次启动：右键点击选择"打开"${NC}
  3. 在弹出的对话框中点击"打开"
  4. 允许麦克风权限（如果提示）

${BLUE}使用提示:${NC}
  • 点击菜单栏的 Babel AI 图标
  • 选择 Start 开始翻译
  • 支持中文→英文实时同声传译

${BLUE}需要帮助？${NC}
  • 查看日志: ~/Library/Logs/BabelAI/
  • 系统设置 → 隐私与安全性 → 麦克风

EOF

# 10. 询问是否立即启动
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -n -e "${GREEN}是否现在启动 Babel AI？[Y/n]: ${NC}"
read -r LAUNCH
echo ""

if [[ ! $LAUNCH =~ ^[Nn]$ ]]; then
    echo -e "${GREEN}正在启动 Babel AI...${NC}"
    # 先打开Finder定位到应用
    open -R "${APP_DEST}"
    sleep 0.5
    # 然后启动应用
    open -a "BabelAI"
    echo -e "${GREEN}✓ 应用已启动！请查看菜单栏的巴别塔图标${NC}"
    echo ""
    echo -e "${YELLOW}温馨提示：${NC}"
    echo -e "  • 首次启动会请求麦克风权限，请点击'允许'"
    echo -e "  • 如果看到安全提示，请选择'打开'"
else
    echo -e "${BLUE}您可以稍后从应用程序文件夹启动 Babel AI${NC}"
fi

echo ""
echo -e "${CYAN}感谢使用 Babel AI - 让世界听懂你！${NC}"
echo ""
echo "按 Enter 键退出安装程序..."
read