#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This build requires macOS 14+ and Xcode command line tools.' >&2
  exit 1
fi
identity="${SIGN_IDENTITY:--}"
configuration="${CONFIGURATION:-debug}"
case "$configuration" in debug|release) ;; *) echo 'CONFIGURATION must be debug or release' >&2; exit 1;; esac
app="$PWD/dist/KeepMyMacAwake.app"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
swift build -c "$configuration" --product KeepMyMacAwake
bin="$(swift build -c "$configuration" --show-bin-path)"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Library/HelperTools" "$app/Contents/Library/LaunchDaemons"
cp "$bin/KeepMyMacAwake" "$app/Contents/MacOS/KeepMyMacAwake"
cp packaging/info.plist "$app/Contents/Info.plist"
cp packaging/io.github.diguike.KeepMyMacAwake.helper.plist "$app/Contents/Library/LaunchDaemons/"
sign_options=(--force --sign "$identity" --options runtime --timestamp=none)
if [[ "$identity" != - && "$configuration" == release ]]; then
  sign_options=(--force --sign "$identity" --options runtime --timestamp)
fi
# Developer preview uses a requirement it cannot satisfy and disables registration.
# Signed builds pin the app's stable certificate-based designated requirement.
codesign "${sign_options[@]}" "$app"
client_requirement='identifier "io.github.diguike.KeepMyMacAwake" and anchor apple generic'
if [[ "$identity" != - ]]; then
  client_requirement="$(codesign -d -r- "$app" 2>&1 | sed -n 's/^designated => //p')"
  if [[ -z "$client_requirement" || "$client_requirement" == *cdhash* ]]; then
    echo 'A stable certificate-based signing identity is required for the helper.' >&2
    exit 1
  fi
  /usr/libexec/PlistBuddy -c 'Set :AwakeHelperEnabled true' "$app/Contents/Info.plist"
fi
python3 - "$work/helper-info.plist" "$client_requirement" <<'PY'
import plistlib,sys
with open(sys.argv[1], 'wb') as f:
    plistlib.dump({'CFBundleIdentifier':'io.github.diguike.KeepMyMacAwake.helper',
                  'CFBundleVersion':'1','AwakeClientRequirement':sys.argv[2]}, f)
PY
swift build -c "$configuration" --product KeepMyMacAwakeHelper \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$work/helper-info.plist"
cp "$bin/KeepMyMacAwakeHelper" "$app/Contents/Library/HelperTools/KeepMyMacAwakeHelper"
codesign "${sign_options[@]}" --identifier io.github.diguike.KeepMyMacAwake.helper "$app/Contents/Library/HelperTools/KeepMyMacAwakeHelper"
codesign "${sign_options[@]}" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
if [[ "$identity" != - ]]; then
  codesign --verify --strict -R "$client_requirement" "$app"
fi
printf 'Built %s\n' "$app"
if [[ "$identity" == - ]]; then
  echo 'Ad-hoc preview: idle-sleep prevention only. Helper registration requires a certificate-signed build.'
fi
