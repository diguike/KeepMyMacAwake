#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
runtime="${AWAKE_WINDOWS_RUNTIME:-win-x64}"
case "$runtime" in win-x64|win-arm64) ;; *) echo 'AWAKE_WINDOWS_RUNTIME must be win-x64 or win-arm64' >&2; exit 1;; esac
nsis="${AWAKE_MAKENSIS:-makensis}"
command -v "$nsis" >/dev/null || { echo 'Install NSIS or set AWAKE_MAKENSIS to makensis.' >&2; exit 1; }
stage="$PWD/dist/windows/$runtime"
[[ -f "$stage/app/KeepMyMacAwake.Windows.exe" ]] || { echo 'Run scripts/build-windows.sh first.' >&2; exit 1; }
version="$(python3 - <<'PY'
import xml.etree.ElementTree as E
print(E.parse('windows/app/Awake.App.csproj').findtext('.//Version'))
PY
)"
artifact="$stage/KeepMyMacAwake-$version-Windows-${runtime#win-}-setup-preview.exe"
filelist="$(mktemp)"
trap 'rm -f "$filelist"' EXIT
python3 - "$stage/app" "$filelist" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
def quote(path):
    return str(path).replace('/', '\\').replace('$', '$$').replace('"', '$\\"')
lines=[f'Delete "$INSTDIR\\{quote(p.relative_to(root))}"' for p in sorted(root.rglob('*')) if p.is_file()]
lines += [f'RMDir "$INSTDIR\\{quote(p.relative_to(root))}"' for p in sorted(root.rglob('*'), key=lambda p: len(p.parts), reverse=True) if p.is_dir()]
Path(sys.argv[2]).write_text('\n'.join(lines)+'\n')
PY
"$nsis" -V2 "-DAPPDIR=$stage/app" "-DOUTPUT=$artifact" "-DVERSION=$version" "-DRUNTIME=$runtime" "-DFILELIST=$filelist" windows/packaging/installer.nsi
python3 - "$artifact" "$stage/SHA256SUMS.txt" <<'PY'
from pathlib import Path
import hashlib,sys
artifact,sums=map(Path,sys.argv[1:])
lines=[line for line in sums.read_text().splitlines() if not line.endswith('  '+artifact.name)] if sums.exists() else []
lines.append(hashlib.sha256(artifact.read_bytes()).hexdigest()+'  '+artifact.name)
sums.write_text('\n'.join(lines)+'\n')
print('Built unsigned installer; Windows execution still required: '+str(artifact))
PY
