// In a real Chrome: the link menu item sends a link whose type is NOT on
// the intercept list. Run: node e2e/linkmenu.e2e.js
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
  await worker.eval(`chrome.storage.local.set({ token: 'secret', port: ${bridge.port} }).then(() => true)`);
  let failed = 0;
  async function check(name, fn) {
    try { await fn(); console.log('  ok  ', name); } catch (e) { failed++; console.log('  FAIL', name, '\n      ', e.message); }
  }
  const posts = () => bridge.log.filter((e) => e.method === 'POST').map((e) => JSON.parse(e.body));
  // The menu's own listener, called the way the browser calls it.
  const click = (info) => worker.eval(`new Promise((resolve) => { chrome.contextMenus.onClicked.dispatch(${JSON.stringify(info)}, { url: 'https://site.example/page' }); setTimeout(resolve, 600); })`);

  await check('the menu item exists', async () => {
    // Creating it twice fails with a duplicate id, which proves it is there.
    const err = await worker.eval(`new Promise((r) => { chrome.contextMenus.create({ id: 'haul-download-link', title: 'x', contexts: ['link'] }, () => r(chrome.runtime.lastError && chrome.runtime.lastError.message)); })`);
    assert.match(String(err), /duplicate id/);
  });

  await check('a link outside the intercept list is sent, with the page as referrer', async () => {
    await click({ menuItemId: 'haul-download-link', linkUrl: 'https://files.example/data.csv', pageUrl: 'https://site.example/page' });
    await until(() => posts().length === 1, 'the post');
    const p = posts()[0];
    assert.equal(p.url, 'https://files.example/data.csv');
    assert.equal(p.referrer, 'https://site.example/page');
    assert.equal(p.source, 'chrome');
  });

  await check('another menu item or a non-http link sends nothing', async () => {
    await click({ menuItemId: 'other', linkUrl: 'https://files.example/x.csv' });
    await click({ menuItemId: 'haul-download-link', linkUrl: 'javascript:alert(1)' });
    await click({ menuItemId: 'haul-download-link', linkUrl: 'ftp://files.example/x.csv' });
    assert.equal(posts().length, 1);
  });

  await check('with the app closed the toolbar button says so', async () => {
    await bridge.close();
    await click({ menuItemId: 'haul-download-link', linkUrl: 'https://files.example/data.csv' });
    const title = await worker.eval(`chrome.action.getTitle({})`);
    const badge = await worker.eval(`chrome.action.getBadgeText({})`);
    assert.equal(badge, '!');
    assert.equal(title, 'Haul is not running');
  });

  await chrome.close();
  console.log(failed ? `${failed} failed` : 'all passed');
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
