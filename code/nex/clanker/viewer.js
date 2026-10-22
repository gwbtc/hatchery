// clanker chat pane: the viewer a chat's log opens in. mount(root, {url,
// args: {proj, chat}, onNavigate}) -> {destroy, onUpdate}. The transcript
// is the event log the collection serves, nothing else: loaded once on
// mount, then every write to the log arrives on the explorer's stream
// with its body (the pane's follow) and is applied. Send, stop and
// resolve post to the collection's api; the log coming back is the
// confirmation. Nothing here polls.
//
// log events: input {body} · response {content, stop, usage} ·
// results {content, trace} · ask {ids} · resolved {decisions} · interrupt
(function () {
  'use strict';
  var API = '/grubbery/clanker';
  var CSS_ID = 'clanker-chat-css';
  function css() {
    if (document.getElementById(CSS_ID)) return;
    var s = document.createElement('style'); s.id = CSS_ID;
    s.textContent =
      '.cv{height:100%;display:flex;flex-direction:column;min-height:0;font:13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#24292f;background:#fff}' +
      '.cv .mono{font:12px ui-monospace,SFMono-Regular,Menlo,monospace}' +
      '.cv-log{flex:1;min-height:0;overflow-y:auto;padding:16px 18px 20px}' +
      '.cv-thread{max-width:820px;margin:0 auto;display:flex;flex-direction:column;gap:14px}' +
      '.cv-empty{color:#8b949e;text-align:center;margin:48px auto;max-width:380px;line-height:1.6}' +
      '.cv-msg{display:flex;flex-direction:column;gap:4px;min-width:0}' +
      '.cv-msg .who{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.04em;color:#8b949e}' +
      '.cv-msg.user{align-items:flex-end}' +
      '.cv-msg .body{font-size:14px;line-height:1.55;white-space:pre-wrap;overflow-wrap:anywhere;max-width:90%}' +
      '.cv-msg.user .body{background:#ddf4ff;border-radius:10px;padding:8px 12px;max-width:80%}' +
      '.cv-msg.bot .body{white-space:normal}' +
      '.cv-msg.bot .body>:first-child{margin-top:0}.cv-msg.bot .body>:last-child{margin-bottom:0}' +
      '.cv-msg.bot .body p,.cv-msg.bot .body ul,.cv-msg.bot .body ol,.cv-msg.bot .body blockquote,.cv-msg.bot .body table{margin:0 0 10px}' +
      '.cv-msg.bot .body ul,.cv-msg.bot .body ol{padding-left:22px}.cv-msg.bot .body li{margin:2px 0}' +
      '.cv-msg.bot .body h1,.cv-msg.bot .body h2,.cv-msg.bot .body h3,.cv-msg.bot .body h4{margin:12px 0 6px;font-size:14px;font-weight:600}' +
      '.cv-msg.bot .body code{background:#eff1f3;padding:1px 4px;border-radius:3px;font:12px ui-monospace,SFMono-Regular,Menlo,monospace}' +
      '.cv-msg.bot .body pre{margin:0 0 10px;padding:8px 10px;background:#f6f8fa;border:1px solid #eaeef2;border-radius:6px;overflow:auto;font:12px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace}' +
      '.cv-msg.bot .body pre code{background:none;padding:0}' +
      '.cv-msg.bot .body blockquote{border-left:3px solid #d0d7de;padding-left:10px;color:#57606a}' +
      '.cv-msg.bot .body a{color:#0969da;text-decoration:none}.cv-msg.bot .body a:hover{text-decoration:underline}' +
      '.cv-msg.bot .body table{border-collapse:collapse;font-size:13px}.cv-msg.bot .body th,.cv-msg.bot .body td{border:1px solid #d0d7de;padding:3px 8px;text-align:left}' +
      '.cv-msg.bot .body hr{border:0;border-top:1px solid #d0d7de;margin:10px 0}' +
      '.cv-msg.user.pending .body{opacity:.55}' +
      '.cv-meta{font-size:11px;color:#8b949e}' +
      '.cv-trace{display:flex;flex-direction:column;gap:2px;max-width:90%}' +
      '.cv-step summary{list-style:none;cursor:pointer;display:flex;align-items:center;gap:8px;padding:3px 6px;border-radius:6px;font:12px ui-monospace,SFMono-Regular,Menlo,monospace;color:#57606a}' +
      '.cv-step summary::-webkit-details-marker{display:none}.cv-step summary:hover{background:#f6f8fa}' +
      '.cv-step .tool{color:#8250df;font-weight:600;flex:none}' +
      '.cv-step .arg{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#8b949e}' +
      '.cv-step a.arg{color:#0969da;text-decoration:none;flex:none}' +
      '.cv-step .state{flex:none;color:#8b949e}.cv-step .state.err{color:#cf222e}.cv-step .state.declined{color:#9a6700}' +
      '.cv-step pre{margin:3px 0 6px 20px;padding:8px 10px;max-height:260px;overflow:auto;background:#f6f8fa;border:1px solid #eaeef2;border-radius:6px;font:11.5px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;color:#24292f;white-space:pre-wrap;word-break:break-word}' +
      '.cv-step img{display:block;max-width:100%;max-height:360px;margin:3px 0 6px 20px;border:1px solid #eaeef2;border-radius:6px;background:#fff}' +
      '.cv-ask{max-width:90%;border:1px solid #d4a72c;background:#fff8c5;border-radius:8px;padding:10px 12px;display:flex;flex-direction:column;gap:8px}' +
      '.cv-ask .title{font-weight:600;font-size:12px;color:#7d4e00}' +
      '.cv-ask .row{display:flex;align-items:center;gap:8px;font:12px ui-monospace,SFMono-Regular,Menlo,monospace;color:#57606a;min-width:0}' +
      '.cv-ask .row .tool{color:#8250df;font-weight:600;flex:none}' +
      '.cv-ask .row .arg{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#8b949e}' +
      '.cv-ask pre{margin:0;padding:6px 8px;max-height:140px;overflow:auto;background:#fff;border:1px solid #eee3bd;border-radius:6px;font:11px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;word-break:break-word}' +
      '.cv-ask button{flex:none;font:inherit;font-size:12px;padding:2px 9px;border:1px solid #d0d7de;border-radius:6px;background:#fff;color:#24292f;cursor:pointer}' +
      '.cv-ask button.run{border-color:#1a7f37;color:#1a7f37}.cv-ask button.run.on{background:#1a7f37;color:#fff}' +
      '.cv-ask button.no{border-color:#cf222e;color:#cf222e}.cv-ask button.no.on{background:#cf222e;color:#fff}' +
      '.cv-ask .all{display:flex;gap:8px;justify-content:flex-end}' +
      '.cv-err{color:#cf222e;background:#fff8f8;border:1px solid #ffcecb;border-radius:6px;padding:6px 10px;max-width:90%;font-size:12px}' +
      '.cv-typing{display:flex;gap:4px;padding:6px 2px}.cv-typing span{width:6px;height:6px;border-radius:50%;background:#c4c4c4;animation:cv-pulse 1.2s infinite both}' +
      '.cv-typing span:nth-child(2){animation-delay:.2s}.cv-typing span:nth-child(3){animation-delay:.4s}' +
      '@keyframes cv-pulse{0%,80%,100%{opacity:.3}40%{opacity:1}}' +
      '.cv-compose{flex:none;border-top:1px solid #d0d7de;padding:10px 18px 8px;background:#f6f8fa}' +
      '.cv-compose .inner{max-width:820px;margin:0 auto;display:flex;gap:8px;align-items:flex-end}' +
      '.cv-compose textarea{flex:1;min-width:0;resize:none;border:1px solid #d0d7de;border-radius:6px;padding:7px 10px;font:14px/1.4 inherit;font-family:inherit;color:#24292f;outline:none;min-height:36px;max-height:200px;background:#fff}' +
      '.cv-compose textarea:focus{border-color:#0969da;box-shadow:0 0 0 2px rgba(9,105,218,.15)}' +
      '.cv-compose button{flex:none;height:34px;padding:0 14px;border-radius:6px;font:inherit;cursor:pointer}' +
      '.cv-compose .send{border:1px solid #0969da;background:#0969da;color:#fff}.cv-compose .send:disabled{opacity:.5;cursor:default}' +
      '.cv-compose .stop{border:1px solid #d0d7de;background:#fff;color:#57606a}.cv-compose .stop:hover:not([disabled]){color:#cf222e;border-color:#ffcecb}.cv-compose .stop:disabled{opacity:.4;cursor:default}' +
      '.cv-compose .hint{max-width:820px;margin:5px auto 0;font-size:11px;color:#8b949e}';
    document.head.appendChild(s);
  }
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
  function post(path, body) { return fetch(API + path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) }); }
  function last(log) { return log[log.length - 1]; }
  // a turn runs after an input, tool results, a resolved ask, or a response
  // that asked for tools; it is paused on the user after an ask
  function busyAfter(log) { var e = last(log); return !!e && (e.k === 'input' || e.k === 'results' || e.k === 'resolved' || (e.k === 'response' && e.stop === 'tool_use')); }
  function askingAfter(log) { var e = last(log); return !!e && e.k === 'ask'; }
  function resultText(res) {
    var c = res.content;
    return typeof c === 'string' ? c : Array.isArray(c) ? c.map(function (b) { return b.type === 'text' ? b.text : '[' + b.type + ']'; }).join('\n') : JSON.stringify(c);
  }
  function firstString(args) { var ks = Object.keys(args || {}); for (var i = 0; i < ks.length; i++) if (typeof args[ks[i]] === 'string') return args[ks[i]]; return ''; }

  // fenced code in a rendered message gets syntax colour from shiki, the
  // highlighter the explorer's file view uses: loaded on demand from esm.sh
  // the first time a fence appears, one instance for the page (kept on
  // window so other renderers can share it), the hoon grammar fetched from
  // the explorer. A block renders plain first and is repainted when the
  // highlighter is ready; an unknown language, or no network, leaves it
  // plain. Tokenised html is cached by text, since the thread re-renders on
  // every log event.
  var LANG = { js: 'javascript', mjs: 'javascript', ts: 'typescript', sh: 'bash', shell: 'bash', zsh: 'bash', yml: 'yaml', py: 'python', md: 'markdown' };
  var hlCache = {};
  function getShiki(lang) {
    if (!window.__shikiP) {
      window.__shikiP = (async function () {
        var mod = await import('https://esm.sh/shiki@1.24.0');
        return mod.createHighlighter({ themes: ['github-light'], langs: [] });
      })();
    }
    return window.__shikiP.then(async function (hl) {
      if (!hl.getLoadedLanguages().includes(lang)) {
        if (lang === 'hoon') await hl.loadLanguage(await (await fetch('/grubbery/ball/apps/explorer.explorer/hoon-grammar.json')).json());
        else await hl.loadLanguage(lang);
      }
      return hl;
    });
  }
  function highlight(body) {
    var blocks = body.querySelectorAll('pre > code[class*="language-"]');
    Array.prototype.forEach.call(blocks, function (code) {
      var m = /language-([\w+-]+)/.exec(code.className); if (!m) return;
      var lang = LANG[m[1].toLowerCase()] || m[1].toLowerCase(), text = code.textContent;
      var key = lang + '\n' + text;
      if (hlCache[key]) { code.innerHTML = hlCache[key]; return; }
      getShiki(lang).then(function (hl) {
        var html = hl.codeToHtml(text, { lang: lang, theme: 'github-light' });
        var tmp = document.createElement('div'); tmp.innerHTML = html;
        var inner = tmp.querySelector('code'); if (!inner) return;
        hlCache[key] = inner.innerHTML;
        if (code.isConnected) code.innerHTML = inner.innerHTML;
      }).catch(function () { /* unknown language or no network: plain stays */ });
    });
  }

  function mount(root, opts) {
    css();
    var a = opts.args || {};
    var proj = typeof a.proj === 'string' ? a.proj : null, chat = typeof a.chat === 'string' ? a.chat : null;
    var who = proj ? proj.replace(/^.*\//, '').replace(/\.clanker$/, '') : 'clanker';
    root.innerHTML = ''; root.classList.add('cv');
    var dead = false;
    var handle = { destroy: function () { dead = true; document.removeEventListener('keydown', onEsc); root.innerHTML = ''; root.classList.remove('cv'); }, onUpdate: function (ev) { if (!ev || /log\.chat-log$/.test(ev.path || '')) more(); } };   // the log changed (a bodiless event): fetch what is past our window; nothing else is ours
    if (!proj || !chat) { root.appendChild(el('div', 'cv-empty', 'no chat here: the collection gave no {proj, chat}')); return handle; }

    var logEl = el('div', 'cv-log'), thread = el('div', 'cv-thread'); logEl.appendChild(thread);
    var form = el('form', 'cv-compose'), inner = el('div', 'inner');
    var input = el('textarea'); input.rows = 1; input.placeholder = 'Message ' + who + '…'; input.spellcheck = false;
    input.setAttribute('data-focus', '');   // where the keyboard lands when it chooses this pane (the host's focusContent)
    var stopBtn = el('button', 'stop', 'stop'); stopBtn.type = 'button'; stopBtn.disabled = true; stopBtn.title = 'stop the running turn (Esc Esc)';
    var sendBtn = el('button', 'send', 'send'); sendBtn.type = 'submit';
    inner.appendChild(input); inner.appendChild(stopBtn); inner.appendChild(sendBtn); form.appendChild(inner);
    form.appendChild(el('div', 'hint', 'Enter sends · Shift+Enter newline · Esc Esc stops'));
    root.appendChild(logEl); root.appendChild(form);

    // pending: a message sent but not yet in the log, shown at once (faded)
    // and replaced by the log's own copy when the next write arrives
    // the log is read in RANGES, never whole: the last PAGE events on mount
    // (state.first is where that window starts), what lies past the window
    // on every change, and the page before on a scroll to the top. A log of
    // any length costs the pane the same.
    var PAGE = 60;
    var state = { busy: false, asking: false, len: -1, log: [], pending: null, first: 0, total: 0, loading: false, again: false };
    function setState(busy, asking) { state.busy = busy; state.asking = asking; sendBtn.disabled = busy || asking; stopBtn.disabled = !(busy || asking); }
    function logUrl(q) { return API + '/api/log?path=' + encodeURIComponent(proj) + '&chat=' + encodeURIComponent(chat) + '&' + q; }
    function getJson(u) { return fetch(u, { cache: 'no-store' }).then(function (r) { return r.json(); }); }
    function settle() {
      var log = state.log, grew = log.length !== state.len;
      if (grew && state.pending != null) state.pending = null;   // the log moved on: our message is in it (or the turn was refused)
      if (grew) { state.len = log.length; render(log); }
      setState(busyAfter(log) || state.pending != null, askingAfter(log));
    }
    function load() {                                                  // fresh: the tail
      if (dead) return;
      getJson(logUrl('tail=' + PAGE)).then(function (r) {
        if (dead || !r || !Array.isArray(r.events)) return;
        state.first = r.from; state.total = r.total; state.log = r.events; state.len = -1; settle();
      }).catch(function () {});
    }
    function more() {                                                  // changed: what is past our window
      if (dead) return;
      if (state.loading) { state.again = true; return; }
      state.loading = true;
      var have = state.first + state.log.length;
      getJson(logUrl('from=' + have)).then(function (r) {
        state.loading = false;
        if (dead || !r || !Array.isArray(r.events)) return;
        if (r.total < have) { load(); return; }                        // shorter than our window: rewritten, start over
        if (r.events.length) state.log = state.log.concat(r.events);
        state.total = r.total; settle();
        if (state.again) { state.again = false; more(); }
      }).catch(function () { state.loading = false; });
    }
    function earlier() {                                               // at the top: the page before
      if (dead || state.loading || state.first === 0) return;
      state.loading = true;
      var to = state.first, from = Math.max(0, to - PAGE), keep = logEl.scrollHeight - logEl.scrollTop;
      getJson(logUrl('from=' + from + '&to=' + to)).then(function (r) {
        state.loading = false;
        if (dead || !r || !Array.isArray(r.events)) return;
        state.first = from; state.log = r.events.concat(state.log); state.len = state.log.length;
        render(state.log, true); logEl.scrollTop = logEl.scrollHeight - keep;
      }).catch(function () { state.loading = false; });
    }
    logEl.addEventListener('scroll', function () { if (logEl.scrollTop < 40) earlier(); });
    // an attachment the log refers to: a file under this clanker's files/blobs
    function blobUrl(name) { return String(opts.url || '').replace(/\/chats\/[^/]+\/log\.chat-log(\?.*)?$/, '') + '/files/blobs/' + encodeURIComponent(name); }
    var me = { path: proj, chat: chat };
    function send() {
      var text = input.value.trim();
      if (!text || state.busy || state.asking) return;
      input.value = ''; autosize(); setState(true, false);
      state.pending = text; render(state.log);                     // echo it now; the log confirms
      post('/api/send', { path: proj, chat: chat, message: text }).catch(function () { state.pending = null; render(state.log); setState(false, false); });
    }
    function resolve(decisions) { setState(true, false); post('/api/resolve', { path: proj, chat: chat, decisions: decisions }); }
    function autosize() { input.style.height = 'auto'; input.style.height = Math.min(input.scrollHeight, 200) + 'px'; }
    form.addEventListener('submit', function (e) { e.preventDefault(); send(); });
    stopBtn.addEventListener('click', function () { post('/api/stop', me); });
    input.addEventListener('input', autosize);
    input.addEventListener('keydown', function (e) { if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); send(); } });
    var lastEsc = 0;
    function onEsc(e) {
      if (e.key !== 'Escape' || dead || stopBtn.disabled || !root.offsetParent) return;
      var now = Date.now();
      if (now - lastEsc < 500) { lastEsc = 0; stopBtn.click(); } else lastEsc = now;
    }
    document.addEventListener('keydown', onEsc);

    // one tool use, with its result once it has one
    function step(use, res, trace) {
      var d = el('details', 'cv-step'), s = el('summary');
      s.appendChild(el('span', 'tool', use.name));
      s.appendChild(el('span', 'arg', (trace && trace.arg) || firstString(use.input)));
      if (use.name === 'spawn' && use.input && use.input.name) {
        var lnk = el('a', 'arg', 'open ' + use.input.name + ' →'); lnk.href = '#';
        var dir = './' + use.input.name + '.clanker';   // the sub-clanker beneath this chat, relative to it as spelled
        lnk.onclick = function (e) { e.preventDefault(); e.stopPropagation(); if (opts.onNavigate) opts.onNavigate(dir, 'dir', { name: use.input.name }); };
        s.appendChild(lnk);
      }
      var note = trace && trace.note;
      s.appendChild(el('span', 'state' + (note === 'error' ? ' err' : note === 'declined' ? ' declined' : ''), res ? (note || 'done') : 'running'));
      d.appendChild(s);
      d.appendChild(el('pre', null, JSON.stringify(use.input || {}, null, 1)));
      if (res) {
        // an attachment (a snap, a document) is a file the log refers to
        var blobs = Array.isArray(res.content) ? res.content.filter(function (b) { return b && typeof b.blob === 'string'; }) : [];
        blobs.forEach(function (b) {
          if (/^image\//.test(b.media_type || '')) { var im = el('img'); im.src = blobUrl(b.blob); im.alt = b.blob; im.loading = 'lazy'; d.appendChild(im); }
          else { var a = el('a', 'arg', b.blob); a.href = blobUrl(b.blob); a.target = '_blank'; d.appendChild(a); }
        });
        var txt = resultText(res);
        if (txt && !/^(\[(image|document)\]\n?)+$/.test(txt)) d.appendChild(el('pre', null, txt));
      }
      return d;
    }
    // the ask box: run / decline per asked use; posts once every use has an answer
    function askBox(uses, live) {
      var box = el('div', 'cv-ask');
      box.appendChild(el('div', 'title', live ? who + ' wants to run these. Allow?' : 'asked'));
      var choice = {};
      function maybe() { if (uses.every(function (u) { return u.id in choice; })) resolve(choice); }
      uses.forEach(function (u) {
        var r = el('div', 'row');
        r.appendChild(el('span', 'tool', u.name)); r.appendChild(el('span', 'arg', firstString(u.input)));
        if (live) {
          var run = el('button', 'run', 'run'), no = el('button', 'no', 'decline');
          run.onclick = function () { choice[u.id] = true; run.classList.add('on'); no.classList.remove('on'); maybe(); };
          no.onclick = function () { choice[u.id] = false; no.classList.add('on'); run.classList.remove('on'); maybe(); };
          r.appendChild(run); r.appendChild(no);
        }
        box.appendChild(r);
        box.appendChild(el('pre', null, JSON.stringify(u.input || {}, null, 1)));
      });
      if (live && uses.length > 1) {
        var all = el('div', 'all'), runAll = el('button', 'run', 'run all'), noAll = el('button', 'no', 'decline all');
        runAll.onclick = function () { uses.forEach(function (u) { choice[u.id] = true; }); resolve(choice); };
        noAll.onclick = function () { uses.forEach(function (u) { choice[u.id] = false; }); resolve(choice); };
        all.appendChild(runAll); all.appendChild(noAll); box.appendChild(all);
      }
      return box;
    }
    // the model's text is markdown (the explorer page carries marked in
    // its kit); the user's stays text. Without marked, text as it is.
    function renderMarkdown(md) {
      if (window.marked) { try { return window.marked.parse(md); } catch (e) { /* fall through */ } }
      return null;
    }
    function msg(cls, label, text) {
      var m = el('div', 'cv-msg ' + cls); m.appendChild(el('div', 'who', label));
      if (text) {
        var body = el('div', 'body');
        var html = cls === 'bot' ? renderMarkdown(text) : null;
        if (html != null) { body.innerHTML = html; highlight(body); } else body.textContent = text;
        m.appendChild(body);
      }
      return m;
    }
    function render(log, keepScroll) {
      thread.innerHTML = '';
      if (!log.length) { thread.appendChild(el('div', 'cv-empty', 'A new chat with ' + who + '. Every turn is appended to its event log.')); return; }
      if (state.first > 0) thread.appendChild(el('div', 'cv-meta', state.first + ' earlier · scroll up for more'));
      var pending = null;
      log.forEach(function (ev, i) {
        if (ev.k === 'input') thread.appendChild(msg('user', 'you', ev.body));
        else if (ev.k === 'response') {
          var content = ev.content || [];
          var text = content.filter(function (c) { return c.type === 'text'; }).map(function (c) { return c.text; }).join('\n');
          var b = msg('bot', who, text);
          if (!content.length && !ev.stop) b.appendChild(el('div', 'cv-err', 'empty response from the proxy'));
          var uses = content.filter(function (c) { return c.type === 'tool_use'; });
          if (uses.length) {
            var tr = el('div', 'cv-trace');
            uses.forEach(function (u) { tr.appendChild(step(u, null, null)); });
            b.appendChild(tr); pending = { el: tr, uses: uses };
          }
          var meta = [];
          if (ev.usage && ev.usage.input_tokens != null) meta.push(ev.usage.input_tokens + ' in · ' + ev.usage.output_tokens + ' out');
          if (ev.stop && ev.stop !== 'end_turn' && ev.stop !== 'tool_use') meta.push(ev.stop);
          if (meta.length) b.appendChild(el('div', 'cv-meta', meta.join(' · ')));
          thread.appendChild(b);
        } else if (ev.k === 'results') {
          if (!pending) return;
          pending.el.innerHTML = '';
          pending.uses.forEach(function (u, j) {
            var res = (ev.content || []).filter(function (r) { return r.tool_use_id === u.id; })[0];
            pending.el.appendChild(step(u, res || null, (ev.trace || [])[j]));
          });
          pending = null;
        } else if (ev.k === 'ask') {
          var live = i === log.length - 1;
          var asked = (pending ? pending.uses : []).filter(function (u) { return (ev.ids || []).indexOf(u.id) >= 0; });
          if (live && pending) pending.el.hidden = true;
          thread.appendChild(askBox(asked, live));
        } else if (ev.k === 'resolved') {
          var d = ev.decisions || {}, ids = Object.keys(d), ran = ids.filter(function (k) { return d[k] !== false; }).length;
          thread.appendChild(el('div', 'cv-meta', ran === ids.length ? 'allowed' : ran === 0 ? 'declined' : ran + ' allowed · ' + (ids.length - ran) + ' declined'));
        } else if (ev.k === 'interrupt') thread.appendChild(el('div', 'cv-meta', 'stopped'));
        else if (ev.k === 'recipe') thread.appendChild(el('div', 'cv-meta', ev.body));
        else thread.appendChild(el('div', 'cv-err', JSON.stringify(ev)));
      });
      if (state.pending != null) thread.appendChild(msg('user pending', 'you', state.pending));
      if ((busyAfter(log) || state.pending != null) && !askingAfter(log)) {
        var t = el('div', 'cv-msg bot'), ty = el('div', 'cv-typing');
        ty.appendChild(el('span')); ty.appendChild(el('span')); ty.appendChild(el('span'));
        t.appendChild(ty); thread.appendChild(t);
      }
      if (!keepScroll) logEl.scrollTop = logEl.scrollHeight;
    }
    load();
    return handle;
  }
  window.Viewers = window.Viewers || {};
  window.Viewers['chat'] = { label: 'Chat', mount: mount };
})();
