// the Chrome zip, unpacked, loads in a real Chrome and its service worker
// runs. Run: node e2e/package.e2e.js
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { launch } = require('./chrome.js');

(async () => {
  const root = path.join(__dirname, '..');
  execFileSync(path.join(root, 'build.sh'), ['package'], { stdio: 'pipe' });
  const version = JSON.parse(fs.readFileSync(path.join(root, 'manifest.chrome.json'))).version;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'haul-unzipped-'));
  execFileSync('unzip', ['-q', path.join(root, 'dist', `haul-chrome-${version}.zip`), '-d', dir]);
  const chrome = await launch({ extensionDir: dir });
  const worker = await chrome.worker();
  const name = await worker.eval('chrome.runtime.getManifest().name + " " + chrome.runtime.getManifest().version');
  assert.equal(name, `Haul ${version}`);
  console.log(`  ok   the unpacked zip runs in Chrome as: ${name}`);
  await chrome.close();
  fs.rmSync(dir, { recursive: true, force: true });
})().catch((e) => { console.error('  FAIL', e.message); process.exit(1); });
