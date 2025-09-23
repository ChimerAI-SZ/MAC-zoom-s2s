#!/bin/bash
# Babel AI 改进的安装助手 - 优雅处理权限问题
# 此脚本帮助用户正确安装Babel AI应用并配置权限

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}       Babel AI 智能安装助手 v2.0         ${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "此安装助手将帮助您："
echo "• 清理旧版本Babel AI"
echo "• 安装新版本到应用程序文件夹"
echo "• 自动配置麦克风权限"
echo "• 启动并验证应用"
echo ""

# 切换到脚本所在目录
cd "$(dirname "$0")"

# 检查BabelAI.app是否存在
echo -e "${YELLOW}[步骤 1/7] 检查安装文件...${NC}"
if [ ! -d "dist/BabelAI.app" ] && [ ! -d "BabelAI.app" ]; then
    echo -e "${RED}❌ 错误：找不到BabelAI.app${NC}"
    echo "请确保BabelAI.app与此脚本在同一目录"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi

# 确定BabelAI.app的位置
if [ -d "dist/BabelAI.app" ]; then
    APP_PATH="dist/BabelAI.app"
elif [ -d "BabelAI.app" ]; then
    APP_PATH="BabelAI.app"
fi

echo -e "${GREEN}✓ 找到BabelAI.app${NC}"

# 停止运行中的Babel AI
echo -e "${YELLOW}[步骤 2/7] 停止旧版本Babel AI...${NC}"
if pgrep -f Babel AI > /dev/null; then
    pkill -f Babel AI
    echo -e "${GREEN}✓ 已停止运行中的Babel AI${NC}"
    sleep 1
else
    echo "• 没有运行的Babel AI进程"
fi

# 清理旧版本
echo -e "${YELLOW}[步骤 3/7] 清理旧版本...${NC}"

# 重置TCC权限
tccutil reset Microphone com.s2s.app 2>/dev/null || true
echo "• 已重置麦克风权限记录"

# 清理日志和偏好设置
rm -rf ~/Library/Logs/Babel AI/ 2>/dev/null || true
rm -rf ~/.config/s2s/ 2>/dev/null || true
defaults delete com.s2s.app 2>/dev/null || true
echo "• 已清理配置文件"

# 删除旧版本应用
if [ -d "/Applications/BabelAI.app" ]; then
    echo "• 发现已安装的旧版本，需要管理员权限删除"
    echo -e "${BLUE}请输入系统密码以继续：${NC}"
    sudo rm -rf /Applications/BabelAI.app
    echo -e "${GREEN}✓ 已删除旧版本${NC}"
fi

# 签名应用（确保权限能正确请求）
echo -e "${YELLOW}[步骤 4/7] 配置应用签名...${NC}"
codesign --force --deep --sign - "$APP_PATH" 2>/dev/null
xattr -cr "$APP_PATH"
echo -e "${GREEN}✓ 应用签名完成${NC}"

# 复制到Applications
echo -e "${YELLOW}[步骤 5/7] 安装Babel AI到应用程序文件夹...${NC}"
echo -e "${BLUE}需要管理员权限安装应用：${NC}"
sudo cp -R "$APP_PATH" /Applications/ || {
    echo -e "${RED}❌ 安装失败：无法复制到/Applications${NC}"
    echo "您可以手动将BabelAI.app拖拽到应用程序文件夹"
    read -p "按回车键退出..."
    exit 1
}

# 设置正确的权限
sudo chmod -R 755 /Applications/BabelAI.app
sudo xattr -cr /Applications/BabelAI.app
echo -e "${GREEN}✓ Babel AI已安装到应用程序文件夹${NC}"

# 首次从终端启动（更容易触发权限）
echo -e "${YELLOW}[步骤 6/7] 配置麦克风权限...${NC}"
echo ""
echo -e "${GREEN}重要提示：${NC}"
echo "即将启动Babel AI并请求麦克风权限。"
echo "当看到权限对话框时，请点击【允许】"
echo ""
read -p "准备好后按回车键继续..."

# 从终端启动应用（这样更容易触发权限对话框）
echo "正在启动Babel AI..."
/Applications/BabelAI.app/Contents/MacOS/Babel AI > /dev/null 2>&1 &
Babel AI_PID=$!

# 等待应用启动
sleep 3

# 检查权限状态
echo -e "${YELLOW}[步骤 7/7] 验证安装...${NC}"

# 检查应用是否在运行
if ps -p $Babel AI_PID > /dev/null; then
    echo -e "${GREEN}✓ Babel AI正在运行${NC}"
else
    echo -e "${YELLOW}⚠ Babel AI未在后台运行，可能需要手动启动${NC}"
fi

# 完成信息
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}        🎉 安装完成！                 ${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}使用方法：${NC}"
echo "1. 点击菜单栏的Babel AI图标"
echo "2. 选择【Start】开始翻译"
echo "3. 支持中文到英文的实时同声传译"
echo ""
echo -e "${YELLOW}如果没有看到权限对话框：${NC}"
echo "1. 打开系统设置 → 隐私与安全性 → 麦克风"
echo "2. 找到Babel AI并勾选允许"
echo "3. 重启Babel AI应用"
echo ""
echo -e "${GREEN}提示：${NC}您也可以从Launchpad或应用程序文件夹启动Babel AI"
echo ""
read -p "按回车键关闭安装助手..."