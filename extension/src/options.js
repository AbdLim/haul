(async function () {
  'use strict';
  const { api, loadSettings, saveSettings, syncConfig, rulesOf } = HaulCommon;
  const $ = (id) => document.getElementById(id);

  function showLists(s) {
    const rules = rulesOf(s);
    $('extensions').textContent = rules.interceptExtensions.join(' ');
    const mb = rules.interceptMinBytes / 1048576;
    $('minSize').textContent = `${Number.isInteger(mb) ? mb : mb.toFixed(1)} MB`;
    $('excluded').textContent = rules.excludedHosts.length ? rules.excludedHosts.join(', ') : 'None';
    $('synced').textContent = s.config && s.config.fetchedAt
      ? `Updated from Haul at ${new Date(s.config.fetchedAt).toLocaleTimeString()}.`
      : 'Not fetched from Haul yet; these are the standard lists.';
  }

  const s = await loadSettings();
  $('token').value = s.token;
  $('port').value = s.port;
  showLists(s);

  // Token and port are saved a moment after typing stops. Both are kept until
  // then, so editing the two quickly loses neither.
  let timer;
  let pending = {};
  function savedSoon(partial) {
    pending = { ...pending, ...partial };
    clearTimeout(timer);
    timer = setTimeout(async () => {
      const toSave = pending;
      pending = {};
      await saveSettings(toSave);
      $('saved').textContent = 'Saved.';
      setTimeout(() => { $('saved').textContent = ''; }, 1500);
    }, 250);
  }

  $('token').addEventListener('input', () => savedSoon({ token: $('token').value.trim() }));
  $('port').addEventListener('input', () => {
    const n = parseInt($('port').value, 10);
    if (n >= 1024 && n <= 65535) savedSoon({ port: n });
  });

  $('test').addEventListener('click', async () => {
    const result = $('result');
    result.className = '';
    result.textContent = 'Testing…';
    const port = parseInt($('port').value, 10) || s.port;
    const r = await syncConfig(port, $('token').value.trim());
    result.className = r.state === 'ok' ? 'good' : 'bad';
    result.textContent = r.message;
    showLists(await loadSettings());
  });

  // Follow the lists as the background script refreshes them.
  api.storage.onChanged.addListener(async (changes) => {
    if (changes.config) showLists(await loadSettings());
  });
})();
