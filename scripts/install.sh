#!/bin/bash

APP_NAME="Activity Mon +"
BINARY_NAME="ActivityMonPlus"
DEST_DIR="/Applications"

echo "🚀 Installing ${APP_NAME} to ${DEST_DIR}..."

# 1. Build the app bundle
./scripts/bundle.sh

if [ $? -ne 0 ]; then
    echo "❌ Build failed. Aborting installation."
    exit 1
fi

# 2. Move to Applications
echo "📂 Moving to Applications..."
sudo rm -rf "${DEST_DIR}/${APP_NAME}.app"
sudo cp -R "${APP_NAME}.app" "${DEST_DIR}/"
# Restore ownership to current user for standard app behavior
sudo chown -R $(id -u):$(id -g) "${DEST_DIR}/${APP_NAME}.app"

# 3. Configure Sudoers for NO PASSWORD on powermetrics
echo "🔐 Configuring password-less access for sensors and performance..."
SUDOERS_FILE="/etc/sudoers.d/macbook-performance"
SUDOERS_CONTENT="%admin ALL=(ALL) NOPASSWD: /usr/bin/powermetrics, /usr/bin/pmset"

echo "$SUDOERS_CONTENT" | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 440 "$SUDOERS_FILE"

# 4. Final signature REFRESH and permission check
echo "✍️  Finalizing permissions and signature..."
sudo chmod +x "${DEST_DIR}/${APP_NAME}.app/Contents/MacOS/${BINARY_NAME}"
sudo xattr -cr "${DEST_DIR}/${APP_NAME}.app"
sudo codesign --force --deep --sign - "${DEST_DIR}/${APP_NAME}.app"

echo "✅ Installation Complete!"
echo "👉 You can now launch '${APP_NAME}' from your Applications folder or Spotlight."
echo "🎯 No more password prompts for sensors!"
