// Firefox is not installed on the machine this was written on, so this runs the
// Firefox build's background scripts the way Firefox does (as plain scripts in
// one shared scope, with a promise-based `browser` and no `importScripts`).
// It proves the file order and the `browser` wrapper work; it does not replace
// loading the add-on in Firefox.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
const { startMockBridge } = require('./mock_bridge.js');

const root = path.join(__dirname, '..');

function fakeEvent() {
  const listeners = [];
  return { addListener: (l) => listeners.push(l), fire: (...a) => listeners.map((l) => l(...a)), listeners };
}

async function loadFirefoxBackground(stored) {
  execFileSync(path.join(root, 'build.sh'), ['firefox'], { stdio: 'pipe' });
  const dir = path.join(root, 'dist/firefox');
  const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json')));
  const events = { onCreated: fakeEvent(), onInstalled: fakeEvent(), onClicked: fakeEvent(), onAlarm: fakeEvent() };
  const calls = [];
  const browser = {
    runtime: {
      id: 'haul@dev.haul.app',
      onInstalled: events.onInstalled,
      onStartup: fakeEvent(),
      openOptionsPage: async () => {},
    },
    alarms: { create: (name, info) => calls.push(['alarm', name, info.periodInMinutes]), onAlarm: events.onAlarm },
    storage: { local: { get: async (d) => ({ ...d, ...stored }), set: async () => {} } },
    downloads: {
      onCreated: events.onCreated,
      cancel: async (id) => calls.push(['cancel', id]),
      erase: async (q) => calls.push(['erase', q.id]),
      search: async () => [],
      removeFile: async () => {},
    },
    cookies: { getAll: async () => [{ name: 'session', value: 'abc' }] },
    contextMenus: { create: (o) => calls.push(['menu', o.title]), onClicked: events.onClicked },
    action: { setBadgeText() {}, setTitle() {} },
  };
  const context = {
    browser, fetch, AbortController, setTimeout, clearTimeout, URL, JSON, console,
    navigator: { userAgent: 'Mozilla/5.0 (Macintosh) Gecko/20100101 Firefox/130.0' },
  };
  context.self = context;
  vm.createContext(context);
  for (const file of manifest.background.scripts) {
    vm.runInContext(fs.readFileSync(path.join(dir, file), 'utf8'), context, { filename: file });
  }
  return { events, calls, context };
}

test('Firefox: the scripts load in order and register their listeners', async () => {
  const { events, context } = await loadFirefoxBackground({});
  assert.equal(typeof context.importScripts, 'undefined');
  assert.equal(events.onCreated.listeners.length, 1);
  assert.equal(events.onInstalled.listeners.length, 1);
  assert.equal(events.onClicked.listeners.length, 1);
});

test('Firefox: a download is taken over and the menu item is made', async () => {
  const bridge = await startMockBridge({ token: 'secret' });
  const { events, calls } = await loadFirefoxBackground({ token: 'secret', port: bridge.port });
  events.onInstalled.fire();
  assert.deepEqual(calls.filter((c) => c[0] === 'menu'), [['menu', 'Download with Haul']]);
  assert.deepEqual(calls.find((c) => c[0] === 'alarm'), ['alarm', 'haul-config', 1]);

  events.onCreated.fire({ id: 7, url: 'https://example.com/a.zip', filename: '' });
  for (let i = 0; i < 50 && !calls.some((c) => c[0] === 'erase'); i++) await new Promise((r) => setTimeout(r, 50));
  const post = bridge.log.find((e) => e.method === 'POST');
  const body = JSON.parse(post.body);
  assert.equal(body.source, 'firefox');
  assert.equal(body.cookies, 'session=abc');
  assert.match(body.userAgent, /Firefox\//);
  assert.deepEqual(calls.filter((c) => c[0] === 'cancel' || c[0] === 'erase'), [['cancel', 7], ['erase', 7]]);
  await bridge.close();
});

test('Firefox: with the app closed the browser keeps the download', async () => {
  const bridge = await startMockBridge({ token: 'secret' });
  const port = bridge.port;
  await bridge.close();
  const { events, calls } = await loadFirefoxBackground({ token: 'secret', port });
  events.onCreated.fire({ id: 8, url: 'https://example.com/a.zip', filename: '' });
  await new Promise((r) => setTimeout(r, 800));
  assert.deepEqual(calls.filter((c) => c[0] === 'cancel' || c[0] === 'erase'), []);
});
