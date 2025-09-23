#!/bin/bash
# Create Professional DMG for BabelAI

set -e

echo "======================================"
echo "   BabelAI DMG Creator"
echo "======================================"
echo ""

# Variables
APP_NAME="BabelAI"
DMG_NAME="BabelAI-1.0.0"
DMG_VOLUME_NAME="BabelAI"
DMG_PATH="dist/${DMG_NAME}.dmg"
DMG_TEMP_PATH="dist/${DMG_NAME}-temp.dmg"
MOUNT_POINT="/Volumes/${DMG_VOLUME_NAME}"

# Clean up any existing DMG
echo "[1/7] Cleaning up old DMG..."
rm -f "${DMG_PATH}" "${DMG_TEMP_PATH}" 2>/dev/null || true
if [ -d "${MOUNT_POINT}" ]; then
    hdiutil detach "${MOUNT_POINT}" 2>/dev/null || true
fi

# Check if app exists
if [ ! -d "dist/${APP_NAME}.app" ]; then
    echo "❌ Error: dist/${APP_NAME}.app not found!"
    exit 1
fi

# Create temporary DMG
echo "[2/7] Creating temporary DMG..."
hdiutil create -size 100m -fs HFS+ -volname "${DMG_VOLUME_NAME}" "${DMG_TEMP_PATH}"

# Mount the DMG
echo "[3/7] Mounting DMG..."
hdiutil attach "${DMG_TEMP_PATH}" -mountpoint "${MOUNT_POINT}"

# Copy contents
echo "[4/7] Copying contents..."
cp -R "dist/${APP_NAME}.app" "${MOUNT_POINT}/"

# Create symbolic link to Applications
ln -s /Applications "${MOUNT_POINT}/Applications"

# Create background and DS_Store for nice layout
echo "[5/7] Setting up DMG layout..."

# Create DMG background
mkdir -p "${MOUNT_POINT}/.background"

# Use AppleScript to set the window properties
echo "[6/7] Configuring DMG appearance..."
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
        set icon size of viewOptions to 80
        set position of item "${APP_NAME}.app" of container window to {150, 160}
        set position of item "Applications" of container window to {350, 160}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount and convert to final DMG
echo "[7/7] Creating final DMG..."
sync
hdiutil detach "${MOUNT_POINT}"

# Convert to compressed DMG
hdiutil convert "${DMG_TEMP_PATH}" -format UDZO -o "${DMG_PATH}"
rm -f "${DMG_TEMP_PATH}"

# Sign the DMG
codesign --force --sign - "${DMG_PATH}" 2>/dev/null || true

echo ""
echo "======================================"
echo "✅ DMG Created Successfully!"
echo "======================================"
echo ""
echo "File: $(pwd)/${DMG_PATH}"
echo "Size: $(du -h "${DMG_PATH}" | cut -f1)"
echo ""
echo "To test: open ${DMG_PATH}"
echo ""