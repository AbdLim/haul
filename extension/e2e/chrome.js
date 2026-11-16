// Drives a real Chrome (headless) with the built extension loaded, over the
// DevTools protocol. Used by the end-to-end checks; needs Google Chrome.
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function until(fn, what, ms = 8000) {
  const end = Date.now() + ms;
  for (;;) {
    const v = await fn();
    if (v) return v;
    if (Date.now() > end) throw new Error(`Timed out waiting for ${what}`);
    await sleep(100);
  }
}

class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.next = 1;
    this.pending = new Map();
    this.listeners = [];
    ws.addEventListener('message', (e) => {
      const m = JSON.parse(e.data);
      if (m.id && this.pending.has(m.id)) {
        const { resolve, reject } = this.pending.get(m.id);
        this.pending.delete(m.id);
        m.error ? reject(new Error(m.error.message)) : resolve(m.result);
      } else if (m.method) {
        for (const l of this.listeners) l(m);
      }
    });
  }
  send(method, params = {}, sessionId) {
    const id = this.next++;
    this.ws.send(JSON.stringify({ id, method, params, sessionId }));
    return new Promise((resolve, reject) => this.pending.set(id, { resolve, reject }));
  }
  on(fn) { this.listeners.push(fn); }
}

async function launch({ extensionDir, downloadsDir }) {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'haul-chrome-'));
  const port = 9300 + Math.floor(Math.random() * 500);
  const proc = spawn(CHROME, [
    '--headless=new', `--user-data-dir=${profile}`, `--remote-debugging-port=${port}`,
    // Branded Chrome ignores --load-extension; this flag allows the protocol call below.
    '--enable-unsafe-extension-debugging',
    '--no-first-run', '--no-default-browser-check', 'about:blank',
  ], { stdio: 'ignore' });

  const version = await until(async () => {
    try { return await (await fetch(`http://127.0.0.1:${port}/json/version`)).json(); } catch (_) { return null; }
  }, 'Chrome to start');
  const cdp = new Cdp(new WebSocket(version.webSocketDebuggerUrl));
  await new Promise((r) => cdp.ws.addEventListener('open', r));

  if (downloadsDir) {
    await cdp.send('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: downloadsDir, eventsEnabled: true });
  }

  const targets = async () => (await cdp.send('Target.getTargets')).targetInfos;
  const loaded = await cdp.send('Extensions.loadUnpacked', { path: extensionDir });
  const extensionId = loaded.id;
  await until(async () => (await targets()).find((t) => t.type === 'service_worker' && t.url.startsWith(`chrome-extension://${extensionId}/`)), 'the extension service worker');

  async function attach(targetId) {
    const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });
    await cdp.send('Runtime.enable', {}, sessionId);
    await sleep(150);
    return {
      sessionId,
      eval: async (expression) => {
        const r = await cdp.send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, sessionId);
        if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
        return r.result.value;
      },
    };
  }

  return {
    cdp, extensionId, proc, profile,
    targets,
    // Runs code inside the extension's service worker.
    worker: async () => attach((await targets()).find((t) => t.type === 'service_worker' && t.url.includes(extensionId)).targetId),
    // Opens a page and returns a handle to it.
    open: async function (url) {
      // Extension pages cannot be opened from outside; ask the extension.
      const before = new Set((await targets()).map((t) => t.targetId));
      if (url.startsWith('chrome-extension://')) {
        await (await this.worker()).eval(`chrome.tabs.create({ url: ${JSON.stringify(url)} }).then(() => true)`);
      } else {
        await cdp.send('Target.createTarget', { url });
      }
      const { targetId } = await until(async () => (await targets()).find((t) => t.type === 'page' && !before.has(t.targetId) && t.url.startsWith(url.split('?')[0])), 'the page to open');
      const page = await attach(targetId);
      page.targetId = targetId;
      await until(async () => (await page.eval(`location.href === ${JSON.stringify(url)} && document.readyState === 'complete' && !!document.body && document.body.children.length > 0`)), `the page to load (${await page.eval('location.href + " " + document.readyState')})`);
      return page;
    },
    close: async () => {
      try { await cdp.send('Browser.close'); } catch (_) { /* already gone */ }
      proc.kill();
      fs.rmSync(profile, { recursive: true, force: true, maxRetries: 3 });
    },
  };
}

module.exports = { launch, until, sleep };
