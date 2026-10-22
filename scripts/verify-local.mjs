#!/usr/bin/env node
// 本地维护版回归检查：不写任何文件，只做静态 + 结构校验
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (rel) => fs.readFileSync(path.join(root, rel), "utf8");
let fail = 0;
const ok = (cond, msg, detail = "") => {
  if (cond) console.log(`  [PASS] ${msg}`);
  else { fail++; console.log(`  [FAIL] ${msg}${detail ? " — " + detail : ""}`); }
};

console.log(`== dsh-purge 本地维护版自检 @ ${root}\n`);

// 1. package.json
console.log("1) package.json");
const pkg = JSON.parse(read("package.json"));
ok(pkg.version === "1.1.71-local.1", `version = ${pkg.version}`, "期望 1.1.71-local.1");
ok(pkg.dshTarget === "0.2.1-rc.2", `dshTarget = ${pkg.dshTarget}`, "期望 0.2.1-rc.2");
ok(pkg.dsh?.install?.preferred === "file", `install.preferred = ${pkg.dsh?.install?.preferred}`, "期望 file");
ok(!JSON.stringify(pkg.dsh?.install || {}).includes("github.com/YuJunZhiXue"), "install 元数据不再指向已删库的 github");

// 2. identity.js：注入路径归零
console.log("\n2) lib/identity.js（{{cwd}} 注入路径）");
const idt = read("lib/identity.js");
ok(/export const CWD_ONLY_SUFFIX = "";/.test(idt), 'CWD_ONLY_SUFFIX = ""');
const replaceBodies = [...idt.matchAll(/\.replace\(\s*\/[\s\S]*?,\s*("(?:[^"\\]|\\.)*")\s*,?\s*\)/g)].map((m) => m[1]);
ok(!replaceBodies.some((b) => b.includes("{{cwd}}")), "所有 .replace() 的回填文本都不含 {{cwd}}",
   replaceBodies.filter((b) => b.includes("{{cwd}}")).join(" | "));
ok(idt.includes('"Working directory: {{cwd}}."'), "isCwdOnlyText 的判定字面量保留（只识别、不注入）");

// 3. core.js
console.log("\n3) lib/core.js（死代码常量）");
const core = read("lib/core.js");
ok(!/ALLOW_EXEC_PERSONA_BLOCK\s*=\s*"Working directory: \{\{cwd\}\}/.test(core), "ALLOW_EXEC_PERSONA_BLOCK 不含 {{cwd}}");
ok(!/ALLOW_EXEC_PERSONA_LINE\s*=\s*\n?\s*"Working directory: \{\{cwd\}\}/.test(core), "ALLOW_EXEC_PERSONA_LINE 不含 {{cwd}}");

// 4. cordis.patch.yml
console.log("\n4) cordis.patch.yml");
const yml = read("cordis.patch.yml");
ok(/personaSuffix:\s*""/.test(yml), 'personaSuffix 为空字符串');
ok(!/^- id: dsh-purge$/m.test(yml), "没有顶层 `- id: dsh-purge` 冗余 patch 行");
ok(/- insert:/.test(yml), "存在 insert 段");
ok(/- id: dsh-purge-redteam-ui/.test(yml), "演练台 UI entry 仍在 insert 内");
const activeRows = yml.split(/\r?\n/).filter((l) => /^\s*-\s*id:/.test(l) && !/^\s*#/.test(l));
const legacyRows = activeRows.filter((l) => /^\s*-\s*id:\s*(redteam-store|redteam-ui|redteam-mode|redteam-mode-store|redteam-mode-ui)\s*$/.test(l));
ok(legacyRows.length === 0, `无旧独立红队包的 active patch 行（当前 ${activeRows.length} 条 active 行）`, legacyRows.join(" | "));

// 5. 入口文件齐全
console.log("\n5) 入口文件");
for (const rel of ["lib/index.js", "lib/core.js", "lib/redteam/index.js", "client.js", "cordis.patch.yml"]) {
  ok(fs.existsSync(path.join(root, rel)), `${rel} 存在`);
}

console.log(`\n== 结果：${fail === 0 ? "全部通过" : fail + " 项失败"} ==`);
process.exit(fail === 0 ? 0 : 1);
