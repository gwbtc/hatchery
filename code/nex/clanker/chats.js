// clanker chats pane: the view of a clanker's chats/ directory. Registered
// as window.Viewers['chats'] with the dir-pane contract: mount(root, opts)
// -> { destroy() }, opts.url the directory's own /grubbery/ball url,
// opts.args what the collection's +pick-viewer handed over: {proj}, which
// clanker this is. One row per chat (its name, how long the log is, the
// last thing said to it, whether a turn is running); a row opens that
// chat's log in this tab, where the chat pane takes over. A new chat is
// made through the collection's api and opened the same way. Nothing here
// holds state: the rows are a fold over the logs the collection serves.
(function () {
  'use strict';
  var API = '/grubbery/clanker';
  var CSS =
    '.cl{height:100%;display:flex;flex-direction:column;min-height:0;font:14px Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#1f2328;background:#fff}' +
    '.cl .head{flex:none;display:flex;align-items:center;gap:10px;padding:12px 16px;border-bottom:1px solid #d0d7de;background:#f6f8fa}' +
    '.cl .head .title{font-weight:600;font-size:13px;color:#57606a;flex:1}' +
    '.cl .head input{width:200px;border:1px solid #d0d7de;border-radius:7px;padding:6px 10px;font:13px Inter,-apple-system,sans-serif;outline:none;background:#fff}' +
    '.cl .head input:focus{border-color:#0969da;box-shadow:0 0 0 3px rgba(9,105,218,.15)}' +
    '.cl .head button{height:31px;padding:0 13px;border-radius:7px;border:1px solid #0969da;background:#0969da;color:#fff;cursor:pointer;font:600 12px Inter,-apple-system,sans-serif}' +
    '.cl .head button:disabled{background:#f6f8fa;border-color:#d0d7de;color:#8b949e;cursor:default}' +
    '.cl .list{flex:1;min-height:0;overflow-y:auto;padding:8px 0}' +
    '.cl .row{display:grid;grid-template-columns:10px 180px 1fr auto;gap:12px;align-items:center;padding:10px 16px;cursor:pointer;border-bottom:1px solid #f0f2f4}' +
    '.cl .row:hover{background:#f6f8fa}' +
    '.cl .dot{width:8px;height:8px;border-radius:50%;background:#d0d7de}' +
    '.cl .dot.busy{background:#2da44e;animation:cl-pulse 1.2s infinite both}' +
    '@keyframes cl-pulse{0%,100%{opacity:.4}50%{opacity:1}}' +
    '.cl .name{font:600 13px ui-monospace,SFMono-Regular,Menlo,monospace;color:#0969da;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
    '.cl .last{color:#57606a;font-size:13px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
    '.cl .last.none{color:#8b949e;font-style:italic}' +
    '.cl .count{font:11px ui-monospace,SFMono-Regular,Menlo,monospace;color:#8b949e;white-space:nowrap}' +
    '.cl .empty{color:#8b949e;font-size:13px;text-align:center;margin:60px auto;max-width:360px;line-height:1.6}' +
    '.cl .err{color:#cf222e;font-size:12.5px;margin:12px 16px}';
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
  function mount(root, opts) {
    injectStyle();
    var proj = opts.args && typeof opts.args.proj === 'string' ? opts.args.proj : null;
    var dirUrl = (opts.url || '').replace(/\?.*$/, '').replace(/\/+$/, '');
    root.innerHTML = '';
    root.classList.add('cl');
    var dead = false, timer = null;
    function destroy() { dead = true; if (timer) clearInterval(timer); root.innerHTML = ''; root.classList.remove('cl'); }
    if (!proj) { root.appendChild(el('div', 'empty', 'no clanker here: the collection gave no {proj} for ' + opts.url)); return { destroy: destroy }; }
    var head = el('div', 'head');
    head.appendChild(el('span', 'title', 'chats of ' + proj.replace(/^.*\//, '').replace(/\.clanker$/, '')));
    var nameEl = el('input'); nameEl.placeholder = 'new chat name'; nameEl.spellcheck = false;
    var newBtn = el('button', null, 'new chat');
    // a chat's own prompt, optional: the role this chat plays on top of the
    // clanker's identity (docs, build, …); stored as chats/<name>/system.md
    var sysEl = el('input'); sysEl.placeholder = 'its prompt (optional)'; sysEl.spellcheck = false; sysEl.style.width = '320px';
    head.appendChild(nameEl); head.appendChild(sysEl); head.appendChild(newBtn);
    var list = el('div', 'list');
    root.appendChild(head); root.appendChild(list);
    function openChat(name) {
      var u = dirUrl + '/' + encodeURIComponent(name) + '/log.chat-log';
      if (opts.onNavigate) opts.onNavigate(u, 'file'); else location.href = u;
    }
    function render(rows) {
      list.innerHTML = '';
      if (!rows.length) { list.appendChild(el('div', 'empty', 'No chats yet. Name one above to start it.')); return; }
      rows.forEach(function (c) {
        var r = el('div', 'row');
        r.appendChild(el('span', 'dot' + (c.busy ? ' busy' : '')));
        r.appendChild(el('span', 'name', c.name + (c.prompt ? ' ·' : '')));
        r.appendChild(el('span', 'last' + (c.last ? '' : ' none'), c.last || 'nothing said yet'));
        r.appendChild(el('span', 'count', c.events + (c.events === 1 ? ' event' : ' events') + (c.prompt ? ' · own prompt' : '')));
        r.title = c.busy ? 'a turn is running' : 'open';
        r.addEventListener('click', function () { openChat(c.name); });
        list.appendChild(r);
      });
    }
    function load() {
      if (dead) return;
      return fetch(API + '/api/chats?path=' + encodeURIComponent(proj), { cache: 'no-store' })
        .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
        .then(function (rows) { if (!dead) render(Array.isArray(rows) ? rows : []); })
        .catch(function (e) { if (!dead) { list.innerHTML = ''; list.appendChild(el('div', 'err', 'chats failed to load: ' + e.message)); } });
    }
    function create() {
      var name = nameEl.value.trim().toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, '');
      if (!name) { nameEl.focus(); return; }
      newBtn.disabled = true;
      var sys = sysEl.value.trim();
      fetch(API + '/api/new', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ kind: 'chat', parent: proj, name: name, system: sys }) })
        .then(function (r) { if (!r.ok) throw new Error(r.status); nameEl.value = ''; sysEl.value = ''; openChat(name); })
        .catch(function (e) { list.insertBefore(el('div', 'err', 'could not make the chat: ' + e.message), list.firstChild); })
        .then(function () { newBtn.disabled = false; });
    }
    newBtn.addEventListener('click', create);
    nameEl.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); create(); } });
    sysEl.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); create(); } });
    load();
    timer = setInterval(load, 4000);
    return { destroy: destroy };
  }
  // the collection pane: the view of the collection root, or of a
  // category in it. Every clanker under it, each with its chats and their
  // state, from the collection's api; a chat row opens that chat's log in
  // this tab, a clanker's name opens its directory. New clankers and
  // categories are made through the api and the listing refreshes.
  var CSS2 =
    '.cc{height:100%;display:flex;flex-direction:column;min-height:0;font:14px Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#1f2328;background:#fff}' +
    '.cc .head{flex:none;display:flex;align-items:center;gap:10px;padding:12px 16px;border-bottom:1px solid #d0d7de;background:#f6f8fa}' +
    '.cc .head .title{font-weight:600;font-size:13px;color:#57606a;flex:1}' +
    '.cc .head input{width:180px;border:1px solid #d0d7de;border-radius:7px;padding:6px 10px;font:13px Inter,-apple-system,sans-serif;outline:none;background:#fff}' +
    '.cc .head select{border:1px solid #d0d7de;border-radius:7px;padding:6px 8px;font:13px Inter,-apple-system,sans-serif;background:#fff}' +
    '.cc .head button{height:31px;padding:0 13px;border-radius:7px;border:1px solid #0969da;background:#0969da;color:#fff;cursor:pointer;font:600 12px Inter,-apple-system,sans-serif}' +
    '.cc .head button:disabled{background:#f6f8fa;border-color:#d0d7de;color:#8b949e;cursor:default}' +
    '.cc .list{flex:1;min-height:0;overflow-y:auto;padding:8px 0 24px}' +
    '.cc .group{padding:14px 16px 6px;display:flex;align-items:baseline;gap:10px;border-bottom:1px solid #f0f2f4}' +
    '.cc .group .nm{font:600 14px ui-monospace,SFMono-Regular,Menlo,monospace;color:#0969da;cursor:pointer}' +
    '.cc .group .nm:hover{text-decoration:underline}' +
    '.cc .group .bundle{font:11px ui-monospace,SFMono-Regular,Menlo,monospace;color:#8b949e}' +
    '.cc .group.cat .nm{color:#57606a}' +
    '.cc .row{display:grid;grid-template-columns:10px 160px 1fr auto;gap:12px;align-items:center;padding:8px 16px 8px 32px;cursor:pointer;border-bottom:1px solid #f6f8fa}' +
    '.cc .row:hover{background:#f6f8fa}' +
    '.cc .dot{width:8px;height:8px;border-radius:50%;background:#d0d7de}' +
    '.cc .dot.busy{background:#2da44e;animation:cl-pulse 1.2s infinite both}' +
    '.cc .dot.asking{background:#d4a72c}' +
    '.cc .name{font:600 13px ui-monospace,SFMono-Regular,Menlo,monospace;color:#0969da;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
    '.cc .last{color:#57606a;font-size:13px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
    '.cc .last.none{color:#8b949e;font-style:italic}' +
    '.cc .count{font:11px ui-monospace,SFMono-Regular,Menlo,monospace;color:#8b949e;white-space:nowrap}' +
    '.cc .nochat{padding:6px 16px 10px 32px;color:#8b949e;font-size:12.5px;font-style:italic}' +
    '.cc .empty{color:#8b949e;font-size:13px;text-align:center;margin:60px auto;max-width:360px;line-height:1.6}' +
    '.cc .err{color:#cf222e;font-size:12.5px;margin:12px 16px}';
  var styled2 = false;
  function injectStyle2() {
    if (styled2) return; styled2 = true;
    var s = document.createElement('style'); s.textContent = CSS2; document.head.appendChild(s);
  }
  function mountCollection(root, opts) {
    injectStyle2();
    var parent = opts.args && typeof opts.args.parent === 'string' ? opts.args.parent : '/';
    var dirUrl = (opts.url || '').replace(/\?.*$/, '').replace(/\/+$/, '');
    root.innerHTML = '';
    root.classList.add('cc');
    var dead = false, timer = null;
    function destroy() { dead = true; if (timer) clearInterval(timer); root.innerHTML = ''; root.classList.remove('cc'); }
    var head = el('div', 'head');
    head.appendChild(el('span', 'title', parent === '/' ? 'clankers' : 'clankers in ' + parent));
    var kindEl = el('select'); ['clanker', 'category'].forEach(function (k) { var o = el('option', null, 'new ' + k); o.value = k; kindEl.appendChild(o); });
    var nameEl = el('input'); nameEl.placeholder = 'name'; nameEl.spellcheck = false;
    var newBtn = el('button', null, 'make');
    head.appendChild(kindEl); head.appendChild(nameEl); head.appendChild(newBtn);
    var list = el('div', 'list');
    root.appendChild(head); root.appendChild(list);
    function go(u, kind) { if (opts.onNavigate) opts.onNavigate(u, kind); else location.href = u; }
    // the subtree of the collection tree under `parent`
    function subtree(tree) {
      var node = tree;
      parent.split('/').filter(Boolean).forEach(function (seg) { node = node && node.dirs && node.dirs[seg]; });
      return node;
    }
    function render(tree) {
      list.innerHTML = '';
      var node = subtree(tree);
      if (!node || !node.dirs) { list.appendChild(el('div', 'empty', 'Nothing here yet.')); return; }
      var names = Object.keys(node.dirs).sort();
      if (!names.length) { list.appendChild(el('div', 'empty', 'No clankers yet. Make one above.')); return; }
      // categories first, then clankers
      var cats = names.filter(function (n) { return !/\.clanker$/.test(n); });
      var clankers = names.filter(function (n) { return /\.clanker$/.test(n); });
      cats.forEach(function (n) {
        var g = el('div', 'group cat');
        var nm = el('span', 'nm', n + '/'); nm.title = 'open';
        nm.addEventListener('click', function () { go(dirUrl + '/' + encodeURIComponent(n), 'dir'); });
        g.appendChild(nm); g.appendChild(el('span', 'bundle', 'category'));
        list.appendChild(g);
      });
      clankers.forEach(function (n) {
        var proj = (parent === '/' ? '' : parent) + '/' + n;
        var g = el('div', 'group');
        var nm = el('span', 'nm', n.replace(/\.clanker$/, '')); nm.title = 'open its directory';
        nm.addEventListener('click', function () { go(dirUrl + '/' + encodeURIComponent(n), 'dir'); });
        g.appendChild(nm);
        var bundle = el('span', 'bundle', '');
        g.appendChild(bundle);
        list.appendChild(g);
        fetch(API + '/api/record?path=' + encodeURIComponent(proj), { cache: 'no-store' })
          .then(function (r) { return r.ok ? r.json() : null; })
          .then(function (rec) { if (rec && rec.record && rec.record.bundle) bundle.textContent = rec.record.bundle; })
          .catch(function () {});
        var holder = el('div');
        list.appendChild(holder);
        fetch(API + '/api/chats?path=' + encodeURIComponent(proj), { cache: 'no-store' })
          .then(function (r) { return r.ok ? r.json() : []; })
          .then(function (rows) {
            if (dead) return;
            holder.innerHTML = '';
            if (!rows.length) { holder.appendChild(el('div', 'nochat', 'no chats')); return; }
            rows.forEach(function (c) {
              var r = el('div', 'row');
              r.appendChild(el('span', 'dot' + (c.asking ? ' asking' : c.busy ? ' busy' : '')));
              r.appendChild(el('span', 'name', c.name));
              r.appendChild(el('span', 'last' + (c.last ? '' : ' none'), c.asking ? 'waiting for you: a tool asks to run' : (c.last || 'nothing said yet')));
              r.appendChild(el('span', 'count', c.events + (c.events === 1 ? ' event' : ' events')));
              r.title = c.asking ? 'a tool is waiting for your answer' : c.busy ? 'a turn is running' : 'open';
              r.addEventListener('click', function () { go(dirUrl + '/' + encodeURIComponent(n) + '/chats/' + encodeURIComponent(c.name) + '/log.chat-log', 'file'); });
              holder.appendChild(r);
            });
          })
          .catch(function () {});
      });
    }
    function load() {
      if (dead) return;
      return fetch(API + '/api/tree', { cache: 'no-store' })
        .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
        .then(function (tree) { if (!dead) render(tree); })
        .catch(function (e) { if (!dead) { list.innerHTML = ''; list.appendChild(el('div', 'err', 'the collection failed to load: ' + e.message)); } });
    }
    function create() {
      var name = nameEl.value.trim().toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, '');
      if (!name) { nameEl.focus(); return; }
      newBtn.disabled = true;
      fetch(API + '/api/new', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ kind: kindEl.value, parent: parent, name: name }) })
        .then(function (r) { if (!r.ok) throw new Error(r.status); nameEl.value = ''; return load(); })
        .catch(function (e) { list.insertBefore(el('div', 'err', 'could not make it: ' + e.message), list.firstChild); })
        .then(function () { newBtn.disabled = false; });
    }
    newBtn.addEventListener('click', create);
    nameEl.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); create(); } });
    load();
    timer = setInterval(load, 5000);
    return { destroy: destroy };
  }
  window.Viewers = window.Viewers || {};
  window.Viewers['chats'] = { label: 'Chats', mount: mount };
  window.Viewers['collection'] = { label: 'Clankers', mount: mountCollection };
})();
