param(
    [ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64',
    [string]$Makensis = $env:AWAKE_MAKENSIS
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
if (-not $Makensis) {
    $command = Get-Command makensis -ErrorAction SilentlyContinue
    if ($command) { $Makensis = $command.Source }
    else { $Makensis = Join-Path ${env:ProgramFiles(x86)} 'NSIS/makensis.exe' }
}
if (-not (Test-Path -LiteralPath $Makensis)) { throw 'Install NSIS 3.11+ or set AWAKE_MAKENSIS to makensis.exe.' }
[xml]$project = Get-Content 'windows/app/Awake.App.csproj'
$version = [string]$project.Project.PropertyGroup.Version
$stage = Join-Path (Get-Location) "dist/windows/$Runtime"
$app = Join-Path $stage 'app'
if (-not (Test-Path (Join-Path $app 'KeepMyMacAwake.Windows.exe'))) { throw 'Run scripts/build-windows.ps1 first.' }
$artifact = Join-Path $stage "KeepMyMacAwake-$version-Windows-$($Runtime.Replace('win-', ''))-setup-preview.exe"
$fileList = Join-Path ([IO.Path]::GetTempPath()) ("keepmymacawake-" + [guid]::NewGuid().ToString('N') + '.nsh')
try {
    $lines = @()
    foreach ($file in Get-ChildItem -LiteralPath $app -Recurse -File | Sort-Object FullName) {
        $relative = [IO.Path]::GetRelativePath($app, $file.FullName).Replace('/', '\').Replace('$', '$$').Replace('"', '$\"')
        $lines += 'Delete "$INSTDIR\' + $relative + '"'
    }
    foreach ($directory in Get-ChildItem -LiteralPath $app -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending) {
        $relative = [IO.Path]::GetRelativePath($app, $directory.FullName).Replace('/', '\').Replace('$', '$$').Replace('"', '$\"')
        $lines += 'RMDir "$INSTDIR\' + $relative + '"'
    }
    [IO.File]::WriteAllLines($fileList, [string[]]$lines, [Text.UTF8Encoding]::new($false))
    $prefix = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { '/' } else { '-' }
    $arguments = @("${prefix}V2", "${prefix}INPUTCHARSET", 'UTF8', "${prefix}DAPPDIR=$app",
        "${prefix}DOUTPUT=$artifact", "${prefix}DVERSION=$version", "${prefix}DRUNTIME=$Runtime",
        "${prefix}DFILELIST=$fileList", (Join-Path (Get-Location) 'windows/packaging/installer.nsi'))
    & $Makensis @arguments
    if ($LASTEXITCODE -ne 0) { throw 'NSIS installer build failed' }
    $name = Split-Path $artifact -Leaf
    $sums = Join-Path $stage 'SHA256SUMS.txt'
    $checksums = @(if (Test-Path $sums) { Get-Content $sums | Where-Object { -not $_.EndsWith("  $name") } })
    $checksums += (Get-FileHash $artifact -Algorithm SHA256).Hash.ToLowerInvariant() + "  $name"
    [IO.File]::WriteAllLines($sums, [string[]]$checksums, [Text.Encoding]::ASCII)
    Write-Host "Built unsigned preview installer: $artifact"
}
finally { Remove-Item -LiteralPath $fileList -Force -ErrorAction SilentlyContinue }
