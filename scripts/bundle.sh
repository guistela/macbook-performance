#!/bin/bash

# Configuration
APP_NAME="Activity Mon +"
BUNDLE_ID="com.guistela.ActivityMonPlus"
OUTPUT_DIR="."

echo "🧹 Cleaning previous build..."
swift package clean
rm -rf "${APP_NAME}.app"
rm -f AppIcon.icns

echo "🎨 Generating App Icon..."
if [ -f "Resources/icon.png" ]; then
    ICONSET="AppIcon.iconset"
    mkdir -p "$ICONSET"
    
    # helper function
    gen_icon() {
        # Using -s format png and ensuring we don't trigger sips warnings
        sips -z "$1" "$1" "$2" --out "$3" -s format png > /dev/null 2>&1
    }

    gen_icon 16   Resources/icon.png "$ICONSET/icon_16x16.png"
    gen_icon 32   Resources/icon.png "$ICONSET/icon_16x16@2x.png"
    gen_icon 32   Resources/icon.png "$ICONSET/icon_32x32.png"
    gen_icon 64   Resources/icon.png "$ICONSET/icon_32x32@2x.png"
    gen_icon 128  Resources/icon.png "$ICONSET/icon_128x128.png"
    gen_icon 256  Resources/icon.png "$ICONSET/icon_128x128@2x.png"
    gen_icon 256  Resources/icon.png "$ICONSET/icon_256x256.png"
    gen_icon 512  Resources/icon.png "$ICONSET/icon_256x256@2x.png"
    gen_icon 512  Resources/icon.png "$ICONSET/icon_512x512.png"
    gen_icon 1024 Resources/icon.png "$ICONSET/icon_512x512@2x.png"
    
    iconutil -c icns "$ICONSET"
    rm -rf "$ICONSET"
    echo "✅ Icon generated: AppIcon.icns"
fi

echo "🚀 Building ${APP_NAME} (Release Mode)..."
swift build -c release --product ActivityMonPlus --arch x86_64

if [ $? -ne 0 ]; then
    echo "❌ Build failed."
    exit 1
fi

echo "📦 Creating App Bundle Structure..."
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"

echo "📝 Creating Info.plist..."
cat > "${APP_NAME}.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ActivityMonPlus</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "🚚 Copying Binary..."
BINARY_PATH=".build/x86_64-apple-macosx/release/ActivityMonPlus"
if [ ! -f "$BINARY_PATH" ]; then
    # Fallback if path differs slightly
    BINARY_PATH=$(find .build -name "ActivityMonPlus" -type f -not -path "*.dSYM*" | head -n 1)
fi
cp "$BINARY_PATH" "${APP_NAME}.app/Contents/MacOS/ActivityMonPlus"

# CRITICAL: Ensure binary is executable
chmod +x "${APP_NAME}.app/Contents/MacOS/ActivityMonPlus"

if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "${APP_NAME}.app/Contents/Resources/"
fi

echo "✍️  Signing App Bundle (Ad-hoc)..."
# Clear existing extended attributes and sign
xattr -cr "${APP_NAME}.app"
codesign --force --deep --sign - "${APP_NAME}.app"

echo "✅ App Bundle Created: ${APP_NAME}.app"
