// gw-handle — isolated-world content script.
//
// Two jobs: relay traffic the MAIN-world tap captures to the background
// worker, and run the ship's DOM ops (click/type/read) on the page.
//
// Injected two ways, so a guard makes re-injection a no-op: dynamically
// registered on ARMED domains at document_start (to catch the tap's early
// messages), and injected on demand into a GROUP tab the ship drives,
// which may be on any URL. It is never ambiently present on every page.
if (!window.__gwContentInstalled) {
  window.__gwContentInstalled = true;

  const MARK = '__session_bridge__';

  // tap.js (MAIN world) has no chrome.* API, so it postMessages captured
  // calls here and this forwards them. Only entries bearing MARK, and
  // only from this window — never a cross-frame or page-forged message
  // that lacks the mark.
  window.addEventListener('message', (ev) => {
    if (ev.source !== window || !ev.data || ev.data[MARK] !== 1) return;
    try { chrome.runtime.sendMessage({ type: 'traffic', entry: ev.data.entry }); } catch {}
  });

  // ---------- DOM control: click, type, read ----------
  // In the isolated world, which can see and drive the page's DOM.
  // Synthetic events, so a site that inspects isTrusted can tell; moving
  // to chrome.debugger later changes only this block.
  const pick = (sel) => {
    if (!sel) return null;
    try { return document.querySelector(sel); } catch { return null; }
  };

  const describe = (el) => {
    if (!el) return null;
    return {
      tag: el.tagName.toLowerCase(),
      text: (el.innerText || el.value || '').slice(0, 2000),
      href: el.getAttribute?.('href') || null,
    };
  };

  chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    if (msg.type !== 'gw-dom') return;
    const job = msg.job || {};
    try {
      if (job.op === 'read') {
        if (!job.selector) {
          sendResponse({ status: 200, body: (document.body?.innerText || '').slice(0, 200000) });
          return;
        }
        const els = Array.from(document.querySelectorAll(job.selector)).slice(0, 200);
        sendResponse({ status: 200, body: JSON.stringify(els.map(describe)) });
        return;
      }
      const el = pick(job.selector);
      if (!el) { sendResponse({ error: 'no element for ' + job.selector }); return; }
      if (job.op === 'click') {
        el.scrollIntoView({ block: 'center' });
        el.click();
        sendResponse({ status: 200, body: 'clicked ' + job.selector });
        return;
      }
      if (job.op === 'type') {
        el.focus();
        const setter = Object.getOwnPropertyDescriptor(
          el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype,
          'value')?.set;
        if (setter) setter.call(el, job.text ?? ''); else el.value = job.text ?? '';
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
        sendResponse({ status: 200, body: 'typed into ' + job.selector });
        return;
      }
      sendResponse({ error: 'unknown dom op ' + job.op });
    } catch (e) {
      sendResponse({ error: String(e) });
    }
    return true;
  });
}
