@echo off
rem 把指定 profile 的 dsh-purge 依赖指向本地维护副本。
rem 双击 = 预演（不落盘）；要真正执行，命令行加 -Apply：
rem     link-to-profile.cmd -Apply
rem     link-to-profile.cmd -Profile web -Apply
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0link-to-profile.ps1" %*
echo.
pause
