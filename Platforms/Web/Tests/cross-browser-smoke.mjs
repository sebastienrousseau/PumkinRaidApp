import { chromium, firefox, webkit } from "playwright";

const baseURL = process.env.PUMKIN_WEB_URL ?? "http://127.0.0.1:8765/index.html";
const engines = [
  ["Chromium", chromium],
  ["Firefox", firefox],
  ["WebKit", webkit],
];

for (const [name, browserType] of engines) {
  const browser = await browserType.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1_280, height: 800 } });
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (message) => {
      if (message.type() === "error") errors.push(message.text());
    });

    const deadline = Date.now() + 30_000;
    while (true) {
      try {
        await page.goto(baseURL, { waitUntil: "domcontentloaded" });
        break;
      } catch (error) {
        if (Date.now() >= deadline) throw error;
        await page.waitForTimeout(250);
      }
    }
    await page.waitForFunction(
      () => document.documentElement.dataset.swiftReady === "true",
      undefined,
      { timeout: 30_000 }
    );
    const canvasReady = await page.locator("#game").evaluate(
      (canvas) => canvas.width > 0 && canvas.height > 0
    );
    if (!canvasReady) throw new Error(`${name}: Swift did not size the game canvas`);
    const modeCount = await page.locator(".modes button").count();
    if (modeCount !== 5) throw new Error(`${name}: expected five game modes, found ${modeCount}`);
    await page.waitForFunction(() => document.querySelector("#ghost-sprite").complete);

    await page.locator("#play").click();
    await page.waitForFunction(() => document.querySelector("#menu").classList.contains("hidden"));
    const startingX = Number(await page.locator("html").getAttribute("data-ghost-x"));
    await page.keyboard.down("ArrowRight");
    await page.waitForTimeout(240);
    await page.keyboard.up("ArrowRight");
    await page.waitForTimeout(80);
    const keyboardX = Number(await page.locator("html").getAttribute("data-ghost-x"));
    if (!(keyboardX > startingX)) throw new Error(`${name}: ArrowRight did not move the ghost`);
    await page.keyboard.press("Space");
    await page.keyboard.press("Enter");

    const box = await page.locator("#game").boundingBox();
    if (!box) throw new Error(`${name}: canvas has no interactive bounds`);
    const ghostX = Number(await page.locator("html").getAttribute("data-ghost-x"));
    const ghostY = Number(await page.locator("html").getAttribute("data-ghost-y"));
    await page.mouse.move(box.x + box.width * ghostX, box.y + box.height * ghostY);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width * Math.min(0.9, ghostX + 0.15), box.y + box.height * ghostY, { steps: 4 });
    await page.mouse.up();
    await page.waitForTimeout(250);
    const pointerX = Number(await page.locator("html").getAttribute("data-ghost-x"));
    if (!(pointerX > ghostX)) throw new Error(`${name}: pointer drag did not move the ghost`);

    if (errors.length) throw new Error(`${name}: ${errors.join(" | ")}`);
    console.log(`${name} passed: Wasm load, five modes, assets, keyboard movement, and pointer drag.`);
  } finally {
    await browser.close();
  }
}
