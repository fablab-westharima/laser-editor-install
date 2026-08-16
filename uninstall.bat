@echo off
setlocal
rem LaserEditor uninstaller launcher for Windows.
rem Double-clicking this removes the app and keeps your data.
rem
rem ASCII only, CRLF, no BOM -- see install.bat for why. The Japanese messages
rem are printed by uninstall.ps1.
rem
rem To see what would be removed without removing anything, run:
rem   uninstall.bat -DryRun
cd /d "%~dp0"

if not exist "%~dp0uninstall.ps1" (
  echo [NG] uninstall.ps1 not found next to this file.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
