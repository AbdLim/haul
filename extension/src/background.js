// Haul's background script. Every listener is registered here, at the top
// level, because the browser stops this script when it is idle and starts it
// again for the next event.

// Chrome runs this as a service worker and needs the shared code pulled in;
// Firefox lists common.js ahead of this file in its manifest.
if (typeof importScripts === 'function') importScripts('common.js');

const H = HaulCommon;
const api = H.api;

const MENU_ID = 'haul-download-link';

// The lists Haul takes over come from the app, so they are fetched when this
// script starts, once a minute, and when the popup opens.
async function syncNow() {
  const s = await H.loadSettings();
  if (s.token) await H.syncConfig(s.port, s.token);
}

function ensureAlarm() {
  api.alarms.create(H.CONFIG_ALARM, { periodInMinutes: 1 });
}

api.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === H.CONFIG_ALARM) syncNow().catch(() => {});
});
api.runtime.onStartup.addListener(() => { ensureAlarm(); syncNow().catch(() => {}); });
ensureAlarm();
syncNow().catch(() => {});

// The menu item is saved by the browser; it is made once, when the extension
// is installed or updated.
api.runtime.onInstalled.addListener(() => {
  ensureAlarm();
  api.contextMenus.create({ id: MENU_ID, title: 'Download with Haul', contexts: ['link'] });
});

api.contextMenus.onClicked.addListener((info, tab) => {
  sendLink(info, tab).catch((e) => console.warn('Haul: could not send the link', e));
});

api.downloads.onCreated.addListener((item) => {
  takeOver(item).catch((e) => console.warn('Haul: left the download to the browser', e));
});

// Takes a browser download over if every check passes. If any step fails the
// browser's download carries on untouched.
async function takeOver(item) {
  const s = await H.loadSettings();

  // 1 to 5: switched on, http(s), not ours, not excluded, a type or size we take.
  if (!H.shouldIntercept(item, s, api.runtime.id).ok) return;

  // 6: the app answers quickly.
  if (!(await H.ping(s.port, H.PING_TIMEOUT_MS)).ok) return;

  // 7: the app accepts it.
  const payload = H.buildPayload(item, await cookiesFor(item), navigator.userAgent, H.browserName());
  const sent = await H.postDownload(s.port, s.token, payload);
  if (!sent.ok) return;

  // Only now is the browser's own download dropped.
  await api.downloads.cancel(item.id);
  await removeFinishedFile(item.id);
  await api.downloads.erase({ id: item.id });
}

// The cookies the browser would send, for the link and where it went.
async function cookiesFor(item) {
  const urls = [item.url];
  if (item.finalUrl && item.finalUrl !== item.url) urls.push(item.finalUrl);
  const all = [];
  for (const url of urls) {
    try { all.push(...(await api.cookies.getAll({ url }))); } catch (_) { /* none for this one */ }
  }
  return all;
}

// A small file can finish in the time it took to ask the app. Cancelling does
// nothing to a finished download, so its file would be left behind as a
// second copy; delete it.
async function removeFinishedFile(id) {
  try {
    const [d] = await api.downloads.search({ id });
    if (d && d.state === 'complete' && d.exists) await api.downloads.removeFile(id);
  } catch (_) { /* nothing to remove */ }
}

// "Download with Haul" on a link: the person asked for it, so the type and size
// checks do not apply, only whether the app is there and accepts it.
async function sendLink(info, tab) {
  if (info.menuItemId !== MENU_ID || !info.linkUrl) return;
  const s = await H.loadSettings();
  const scheme = H.schemeOf(info.linkUrl);
  if (scheme !== 'http' && scheme !== 'https') return flash('!', 'Haul only takes http and https links');
  if (!(await H.ping(s.port, 2000)).ok) return flash('!', 'Haul is not running');
  const page = info.pageUrl || (tab && tab.url) || '';
  const cookies = await cookiesFor({ url: info.linkUrl });
  const sent = await H.postDownload(
    s.port, s.token, H.buildLinkPayload(info.linkUrl, page, cookies, navigator.userAgent, H.browserName()),
  );
  if (sent.ok) return flash('✓', 'Sent to Haul');
  flash('!', sent.status === 401 ? 'Haul did not accept the token' : 'Haul did not take the link');
}

// A short mark on the toolbar button, since a menu item has nowhere to answer.
function flash(text, title) {
  const action = api.action || api.browserAction;
  if (!action) return;
  action.setBadgeText({ text });
  action.setTitle({ title });
  setTimeout(() => {
    action.setBadgeText({ text: '' });
    action.setTitle({ title: 'Haul' });
  }, 4000);
}
