const test = require('node:test');
const assert = require('node:assert');
const net = require('node:net');
const http = require('node:http');

// common.js picks `chrome` or `browser` at load; a bare stub is enough here.
globalThis.chrome = { storage: { local: { get: async (d) => d, set: async () => {} } } };
const C = require('../src/common.js');
const { startMockBridge } = require('./mock_bridge.js');

async function freePort() {
  return new Promise((resolve) => {
    const s = net.createServer();
    s.listen(0, '127.0.0.1', () => { const { port } = s.address(); s.close(() => resolve(port)); });
  });
}

test('the defaults', () => {
  assert.equal(C.DEFAULTS.enabled, true);
  assert.equal(C.DEFAULTS.interceptMinBytes, 1048576);
  assert.deepEqual(C.DEFAULTS.interceptExtensions, [
    'zip', 'rar', '7z', 'tar', 'gz', 'dmg', 'pkg', 'iso', 'exe', 'msi', 'apk',
    'mp4', 'mkv', 'mov', 'avi', 'mp3', 'flac', 'wav', 'pdf', 'epub',
  ]);
});

test('parseExtensions cleans, lowercases and removes duplicates', () => {
  assert.deepEqual(C.parseExtensions('zip, .RAR  7z;zip\niso'), ['zip', 'rar', '7z', 'iso']);
  assert.deepEqual(C.parseExtensions('  '), []);
});

test('parseHosts cuts links down to the host', () => {
  assert.deepEqual(
    C.parseHosts('Example.com\nhttps://cdn.site.org/a/b?x=1, files.net:8080'),
    ['example.com', 'cdn.site.org', 'files.net'],
  );
});

test('testConnection: connected', async () => {
  const b = await startMockBridge();
  const r = await C.testConnection(b.port, 'secret');
  assert.equal(r.state, 'ok');
  assert.match(r.message, /Connected to Haul 1\.0\.0/);
  assert.deepEqual(r.config.excludedHosts, ['blocked.example']);
  await b.close();
});

test('testConnection: wrong token says the token is wrong', async () => {
  const b = await startMockBridge();
  const r = await C.testConnection(b.port, 'nope');
  assert.equal(r.state, 'badToken');
  assert.match(r.message, /did not accept this token/);
  await b.close();
});

test('testConnection: no token yet', async () => {
  const b = await startMockBridge();
  const r = await C.testConnection(b.port, '');
  assert.equal(r.state, 'noToken');
  await b.close();
});

test('testConnection: app closed names the port', async () => {
  const port = await freePort();
  const r = await C.testConnection(port, 'secret');
  assert.equal(r.state, 'unreachable');
  assert.match(r.message, new RegExp(`port ${port}`));
});

test('ping gives up after its timeout', async () => {
  const hang = http.createServer(() => {});
  await new Promise((r) => hang.listen(0, '127.0.0.1', r));
  const started = Date.now();
  const r = await C.ping(hang.address().port, 300);
  assert.equal(r.ok, false);
  assert.ok(Date.now() - started < 1500);
  hang.closeAllConnections();
  hang.close();
});

test('something that is not Haul on the port is not Haul', async () => {
  const other = http.createServer((_, res) => { res.end('{"app":"Other"}'); });
  await new Promise((r) => other.listen(0, '127.0.0.1', r));
  const r = await C.ping(other.address().port);
  assert.equal(r.ok, false);
  other.close();
});
