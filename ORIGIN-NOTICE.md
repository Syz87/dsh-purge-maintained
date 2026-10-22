# ORIGIN-NOTICE — 原样快照说明（请先读这一页）

本目录是 **dsh-purge v1.1.71 的未修改原样快照**，仅作归档与来源比对，**不包含任何修复**。

## 来源

| 项目 | 值 |
| --- | --- |
| 插件 | `dsh-purge` v1.1.71 |
| 上游仓库 | `https://github.com/YuJunZhiXue/dsh-purge`（2026-10-22 起返回 404，个人主页仍显示该仓库 99 commits，疑似转私有） |
| 快照取自 | 本机 `$DSH_HOME\profiles\web\node_modules\dsh-purge`（2026-10-16 由插件市场从上游安装落盘） |
| 快照时间 | 2026-10-22 |
| 文件数 | 108（不含本说明与 `SHA256SUMS.txt`） |
| `package.json` | 2502 字节 |

## 交叉验证

这份快照与社区独立备份一致，可作为"原件"的可信副本：

- `marspang/DSH-Purge-backup`：`package.json` 同为 2502 字节，文件树相同
- `shengqinglian-ctrl/dsh-purge-archive-20261022`：同为 v1.1.71（另含上游未发版的 `fix/restart-sticky` 分支）
- `tacssen/dsh-purge`：自称 v1.1.71 archive

## 完整性校验

```powershell
# 在本目录下执行，逐文件核对
Get-Content SHA256SUMS.txt | ForEach-Object {
  $hash, $rel = $_ -split '  ', 2
  $actual = (Get-FileHash (Join-Path . $rel) -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $hash) { "MISMATCH $rel" }
}
```

清单本身指纹（sha256）：`040FC9F3DFB29B25BB4CF34F83076B5C5EDF66C5A4938C325E88B004FFF976BF`

## ⚠️ 这份代码**不要**直接用于 DSH 0.2.1-rc.2

原版 `lib/identity.js` 第 8 行仍是：

```js
export const CWD_ONLY_SUFFIX = "Your working directory is {{cwd}}.";
```

而 DSH `0.2.1-rc.2` 的 `system-prompt` 只注册 `provider` / `model` 两个提示词变量，
带 `{{cwd}}` 的注入文本会在每次组装时抛 `unknown prompt variable "{{cwd}}"`，
表现为**开启插件后整轮对话直接失败**。`cordis.patch.yml` 的 `personaSuffix` 同样带 `{{cwd}}`。

要可用的版本，请切到本仓库 `main` 分支（维护版，见 `README-MAINTENANCE.md`），
本目录只用于「原件是什么样」的取证与 diff。

## 许可与署名

原项目为 MIT 许可，作者 **YuJunZhiXue（叫我小杨同学）**。`LICENSE` 原样保留。

上游 README 中的署名要求仍然有效：借用本项目的名称、思路、代码或提示词时，
必须注明作者并写明来源仓库。本快照不改变任何版权归属，也不代表原作者对本仓库的背书。

## 免责

- 这是社区归档，**非原作者发布**。
- 该插件会修改 DSH 安装目录（改写 `dsh.cmd`、向宿主 `lib/bin.js` 注入 `child_process` 包装、
  通过 `schtasks` 清理计划任务）、改写系统提示词与权限策略。使用前请自行审阅代码。
- 红队/破甲类内容可能违反 GitHub 或模型服务方的使用条款，本仓库仅作技术归档。
