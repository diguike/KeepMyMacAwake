#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGN_IDENTITY:?Set a certificate signing identity}"
if [[ "$SIGN_IDENTITY" == - ]]; then echo 'A certificate signature is required for this preview package.' >&2; exit 1; fi
ARCHITECTURES='arm64 x86_64' CONFIGURATION=release ./scripts/build-macos.sh
app="$PWD/dist/KeepMyMacAwake.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
output="$PWD/dist/releases"
work="$(mktemp -d)"
mounted=0
cleanup() {
  if [[ "$mounted" == 1 ]]; then
    if ! hdiutil detach "$work/mounted" >/dev/null; then
      echo 'Could not detach the verification image; retaining its temporary directory.' >&2
      return 1
    fi
  fi
  rm -r "$work"
}
trap cleanup EXIT
mkdir -p "$output" "$work/KeepMyMacAwake-$version" "$work/mounted"
stage="$work/KeepMyMacAwake-$version"
ditto "$app" "$stage/KeepMyMacAwake.app"
cp packaging/INSTALL.txt "$stage/安装说明.txt"
cp LICENSE "$stage/LICENSE.txt"
zip="$output/KeepMyMacAwake-$version-macOS-universal.zip"
dmg="$output/KeepMyMacAwake-$version-macOS-universal.dmg"
ditto -c -k --sequesterRsrc --keepParent "$stage" "$zip"
ln -s /Applications "$stage/Applications"
hdiutil create -ov -volname "KeepMyMacAwake $version" -srcfolder "$stage" -format UDZO "$dmg"
hdiutil verify "$dmg"
hdiutil attach -readonly -nobrowse -mountpoint "$work/mounted" "$dmg" >/dev/null
mounted=1
mounted_app="$work/mounted/KeepMyMacAwake.app"
codesign --verify --deep --strict --all-architectures "$mounted_app"
xcrun lipo "$mounted_app/Contents/MacOS/KeepMyMacAwake" -verify_arch arm64 x86_64
xcrun lipo "$mounted_app/Contents/Library/HelperTools/KeepMyMacAwakeHelper" -verify_arch arm64 x86_64
hdiutil detach "$work/mounted" >/dev/null
mounted=0
ditto -x -k "$zip" "$work/unzipped"
codesign --verify --deep --strict --all-architectures "$work/unzipped/KeepMyMacAwake-$version/KeepMyMacAwake.app"
(
  cd "$output"
  shasum -a 256 "$(basename "$dmg")" "$(basename "$zip")" > SHA256SUMS.txt
)
printf 'Verified release packages in %s\n' "$output"
