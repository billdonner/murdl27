#!/bin/sh
# Wraps the built .NET app in a minimal .app bundle so it launches like any Mac app.
# Usage: ./make-mac-app.sh [output-dir]   (default: bin/Release/net9.0, after `dotnet build -c Release`;
# pass a `dotnet publish --self-contained` folder to get a bundle that needs no .NET install)
set -e
cd "$(dirname "$0")"
OUT="${1:-bin/Release/net9.0}"
APP="$OUT/MURDL.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Everything the build produced, including runtimes/osx/native for Skia and AvaloniaNative.
for item in "$OUT"/*; do
  case "$(basename "$item")" in MURDL.app) ;; *) cp -R "$item" "$APP/Contents/MacOS/" ;; esac
done
mv "$APP/Contents/MacOS/MURDL" "$APP/Contents/MacOS/MURDL-bin"
cat > "$APP/Contents/MacOS/MURDL" <<'SH'
#!/bin/sh
# Find a .NET runtime: the standard install, or a per-user one from dotnet-install.sh.
for d in "$DOTNET_ROOT" /usr/local/share/dotnet "$HOME/.dotnet"; do
  if [ -n "$d" ] && [ -x "$d/dotnet" ]; then export DOTNET_ROOT="$d"; break; fi
done
exec "$(dirname "$0")/MURDL-bin" "$@"
SH
chmod +x "$APP/Contents/MacOS/MURDL"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>MURDL Desktop</string>
  <key>CFBundleDisplayName</key><string>MURDL Desktop</string>
  <key>CFBundleIdentifier</key><string>com.billdonner.murdl.desktop</string>
  <key>CFBundleExecutable</key><string>MURDL</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
echo "Built $APP"
