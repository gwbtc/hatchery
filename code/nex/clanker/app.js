// clanker: a collection of clankers. The tree on the left is the whole
// collection, every file of every clanker included; tab 0 shows whatever
// the tree selected (the root, a category, a clanker's page, a plain dir);
// a chat opens as a chat tab, any other file as a FileView tab on the
// kernel's file API. Nothing here holds chat state: every render is a
// fold over what the ship has.
(function () {
  'use strict';
  var BASE = '/grubbery/clanker';
  var $ = function (id) { return document.getElementById(id); };
  var tree = $('tree'), tabs = $('tabs'), home = $('home'), ctx = $('ctx'), statusEl = $('status'), loadBar = $('load-bar');
  var ROOT = '';            // this instance's absolute root (/api/root)
  var TREE = { dirs: {}, files: [] };
  var homePath = '/';
  var panes = {};           // tab key -> pane (chat or file)
  var inflight = 0;

  // ── helpers ──
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function track(p) {
    inflight++; loadBar.classList.add('active');
    return p.finally(function () { if (--inflight <= 0) { inflight = 0; loadBar.classList.remove('active'); } });
  }
  function api(path, opts) { return track(fetch(BASE + path, Object.assign({ cache: 'no-store' }, opts || {}))); }
  function post(path, body) { return api(path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) }); }
  function isClanker(name) { return /\.clanker$/.test(name); }
  function short(name) { return name.replace(/\.clanker$/, ''); }
  function join(dir, name) { return dir === '/' ? '/' + name : dir + '/' + name; }
  function parentOf(path) { var i = path.lastIndexOf('/'); return i <= 0 ? '/' : path.slice(0, i); }
  function baseOf(path) { return path.slice(path.lastIndexOf('/') + 1); }
  function segs(path) { return path.split('/').filter(Boolean); }
  function nodeAt(path) {
    var node = TREE, ss = segs(path);
    for (var i = 0; i < ss.length; i++) {
      node = (node.dirs || {})[ss[i]];
      if (!node) return null;
    }
    return node;
  }
  // the clanker a path belongs to (itself or the nearest ancestor), or null
  function clankerOf(path) {
    var ss = segs(path);
    for (var i = ss.length - 1; i >= 0; i--) if (isClanker(ss[i])) return '/' + ss.slice(0, i + 1).join('/');
    return null;
  }
  // what a dir is: root | category | clanker | chat | dir (inside a clanker)
  function kindOf(path) {
    if (path === '/') return 'root';
    var ss = segs(path), last = ss[ss.length - 1];
    if (isClanker(last)) return 'clanker';
    if (ss.length >= 3 && ss[ss.length - 2] === 'chats' && isClanker(ss[ss.length - 3])) return 'chat';
    return clankerOf(path) ? 'dir' : 'category';
  }
  // the namespace path of a tree path: a clanker's tools/ is folded in
  // the listing (tools/x.hoon is tools/code/lib/tools/x.hoon); its runs/
  // is where it really is
  function realPath(path) {
    var ss = segs(path);
    var out = [];
    for (var i = 0; i < ss.length; i++) {
      out.push(ss[i]);
      if (ss[i] === 'tools' && i > 0 && isClanker(ss[i - 1]) && i < ss.length - 1 && ss[i + 1] !== 'runs') out.push('code', 'lib', 'tools');
    }
    return '/' + out.join('/');
  }
  // a run's summary {tool, step, arg} if this file is a tool run
  function runOf(path) {
    var node = nodeAt(parentOf(path));
    return node && node.runs ? node.runs[baseOf(path)] || null : null;
  }
  function isToolsDir(path) { var ss = segs(path); return ss.length >= 2 && ss[ss.length - 1] === 'tools' && isClanker(ss[ss.length - 2]); }
  function fileUrl(path) { return '/grubbery/ball' + ROOT + '/projects' + realPath(path); }
  function icon(path) {
    var s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    s.setAttribute('viewBox', '0 0 24 24'); s.setAttribute('fill', 'none');
    s.setAttribute('stroke', 'currentColor'); s.setAttribute('stroke-width', '2');
    s.setAttribute('stroke-linecap', 'round'); s.setAttribute('stroke-linejoin', 'round');
    s.setAttribute('class', 'ico');
    s.innerHTML = path;
    return s;
  }
  var ICO_TOOL = '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>';
  var ICO_SEND = '<line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>';

  // ── the tree ──
  function getChildren(path) {
    var node = nodeAt(path);
    if (!node) return [];
    var items = [];
    Object.keys(node.dirs || {}).forEach(function (n) {
      var p = join(path, n);
      items.push({ name: n, isDir: true, kind: kindOf(p), path: p });
    });
    var files = (node.files || []).slice();
    if (node.runs) files.reverse();   // runs: newest first
    files.forEach(function (n) {
      var run = node.runs ? node.runs[n] || null : null;
      items.push({ name: n, isDir: false, kind: run ? 'run' : 'file', path: join(path, n), run: run });
    });
    return items;
  }
  tree.root = '/';
  tree.persistKey = 'clanker-tree';
  tree.getChildren = getChildren;
  tree.onOpenDir = function (item, path) {
    if (item.kind === 'chat') openChat(clankerOf(path), baseOf(path));
    else showHome(path);
  };
  tree.onOpenFile = function (item, path) {
    var k = kindOf(parentOf(path));
    if (k === 'chat' && item.name === 'log.json') openChat(clankerOf(path), baseOf(parentOf(path)));
    else openFile(path);
  };
  tree.decorateRow = function (row, item, path, isDir) {
    row.__item = item;
    var name = row.querySelector('.name');
    if (isDir && item.kind === 'clanker') {
      if (name) name.textContent = short(item.name);
      row.appendChild(el('span', 'row-kind', 'clanker'));
    } else if (isDir && item.kind === 'chat') {
      if (name) name.textContent = item.name;
      row.appendChild(el('span', 'row-kind', 'chat'));
    } else if (isDir && isToolsDir(path)) {
      row.appendChild(el('span', 'row-kind', 'nexus'));
    } else if (!isDir && item.run) {
      // a tool run: the tool it ran, how it ended; the id is the title
      if (name) { name.textContent = item.run.tool; name.title = item.name + (item.run.arg ? ' · ' + item.run.arg : ''); }
      row.appendChild(el('span', 'row-kind' + (item.run.step === 'error' ? ' err' : item.run.step === 'done' ? '' : ' live'), item.run.step));
    }
  };
  var treeText = '';
  function loadTree() {
    return api('/api/tree').then(function (r) { return r.text(); }).then(function (text) {
      if (text === treeText) return;
      treeText = text;
      TREE = JSON.parse(text);
      tree.render(getChildren('/'));
      updateTreeToggle();
    });
  }
  function updateTreeToggle() { $('tree-toggle').textContent = tree.anyOpen ? 'collapse all' : 'expand all'; }
  $('tree-toggle').addEventListener('click', function () {
    (tree.anyOpen ? tree.collapseAll() : tree.expandAll());
    setTimeout(updateTreeToggle, 0);
  });

  // ── tab 0: the collection view ──
  function showHome(path, select) {
    homePath = path;
    home.setAttribute('tab-label', path === '/' ? '/' : short(baseOf(path)));
    home.setAttribute('tab-title', path);
    tabs.refresh();
    if (select !== false) tabs.select(0);
    renderHome();
  }
  function renderHome() {
    var node = nodeAt(homePath);
    home.innerHTML = '';
    if (!node) { home.appendChild(el('div', 'empty', 'gone')); return; }
    var k = kindOf(homePath);
    if (k === 'clanker') return renderClanker(homePath, node);
    renderDir(homePath, node, k);
  }
  function crumbs(path) {
    var h = el('div', 'hv-path');
    var a = el('a', null, 'clankers'); a.href = '#'; a.onclick = function (e) { e.preventDefault(); showHome('/'); };
    h.appendChild(a);
    var acc = '';
    segs(path).forEach(function (seg) {
      acc += '/' + seg;
      h.appendChild(document.createTextNode(' / '));
      var s = el('a', null, short(seg)); s.href = '#';
      (function (p) { s.onclick = function (e) { e.preventDefault(); showHome(p); }; })(acc);
      h.appendChild(s);
    });
    return h;
  }
  function listing(path, node, opts) {
    var sec = el('div', 'sec');
    sec.appendChild(el('div', 'sec-head', opts.title));
    var dirs = Object.keys(node.dirs || {}).sort(), files = (node.files || []).slice().sort();
    if (!dirs.length && !files.length) { sec.appendChild(el('div', 'empty', opts.empty || 'nothing here yet')); return sec; }
    var t = el('table', 'list');
    dirs.forEach(function (n) {
      var p = join(path, n), k = kindOf(p), kid = node.dirs[n];
      var tr = el('tr');
      var td = el('td'); var a = el('a', null, short(n)); a.href = '#';
      a.onclick = function (e) { e.preventDefault(); if (k === 'chat') openChat(clankerOf(p), n); else showHome(p); };
      td.appendChild(a); tr.appendChild(td);
      var count = k === 'clanker' ? Object.keys((kid.dirs || {}).chats ? kid.dirs.chats.dirs || {} : {}).length + ' chats'
        : Object.keys(kid.dirs || {}).length + (kid.files || []).length + ' inside';
      tr.appendChild(el('td', 'mono', count));
      var kt = el('td'); kt.appendChild(el('span', 'chip', k)); tr.appendChild(kt);
      var act = el('td', 'act');
      if (k !== 'dir') {
        var del = el('button', 'hdr-btn danger', 'delete');
        del.onclick = function () { if (confirm('Delete ' + n + ' and everything in it?')) removeNode(p); };
        act.appendChild(del);
      }
      tr.appendChild(act);
      t.appendChild(tr);
    });
    if (node.runs) files.reverse();   // runs: newest first
    files.forEach(function (n) {
      var p = join(path, n), run = node.runs ? node.runs[n] : null;
      var tr = el('tr');
      var td = el('td'); var a = el('a', null, run ? run.tool : n); a.href = '#'; a.title = n;
      a.onclick = function (e) { e.preventDefault(); openFile(p); };
      td.appendChild(a); tr.appendChild(td);
      tr.appendChild(el('td', 'mono', run ? run.arg || '' : ''));
      var kt = el('td'); kt.appendChild(el('span', 'chip' + (run && run.step === 'error' ? ' err' : ''), run ? run.step : 'file')); tr.appendChild(kt);
      tr.appendChild(el('td', 'act'));
      t.appendChild(tr);
    });
    sec.appendChild(t);
    return sec;
  }
  function renderDir(path, node, kind) {
    var v = el('div', 'hv');
    var head = el('div', 'hv-head');
    head.appendChild(el('h1', null, path === '/' ? 'clankers' : baseOf(path)));
    head.appendChild(crumbs(path));
    v.appendChild(head);
    v.appendChild(el('div', 'hv-sub', kind === 'root' ? 'The collection. A clanker is a scoped chat agent; a category just holds clankers.'
      : kind === 'category' ? 'A category.' : 'A directory inside ' + short(baseOf(clankerOf(path))) + '.'));
    v.appendChild(listing(path, node, { title: 'contents' }));
    if (kind === 'root' || kind === 'category') {
      var mk = el('div', 'sec');
      mk.appendChild(el('div', 'sec-head', 'new'));
      mk.appendChild(newRow('new clanker', 'clanker', path));
      mk.appendChild(newRow('new category', 'category', path));
      v.appendChild(mk);
    }
    home.appendChild(v);
  }
  function newRow(label, kind, parent) {
    var row = el('div', 'newrow');
    var inp = el('input'); inp.placeholder = kind + ' name'; inp.spellcheck = false;
    var btn = el('button', 'hdr-btn primary', label);
    var go = function () {
      var name = inp.value.trim();
      if (!name) return;
      post('/api/new', { kind: kind, parent: parent, name: name }).then(function (r) {
        if (!r.ok) return r.text().then(alert);
        inp.value = '';
        return loadTree().then(function () {
          if (kind === 'chat') { renderHome(); openChat(parent, name); }
          else showHome(kind === 'clanker' ? join(parent, name + '.clanker') : parent);
        });
      });
    };
    btn.onclick = go;
    inp.addEventListener('keydown', function (e) { if (e.key === 'Enter') go(); });
    row.appendChild(inp); row.appendChild(btn);
    return row;
  }
  function renderClanker(path, node) {
    var v = el('div', 'hv');
    var head = el('div', 'hv-head');
    head.appendChild(el('h1', null, short(baseOf(path))));
    head.appendChild(crumbs(path));
    v.appendChild(head);
    v.appendChild(el('div', 'hv-sub', 'A clanker: its standing prompt, memories, skills, tools, and chats, all files in its own directory.'));
    home.appendChild(v);
    var d = node.dirs || {};
    // chats
    var chats = d.chats ? Object.keys(d.chats.dirs || {}).sort() : [];
    var cs = el('div', 'sec');
    cs.appendChild(el('div', 'sec-head', 'chats'));
    if (!chats.length) cs.appendChild(el('div', 'empty', 'no chats yet'));
    else {
      var t = el('table', 'list');
      chats.forEach(function (c) {
        var cp = path + '/chats/' + c, sub = Object.keys(d.chats.dirs[c].dirs || {}).filter(isClanker);
        var tr = el('tr');
        var td = el('td'); var a = el('a', null, c); a.href = '#';
        a.onclick = function (e) { e.preventDefault(); openChat(path, c); };
        td.appendChild(a); tr.appendChild(td);
        tr.appendChild(el('td', 'mono', sub.length ? sub.length + ' nested' : ''));
        var kt = el('td'); kt.appendChild(el('span', 'chip', 'chat')); tr.appendChild(kt);
        var act = el('td', 'act');
        var del = el('button', 'hdr-btn danger', 'delete');
        del.onclick = function () { if (confirm('Delete chat ' + c + '?')) removeChat(path, c); };
        act.appendChild(del); tr.appendChild(act);
        t.appendChild(tr);
      });
      cs.appendChild(t);
    }
    cs.appendChild(newRow('new chat', 'chat', path));
    v.appendChild(cs);
    // the standing context: files
    ['skills', 'memories', 'tools'].forEach(function (sec) {
      if (d[sec]) v.appendChild(listing(path + '/' + sec, d[sec], { title: sec, empty: 'none yet' }));
    });
    // tool runs, newest first: what ran and how it ended
    var runs = d.tools && d.tools.dirs && d.tools.dirs.runs;
    if (runs) v.appendChild(listing(path + '/tools/runs', runs, { title: 'tool runs', empty: 'no runs yet' }));
    // the record
    api('/api/record?path=' + encodeURIComponent(path)).then(function (r) { return r.json(); }).then(function (doc) {
      if (homePath !== path) return;
      var rec = doc.record || {};
      var rs = el('div', 'sec');
      rs.appendChild(el('div', 'sec-head', 'record'));
      var sys = field('system prompt (system.md)', 'textarea', doc.system || '');
      var row = el('div', 'field-row');
      var model = field('model', 'input', rec.model || '');
      var max = field('max tokens', 'input', rec.max_tokens != null ? String(rec.max_tokens) : '');
      var bundle = field('tool bundle', 'input', rec.bundle || 'default', 'default, or kernel for the grubbery self-editing set; set at creation');
      bundle.input.readOnly = true;
      row.appendChild(model.wrap); row.appendChild(max.wrap); row.appendChild(bundle.wrap);
      rs.appendChild(sys.wrap); rs.appendChild(row);
      var foot = el('div', 'rec-foot');
      var save = el('button', 'hdr-btn primary', 'save record');
      save.onclick = function () {
        post('/api/record', { path: path, system: sys.input.value, model: model.input.value, max_tokens: Number(max.input.value) || 4096 })
          .then(function (r) { save.textContent = r.ok ? 'saved' : 'failed'; setTimeout(function () { save.textContent = 'save record'; }, 1200); });
      };
      foot.appendChild(save);
      rs.appendChild(foot);
      v.appendChild(rs);
    });
  }
  function field(label, kind, value, hint) {
    var wrap = el('div', 'field');
    wrap.appendChild(el('label', null, label));
    var input = el(kind === 'textarea' ? 'textarea' : 'input');
    input.value = value; input.spellcheck = false;
    wrap.appendChild(input);
    if (hint) wrap.appendChild(el('span', 'hint', hint));
    return { wrap: wrap, input: input };
  }
  function removeNode(path) {
    post('/api/delete', { path: path }).then(function () {
      Object.keys(panes).forEach(function (k) { if (k.indexOf(path + '#') === 0 || k.indexOf(path + '/') === 0 || k.indexOf('file:' + path + '/') === 0) closePane(k); });
      return loadTree();
    }).then(function () { showHome(parentOf(path)); });
  }
  function removeChat(path, chat) {
    post('/api/delete', { path: path, chat: chat }).then(function () {
      closePane(path + '#' + chat);
      return loadTree();
    }).then(renderHome);
  }

  // ── chat tabs ──
  function ChatPane(path, chat) {
    this.path = path; this.chat = chat; this.key = path + '#' + chat;
    this.lastLen = -1; this.busy = false; this.timer = null;
    var panel = el('div', 'pane');
    panel.setAttribute('tab-label', chat);
    panel.setAttribute('tab-title', short(path) + ' · ' + chat);
    panel.__pane = this;
    this.panel = panel;
    this.logEl = el('div', 'log'); this.threadEl = el('div', 'thread'); this.logEl.appendChild(this.threadEl);
    panel.appendChild(this.logEl);
    var form = el('form', 'compose');
    var inner = el('div', 'compose-inner');
    this.msgEl = el('textarea'); this.msgEl.rows = 1; this.msgEl.placeholder = 'Message ' + short(baseOf(path)) + '…'; this.msgEl.spellcheck = false;
    this.stopBtn = el('button', 'hdr-btn danger stop', 'stop'); this.stopBtn.type = 'button'; this.stopBtn.disabled = true;
    this.sendBtn = el('button', 'send'); this.sendBtn.type = 'submit'; this.sendBtn.title = 'send (⌘↩)';
    this.sendBtn.appendChild(icon(ICO_SEND));
    inner.appendChild(this.msgEl); inner.appendChild(this.stopBtn); inner.appendChild(this.sendBtn);
    form.appendChild(inner);
    var hint = el('div', 'hint'); hint.appendChild(el('span', null, '⌘↩ to send')); hint.appendChild(el('span', null, 'the transcript is the stored event log'));
    form.appendChild(hint);
    panel.appendChild(form);
    var self = this;
    form.addEventListener('submit', function (e) { e.preventDefault(); self.send(); });
    this.stopBtn.addEventListener('click', function () { post('/api/stop', { path: self.path }).then(function () { setTimeout(function () { self.load(); }, 600); }); });
    this.msgEl.addEventListener('input', function () { self.autosize(); });
    this.msgEl.addEventListener('keydown', function (e) { if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); self.send(); } });
  }
  ChatPane.prototype.autosize = function () { this.msgEl.style.height = 'auto'; this.msgEl.style.height = Math.min(this.msgEl.scrollHeight, 200) + 'px'; };
  ChatPane.prototype.send = function () {
    var text = this.msgEl.value.trim(), self = this;
    if (!text || this.busy) return;
    this.msgEl.value = ''; this.autosize();
    post('/api/send', { path: this.path, chat: this.chat, message: text }).then(function () { self.setBusy(true); self.load(); });
  };
  ChatPane.prototype.load = function () {
    var self = this;
    return api('/api/log?path=' + encodeURIComponent(this.path) + '&chat=' + encodeURIComponent(this.chat))
      .then(function (r) { return r.json(); })
      .then(function (log) {
        if (log.length !== self.lastLen) { self.lastLen = log.length; self.render(log); }
        var last = log[log.length - 1];
        var wasBusy = self.busy;
        self.setBusy(!!last && (last.k === 'input' || last.k === 'results' || (last.k === 'response' && last.stop === 'tool_use')));
        // while a turn runs its tool runs appear under tools/runs; when
        // it finishes it may have spawned a clanker or written a memory.
        // loadTree only re-renders when the tree text changed.
        if (self.busy || wasBusy) loadTree();
      })
      .catch(function () {});
  };
  ChatPane.prototype.setBusy = function (b) {
    var self = this;
    this.busy = b;
    this.sendBtn.disabled = b; this.stopBtn.disabled = !b;
    if (b && !this.timer) this.timer = setInterval(function () { self.load(); }, 1500);
    if (!b && this.timer) { clearInterval(this.timer); this.timer = null; }
    updateStatus();
  };
  ChatPane.prototype.render = function (log) {
    var threadEl = this.threadEl, self = this;
    threadEl.innerHTML = '';
    if (!log.length) {
      var e = el('div', 'empty');
      e.innerHTML = 'A new chat with <b>' + short(baseOf(this.path)) + '</b>. Every turn is appended to its event log and the request is assembled from it.';
      threadEl.appendChild(e);
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
            pending.el.appendChild(step(use, res || null, (ev.trace || [])[i], self.path, self.chat));
          });
          pending = null;
        }
      } else threadEl.appendChild(el('div', 'err', JSON.stringify(ev)));
    });
    var last = log[log.length - 1];
    if (last.k === 'input' || last.k === 'results' || (last.k === 'response' && last.stop === 'tool_use')) {
      var t = el('div', 'msg bot'), ty = el('div', 'typing');
      ty.appendChild(el('span')); ty.appendChild(el('span')); ty.appendChild(el('span'));
      t.appendChild(ty); threadEl.appendChild(t);
    }
    self.logEl.scrollTop = self.logEl.scrollHeight;
  };
  function step(use, result, trace, path, chat) {
    var d = el('details', 'step'), s = el('summary');
    s.appendChild(icon(ICO_TOOL));
    s.appendChild(el('span', 'tool', use.name));
    if (trace && trace.arg) s.appendChild(el('span', 'arg', trace.arg));
    // a spawn is a nested clanker beneath this chat: link to its page
    if (use.name === 'spawn' && use.input && use.input.name && path) {
      var lnk = el('a', 'arg', 'open ' + use.input.name + ' →'); lnk.href = '#';
      lnk.onclick = function (e) { e.preventDefault(); e.stopPropagation(); showHome(path + '/chats/' + chat + '/' + use.input.name + '.clanker'); };
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
  function updateStatus() {
    var busy = Object.keys(panes).filter(function (k) { return panes[k].busy; }).length;
    statusEl.innerHTML = '';
    if (busy) { statusEl.appendChild(el('span', 'dot')); statusEl.appendChild(el('span', null, busy === 1 ? 'thinking' : busy + ' thinking')); }
  }

  // ── file tabs: the kernel's FileView on the clanker's own grubs ──
  function FilePane(path) {
    this.path = path; this.key = 'file:' + path; this.busy = false;
    var panel = el('div', 'pane file');
    panel.setAttribute('tab-label', baseOf(path));
    panel.setAttribute('tab-title', path);
    panel.__pane = this;
    this.panel = panel;
    var mount = el('div', 'fv-mount');
    panel.appendChild(mount);
    this.view = window.FileView ? FileView.mount(mount, { url: fileUrl(path), wrapKey: 'clanker-wrap', crumbBase: '/grubbery/ball' + ROOT + '/projects' }) : null;
  }
  FilePane.prototype.load = function () {};
  function openFile(path) {
    var key = 'file:' + path;
    var pane = panes[key];
    if (!pane) {
      pane = panes[key] = new FilePane(path);
      tabs.appendChild(pane.panel);
      saveTabs();
    }
    selectPane(pane, path);
  }
  function openChat(path, chat) {
    var key = path + '#' + chat;
    var pane = panes[key];
    if (!pane) {
      pane = panes[key] = new ChatPane(path, chat);
      tabs.appendChild(pane.panel);
      pane.load();
      saveTabs();
    }
    selectPane(pane, path + '/chats/' + chat + '/log.json');
  }
  function selectPane(pane, treePath) {
    // select after the slotchange rebuild has settled
    Promise.resolve().then(function () {
      var i = tabPanels().indexOf(pane.panel);
      if (i >= 0) tabs.select(i);
      tree.markActive(treePath);
    });
  }
  function closePane(key) {
    var pane = panes[key];
    if (!pane) return;
    if (pane.timer) clearInterval(pane.timer);
    if (pane.view && pane.view.destroy) pane.view.destroy();
    pane.panel.remove();
    delete panes[key];
    saveTabs(); updateStatus();
  }
  function tabPanels() { return Array.from(tabs.children).filter(function (c) { return c.hasAttribute('tab-label'); }); }
  tabs.addEventListener('tg-close', function (e) {
    var p = e.detail.panel;
    if (p.__pane) closePane(p.__pane.key);
    Promise.resolve().then(function () { tabs.select(0); });
  });
  tabs.addEventListener('tg-change', function (e) {
    var p = tabPanels()[e.detail.index];
    if (p && p.__pane) {
      p.__pane.load();
      tree.markActive(p.__pane.chat ? p.__pane.path + '/chats/' + p.__pane.chat + '/log.json' : p.__pane.path);
    } else tree.markActive(null);
  });
  function saveTabs() {
    try { localStorage.setItem('clanker-tabs', JSON.stringify(Object.keys(panes))); } catch (_) {}
  }
  function restoreTabs() {
    var keys = [];
    try { keys = JSON.parse(localStorage.getItem('clanker-tabs')) || []; } catch (_) {}
    keys.forEach(function (k) {
      if (k.indexOf('file:') === 0) { if (nodeAt(parentOf(k.slice(5)))) openFile(k.slice(5)); return; }
      var i = k.indexOf('#');
      if (i > 0 && nodeAt(k.slice(0, i))) openChat(k.slice(0, i), k.slice(i + 1));
    });
    Promise.resolve().then(function () { tabs.select(0); });
  }

  // ── right-click ──
  document.addEventListener('contextmenu', function (e) {
    var row = e.composedPath().find(function (x) { return x && x.__item; });
    var inTree = e.composedPath().indexOf(tree) >= 0;
    if (!row && !inTree) return;
    e.preventDefault();
    var item = row ? row.__item : { kind: 'root', path: '/', name: '' };
    var items = [];
    var add = function (label, fn, danger) { items.push({ label: label, fn: fn, danger: danger }); };
    var k = item.kind;
    if (k === 'chat') {
      add('open', function () { openChat(clankerOf(item.path), item.name); });
      add('delete chat', function () { if (confirm('Delete chat ' + item.name + '?')) removeChat(clankerOf(item.path), item.name); }, true);
    } else if (k === 'file') {
      add('open', function () { openFile(item.path); });
    } else if (k === 'clanker') {
      add('open', function () { showHome(item.path); });
      add('new chat', function () { var n = prompt('chat name'); if (n) post('/api/new', { kind: 'chat', parent: item.path, name: n.trim() }).then(loadTree).then(function () { openChat(item.path, n.trim()); }); });
      add('delete clanker', function () { if (confirm('Delete ' + item.name + ' and all its chats?')) removeNode(item.path); }, true);
    } else if (k === 'dir') {
      add('open', function () { showHome(item.path); });
    } else {
      if (k !== 'root') add('open', function () { showHome(item.path); });
      add('new clanker', function () { var n = prompt('clanker name'); if (n) post('/api/new', { kind: 'clanker', parent: item.path, name: n.trim() }).then(loadTree).then(function () { showHome(join(item.path, n.trim() + '.clanker')); }); });
      add('new category', function () { var n = prompt('category name'); if (n) post('/api/new', { kind: 'category', parent: item.path, name: n.trim() }).then(loadTree).then(function () { showHome(item.path); }); });
      if (k !== 'root') add('delete category', function () { if (confirm('Delete ' + item.name + ' and everything in it?')) removeNode(item.path); }, true);
    }
    Array.from(ctx.children).forEach(function (c) { if (!c.hasAttribute('slot')) c.remove(); });
    items.forEach(function (it) {
      var b = el('button', 'rm-item' + (it.danger ? ' danger' : ''), it.label);
      b.type = 'button';
      b.addEventListener('click', function () { ctx.close(); it.fn(); });
      ctx.appendChild(b);
    });
    ctx.style.left = e.clientX + 'px'; ctx.style.top = e.clientY + 'px'; ctx.style.display = '';
    ctx.open();
  });
  ctx.addEventListener('dm-close', function () { ctx.style.display = 'none'; });

  // ── boot ──
  api('/api/root').then(function (r) { return r.json(); }).then(function (j) { ROOT = j.root || ''; })
    .catch(function () {})
    .then(loadTree)
    .then(function () {
      showHome('/', false);
      restoreTabs();
    });
})();
