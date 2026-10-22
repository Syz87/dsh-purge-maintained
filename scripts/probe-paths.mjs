// 只读探测：确认 dsh-purge 在本次 DSH 环境里解析到的路径与 cmd-flash 目标
import * as core from "../lib/core.js";

const out = (label, val) => {
  console.log(`\n=== ${label} ===`);
  console.log(typeof val === "string" ? val : JSON.stringify(val, null, 2));
};

out("platform / node", `${process.platform} ${process.version}`);
try { out("findAiBase()", core.findAiBase()); } catch (e) { out("findAiBase() 抛错", String(e)); }
try { out("findDshBinRoot()", core.findDshBinRoot()); } catch (e) { out("findDshBinRoot() 抛错", String(e)); }
try { out("findDshHome()", core.findDshHome()); } catch (e) { out("findDshHome() 抛错", String(e)); }
try { out("findDesktopShimDir()", core.findDesktopShimDir()); } catch (e) { out("findDesktopShimDir() 抛错", String(e)); }
try { out("findShimDir()", core.findShimDir()); } catch (e) { out("findShimDir() 抛错", String(e)); }
try { out("listDesktopCommandRuntimeDirs()", core.listDesktopCommandRuntimeDirs()); } catch (e) { out("listDesktopCommandRuntimeDirs() 抛错", String(e)); }
try { out("listShimDirsForPatch()", core.listShimDirsForPatch()); } catch (e) { out("listShimDirsForPatch() 抛错", String(e)); }
try { out("enumeratePatchAiBases()", core.enumeratePatchAiBases()); } catch (e) { out("enumeratePatchAiBases() 抛错", String(e)); }
try {
  const aiBase = core.findAiBase();
  out("targetFiles(aiBase).length", core.targetFiles(aiBase).length);
  out("targetFiles(aiBase)", core.targetFiles(aiBase));
} catch (e) { out("targetFiles 抛错", String(e)); }
try { out("dshBaseEnvStatus()", core.dshBaseEnvStatus()); } catch (e) { out("dshBaseEnvStatus() 抛错", String(e)); }
try { out("missingAiBaseMessage()", core.missingAiBaseMessage()); } catch (e) { out("missingAiBaseMessage() 抛错", String(e)); }
