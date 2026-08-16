@echo off
setlocal
rem LaserEditor installer launcher for Windows.
rem
rem ASCII only, CRLF, no BOM -- on purpose. cmd.exe reads a .bat in the OEM
rem code page (932 on a Japanese Windows), where a UTF-8 Japanese line ends on
rem a DBCS lead byte that swallows the newline and merges the next line into
rem it. Every human-facing Japanese message lives in install.ps1, which
rem PowerShell reads as UTF-8 because that file carries a BOM.
rem
rem This launcher exists because a .ps1 is blocked from running by default.
rem
rem Automation interface:
rem   LASER_NONINTERACTIVE=1  skip the pause and return the exit code at once.
rem   LASER_IMAGE_TAG         image tag to seed a NEW .env with (install.ps1).
rem   LASER_IMAGE_DIGEST      image digest to seed a NEW .env with.
rem Set none of them and this behaves exactly as it did for a double-click.
rem The pause is what keeps the window open long enough to read the result, so
rem it stays; only an explicit opt-out removes it. Redirecting stdin does not
rem work -- cmd.exe's pause does not read it (measured on Windows 2026-08-16).
cd /d "%~dp0"

if not exist "%~dp0install.ps1" (
  echo [NG] install.ps1 not found next to this file.
  echo      Extract the downloaded zip first, then run install.bat from the
  echo      extracted folder.
  if not "%LASER_NONINTERACTIVE%"=="1" pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
  echo [NG] Setup did not finish. Please show the messages above to your contact.
)
if not "%LASER_NONINTERACTIVE%"=="1" pause
exit /b %RC%
