$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$source = Join-Path $PSScriptRoot 'Start-BY-TRXP-WebDashboard.ps1'
$output = Join-Path $PSScriptRoot 'BY_TRXP_WebDashboard.exe'
try {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing source: $source" }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
    }
    if (-not (Get-Module -ListAvailable -Name ps2exe)) { Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber }
    Import-Module ps2exe -Force -ErrorAction Stop
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
    Invoke-PS2EXE -InputFile $source -OutputFile $output -STA -NoConsole -Title 'BY TRXP Local Web Dashboard' -Product 'BY TRXP Web Dashboard' -Description 'Local-only BY TRXP Dashboard with PC specs, Mouse/Keyboard REG, Network, TRXP Power Plan, RAMMap, Cleaner and Restore' -Company 'BY TRXP' -Version '2.3.0.0' -requireAdmin
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) { throw 'PS2EXE completed without creating the EXE.' }
    Write-Host "SUCCESS: $output" -ForegroundColor Green
    Write-Host 'Keep dashboard.html, assets folder, both REG files, RAMMap executables and FilterKeysSetter.exe beside the EXE.' -ForegroundColor Yellow
    exit 0
} catch {
    Write-Host "BUILD FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Try again on Windows 10/11 with internet access. Build uses the PS2EXE module.' -ForegroundColor Yellow
    exit 1
}
