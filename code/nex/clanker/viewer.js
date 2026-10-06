// clanker chat viewer: how the explorer opens a chat-log. Registered as
// window.Viewers['chat-log'] with the FileView contract: mount(root, opts)
// -> { destroy() }, opts.url the file's own /grubbery/ball url. The url
// says which clanker and chat this is (…/<x>.clanker/chats/<chat>/log.chat-log);
// the transcript is a fold over the log the collection serves, and send /
// stop go to the collection's api, which pokes that clanker's main.sig.
// Nothing here holds chat state.
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
  // where this log lives: the clanker path under /projects and the chat name
  function locate(url) {
    var u = url.replace(/\?.*$/, '');
    var pi = u.indexOf('/projects/');
    var ci = u.lastIndexOf('/chats/');
    if (pi < 0 || ci < 0 || ci < pi) return null;
    var proj = u.slice(pi + '/projects'.length, ci);
    var rest = u.slice(ci + '/chats/'.length).split('/');
    return { ballRoot: u.slice(0, pi), proj: proj, chat: decodeURIComponent(rest[0] || 'main') };
  }
  function busyAfter(log) {
    var last = log[log.length - 1];
    return !!last && (last.k === 'input' || last.k === 'results' || (last.k === 'response' && last.stop === 'tool_use'));
  }
  function mount(root, opts) {
    injectStyle();
    var loc = locate(opts.url);
    root.innerHTML = '';
    root.classList.add('cv');
    if (!loc) { root.appendChild(el('div', 'empty', 'not a chat log: ' + opts.url)); return { destroy: function () { root.innerHTML = ''; root.classList.remove('cv'); } }; }
    var logEl = el('div', 'log'), threadEl = el('div', 'thread'); logEl.appendChild(threadEl);
    var form = el('form', 'compose'), inner = el('div', 'compose-inner');
    var msgEl = el('textarea'); msgEl.rows = 1; msgEl.placeholder = 'Message ' + loc.proj.replace(/^.*\//, '').replace(/\.clanker$/, '') + ' …'; msgEl.spellcheck = false;
    var stopBtn = el('button', 'stop', 'stop'); stopBtn.type = 'button'; stopBtn.disabled = true;
    var sendBtn = el('button', 'send', 'send'); sendBtn.type = 'submit'; sendBtn.title = 'send (⌘↩)';
    inner.appendChild(msgEl); inner.appendChild(stopBtn); inner.appendChild(sendBtn);
    form.appendChild(inner);
    var hint = el('div', 'hint'); hint.appendChild(el('span', null, '⌘↩ to send')); hint.appendChild(el('span', null, 'the transcript is the stored event log'));
    form.appendChild(hint);
    root.appendChild(logEl); root.appendChild(form);
    var busy = false, timer = null, lastLen = -1, dead = false;
    function post(path, body) { return fetch(API + path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) }); }
    function setBusy(b) {
      busy = b; sendBtn.disabled = b; stopBtn.disabled = !b;
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
          setBusy(busyAfter(log));
        }).catch(function () {});
    }
    function send() {
      var text = msgEl.value.trim();
      if (!text || busy) return;
      msgEl.value = ''; autosize();
      post('/api/send', { path: loc.proj, chat: loc.chat, message: text }).then(function () { setBusy(true); load(); });
    }
    function autosize() { msgEl.style.height = 'auto'; msgEl.style.height = Math.min(msgEl.scrollHeight, 200) + 'px'; }
    form.addEventListener('submit', function (e) { e.preventDefault(); send(); });
    stopBtn.addEventListener('click', function () { post('/api/stop', { path: loc.proj }).then(function () { setTimeout(load, 600); }); });
    msgEl.addEventListener('input', autosize);
    msgEl.addEventListener('keydown', function (e) { if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); send(); } });
    function step(use, result, trace) {
      var d = el('details', 'step'), s = el('summary');
      s.appendChild(el('span', 'tool', use.name));
      if (trace && trace.arg) s.appendChild(el('span', 'arg', trace.arg));
      // a spawn is a nested clanker beneath this chat: link to its directory
      if (use.name === 'spawn' && use.input && use.input.name) {
        var lnk = el('a', 'arg', 'open ' + use.input.name + ' →'); lnk.href = '#';
        var dir = loc.ballRoot + '/projects' + loc.proj + '/chats/' + loc.chat + '/' + use.input.name + '.clanker';
        lnk.onclick = function (e) { e.preventDefault(); e.stopPropagation(); if (opts.onNavigate) opts.onNavigate(dir); else location.href = dir; };
        s.appendChild(lnk);
      }
      s.appendChild(el('span', 'note' + (trace && trace.note === 'error' ? ' err' : ''), result ? (trace ? trace.note : 'done') : 'running'));
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
    function render(log) {
      threadEl.innerHTML = '';
      if (!log.length) {
        threadEl.appendChild(el('div', 'empty', 'A new chat. Every turn is appended to its event log and the request is assembled from it.'));
        return;
      }
      var pending = null;
      log.forEach(function (ev) {
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
        } else threadEl.appendChild(el('div', 'err', JSON.stringify(ev)));
      });
      if (busyAfter(log)) {
        var t = el('div', 'msg bot'), ty = el('div', 'typing');
        ty.appendChild(el('span')); ty.appendChild(el('span')); ty.appendChild(el('span'));
        t.appendChild(ty); threadEl.appendChild(t);
      }
      logEl.scrollTop = logEl.scrollHeight;
    }
    load();
    return {
      destroy: function () { dead = true; if (timer) clearInterval(timer); root.innerHTML = ''; root.classList.remove('cv'); },
      setUrl: function (u) { mount(root, Object.assign({}, opts, { url: u })); }
    };
  }
  window.Viewers = window.Viewers || {};
  window.Viewers['chat-log'] = { label: 'Chat', mount: mount };
})();
