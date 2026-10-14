@echo off
setlocal
cd /d "%~dp0"
title BY TRXP - Local Web Dashboard
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Start-BY-TRXP-WebDashboard.ps1"
if errorlevel 1 (
  echo.
  echo BY TRXP Dashboard failed to start. Check BY_TRXP_WebDashboard.log.
  pause
)
endlocal
