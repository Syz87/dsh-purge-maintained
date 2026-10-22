<#
.SYNOPSIS
  把某个 dsh profile 的 dsh-purge 依赖指向本地维护副本（E:\YX\AI\XM\dsh-purge）。

.DESCRIPTION
  上游 YuJunZhiXue/dsh-purge 已删库，原来的 github: / master.tar.gz 依赖无法再安装。
  本脚本做三件事（默认只预演，不加 -Apply 不落盘）：
    1) dependencies["dsh-purge"] = "file:E:/YX/AI/XM/dsh-purge"
    2) dsh.profile.bundles 里补回 "dsh-purge"
    3) cordis.patch.yml 里删掉针对 dsh-purge 四个 entry 的 `disabled: true` 行
  执行前会备份 package.json / pnpm-lock.yaml / cordis.patch.yml 到 $DSH_HOME\_backups。

  要求：DeepSeek Harness 必须完全退出（宿主运行期间 pnpm 拿不到 package.json.lock）。

.EXAMPLE
  .\link-to-profile.ps1                 # 预演，只打印将要做的改动
  .\link-to-profile.ps1 -Apply          # 真正落盘并跑 pnpm install
  .\link-to-profile.ps1 -Profile web -Apply
#>
[CmdletBinding()]
param(
  [ValidateSet('desktop', 'web')]
  [string]$Profile = 'desktop',
  [string]$PluginDir = 'E:\YX\AI\XM\dsh-purge',
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host "   $msg" }
function Write-Warn2($msg) { Write-Host "   ! $msg" -ForegroundColor Yellow }

# ---------- 0. 环境 ----------
$dshHome = $env:DSH_HOME
if (-not $dshHome) { $dshHome = 'E:\DevTools\dsh-home' }
$profileDir = Join-Path $dshHome "profiles\$Profile"
$pkgPath = Join-Path $profileDir 'package.json'
$lockPath = Join-Path $profileDir 'pnpm-lock.yaml'
$patchPath = Join-Path $profileDir 'cordis.patch.yml'

Write-Step "目标 profile: $Profile ($profileDir)"
foreach ($p in @($pkgPath, $patchPath)) {
  if (-not (Test-Path $p)) { Write-Warn2 "缺少文件：$p"; exit 2 }
}
if (-not (Test-Path (Join-Path $PluginDir 'package.json'))) { Write-Warn2 "维护副本不完整：$PluginDir"; exit 2 }

# ---------- 1. 守卫：DSH 必须已退出 ----------
Write-Step '检查 DeepSeek Harness 进程'
$procs = @(Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue)
if ($procs.Count -gt 0) {
  Write-Warn2 "仍有 $($procs.Count) 个 DeepSeek Harness 进程（PID: $(($procs | ForEach-Object Id) -join ', ')）"
  Write-Warn2 '请先完全退出 DeepSeek Harness，再重新运行本脚本。'
  exit 1
}
Write-Info '没有运行中的宿主进程，可以继续。'

# ---------- 2. 算改动 ----------
Write-Step '计算改动'
$pkgRaw = Get-Content $pkgPath -Raw -Encoding UTF8
$pkg = $pkgRaw | ConvertFrom-Json
if (-not $pkg.dependencies) { $pkg | Add-Member -NotePropertyName dependencies -NotePropertyValue ([pscustomobject]@{}) -Force }
$oldDep = $pkg.dependencies.'dsh-purge'
$newDep = 'file:E:/YX/AI/XM/dsh-purge'
Write-Info "dependencies['dsh-purge']: $oldDep -> $newDep"

$bundles = @()
if ($pkg.dsh -and $pkg.dsh.profile -and $pkg.dsh.profile.bundles) { $bundles = @($pkg.dsh.profile.bundles) }
$hasBundle = $bundles -contains 'dsh-purge'
Write-Info "bundles 含 dsh-purge: $hasBundle"

$patchRaw = Get-Content $patchPath -Raw -Encoding UTF8
$purgeRows = [regex]::Matches($patchRaw, '(?m)^-\s*id:\s*dsh-purge(?:-redteam(?:-store|-ui)?)?\s*\r?\n\s*disabled:\s*true\s*\r?\n')
Write-Info "cordis.patch.yml 里 dsh-purge 的 disabled 行: $($purgeRows.Count) 处"

if (-not $Apply) {
  Write-Step '预演结束（未落盘）'
  Write-Info '确认无误后加 -Apply 重新运行。'
  return
}

# ---------- 3. 备份 ----------
Write-Step '备份'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bak = Join-Path $dshHome "_backups\purge-local-$stamp"
New-Item -ItemType Directory -Force -Path $bak | Out-Null
foreach ($f in @($pkgPath, $patchPath)) {
  if (Test-Path $f) { Copy-Item $f (Join-Path $bak (Split-Path $f -Leaf)) -Force }
}
if (Test-Path $lockPath) { Copy-Item $lockPath (Join-Path $bak 'pnpm-lock.yaml') -Force }
Write-Info "已备份到 $bak"

# ---------- 4. 改 package.json ----------
Write-Step '改写 package.json'
$pkg.dependencies | Add-Member -NotePropertyName 'dsh-purge' -NotePropertyValue $newDep -Force
if (-not $hasBundle) {
  if (-not $pkg.dsh) { $pkg | Add-Member -NotePropertyName dsh -NotePropertyValue ([pscustomobject]@{}) -Force }
  if (-not $pkg.dsh.profile) { $pkg.dsh | Add-Member -NotePropertyName profile -NotePropertyValue ([pscustomobject]@{}) -Force }
  $pkg.dsh.profile | Add-Member -NotePropertyName bundles -NotePropertyValue (@($bundles) + 'dsh-purge') -Force
  Write-Info 'bundles 已补回 dsh-purge'
}
$pkgJson = $pkg | ConvertTo-Json -Depth 20
Set-Content -Path $pkgPath -Value $pkgJson -Encoding UTF8
Write-Info "已写入 $pkgPath"

# ---------- 5. 改 cordis.patch.yml ----------
Write-Step '改写 cordis.patch.yml'
$newPatch = [regex]::Replace($patchRaw, '(?m)^-\s*id:\s*dsh-purge(?:-redteam(?:-store|-ui)?)?\s*\r?\n\s*disabled:\s*true\s*\r?\n', '')
if ($newPatch -ne $patchRaw) {
  Set-Content -Path $patchPath -Value $newPatch -Encoding UTF8
  Write-Info '已移除 dsh-purge 的 disabled 行'
} else {
  Write-Info '没有需要移除的 disabled 行'
}

# ---------- 6. pnpm install ----------
Write-Step 'pnpm install'
$exe = 'D:\Program Files\DeepSeek Harness\DeepSeek Harness.exe'
$pnpm = 'D:\Program Files\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\pnpm\bin\pnpm.cjs'
if (-not (Test-Path $exe)) { throw "找不到宿主可执行文件：$exe" }
if (-not (Test-Path $pnpm)) { throw "找不到 pnpm：$pnpm" }
$env:ELECTRON_RUN_AS_NODE = '1'
Push-Location $profileDir
try {
  & $exe --expose-internals $pnpm install --reporter=append-only
  $code = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($code -ne 0) {
  Write-Warn2 "pnpm install 退出码 $code；备份在 $bak，可用它回滚。"
  exit $code
}

# ---------- 7. 回读校验 ----------
Write-Step '回读校验'
$pkg2 = Get-Content $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$dep2 = $pkg2.dependencies.'dsh-purge'
$b2 = @($pkg2.dsh.profile.bundles) -contains 'dsh-purge'
$patch2 = Get-Content $patchPath -Raw -Encoding UTF8
$left = [regex]::Matches($patch2, '(?m)^-\s*id:\s*dsh-purge').Count
Write-Info "依赖 = $dep2"
Write-Info "bundles 含 dsh-purge = $b2"
Write-Info "patch 里剩余 dsh-purge 顶层行 = $left（应为 0）"
$nm = Join-Path $profileDir 'node_modules\dsh-purge\package.json'
if (Test-Path $nm) {
  $v = (Get-Content $nm -Raw -Encoding UTF8 | ConvertFrom-Json).version
  Write-Info "node_modules\dsh-purge 版本 = $v（应为 1.1.71-local.1）"
  if ($v -ne '1.1.71-local.1') { Write-Warn2 '版本不对，可能是 pnpm 复用了旧缓存，试试 install --force' }
} else {
  Write-Warn2 'node_modules\dsh-purge 不存在，安装可能未完成'
}

Write-Step '完成'
Write-Info "备份：$bak"
Write-Info '现在启动 DeepSeek Harness，插件应能正常加载（终端不应再出现 patch/unknown prompt variable 报错）。'
