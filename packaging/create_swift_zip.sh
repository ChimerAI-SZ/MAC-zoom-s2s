#!/bin/bash
# Create ZIP for BabelAI Swift App with Installation Instructions

set -e

echo "======================================"
echo "    BabelAI ZIP Creator"
echo "======================================"
echo ""

# Variables
APP_NAME="BabelAI"
ZIP_NAME="BabelAI-1.0.0.zip"
ZIP_PATH="dist/${ZIP_NAME}"
TEMP_DIR="dist/BabelAI-Package"

# Check if app exists
if [ ! -d "dist/${APP_NAME}.app" ]; then
    echo "❌ Error: dist/${APP_NAME}.app not found!"
    echo "Please run ./build_swift_release.sh first"
    exit 1
fi

# Clean up
echo "[1/4] 🧹 Cleaning up..."
rm -f "${ZIP_PATH}" 2>/dev/null || true
rm -rf "${TEMP_DIR}" 2>/dev/null || true

# Create temporary package directory
echo "[2/4] 📦 Preparing package..."
mkdir -p "${TEMP_DIR}"
cp -R "dist/${APP_NAME}.app" "${TEMP_DIR}/"
cp "README_FIRST.txt" "${TEMP_DIR}/安装说明_INSTALL_GUIDE.txt"

# Create a simple install helper script
cat > "${TEMP_DIR}/Install_BabelAI.command" <<'EOF'
#!/bin/bash
# BabelAI Quick Installer

echo "======================================"
echo "    BabelAI Quick Installer"
echo "======================================"
echo ""

# Get the directory where this script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_NAME="BabelAI.app"

# Check if app exists
if [ ! -d "$DIR/$APP_NAME" ]; then
    echo "❌ Error: BabelAI.app not found in current directory!"
    exit 1
fi

echo "📦 Installing BabelAI to Applications folder..."

# Copy to Applications
cp -R "$DIR/$APP_NAME" /Applications/ || {
    echo "❌ Failed to copy to Applications. Trying with admin privileges..."
    sudo cp -R "$DIR/$APP_NAME" /Applications/
}

# Clear quarantine attribute
echo "🔓 Clearing security attributes..."
xattr -cr /Applications/$APP_NAME 2>/dev/null || {
    echo "  Note: You may need to manually allow the app in System Preferences"
}

echo ""
echo "✅ Installation complete!"
echo ""
echo "To open BabelAI:"
echo "1. Go to Applications folder"
echo "2. Right-click on BabelAI"
echo "3. Select 'Open'"
echo "4. Click 'Open' in the security dialog"
echo ""
echo "Or run: open /Applications/$APP_NAME"
echo ""
read -p "Press Enter to close..."
EOF

chmod +x "${TEMP_DIR}/Install_BabelAI.command"

# Create ZIP
echo "[3/4] 🗜️ Creating ZIP archive..."
cd dist
zip -r -q "${ZIP_NAME}" "BabelAI-Package"
cd ..

# Clean up temp directory
echo "[4/4] 🧹 Cleaning up temporary files..."
rm -rf "${TEMP_DIR}"

# Get file size
ZIP_SIZE=$(du -h "${ZIP_PATH}" | cut -f1)

echo ""
echo "======================================"
echo "✅ ZIP Created Successfully!"
echo "======================================"
echo ""
echo "📍 File: ${ZIP_PATH}"
echo "📏 Size: ${ZIP_SIZE}"
echo ""
echo "Package contents:"
echo "  • BabelAI.app - The application"
echo "  • 安装说明_INSTALL_GUIDE.txt - Installation instructions"
echo "  • Install_BabelAI.command - One-click installer"
echo ""
echo "Users can:"
echo "1. Unzip the package"
echo "2. Double-click Install_BabelAI.command for auto-install"
echo "3. Or manually drag BabelAI.app to Applications"
echo ""