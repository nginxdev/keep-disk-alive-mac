#!/bin/bash

# Define variables
APP_NAME="KeepDiskAlive"
BUILD_DIR=".build/release"
ICON_SOURCE="appicon.png"
ICONSET_DIR="AppIcon.iconset"

# Ensure clean state
rm -rf "$APP_NAME.app"
rm -rf "$ICONSET_DIR"

# Build the Swift project
echo "Building $APP_NAME..."
swift build -c release

# Create App Bundle Structure
echo "Creating Bundle Structure..."
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# Copy Executable
cp "$BUILD_DIR/$APP_NAME" "$APP_NAME.app/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "$APP_NAME.app/Contents/"

# Generate ICNS
echo "Generating Icon..."
mkdir "$ICONSET_DIR"
sips -s format png -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png"
sips -s format png -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png"
sips -s format png -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png"
sips -s format png -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png"
sips -s format png -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png"
sips -s format png -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png"
sips -s format png -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png"
sips -s format png -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png"
sips -s format png -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png"
sips -s format png -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$APP_NAME.app/Contents/Resources/AppIcon.icns"

# Verify ICNS creation
if [ -f "$APP_NAME.app/Contents/Resources/AppIcon.icns" ]; then
    echo "Icon generated successfully."
else
    echo "Error: Failed to generate AppIcon.icns"
    exit 1
fi

# Clean up temporary iconset
rm -rf "$ICONSET_DIR"

# Ad-hoc code signing (required for ARM64 macOS)
echo "Signing Application..."
codesign --force --deep --sign - "$APP_NAME.app"

echo "Build Complete: $APP_NAME.app"
