import fs from "node:fs";
import path from "node:path";

const pkgDir = path.resolve(process.argv[2] ?? ".build/plugins/PackageToJS/outputs/Package");
const browserJsPath = path.join(pkgDir, "platforms", "browser.js");
const instantiateJsPath = path.join(pkgDir, "instantiate.js");

if (fs.existsSync(browserJsPath)) {
  let content = fs.readFileSync(browserJsPath, "utf8");
  if (!content.includes("@bjorn3/browser_wasi_shim")) {
    console.log("Injecting WASI shim into PackageToJS browser.js...");
    const wasiImport = `import { WASI, File, OpenFile, ConsoleStdout, PreopenDirectory } from '@bjorn3/browser_wasi_shim';\n`;
    content = wasiImport + content;
    content = content.replace(
      /export async function defaultBrowserSetup\(options\) \{[\s\S]*?\n\}/,
      `export async function defaultBrowserSetup(options) {
    const args = options.args ?? [];
    const onStdoutLine = options.onStdoutLine ?? ((line) => console.log(line));
    const onStderrLine = options.onStderrLine ?? ((line) => console.error(line));
    const wasi = new WASI([MODULE_PATH, ...args], [], [
        new OpenFile(new File([])),
        ConsoleStdout.lineBuffered((stdout) => onStdoutLine(stdout)),
        ConsoleStdout.lineBuffered((stderr) => onStderrLine(stderr)),
        new PreopenDirectory("/", new Map()),
    ], { debug: false });

    return {
        module: options.module,
        wasi: Object.assign(wasi, {
            setInstance(instance) {
                wasi.inst = instance;
            }
        }),
    };
}`
    );
    fs.writeFileSync(browserJsPath, content, "utf8");
  }
}

if (fs.existsSync(instantiateJsPath)) {
  let content = fs.readFileSync(instantiateJsPath, "utf8");
  if (!content.includes("wasi_snapshot_preview1")) {
    console.log("Injecting wasi_snapshot_preview1 into PackageToJS instantiate.js...");
    content = content.replace(
      "javascript_kit: swift.wasmImports,",
      `javascript_kit: swift.wasmImports,\n        wasi_snapshot_preview1: options.wasi?.wasiImport,`
    );
    content = content.replace(
      "result.swift.main();",
      `if (options.wasi) {\n        options.wasi.initialize(result.instance);\n    }\n    result.swift.main();`
    );
    fs.writeFileSync(instantiateJsPath, content, "utf8");
  }
}
