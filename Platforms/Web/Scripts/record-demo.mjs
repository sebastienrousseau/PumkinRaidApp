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

// 1. Showcase title screen
await page.waitForTimeout(800);

// 2. Click Play to start raid
console.log("Clicking Play to start raid...");
await page.locator("#play").hover();
await page.waitForTimeout(150);
await page.locator("#play").click();

await page.waitForFunction(() => document.querySelector("#menu").classList.contains("hidden"));
console.log("Raid active! Commencing Fruit Ninja style gameplay choreography...");

const box = await page.locator("#game").boundingBox();
if (!box) throw new Error("Canvas #game not found");

// Helper for dynamic Fruit-Ninja sword slashes
async function swipe(startX, startY, endX, endY, steps = 14, pauseAfterMs = 120) {
  await page.mouse.move(box.x + startX, box.y + startY);
  await page.mouse.down();
  await page.mouse.move(box.x + endX, box.y + endY, { steps });
  await page.mouse.up();
  if (pauseAfterMs > 0) {
    await page.waitForTimeout(pauseAfterMs);
  }
}

// Initial movement: Rise up from ground into the pumpkin flock
console.log("Ascending into pumpkin flock...");
await page.keyboard.down("ArrowUp");
await page.waitForTimeout(300);
await page.keyboard.up("ArrowUp");

// Slash 1: Rapid diagonal slice through ascending pumpkins
console.log("Executing Slash 1 (Ascending diagonal cut)...");
await swipe(box.width * 0.22, box.height * 0.52, box.width * 0.48, box.height * 0.26, 12, 140);

// Dash attack cutting right through the middle cluster!
console.log("Executing Dash attack through middle cluster...");
await page.keyboard.down("ArrowRight");
await page.keyboard.press("Space");
await page.waitForTimeout(180);
await page.keyboard.up("ArrowRight");

// Slash 2: High-speed counter-cut slicing across upper pumpkins
console.log("Executing Slash 2 (Counter cross-cut)...");
await swipe(box.width * 0.78, box.height * 0.28, box.width * 0.32, box.height * 0.38, 14, 150);

// Dash attack left!
console.log("Executing Dash attack left...");
await page.keyboard.down("ArrowLeft");
await page.keyboard.press("Space");
await page.waitForTimeout(180);
await page.keyboard.up("ArrowLeft");

// Slash 3: Broad rising arc slice
console.log("Executing Slash 3 (Rising arc slice)...");
await swipe(box.width * 0.28, box.height * 0.42, box.width * 0.72, box.height * 0.24, 16, 200);

// Shriek shockwave to detonate remaining pumpkins!
console.log("Triggering Shriek shockwave!");
await page.keyboard.press("Enter");
await page.waitForTimeout(300);

// Slash 4: Rapid descending cross-cut on tumbling pumpkin halves
console.log("Executing Slash 4 (Descending slice)...");
await swipe(box.width * 0.68, box.height * 0.26, box.width * 0.42, box.height * 0.52, 14, 150);

// Settle smoothly for 1.2s to showcase the score, glowing splatters, and calm aftermath without abrupt cut
console.log("Letting gameplay settle gracefully...");
await page.waitForTimeout(1200);

const finalScore = await page.locator("#score").textContent();
console.log(`Action demonstration complete. HUD Score: ${finalScore}`);

// Note: Close context directly WITHOUT page.close() to avoid white frame flash
await context.close();
await browser.close();

console.log("Recording finalized!");
for (const file of fs.readdirSync(outputDir)) {
  const stat = fs.statSync(`${outputDir}/${file}`);
  console.log(`- ${file} (${stat.size} bytes)`);
}

process.exit(0);
