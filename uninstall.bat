@echo off
rem LaserEditor uninstaller launcher - Windows.
rem これをダブルクリックすると、アプリを外してデータは残します。
rem 何が消えて何が残るかだけ見たいときは、末尾に -DryRun を付けて実行します:
rem   powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1 -DryRun
setlocal
cd /d "%~dp0"
if not exist "%~dp0uninstall.ps1" (
  echo NG: uninstall.ps1 が見つかりません。
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
set RC=%ERRORLEVEL%
echo.
pause
exit /b %RC%
