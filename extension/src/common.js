// Code shared by the background script, the options page and the popup.
// It runs as a plain script (no modules), so it works unchanged in Chrome's
// service worker and in Firefox's background page.
(function (root) {
  'use strict';

  // Chrome has `chrome`; Firefox has `browser` (and `chrome` as well). Use
  // `browser` when it exists so promises work the same everywhere.
  const api = typeof browser !== 'undefined' ? browser : chrome;

  const DEFAULT_EXTENSIONS = [
    'zip', 'rar', '7z', 'tar', 'gz', 'dmg', 'pkg', 'iso', 'exe', 'msi', 'apk',
    'mp4', 'mkv', 'mov', 'avi', 'mp3', 'flac', 'wav', 'pdf', 'epub',
  ];

  // What is stored in storage.local, with their defaults.
  const DEFAULTS = {
    enabled: true, // the popup switch
    token: '',
    port: 47821,
    interceptExtensions: DEFAULT_EXTENSIONS,
    interceptMinBytes: 1048576,
    excludedHosts: [],
    // The lists last fetched from the app (see syncConfig); null until the
    // first time. While it is null the defaults above apply.
    config: null,
  };

  const CONFIG_ALARM = 'haul-config';

  const PING_TIMEOUT_MS = 500;

  function bridgeUrl(port, path) {
    return `http://127.0.0.1:${port}${path}`;
  }

  async function fetchWithTimeout(url, options, timeoutMs) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      return await fetch(url, { ...options, signal: controller.signal });
    } finally {
      clearTimeout(timer);
    }
  }

  // Asks the app if it is there. Resolves to {ok, version}; never throws.
  async function ping(port, timeoutMs = PING_TIMEOUT_MS) {
    try {
      const res = await fetchWithTimeout(bridgeUrl(port, '/v1/ping'), {}, timeoutMs);
      if (!res.ok) return { ok: false };
      const body = await res.json();
      return { ok: body && body.app === 'Haul', version: body && body.version };
    } catch (_) {
      return { ok: false };
    }
  }

  // Checks the port and the token, and says which is wrong. Resolves to
  // {state, message} with state one of ok, unreachable, noToken, badToken.
  async function testConnection(port, token) {
    const pong = await ping(port, 2000);
    if (!pong.ok) {
      return {
        state: 'unreachable',
        message: `Haul did not answer on port ${port}. Is Haul running, and is the port the same as in its Settings?`,
      };
    }
    if (!token) {
      return { state: 'noToken', message: 'Haul is running. Paste the pairing token from its Settings.' };
    }
    try {
      const res = await fetchWithTimeout(
        bridgeUrl(port, '/v1/config'),
        { headers: { 'X-Bridge-Token': token } },
        2000,
      );
      if (res.status === 401) {
        return { state: 'badToken', message: 'Haul did not accept this token. Copy it again from Haul’s Settings.' };
      }
      if (!res.ok) {
        return { state: 'unreachable', message: `Haul answered with an error (${res.status}).` };
      }
      return { state: 'ok', message: `Connected to Haul ${pong.version || ''}`.trim() + '.', config: await res.json() };
    } catch (_) {
      return { state: 'unreachable', message: `Haul stopped answering on port ${port}.` };
    }
  }

  async function loadSettings() {
    return api.storage.local.get(DEFAULTS);
  }

  // The lists to follow: the app's, once fetched, else the defaults.
  function rulesOf(s) {
    const c = s.config;
    return {
      interceptExtensions: (c && c.interceptExtensions) || s.interceptExtensions,
      interceptMinBytes: c && Number.isFinite(c.interceptMinBytes) ? c.interceptMinBytes : s.interceptMinBytes,
      excludedHosts: (c && c.excludedHosts) || s.excludedHosts,
    };
  }

  // Fetches the app's lists and keeps them. When the app is not there, the
  // lists kept last time stay in force. Resolves to the connection result.
  async function syncConfig(port, token) {
    const r = await testConnection(port, token);
    if (r.state === 'ok' && r.config) {
      await saveSettings({ config: { ...r.config, fetchedAt: Date.now() } });
    }
    return r;
  }

  async function saveSettings(partial) {
    await api.storage.local.set(partial);
  }

  // "zip, .RAR  7z" -> ["zip", "rar", "7z"]
  function parseExtensions(text) {
    const seen = new Set();
    for (const part of String(text).split(/[\s,;]+/)) {
      const e = part.trim().replace(/^\.+/, '').toLowerCase();
      if (e) seen.add(e);
    }
    return [...seen];
  }

  // One site per line or separated by commas; links and paths are cut down to
  // the host name.
  function parseHosts(text) {
    const seen = new Set();
    for (const part of String(text).split(/[\n,;\s]+/)) {
      let h = part.trim().toLowerCase();
      if (!h) continue;
      h = h.replace(/^[a-z][a-z0-9+.-]*:\/\//, '').split(/[/?#]/)[0].replace(/:\d+$/, '');
      if (h) seen.add(h);
    }
    return [...seen];
  }


  // -- deciding whether to take a download over ------------------------------

  function schemeOf(url) {
    try { return new URL(url).protocol.replace(':', ''); } catch (_) { return ''; }
  }

  function hostOf(url) {
    try { return new URL(url).hostname.toLowerCase(); } catch (_) { return ''; }
  }

  // "zip" for ".../a/Movie.ZIP?x=1" or for a file name "Movie.zip".
  function extensionOf(nameOrUrl) {
    if (!nameOrUrl) return '';
    let path = String(nameOrUrl);
    try { path = new URL(path).pathname; } catch (_) { /* a plain file name */ }
    path = path.split(/[\\/]/).pop() || '';
    const dot = path.lastIndexOf('.');
    return dot > 0 && dot < path.length - 1 ? path.slice(dot + 1).toLowerCase() : '';
  }

  // A host is excluded if it is listed or is a sub-site of a listed one.
  function hostExcluded(host, excluded) {
    if (!host) return false;
    return (excluded || []).some((e) => host === e || host.endsWith('.' + e));
  }

  // The first five checks, in order. Resolves to {ok, reason}.
  // `item` is a browser download item; `ownId` is this extension's id.
  function shouldIntercept(item, s, ownId) {
    if (!s.enabled) return { ok: false, reason: 'switched off' };
    if (s.config && s.config.enabled === false) return { ok: false, reason: 'switched off in Haul' };
    const scheme = schemeOf(item.url);
    if (scheme !== 'http' && scheme !== 'https') return { ok: false, reason: 'not an http link' };
    if (item.byExtensionId && item.byExtensionId === ownId) return { ok: false, reason: 'started by Haul' };
    const rules = rulesOf(s);
    const hosts = [hostOf(item.url), hostOf(item.finalUrl)];
    if (hosts.some((h) => hostExcluded(h, rules.excludedHosts))) return { ok: false, reason: 'excluded site' };
    const ext = extensionOf(item.filename) || extensionOf(item.finalUrl) || extensionOf(item.url);
    const size = item.fileSize > 0 ? item.fileSize : item.totalBytes > 0 ? item.totalBytes : 0;
    const listed = ext && rules.interceptExtensions.includes(ext);
    const big = size > 0 && size >= rules.interceptMinBytes;
    if (!listed && !big) return { ok: false, reason: 'not a type or size Haul takes' };
    return { ok: true };
  }

  // [{name, value}] -> "a=1; b=2", with a later cookie of the same name winning.
  function cookieHeader(cookies) {
    const byName = new Map();
    for (const c of cookies || []) byName.set(c.name, c.value);
    return [...byName].map(([n, v]) => `${n}=${v}`).join('; ');
  }

  // What POST /v1/downloads takes. Empty fields are left out.
  function buildPayload(item, cookies, userAgent, source) {
    const p = { url: item.url, source };
    const set = (k, v) => { if (v) p[k] = v; };
    if (item.finalUrl && item.finalUrl !== item.url) p.finalUrl = item.finalUrl;
    // The file name is often empty this early; it is the leaf of the path.
    const leaf = item.filename ? String(item.filename).split(/[\\/]/).pop() : '';
    set('fileName', leaf);
    set('referrer', item.referrer);
    set('userAgent', userAgent);
    set('cookies', cookieHeader(cookies));
    set('mimeType', item.mime);
    const size = item.fileSize > 0 ? item.fileSize : item.totalBytes > 0 ? item.totalBytes : 0;
    if (size > 0) p.fileSize = size;
    return p;
  }

  // What the link menu sends: the link, with the page it was on as referrer.
  function buildLinkPayload(linkUrl, pageUrl, cookies, userAgent, source) {
    const p = { url: linkUrl, source };
    if (pageUrl) p.referrer = pageUrl;
    if (userAgent) p.userAgent = userAgent;
    const c = cookieHeader(cookies);
    if (c) p.cookies = c;
    return p;
  }

  // Sends a download to Haul. Resolves to {ok, id} or {ok:false, status}.
  async function postDownload(port, token, payload, timeoutMs = 5000) {
    try {
      const res = await fetchWithTimeout(bridgeUrl(port, '/v1/downloads'), {
        method: 'POST',
        headers: { 'X-Bridge-Token': token, 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      }, timeoutMs);
      if (res.status !== 202) return { ok: false, status: res.status };
      const body = await res.json();
      return { ok: true, id: body.id };
    } catch (_) {
      return { ok: false, status: 0 };
    }
  }

  // Which browser this is, as Haul names it.
  function browserName() {
    return typeof navigator !== 'undefined' && /Firefox\//.test(navigator.userAgent) ? 'firefox' : 'chrome';
  }

  const exported = {
    api, DEFAULTS, DEFAULT_EXTENSIONS, PING_TIMEOUT_MS,
    bridgeUrl, ping, testConnection, loadSettings, saveSettings, rulesOf, syncConfig, CONFIG_ALARM,
    parseExtensions, parseHosts,
    schemeOf, hostOf, extensionOf, hostExcluded, shouldIntercept, cookieHeader,
    buildPayload, buildLinkPayload, postDownload, browserName,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = exported;
  else root.HaulCommon = exported;
})(typeof self !== 'undefined' ? self : globalThis);
