@echo off
setlocal
cd /d "%~dp0"
title BY TRXP - Build Web Dashboard EXE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-WebDashboard-EXE.ps1"
if errorlevel 1 (
  echo.
  echo BUILD FAILED. Read the error above.
) else (
  echo.
  echo Check for BY_TRXP_WebDashboard.exe in this folder.
)
echo.
pause
endlocal
