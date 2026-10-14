# BY TRXP Local Web Dashboard - public bootstrapper
# Downloads the public ZIP, installs its files under LocalAppData, then starts the dashboard.
$ErrorActionPreference = 'Stop'
$repoBase = 'https://raw.githubusercontent.com/thananthonn27-ops/TRXP-LocalWebDashboard/main'

$repoBase = 'https://raw.githubusercontent.com/thananthonn27-ops/BY-TRXP-LocalWebDashboard/main'
$zipUrl = "$repoBase/BY_TRXP_LocalWebDashboard_FIVEM_ApplyOnly_FixINI.zip"
$installRoot = Join-Path $env:LOCALAPPDATA 'BY-TRXP\LocalWebDashboard'
$workRoot = Join-Path $env:TEMP ('BYTRXP-Install-' + [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $workRoot 'package.zip'
$stagePath = Join-Path $workRoot 'extract'

try {
    New-Item -ItemType Directory -Path $stagePath -Force | Out-Null
    Write-Host 'BY TRXP: Downloading public package...' -ForegroundColor Cyan
    Invoke-WebRequest -UseBasicParsing -Uri $zipUrl -OutFile $zipPath

    $download = Get-Item -LiteralPath $zipPath
    if ($download.Length -lt 500000) {
        throw 'The package ZIP is missing or incomplete. Upload the ZIP to the repository root first.'
    }

    Write-Host 'BY TRXP: Extracting package...' -ForegroundColor Cyan
    Expand-Archive -LiteralPath $zipPath -DestinationPath $stagePath -Force

    $launcher = Get-ChildItem -LiteralPath $stagePath -Filter 'Open-Dashboard.bat' -File -Recurse |
        Select-Object -First 1
    if (-not $launcher) {
        throw 'Open-Dashboard.bat was not found inside the downloaded package.'
    }

    $packageRoot = Split-Path -Parent $launcher.FullName
    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    Copy-Item -Path (Join-Path $packageRoot '*') -Destination $installRoot -Recurse -Force

    $installedLauncher = Join-Path $installRoot 'Open-Dashboard.bat'
    if (-not (Test-Path -LiteralPath $installedLauncher -PathType Leaf)) {
        throw 'The dashboard launcher was not installed.'
    }

    Write-Host "BY TRXP installed to: $installRoot" -ForegroundColor Green
    Write-Host 'Starting dashboard...' -ForegroundColor Cyan
    Start-Process -FilePath $env:ComSpec -ArgumentList ('/c "' + $installedLauncher + '"') -WorkingDirectory $installRoot
}
catch {
    Write-Host ('BY TRXP launch failed: ' + $_.Exception.Message) -ForegroundColor Red
    throw
}
finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
