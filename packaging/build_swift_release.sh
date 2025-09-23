#!/bin/bash
# Build BabelAI Swift App for Distribution (without Developer Certificate)
# This script builds a properly signed app that users can run after bypassing Gatekeeper

set -e

echo "======================================"
echo "    BabelAI Swift Release Builder"
echo "======================================"
echo ""

# Variables
APP_NAME="BabelAI"
PROJECT_DIR="../BabelAI"
BUILD_DIR="build"
DIST_DIR="dist"
ICONSET_DIR="BabelAI.iconset"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Clean old builds
echo "[1/8] 🧹 Cleaning old builds..."
rm -rf "$DIST_DIR/$APP_NAME.app" 2>/dev/null || true
rm -rf "$PROJECT_DIR/$BUILD_DIR" 2>/dev/null || true
mkdir -p "$DIST_DIR"

# Build the app with xcodebuild
echo "[2/8] 🔨 Building Swift app with xcodebuild..."
echo "  Configuration: Release"
echo "  Architecture: Native (arm64/x86_64)"
echo ""

cd "$PROJECT_DIR"
xcodebuild -project BabelAI.xcodeproj \
           -scheme BabelAI \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           clean build \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGNING_REQUIRED=YES \
           DEVELOPMENT_TEAM="" \
           ENABLE_HARDENED_RUNTIME=NO \
           OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
           PRODUCT_BUNDLE_IDENTIFIER="com.babelai.translator" -quiet || {
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
}

# Find the built app
echo "[3/8] 📍 Locating built app..."
APP_PATH=$(find "$BUILD_DIR" -name "BabelAI.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: Could not find BabelAI.app in build directory${NC}"
    exit 1
fi
echo "  Found: $APP_PATH"

# Copy to dist
echo "[4/8] 📦 Copying app to distribution folder..."
cd ../packaging
cp -R "../BabelAI/$APP_PATH" "$DIST_DIR/"

# Copy icons if they exist
echo "[5/8] 🎨 Ensuring icons are in place..."
if [ -f "BabelAI.icns" ]; then
    cp "BabelAI.icns" "$DIST_DIR/$APP_NAME.app/Contents/Resources/" 2>/dev/null || {
        echo -e "${YELLOW}  ⚠️  Warning: Could not copy icns file${NC}"
    }
fi

# Deep sign the app with ad-hoc certificate
echo "[6/8] ✍️  Code signing with ad-hoc certificate..."
# First sign all frameworks and dylibs
find "$DIST_DIR/$APP_NAME.app" -name "*.dylib" -o -name "*.framework" | while read -r item; do
    codesign --force --sign - "$item" 2>/dev/null || true
done
# Then sign the main app
codesign --force --deep --sign - \
         --options runtime \
         --timestamp=none \
         --entitlements ../BabelAI/BabelAI.entitlements \
         "$DIST_DIR/$APP_NAME.app" || {
    echo -e "${YELLOW}  ⚠️  Warning: Signing with entitlements failed, trying without...${NC}"
    codesign --force --deep --sign - --timestamp=none "$DIST_DIR/$APP_NAME.app"
}

# Clear extended attributes including quarantine
echo "[7/8] 🔓 Clearing extended attributes..."
xattr -cr "$DIST_DIR/$APP_NAME.app"

# Verify the app
echo "[8/8] ✅ Verifying app..."
echo ""
echo "App Information:"
echo "----------------"
codesign -dv "$DIST_DIR/$APP_NAME.app" 2>&1 | grep -E "Identifier|Format|Signature|Sealed" | head -6

# Check if app can be opened
if [ -f "$DIST_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME" ]; then
    echo -e "${GREEN}  ✅ Executable found${NC}"
else
    echo -e "${RED}  ❌ Executable not found!${NC}"
    exit 1
fi

# Get app size
APP_SIZE=$(du -sh "$DIST_DIR/$APP_NAME.app" | cut -f1)

echo ""
echo "======================================"
echo -e "${GREEN}✅ Build Complete!${NC}"
echo "======================================"
echo ""
echo "📍 App location: $(pwd)/$DIST_DIR/$APP_NAME.app"
echo "📏 App size: $APP_SIZE"
echo ""
echo "Next steps:"
echo "1. Test locally: open $DIST_DIR/$APP_NAME.app"
echo "2. Create DMG: ./create_swift_dmg.sh"
echo "3. Create ZIP: ./create_swift_zip.sh"
echo ""
echo -e "${YELLOW}⚠️  Note for distribution:${NC}"
echo "  Since the app is not notarized (no Apple Developer account),"
echo "  users will need to bypass Gatekeeper on first launch:"
echo "  • Right-click the app → Open → Click 'Open' in the dialog"
echo "  • Or: System Preferences → Privacy & Security → Open Anyway"
echo ""