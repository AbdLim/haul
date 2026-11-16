// In a real Chrome: the options page and the popup, against a stand-in
// bridge. Run: node e2e/options.e2e.js
const assert = require('node:assert');
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const { launch, until } = require('./chrome.js');
const { startMockBridge } = require('../test/mock_bridge.js');

(async () => {
  const root = path.join(__dirname, '..');
  execFileSync(path.join(root, 'build.sh'), ['chrome'], { stdio: 'pipe' });
  const bridge = await startMockBridge({ token: 'secret' });
  const chrome = await launch({ extensionDir: path.join(root, 'dist/chrome') });
  const base = `chrome-extension://${chrome.extensionId}`;
  let failed = 0;
  async function check(name, fn) {
    try { await fn(); console.log('  ok  ', name); } catch (e) { failed++; console.log('  FAIL', name, '\n      ', e.message); }
  }

  const options = await chrome.open(`${base}/options.html`);
  const type = (id, value) => options.eval(`(() => { const e = document.getElementById('${id}'); e.value = ${JSON.stringify(value)}; e.dispatchEvent(new Event('input')); })()`);
  const result = () => options.eval(`document.getElementById('result').textContent`);
  const press = async () => { await options.eval(`document.getElementById('test').click()`); await until(async () => !(await result()).startsWith('Testing'), 'the test to finish', 6000); return result(); };
  const stored = async () => (await chrome.worker()).eval(`chrome.storage.local.get(null)`);

  await check('before the first sync the standard lists show, read-only', async () => {
    assert.equal(await options.eval(`document.getElementById('port').value`), '47821');
    assert.match(await options.eval(`document.getElementById('extensions').textContent`), /^zip rar 7z/);
    assert.equal(await options.eval(`document.getElementById('minSize').textContent`), '1 MB');
    assert.equal(await options.eval(`document.getElementById('excluded').textContent`), 'None');
    // Nothing on the page edits the lists.
    assert.equal(await options.eval(`document.querySelectorAll('textarea').length`), 0);
    assert.match(await options.eval(`document.getElementById('note').textContent`), /Change them in Haul’s Settings/);
  });

  await check('a right token reports success', async () => {
    await type('port', String(bridge.port));
    await type('token', 'secret');
    assert.match(await press(), /^Connected to Haul 1\.0\.0\./);
  });

  await check('a wrong token says the token is wrong', async () => {
    await type('token', 'wrong');
    assert.match(await press(), /did not accept this token/);
  });

  await check('with the app closed it says so and names the port', async () => {
    await type('port', '47999');
    assert.match(await press(), /did not answer on port 47999/);
  });

  await check('the token and port are saved to storage.local', async () => {
    await type('port', String(bridge.port));
    await type('token', 'secret');
    await new Promise((r) => setTimeout(r, 600));
    const s = await stored();
    assert.equal(s.port, bridge.port);
    assert.equal(s.token, 'secret');
  });

  await check('Test connection shows the app\'s lists', async () => {
    assert.match(await press(), /^Connected/);
    assert.equal(await options.eval(`document.getElementById('extensions').textContent`), 'zip');
    assert.equal(await options.eval(`document.getElementById('excluded').textContent`), 'blocked.example');
    assert.match(await options.eval(`document.getElementById('synced').textContent`), /Updated from Haul at/);
  });

  const popup = await chrome.open(`${base}/popup.html`);
  const status = () => popup.eval(`document.getElementById('status').textContent`);
  await check('the popup says whether Haul is reachable', async () => {
    await until(async () => (await status()) === 'Haul is running.', 'the popup status');
  });

  await check('the popup switch persists', async () => {
    await popup.eval(`(() => { const e = document.getElementById('enabled'); e.checked = false; e.dispatchEvent(new Event('change')); })()`);
    await new Promise((r) => setTimeout(r, 300));
    assert.equal((await stored()).enabled, false);
    const again = await chrome.open(`${base}/popup.html`);
    assert.equal(await again.eval(`document.getElementById('enabled').checked`), false);
  });

  await check('the popup reports the app closed', async () => {
    await bridge.close();
    const p = await chrome.open(`${base}/popup.html`);
    await until(async () => /did not answer/.test(await p.eval(`document.getElementById('status').textContent`)), 'the closed message');
  });

  await chrome.close();
  console.log(failed ? `${failed} failed` : 'all passed');
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
