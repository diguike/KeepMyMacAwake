param([ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$stage = Join-Path (Get-Location) "dist/windows/$Runtime"
$app = Join-Path $stage 'app'
[xml]$project = Get-Content 'windows/app/Awake.App.csproj'
$version = [string]$project.Project.PropertyGroup.Version
$zip = Join-Path $stage "KeepMyMacAwake-$version-Windows-$($Runtime.Replace('win-', ''))-preview.zip"
$installer = Join-Path $stage "KeepMyMacAwake-$version-Windows-$($Runtime.Replace('win-', ''))-setup-preview.exe"
foreach ($path in @($zip, $installer)) {
    if (-not (Test-Path $path)) { throw "Missing package: $path" }
}
$expectedChecksums = @{}
foreach ($line in Get-Content (Join-Path $stage 'SHA256SUMS.txt')) {
    if ($line -notmatch '^([0-9a-f]{64})  ([^/\\]+)$') { throw 'Invalid checksum line' }
    $checksum, $name = $Matches[1], $Matches[2]
    if ($expectedChecksums.ContainsKey($name)) { throw 'Duplicate checksum entry' }
    $expectedChecksums[$name] = $checksum
    if ((Get-FileHash (Join-Path $stage $name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $checksum) { throw "Checksum mismatch: $name" }
}
foreach ($path in @($zip, $installer)) {
    if (-not $expectedChecksums.ContainsKey((Split-Path $path -Leaf))) { throw 'Package missing from checksum file' }
}
$temporary = Join-Path ([IO.Path]::GetTempPath()) ("keepmymacawake-verify-" + [guid]::NewGuid().ToString('N'))
try {
    Expand-Archive -LiteralPath $zip -DestinationPath $temporary
    $unpacked = Join-Path $temporary "KeepMyMacAwake-$version"
    # PowerShell ZIPs use the app files as the archive root; shell ZIPs wrap them.
    if (-not (Test-Path $unpacked)) { $unpacked = $temporary }
    foreach ($file in Get-ChildItem -LiteralPath $app -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($app, $file.FullName)
        $copy = Join-Path $unpacked $relative
        if (-not (Test-Path $copy) -or (Get-FileHash $copy).Hash -ne (Get-FileHash $file.FullName).Hash) { throw "ZIP payload mismatch: $relative" }
    }
    foreach ($name in @('coreclr.dll', '安装说明.txt', 'LICENSE.txt')) {
        if (-not (Test-Path (Join-Path $unpacked $name))) { throw "Missing payload: $name" }
    }
    if (Get-ChildItem -LiteralPath $unpacked -Recurse -File | Where-Object { $_.Name -like 'Awake.Service*' }) { throw 'Unfinished service present in user package' }
    $executable = [IO.File]::ReadAllBytes((Join-Path $unpacked 'KeepMyMacAwake.Windows.exe'))
    $pe = [BitConverter]::ToInt32($executable, 0x3c)
    $expectedMachine = if ($Runtime -eq 'win-x64') { 0x8664 } else { 0xaa64 }
    if ([BitConverter]::ToUInt32($executable, $pe) -ne 0x4550 -or [BitConverter]::ToUInt16($executable, $pe + 4) -ne $expectedMachine) { throw 'App PE architecture mismatch' }
    if ([BitConverter]::ToUInt16($executable, $pe + 24 + 68) -ne 2) { throw 'App is not a GUI executable' }
    foreach ($path in @((Join-Path $unpacked 'KeepMyMacAwake.Windows.exe'), $installer)) {
        if (-not [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($path)).Contains('level="asInvoker"')) { throw "Expected asInvoker manifest: $path" }
    }
}
finally { Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue }
$metadata = [ordered]@{
    version = $version
    runtime = $Runtime
    sourceCommit = $env:GITHUB_SHA
    runUrl = if ($env:GITHUB_RUN_ID) { "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID" } else { $null }
    sdk = (dotnet --version)
    signed = $false
    validation = 'Core/protocol checks, WPF injection and off-screen renders, ZIP payload/PE/manifest/SHA256. No physical power/lid or ordinary-user installation acceptance.'
    checksums = $expectedChecksums
}
$metadata | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $stage 'build-info.json') -Encoding utf8
Write-Host "Verified $Runtime ZIP payload, GUI/architecture/asInvoker, service exclusion and package checksums."
