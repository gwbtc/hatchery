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

  function mount(root, opts) {
    css();
    var a = opts.args || {};
    var proj = typeof a.proj === 'string' ? a.proj : null, chat = typeof a.chat === 'string' ? a.chat : null;
    var who = proj ? proj.replace(/^.*\//, '').replace(/\.clanker$/, '') : 'clanker';
    root.innerHTML = ''; root.classList.add('cv');
    var dead = false;
    var handle = { destroy: function () { dead = true; document.removeEventListener('keydown', onEsc); root.innerHTML = ''; root.classList.remove('cv'); }, onUpdate: function (ev) { if (ev && Array.isArray(ev.body)) apply(ev.body); else if (!ev || /log\.chat-log$/.test(ev.path || '')) load(); } };   // the log's body, or a bodiless event for the log itself; nothing else is ours
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
    var state = { busy: false, asking: false, len: -1, log: [], pending: null };
    function setState(busy, asking) { state.busy = busy; state.asking = asking; sendBtn.disabled = busy || asking; stopBtn.disabled = !(busy || asking); }
    function apply(log) {
      if (dead || !Array.isArray(log)) return;
      var grew = log.length !== state.len;
      if (grew && state.pending != null) state.pending = null;   // the log moved on: our message is in it (or the turn was refused)
      state.log = log;
      if (grew) { state.len = log.length; render(log); }
      setState(busyAfter(log) || state.pending != null, askingAfter(log));
    }
    function load() {
      if (dead) return;
      fetch(API + '/api/log?path=' + encodeURIComponent(proj) + '&chat=' + encodeURIComponent(chat), { cache: 'no-store' })
        .then(function (r) { return r.json(); }).then(apply).catch(function () {});
    }
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
      if (res) d.appendChild(el('pre', null, resultText(res)));
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
    function msg(cls, label, text) {
      var m = el('div', 'cv-msg ' + cls); m.appendChild(el('div', 'who', label));
      if (text) m.appendChild(el('div', 'body', text));
      return m;
    }
    function render(log) {
      thread.innerHTML = '';
      if (!log.length) { thread.appendChild(el('div', 'cv-empty', 'A new chat with ' + who + '. Every turn is appended to its event log.')); return; }
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
        else thread.appendChild(el('div', 'cv-err', JSON.stringify(ev)));
      });
      if (state.pending != null) thread.appendChild(msg('user pending', 'you', state.pending));
      if ((busyAfter(log) || state.pending != null) && !askingAfter(log)) {
        var t = el('div', 'cv-msg bot'), ty = el('div', 'cv-typing');
        ty.appendChild(el('span')); ty.appendChild(el('span')); ty.appendChild(el('span'));
        t.appendChild(ty); thread.appendChild(t);
      }
      logEl.scrollTop = logEl.scrollHeight;
    }
    load();
    return handle;
  }
  window.Viewers = window.Viewers || {};
  window.Viewers['chat'] = { label: 'Chat', mount: mount };
})();
