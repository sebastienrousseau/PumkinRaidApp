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

    await page.locator("#play").click();
    await page.waitForFunction(() => document.querySelector("#menu").classList.contains("hidden"));
    await page.keyboard.down("ArrowRight");
    await page.waitForTimeout(120);
    await page.keyboard.up("ArrowRight");
    await page.keyboard.press("Space");
    await page.keyboard.press("Enter");

    const box = await page.locator("#game").boundingBox();
    if (!box) throw new Error(`${name}: canvas has no interactive bounds`);
    await page.mouse.move(box.x + box.width * 0.5, box.y + box.height * 0.5);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width * 0.65, box.y + box.height * 0.45, { steps: 4 });
    await page.mouse.up();
    await page.waitForTimeout(250);

    if (errors.length) throw new Error(`${name}: ${errors.join(" | ")}`);
    console.log(`${name} passed: Wasm load, start, keyboard, and pointer paths.`);
  } finally {
    await browser.close();
  }
}
