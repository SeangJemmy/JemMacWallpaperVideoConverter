#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "=== Building JemWallpaperConverter ==="
swift build -c release

echo "=== Creating macOS App Bundle ==="
APP_NAME="JemWallpaperConverter.app"
rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS" "$APP_NAME/Contents/Resources"

cp .build/release/JemWallpaperConverter "$APP_NAME/Contents/MacOS/"
cp Bundle/Info.plist "$APP_NAME/Contents/"
if [ -f "Bundle/AppIcon.icns" ]; then
    cp Bundle/AppIcon.icns "$APP_NAME/Contents/Resources/"
fi
echo "APPL????" > "$APP_NAME/Contents/PkgInfo"

echo "=== Signing App Bundle ==="
codesign --force --deep -s - "$APP_NAME"

echo ""
echo "✅ Build complete: $PWD/$APP_NAME"
echo "To run the app:"
echo "  open $APP_NAME"
echo "To run via CLI:"
echo "  $APP_NAME/Contents/MacOS/JemWallpaperConverter input.mp4 [output.mov]"
