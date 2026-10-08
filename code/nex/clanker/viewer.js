// clanker chat viewer: the pane a chat-log opens in. Registered as
// window.Viewers['chat'] with the FileView contract: mount(root, opts)
// -> { destroy() }, opts.url the file's own /grubbery/ball url and
// opts.args what the collection's +pick-viewer handed over: {proj, chat},
// which clanker and chat this log is. The transcript is a fold over the
// log the collection serves, and send / stop go to the collection's api,
// which pokes that clanker's main.sig. Nothing here holds chat state.
(function () {
  'use strict';
  var API = '/grubbery/clanker';
  var CSS =
    '.cv{height:100%;display:flex;flex-direction:column;min-height:0;font:14px Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#1f2328;background:#fff}' +
    '.cv .log{flex:1;min-height:0;overflow-y:auto;padding:22px 16px 28px}' +
    '.cv .thread{max-width:760px;margin:0 auto;display:flex;flex-direction:column;gap:14px}' +
    '.cv .empty{color:#8b949e;font-size:13px;text-align:center;margin:60px auto;max-width:360px;line-height:1.6}' +
    '.cv .msg{display:flex;flex-direction:column;gap:5px}' +
    '.cv .msg.user{align-items:flex-end}' +
    '.cv .bubble{padding:9px 13px;border-radius:13px;font-size:14px;line-height:1.55;max-width:86%;white-space:pre-wrap;overflow-wrap:anywhere}' +
    '.cv .user .bubble{background:#0969da;color:#fff;border-bottom-right-radius:4px}' +
    '.cv .bot .bubble{background:#f6f8fa;color:#1f2328;border-bottom-left-radius:4px}' +
    '.cv .meta{font:11px ui-monospace,SFMono-Regular,Menlo,monospace;color:#8b949e;padding:0 4px}' +
    '.cv .trace{display:flex;flex-direction:column;gap:3px;max-width:86%}' +
    '.cv .step summary{list-style:none;cursor:pointer;display:flex;align-items:center;gap:7px;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;color:#57606a;padding:3px 6px;border-radius:7px}' +
    '.cv .step summary::-webkit-details-marker{display:none}' +
    '.cv .step summary:hover{background:#f6f8fa}' +
    '.cv .step .tool{color:#8250df;font-weight:700}' +
    '.cv .step .arg{color:#8b949e;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
    '.cv .step a.arg{color:#0969da;text-decoration:none}' +
    '.cv .step .note{color:#8b949e;flex:0 0 auto;margin-left:auto}' +
    '.cv .step .note.err{color:#cf222e}' +
    '.cv .step .note.declined{color:#9a6700}' +
    '.cv .ask{max-width:86%;border:1px solid #e3d4a0;background:#fffbea;border-radius:10px;padding:10px 12px;display:flex;flex-direction:column;gap:8px}' +
    '.cv .ask .ask-title{font:600 12px Inter,-apple-system,sans-serif;color:#7d5a00}' +
    '.cv .ask .ask-row{display:flex;align-items:center;gap:8px;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;color:#57606a}' +
    '.cv .ask .ask-row .tool{color:#8250df;font-weight:700}' +
    '.cv .ask .ask-row .arg{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#8b949e}' +
    '.cv .ask .ask-row pre{margin:0 0 0 0;padding:6px 8px;max-height:140px;overflow:auto;background:#fff;border:1px solid #eee3bd;border-radius:6px;font:11px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace;color:#444;white-space:pre-wrap;word-break:break-word}' +
    '.cv .ask button{flex:0 0 auto;height:26px;padding:0 10px;border-radius:6px;border:1px solid #d0d7de;background:#fff;color:#1f2328;cursor:pointer;font:600 11px Inter,-apple-system,sans-serif}' +
    '.cv .ask button.run{border-color:#1a7f37;color:#1a7f37}' +
    '.cv .ask button.run.on{background:#1a7f37;color:#fff}' +
    '.cv .ask button.decline{border-color:#cf222e;color:#cf222e}' +
    '.cv .ask button.decline.on{background:#cf222e;color:#fff}' +
    '.cv .ask .ask-all{display:flex;gap:8px;justify-content:flex-end}' +
    '.cv .step pre{margin:4px 0 6px 26px;padding:8px 10px;max-height:260px;overflow:auto;background:#fbfbfd;border:1px solid #e2e7ee;border-radius:7px;font:11.5px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;color:#444;white-space:pre-wrap;word-break:break-word}' +
    '.cv .step pre.args{background:#f6f8fa}' +
    '.cv .err{color:#cf222e;font-size:12.5px;background:#fff8f8;border:1px solid #ffcecb;border-radius:8px;padding:8px 11px;line-height:1.5;max-width:86%}' +
    '.cv .typing{display:flex;gap:4px;padding:6px 2px}' +
    '.cv .typing span{width:6px;height:6px;border-radius:50%;background:#c4c4c4;animation:cv-pulse 1.2s infinite both}' +
    '.cv .typing span:nth-child(2){animation-delay:.2s}.cv .typing span:nth-child(3){animation-delay:.4s}' +
    '@keyframes cv-pulse{0%,80%,100%{opacity:.3}40%{opacity:1}}' +
    '.cv .compose{flex:none;border-top:1px solid #d0d7de;padding:12px 16px;background:#f6f8fa}' +
    '.cv .compose-inner{max-width:760px;margin:0 auto;display:flex;gap:8px;align-items:flex-end}' +
    '.cv textarea{flex:1;resize:none;border:1px solid #d0d7de;border-radius:8px;padding:9px 12px;font:14px/1.4 Inter,-apple-system,sans-serif;color:#1f2328;outline:none;min-height:40px;max-height:200px;background:#fff}' +
    '.cv textarea:focus{border-color:#0969da;box-shadow:0 0 0 3px rgba(9,105,218,.15)}' +
    '.cv .send{flex:0 0 auto;height:40px;padding:0 16px;border-radius:8px;border:1px solid #0969da;background:#0969da;color:#fff;cursor:pointer;font:600 12px Inter,-apple-system,sans-serif}' +
    '.cv .send:disabled{background:#f6f8fa;border-color:#d0d7de;color:#8b949e;cursor:default}' +
    '.cv .stop{flex:0 0 auto;height:40px;padding:0 12px;border-radius:8px;border:1px solid #d0d7de;background:#fff;color:#57606a;cursor:pointer;font:12px Inter,-apple-system,sans-serif}' +
    '.cv .stop:hover:not([disabled]){background:#fff8f8;color:#cf222e;border-color:#ffcecb}' +
    '.cv .stop:disabled{opacity:.45;cursor:default}' +
    '.cv .hint{max-width:760px;margin:6px auto 0;font-size:11px;color:#8b949e;display:flex;gap:10px}';
  var styled = false;
  function injectStyle() {
    if (styled) return; styled = true;
    var s = document.createElement('style'); s.textContent = CSS; document.head.appendChild(s);
  }
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  // where this log lives, as the collection said: {proj, chat}; the log's
  // own directory (for a spawn link) is the url's dirname
  function locate(opts) {
    var a = opts.args || {};
    if (typeof a.proj !== 'string' || typeof a.chat !== 'string') return null;
    var u = (opts.url || '').replace(/\?.*$/, '');
    return { dir: u.slice(0, u.lastIndexOf('/')), proj: a.proj, chat: a.chat };
  }
  // a turn is running after an input, tool results, a response that asked
  // for tools, or a resolved ask; paused on the user after an ask (no new
  // message until it is answered, stop cancels it)
  function busyAfter(log) {
    var last = log[log.length - 1];
    return !!last && (last.k === 'input' || last.k === 'results' || last.k === 'resolved' || (last.k === 'response' && last.stop === 'tool_use'));
  }
  function askingAfter(log) {
    var last = log[log.length - 1];
    return !!last && last.k === 'ask';
  }
  function mount(root, opts) {
    injectStyle();
    var loc = locate(opts);
    root.innerHTML = '';
    root.classList.add('cv');
    if (!loc) { root.appendChild(el('div', 'empty', 'no chat here: the collection gave no {proj, chat} for ' + opts.url)); return { destroy: function () { root.innerHTML = ''; root.classList.remove('cv'); } }; }
    var logEl = el('div', 'log'), threadEl = el('div', 'thread'); logEl.appendChild(threadEl);
    var form = el('form', 'compose'), inner = el('div', 'compose-inner');
    var msgEl = el('textarea'); msgEl.rows = 1; msgEl.placeholder = 'Message ' + loc.proj.replace(/^.*\//, '').replace(/\.clanker$/, '') + ' …'; msgEl.spellcheck = false;
    var stopBtn = el('button', 'stop', 'stop'); stopBtn.type = 'button'; stopBtn.disabled = true; stopBtn.title = 'stop the running turn (Esc Esc)';
    var sendBtn = el('button', 'send', 'send'); sendBtn.type = 'submit'; sendBtn.title = 'send (Enter)';
    inner.appendChild(msgEl); inner.appendChild(stopBtn); inner.appendChild(sendBtn);
    form.appendChild(inner);
    var hint = el('div', 'hint'); hint.appendChild(el('span', null, 'Enter to send, Shift+Enter for a new line, Esc Esc to stop')); hint.appendChild(el('span', null, 'the transcript is the stored event log'));
    form.appendChild(hint);
    root.appendChild(logEl); root.appendChild(form);
    var busy = false, timer = null, lastLen = -1, dead = false;
    function post(path, body) { return fetch(API + path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) }); }
    // busy: a turn runs (poll the log; send off, stop on). asking: paused
    // on the user (no poll; send off, stop on; the ask box takes the answer)
    function setBusy(b, asking) {
      busy = b; sendBtn.disabled = b || !!asking; stopBtn.disabled = !(b || asking);
      if (b && !timer) timer = setInterval(load, 1500);
      if (!b && timer) { clearInterval(timer); timer = null; }
    }
    function load() {
      if (dead) return;
      return fetch(API + '/api/log?path=' + encodeURIComponent(loc.proj) + '&chat=' + encodeURIComponent(loc.chat), { cache: 'no-store' })
        .then(function (r) { return r.json(); })
        .then(function (log) {
          if (dead) return;
          if (log.length !== lastLen) { lastLen = log.length; render(log); }
          setBusy(busyAfter(log), askingAfter(log));
        }).catch(function () {});
    }
    // the user's answer to a pending ask: {id: true|false} for every asked
    // use, posted once each has one
    function resolve(decisions) {
      post('/api/resolve', { path: loc.proj, chat: loc.chat, decisions: decisions }).then(function () { setBusy(true, false); load(); });
    }
    function send() {
      var text = msgEl.value.trim();
      if (!text || busy) return;
      msgEl.value = ''; autosize();
      post('/api/send', { path: loc.proj, chat: loc.chat, message: text }).then(function () { setBusy(true); load(); });
    }
    function autosize() { msgEl.style.height = 'auto'; msgEl.style.height = Math.min(msgEl.scrollHeight, 200) + 'px'; }
    form.addEventListener('submit', function (e) { e.preventDefault(); send(); });
    stopBtn.addEventListener('click', function () { post('/api/stop', { path: loc.proj, chat: loc.chat }).then(function () { setTimeout(load, 600); }); });
    msgEl.addEventListener('input', autosize);
    // Enter sends; Shift+Enter is a newline
    msgEl.addEventListener('keydown', function (e) { if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) { e.preventDefault(); send(); } });
    // Escape twice within half a second stops the running turn (as the
    // claude page does); only while this pane is showing and a turn runs
    var lastEsc = 0;
    function onEsc(e) {
      if (e.key !== 'Escape' || dead || stopBtn.disabled || !root.offsetParent) return;
      var now = Date.now();
      if (now - lastEsc < 500) { lastEsc = 0; stopBtn.click(); } else lastEsc = now;
    }
    document.addEventListener('keydown', onEsc);
    function step(use, result, trace) {
      var d = el('details', 'step'), s = el('summary');
      s.appendChild(el('span', 'tool', use.name));
      if (trace && trace.arg) s.appendChild(el('span', 'arg', trace.arg));
      // a spawn is a nested clanker beneath this chat: link to its directory
      if (use.name === 'spawn' && use.input && use.input.name) {
        var lnk = el('a', 'arg', 'open ' + use.input.name + ' →'); lnk.href = '#';
        var dir = loc.dir + '/' + use.input.name + '.clanker';
        lnk.onclick = function (e) { e.preventDefault(); e.stopPropagation(); if (opts.onNavigate) opts.onNavigate(dir); else location.href = dir; };
        s.appendChild(lnk);
      }
      var noteCls = trace && trace.note === 'error' ? ' err' : trace && trace.note === 'declined' ? ' declined' : '';
      s.appendChild(el('span', 'note' + noteCls, result ? (trace ? trace.note : 'done') : 'running'));
      d.appendChild(s);
      d.appendChild(el('pre', 'args', JSON.stringify(use.input || {}, null, 1)));
      if (result) {
        var body = typeof result.content === 'string' ? result.content
          : Array.isArray(result.content) ? result.content.map(function (b) { return b.type === 'text' ? b.text : '[' + b.type + ']'; }).join('\n')
          : JSON.stringify(result.content);
        d.appendChild(el('pre', null, body));
      }
      return d;
    }
    // the ask box: one row per asked tool use with run / decline; the
    // answer posts once every row has one (one click when there is one).
    // A box that is no longer live shows the uses, no buttons.
    function askBox(uses, live) {
      var box = el('div', 'ask');
      box.appendChild(el('div', 'ask-title', live ? 'wants to run — allow?' : 'asked'));
      var choice = {};
      function maybePost() {
        if (uses.every(function (u) { return u.id in choice; })) resolve(choice);
      }
      uses.forEach(function (u) {
        var row = el('div', 'ask-row');
        row.appendChild(el('span', 'tool', u.name));
        var args = u.input || {};
        var first = Object.keys(args).map(function (k) { return args[k]; }).filter(function (v) { return typeof v === 'string'; })[0];
        row.appendChild(el('span', 'arg', first || ''));
        if (live) {
          var runB = el('button', 'run', 'run'), noB = el('button', 'decline', 'decline');
          runB.onclick = function () { choice[u.id] = true; runB.classList.add('on'); noB.classList.remove('on'); maybePost(); };
          noB.onclick = function () { choice[u.id] = false; noB.classList.add('on'); runB.classList.remove('on'); maybePost(); };
          row.appendChild(runB); row.appendChild(noB);
        }
        box.appendChild(row);
        var pre = el('pre', null, JSON.stringify(args, null, 1));
        box.appendChild(pre);
      });
      if (live && uses.length > 1) {
        var all = el('div', 'ask-all');
        var runAll = el('button', 'run', 'run all'), noAll = el('button', 'decline', 'decline all');
        runAll.onclick = function () { uses.forEach(function (u) { choice[u.id] = true; }); resolve(choice); };
        noAll.onclick = function () { uses.forEach(function (u) { choice[u.id] = false; }); resolve(choice); };
        all.appendChild(runAll); all.appendChild(noAll);
        box.appendChild(all);
      }
      return box;
    }
    function render(log) {
      threadEl.innerHTML = '';
      if (!log.length) {
        threadEl.appendChild(el('div', 'empty', 'A new chat. Every turn is appended to its event log and the request is assembled from it.'));
        return;
      }
      var pending = null;
      log.forEach(function (ev, i) {
        if (ev.k === 'input') {
          var u = el('div', 'msg user'); u.appendChild(el('div', 'bubble', ev.body)); threadEl.appendChild(u);
        } else if (ev.k === 'response') {
          var b = el('div', 'msg bot');
          var text = (ev.content || []).filter(function (c) { return c.type === 'text'; }).map(function (c) { return c.text; }).join('\n');
          if (ev.content && !ev.content.length && !ev.stop) b.appendChild(el('div', 'err', 'empty response from the proxy'));
          if (text) b.appendChild(el('div', 'bubble', text));
          var uses = (ev.content || []).filter(function (c) { return c.type === 'tool_use'; });
          if (uses.length) {
            var tr = el('div', 'trace');
            uses.forEach(function (use) { tr.appendChild(step(use, null, null)); });
            b.appendChild(tr);
            pending = { el: tr, uses: uses };
          }
          var meta = [];
          if (ev.usage && ev.usage.input_tokens != null) meta.push(ev.usage.input_tokens + ' in · ' + ev.usage.output_tokens + ' out');
          if (ev.stop && ev.stop !== 'end_turn' && ev.stop !== 'tool_use') meta.push(ev.stop);
          if (meta.length) b.appendChild(el('div', 'meta', meta.join(' · ')));
          threadEl.appendChild(b);
        } else if (ev.k === 'results') {
          if (pending) {
            pending.el.innerHTML = '';
            pending.uses.forEach(function (use, i) {
              var res = (ev.content || []).filter(function (r) { return r.tool_use_id === use.id; })[0];
              pending.el.appendChild(step(use, res || null, (ev.trace || [])[i]));
            });
            pending = null;
          }
        } else if (ev.k === 'interrupt') {
          threadEl.appendChild(el('div', 'meta', 'stopped'));
        } else if (ev.k === 'ask') {
          // the turn is paused: these uses of the last response ask first.
          // Only the LAST ask (the log's tail) is live; an earlier one was
          // answered (a resolved event follows) or stopped.
          var live = (i === log.length - 1);
          var asked = (pending ? pending.uses : []).filter(function (u) { return (ev.ids || []).indexOf(u.id) >= 0; });
          // while paused the response's own trace ("running") would mislead
          if (live && pending) pending.el.style.display = 'none';
          threadEl.appendChild(askBox(asked, live));
        } else if (ev.k === 'resolved') {
          var d = ev.decisions || {};
          var ids = Object.keys(d);
          var ran = ids.filter(function (k) { return d[k] !== false; }).length;
          threadEl.appendChild(el('div', 'meta', ran === ids.length ? 'allowed' : ran === 0 ? 'declined' : ran + ' allowed · ' + (ids.length - ran) + ' declined'));
        } else threadEl.appendChild(el('div', 'err', JSON.stringify(ev)));
      });
      if (busyAfter(log) && !askingAfter(log)) {
        var t = el('div', 'msg bot'), ty = el('div', 'typing');
        ty.appendChild(el('span')); ty.appendChild(el('span')); ty.appendChild(el('span'));
        t.appendChild(ty); threadEl.appendChild(t);
      }
      logEl.scrollTop = logEl.scrollHeight;
    }
    load();
    return {
      destroy: function () { dead = true; if (timer) clearInterval(timer); document.removeEventListener('keydown', onEsc); root.innerHTML = ''; root.classList.remove('cv'); },
      setUrl: function (u) { mount(root, Object.assign({}, opts, { url: u })); }
    };
  }
  window.Viewers = window.Viewers || {};
  window.Viewers['chat'] = { label: 'Chat', mount: mount };
})();
