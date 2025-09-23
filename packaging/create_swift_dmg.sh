#!/bin/bash
# Create DMG for BabelAI Swift App with Installation Instructions

set -e

echo "======================================"
echo "    BabelAI DMG Creator"
echo "======================================"
echo ""

# Variables
APP_NAME="BabelAI"
DMG_NAME="BabelAI-1.0.0"
DMG_VOLUME_NAME="BabelAI Installer"
DMG_PATH="dist/${DMG_NAME}.dmg"
DMG_TEMP_PATH="dist/${DMG_NAME}-temp.dmg"
MOUNT_POINT="/Volumes/${DMG_VOLUME_NAME}"

# Check if app exists
if [ ! -d "dist/${APP_NAME}.app" ]; then
    echo "❌ Error: dist/${APP_NAME}.app not found!"
    echo "Please run ./build_swift_release.sh first"
    exit 1
fi

# Clean up any existing DMG
echo "[1/7] 🧹 Cleaning up old DMG..."
rm -f "${DMG_PATH}" "${DMG_TEMP_PATH}" 2>/dev/null || true
if [ -d "${MOUNT_POINT}" ]; then
    hdiutil detach "${MOUNT_POINT}" 2>/dev/null || true
fi

# Create temporary DMG (200MB to have enough space)
echo "[2/7] 📁 Creating temporary DMG..."
hdiutil create -size 200m -fs HFS+ -volname "${DMG_VOLUME_NAME}" "${DMG_TEMP_PATH}"

# Mount the DMG
echo "[3/7] 🔌 Mounting DMG..."
hdiutil attach "${DMG_TEMP_PATH}" -mountpoint "${MOUNT_POINT}"

# Copy contents
echo "[4/7] 📦 Copying contents..."
cp -R "dist/${APP_NAME}.app" "${MOUNT_POINT}/"
cp "README_FIRST.txt" "${MOUNT_POINT}/安装说明.txt"

# Create symbolic link to Applications
ln -s /Applications "${MOUNT_POINT}/Applications"

# Create background folder and add instructions
echo "[5/7] 🎨 Setting up DMG layout..."
mkdir -p "${MOUNT_POINT}/.background"

# Set custom layout using AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "${DMG_VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 450}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set background color of viewOptions to {65535, 65535, 65535}
        set position of item "BabelAI.app" of container window to {150, 180}
        set position of item "Applications" of container window to {450, 180}
        set position of item "安装说明.txt" of container window to {300, 320}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount
echo "[6/7] 🏁 Creating final DMG..."
sync
hdiutil detach "${MOUNT_POINT}"

# Convert to compressed DMG
hdiutil convert "${DMG_TEMP_PATH}" -format UDZO -o "${DMG_PATH}"
rm -f "${DMG_TEMP_PATH}"

# Sign the DMG
echo "[7/7] ✍️ Signing DMG..."
codesign --force --sign - "${DMG_PATH}"

# Get file size
DMG_SIZE=$(du -h "${DMG_PATH}" | cut -f1)

echo ""
echo "======================================"
echo "✅ DMG Created Successfully!"
echo "======================================"
echo ""
echo "📍 File: ${DMG_PATH}"
echo "📏 Size: ${DMG_SIZE}"
echo ""
echo "Installation instructions included:"
echo "  • 安装说明.txt - How to bypass Gatekeeper"
echo "  • Drag & Drop interface"
echo ""
echo "Test: open ${DMG_PATH}"
echo ""