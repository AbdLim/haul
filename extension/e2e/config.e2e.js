// In a real Chrome: the app's lists reach the extension by themselves
// within 60 seconds (a real alarm, no nudging), and the last lists are kept
// when the app is closed. Takes about a minute. Run: node e2e/config.e2e.js
const assert = require('node:assert');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { launch, until } = require('./chrome.js');
const { startMockBridge } = require('../test/mock_bridge.js');

(async () => {
  const root = path.join(__dirname, '..');
  execFileSync(path.join(root, 'build.sh'), ['chrome'], { stdio: 'pipe' });
  const bridge = await startMockBridge({ token: 'secret' });
  const chrome = await launch({ extensionDir: path.join(root, 'dist/chrome') });
  const worker = await chrome.worker();
  const config = async () => (await worker.eval(`chrome.storage.local.get('config')`)).config;
  let failed = 0;
  async function check(name, fn) {
    try { await fn(); console.log('  ok  ', name); } catch (e) { failed++; console.log('  FAIL', name, '\n      ', e.message); }
  }

  await check('the lists are fetched when the extension has a token', async () => {
    await worker.eval(`chrome.storage.local.set({ token: 'secret', port: ${bridge.port} }).then(() => true)`);
    // Opening the popup fetches them straight away.
    await chrome.open(`chrome-extension://${chrome.extensionId}/popup.html`);
    await until(async () => (await config())?.interceptExtensions?.join() === 'zip', 'the first fetch');
  });

  await check('a change made in Haul arrives by itself within 60 seconds', async () => {
    const started = Date.now();
    bridge.config.interceptExtensions = ['zip', 'iso'];
    bridge.config.excludedHosts = ['example.com'];
    await until(async () => (await config())?.interceptExtensions?.includes('iso'), 'the alarm to fetch', 75000);
    const took = (Date.now() - started) / 1000;
    console.log(`        arrived after ${took.toFixed(0)} s`);
    assert.ok(took <= 65, `took ${took} s`);
    assert.deepEqual((await config()).excludedHosts, ['example.com']);
  });

  await check('with the app closed the last lists stay in force', async () => {
    await bridge.close();
    await new Promise((r) => setTimeout(r, 1500));
    assert.deepEqual((await config()).interceptExtensions, ['zip', 'iso']);
    const options = await chrome.open(`chrome-extension://${chrome.extensionId}/options.html`);
    assert.equal(await options.eval(`document.getElementById('extensions').textContent`), 'zip iso');
    assert.equal(await options.eval(`document.getElementById('excluded').textContent`), 'example.com');
  });

  await chrome.close();
  console.log(failed ? `${failed} failed` : 'all passed');
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
