param([ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64')
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or -not $env:RUNNER_TEMP) { throw 'This registry/install smoke check is only for disposable GitHub-hosted Windows jobs.' }
Set-Location (Split-Path $PSScriptRoot -Parent)
[xml]$project = Get-Content 'windows/app/Awake.App.csproj'
$version = [string]$project.Project.PropertyGroup.Version
$stage = Join-Path (Get-Location) "dist/windows/$Runtime"
$installer = Join-Path $stage "KeepMyMacAwake-$version-Windows-$($Runtime.Replace('win-', ''))-setup-preview.exe"
$installation = Join-Path $env:RUNNER_TEMP ('keepmymacawake smoke ' + [guid]::NewGuid().ToString('N'))
$executable = Join-Path $installation 'KeepMyMacAwake.Windows.exe'
$uninstaller = Join-Path $installation 'uninstall.exe'
$registration = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\KeepMyMacAwake.Windows'
$startupKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$startupName = 'KeepMyMacAwake.Windows'
$checks = [Collections.Generic.List[string]]::new()
function Invoke-Bounded([string]$Path, [string]$Arguments) {
    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -PassThru
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw 'Installer/application process timed out'
    }
    if ($process.ExitCode -ne 0) { throw "Installer/application exit code: $($process.ExitCode)" }
}
function Install-Preview {
    # NSIS /D must be last and unquoted, including paths containing spaces.
    Invoke-Bounded $installer "/S /D=$installation"
    if (-not (Test-Path $executable) -or -not (Test-Path $uninstaller)) { throw 'Installer did not create app and uninstaller' }
    if ((Get-ItemProperty $registration).InstallLocation -ne $installation) { throw 'Uninstall registration has incorrect path' }
    if ((Get-FileHash $executable).Hash -ne (Get-FileHash (Join-Path $stage 'app/KeepMyMacAwake.Windows.exe')).Hash) { throw 'Installed app differs from packaged output' }
}
function Uninstall-Preview {
    Invoke-Bounded $uninstaller '/S'
    # The normal NSIS uninstaller runs a temporary copy; wait for that child too.
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    while ((Test-Path $executable) -or (Test-Path $registration)) {
        if ([DateTime]::UtcNow -ge $deadline) { throw 'Uninstaller did not finish removing app/registration' }
        Start-Sleep -Milliseconds 250
    }
}
try {
    if (Test-Path $registration) { throw 'Unexpected existing installation in CI profile' }
    Install-Preview
    $checks.Add('Silent installation to a path containing spaces; app/hash/uninstall registration')
    Invoke-Bounded $executable '--prepare-update'
    $checks.Add('Packaged updater executes and exits without starting a power session')
    New-Item -Path $startupKey -Force | Out-Null
    New-ItemProperty -Path $startupKey -Name $startupName -Value ('"' + $executable + '" --startup') -PropertyType String -Force | Out-Null
    Install-Preview
    $checks.Add('Silent upgrade confirms the packaged updater before replacing files')
    $kept = Join-Path $installation 'user-kept.txt'
    Set-Content $kept 'Synthetic CI file that the package must preserve'
    Uninstall-Preview
    if ((Get-ItemProperty $startupKey -Name $startupName -ErrorAction SilentlyContinue)) { throw 'Owned startup registration remains after uninstall' }
    if (-not (Test-Path $kept)) { throw 'Uninstaller recursively removed unrelated file' }
    $checks.Add('Uninstall removes owned startup registration and preserves unrelated file')
    Install-Preview
    $foreignStartup = '"C:\unrelated-preview\KeepMyMacAwake.Windows.exe" --startup'
    New-ItemProperty -Path $startupKey -Name $startupName -Value $foreignStartup -PropertyType String -Force | Out-Null
    Uninstall-Preview
    if ((Get-ItemProperty $startupKey).$startupName -ne $foreignStartup) { throw 'Uninstaller removed startup entry for another installation' }
    $checks.Add('Uninstall preserves startup entry belonging to another installation')
    $report = [ordered]@{
        runtime = $Runtime
        sourceCommit = $env:GITHUB_SHA
        checks = $checks.ToArray()
        evidence = 'Real silent installer lifecycle on disposable GitHub Windows host. Host runs as administrator with UAC disabled; not ordinary-user, physical power/lid or interactive GUI acceptance.'
    }
    $reportDirectory = Join-Path $stage 'report'
    New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    $report | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $reportDirectory 'installer-smoke.json') -Encoding utf8
    Write-Host "$($checks.Count) installer lifecycle smoke checks passed on $Runtime."
}
finally {
    if ((Get-ItemProperty $startupKey -Name $startupName -ErrorAction SilentlyContinue)) { Remove-ItemProperty $startupKey -Name $startupName -ErrorAction SilentlyContinue }
    if (Test-Path $installation) { Remove-Item -LiteralPath $installation -Recurse -Force -ErrorAction SilentlyContinue }
}
