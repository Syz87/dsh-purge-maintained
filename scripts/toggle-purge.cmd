@echo off
rem Toggle dsh-purge on/off by adding or removing it from dsh.profile.bundles.
rem Requires DeepSeek Harness to be fully closed. Restart DSH to apply.
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0toggle-purge.ps1" %*
echo.
echo [done] Press any key to close.
pause >nul