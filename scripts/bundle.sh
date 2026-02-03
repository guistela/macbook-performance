#!/bin/bash

# Configuration
APP_NAME="MacbookPerformance"
BUNDLE_ID="com.guistela.MacbookPerformance"
OUTPUT_DIR="."


echo "🧹 Cleaning previous build..."
swift package clean

echo "🚀 Building ${APP_NAME} (Release Mode)..."
# Adding --verbose to show progress if it hangs
swift build -c release --verbose

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
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "🚚 Copying Binary..."
cp ".build/release/${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/"

echo "✍️  Signing App Bundle (Ad-hoc)..."
codesign --force --deep --sign - "${APP_NAME}.app"

echo "✅ App Bundle Created: ${APP_NAME}.app"
echo "👉 You can now move '${APP_NAME}.app' to /Applications or run it immediately."
