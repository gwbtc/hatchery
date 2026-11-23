// Session Bridge — page-world traffic tap.
// Injected (MAIN world, document_start) only on enabled domains.
// Wraps fetch and XMLHttpRequest, posts request/response pairs to the
// isolated content script via window.postMessage. Never touches the DOM.
(() => {
  if (window.__sbTapInstalled) return;
  window.__sbTapInstalled = true;

  const MARK = '__session_bridge__';
  const BODY_CAP = 256 * 1024;
  const TEXTUAL = /json|text|xml|x-www-form-urlencoded|graphql/i;

  // No filtering here. The tap drinks from the firehose: every fetch and
  // XHR the page makes is reported as-is. Deciding which calls matter —
  // the site's API versus its telemetry and furniture — is a judgement,
  // and judgement belongs to the intelligence that reads this later, not
  // to the tap. Lose nothing at the point of capture.

  const emit = (entry) => {
    try { window.postMessage({ [MARK]: 1, entry }, '*'); } catch {}
  };

  // This file ONLY observes. It once also hosted an executor that ran
  // ship-submitted fetches, listening for page messages — an ambient
  // listener on every armed page that the page itself could post to. The
  // ship's in-page fetch now runs as a one-shot injected function
  // (background.js runInPage), present only for the moment it runs, so
  // there is no standing executor here to address.

  const cap = (s) => (typeof s === 'string' && s.length > BODY_CAP)
    ? s.slice(0, BODY_CAP) + `…[truncated ${s.length - BODY_CAP}]` : s;

  const headersToObj = (h) => {
    const o = {};
    if (!h) return o;
    if (h instanceof Headers) { h.forEach((v, k) => { o[k] = v; }); return o; }
    if (Array.isArray(h)) { for (const [k, v] of h) o[k.toLowerCase()] = v; return o; }
    for (const k of Object.keys(h)) o[k.toLowerCase()] = h[k];
    return o;
  };

  const bodyToText = async (b) => {
    if (b == null) return null;
    if (typeof b === 'string') return cap(b);
    if (b instanceof URLSearchParams) return cap(b.toString());
    if (b instanceof FormData) {
      const o = {}; b.forEach((v, k) => { o[k] = typeof v === 'string' ? v : '[file]'; });
      return cap(JSON.stringify(o));
    }
    if (b instanceof Blob) return TEXTUAL.test(b.type) ? cap(await b.text()) : `[blob ${b.type} ${b.size}b]`;
    if (b instanceof ArrayBuffer || ArrayBuffer.isView(b)) return `[binary ${b.byteLength}b]`;
    return '[unsupported body]';
  };

  // ---- fetch ----
  const origFetch = window.fetch;
  window.fetch = async function (input, init) {
    const started = Date.now();
    let method = 'GET', url, reqHeaders = {}, reqBody = null;
    try {
      if (input instanceof Request) {
        url = new URL(input.url, location.href).href; method = input.method;
        reqHeaders = headersToObj(input.headers);
        try { reqBody = await bodyToText(await input.clone().text()); } catch {}
      } else {
        url = new URL(String(input), location.href).href;
      }
      if (init) {
        if (init.method) method = init.method;
        Object.assign(reqHeaders, headersToObj(init.headers));
        if (init.body != null) reqBody = await bodyToText(init.body);
      }
    } catch {}

    const res = await origFetch.apply(this, arguments);

    (async () => {
      try {
        const ct = res.headers.get('content-type') || '';
        let resBody = null;
        if (TEXTUAL.test(ct)) resBody = cap(await res.clone().text());
        emit({
          kind: 'fetch', at: new Date(started).toISOString(), ms: Date.now() - started,
          method: method.toUpperCase(), url,
          request: { headers: reqHeaders, body: reqBody },
          response: { status: res.status, headers: headersToObj(res.headers), body: resBody },
        });
      } catch {}
    })();

    return res;
  };

  // ---- XHR ----
  const XP = XMLHttpRequest.prototype;
  const oOpen = XP.open, oSend = XP.send, oSet = XP.setRequestHeader;
  XP.open = function (method, url) {
    this.__sb = { method: String(method).toUpperCase(), url: String(url), headers: {} };
    return oOpen.apply(this, arguments);
  };
  XP.setRequestHeader = function (k, v) {
    if (this.__sb) this.__sb.headers[String(k).toLowerCase()] = v;
    return oSet.apply(this, arguments);
  };
  XP.send = function (body) {
    const sb = this.__sb;
    if (sb) {
      const started = Date.now();
      bodyToText(body).then((t) => { sb.body = t; }).catch(() => {});
      this.addEventListener('loadend', () => {
        try {
          const raw = this.getAllResponseHeaders() || '';
          const headers = {};
          for (const line of raw.trim().split(/\r?\n/)) {
            const i = line.indexOf(':'); if (i > 0) headers[line.slice(0, i).trim().toLowerCase()] = line.slice(i + 1).trim();
          }
          const full = new URL(sb.url, location.href).href;
          let resBody = null;
          if (this.responseType === '' || this.responseType === 'text') resBody = cap(this.responseText);
          else if (this.responseType === 'json') resBody = cap(JSON.stringify(this.response));
          emit({
            kind: 'xhr', at: new Date(started).toISOString(), ms: Date.now() - started,
            method: sb.method, url: full,
            request: { headers: sb.headers, body: sb.body ?? null },
            response: { status: this.status, headers, body: resBody },
          });
        } catch {}
      });
    }
    return oSend.apply(this, arguments);
  };
})();
