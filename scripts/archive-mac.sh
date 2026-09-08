#!/bin/sh
# Archive, export, and upload MURDL to App Store Connect from this Mac.
# Signing is automatic under team NEAY582ME4 using the ASC API key in ~/.private_keys.
set -eu
cd "$(dirname "$0")/.."
K="$HOME/.private_keys/AuthKey_MN6H2P6385.p8"
AUTH="-allowProvisioningUpdates -authenticationKeyPath $K -authenticationKeyID MN6H2P6385 -authenticationKeyIssuerID 69a6de6f-2572-47e3-e053-5b8c7c11a4d1"
rm -rf build/MURDL.xcarchive build/export
# shellcheck disable=SC2086
xcodebuild -project Murdl.xcodeproj -scheme Murdl -destination 'generic/platform=macOS' -configuration Release \
  archive -archivePath build/MURDL.xcarchive $AUTH
# shellcheck disable=SC2086
xcodebuild -exportArchive -archivePath build/MURDL.xcarchive -exportOptionsPlist scripts/ExportOptions-MacAppStore.plist \
  -exportPath build/export $AUTH
PKG=$(ls build/export/*.pkg | head -1)
xcrun altool --upload-app -t macos -f "$PKG" --apiKey MN6H2P6385 --apiIssuer 69a6de6f-2572-47e3-e053-5b8c7c11a4d1
