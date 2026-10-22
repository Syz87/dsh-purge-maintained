// 只读检查：cmd-flash 在 shim 与宿主 CLI 上的实际命中情况（不写任何文件）
import * as core from "../lib/core.js";
import fs from "node:fs";
import path from "node:path";

const shimDir = "D:\\Program Files\\DeepSeek Harness\\resources\\runtime\\cli\\bin";
const files = ["dsh.cmd", "dsh.ps1", "dsh"];

console.log("=== shim dir:", shimDir, "存在:", fs.existsSync(shimDir));
for (const n of files) {
  const fp = path.join(shimDir, n);
  if (!fs.existsSync(fp)) { console.log(`  ${n}: 不存在`); continue; }
  const text = fs.readFileSync(fp, "utf8");
  console.log(`  ${n}: size=${text.length} shimIsPatched=${core.shimIsPatched(fp)} status=${JSON.stringify(core.shimFileStatus(fp))} 含[dsh-purge]=${text.includes("[dsh-purge]")}`);
}

console.log("\n=== runtime/cli 下是否有 node_modules/@deepseek-ai/dsh ===");
const cliRoot = path.join(shimDir, "..");
for (const rel of ["node_modules\\@deepseek-ai\\dsh\\lib\\bin.js", "..\\node_modules\\@deepseek-ai\\dsh\\lib\\bin.js"]) {
  const p = path.join(cliRoot, rel);
  console.log(`  ${rel}: ${fs.existsSync(p)}`);
}

console.log("\n=== 备份文件 ===");
const bakRoot = path.join("E:\\DevTools\\dsh-home", "dsh-purge", "shim-backups");
if (fs.existsSync(bakRoot)) console.log(fs.readdirSync(bakRoot));
else console.log("  shim-backups 目录不存在");

console.log("\n=== DSH Doctor 目录 ===");
const doctorDir = path.join(process.env.LOCALAPPDATA || "", "DSH Doctor");
console.log(`  ${doctorDir} 存在: ${fs.existsSync(doctorDir)}`);
if (fs.existsSync(doctorDir)) console.log("  ", fs.readdirSync(doctorDir));

console.log("\n=== findShimDir() / listShimDirsForPatch() ===");
console.log("  findShimDir:", core.findShimDir());
console.log("  listShimDirsForPatch:", core.listShimDirsForPatch());
