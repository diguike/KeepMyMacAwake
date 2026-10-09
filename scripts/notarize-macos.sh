#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGN_IDENTITY:?Set a Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set the name of an existing local notarytool keychain profile}"
if [[ "$SIGN_IDENTITY" == - ]]; then echo 'Developer ID signing is required' >&2; exit 1; fi
CONFIGURATION=release ./scripts/build-macos.sh
app="$PWD/dist/KeepMyMacAwake.app"
ditto -c -k --keepParent "$app" dist/KeepMyMacAwake-notary.zip
xcrun notarytool submit dist/KeepMyMacAwake-notary.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose "$app"
ditto -c -k --keepParent "$app" dist/KeepMyMacAwake.zip
