#!/bin/bash
# Needs the Command Line Tools: xcode-select --install
# release.sh sets ARCHS, VERSION and SIGN_IDENTITY. Without them: this Mac's architecture, 0.1, ad hoc signature.
set -e
cd "$(dirname "$0")"
ARCHS=${ARCHS:-$(uname -m)}
VERSION=${VERSION:-0.1}
SIGN_IDENTITY=${SIGN_IDENTITY:--}

rm -rf Trace.app
mkdir -p Trace.app/Contents/MacOS
slices=()
for arch in $ARCHS; do
    swiftc -Osize -swift-version 6 -default-isolation MainActor -target "$arch-apple-macos12" \
        -Xlinker -dead_strip -Xlinker -x main.swift -o "Trace-$arch"
    slices+=("Trace-$arch")
done
# lipo pads even a single slice: 16 KB more for nothing.
if [ ${#slices[@]} -eq 1 ]; then
    mv "${slices[0]}" Trace.app/Contents/MacOS/Trace
else
    lipo -create "${slices[@]}" -output Trace.app/Contents/MacOS/Trace
    rm "${slices[@]}"
fi

cat > Trace.app/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Trace</string>
    <key>CFBundleIdentifier</key><string>local.trace</string>
    <key>CFBundleName</key><string>Trace</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --sign - Trace.app
else
    # Notarization refuses an app without the hardened runtime and a secure timestamp.
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" Trace.app
fi
echo "✓ Trace.app prêt ($(du -sh Trace.app | cut -f1)) → open Trace.app"
