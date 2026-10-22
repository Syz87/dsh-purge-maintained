@echo off
rem Preview only: prints what would change, writes nothing.
rem (Pure ASCII on purpose -- cmd.exe reads .cmd in the OEM codepage,
rem  so any UTF-8 Chinese in here would garble the following lines.)
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0link-to-profile.ps1" %*
echo.
echo [preview] Nothing was written. Press any key to close.
pause >nul