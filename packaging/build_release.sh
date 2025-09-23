#!/bin/bash
# 构建Babel AI发布包

set -e

VERSION="1.0.0"
RELEASE_NAME="Babel AI-${VERSION}"

echo "======================================"
echo "    Babel AI Release Builder v${VERSION}"
echo "======================================"
echo ""

# 切换到packaging目录
cd "$(dirname "$0")"

# 1. 构建app
echo "[1/5] 构建BabelAI.app..."
if [ ! -f "build_app.sh" ]; then
    echo "❌ 错误: build_app.sh不存在"
    exit 1
fi
bash build_app.sh

# 检查构建结果
if [ ! -d "dist/BabelAI.app" ]; then
    echo "❌ 错误: 构建失败，找不到BabelAI.app"
    exit 1
fi

# 2. 创建发布目录
echo ""
echo "[2/5] 准备发布文件..."
rm -rf release 2>/dev/null || true
mkdir -p release

# 复制必要文件
cp -R dist/BabelAI.app release/
cp install_helper.command release/

# 3. 创建README
echo "[3/5] 创建说明文档..."
cat > release/README.txt << 'EOF'
====================================
Babel AI 同声传译系统 - 安装说明
====================================

感谢您选择Babel AI！

【快速安装】
1. 双击 install_helper.command
2. 输入系统密码完成安装
3. 允许麦克风权限

【使用方法】
1. 点击菜单栏的Babel AI图标
2. 选择Start开始翻译
3. 支持中文到英文的实时同声传译

【会议模式】
1. 安装BlackHole虚拟音频设备
2. 在Settings中开启Conference Mode
3. 设置会议软件的麦克风为BlackHole

【故障排除】
• 没有声音：检查系统设置→隐私与安全性→麦克风
• 无法启动：重新运行install_helper.command
• 其他问题：访问 github.com/your-repo/s2s

【版本信息】
EOF
echo "版本: ${VERSION}" >> release/README.txt
echo "构建时间: $(date '+%Y-%m-%d %H:%M:%S')" >> release/README.txt

# 4. 创建ZIP包
echo "[4/5] 打包发布文件..."
cd release
zip -r "../${RELEASE_NAME}.zip" * -x "*.DS_Store"
cd ..

# 5. 创建DMG（可选，需要create-dmg工具）
echo "[5/5] 创建DMG镜像..."
if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "${RELEASE_NAME}" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "BabelAI.app" 150 185 \
        --hide-extension "BabelAI.app" \
        --app-drop-link 450 185 \
        --no-internet-enable \
        "${RELEASE_NAME}.dmg" \
        "release/" 2>/dev/null || {
            echo "  DMG创建失败，但ZIP包已准备好"
        }
else
    echo "  跳过DMG创建（未安装create-dmg）"
    echo "  可通过以下命令安装: brew install create-dmg"
fi

# 清理临时文件
echo ""
echo "清理临时文件..."
rm -rf release

# 完成
echo ""
echo "======================================"
echo "✅ 发布包创建完成！"
echo "======================================"
echo ""
echo "发布文件:"
echo "  • ZIP包: $(pwd)/${RELEASE_NAME}.zip"
if [ -f "${RELEASE_NAME}.dmg" ]; then
    echo "  • DMG包: $(pwd)/${RELEASE_NAME}.dmg"
fi
echo ""
echo "ZIP包大小: $(du -h ${RELEASE_NAME}.zip | cut -f1)"
echo ""
echo "发布步骤:"
echo "1. 上传到GitHub Releases"
echo "2. 更新官网下载链接"
echo "3. 通知用户更新"
echo ""