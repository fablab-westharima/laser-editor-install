@echo off
rem LaserEditor installer launcher - Windows.
rem これをダブルクリックしてください。実体は install.ps1 です。
rem （PowerShell スクリプトは既定では実行が止められるため、この 1 枚を経由します）
setlocal
cd /d "%~dp0"
if not exist "%~dp0install.ps1" (
  echo NG: install.ps1 が見つかりません。
  echo     ダウンロードした zip を展開してから、展開先のフォルダにある
  echo     install.bat を実行してください。
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set RC=%ERRORLEVEL%
echo.
if not "%RC%"=="0" (
  echo セットアップは完了していません。上の内容をそのまま担当者に伝えてください。
)
pause
exit /b %RC%
