#!/bin/bash

# S2S macOS PKG 打包脚本
# 生成可分发的.pkg安装包（带安装向导）

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置
APP_NAME="S2S"
VERSION=$(cat ../VERSION 2>/dev/null || echo "1.0.0")
BUNDLE_ID="com.s2s.app"
PKG_NAME="${APP_NAME}-v${VERSION}.pkg"
BUILD_DIR="build"
DIST_DIR="dist"
SCRIPTS_DIR="scripts"
RESOURCES_DIR="resources"

# 输出信息
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}S2S PKG 打包工具${NC}"
echo -e "${GREEN}版本: ${VERSION}${NC}"
echo -e "${GREEN}================================${NC}\n"

# 1. 检查环境
echo -e "${YELLOW}[1/7] 检查环境...${NC}"
if ! command -v pkgbuild &> /dev/null; then
    echo -e "${RED}错误: 未找到 pkgbuild 命令${NC}"
    exit 1
fi
if ! command -v productbuild &> /dev/null; then
    echo -e "${RED}错误: 未找到 productbuild 命令${NC}"
    exit 1
fi

# 2. 构建 App（如果尚未构建）
echo -e "${YELLOW}[2/7] 检查 S2S.app...${NC}"
if [ ! -d "${DIST_DIR}/${APP_NAME}.app" ]; then
    echo "正在构建 ${APP_NAME}.app..."
    pyinstaller --clean --noconfirm macos.spec
fi

if [ ! -d "${DIST_DIR}/${APP_NAME}.app" ]; then
    echo -e "${RED}错误: 未找到 ${DIST_DIR}/${APP_NAME}.app${NC}"
    echo "请先运行 'make build' 构建应用"
    exit 1
fi

# 3. 创建临时目录结构
echo -e "${YELLOW}[3/7] 准备打包目录...${NC}"
rm -rf "${BUILD_DIR}/pkg"
mkdir -p "${BUILD_DIR}/pkg/Applications"
cp -R "${DIST_DIR}/${APP_NAME}.app" "${BUILD_DIR}/pkg/Applications/"

# 确保应用有正确的权限
chmod -R 755 "${BUILD_DIR}/pkg/Applications/${APP_NAME}.app"

# 4. 创建脚本目录
echo -e "${YELLOW}[4/7] 创建安装脚本...${NC}"
mkdir -p "${SCRIPTS_DIR}"

# 创建 preinstall 脚本（安装前检查）
cat > "${SCRIPTS_DIR}/preinstall" << 'EOF'
#!/bin/bash
# S2S 安装前脚本

# 如果旧版本存在，备份用户配置
if [ -d "/Applications/S2S.app" ]; then
    echo "检测到已安装的S2S，正在更新..."
    # 备份用户偏好设置（如果需要）
    if [ -f "$HOME/Library/Preferences/com.s2s.app.plist" ]; then
        cp "$HOME/Library/Preferences/com.s2s.app.plist" "$HOME/Library/Preferences/com.s2s.app.plist.backup"
    fi
fi

exit 0
EOF

# 创建 postinstall 脚本（安装后操作）
cat > "${SCRIPTS_DIR}/postinstall" << 'EOF'
#!/bin/bash
# S2S 安装后脚本

# 设置应用权限
if [ -d "/Applications/S2S.app" ]; then
    # 确保应用可执行
    chmod -R 755 "/Applications/S2S.app"
    
    # 清除隔离属性（避免"无法打开"错误）
    xattr -cr "/Applications/S2S.app" 2>/dev/null || true
    
    # 设置正确的所有者
    chown -R "$USER:staff" "/Applications/S2S.app"
    
    # 注册到 Launch Services（确保在 Launchpad 中可见）
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "/Applications/S2S.app" 2>/dev/null || true
    
    # 恢复用户配置（如果有备份）
    if [ -f "$HOME/Library/Preferences/com.s2s.app.plist.backup" ]; then
        mv "$HOME/Library/Preferences/com.s2s.app.plist.backup" "$HOME/Library/Preferences/com.s2s.app.plist"
    fi
    
    echo "S2S 已成功安装到 /Applications"
    
    # 自动安装 BlackHole（如果未安装）
    if [ -f "/Applications/S2S.app/Contents/Resources/resources/BlackHole2ch.pkg" ]; then
        if ! system_profiler SPAudioDataType 2>/dev/null | grep -q "BlackHole"; then
            echo "正在安装 BlackHole 虚拟音频设备..."
            # 静默安装BlackHole
            /usr/sbin/installer -pkg "/Applications/S2S.app/Contents/Resources/resources/BlackHole2ch.pkg" \
                -target / 2>/dev/null || true
            
            if system_profiler SPAudioDataType 2>/dev/null | grep -q "BlackHole"; then
                echo "BlackHole 已成功安装"
            else
                echo "BlackHole 安装失败，会议模式可能不可用"
            fi
        else
            echo "BlackHole 已安装"
        fi
    fi
fi

exit 0
EOF

chmod +x "${SCRIPTS_DIR}/preinstall"
chmod +x "${SCRIPTS_DIR}/postinstall"

# 5. 构建组件包
echo -e "${YELLOW}[5/7] 构建组件包...${NC}"
pkgbuild \
    --root "${BUILD_DIR}/pkg" \
    --identifier "${BUNDLE_ID}" \
    --version "${VERSION}" \
    --scripts "${SCRIPTS_DIR}" \
    --install-location "/" \
    "${BUILD_DIR}/${APP_NAME}-component.pkg"

# 6. 检查资源文件
echo -e "${YELLOW}[6/7] 检查安装资源...${NC}"
if [ ! -f "${RESOURCES_DIR}/Welcome.txt" ]; then
    echo -e "${YELLOW}警告: 缺少 Welcome.txt，使用默认设置${NC}"
fi
if [ ! -f "${RESOURCES_DIR}/License.txt" ]; then
    echo -e "${YELLOW}警告: 缺少 License.txt，使用默认设置${NC}"
fi

# 7. 构建最终产品包
echo -e "${YELLOW}[7/7] 生成安装包...${NC}"

# 检查是否有distribution.xml
if [ -f "distribution.xml" ] && [ -d "${RESOURCES_DIR}" ]; then
    # 使用自定义分发配置（带安装向导）
    echo "使用安装向导模式..."
    productbuild \
        --distribution "distribution.xml" \
        --resources "${RESOURCES_DIR}" \
        --package-path "${BUILD_DIR}" \
        --version "${VERSION}" \
        "${DIST_DIR}/${PKG_NAME}"
else
    # 简单模式（无向导）
    echo "使用简单安装模式..."
    productbuild \
        --package "${BUILD_DIR}/${APP_NAME}-component.pkg" \
        --identifier "${BUNDLE_ID}" \
        --version "${VERSION}" \
        "${DIST_DIR}/${PKG_NAME}"
fi

# 清理临时文件
echo "清理临时文件..."
rm -rf "${BUILD_DIR}/pkg"
rm -f "${BUILD_DIR}/${APP_NAME}-component.pkg"
rm -rf "${SCRIPTS_DIR}"

# 显示结果
if [ -f "${DIST_DIR}/${PKG_NAME}" ]; then
    SIZE=$(du -h "${DIST_DIR}/${PKG_NAME}" | awk '{print $1}')
    echo -e "\n${GREEN}✅ 打包成功！${NC}"
    echo -e "${GREEN}文件: ${DIST_DIR}/${PKG_NAME}${NC}"
    echo -e "${GREEN}大小: ${SIZE}${NC}"
    echo -e "\n安装方式:"
    echo -e "  1. 双击 ${PKG_NAME} 进行图形化安装（推荐）"
    echo -e "  2. 命令行安装: sudo installer -pkg ${DIST_DIR}/${PKG_NAME} -target /"
    echo -e "\n安装位置: /Applications/S2S.app"
    echo -e "启动方式: 在 Launchpad 或应用程序文件夹中找到 S2S"
else
    echo -e "\n${RED}❌ 打包失败${NC}"
    exit 1
fi