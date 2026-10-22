# dsh-purge 本地维护版（local fork）

> 上游 `YuJunZhiXue/dsh-purge` 在 GitHub 返回 404（个人主页仍显示该仓库 99 commits，疑似转私有），
> 本目录是基于 1.1.71 的本地维护副本，脱离插件市场独立存在。**不要在市场点升级/重装**，否则会写回
> github 依赖并再次 404，同时覆盖本目录的修复。

- 维护目录：`E:\YX\AI\XM\dsh-purge`
- 本版版本号：`1.1.71-local.1`
- 目标宿主：DeepSeek Harness `0.2.1-rc.2`
- 基线来源：**原样快照** `E:\YX\AI\XM\dsh-purge-original`（v1.1.71，108 文件，
  `package.json` 2502 字节，含 `SHA256SUMS.txt`），已与社区备份 `marspang/DSH-Purge-backup` 交叉核对一致；
  在此基础上叠加 2026-10-18 的 cwdfix 与本次（2026-10-22）的补齐修复。

## 为什么需要本地维护

1. **上游删库**：`package.json` 原本的 `github:` / `master.tar.gz` 依赖全部无法再拉取，`pnpm install` 会 404；
   市场里的"升级"按钮同理。必须改成 `file:` 指向本目录。
2. **`{{cwd}}` 变量已从宿主移除**：DSH `0.2.1-rc.2` 的 `system-prompt` 只注册 `provider` / `model`
   两个提示词变量。任何仍带 `{{cwd}}` 的注入文本都会在**每次组装 system prompt 时抛**
   `unknown prompt variable "{{cwd}}"`，表现为"开启插件后整轮对话直接失败"。
   2026-10-18 的 cwdfix 只修了 `identity.js` 的常量与 `cordis.patch.yml` 的 `personaSuffix`，
   本次补齐其余残留点。

## 本版改了什么

| 文件 | 改动 | 原因 |
| --- | --- | --- |
| `lib/identity.js` | `CWD_ONLY_SUFFIX` 保持 `""`；两处 `stripHarnessPersona` 的 `.replace(...)` 第二参数由 `"Working directory: {{cwd}}. "` 改为 `""` | 这两处会把官方身份里的工作目录句**重新写回**含 `{{cwd}}` 的文本，是最隐蔽的复发点 |
| `lib/core.js` | `ALLOW_EXEC_PERSONA_BLOCK` / `ALLOW_EXEC_PERSONA_LINE` 去掉 `Working directory: {{cwd}}.` 前缀 | 当前未被引用（死代码），但同样是不能留的变量占位符 |
| `cordis.patch.yml` | 删除顶层 `- id: dsh-purge / inject: [...]` | 该行在 insert 之前引用尚不存在的 entry，启动时打印 `patch: entry "dsh-purge" not found` |
| `cordis.patch.yml` | 注释掉 5 条 `redteam-*` 的 `disabled: true` | 本机两个 profile 都没装旧独立红队包，这 5 行只产生 `patch: entry "redteam-xxx" not found` 噪音 |
| `cordis.patch.yml` | `personaSuffix: ""`（沿用 10-18 修复） | 遮蔽官方 `{{cwd}}` 后缀 |
| `package.json` | `version` → `1.1.71-local.1`；`dshTarget` → `0.2.1-rc.2`；`dsh.install` 由 github 链接改为 `file` | 断掉对已删库的依赖，市场不再尝试下载 |

> 保留不改：`isCwdOnlyText()`（`identity.js`）与 `core.js` 中的字符串**判定**分支仍然匹配
> `"Working directory: {{cwd}}."` 字面量——它们只用于识别旧文本并清空，不产生注入，必须保留。

## 接入（把某个 profile 指向本目录）

前提：**完全退出 DSH**（宿主运行期间 CLI 拿不到 `package.json.lock`）。

```powershell
# 1) 备份
$p = "E:\DevTools\dsh-home\profiles\desktop"
$bak = "E:\DevTools\dsh-home\_backups\purge-local-$(Get-Date -Format yyyyMMdd-HHmmss)"
New-Item -ItemType Directory -Force -Path $bak | Out-Null
Copy-Item "$p\package.json","$p\pnpm-lock.yaml","$p\cordis.patch.yml" $bak

# 2) 依赖改成 file:
#    package.json -> dependencies."dsh-purge" = "file:E:/YX/AI/XM/dsh-purge"

# 3) 恢复加载：bundles 里加回 "dsh-purge"（或直接用市场开关），
#    并删掉 cordis.patch.yml 末尾 4 行 dsh-purge 相关的 `disabled: true`

# 4) 安装 + 启动
$env:ELECTRON_RUN_AS_NODE = 1
& 'D:\Program Files\DeepSeek Harness\DeepSeek Harness.exe' --expose-internals `
  'D:\Program Files\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\pnpm\bin\pnpm.cjs' `
  install --reporter=append-only
```

更省事的方式：退出 DSH 后双击本目录的 `scripts\link-to-profile.cmd`（带备份与回滚提示）。

## 回滚

```powershell
# 依赖侧
#   package.json 的 dsh-purge 改回 github:YuJunZhiXue/dsh-purge#5e757260...（该 sha 已不可拉取，仅作记录）
#   bundles 移除 dsh-purge，cordis.patch.yml 补回 disabled: true
# 安装期清洗侧（与插件开关无关，独立存在）
dsh-purge --revert
```

## 自检

```powershell
node scripts\probe-paths.mjs        # AI 基线 / shim 路径解析
node scripts\probe-cmd-flash.mjs    # dsh.cmd 注入状态（只读）
node scripts\probe-ai-base.mjs      # desktop 侧 aiBase 解析
node scripts\verify-local.mjs       # 本维护版的回归检查（{{cwd}} 归零 / patch 层干净 / 沙箱可加载）
```

## 已知遗留

- `dsh-purge-redteam-ui` 需要 `webServer` 服务；headless 启动时只会 `pending`，属于预期（桌面/Web 宿主下正常）。
- `presets/redteam/agent.cordis.yml` 注释里提到 `{{cwd}}`，仅注释、不参与组装。
- `*.bak-cwdfix-20261018` 是 10-18 修复前的原件备份，保留用于对比，不参与加载。

---

## 与原版 v1.1.71 的逐文件差异

以 `dsh-purge-original`（108 文件原样快照）为基准，本维护版 **修改 4 个、新增 7 个、删除 0 个**：

| 类型 | 文件 | 说明 |
| --- | --- | --- |
| 修改 | `lib/identity.js` | 两处 `stripHarnessPersona` 的 `.replace()` 回填由 `"Working directory: {{cwd}}. "` 改为 `""`；`CWD_ONLY_SUFFIX` 保持 `""` |
| 修改 | `lib/core.js` | `ALLOW_EXEC_PERSONA_BLOCK` / `ALLOW_EXEC_PERSONA_LINE` 去掉 `{{cwd}}` 前缀 |
| 修改 | `cordis.patch.yml` | 删顶层 `- id: dsh-purge`；注释掉 5 条 `redteam-*` disabled 行；`personaSuffix: ""` |
| 修改 | `package.json` | `version` → `1.1.71-local.1`；`dshTarget` → `0.2.1-rc.2`；`dsh.install` → `file` |
| 新增 | `README-MAINTENANCE.md` | 本文件 |
| 新增 | `scripts/link-to-profile.ps1` / `.cmd` | 接入脚本（默认预演，`-Apply` 才落盘，带进程守卫与备份） |
| 新增 | `scripts/verify-local.mjs` | 回归自检（{{cwd}} 归零 / patch 层干净 / 入口齐全） |
| 新增 | `scripts/probe-*.mjs`（3 个） | 只读探测：AI 基线路径、cmd-flash 状态、desktop aiBase 解析 |

复核方法：

```powershell
# 逐文件比对（原版目录下另有 SHA256SUMS.txt）
$o='E:\YX\AI\XM\dsh-purge-original'; $m='E:\YX\AI\XM\dsh-purge'
Get-ChildItem $o -Recurse -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | ForEach-Object {
  $rel = $_.FullName.Substring($o.Length+1)
  $mp = Join-Path $m $rel
  if (-not (Test-Path $mp)) { "ONLY-ORIGINAL $rel" }
  elseif ((Get-FileHash $_.FullName).Hash -ne (Get-FileHash $mp).Hash) { "CHANGED $rel" }
}
```

## 上游备份仓库（2026-10-22 检索，对照用）

删库后社区在 24 小时内建了一批镜像，GitHub 搜 `dsh-purge` 命中 119 个仓库：

- `marspang/DSH-Purge-backup` —— 完整文件树 + `MIRROR-NOTICE.md`，`package.json` 2502 字节与本快照一致（**最可信的原件备份**）
- `shengqinglian-ctrl/dsh-purge-archive-20261022` —— 最大（3.6MB），默认分支 `fix/restart-sticky`，含上游未发版分支
- `tacssen/dsh-purge` —— 自称 v1.1.71 archive
- `Changran7/dsh-purge` —— 社区修复版 `1.1.72-fix.1`，只改 `personaSuffix`，仍留 6 条 patch 噪音、`install` 仍指向死链
- `wang12339/dsh-purge-0.2.1-adapted` —— 0.2.1 适配版
- `Laiarenas/dsh-purge2` —— 衍生改写版（行为已变，不适合当备份）
- `shibocao797-max/dsh-purge`、`shipmap/dsh-purge-bak` —— 空仓库（size 0）

## 许可、署名与风险

- 原项目 MIT，作者 **YuJunZhiXue（叫我小杨同学）**；`LICENSE` 原样保留，上游 README 的署名要求继续有效。
- 本维护版是**社区修复**，非原作者发布，不代表其背书；所有改动都在上表列明，可逐行复核。
- ⚠️ 该插件会修改 DSH 安装目录：改写 `dsh.cmd`、向宿主 `lib/bin.js` 注入 `child_process` 包装、
  用 `schtasks` 清理计划任务、改写系统提示词与权限策略。使用前请审阅代码。
- 破甲 / 红队类内容可能违反 GitHub 或模型服务方的使用条款，公开仓库存在被下架的可能。

