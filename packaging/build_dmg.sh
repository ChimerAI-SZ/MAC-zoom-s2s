#!/bin/bash
# Babel AI DMG Creator
# Creates a beautiful DMG with the app and installer

set -e

echo "=================================="
echo "   Babel AI DMG Creator"
echo "=================================="
echo ""

# Variables
APP_NAME="BabelAI"
APP_PATH="dist/${APP_NAME}.app"
DMG_NAME="BabelAI-Installer"
DMG_VOLUME_NAME="Babel AI Installer"
DMG_PATH="dist/${DMG_NAME}.dmg"
DMG_TEMP_PATH="dist/${DMG_NAME}-temp.dmg"
MOUNT_POINT="/Volumes/${DMG_VOLUME_NAME}"

# Clean up any existing DMG
echo "[1/6] Cleaning up old DMG..."
rm -f "${DMG_PATH}" "${DMG_TEMP_PATH}" 2>/dev/null || true
if [ -d "${MOUNT_POINT}" ]; then
    hdiutil detach "${MOUNT_POINT}" 2>/dev/null || true
fi

# Check if app exists
if [ ! -d "${APP_PATH}" ]; then
    echo "❌ Error: ${APP_PATH} not found!"
    echo "Please run build_app.sh first"
    exit 1
fi

# Make installer executable
chmod +x one_click_install.command

# Create temporary DMG
echo "[2/6] Creating temporary DMG..."
hdiutil create -size 150m -fs HFS+ -volname "${DMG_VOLUME_NAME}" "${DMG_TEMP_PATH}"

# Mount the DMG
echo "[3/6] Mounting DMG..."
hdiutil attach "${DMG_TEMP_PATH}" -mountpoint "${MOUNT_POINT}"

# Copy contents
echo "[4/6] Copying contents..."
cp -R "${APP_PATH}" "${MOUNT_POINT}/"
cp "one_click_install.command" "${MOUNT_POINT}/安装 Babel AI.command"

# Create a symbolic link to Applications
ln -s /Applications "${MOUNT_POINT}/Applications"

# Create .DS_Store for nice layout (optional)
echo "[5/6] Setting up DMG layout..."
mkdir -p "${MOUNT_POINT}/.background"
cat > "${MOUNT_POINT}/.background/background.txt" <<EOF
Babel AI - 实时同声传译系统

安装步骤:
1. 双击"安装 Babel AI.command"
2. 按照提示完成安装
3. 或者直接拖动 Babel AI 到 Applications

需要帮助? 查看 README.md
EOF

# Set custom icon positions using AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "${DMG_VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        set position of item "BabelAI.app" of container window to {125, 120}
        set position of item "Applications" of container window to {375, 120}
        set position of item "安装 Babel AI.command" of container window to {250, 220}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

# Unmount
echo "[6/6] Creating final DMG..."
sync
hdiutil detach "${MOUNT_POINT}"

# Convert to compressed DMG
hdiutil convert "${DMG_TEMP_PATH}" -format UDZO -o "${DMG_PATH}"
rm -f "${DMG_TEMP_PATH}"

# Sign the DMG (optional)
echo "Signing DMG..."
codesign --force --sign - "${DMG_PATH}"

echo ""
echo "=================================="
echo "✅ DMG创建成功!"
echo "=================================="
echo ""
echo "文件位置: $(pwd)/${DMG_PATH}"
echo "文件大小: $(du -h "${DMG_PATH}" | cut -f1)"
echo ""
echo "下一步:"
echo "1. 测试安装: open ${DMG_PATH}"
echo "2. 分发给用户"
echo ""