// In a real Chrome: clicking a file link is taken over by the app (here a
// stand-in bridge) and leaves nothing in Chrome's downloads; with the app
// closed Chrome downloads as normal. Run: node e2e/intercept.e2e.js
const assert = require('node:assert');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { launch, until, sleep } = require('./chrome.js');
const { startMockBridge } = require('../test/mock_bridge.js');

// A little web site: files, one behind a login cookie, and a page that makes a
// blob download.
function startSite() {
  const requests = [];
  const server = http.createServer((req, res) => {
    requests.push({ url: req.url, cookie: req.headers.cookie, referer: req.headers.referer });
    const attach = (name, type = 'application/zip') => {
      res.writeHead(200, { 'content-type': type, 'content-disposition': `attachment; filename="${name}"`, 'content-length': 2048 });
      res.end(Buffer.alloc(2048, 7));
    };
    if (req.url === '/a.zip') return attach('a.zip');
    if (req.url === '/private.zip') {
      if (!/session=abc/.test(req.headers.cookie || '')) { res.writeHead(403); return res.end('login first'); }
      return attach('private.zip');
    }
    if (req.url === '/notes.txt') return attach('notes.txt', 'text/plain');
    if (req.url === '/blob.html') {
      res.writeHead(200, { 'content-type': 'text/html' });
      return res.end('<a id=b>x</a><script>const a=document.getElementById("b");a.href=URL.createObjectURL(new Blob(["hello"]));a.download="blob.zip";</script>');
    }
    res.writeHead(404); res.end();
  });
  return new Promise((r) => server.listen(0, '127.0.0.1', () => r({ server, port: server.address().port, requests })));
}

(async () => {
  const root = path.join(__dirname, '..');
  execFileSync(path.join(root, 'build.sh'), ['chrome'], { stdio: 'pipe' });
  const site = await startSite();
  const downloads = fs.mkdtempSync(path.join(os.tmpdir(), 'haul-dl-'));
  let bridge = await startMockBridge({ token: 'secret' });
  const chrome = await launch({ extensionDir: path.join(root, 'dist/chrome'), downloadsDir: downloads });
  const worker = await chrome.worker();
  const configure = (b) => worker.eval(`chrome.storage.local.set({ token: 'secret', port: ${b.port} }).then(() => true)`);
  await configure(bridge);

  const files = () => fs.readdirSync(downloads).filter((f) => !f.startsWith('.'));
  const inChrome = () => worker.eval(`chrome.downloads.search({}).then((l) => l.map((d) => d.filename))`);
  const posts = () => bridge.log.filter((e) => e.method === 'POST' && e.url === '/v1/downloads').map((e) => JSON.parse(e.body));

  // A page of our own to navigate: each download starts as a navigation.
  const { targetId } = await chrome.cdp.send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await chrome.cdp.send('Target.attachToTarget', { targetId, flatten: true });
  await chrome.cdp.send('Page.enable', {}, sessionId);
  await chrome.cdp.send('Network.enable', {}, sessionId);
  const go = (url) => chrome.cdp.send('Page.navigate', { url }, sessionId);
  const site_ = `http://127.0.0.1:${site.port}`;

  let failed = 0;
  async function check(name, fn) {
    try { await fn(); console.log('  ok  ', name); } catch (e) { failed++; console.log('  FAIL', name, '\n      ', e.message); }
  }

  await check('a .zip link goes to the app and not to Chrome', async () => {
    await go(`${site_}/a.zip`);
    await until(() => posts().length === 1, 'the post to the app');
    const p = posts()[0];
    assert.equal(p.url, `${site_}/a.zip`);
    assert.equal(p.source, 'chrome');
    assert.match(p.userAgent, /Chrome\//);
    await until(async () => (await inChrome()).length === 0, 'Chrome’s own download to be erased');
    await sleep(500);
    assert.deepEqual(files().filter((f) => !f.endsWith('.crdownload')), [], 'no file saved by Chrome');
  });

  await check('a file behind a login carries the cookies', async () => {
    await chrome.cdp.send('Network.setCookie', { name: 'session', value: 'abc', url: site_ }, sessionId);
    await go(`${site_}/private.zip`);
    await until(() => posts().length === 2, 'the second post');
    const p = posts()[1];
    assert.match(p.cookies, /session=abc/);
    // The app can then fetch it as the browser would.
    const res = await fetch(p.url, { headers: { cookie: p.cookies } });
    assert.equal(res.status, 200);
    assert.equal((await fetch(p.url)).status, 403);
  });

  await check('the app\'s lists decide: a new type, and an excluded site', async () => {
    // The person adds "txt" in Haul's Settings; the extension picks it up.
    bridge.config.interceptExtensions = ['zip', 'txt'];
    await worker.eval(`chrome.alarms.onAlarm.dispatch({ name: 'haul-config' })`);
    await until(async () => (await worker.eval(`chrome.storage.local.get('config')`)).config?.interceptExtensions?.includes('txt'), 'the new list');
    const before = posts().length;
    await go(`${site_}/notes.txt`);
    await until(() => posts().length === before + 1, 'notes.txt to go to the app');
    await until(async () => (await inChrome()).length === 0, 'Chrome’s copy to be erased');
    // Excluding the site stops it again.
    bridge.config.excludedHosts = ['127.0.0.1'];
    await worker.eval(`chrome.alarms.onAlarm.dispatch({ name: 'haul-config' })`);
    await until(async () => (await worker.eval(`chrome.storage.local.get('config')`)).config?.excludedHosts?.includes('127.0.0.1'), 'the exclusion');
    fs.rmSync(path.join(downloads, 'a.zip'), { force: true });
    await go(`${site_}/a.zip`);
    await until(() => files().includes('a.zip'), 'Chrome to save a.zip');
    assert.equal(posts().length, before + 1);
    bridge.config.excludedHosts = [];
    bridge.config.interceptExtensions = ['zip'];
    await worker.eval(`chrome.alarms.onAlarm.dispatch({ name: 'haul-config' })`);
    await until(async () => !(await worker.eval(`chrome.storage.local.get('config')`)).config?.excludedHosts?.length, 'the exclusion to be lifted');
    fs.rmSync(path.join(downloads, 'a.zip'), { force: true });
    fs.rmSync(path.join(downloads, 'notes.txt'), { force: true });
  });

  await check('a type that is not on the list and is small stays in Chrome', async () => {
    const before = posts().length;
    await go(`${site_}/notes.txt`);
    await until(() => files().includes('notes.txt'), 'Chrome to save notes.txt');
    assert.equal(posts().length, before);
  });

  await check('a blob: download stays in Chrome', async () => {
    const before = posts().length;
    await go(`${site_}/blob.html`);
    await sleep(500);
    await chrome.cdp.send('Runtime.enable', {}, sessionId);
    await chrome.cdp.send('Runtime.evaluate', { expression: 'document.getElementById("b").click()', userGesture: true }, sessionId);
    await until(() => files().includes('blob.zip'), 'Chrome to save blob.zip');
    assert.equal(posts().length, before);
  });

  await check('with the switch off nothing is taken over', async () => {
    await worker.eval(`chrome.storage.local.set({ enabled: false }).then(() => true)`);
    const before = posts().length;
    fs.rmSync(path.join(downloads, 'a.zip'), { force: true });
    await go(`${site_}/a.zip`);
    await until(() => files().includes('a.zip'), 'Chrome to save a.zip');
    assert.equal(posts().length, before);
    await worker.eval(`chrome.storage.local.set({ enabled: true }).then(() => true)`);
    fs.rmSync(path.join(downloads, 'a.zip'), { force: true });
  });

  await check('with the app closed Chrome downloads as normal', async () => {
    await bridge.close();
    fs.rmSync(path.join(downloads, 'a.zip'), { force: true });
    await go(`${site_}/a.zip`);
    await until(() => files().includes('a.zip'), 'Chrome to save a.zip');
    await until(async () => (await inChrome()).some((f) => f.endsWith('a.zip')), 'it in Chrome’s list');
  });

  await check('an app that refuses leaves the download with Chrome', async () => {
    bridge = await startMockBridge({ token: 'secret', accept: false });
    await configure(bridge);
    fs.rmSync(path.join(downloads, 'a.zip'), { force: true });
    await go(`${site_}/a.zip`);
    await until(() => files().includes('a.zip'), 'Chrome to save a.zip');
  });

  await chrome.close();
  await bridge.close();
  site.server.close();
  fs.rmSync(downloads, { recursive: true, force: true });
  console.log(failed ? `${failed} failed` : 'all passed');
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
