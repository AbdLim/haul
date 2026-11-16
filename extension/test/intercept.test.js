const test = require('node:test');
const assert = require('node:assert');

globalThis.chrome = { storage: { local: { get: async (d) => d, set: async () => {} } } };
const C = require('../src/common.js');
const { startMockBridge } = require('./mock_bridge.js');

const settings = (over = {}) => ({ ...C.DEFAULTS, ...over });
const item = (over = {}) => ({ id: 1, url: 'https://example.com/files/a.zip', filename: '', ...over });
const verdict = (i, s = settings()) => C.shouldIntercept(i, s, 'me');

test('a listed type is taken, whatever its size', () => {
  assert.equal(verdict(item()).ok, true);
  assert.equal(verdict(item({ url: 'https://e.com/x/Movie.MKV?sig=1', fileSize: 10 })).ok, true);
});

test('the file name wins over the link when the browser knows it', () => {
  assert.equal(verdict(item({ url: 'https://e.com/download?id=7', filename: '/Users/a/Downloads/setup.dmg' })).ok, true);
});

test('check 1: the switch', () => {
  assert.equal(verdict(item(), settings({ enabled: false })).ok, false);
});

test('check 2: only http and https', () => {
  for (const url of ['blob:https://e.com/1234', 'data:text/plain,hi', 'ftp://e.com/a.zip', 'file:///a.zip']) {
    assert.equal(verdict(item({ url })).ok, false, url);
  }
  assert.equal(verdict(item({ url: 'http://e.com/a.zip' })).ok, true);
});

test('check 3: not one the extension started itself', () => {
  assert.equal(verdict(item({ byExtensionId: 'me' })).ok, false);
  assert.equal(verdict(item({ byExtensionId: 'someone-else' })).ok, true);
});

test('check 4: excluded sites, including sub-sites and where it redirected', () => {
  const s = settings({ excludedHosts: ['example.com'] });
  assert.equal(verdict(item(), s).ok, false);
  assert.equal(verdict(item({ url: 'https://dl.example.com/a.zip' }), s).ok, false);
  assert.equal(verdict(item({ url: 'https://e2.org/a.zip', finalUrl: 'https://cdn.example.com/a.zip' }), s).ok, false);
  assert.equal(verdict(item({ url: 'https://notexample.com/a.zip' }), s).ok, true);
});

test('check 5: a type not on the list needs a known size at least the minimum', () => {
  const plain = { url: 'https://e.com/video.webm' };
  assert.equal(verdict(item({ ...plain })).ok, false);
  assert.equal(verdict(item({ ...plain, fileSize: 1048575 })).ok, false);
  assert.equal(verdict(item({ ...plain, fileSize: 1048576 })).ok, true);
  assert.equal(verdict(item({ ...plain, totalBytes: 5e6 })).ok, true);
  assert.equal(verdict(item({ ...plain, fileSize: -1 })).ok, false);
});

test('the lists and the minimum come from the settings', () => {
  const s = settings({ interceptExtensions: ['iso'], interceptMinBytes: 100 });
  assert.equal(verdict(item(), s).ok, false);
  assert.equal(verdict(item({ url: 'https://e.com/a.iso' }), s).ok, true);
  assert.equal(verdict(item({ url: 'https://e.com/a.webm', fileSize: 100 }), s).ok, true);
});

test('cookies are joined as name=value; name=value', () => {
  assert.equal(C.cookieHeader([{ name: 'a', value: '1' }, { name: 'b', value: '2' }]), 'a=1; b=2');
  assert.equal(C.cookieHeader([{ name: 'a', value: '1' }, { name: 'a', value: '9' }]), 'a=9');
  assert.equal(C.cookieHeader([]), '');
});

test('the payload carries only what is known', () => {
  const p = C.buildPayload(
    item({ referrer: 'https://example.com/dl', finalUrl: 'https://cdn.e.com/a.zip?s=1', mime: 'application/zip', fileSize: 99 }),
    [{ name: 'session', value: 'abc' }], 'UA/1', 'chrome',
  );
  assert.deepEqual(p, {
    url: 'https://example.com/files/a.zip', source: 'chrome', finalUrl: 'https://cdn.e.com/a.zip?s=1',
    referrer: 'https://example.com/dl', userAgent: 'UA/1', cookies: 'session=abc',
    mimeType: 'application/zip', fileSize: 99,
  });
  // No file name yet, no cookies, no size: none of them is sent.
  const bare = C.buildPayload(item(), [], '', 'firefox');
  assert.deepEqual(bare, { url: 'https://example.com/files/a.zip', source: 'firefox' });
  // A name that is known is just the leaf.
  assert.equal(C.buildPayload(item({ filename: '/Users/a/Downloads/x.zip' }), [], '', 'chrome').fileName, 'x.zip');
});

test('postDownload: accepted gives the id, a refusal gives the status', async () => {
  const b = await startMockBridge({ token: 'secret' });
  const ok = await C.postDownload(b.port, 'secret', { url: 'https://e.com/a.zip', source: 'chrome' });
  assert.equal(ok.ok, true);
  assert.match(ok.id, /^id-/);
  const bad = await C.postDownload(b.port, 'wrong', { url: 'https://e.com/a.zip', source: 'chrome' });
  assert.deepEqual(bad, { ok: false, status: 401 });
  await b.close();
  assert.deepEqual(await C.postDownload(b.port, 'secret', {}), { ok: false, status: 0 });
});

test('the link menu sends the link with the page as referrer', () => {
  assert.deepEqual(
    C.buildLinkPayload('https://e.com/a.bin', 'https://e.com/page', [{ name: 's', value: '1' }], 'UA', 'firefox'),
    { url: 'https://e.com/a.bin', source: 'firefox', referrer: 'https://e.com/page', userAgent: 'UA', cookies: 's=1' },
  );
  assert.deepEqual(C.buildLinkPayload('https://e.com/a.bin', '', [], '', 'chrome'), { url: 'https://e.com/a.bin', source: 'chrome' });
});

test('the app’s lists replace the standard ones once fetched', () => {
  const s = settings({ config: { enabled: true, interceptExtensions: ['iso'], interceptMinBytes: 10, excludedHosts: ['x.com'] } });
  assert.equal(C.shouldIntercept(item({ url: 'https://e.com/a.zip' }), s, 'me').ok, false);
  assert.equal(C.shouldIntercept(item({ url: 'https://e.com/a.iso' }), s, 'me').ok, true);
  assert.equal(C.shouldIntercept(item({ url: 'https://x.com/a.iso' }), s, 'me').ok, false);
  assert.equal(C.shouldIntercept(item({ url: 'https://e.com/a.bin', fileSize: 10 }), s, 'me').ok, true);
});

test('the app can switch interception off, and the popup cannot switch it back on', () => {
  const off = settings({ config: { enabled: false, interceptExtensions: ['zip'], interceptMinBytes: 1, excludedHosts: [] } });
  assert.equal(C.shouldIntercept(item(), off, 'me').ok, false);
  const popupOff = settings({ enabled: false, config: { enabled: true, interceptExtensions: ['zip'], interceptMinBytes: 1, excludedHosts: [] } });
  assert.equal(C.shouldIntercept(item(), popupOff, 'me').ok, false);
});
