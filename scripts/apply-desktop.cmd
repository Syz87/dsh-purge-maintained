@echo off
rem Apply: rewrites the desktop profile and installs the maintained copy.
rem (Pure ASCII on purpose -- cmd.exe reads .cmd in the OEM codepage,
rem  so any UTF-8 Chinese in here would garble the following lines.)
setlocal
cd /d "%~dp0"
echo.
echo About to rewrite the desktop profile:
echo   dependency -^> file:, bundles += dsh-purge, remove 4 "disabled" rows
echo   then run pnpm install
echo Backup goes to ^<DSH_HOME^>\_backups\purge-local-^<timestamp^>\
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0link-to-profile.ps1" -Apply %*
echo.
echo [done] Press any key to close.
pause >nul