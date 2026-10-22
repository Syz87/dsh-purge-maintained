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

  安装方式二选一：
    - 默认：跑 pnpm install（lockfile 与声明一致，最规范；失败时可用 -NoInstall 兜底）
    - -NoInstall：跳过 pnpm，直接把 node_modules\dsh-purge 换成指向维护目录的 junction
      （零联网、立即生效；代价是 pnpm-lock.yaml 暂时不一致，下次 pnpm install 会覆盖）

.EXAMPLE
  .\link-to-profile.ps1                          # 预演，只打印将要做的改动
  .\link-to-profile.ps1 -Apply                   # 落盘并跑 pnpm install
  .\link-to-profile.ps1 -Apply -NoInstall        # 落盘 + junction 直连（不联网）
  .\link-to-profile.ps1 -Profile web -Apply      # 处理 web profile
#>
[CmdletBinding()]
param(
  [ValidateSet('desktop', 'web')]
  [string]$Profile = 'desktop',
  [string]$PluginDir = 'E:\YX\AI\XM\dsh-purge',
  [switch]$Apply,
  [switch]$NoInstall
)

$ErrorActionPreference = 'Stop'

# 控制台按 UTF-8 输出：否则在 GBK(936) 代码页下中文会显示成乱码
try {
  chcp 65001 > $null
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

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

# ---------- 4. 改 package.json（文本级最小编辑，不做 JSON 往返）----------
Write-Step '改写 package.json'
$noBom = New-Object System.Text.UTF8Encoding($false)
$pkgNew = $pkgRaw

# 4a. 依赖行：只替换 dsh-purge 的值，其他行不碰
$depPattern = '(?m)^(\s*)"dsh-purge"\s*:\s*"[^"]*"\s*,'
if ([regex]::IsMatch($pkgNew, $depPattern)) {
  $repl = '$1"dsh-purge": "' + $newDep + '",'
  $pkgNew = [regex]::Replace($pkgNew, $depPattern, $repl)
  Write-Info "依赖行已替换为 $newDep"
} else {
  Write-Warn2 '在 dependencies 里没找到 dsh-purge 行，请手工改成 file:E:/YX/AI/XM/dsh-purge'
}

# 4b. bundles：在数组最后一项后面补一行
if (-not $hasBundle) {
  $lines = $pkgNew -split "`n"
  $inBundles = $false
  $lastIdx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '"bundles"\s*:\s*\[') { $inBundles = $true; continue }
    if ($inBundles) {
      if ($lines[$i] -match '^\s*\]') { break }
      if ($lines[$i] -match '^\s*"') { $lastIdx = $i }
    }
  }
  if ($lastIdx -ge 0) {
    $indent = ([regex]::Match($lines[$lastIdx], '^(\s*)')).Groups[1].Value
    $cr = if ($lines[$lastIdx].EndsWith("`r")) { "`r" } else { "" }
    if (-not $lines[$lastIdx].TrimEnd().EndsWith(',')) {
      $lines[$lastIdx] = $lines[$lastIdx].TrimEnd() + ',' + $cr
    }
    $insert = $indent + '"dsh-purge"' + $cr
    if ($lastIdx -eq $lines.Count - 1) {
      $lines = @($lines[0..$lastIdx]) + @($insert)
    } else {
      $lines = @($lines[0..$lastIdx]) + @($insert) + @($lines[($lastIdx + 1)..($lines.Count - 1)])
    }
    $pkgNew = $lines -join "`n"
    Write-Info 'bundles 已补回 dsh-purge'
  } else {
    Write-Warn2 '没定位到 bundles 数组末项，请手工在 bundles 里加 "dsh-purge"'
  }
}

[System.IO.File]::WriteAllText($pkgPath, $pkgNew, $noBom)

# 4c. BOM 检查：DSH 的 JSON.parse 不容忍 BOM（历史上有过 crash 记录）
$bytes = [System.IO.File]::ReadAllBytes($pkgPath)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
  Write-Warn2 'package.json 带 BOM，正在按无 BOM 重写（否则 DSH 启动报 Unexpected token）'
  [System.IO.File]::WriteAllText($pkgPath, $pkgNew, $noBom)
}
try {
  $null = [System.IO.File]::ReadAllText($pkgPath) | ConvertFrom-Json
  Write-Info 'package.json JSON 语法校验通过'
} catch {
  Write-Warn2 "package.json 语法校验失败：$($_.Exception.Message)（备份在 $bak，可回滚）"
  exit 3
}

# ---------- 5. 改 cordis.patch.yml ----------
Write-Step '改写 cordis.patch.yml'
$newPatch = [regex]::Replace($patchRaw, '(?m)^-\s*id:\s*dsh-purge(?:-redteam(?:-store|-ui)?)?\s*\r?\n\s*disabled:\s*true\s*\r?\n', '')
if ($newPatch -ne $patchRaw) {
  [System.IO.File]::WriteAllText($patchPath, $newPatch, $noBom)
  Write-Info '已移除 dsh-purge 的 disabled 行'
} else {
  Write-Info '没有需要移除的 disabled 行'
}

# ---------- 6. 安装 ----------
$exe = 'D:\Program Files\DeepSeek Harness\DeepSeek Harness.exe'
$pnpm = 'D:\Program Files\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\pnpm\bin\pnpm.cjs'
$target = Join-Path $profileDir 'node_modules\dsh-purge'

if ($NoInstall) {
  Write-Step '跳过 pnpm：改用 junction 直连维护目录'
  if (Test-Path $target) {
    $item = Get-Item $target -Force
    if ($item.LinkType) {
      cmd /c rmdir "$target" | Out-Null
      Write-Info "已移除旧的链接（$($item.LinkType)）"
    } else {
      Remove-Item $target -Recurse -Force
      Write-Info '已删除旧的实体目录'
    }
  }
  cmd /c mklink /J "$target" "$PluginDir" | Out-Null
  if (Test-Path (Join-Path $target 'package.json')) {
    Write-Info "junction 已建立：$target -> $PluginDir（改维护目录即时生效，无需重装）"
  } else {
    Write-Warn2 'junction 建立失败，请手工执行：mklink /J "<profile>\node_modules\dsh-purge" "E:\YX\AI\XM\dsh-purge"'
  }
  Write-Warn2 '注意：pnpm-lock.yaml 未更新，下次 pnpm install 会把 junction 换回包副本'
} else {
  Write-Step 'pnpm install'
  if (-not (Test-Path $exe)) { Write-Warn2 "找不到宿主可执行文件：$exe"; exit 4 }
  if (-not (Test-Path $pnpm)) { Write-Warn2 "找不到 pnpm：$pnpm"; exit 4 }
  $env:ELECTRON_RUN_AS_NODE = '1'
  # 必须 Start-Process -Wait：直接 & 调用时 Electron 主进程会先返回，pnpm 子进程晚几秒才真正写完
  # node_modules，后面的回读就会读到旧版本（2026-10-22 实际踩到：误报「版本 1.1.71，应为 1.1.71-local.1」）
  $proc = Start-Process -FilePath $exe `
    -ArgumentList @('--expose-internals', "`"$pnpm`"", 'install', '--reporter=append-only') `
    -WorkingDirectory $profileDir -NoNewWindow -Wait -PassThru
  $code = $proc.ExitCode
  if ($code -ne 0) {
    Write-Warn2 "pnpm install 退出码 $code；备份在 $bak，可用它回滚。"
    Write-Warn2 '若失败原因是联网/锁文件，可改用：link-to-profile.cmd -Apply -NoInstall（junction 直连，零联网）'
    exit $code
  }
}

# ---------- 7. 回读校验（轮询等待安装落盘）----------
Write-Step '回读校验'
$pkg2 = Get-Content $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$dep2 = $pkg2.dependencies.'dsh-purge'
$b2 = @($pkg2.dsh.profile.bundles) -contains 'dsh-purge'
$patch2 = Get-Content $patchPath -Raw -Encoding UTF8
$left = [regex]::Matches($patch2, '(?m)^-\s*id:\s*dsh-purge').Count
Write-Info "依赖 = $dep2"
Write-Info "bundles 含 dsh-purge = $b2"
Write-Info "patch 里剩余 dsh-purge 顶层行 = $left（应为 0）"

$expect = (Get-Content (Join-Path $PluginDir 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version
$nm = Join-Path $profileDir 'node_modules\dsh-purge\package.json'
$v = ''
$deadline = (Get-Date).AddSeconds(90)
$waited = 0
do {
  if (Test-Path $nm) { $v = (Get-Content $nm -Raw -Encoding UTF8 | ConvertFrom-Json).version }
  if ($v -eq $expect) { break }
  Start-Sleep -Milliseconds 1500
  $waited++
} while ((Get-Date) -lt $deadline)

if (-not (Test-Path $nm)) {
  Write-Warn2 'node_modules\dsh-purge 不存在，安装可能未完成'
} elseif ($v -eq $expect) {
  Write-Info "node_modules\dsh-purge 版本 = $v（与源一致，等了 ${waited} 轮）"
} else {
  Write-Warn2 "等了 $($waited * 1.5) 秒，node_modules\dsh-purge 版本仍是 $v（源是 $expect）"
  Write-Warn2 '可能是 pnpm 复用了旧缓存，试试 install --force；或改用 -NoInstall（junction 直连）'
}

Write-Step '完成'
Write-Info "备份：$bak"
Write-Info '现在启动 DeepSeek Harness，插件应能正常加载（终端不应再出现 patch/unknown prompt variable 报错）。'
