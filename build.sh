#!/bin/bash
# Build Gulir.app dari source. Butuh Xcode Command Line Tools (xcode-select --install).
set -euo pipefail
cd "$(dirname "$0")"

# Universal binary: jalan di Apple silicon (arm64) dan Intel (x86_64)
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/Gulir"

APP="build/Gulir.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Gulir"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Gulir</string>
    <key>CFBundleDisplayName</key><string>Gulir</string>
    <key>CFBundleIdentifier</key><string>local.gulir.app</string>
    <key>CFBundleExecutable</key><string>Gulir</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

# Tanda tangan ad-hoc (cukup untuk dipakai sendiri, bukan untuk dibagikan)
codesign --force --sign - "$APP"

# Bungkus jadi .dmg (isi: Gulir.app + pintasan ke folder Applications)
DMG="build/Gulir.dmg"
STAGING="build/dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Gulir" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo ""
echo "Selesai:"
echo "  App : $(pwd)/$APP"
echo "  DMG : $(pwd)/$DMG"
echo "Buka DMG-nya, lalu seret Gulir ke folder Applications."
