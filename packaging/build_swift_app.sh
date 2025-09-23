#!/bin/bash
# Build BabelAI Swift App for Distribution

set -e

echo "======================================"
echo "    BabelAI Swift App Builder"
echo "======================================"
echo ""

# Variables
APP_NAME="BabelAI"
PROJECT_DIR="../BabelAI"
BUILD_DIR="../BabelAI/build"
DIST_DIR="dist"

# Clean old builds
echo "[1/6] Cleaning old builds..."
rm -rf "$DIST_DIR" 2>/dev/null || true
mkdir -p "$DIST_DIR"

# Build the app
echo "[2/6] Building Swift app..."
cd "$PROJECT_DIR"
xcodebuild -project BabelAI.xcodeproj \
           -scheme BabelAI \
           -configuration Release \
           -derivedDataPath build \
           -quiet \
           clean build \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGNING_REQUIRED=YES \
           CODE_SIGN_STYLE=Manual \
           DEVELOPMENT_TEAM="" \
           CODE_SIGN_ENTITLEMENTS="" \
           ENABLE_HARDENED_RUNTIME=NO

# Find the built app
echo "[3/6] Locating built app..."
APP_PATH=$(find build -name "BabelAI.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find BabelAI.app in build directory"
    exit 1
fi

# Copy to dist
echo "[4/6] Copying app to dist..."
cd ../packaging
cp -R "../BabelAI/$APP_PATH" "$DIST_DIR/"

# Copy icon file to Resources
echo "[5/6] Copying icon to app bundle..."
cp "BabelAI.icns" "$DIST_DIR/$APP_NAME.app/Contents/Resources/" 2>/dev/null || {
    echo "Warning: Could not copy BabelAI.icns to app bundle"
}

# Sign the app with ad-hoc signature
echo "[6/6] Code signing..."
codesign --force --deep --sign - "$DIST_DIR/$APP_NAME.app"

# Clear quarantine
xattr -cr "$DIST_DIR/$APP_NAME.app"

# Verify
echo ""
echo "Verifying app..."
codesign -dv "$DIST_DIR/$APP_NAME.app" 2>&1 | head -n 5

echo ""
echo "======================================"
echo "✅ Build Complete!"
echo "======================================"
echo ""
echo "App location: $(pwd)/$DIST_DIR/$APP_NAME.app"
echo "App size: $(du -sh "$DIST_DIR/$APP_NAME.app" | cut -f1)"
echo ""
echo "Next steps:"
echo "1. Test: open $DIST_DIR/$APP_NAME.app"
echo "2. Create DMG: ./build_dmg.sh"
echo ""