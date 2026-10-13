// clanker panes: the collection selector, a clanker's chat list, and the
// record form. Each is a viewer the explorer mounts from +pick-viewer's
// answer: mount(root, {url, args, onNavigate}) -> {destroy, onUpdate}.
// Every pane draws from ONE request to the collection's api and redraws
// when the explorer's stream says what it follows moved. Nothing polls.
//
//   collection  the collection root or a category: its categories and
//               clankers, one row each, in a sidebar. args {parent}
//   chats       a clanker's chats/: one row per chat, in a sidebar. args {proj}
//   record      a clanker's config + standing prompt, or (args.chat) one
//               chat's own prompt, as a form. args {proj, chat?}
(function () {
  'use strict';
  var API = '/grubbery/clanker';
  var CSS_ID = 'clanker-panes-css';
  function css() {
    if (document.getElementById(CSS_ID)) return;
    var s = document.createElement('style'); s.id = CSS_ID;
    s.textContent =
      '.ck{height:100%;display:flex;flex-direction:column;min-height:0;font:13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#24292f;background:#fff}' +
      '.ck .mono{font:12px ui-monospace,SFMono-Regular,Menlo,monospace}' +
      '.ck-head{flex:none;display:flex;align-items:center;gap:6px;padding:8px 10px;border-bottom:1px solid #d0d7de;background:#f6f8fa}' +
      '.ck-head input,.ck-head select{font:inherit;min-width:0;padding:4px 7px;border:1px solid #d0d7de;border-radius:6px;background:#fff;color:#24292f}' +
      '.ck-head input{flex:1}.ck-head input:focus,.ck-head select:focus{outline:none;border-color:#0969da;box-shadow:0 0 0 2px rgba(9,105,218,.15)}' +
      '.ck-head button{flex:none;font:inherit;padding:4px 10px;border:1px solid #0969da;border-radius:6px;background:#0969da;color:#fff;cursor:pointer}' +
      '.ck-head button:disabled{opacity:.5;cursor:default}' +
      '.ck-list{flex:1;min-height:0;overflow:auto}' +
      '.ck-sec{padding:10px 12px 4px;font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.04em;color:#57606a}' +
      '.ck-row{display:flex;align-items:center;gap:8px;padding:7px 12px;cursor:pointer;border-bottom:1px solid #eaeef2;min-width:0}' +
      '.ck-row:hover{background:#f6f8fa}' +
      '.ck-row .dot{flex:none;width:7px;height:7px;border-radius:50%;background:#d0d7de}' +
      '.ck-row .dot.busy{background:#1a7f37;animation:ck-pulse 1.2s infinite both}.ck-row .dot.asking{background:#9a6700}' +
      '@keyframes ck-pulse{0%,100%{opacity:.35}50%{opacity:1}}' +
      '.ck-row .main{flex:1;min-width:0}' +
      '.ck-row .name{font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.ck-row .sub{color:#57606a;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;margin-top:1px}' +
      '.ck-row .sub.none{color:#8b949e;font-style:italic}' +
      '.ck-row .right{flex:none;color:#8b949e;font-size:11px;white-space:nowrap}' +
      '.ck-row.cat{padding-top:5px;padding-bottom:5px;border-bottom:none}.ck-row.cat .name{color:#57606a;font-weight:500}.ck-row.cat .name:after{content:"/"}' +
      '.ck-row.cat.in .name{color:#24292f;font-weight:600}' +
      '.ck-row .caret{flex:none;width:12px;color:#57606a;font-size:14px;line-height:1;text-align:center}' +
      '.ck-empty{padding:14px 12px;color:#8b949e}.ck-err{padding:10px 12px;color:#cf222e}' +
      '.ck-rec{flex:1;min-height:0;display:flex;flex-direction:column;padding:14px 18px;max-width:820px;box-sizing:border-box;width:100%}' +
      '.ck-rec h2{font-size:14px;font-weight:600;margin:0 0 2px}' +
      '.ck-rec .extra{color:#57606a;margin-bottom:12px;white-space:pre-wrap}' +
      '.ck-rec .grid{display:grid;grid-template-columns:1fr 140px;gap:10px;margin-bottom:10px}' +
      '.ck-rec label{display:flex;flex-direction:column;gap:3px;min-width:0}' +
      '.ck-rec label.grow{flex:1;min-height:0}' +
      '.ck-rec label span{font-size:12px;color:#57606a}' +
      '.ck-rec input,.ck-rec textarea{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;padding:5px 8px;border:1px solid #d0d7de;border-radius:6px;background:#fff;color:#24292f;min-width:0;box-sizing:border-box;width:100%}' +
      '.ck-rec textarea{flex:1;min-height:120px;resize:none;line-height:1.45}' +
      '.ck-rec input:focus,.ck-rec textarea:focus{outline:none;border-color:#0969da;box-shadow:0 0 0 2px rgba(9,105,218,.15)}' +
      '.ck-rec .foot{flex:none;display:flex;align-items:center;gap:10px;margin-top:10px}' +
      '.ck-rec .foot .note{color:#57606a;font-size:12px}' +
      '.ck-rec button{font:inherit;padding:5px 12px;border:1px solid #0969da;border-radius:6px;background:#0969da;color:#fff;cursor:pointer}.ck-rec button:disabled{opacity:.5;cursor:default}' +
      '.ck-def{display:flex;align-items:center;gap:10px;margin:4px 0 12px;color:#57606a;font-size:12px}' +
      '.ck-def select{font:inherit;padding:3px 6px;border:1px solid #d0d7de;border-radius:6px;background:#fff;color:#24292f}' +
      '.ck-tools{flex:1;min-height:0;overflow:auto;border:1px solid #d0d7de;border-radius:6px}' +
      '.ck-tool{display:flex;align-items:center;gap:12px;padding:5px 10px;border-bottom:1px solid #eaeef2;min-width:0}' +
      '.ck-tool:last-child{border-bottom:none}.ck-tool.head{background:#f6f8fa;font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.04em;color:#57606a}' +
      '.ck-tool .nm{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.ck-tool .v{flex:none;width:72px;font-size:12px;color:#57606a;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.ck-tool .v.deny{color:#cf222e}.ck-tool .v.ask{color:#9a6700}.ck-tool .v.allow{color:#1a7f37}' +
      '.ck-tool .opts{flex:none;display:flex;gap:0;width:232px}' +
      '.ck-tool.head .opts{display:block}' +
      '.ck-tool .pick{all:unset;cursor:pointer;flex:1;text-align:center;font-size:11px;padding:2px 0;border:1px solid #d0d7de;margin-left:-1px;color:#57606a;background:#fff}' +
      '.ck-tool .pick:first-child{border-radius:5px 0 0 5px;margin-left:0}.ck-tool .pick:last-child{border-radius:0 5px 5px 0}' +
      '.ck-tool .pick.on{background:#24292f;color:#fff;border-color:#24292f;position:relative}';
    document.head.appendChild(s);
  }
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
  function get(url) { return fetch(url, { cache: 'no-store' }).then(function (r) { if (!r.ok) throw new Error('' + r.status); return r.json(); }); }
  function post(path, body) { return fetch(API + path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) }).then(function (r) { if (!r.ok) throw new Error('' + r.status); return r; }); }
  function slug(s) { return s.trim().toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, ''); }
  function short(proj) { return proj.replace(/^.*\//, '').replace(/\.clanker$/, ''); }
  function dirOf(opts) { return (opts.url || '').replace(/\?.*$/, '').replace(/\/+$/, ''); }
  // a sidebar pane: head (what makes a new thing) over a list that one
  // loader fills; the stream's onUpdate re-runs the loader
  function sidebar(root, opts, load) {
    css();
    root.innerHTML = ''; root.classList.add('ck');
    var head = el('div', 'ck-head'), list = el('div', 'ck-list');
    root.appendChild(head); root.appendChild(list);
    var dead = false;
    function fail(msg) { list.innerHTML = ''; list.appendChild(el('div', 'ck-err', msg)); }
    function go(u, kind, name) { if (opts.onNavigate) opts.onNavigate(u, kind, name ? { name: name } : undefined); else location.href = u; }
    function reload() { if (!dead) load(list, fail).catch(function (e) { if (!dead) fail('failed to load: ' + e.message); }); }
    return {
      head: head, list: list, go: go, reload: reload,
      handle: { destroy: function () { dead = true; root.innerHTML = ''; root.classList.remove('ck'); }, onUpdate: reload }
    };
  }
  // one row: a status dot, a name over a subline, something small at the right
  function row(cls, dot, name, sub, right) {
    var r = el('div', 'ck-row' + (cls ? ' ' + cls : ''));
    if (dot !== null) r.appendChild(el('span', 'dot' + (dot ? ' ' + dot : '')));
    var main = el('div', 'main'); main.appendChild(el('div', 'name', name));
    if (sub != null) main.appendChild(el('div', 'sub' + (sub ? '' : ' none'), sub || 'nothing said yet'));
    r.appendChild(main);
    if (right) r.appendChild(el('span', 'right', right));
    return r;
  }
  function chatDot(c) { return c.asking ? 'asking' : c.busy ? 'busy' : ''; }

  // ---- collection: the whole collection as a tree ----
  // categories fold (closed ones remembered per browser), clankers are the
  // leaves; a clanker opens its layout, a category just folds. The head makes
  // a clanker or category IN the category last clicked (the root otherwise).
  function mountCollection(root, opts) {
    var parent = opts.args && typeof opts.args.parent === 'string' ? opts.args.parent : '/';
    var dir = dirOf(opts);
    var key = 'clanker-tree:' + dir, closed = {};
    try { closed = JSON.parse(localStorage.getItem(key) || '{}') || {}; } catch (_) { closed = {}; }
    function remember() { try { localStorage.setItem(key, JSON.stringify(closed)); } catch (_) {} }
    var into = parent, tree = null;
    function sub(p) { return p === '/' ? '' : p; }
    function count(node) { return (node.clankers || []).length + (node.categories || []).reduce(function (n, c) { return n + count(c); }, 0); }
    function plural(n, word) { return n + ' ' + word + (n === 1 ? '' : 's'); }
    // a clanker's state is its chats'; a category's is its clankers': asking
    // beats busy beats quiet, so the dot at every level says what is inside
    function dotOf(chats) { return chats.some(function (c) { return c.asking; }) ? 'asking' : chats.some(function (c) { return c.busy; }) ? 'busy' : ''; }
    function status(node) {
      var states = (node.clankers || []).map(function (k) { return dotOf(k.chats || []); }).concat((node.categories || []).map(status));
      return states.indexOf('asking') >= 0 ? 'asking' : states.indexOf('busy') >= 0 ? 'busy' : '';
    }
    function draw(node, path, depth, list) {
      var pad = 12 + depth * 14;
      (node.categories || []).forEach(function (c) {
        var p = sub(path) + '/' + c.name, open = !closed[p];
        var r = el('div', 'ck-row cat' + (p === into ? ' in' : ''));
        r.style.paddingLeft = pad + 'px';
        var st = status(c);
        r.appendChild(el('span', 'caret', open ? '▾' : '▸'));
        r.appendChild(el('span', 'dot' + (st ? ' ' + st : '')));
        var main = el('div', 'main'); main.appendChild(el('div', 'name', c.name)); r.appendChild(main);
        var n = count(c); if (n) r.appendChild(el('span', 'right', plural(n, 'clanker')));
        r.addEventListener('click', function () {
          if (into === p) { if (open) closed[p] = true; else delete closed[p]; remember(); }
          into = p; name.placeholder = 'new in ' + p.replace(/^\//, '') + '/…';
          render();
        });
        list.appendChild(r);
        if (open) draw(c, p, depth + 1, list);
      });
      (node.clankers || []).forEach(function (k) {
        var chats = k.chats || [];
        var r = row('', dotOf(chats), short(k.name), k.bundle || '', chats.length ? plural(chats.length, 'chat') : 'no chats');
        r.style.paddingLeft = (pad + 20) + 'px';   // its dot under the category's (past caret + gap)
        var u = dir + sub(path).split('/').map(encodeURIComponent).join('/') + '/' + encodeURIComponent(k.name);
        r.addEventListener('click', function () { sb.go(u, 'dir', short(k.name)); });
        list.appendChild(r);
      });
    }
    function render() {
      var list = sb.list; list.innerHTML = '';
      if (!tree) return;
      if (!count(tree) && !(tree.categories || []).length) { list.appendChild(el('div', 'ck-empty', 'No clankers yet. Name one above.')); return; }
      draw(tree, parent, 0, list);
    }
    var sb = sidebar(root, opts, function () {
      return get(API + '/api/collection?path=' + encodeURIComponent(parent)).then(function (c) { tree = c; render(); });
    });
    var kind = el('select'); ['clanker', 'category'].forEach(function (k) { var o = el('option', null, k); o.value = k; kind.appendChild(o); });
    var name = el('input'); name.placeholder = 'new…'; name.spellcheck = false;
    sb.head.appendChild(kind); sb.head.appendChild(name);
    function make() {
      var n = slug(name.value); if (!n) { name.focus(); return; }
      name.disabled = true;
      post('/api/new', { kind: kind.value, parent: into, name: n })
        .then(function () { name.value = ''; sb.reload(); }, function (e) { sb.list.insertBefore(el('div', 'ck-err', 'could not make it: ' + e.message), sb.list.firstChild); })
        .then(function () { name.disabled = false; });
    }
    name.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); make(); } });
    sb.reload();
    return sb.handle;
  }

  // ---- chats: one clanker's chats/ ----
  function mountChats(root, opts) {
    var proj = opts.args && typeof opts.args.proj === 'string' ? opts.args.proj : null;
    var dir = dirOf(opts);
    var sb = sidebar(root, opts, function (list) {
      if (!proj) { list.innerHTML = ''; list.appendChild(el('div', 'ck-err', 'no clanker here')); return Promise.resolve(); }
      return get(API + '/api/chats?path=' + encodeURIComponent(proj)).then(function (rows) {
        list.innerHTML = '';
        if (!rows.length) { list.appendChild(el('div', 'ck-empty', 'No chats yet. Name one above.')); return; }
        rows.forEach(function (c) {
          var r = row('', chatDot(c), c.name, c.asking ? 'waiting for you: a tool asks to run' : c.last, c.events ? c.events + (c.events === 1 ? ' event' : ' events') : '');
          r.addEventListener('click', function () { sb.go(dir + '/' + encodeURIComponent(c.name), 'dir', c.name); });
          list.appendChild(r);
        });
      });
    });
    var name = el('input'); name.placeholder = 'new chat…'; name.spellcheck = false;
    sb.head.appendChild(name);
    function make() {
      var n = slug(name.value); if (!n || !proj) { name.focus(); return; }
      name.disabled = true;
      post('/api/new', { kind: 'chat', parent: proj, name: n })
        .then(function () { name.value = ''; sb.go(dir + '/' + encodeURIComponent(n), 'dir', n); }, function (e) { sb.list.insertBefore(el('div', 'ck-err', 'could not make the chat: ' + e.message), sb.list.firstChild); })
        .then(function () { name.disabled = false; });
    }
    name.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); make(); } });
    sb.reload();
    return sb.handle;
  }

  // ---- record: config + standing prompt, or one chat's own prompt ----
  function mountRecord(root, opts) {
    css();
    var proj = opts.args && typeof opts.args.proj === 'string' ? opts.args.proj : null;
    var chat = opts.args && typeof opts.args.chat === 'string' ? opts.args.chat : null;
    root.innerHTML = ''; root.classList.add('ck');
    var dead = false, dirty = false;
    var handle = { destroy: function () { dead = true; root.innerHTML = ''; root.classList.remove('ck'); }, onUpdate: function () { load(); } };
    if (!proj) { root.appendChild(el('div', 'ck-err', 'no clanker here')); return handle; }
    var qs = '?path=' + encodeURIComponent(proj) + (chat ? '&chat=' + encodeURIComponent(chat) : '');
    var box = el('div', 'ck-rec');
    box.appendChild(el('h2', null, chat ? short(proj) + ' / ' + chat : short(proj)));
    var extra = el('div', 'extra mono', ''); box.appendChild(extra);
    var model = el('input'), max = el('input'); model.spellcheck = false; max.type = 'number'; max.min = '1';
    if (!chat) {
      var grid = el('div', 'grid');
      var l1 = el('label'); l1.appendChild(el('span', null, 'model')); l1.appendChild(model);
      var l2 = el('label'); l2.appendChild(el('span', null, 'max tokens')); l2.appendChild(max);
      grid.appendChild(l1); grid.appendChild(l2); box.appendChild(grid);
    }
    var sys = el('textarea'); sys.spellcheck = false;
    var l3 = el('label', 'grow'); l3.appendChild(el('span', null, chat ? 'this chat’s prompt, on top of ' + short(proj) + '’s' : 'standing prompt (system.md)')); l3.appendChild(sys); box.appendChild(l3);
    var foot = el('div', 'foot'), save = el('button', null, 'save'), note = el('span', 'note', '');
    foot.appendChild(save); foot.appendChild(note); box.appendChild(foot);
    root.appendChild(box);
    [model, max, sys].forEach(function (i) { i.addEventListener('input', function () { dirty = true; note.textContent = 'unsaved changes'; }); });
    var rec = null;
    function fill() {
      if (dirty || !rec) return;
      var r = rec.record || {};
      model.value = r.model || ''; max.value = r.max_tokens != null ? r.max_tokens : ''; sys.value = rec.system || '';
      var ks = Object.keys(r).filter(function (k) { return ['name', 'model', 'max_tokens'].indexOf(k) < 0; });
      extra.textContent = ks.map(function (k) { return k + ': ' + (typeof r[k] === 'string' ? r[k] : JSON.stringify(r[k])); }).join('\n');
    }
    function load() {
      if (dead) return;
      get(API + '/api/record' + qs).then(function (j) { if (!dead) { rec = j; fill(); } }, function (e) { if (!dead) note.textContent = 'could not load: ' + e.message; });
    }
    function doSave() {
      save.disabled = true; note.textContent = 'saving…';
      var body = chat ? { path: proj, chat: chat, system: sys.value } : { path: proj, model: model.value.trim(), system: sys.value };
      var mt = parseInt(max.value, 10); if (!chat && !isNaN(mt)) body.max_tokens = mt;
      post('/api/record', body)
        .then(function () { dirty = false; note.textContent = 'saved'; load(); }, function (e) { note.textContent = 'save failed: ' + e.message; })
        .then(function () { save.disabled = false; });
    }
    save.addEventListener('click', doSave);
    box.addEventListener('keydown', function (e) { if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); doSave(); } });
    load();
    return handle;
  }

  // ---- tools: the tool policy (tools.json), the clanker's or one chat's ----
  // One row per tool the clanker's tools nexus holds: its verdict here
  // (inherit the default, allow, ask, deny). A chat's policy sits over the
  // clanker's and can only tighten it, so a chat's rows also show the
  // clanker's verdict and what results. Follows both files; redraws from
  // the ship unless edited and unsaved.
  var VERDICTS = ['allow', 'ask', 'deny'];
  function parsePolicy(j) {
    if (!j || typeof j !== 'object') return null;
    var d = VERDICTS.indexOf(j['default']) >= 0 ? j['default'] : 'ask';
    var set = function (k) { return Array.isArray(j[k]) ? j[k].filter(function (x) { return typeof x === 'string'; }) : []; };
    return { 'default': d, allow: set('allow'), ask: set('ask'), deny: set('deny') };
  }
  var NO_POLICY = { 'default': 'allow', allow: [], ask: [], deny: [] };
  function verdict(p, n) { return p.deny.indexOf(n) >= 0 ? 'deny' : p.ask.indexOf(n) >= 0 ? 'ask' : p.allow.indexOf(n) >= 0 ? 'allow' : p['default']; }
  function stricter(a, b) { return VERDICTS.indexOf(a) >= VERDICTS.indexOf(b) ? a : b; }
  function mountTools(root, opts) {
    css();
    var proj = opts.args && typeof opts.args.proj === 'string' ? opts.args.proj : null;
    var chat = opts.args && typeof opts.args.chat === 'string' ? opts.args.chat : null;
    root.innerHTML = ''; root.classList.add('ck');
    var dead = false, dirty = false, data = null;
    var handle = { destroy: function () { dead = true; root.innerHTML = ''; root.classList.remove('ck'); }, onUpdate: function () { load(); } };
    if (!proj) { root.appendChild(el('div', 'ck-err', 'no clanker here')); return handle; }
    var qs = '?path=' + encodeURIComponent(proj) + (chat ? '&chat=' + encodeURIComponent(chat) : '');
    var box = el('div', 'ck-rec');
    box.appendChild(el('h2', null, (chat ? short(proj) + ' / ' + chat : short(proj)) + ' · tools'));
    box.appendChild(el('div', 'extra', chat
      ? 'What this chat may do with ' + short(proj) + '’s tools. It can only tighten the clanker’s policy: the stricter verdict wins.'
      : 'deny: the model never sees the tool · ask: the turn pauses for you before it runs · allow: it runs as called.'));
    var defRow = el('div', 'ck-def');
    defRow.appendChild(el('span', null, 'tools not listed below'));
    var defSel = el('select'); VERDICTS.forEach(function (v) { var o = el('option', null, v); o.value = v; defSel.appendChild(o); });
    defRow.appendChild(defSel); box.appendChild(defRow);
    var table = el('div', 'ck-tools'); box.appendChild(table);
    var foot = el('div', 'foot'), save = el('button', null, 'save'), note = el('span', 'note', '');
    foot.appendChild(save); foot.appendChild(note); box.appendChild(foot);
    root.appendChild(box);
    var choice = {};   // tool -> '' (inherit) | allow | ask | deny
    function markDirty() { dirty = true; note.textContent = 'unsaved changes'; refreshEffective(); }
    defSel.addEventListener('change', markDirty);
    var rows = {};
    function draw() {
      table.innerHTML = ''; rows = {};
      var own = parsePolicy(chat ? data.own : data.clanker) || NO_POLICY;
      var base = chat ? (parsePolicy(data.clanker) || NO_POLICY) : null;
      defSel.value = own['default'];
      var head = el('div', 'ck-tool head');
      head.appendChild(el('span', 'nm', 'tool'));
      if (base) head.appendChild(el('span', 'v', short(proj)));
      head.appendChild(el('span', 'opts', chat ? 'this chat' : 'verdict'));
      if (base) head.appendChild(el('span', 'v', 'result'));
      table.appendChild(head);
      (data.tools || []).forEach(function (n) {
        var r = el('div', 'ck-tool');
        r.appendChild(el('span', 'nm mono', n));
        if (base) r.appendChild(el('span', 'v ' + verdict(base, n), verdict(base, n)));
        var o = el('span', 'opts');
        var cur = own.deny.indexOf(n) >= 0 ? 'deny' : own.ask.indexOf(n) >= 0 ? 'ask' : own.allow.indexOf(n) >= 0 ? 'allow' : '';
        choice[n] = cur;
        [''].concat(VERDICTS).forEach(function (v) {
          var b = el('button', 'pick' + (v === cur ? ' on' : ''), v || 'default'); b.type = 'button';
          b.addEventListener('click', function () { choice[n] = v; o.querySelectorAll('.pick').forEach(function (x) { x.classList.toggle('on', x === b); }); markDirty(); });
          o.appendChild(b);
        });
        r.appendChild(o);
        if (base) r.appendChild(el('span', 'v eff'));
        table.appendChild(r); rows[n] = r;
      });
      refreshEffective();
    }
    // the verdict each row ends with, as the ship would compute it
    function refreshEffective() {
      var p = policy();
      var base = chat ? (parsePolicy(data && data.clanker) || NO_POLICY) : null;
      Object.keys(rows).forEach(function (n) {
        var v = verdict(p, n), e = base ? stricter(verdict(base, n), v) : v;
        var eff = rows[n].querySelector('.eff');
        if (eff) { eff.textContent = e; eff.className = 'v eff ' + e; }
      });
    }
    function policy() {
      var p = { 'default': defSel.value, allow: [], ask: [], deny: [] };
      Object.keys(choice).forEach(function (n) { if (choice[n]) p[choice[n]].push(n); });
      return p;
    }
    function load() {
      if (dead) return;
      get(API + '/api/tools' + qs).then(function (j) { if (dead) return; data = j; if (!dirty) draw(); else refreshEffective(); }, function (e) { if (!dead) note.textContent = 'could not load: ' + e.message; });
    }
    save.addEventListener('click', function () {
      save.disabled = true; note.textContent = 'saving…';
      post('/api/tools', { path: proj, chat: chat || '', policy: policy() })
        .then(function () { dirty = false; note.textContent = 'saved'; load(); }, function (e) { note.textContent = 'save failed: ' + e.message; })
        .then(function () { save.disabled = false; });
    });
    load();
    return handle;
  }

  window.Viewers = window.Viewers || {};
  window.Viewers['tools'] = { label: 'Tools', mount: mountTools };
  window.Viewers['collection'] = { label: 'Clankers', mount: mountCollection };
  window.Viewers['chats'] = { label: 'Chats', mount: mountChats };
  window.Viewers['record'] = { label: 'Record', mount: mountRecord };
})();
