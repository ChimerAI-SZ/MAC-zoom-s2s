#!/bin/bash
# BabelAI Swift App PKG Creator
# Creates an installable .pkg file for easy distribution

set -e

echo "======================================"
echo "    BabelAI PKG Installer Creator"
echo "======================================"
echo ""

# Variables
APP_NAME="BabelAI"
VERSION="1.0.0"
BUNDLE_ID="com.babelai.translator"
PKG_NAME="BabelAI-${VERSION}.pkg"
PKG_PATH="dist/${PKG_NAME}"
BUILD_DIR="build/pkg"
SCRIPTS_DIR="build/scripts"
DIST_DIR="dist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if app exists
if [ ! -d "${DIST_DIR}/${APP_NAME}.app" ]; then
    echo -e "${RED}❌ Error: ${DIST_DIR}/${APP_NAME}.app not found!${NC}"
    echo "Please run ./build_swift_release.sh first"
    exit 1
fi

# Clean up
echo "[1/7] 🧹 Cleaning up old files..."
rm -rf "${BUILD_DIR}" 2>/dev/null || true
rm -rf "${SCRIPTS_DIR}" 2>/dev/null || true
rm -f "${PKG_PATH}" 2>/dev/null || true

# Create package root structure
echo "[2/7] 📦 Preparing package structure..."
mkdir -p "${BUILD_DIR}/Applications"
cp -R "${DIST_DIR}/${APP_NAME}.app" "${BUILD_DIR}/Applications/"

# Ensure proper permissions
chmod -R 755 "${BUILD_DIR}/Applications/${APP_NAME}.app"

# Create scripts directory
echo "[3/7] 📝 Creating installation scripts..."
mkdir -p "${SCRIPTS_DIR}"

# Create postinstall script
cat > "${SCRIPTS_DIR}/postinstall" <<'EOF'
#!/bin/bash
# BabelAI Post-Installation Script

echo "======================================"
echo "    BabelAI Installation"
echo "======================================"

APP_PATH="/Applications/BabelAI.app"

# Clear quarantine attribute for the app
if [ -d "$APP_PATH" ]; then
    echo "🔓 Clearing security attributes..."
    xattr -cr "$APP_PATH" 2>/dev/null || true
    
    # Set proper permissions
    chmod -R 755 "$APP_PATH"
    
    echo "✅ BabelAI has been installed successfully!"
    echo ""
    echo "To open BabelAI for the first time:"
    echo "1. Go to Applications folder"
    echo "2. Right-click on BabelAI"
    echo "3. Select 'Open'"
    echo "4. Click 'Open' in the security dialog"
    echo ""
    echo "Or if you see a security warning:"
    echo "Go to System Settings > Privacy & Security > Open Anyway"
else
    echo "⚠️  Warning: BabelAI.app not found in /Applications"
fi

exit 0
EOF

chmod +x "${SCRIPTS_DIR}/postinstall"

# Build component package
echo "[4/7] 🔧 Building component package..."
pkgbuild \
    --root "${BUILD_DIR}" \
    --identifier "${BUNDLE_ID}" \
    --version "${VERSION}" \
    --scripts "${SCRIPTS_DIR}" \
    --install-location "/" \
    "${BUILD_DIR}/${APP_NAME}-component.pkg"

# Check if distribution.xml exists
if [ -f "distribution.xml" ]; then
    echo "[5/7] 📋 Using custom distribution configuration..."
    # Build product with distribution
    productbuild \
        --distribution "distribution.xml" \
        --package-path "${BUILD_DIR}" \
        --version "${VERSION}" \
        "${PKG_PATH}"
else
    echo "[5/7] 📋 Creating distribution configuration..."
    # Create a simple distribution.xml
    cat > "${BUILD_DIR}/distribution.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2.0">
    <title>BabelAI</title>
    <organization>com.babelai</organization>
    <domains enable_localSystem="true"/>
    <options customize="never" require-scripts="true" rootVolumeOnly="true"/>
    <background file="background.png" mime-type="image/png" scaling="proportional"/>
    <welcome>
        <line>Welcome to BabelAI Installer</line>
        <line></line>
        <line>BabelAI is a real-time speech translation app for macOS.</line>
        <line>This will install BabelAI ${VERSION} on your computer.</line>
    </welcome>
    <readme mime-type="text/plain">
BabelAI - Real-time Speech Translation

Features:
• Real-time translation between Chinese and English
• Ultra-low latency (< 1.5 seconds)
• High-quality audio (48kHz)
• Floating subtitle window
• Meeting mode support

Requirements:
• macOS 13.0 or later
• Microphone access permission

Note: On first launch, you may need to allow the app in System Settings > Privacy & Security.
    </readme>
    <license mime-type="text/plain">
MIT License

Copyright (c) 2025 BabelAI Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    </license>
    <choices-outline>
        <line choice="default">
            <line choice="com.babelai.translator"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.babelai.translator" visible="false">
        <pkg-ref id="com.babelai.translator"/>
    </choice>
    <pkg-ref id="com.babelai.translator" version="${VERSION}" onConclusion="none">${APP_NAME}-component.pkg</pkg-ref>
    <product id="com.babelai.translator" version="${VERSION}"/>
</installer-gui-script>
EOF

    # Build product with distribution
    productbuild \
        --distribution "${BUILD_DIR}/distribution.xml" \
        --package-path "${BUILD_DIR}" \
        --version "${VERSION}" \
        "${PKG_PATH}"
fi

# Sign the PKG (ad-hoc, without developer certificate)
echo "[6/7] ✍️  Signing package..."
productsign --sign - "${PKG_PATH}" "${PKG_PATH}.signed" 2>/dev/null && {
    mv "${PKG_PATH}.signed" "${PKG_PATH}"
    echo "  ✅ Package signed with ad-hoc certificate"
} || {
    echo -e "${YELLOW}  ⚠️  Warning: Could not sign package (this is normal without a developer certificate)${NC}"
}

# Clean up
echo "[7/7] 🧹 Cleaning up temporary files..."
rm -rf "${BUILD_DIR}"
rm -rf "${SCRIPTS_DIR}"

# Get package info
if [ -f "${PKG_PATH}" ]; then
    PKG_SIZE=$(du -h "${PKG_PATH}" | cut -f1)
    
    echo ""
    echo "======================================"
    echo -e "${GREEN}✅ PKG Created Successfully!${NC}"
    echo "======================================"
    echo ""
    echo "📍 File: ${PKG_PATH}"
    echo "📏 Size: ${PKG_SIZE}"
    echo ""
    echo "Installation:"
    echo "1. Double-click the PKG file to install"
    echo "2. Or run: sudo installer -pkg ${PKG_PATH} -target /"
    echo ""
    echo -e "${YELLOW}Note for users:${NC}"
    echo "After installation, when opening BabelAI for the first time:"
    echo "• Right-click the app → Open → Click 'Open'"
    echo "• Or go to System Settings → Privacy & Security → Open Anyway"
    echo ""
else
    echo -e "${RED}❌ Error: Failed to create PKG${NC}"
    exit 1
fi