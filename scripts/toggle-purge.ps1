<#
.SYNOPSIS
  开 / 关 dsh-purge 插件（改 profile 的 dsh.profile.bundles 成员）。

.DESCRIPTION
  DSH 没有插件级的运行时开关：宿主的设置页里没有 dsh-purge 条目，插件自身也只提供
  「清洗页的 应用 / 卸载」（那是提示词补丁层，不是插件的加载开关）。
  真正决定"这次启动加不加载它"的是 profile package.json 里 dsh.profile.bundles 是否含 "dsh-purge"。
  所以本脚本做的就是增删那一行，改完必须重启 DSH 才生效。

  要求：DeepSeek Harness 必须完全退出（package.json.lock 被宿主占用）。

.EXAMPLE
  .\toggle-purge.ps1              # 切换：开着就关，关着就开（默认）
  .\toggle-purge.ps1 -Set off     # 强制关闭
  .\toggle-purge.ps1 -Set on      # 强制开启
  .\toggle-purge.ps1 -Profile web -Set off
#>
[CmdletBinding()]
param(
  [ValidateSet('desktop', 'web')]
  [string]$Profile = 'desktop',
  [ValidateSet('toggle', 'on', 'off')]
  [string]$Set = 'toggle'
)

$ErrorActionPreference = 'Stop'
try {
  chcp 65001 > $null
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

function Write-Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Write-Info($m) { Write-Host "   $m" }
function Write-Warn2($m) { Write-Host "   ! $m" -ForegroundColor Yellow }

$dshHome = $env:DSH_HOME
if (-not $dshHome) { $dshHome = 'E:\DevTools\dsh-home' }
$profileDir = Join-Path $dshHome "profiles\$Profile"
$pkgPath = Join-Path $profileDir 'package.json'

Write-Step "目标：$Profile"
if (-not (Test-Path $pkgPath)) { Write-Warn2 "找不到 $pkgPath"; exit 2 }

Write-Step '检查 DeepSeek Harness 进程'
$procs = @(Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue)
if ($procs.Count -gt 0) {
  Write-Warn2 "仍有 $($procs.Count) 个进程（PID: $(($procs | ForEach-Object Id) -join ', ')）"
  Write-Warn2 '请先完全退出 DeepSeek Harness，再运行本脚本。'
  exit 1
}
Write-Info '宿主已退出，可以改。'

Write-Step '当前状态'
$raw = [System.IO.File]::ReadAllText($pkgPath)
$pkg = $raw | ConvertFrom-Json
$bundles = @($pkg.dsh.profile.bundles)
$has = $bundles -contains 'dsh-purge'
Write-Info "bundles 总数 = $($bundles.Count)"
Write-Info "含 dsh-purge = $has（当前$(if ($has) { '开启' } else { '关闭' })）"

$want = switch ($Set) {
  'on' { $true }
  'off' { $false }
  default { -not $has }
}
if ($want -eq $has) {
  Write-Step '无需改动'
  Write-Info "已经是「$(if ($has) { '开启' } else { '关闭' })」状态。"
  return
}

$bak = Join-Path $dshHome "_backups\toggle-purge-$Profile-$(Get-Date -Format yyyyMMdd-HHmmss)"
New-Item -ItemType Directory -Force -Path $bak | Out-Null
Copy-Item $pkgPath (Join-Path $bak 'package.json') -Force
Write-Info "已备份到 $bak"

$noBom = New-Object System.Text.UTF8Encoding($false)
$new = $raw

if ($want) {
  # 插入：挪到 bundles 数组最后一项之后
  $lines = $new -split "`n"
  $inB = $false; $last = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '"bundles"\s*:\s*\[') { $inB = $true; continue }
    if ($inB) {
      if ($lines[$i] -match '^\s*\]') { break }
      if ($lines[$i] -match '^\s*"') { $last = $i }
    }
  }
  if ($last -lt 0) { Write-Warn2 '没定位到 bundles 数组，放弃改动'; exit 3 }
  $indent = ([regex]::Match($lines[$last], '^(\s*)')).Groups[1].Value
  $cr = if ($lines[$last].EndsWith("`r")) { "`r" } else { "" }
  if (-not $lines[$last].TrimEnd().EndsWith(',')) { $lines[$last] = $lines[$last].TrimEnd() + ',' + $cr }
  $ins = $indent + '"dsh-purge"' + $cr
  $new = (@($lines[0..$last]) + @($ins) + @($lines[($last + 1)..($lines.Count - 1)])) -join "`n"
  Write-Step '已加入 bundles'
} else {
  # 删除：先试"最后一项"（前面有逗号），再试"中间项"（自身带逗号）
  $p1 = '(?m),\s*\r?\n(\s*)"dsh-purge"\s*\r?\n'
  $p2 = '(?m)^(\s*)"dsh-purge"\s*,\s*\r?\n'
  if ([regex]::IsMatch($new, $p1)) {
    $new = [regex]::Replace($new, $p1, "`r`n")
    Write-Step '已从 bundles 移除（末项）'
  } elseif ([regex]::IsMatch($new, $p2)) {
    $new = [regex]::Replace($new, $p2, '')
    Write-Step '已从 bundles 移除（中间项）'
  } else {
    Write-Warn2 '正则没匹配到，放弃改动'; exit 3
  }
}

[System.IO.File]::WriteAllText($pkgPath, $new, $noBom)
$b = [System.IO.File]::ReadAllBytes($pkgPath)
if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) {
  [System.IO.File]::WriteAllText($pkgPath, $new, $noBom)
  Write-Warn2 '检测到 BOM 已重写为无 BOM'
}

Write-Step '回读校验'
$pkg2 = Get-Content $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$b2 = @($pkg2.dsh.profile.bundles)
$has2 = $b2 -contains 'dsh-purge'
Write-Info "bundles 总数 = $($b2.Count)"
Write-Info "含 dsh-purge = $has2 -> 现在$(if ($has2) { '开启' } else { '关闭' })"
Write-Info "依赖仍为 = $($pkg2.dependencies.'dsh-purge')"
if ($has2 -ne $want) { Write-Warn2 '改动未生效，请检查 package.json'; exit 3 }

Write-Step '完成'
Write-Info '启动 DeepSeek Harness 后生效（插件装配在启动时解析）。'
if ($has2) { Write-Info '关闭方式：再跑一次本脚本，或双击桌面「开关dsh-purge」图标。' }
