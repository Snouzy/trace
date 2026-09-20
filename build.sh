#!/bin/bash
# Needs the Command Line Tools: xcode-select --install
set -e
cd "$(dirname "$0")"

swiftc -Osize -swift-version 6 -default-isolation MainActor -target "$(uname -m)-apple-macos12" \
    -Xlinker -dead_strip -Xlinker -x main.swift -o Trace

rm -rf Trace.app
mkdir -p Trace.app/Contents/MacOS
mv Trace Trace.app/Contents/MacOS/

cat > Trace.app/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Trace</string>
    <key>CFBundleIdentifier</key><string>local.trace</string>
    <key>CFBundleName</key><string>Trace</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - Trace.app
echo "✓ Trace.app prêt ($(du -sh Trace.app | cut -f1)) → open Trace.app"
