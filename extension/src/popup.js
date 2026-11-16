(async function () {
  'use strict';
  const { api, loadSettings, saveSettings, syncConfig } = HaulCommon;
  const $ = (id) => document.getElementById(id);

  const s = await loadSettings();
  $('enabled').checked = s.enabled;
  $('enabled').addEventListener('change', () => saveSettings({ enabled: $('enabled').checked }));
  $('options').addEventListener('click', (e) => {
    e.preventDefault();
    api.runtime.openOptionsPage();
    window.close();
  });

  // Opening the popup also refreshes the lists from the app.
  const r = await syncConfig(s.port, s.token);
  const status = $('status');
  status.className = r.state === 'ok' ? 'good' : 'bad';
  status.textContent = r.state === 'ok' ? 'Haul is running.' : r.message;
})();
