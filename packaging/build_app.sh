#!/bin/bash
# 构建Babel AI.app并正确签名

set -e

echo "======================================"
echo "    Babel AI App Builder"
echo "======================================"
echo ""

# 切换到packaging目录
cd "$(dirname "$0")"

echo "[1/4] 清理旧的构建..."
rm -rf build dist 2>/dev/null || true

echo "[2/4] 使用PyInstaller构建app..."
pyinstaller --clean --noconfirm macos.spec

echo "[3/4] 签名应用（启用麦克风权限）..."
# 简单的ad-hoc签名，不使用hardened runtime
echo "  执行ad-hoc签名..."
if [ -f "entitlements.plist" ]; then
    echo "  使用entitlements进行签名..."
    # 一次性完成签名和entitlements应用
    codesign --force --deep --sign - \
        --entitlements entitlements.plist \
        "dist/BabelAI.app"
else
    echo "  基础ad-hoc签名..."
    codesign --force --deep --sign - "dist/BabelAI.app"
fi

echo "[4/4] 清除隔离属性..."
xattr -cr "dist/BabelAI.app"

# 验证签名
echo ""
echo "验证签名..."
codesign -dv "dist/BabelAI.app" 2>&1 | head -n 5

echo ""
echo "======================================"
echo "✅ 构建完成！"
echo "======================================"
echo ""
echo "应用位置: $(pwd)/dist/Babel AI.app"
echo ""
echo "下一步："
echo "1. 测试: open dist/Babel AI.app"
echo "2. 发布: bash build_release.sh"
echo ""