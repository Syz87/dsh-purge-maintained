#!/usr/bin/env node
// 本地维护版回归检查：不写任何文件，只做静态 + 结构校验
// 2026-10-27 随 1.1.71-local.1 → 1.1.79-local.1 升级同步更新期望值：
//   - 版本/dshTarget 跟随 1.1.79
//   - CWD_ONLY_SUFFIX 不再要求清空：1.1.79 的 overlayOfficialIdentity 按
//     cwdVariableSupported() 分流，末尾 sanitizeCwdTokens() 兜底，支持时才用 {{cwd}}
//   - patch 层保留上游 `- id: dsh-purge` 顶层条目（REPLACE 语义，非 insert）
//   - 新增知识库/技能库/页签回归项（本地维护版保留被上游下架的功能）
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
ok(pkg.version === "1.1.79-local.1", `version = ${pkg.version}`, "期望 1.1.79-local.1");
ok(pkg.dshTarget === "0.2.1-rc.3", `dshTarget = ${pkg.dshTarget}`, "期望 0.2.1-rc.3");
ok(pkg.dsh?.install?.preferred === "file", `install.preferred = ${pkg.dsh?.install?.preferred}`, "期望 file");
ok(!JSON.stringify(pkg.dsh?.install || {}).includes("github.com/YuJunZhiXue"), "install 元数据不再指向已删库的 github");
ok(Array.isArray(pkg.files) && pkg.files.includes("skills"), "files 字段包含 skills（本地保留随包技能）");
ok(!JSON.stringify(pkg.peerDependencies || {}).includes("dsh"), "peerDependencies 不锁宿主包（1.1.79 只留 cordis）");

// 2. identity.js：{{cwd}} 注入路径
console.log("\n2) lib/identity.js（{{cwd}} 注入路径）");
const idt = read("lib/identity.js");
// 1.1.79 语义：支持 cwd 时才允许 CWD_ONLY_SUFFIX 带 {{cwd}}；不支持时走 CWD_STATIC_SUFFIX。
ok(idt.includes('export const CWD_ONLY_SUFFIX = "Your working directory is {{cwd}}.";'),
   "CWD_ONLY_SUFFIX 保持上游值（由 cwdVariableSupported 分流 + sanitizeCwdTokens 兜底）");
ok(idt.includes("function cwdVariableSupported(") && idt.includes("function sanitizeCwdTokens("),
   "cwdVariableSupported / sanitizeCwdTokens 分流与兜底逻辑在位");
const replaceBodies = [...idt.matchAll(/\.replace\(\s*\/[\s\S]*?,\s*("(?:[^"\\]|\\.)*")\s*,?\s*\)/g)].map((m) => m[1]);
ok(!replaceBodies.some((b) => b.includes("{{cwd}}")), "所有 .replace() 的回填文本都不含 {{cwd}}",
   replaceBodies.filter((b) => b.includes("{{cwd}}")).join(" | "));
ok(idt.includes('"Working directory: {{cwd}}."'), "isCwdOnlyText 的判定字面量保留（只识别、不注入）");
ok(idt.includes('2026-10-27 本地维护'), "cwdfix 本地维护注释在位（stripHarnessPersona 不回填 {{cwd}}）");

// 3. core.js
console.log("\n3) lib/core.js（死代码常量）");
const core = read("lib/core.js");
ok(!/ALLOW_EXEC_PERSONA_BLOCK\s*=\s*"Working directory: \{\{cwd\}\}/.test(core), "ALLOW_EXEC_PERSONA_BLOCK 不含 {{cwd}}");
ok(!/ALLOW_EXEC_PERSONA_LINE\s*=\s*\n?\s*"Working directory: \{\{cwd\}\}/.test(core), "ALLOW_EXEC_PERSONA_LINE 不含 {{cwd}}");

// 4. cordis.patch.yml
console.log("\n4) cordis.patch.yml");
const yml = read("cordis.patch.yml");
ok(/personaSuffix:\s*""/.test(yml), 'personaSuffix 为空字符串');
ok(/^- id: dsh-purge$/m.test(yml), "保留上游顶层 `- id: dsh-purge` 条目（只改 inject/config，非 insert）");
ok(/- insert:/.test(yml), "存在 insert 段");
ok(/- id: dsh-purge-redteam-ui/.test(yml), "演练台 UI entry 仍在 insert 内");
const activeRows = yml.split(/\r?\n/).filter((l) => /^\s*-\s*id:/.test(l) && !/^\s*#/.test(l));
const legacyRows = activeRows.filter((l) => /^\s*-\s*id:\s*(redteam-store|redteam-ui|redteam-mode|redteam-mode-store|redteam-mode-ui)\s*$/.test(l));
ok(legacyRows.length === 0, `无旧独立红队包的 active patch 行（当前 ${activeRows.length} 条 active 行）`, legacyRows.join(" | "));

// 5. 知识库 / 技能库（本地维护版保留）
console.log("\n5) 知识库 / 技能库（本地保留项）");
for (const rel of ["lib/redteam/store-core.js", "lib/redteam/tools.js", "lib/redteam/client.js", "lib/redteam/evidence-ledger.mjs"]) {
  ok(fs.existsSync(path.join(root, rel)), `${rel} 存在`);
}
const store = read("lib/redteam/store-core.js");
ok(!store.includes("开源版已下架知识库"), "store-core.js 无上游知识库短路");
for (const op of ["pocSearch", "pocList", "pocGet", "pocSave", "pocUpdate", "pocDelete", "pocUse", "pocStats"]) {
  ok(new RegExp(`if \\(op === '${op}'\\)`).test(store), `store-core.js 保留 op: ${op}`);
}
const tools = read("lib/redteam/tools.js");
ok(!tools.includes("KB_DISABLED"), "tools.js 无 KB_DISABLED 短路");
const pocTools = [...tools.matchAll(/name: ["'](redteam_poc_[a-z_]+)["']/g)].map((m) => m[1]);
ok(pocTools.length >= 6, `POC 工具数量 >= 6（实际 ${pocTools.length}: ${pocTools.join(", ")}）`);
const rtc = read("lib/redteam/client.js");
ok(rtc.includes("['knowledge', '知识库']") && rtc.includes("['skills', '技能库']"), "演练台页签含知识库 / 技能库");
ok(rtc.includes("st.tab === 'knowledge') body = h(KnowledgeTab"), "知识库路由指向 KnowledgeTab");
ok(rtc.includes("st.tab === 'skills') body = h(SkillsTab"), "技能库路由指向 SkillsTab");
const clientJs = read("client.js");
ok(clientJs.includes("'knowledge', '知识库'") && clientJs.includes("st.tab === 'knowledge') body = h(KnowledgeTab"),
   "client.js 已重新嵌入恢复后的演练台 UI");
ok(!clientJs.includes("KB_DISABLED") && !clientJs.includes("开源版已下架知识库"), "client.js 无知识库短路残留");
const skillsDir = path.join(root, "skills", "redteam");
const skillFiles = fs.existsSync(skillsDir) ? fs.readdirSync(skillsDir).filter((f) => f.endsWith(".md")) : [];
ok(skillFiles.length >= 20, `skills/redteam 技能数 >= 20（实际 ${skillFiles.length}）`);
ok(skillFiles.includes("redteam-setup.md"), "核心技能 redteam-setup.md 在位");
// 2026-10-27：从社区 fork（7900mpsOVO/dsh-purge1.1.73）找回上游下架的两个技能
ok(skillFiles.includes("evidence-discipline.md"), "evidence-discipline.md 在位（配套 1.1.79 证据账本与 redteam_evidence 工具）");
const paDir = path.join(root, "skills", "paper-autopilot");
const paFiles = fs.existsSync(paDir) ? (function walk(d) {
  return fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => e.isDirectory() ? walk(path.join(d, e.name)) : [e.name]);
})(paDir) : [];
ok(fs.existsSync(path.join(paDir, "SKILL.md")) && paFiles.length >= 60, `skills/paper-autopilot 在位（${paFiles.length} 个文件）`);
ok(fs.existsSync(path.join(root, "scripts", "install-paper-autopilot.mjs")), "install:skill 安装脚本在位");

// 6. 入口文件齐全
console.log("\n6) 入口文件");
for (const rel of ["lib/index.js", "lib/core.js", "lib/redteam/index.js", "client.js", "cordis.patch.yml", "scripts/ensure-profile-bundle.mjs"]) {
  ok(fs.existsSync(path.join(root, rel)), `${rel} 存在`);
}

console.log(`\n== 结果：${fail === 0 ? "全部通过" : fail + " 项失败"} ==`);
process.exit(fail === 0 ? 0 : 1);
