// Checks the built extension is complete: every file a manifest names exists.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const root = path.join(__dirname, '..');

function filesNamedBy(manifest) {
  const files = new Set(Object.values(manifest.icons || {}));
  const bg = manifest.background || {};
  if (bg.service_worker) files.add(bg.service_worker);
  for (const s of bg.scripts || []) files.add(s);
  if (manifest.action) {
    files.add(manifest.action.default_popup);
    for (const f of Object.values(manifest.action.default_icon || {})) files.add(f);
  }
  if (manifest.options_ui) files.add(manifest.options_ui.page);
  return [...files].filter(Boolean);
}

for (const target of ['chrome', 'firefox']) {
  test(`${target}: the build holds every file the manifest names`, () => {
    execFileSync(path.join(root, 'build.sh'), [target], { stdio: 'pipe' });
    const dir = path.join(root, 'dist', target);
    const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json')));
    assert.equal(manifest.manifest_version, 3);
    for (const f of filesNamedBy(manifest)) {
      assert.ok(fs.existsSync(path.join(dir, f)), `${target}: missing ${f}`);
    }
  });
}

test('the Chrome manifest asks for exactly the permissions it needs', () => {
  const m = JSON.parse(fs.readFileSync(path.join(root, 'manifest.chrome.json')));
  assert.deepEqual([...m.permissions].sort(), ['alarms', 'contextMenus', 'cookies', 'downloads', 'storage']);
  assert.deepEqual([...m.host_permissions].sort(), ['<all_urls>', 'http://127.0.0.1/*']);
});

test('the Firefox manifest differs only where Firefox needs it', () => {
  const c = JSON.parse(fs.readFileSync(path.join(root, 'manifest.chrome.json')));
  const f = JSON.parse(fs.readFileSync(path.join(root, 'manifest.firefox.json')));
  assert.deepEqual(f.permissions, c.permissions);
  assert.deepEqual(f.host_permissions, c.host_permissions);
  assert.deepEqual(f.action, c.action);
  assert.deepEqual(f.options_ui, c.options_ui);
  assert.deepEqual(f.background, { scripts: ['common.js', 'background.js'] });
  assert.equal(c.background.service_worker, 'background.js');
  assert.match(f.browser_specific_settings.gecko.id, /@/);
});

test('Firefox loads the shared code before the background script', () => {
  const f = JSON.parse(fs.readFileSync(path.join(root, 'manifest.firefox.json')));
  const scripts = f.background.scripts;
  assert.ok(scripts.indexOf('common.js') < scripts.indexOf('background.js'));
});

test('the source reaches for `browser` first and only falls back to `chrome`', () => {
  const common = fs.readFileSync(path.join(root, 'src/common.js'), 'utf8');
  assert.match(common, /typeof browser !== 'undefined' \? browser : chrome/);
  // No other file touches `chrome.` directly except for the one MV3 worker
  // check in tests.
  for (const f of ['background.js', 'options.js', 'popup.js']) {
    const text = fs.readFileSync(path.join(root, 'src', f), 'utf8').replace(/\/\/.*$/gm, '');
    assert.doesNotMatch(text, /\bchrome\./, `${f} uses chrome. directly`);
  }
});

// -- the store packages -------------------------------------------------------

const version = JSON.parse(fs.readFileSync(path.join(root, 'manifest.chrome.json'))).version;

function listZip(file) {
  return execFileSync('unzip', ['-Z1', file]).toString().split('\n').filter(Boolean);
}

for (const target of ['chrome', 'firefox']) {
  test(`${target}: the zip holds the built extension and nothing else`, () => {
    execFileSync(path.join(root, 'build.sh'), ['package'], { stdio: 'pipe' });
    const zip = path.join(root, 'dist', `haul-${target}-${version}.zip`);
    const entries = listZip(zip).filter((e) => !e.endsWith('/'));
    assert.ok(entries.includes('manifest.json'), 'manifest.json is at the top');

    // The same files as the source, plus the manifest.
    const src = fs.readdirSync(path.join(root, 'src'), { recursive: true })
      .filter((f) => fs.statSync(path.join(root, 'src', f)).isFile());
    assert.deepEqual([...entries].sort(), [...src, 'manifest.json'].sort());

    for (const e of entries) {
      assert.doesNotMatch(e, /(^|\/)(test|e2e|dist|node_modules)\//, e);
      assert.doesNotMatch(e, /\.(md|sh|map|log)$|package\.json|\.DS_Store|manifest\.(chrome|firefox)\.json/, e);
    }
  });

  test(`${target}: the zip unpacks to a working extension`, () => {
    const zip = path.join(root, 'dist', `haul-${target}-${version}.zip`);
    const dir = fs.mkdtempSync(path.join(require('node:os').tmpdir(), `haul-zip-${target}-`));
    execFileSync('unzip', ['-q', zip, '-d', dir]);
    const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json')));
    assert.equal(manifest.version, version);
    for (const f of filesNamedBy(manifest)) assert.ok(fs.existsSync(path.join(dir, f)), `missing ${f}`);
    fs.rmSync(dir, { recursive: true, force: true });
  });
}
