#!/bin/zsh
# App Store screenshots for iPad (landscape) and iPhone (portrait), headless.
# The simulator has no rotate command, so the UI test target sets the orientation and
# attaches a capture per demo scenario (Sources/MurdlIOS/App/Demo.swift). Landscape iPad
# frames come out in the portrait framebuffer and are turned upright here.
#
#   scripts/screenshots.sh            # both devices, all scenarios
set -e
cd "$(dirname "$0")/.."
IPAD="iPad Pro 13-inch (M5)"
IPHONE="iPhone 17 Pro Max"
SHOTS=${SHOTS:-eight,sixteen,one,daily,win,sequence,rescue,helper,scores}
OUT=${OUT:-build/screenshots}
capture() {  # name device landscape folder
  local name=$1 device=$2 landscape=$3 folder=$4
  rm -rf "$OUT/$name.xcresult" "$folder"; mkdir -p "$folder"
  TEST_RUNNER_MURDL_SHOTS=$SHOTS TEST_RUNNER_MURDL_LANDSCAPE=$landscape xcodebuild test \
    -project Murdl.xcodeproj -scheme MurdlIOS -destination "platform=iOS Simulator,name=$device" \
    -derivedDataPath build/dd-ios -only-testing:MurdlIOSUITests -resultBundlePath "$OUT/$name.xcresult" -quiet
  xcrun xcresulttool export attachments --path "$OUT/$name.xcresult" --output-path "$folder" >/dev/null
  python3 - "$folder" "$name" "$landscape" <<'PY'
import json, os, sys, subprocess
folder, name, landscape = sys.argv[1:]
for test in json.load(open(f"{folder}/manifest.json")):
    for a in test.get("attachments", []):
        label = (a.get("suggestedHumanReadableName") or a.get("name") or "").split("_")[0].split(".")[0]
        src = f"{folder}/{a['exportedFileName']}"
        if label and os.path.exists(src):
            dst = f"{folder}/murdl-{name}-{label}.png"
            os.rename(src, dst)
            if landscape == "1":
                subprocess.run(["sips", "-r", "-90", dst, "--out", dst], capture_output=True)
os.remove(f"{folder}/manifest.json")
PY
  ls "$folder"
}
capture ipad "$IPAD" 1 Screenshots/iPad
capture iphone "$IPHONE" 0 Screenshots/iPhone
