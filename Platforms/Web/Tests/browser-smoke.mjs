const endpoint = process.env.CHROME_DEBUG_URL ?? "http://127.0.0.1:9222";
const deadline = Date.now() + 30_000;

async function pageTarget() {
  while (Date.now() < deadline) {
    try {
      const targets = await fetch(`${endpoint}/json/list`).then((response) => response.json());
      const page = targets.find((target) => target.type === "page");
      if (page) return page;
    } catch {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Chrome DevTools page target did not become ready");
}

const target = await pageTarget();
const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener("open", resolve, { once: true });
  socket.addEventListener("error", reject, { once: true });
});

let nextID = 0;
const pending = new Map();
const exceptions = [];
const logs = [];
socket.addEventListener("message", (event) => {
  const message = JSON.parse(event.data);
  if (message.method === "Runtime.exceptionThrown") exceptions.push(message.params);
  if (message.method === "Log.entryAdded") logs.push(message.params.entry);
  if (!message.id) return;
  const continuation = pending.get(message.id);
  if (!continuation) return;
  pending.delete(message.id);
  if (message.error) continuation.reject(new Error(message.error.message));
  else continuation.resolve(message.result);
});

function command(method, params = {}) {
  const id = ++nextID;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
}

async function evaluate(expression) {
  const result = await command("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true,
  });
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
  return result.result.value;
}

await command("Runtime.enable");
await command("Log.enable");
await command("Page.enable");
exceptions.length = 0;
logs.length = 0;
await command("Page.reload", { ignoreCache: true });
while (Date.now() < deadline && !(await evaluate("document.documentElement.dataset.swiftReady === 'true'"))) {
  await new Promise((resolve) => setTimeout(resolve, 100));
}

const ready = await evaluate(`(() => {
  const canvas = document.querySelector('#game');
  return document.documentElement.dataset.swiftReady === 'true'
    && canvas.width > 0 && canvas.height > 0;
})()`);
if (!ready) {
  const phase = await evaluate("document.documentElement.dataset.swiftPhase ?? 'not-started'");
  throw new Error(
    `Swift/Wasm game stopped during ${phase}. Exceptions: ${JSON.stringify(exceptions)} Logs: ${JSON.stringify(logs)}`
  );
}

await evaluate("document.querySelector('#play').click(); true");
await new Promise((resolve) => setTimeout(resolve, 250));
const started = await evaluate("document.querySelector('#menu').classList.contains('hidden')");
if (!started) throw new Error("Play control did not start the game");

await evaluate(`(() => {
  window.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight' }));
  window.dispatchEvent(new KeyboardEvent('keyup', { key: 'ArrowRight' }));
  const canvas = document.querySelector('#game');
  const rect = canvas.getBoundingClientRect();
  canvas.dispatchEvent(new PointerEvent('pointerdown', {
    pointerId: 1, clientX: rect.left + rect.width / 2, clientY: rect.top + rect.height / 2
  }));
  window.dispatchEvent(new PointerEvent('pointerup', {
    pointerId: 1, clientX: rect.left + rect.width / 2, clientY: rect.top + rect.height / 2
  }));
  return true;
})()`);
await new Promise((resolve) => setTimeout(resolve, 250));
if (exceptions.length) throw new Error(`Browser exceptions: ${JSON.stringify(exceptions)}`);

console.log("Chromium WebAssembly smoke test passed: load, start, keyboard, and pointer paths.");
socket.close();
