// 定向探测 desktop 侧 AI 基线解析（只读）
import * as desktop from "../lib/desktop.js";
import fs from "node:fs";
import path from "node:path";

const EXE = "D:\\Program Files\\DeepSeek Harness\\DeepSeek Harness.exe";
const RES = "D:\\Program Files\\DeepSeek Harness\\resources";
const isAiBase = (p) => Boolean(p) && fs.existsSync(path.join(p, "dsh-agent-instructions", "lib"));

const show = (label, fn) => {
  try { console.log(`${label} => ${JSON.stringify(fn())}`); }
  catch (e) { console.log(`${label} !! ${e && e.message}`); }
};

show("isOfficialHarnessExecutable(EXE)", () => desktop.isOfficialHarnessExecutable(EXE));
show("isOfficialHarnessExecutable(process.execPath)", () => desktop.isOfficialHarnessExecutable(process.execPath));
show("findDesktopAppExecutable()", () => desktop.findDesktopAppExecutable());
show("resolveDesktopAiBase({exe,res,argv,env})", () => desktop.resolveDesktopAiBase({ execPath: EXE, resourcesPath: RES, argv: [], env: {} }));
show("resolveDesktopAiBase() 无参", () => desktop.resolveDesktopAiBase());
show("isInsideDesktopInstall(app\\dsh\\...)", () => desktop.isInsideDesktopInstall("D:\\Program Files\\DeepSeek Harness\\resources\\app\\dsh\\node_modules\\@deepseek-ai"));
show("listDesktopPackageRoots({discover:false})", () => desktop.listDesktopPackageRoots({ discover: false }));

const cands = [
  "D:\\Program Files\\DeepSeek Harness\\resources\\app\\dsh\\node_modules\\@deepseek-ai",
  "D:\\Program Files\\DeepSeek Harness\\resources\\app\\dsh\\node_modules\\@deepseek-ai\\dsh-agent-instructions",
];
for (const c of cands) console.log(`isAiBase(${c}) => ${isAiBase(c)}`);

console.log("env DSH_BASE =", JSON.stringify(process.env.DSH_BASE || ""));
console.log("env DSH_HOME =", JSON.stringify(process.env.DSH_HOME || ""));
