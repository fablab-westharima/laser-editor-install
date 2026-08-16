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
cd /d "%~dp0"

if not exist "%~dp0install.ps1" (
  echo [NG] install.ps1 not found next to this file.
  echo      Extract the downloaded zip first, then run install.bat from the
  echo      extracted folder.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
  echo [NG] Setup did not finish. Please show the messages above to your contact.
)
pause
exit /b %RC%
