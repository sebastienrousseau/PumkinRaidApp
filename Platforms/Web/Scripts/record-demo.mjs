import { chromium } from "playwright";
import fs from "node:fs";

const baseURL = "http://127.0.0.1:8765/index.html";
const outputDir = "/tmp/pumkin_recordings";

if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

// Clear any previous recordings
for (const file of fs.readdirSync(outputDir)) {
  fs.unlinkSync(`${outputDir}/${file}`);
}

console.log("Launching Chromium for recording...");
const browser = await chromium.launch({
  headless: true,
  args: ["--no-sandbox", "--disable-setuid-sandbox"]
});

const context = await browser.newContext({
  viewport: { width: 840, height: 525 },
  recordVideo: {
    dir: outputDir,
    size: { width: 840, height: 525 }
  }
});

const page = await context.newPage();

console.log("Navigating to", baseURL);
await page.goto(baseURL, { waitUntil: "domcontentloaded" });

console.log("Waiting for Swift Wasm initialization...");
await page.waitForFunction(
  () => document.documentElement.dataset.swiftReady === "true" || !!document.documentElement.dataset.swiftError,
  undefined,
  { timeout: 30000 }
);

const swiftError = await page.evaluate(() => document.documentElement.dataset.swiftError);
if (swiftError) {
  throw new Error(`Swift init error: ${swiftError}`);
}

await page.waitForFunction(() => document.querySelector("#ghost-sprite").complete);
console.log("Game engine ready! Showing title screen...");
// Record title screen for 1 second
await page.waitForTimeout(1000);

console.log("Hovering and clicking Play...");
await page.locator("#play").hover();
await page.waitForTimeout(250);
await page.locator("#play").click();

await page.waitForFunction(() => document.querySelector("#menu").classList.contains("hidden"));
console.log("Raid started!");

// Get game canvas bounds
const box = await page.locator("#game").boundingBox();

// Choreographed gameplay:
// 1. Move ghost smoothly right and up towards first pumpkin cluster
await page.keyboard.down("ArrowRight");
await page.keyboard.down("ArrowUp");
await page.waitForTimeout(350);
await page.keyboard.up("ArrowUp");
await page.keyboard.up("ArrowRight");

// 2. Dash!
await page.keyboard.press("Space");
console.log("Dash 1 executed");
await page.waitForTimeout(250);

// 3. Mouse sweep across middle screen to intercept pumpkins
if (box) {
  const midX = box.x + box.width * 0.55;
  const midY = box.y + box.height * 0.45;
  await page.mouse.move(midX, midY);
  await page.mouse.down();
  
  // Sweep left
  await page.mouse.move(box.x + box.width * 0.25, box.y + box.height * 0.4, { steps: 10 });
  await page.waitForTimeout(200);
  
  // Dash during sweep!
  await page.keyboard.press("Space");
  console.log("Dash 2 during sweep");
  
  // Sweep up-right towards high pumpkins
  await page.mouse.move(box.x + box.width * 0.75, box.y + box.height * 0.35, { steps: 12 });
  await page.waitForTimeout(200);
  
  // Shriek! Destroys all visible pumpkins on screen
  await page.keyboard.press("Enter");
  console.log("Shriek activated!");
  await page.waitForTimeout(300);

  // Sweep down-left to gather falling remnants
  await page.mouse.move(box.x + box.width * 0.4, box.y + box.height * 0.6, { steps: 10 });
  await page.waitForTimeout(200);
  await page.mouse.up();
}

// 4. Quick directional dodge and final dash
await page.keyboard.down("ArrowRight");
await page.waitForTimeout(300);
await page.keyboard.up("ArrowRight");
await page.keyboard.press("Space");
console.log("Final dash executed");

await page.waitForTimeout(600);

const finalScore = await page.locator("#score").textContent();
console.log(`Final HUD state: ${finalScore}`);

// Close page & context to finalize video
await page.close();
await context.close();
await browser.close();

console.log("Video written successfully!");
for (const file of fs.readdirSync(outputDir)) {
  const stat = fs.statSync(`${outputDir}/${file}`);
  console.log(`- ${file} (${stat.size} bytes)`);
}

process.exit(0);
