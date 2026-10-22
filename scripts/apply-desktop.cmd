@echo off
rem ============================================================
rem  双击这个文件 = 真正执行接入（等价于 link-to-profile.cmd -Apply）
rem  前提：DeepSeek Harness 已完全退出（含托盘图标）
rem  如果 pnpm 报错（联网/锁文件），改在命令行跑：
rem      link-to-profile.cmd -Apply -NoInstall
rem ============================================================
setlocal
cd /d "%~dp0"
echo.
echo 即将改写 desktop profile：依赖 -> file:、bundles 补回 dsh-purge、删掉 4 行 disabled，然后跑 pnpm install。
echo 会自动备份到 ^<DSH_HOME^>\_backups\purge-local-^<时间戳^>\
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0link-to-profile.ps1" -Apply %*
echo.
echo ---- 结束，按任意键关闭 ----
pause >nul
