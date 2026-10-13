#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
dotnet_bin="${AWAKE_DOTNET:-dotnet}"
if ! command -v "$dotnet_bin" >/dev/null; then
  echo 'Install .NET 10 SDK or set AWAKE_DOTNET to its dotnet executable.' >&2
  exit 1
fi
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export PATH="$(dirname "$(command -v "$dotnet_bin")"):$PATH"
swift test
"$dotnet_bin" test windows/tests/Awake.Core.Tests.csproj -c Release --nologo
"$dotnet_bin" run --project windows/service-tests/Awake.Service.Tests.csproj -c Release
"$dotnet_bin" build windows/KeepMyMacAwake.slnx -c Release --nologo
git diff --check
echo 'Local logic/build checks passed. Windows WPF execution and device checks require Windows.'
