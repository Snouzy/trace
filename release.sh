#!/bin/bash
# Makes a notarized universal Trace-<version>.dmg and publishes it as a GitHub release.
#
# One-time setup:
#   1. Put a "Developer ID Application" certificate in the keychain:
#      Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application.
#   2. Store the notarization credentials (the password is an app-specific password from account.apple.com):
#      xcrun notarytool store-credentials trace-notary --apple-id <apple id> --team-id <team id>
set -euo pipefail
cd "$(dirname "$0")"

VERSION=${1:?usage: bash release.sh <version>, for example: bash release.sh 0.1.0}
PROFILE=trace-notary
DMG="Trace-$VERSION.dmg"

fail() {
    echo "release.sh: $1" >&2
    exit 1
}

IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
[ -n "$IDENTITY" ] || fail "no Developer ID Application certificate in the keychain. See the top of this file."
xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 ||
    fail "no notarytool profile \"$PROFILE\". See the top of this file."

# The release tag must point at the code that the DMG contains.
git fetch --quiet origin main
[ -z "$(git status --porcelain)" ] || fail "the working tree is not clean."
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || fail "HEAD is not origin/main."

ARCHS="arm64 x86_64" VERSION="$VERSION" SIGN_IDENTITY="$IDENTITY" bash build.sh

stage=$(mktemp -d)
cp -R Trace.app "$stage/"
ln -s /Applications "$stage/Applications"
hdiutil create -volname Trace -srcfolder "$stage" -ov -format UDZO "$DMG"
codesign --timestamp --sign "$IDENTITY" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"

gh release create "v$VERSION" "$DMG" --target "$(git rev-parse HEAD)" --title "Trace $VERSION" --generate-notes
