param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Release',
    [ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
[xml]$project = Get-Content 'windows/app/Awake.App.csproj'
$version = $project.Project.PropertyGroup.Version
$stage = Join-Path (Get-Location) "dist/windows/$Runtime"
$app = Join-Path $stage 'app'
if (Test-Path $app) { throw "Move or remove the previous $app before packaging a clean build." }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
# Do not install or include the unfinished service in the user package.
dotnet build windows/service/Awake.Service.csproj -c $Configuration --nologo
if ($LASTEXITCODE -ne 0) { throw 'Service build failed' }
dotnet publish windows/app/Awake.App.csproj -c $Configuration -r $Runtime --self-contained true '-p:PublishSingleFile=false' '-p:PublishTrimmed=false' -o $app --nologo
if ($LASTEXITCODE -ne 0) { throw 'App publish failed' }
Copy-Item 'windows/packaging/INSTALL.txt' (Join-Path $app '安装说明.txt')
Copy-Item 'LICENSE' (Join-Path $app 'LICENSE.txt')
$name = "KeepMyMacAwake-$version-Windows-$($Runtime.Replace('win-', ''))-preview.zip"
$artifact = Join-Path $stage $name
Compress-Archive -Path "$app/*" -DestinationPath $artifact -Force
$hash = (Get-FileHash $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content (Join-Path $stage 'SHA256SUMS.txt') "$hash  $name" -Encoding ascii
Write-Host "Built unsigned, unverified preview: $artifact"
