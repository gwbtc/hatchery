// gw-handle — background service worker.
// Owns config, per-domain arming, cookie sync, and the job loop the ship
// drives the browser through. Nothing leaves the browser for a domain
// that is not armed, and everything goes only to the paired ship.

const TAP_SCRIPT_ID = 'sb-tap';
const SYNC_DEBOUNCE_MS = 1500;

// ---------- config ----------

async function getConfig() {
  const { endpoint = '', enabled = {} } =
    await chrome.storage.local.get(['endpoint', 'enabled']);
  return { endpoint, enabled };
}

function stripDot(d) {
  return d.startsWith('.') ? d.slice(1) : d;
}

// host "api.x.com" matches enabled "x.com"; cookie domain ".x.com" too.
function matchesDomain(host, domain) {
  host = stripDot(host);
  return host === domain || host.endsWith('.' + domain);
}

function enabledDomainFor(host, enabled) {
  for (const d of Object.keys(enabled)) {
    if (enabled[d] && matchesDomain(host, d)) return d;
  }
  return null;
}

// ---------- transport ----------

// Cookie jars and captured traffic carry real credentials, so the only
// endpoints allowed are HTTPS or loopback. A plain-http remote would put
// every armed jar on the wire in the clear; refuse it rather than leak.
function endpointAllowed(endpoint) {
  let u;
  try { u = new URL(endpoint); } catch { return false; }
  if (u.protocol === 'https:') return true;
  if (u.protocol === 'http:') {
    return u.hostname === 'localhost' || u.hostname === '127.0.0.1' || u.hostname === '[::1]' || u.hostname === '::1';
  }
  return false;
}

async function post(kind, payload) {
  const { endpoint } = await getConfig();
  if (!endpoint) return { ok: false, error: 'no endpoint configured' };
  if (!endpointAllowed(endpoint)) return { ok: false, error: 'endpoint must be https or loopback' };
  const url = endpoint.replace(/\/+$/, '') + '/' + kind;
  try {
    const res = await fetch(url, {
      method: 'POST',
      credentials: 'include',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) return { ok: false, error: `endpoint ${res.status}` };
    return { ok: true };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

// ---------- cookies ----------

async function listCookieDomains() {
  const all = await chrome.cookies.getAll({});
  const counts = {};
  for (const c of all) {
    const d = stripDot(c.domain);
    counts[d] = (counts[d] || 0) + 1;
  }
  return counts;
}

async function syncDomain(domain) {
  const cookies = await chrome.cookies.getAll({ domain });
  const payload = {
    domain,
    at: new Date().toISOString(),
    cookies: cookies.map((c) => ({
      name: c.name,
      value: c.value,
      domain: c.domain,
      path: c.path,
      secure: c.secure,
      httpOnly: c.httpOnly,
      sameSite: c.sameSite,
      session: c.session,
      expirationDate: c.expirationDate ?? null,
    })),
  };
  const r = await post('api/cookies', payload);
  await chrome.storage.local.set({
    ['last:' + domain]: { at: payload.at, count: cookies.length, ...r },
  });
  return r;
}

async function syncAllEnabled() {
  const { enabled } = await getConfig();
  const results = {};
  for (const d of Object.keys(enabled)) {
    if (enabled[d]) results[d] = await syncDomain(d);
  }
  return results;
}

// Debounced resync per domain on any cookie change.
const pending = new Map();
chrome.cookies.onChanged.addListener(async ({ cookie }) => {
  const { enabled } = await getConfig();
  const d = enabledDomainFor(cookie.domain, enabled);
  if (!d) return;
  clearTimeout(pending.get(d));
  pending.set(d, setTimeout(() => { pending.delete(d); syncDomain(d); }, SYNC_DEBOUNCE_MS));
});

// ---------- traffic buffering ----------
//
// The tap reports every call the page makes, which on a busy site is a
// flood. Posting each one is an eyre event each; instead the entries are
// collected and flushed as a single array, so the ship takes one write
// per flush however fast the page talks. Nothing is dropped — the buffer
// only delays, by at most TRAFFIC_FLUSH_MS or until it reaches the size
// bound, whichever comes first.
const TRAFFIC_FLUSH_MS = 2000;
const TRAFFIC_FLUSH_MAX = 100;
let trafficBuffer = [];
let trafficTimer = null;

function bufferTraffic(entry) {
  trafficBuffer.push(entry);
  if (trafficBuffer.length >= TRAFFIC_FLUSH_MAX) { flushTraffic(); return; }
  // a pending setTimeout keeps the MV3 worker alive until it fires, so a
  // short delay will not be lost to suspension
  if (!trafficTimer) trafficTimer = setTimeout(flushTraffic, TRAFFIC_FLUSH_MS);
}

async function flushTraffic() {
  if (trafficTimer) { clearTimeout(trafficTimer); trafficTimer = null; }
  if (!trafficBuffer.length) return;
  const batch = trafficBuffer;
  trafficBuffer = [];
  await post('api/traffic', { batch });
}

// ---------- content script registration ----------

// Both scripts are registered dynamically, for ARMED domains only, so
// nothing of this extension runs ambiently on an un-armed page: the tap
// in the MAIN world to wrap fetch/XHR, and content.js in the isolated
// world to relay what the tap captures. (content.js is ALSO injected on
// demand into a driven group tab — see ensureContent — so driving works
// on un-armed sites without a standing presence there.)
const CONTENT_SCRIPT_ID = 'gw-content';

async function refreshTapRegistration() {
  const { enabled } = await getConfig();
  const domains = Object.keys(enabled).filter((d) => enabled[d]);
  try { await chrome.scripting.unregisterContentScripts({ ids: [TAP_SCRIPT_ID, CONTENT_SCRIPT_ID] }); } catch {}
  if (domains.length === 0) return;
  const matches = domains.flatMap((d) => [`https://${d}/*`, `https://*.${d}/*`]);
  await chrome.scripting.registerContentScripts([
    { id: TAP_SCRIPT_ID, js: ['tap.js'], matches, runAt: 'document_start', world: 'MAIN', persistAcrossSessions: true },
    { id: CONTENT_SCRIPT_ID, js: ['content.js'], matches, runAt: 'document_start', persistAcrossSessions: true },
  ]);
}

chrome.runtime.onInstalled.addListener(refreshTapRegistration);
chrome.runtime.onStartup.addListener(refreshTapRegistration);

// ---------- driving the ship's own tab group ----------
// The ship queues a job on the nexus; the extension claims it and runs it
// in a tab of the handle's group — full agency there, the same a user has
// in those tabs: navigate, click, type, run JS, any HTTP request. The
// group is the whole boundary; a tab the person opened is never touched.

async function endpointBase() {
  const { endpoint } = await getConfig();
  return endpoint ? endpoint.replace(/\/+$/, '') : null;
}

// The session IS the credential: the nexus answers only our own @p,
// judged from the eyre session, so the urbauth cookie has to ride along
// and there is no token to present besides it.
async function execGet(path) {
  const base = await endpointBase(); if (!base) return null;
  if (!endpointAllowed(base)) return null;
  const res = await fetch(base + path, { credentials: 'include' });
  return res.ok ? res.json() : null;
}

// An HTTP request inside a group tab, any method, run as a one-shot
// injected function rather than a standing listener — it exists only for
// the duration of the call, so there is no ambient executor a page could
// poke. The request runs in the page's MAIN world, carrying the live
// session and TLS. body and headers are optional.
async function runInPage(domain, job) {
  const tab = await findTab(domain);
  if (!tab) return { status: null, error: 'no tab on ' + domain + ' in the ' + GROUP_TITLE + ' group' };
  try {
    const [res] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      world: 'MAIN',
      args: [job.url, job.method || 'GET', job.headers || {}, job.body ?? null],
      func: async (url, method, headers, body) => {
        try {
          const init = { method, credentials: 'include', headers };
          if (body != null && !/^(GET|HEAD)$/i.test(method)) init.body = body;
          const r = await fetch(url, init);
          const text = await r.text();
          const respHeaders = {};
          r.headers.forEach((v, k) => { respHeaders[k] = v; });
          return { status: r.status, headers: respHeaders, body: text.length > 512 * 1024 ? text.slice(0, 512 * 1024) : text };
        } catch (e) {
          return { status: null, error: String(e) };
        }
      },
    });
    return res?.result ?? { status: null, error: 'no result' };
  } catch (e) {
    return { status: null, error: 'inject failed: ' + String(e) };
  }
}

// Run arbitrary JavaScript in a group tab's MAIN world and return its
// result. `code` is a function body: it may `return` a value, which comes
// back (JSON-serialisable) as the body. Full agency inside the ship's own
// tab — the same reach a script the page loaded would have.
async function runJs(domain, job) {
  if (!job.code) return { error: 'js needs code' };
  const tab = await findTab(domain);
  if (!tab) return { error: 'no tab on ' + domain + ' in the ' + GROUP_TITLE + ' group' };
  try {
    const [res] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      world: 'MAIN',
      args: [job.code],
      func: async (code) => {
        try {
          const fn = new Function('return (async () => { ' + code + ' })()');
          const out = await fn();
          return { status: 200, body: out === undefined ? null : out };
        } catch (e) {
          return { status: null, error: String(e) };
        }
      },
    });
    return res?.result ?? { error: 'no result' };
  } catch (e) {
    return { error: 'inject failed: ' + String(e) };
  }
}

// Ensure content.js is present in a tab the ship is about to drive. The
// script guards against double-install, so this is idempotent; it is how
// a DOM op reaches a GROUP tab on an unarmed site, where content.js was
// never statically registered.
async function ensureContent(tabId) {
  try {
    await chrome.scripting.executeScript({ target: { tabId }, files: ['content.js'] });
  } catch (e) { /* restricted page (chrome://, store) — the op will error clearly */ }
}

// ---------- the handle's tab group ----------
//
// The ship drives one tab group and nothing else. Every op resolves its
// tab through groupTabs, so a tab the person opened is not reachable
// even when it sits on an armed domain: being armed says WHICH sites may
// be driven, not whose windows. Widening this to "any tab on the domain"
// hands the ship the live logged-in session of whatever is open.
const GROUP_TITLE = 'gw-handle';

// The stored id goes stale whenever the group is closed, so it is
// verified rather than trusted, and a stale one is forgotten.
async function currentGroup() {
  const { groupId = null } = await chrome.storage.local.get(['groupId']);
  if (groupId == null) return null;
  try {
    await chrome.tabGroups.get(groupId);
    return groupId;
  } catch {
    await chrome.storage.local.remove(['groupId']);
    return null;
  }
}

async function ensureGroup(firstTabId) {
  const existing = await currentGroup();
  if (existing != null) {
    if (firstTabId != null) await chrome.tabs.group({ groupId: existing, tabIds: [firstTabId] });
    return existing;
  }
  const seed = firstTabId ?? (await chrome.tabs.create({ url: 'about:blank', active: false })).id;
  const groupId = await chrome.tabs.group({ tabIds: [seed] });
  await chrome.tabGroups.update(groupId, { title: GROUP_TITLE, color: 'blue' });
  await chrome.storage.local.set({ groupId });
  return groupId;
}

async function groupTabs() {
  const groupId = await currentGroup();
  if (groupId == null) return [];
  return chrome.tabs.query({ groupId });
}

// A tab in the handle's group whose host matches the armed domain.
// Returns null rather than reaching outside the group.
async function findTab(domain) {
  const tabs = await groupTabs();
  return tabs.find((t) => {
    if (t.id == null || !t.url) return null;
    try { return matchesDomain(new URL(t.url).hostname, domain); } catch { return false; }
  }) || null;
}

function hostOf(url) {
  try { return new URL(url).hostname; } catch { return null; }
}

// ---------- waiting for a page ----------
//
// chrome.tabs.create and .update resolve when the navigation STARTS, so
// a screenshot or read issued straight after one catches the previous
// page, or a blank one. Wait for the load to finish instead, bounded:
// a page that never fires onCompleted (a stalled request, a stream)
// must not park the job queue forever.
const LOAD_TIMEOUT_MS = 15000;

function waitForLoad(tabId) {
  return new Promise((resolve) => {
    let done = false;
    const finish = (how) => {
      if (done) return;
      done = true;
      chrome.webNavigation.onCompleted.removeListener(onDone);
      chrome.webNavigation.onErrorOccurred.removeListener(onFail);
      clearTimeout(timer);
      resolve(how);
    };
    // frameId 0 is the top-level document; subframes finish on their own
    const onDone = (d) => { if (d.tabId === tabId && d.frameId === 0) finish('loaded'); };
    const onFail = (d) => { if (d.tabId === tabId && d.frameId === 0) finish('error'); };
    const timer = setTimeout(() => finish('timeout'), LOAD_TIMEOUT_MS);
    chrome.webNavigation.onCompleted.addListener(onDone);
    chrome.webNavigation.onErrorOccurred.addListener(onFail);
    // already finished before we attached
    chrome.tabs.get(tabId).then((t) => {
      if (t && t.status === 'complete') finish('loaded');
    }).catch(() => finish('error'));
  });
}

// ---------- screenshots ----------
//
// captureVisibleTab only reads a tab that is active in a FOCUSED window
// ("image readback failed" otherwise), which is exactly the case the
// ship is in: nobody is looking at Chrome. CDP captures an unfocused
// tab, so attach, shoot, detach — holding the attachment would keep
// Chrome's debug banner up and lock out devtools.
async function captureViaDebugger(tabId) {
  const target = { tabId };
  await chrome.debugger.attach(target, '1.3');
  try {
    const { data } = await chrome.debugger.sendCommand(target, 'Page.captureScreenshot', {
      format: 'png', captureBeyondViewport: false,
    });
    return 'data:image/png;base64,' + data;
  } finally {
    try { await chrome.debugger.detach(target); } catch {}
  }
}

// Ask the page to do something in the DOM. click/type/read all run in the
// isolated content world; no MAIN-world injection is needed for these.
async function runDom(domain, job) {
  const tab = await findTab(domain);
  if (!tab) return { error: 'no tab on ' + domain + ' in the ' + GROUP_TITLE + ' group' };
  await ensureContent(tab.id);
  try {
    return await chrome.tabs.sendMessage(tab.id, { type: 'gw-dom', job });
  } catch (e) {
    return { error: 'tab message failed: ' + String(e) };
  }
}

// One job, dispatched by op. `fetch` keeps the old in-page path.
async function runJob(domain, job) {
  switch (job.op || 'fetch') {
    case 'screenshot': {
      const tab = await findTab(domain);
      if (!tab) return { error: 'no tab on ' + domain + ' in the ' + GROUP_TITLE + ' group' };
      try {
        return { body: await captureViaDebugger(tab.id), status: 200 };
      } catch (e) {
        // CDP refused (devtools already attached, policy). Fall back to
        // the focused-window path, which works when someone IS looking.
        try {
          await chrome.tabs.update(tab.id, { active: true });
          const dataUrl = await chrome.tabs.captureVisibleTab(tab.windowId, { format: 'png' });
          return { body: dataUrl, status: 200 };
        } catch (e2) {
          return { error: 'capture failed: ' + String(e) + ' / fallback: ' + String(e2) };
        }
      }
    }
    // Open a tab IN the group, creating the group if there isn't one.
    // The only op that does not need a tab to already exist — this is
    // how the ship gets its first one.
    case 'open': {
      if (!job.url) return { error: 'open needs a url' };
      if (!matchesDomain(hostOf(job.url) || '', domain)) {
        return { error: 'url host is not the armed domain ' + domain };
      }
      const tab = await chrome.tabs.create({ url: job.url, active: false });
      const groupId = await ensureGroup(tab.id);
      await chrome.tabGroups.update(groupId, { title: GROUP_TITLE, color: 'blue' });
      const load = await waitForLoad(tab.id);
      return { status: 200, body: { tabId: tab.id, groupId, url: job.url, load } };
    }
    // What the ship is holding. Metadata only, and only for its group.
    case 'tabs': {
      const tabs = await groupTabs();
      return { status: 200, body: tabs.map((t) => ({ tabId: t.id, url: t.url, title: t.title })) };
    }
    case 'close': {
      const tabs = await groupTabs();
      const tab = tabs.find((t) => t.id === job.tabId);
      if (!tab) return { error: 'tab ' + job.tabId + ' is not in the ' + GROUP_TITLE + ' group' };
      await chrome.tabs.remove(tab.id);
      return { status: 200, body: 'closed ' + job.tabId };
    }
    // Navigate the job's group tab anywhere. These are the ship's own
    // tabs, so there is no armed-list gate — the group is the boundary,
    // not the URL.
    case 'navigate': {
      if (!job.url) return { error: 'navigate needs a url' };
      if (!hostOf(job.url)) return { error: 'navigate needs an absolute url' };
      const tab = await findTab(domain);
      if (!tab) return { error: 'no tab on ' + domain + ' in the ' + GROUP_TITLE + ' group' };
      await chrome.tabs.update(tab.id, { url: job.url });
      const load = await waitForLoad(tab.id);
      return { status: 200, body: { url: job.url, load } };
    }
    case 'click':
    case 'type':
    case 'read':
      return runDom(domain, job);
    // Run arbitrary JavaScript in the group tab and return its result.
    // This is the general case the structured ops are conveniences over:
    // inside its own tab, the ship can do whatever a script on the page
    // could. The code is a function body evaluated in the page's MAIN
    // world; its return value (JSON-serialisable) comes back as the body.
    case 'js':
      return runJs(domain, job);
    // An HTTP request from inside the tab, ANY method. These are the
    // ship's own tabs, where it has the same agency a user does, so a
    // POST is as allowed as a GET — there is no read-only line. The
    // request carries the live session.
    default:
      return runInPage(domain, job);
  }
}

// One pass: claim a job per enabled domain, run it, write the answer back.
// A claimed job is marked sent on the nexus side, so the next pass does not
// take the same one. `ok` is explicit: the nexus treats a missing ok as a
// failure, which is the right default but has to be answered honestly.
// Claim and run pending driving jobs. One undomained poll: driving the
// ship's own group tabs is not gated by the armed list (that list is for
// cookie/traffic collection), so the ship may open and act on any URL in
// its own group. The job carries its own domain, used only to route to a
// tab. Drain several per tick so a queue does not trickle out one per poll.
async function pollJobs() {
  for (let i = 0; i < 10; i++) {
    const r = await execGet('/api/next');
    const job = r && r.job;
    if (!job) break;
    const domain = job.req?.domain || '';
    const result = await runJob(domain, { ...job.req, id: job.id });
    await post('api/complete', {
      id: job.id,
      ok: !result.error,
      body: result.body ?? null,
      error: result.error || '',
    });
  }
}

chrome.alarms.create('sb-poll', { periodInMinutes: 0.5 });
chrome.alarms.onAlarm.addListener((a) => { if (a.name === 'sb-poll') pollJobs(); });

// ---------- messages ----------

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  (async () => {
    switch (msg.type) {
      case 'get-config': {
        const cfg = await getConfig();
        const last = await chrome.storage.local.get(null);
        cfg.last = Object.fromEntries(
          Object.entries(last).filter(([k]) => k.startsWith('last:')).map(([k, v]) => [k.slice(5), v]));
        return cfg;
      }
      case 'set-config':
        await chrome.storage.local.set({ endpoint: msg.endpoint });
        return { ok: true };
      case 'test-endpoint':
        return post('api/ping', { at: new Date().toISOString() });
      case 'list-domains':
        return listCookieDomains();
      case 'set-enabled': {
        const { enabled } = await getConfig();
        if (msg.on) enabled[msg.domain] = true; else delete enabled[msg.domain];
        await chrome.storage.local.set({ enabled });
        await refreshTapRegistration();
        if (msg.on) return syncDomain(msg.domain);
        return { ok: true };
      }
      case 'sync-now':
        return msg.domain ? syncDomain(msg.domain) : syncAllEnabled();
      case 'traffic': {
        // From content.js relay. Gate on the *page's* host being enabled,
        // then buffer: the page is a firehose and one write per call would
        // be one eyre event per call. Batching bounds the write RATE the
        // ship sees without dropping a single entry.
        const host = sender?.url ? new URL(sender.url).hostname : '';
        const { enabled } = await getConfig();
        const d = enabledDomainFor(host, enabled);
        if (!d) return { ok: false, error: 'domain not enabled' };
        bufferTraffic({ domain: d, page: sender.url, ...msg.entry });
        return { ok: true };
      }
      default:
        return { ok: false, error: 'unknown message ' + msg.type };
    }
  })().then(sendResponse, (e) => sendResponse({ ok: false, error: String(e) }));
  return true;
});
