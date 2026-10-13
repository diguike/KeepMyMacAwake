#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
dotnet_bin="${AWAKE_DOTNET:-dotnet}"
configuration="${CONFIGURATION:-Release}"
runtime="${AWAKE_WINDOWS_RUNTIME:-win-x64}"
case "$configuration" in Debug|Release) ;; *) echo 'CONFIGURATION must be Debug or Release' >&2; exit 1;; esac
case "$runtime" in win-x64|win-arm64) ;; *) echo 'AWAKE_WINDOWS_RUNTIME must be win-x64 or win-arm64' >&2; exit 1;; esac
version="$(python3 - <<'PY'
import xml.etree.ElementTree as E
print(E.parse('windows/app/Awake.App.csproj').findtext('.//Version'))
PY
)"
stage="$PWD/dist/windows/$runtime"
mkdir -p "$stage"
if [[ -e "$stage/app" ]]; then
  echo "Remove or move the previous $stage/app before packaging a clean build." >&2
  exit 1
fi
# Service is compiled for developers but never installed or included in the user ZIP.
"$dotnet_bin" build windows/service/Awake.Service.csproj -c "$configuration" --nologo
"$dotnet_bin" publish windows/app/Awake.App.csproj -c "$configuration" -r "$runtime" --self-contained true \
  -p:PublishSingleFile=false -p:PublishTrimmed=false -o "$stage/app" --nologo
cp windows/packaging/INSTALL.txt "$stage/app/安装说明.txt"
cp LICENSE "$stage/app/LICENSE.txt"
python3 - "$stage" "$version" "$runtime" <<'PY'
from pathlib import Path
import hashlib,sys,zipfile
stage,version,runtime=Path(sys.argv[1]),sys.argv[2],sys.argv[3]
artifact=stage/f'KeepMyMacAwake-{version}-Windows-{runtime[4:]}-preview.zip'
with zipfile.ZipFile(artifact,'w',zipfile.ZIP_DEFLATED) as package:
    for path in sorted((stage/'app').rglob('*')):
        if path.is_file(): package.write(path,Path(f'KeepMyMacAwake-{version}')/path.relative_to(stage/'app'))
with zipfile.ZipFile(artifact) as package:
    bad=package.testzip()
    if bad: raise SystemExit(f'ZIP integrity failure: {bad}')
checksum=hashlib.sha256(artifact.read_bytes()).hexdigest()
(stage/'SHA256SUMS.txt').write_text(f'{checksum}  {artifact.name}\n')
print(f'Built unsigned, unverified preview: {artifact}')
PY
