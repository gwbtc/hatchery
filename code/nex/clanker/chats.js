// clanker panes: the collection selector, a clanker's chat list, and the
// record form. Each is a viewer the explorer mounts from +pick-viewer's
// answer: mount(root, {url, args, onNavigate}) -> {destroy, onUpdate}.
// Every pane draws from ONE request to the collection's api and redraws
// when the explorer's stream says what it follows moved. Nothing polls.
//
//   collection  the collection root or a category: its categories and
//               clankers, one row each, in a sidebar. args {parent}
//   chats       a clanker's chats/: one row per chat, in a sidebar. args {proj}
//   record      a clanker's standing prompt, or (args.chat) one chat's
//               own prompt, as a form. args {proj, chat?}
//   config      which endpoint answers a clanker and with which model,
//               as a form over the provider registry. args {proj}
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
      '.ck-row.empty{cursor:default;border-bottom:none;padding-top:4px;padding-bottom:4px}.ck-row.empty:hover{background:none}' +
      '.ck-row.empty .name{color:#8b949e;font-style:italic;font-weight:400;opacity:.8}' +
      '.ck-row .caret{flex:none;width:12px;color:#57606a;font-size:14px;line-height:1;text-align:center}' +
      '.ck-empty{padding:14px 12px;color:#8b949e}.ck-err{padding:10px 12px;color:#cf222e}' +
      '.ck-confirm{margin:14px 12px;padding:14px 16px;border:1px solid #d0d7de;border-radius:8px;background:#fff;box-shadow:0 1px 3px rgba(31,35,40,.06)}' +
      '.ck-confirm .t{font-weight:600;font-size:14px;margin-bottom:6px;overflow-wrap:anywhere}.ck-confirm .n{color:#57606a;line-height:1.5;margin-bottom:12px}' +
      '.ck-confirm .acts{display:flex;gap:8px;flex-wrap:wrap}.ck-confirm .acts button{flex:1 1 auto;font:inherit;padding:5px 12px;border:1px solid #d0d7de;border-radius:6px;background:#fff;color:#24292f;cursor:pointer}' +
      '.ck-confirm .acts button.danger{border-color:#cf222e;background:#cf222e;color:#fff}.ck-confirm .acts button:focus{outline:none;box-shadow:0 0 0 2px rgba(9,105,218,.25)}.ck-confirm .acts button:disabled{opacity:.5;cursor:default}' +
      '.ck-confirm .ck-err{padding:8px 0 0}' +
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
      '.ck-tool .pick.on{background:#24292f;color:#fff;border-color:#24292f;position:relative}' +
      '.ck-tip{margin:6px 0 0;padding:10px 12px;border:1px solid #d0d7de;border-radius:6px;background:#f6f8fa;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;color:#24292f;max-height:320px;overflow:auto}' +
      '.ck-rec button.quiet{border-color:#d0d7de;background:#fff;color:#cf222e;font-size:11px;padding:2px 9px}' +
      '.ck-stack{flex:1;min-height:0;overflow:auto}' +
      '.ck-frame{border:1px solid #e2e7ee;border-radius:8px;padding:10px 12px;margin:0 0 10px;background:#fff}' +
      '.ck-frame.top{border-color:#54aeff;box-shadow:0 0 0 2px #ddf4ff}' +
      '.ck-frame .fhead{display:flex;gap:8px;align-items:center;min-width:0}' +
      '.ck-frame .fname{font:600 12px ui-monospace,SFMono-Regular,Menlo,monospace}' +
      '.ck-frame .fstep{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;color:#0969da}' +
      '.ck-frame .fstep:before{content:"→ ";color:#8b949e}' +
      '.ck-frame .flevel{font-size:11px;color:#8b949e}' +
      '.ck-frame .fask{font-size:11px;color:#7d4e00;background:#fff8c5;border-radius:5px;padding:1px 7px}' +
      '.ck-frame .fhead button{margin-left:auto}' +
      '.ck-frame .faim{color:#57606a;margin:4px 0 0}' +
      '.ck-frame .fcard{border-top:1px solid #f0f2f5;margin-top:8px;padding-top:8px}' +
      '.ck-frame .caim{font-weight:600;margin:0 0 4px}' +
      '.ck-frame .cdesc{color:#57606a;white-space:pre-wrap;margin:0 0 8px}' +
      '.ck-frame .fio{display:grid;grid-template-columns:max-content 1fr;gap:2px 10px;padding:6px 8px;background:#f6f8fa;border-radius:6px;margin:0 0 8px}' +
      '.ck-frame .fio .k{font:11px ui-monospace,monospace;color:#8b949e;text-transform:uppercase;letter-spacing:.04em;padding-top:2px}' +
      '.ck-frame .fio .v{white-space:pre-wrap;min-width:0}' +
      '.ck-frame .fchips{display:flex;gap:4px;margin:0 0 8px;flex-wrap:wrap}' +
      '.ck-frame .fchip{font:11px ui-monospace,monospace;color:#57606a;background:#eef1f4;border-radius:5px;padding:1px 7px}' +
      '.ck-frame .fchip.out{color:#cf222e;background:#ffebe9}' +
      '.ck-frame .farrows{list-style:none;margin:0;padding:6px 0 0;border-top:1px solid #f0f2f5}' +
      '.ck-frame .farrows li{display:flex;gap:8px;padding:2px 4px;border-radius:5px}' +
      '.ck-frame .farrows li.spent{opacity:.45}.ck-frame .farrows li.spent .to{text-decoration:line-through}' +
      '.ck-frame .to{font:11px ui-monospace,monospace;color:#0969da;flex:0 0 auto;min-width:5.5rem}' +
      '.ck-frame .to.done{color:#116329}.ck-frame .to.ask{color:#9a6700;font-style:italic}.ck-frame .to.abort{color:#cf222e}' +
      '.ck-frame .cond{color:#57606a;min-width:0}' +
      '.ck-frame details{margin-top:8px}.ck-frame summary{cursor:pointer;font-size:11px;color:#8b949e}';
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
    // open / close over moments: the host routes them; a host without them
    // (the plain page) just follows the link
    // beside: the keyboard's ⇧Enter, a new pane beside (the host's ⌘-click)
    function go(u, kind, name, beside) { var o = (name || beside) ? { name: name, beside: !!beside } : undefined; if (opts.open) opts.open(u, o); else if (opts.onNavigate) opts.onNavigate(u, kind, o); else location.href = u; }
    function close(u) { if (opts.close) opts.close(u); }
    function reload() { if (!dead) load(list, fail).catch(function (e) { if (!dead) fail('failed to load: ' + e.message); }); }
    // the stream says something under us moved: one reload per burst, not
    // one per event (a turn step writes a status and a log, every chat of
    // every clanker does; each reload is a request the ship serves in turn)
    var timer = null;
    function later() { if (timer) return; timer = setTimeout(function () { timer = null; reload(); }, 300); }
    var sb = {
      head: head, list: list, go: go, close: close, reload: reload,
      handle: { destroy: function () { dead = true; clearTimeout(timer); root.innerHTML = ''; root.classList.remove('ck'); }, onUpdate: later }
    };
    sb.handle.contextMenu = function (e) { return rowMenu(sb, e); };
    // the keys every navigator has (nav-keys.js): a row says what it is in
    // row._nk = {open(beside), folded(), fold(open), parent()}; Enter on a
    // row without one just clicks it
    sb.nk = window.navKeys ? window.navKeys(list, {
      rows: function () { return Array.prototype.slice.call(list.querySelectorAll('.ck-row:not(.empty)')); },
      open: function (row, m) { if (row._nk && row._nk.open) row._nk.open(m && m.beside); else row.click(); },
      folded: function (row) { return (row._nk && row._nk.folded) ? row._nk.folded() : null; },
      fold: function (row, open) { if (row._nk && row._nk.fold) row._nk.fold(open); },
      parent: function (row) { return (row._nk && row._nk.parent) ? row._nk.parent() : null; }
    }) : null;
    return sb;
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
  // a chat is on the user when a tool asks to run, or when the recipe it
  // follows took an ask arrow; both are the same dot and the same row text
  function onUser(c) { return !!(c.asking || (c.recipe && c.recipe.asked)); }
  function chatDot(c) { return onUser(c) ? 'asking' : c.busy ? 'busy' : ''; }
  function chatSub(c) {
    if (c.asking) return 'waiting for you: a tool asks to run';
    if (c.recipe && c.recipe.asked) return 'waiting for you: ' + c.recipe.name + ' at ' + c.recipe.step + ' asks';
    if (c.recipe) return c.recipe.name + ' at ' + c.recipe.step + (c.last ? ' · ' + c.last : '');
    return c.last;
  }
  // a confirmation that takes over the sidebar's list: what is about to
  // happen, cancel / the verb. Enter is the verb, Escape cancels (only while
  // focus is on the card, so a chat being typed in is never caught). The
  // list is redrawn either way; a done deed is also announced by the stream.
  function takeover(sb, title, note, verb, act) {
    var list = sb.list; list.innerHTML = '';
    var card = el('div', 'ck-confirm');
    card.appendChild(el('div', 't', title));
    card.appendChild(el('div', 'n', note));
    var acts = el('div', 'acts'), no = el('button', null, 'cancel'), yes = el('button', 'danger', verb);
    acts.appendChild(no); acts.appendChild(yes); card.appendChild(acts);
    var err = el('div', 'ck-err'); err.hidden = true; card.appendChild(err);
    list.appendChild(card);
    var done = false;
    function end(go) {
      if (done) return; done = true;
      document.removeEventListener('keydown', key, true);
      if (!go) { sb.reload(); return; }
      yes.disabled = true; yes.textContent = verb + '…';
      act().then(function () { sb.reload(); }, function (e) { done = false; yes.disabled = false; yes.textContent = verb; err.hidden = false; err.textContent = 'failed: ' + e.message; document.addEventListener('keydown', key, true); });
    }
    function key(e) {
      if (!card.isConnected) { document.removeEventListener('keydown', key, true); return; }
      if (!(card.contains(document.activeElement) || document.activeElement === document.body)) return;
      if (e.key === 'Enter') { e.preventDefault(); e.stopPropagation(); end(true); }
      else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); end(false); }
    }
    document.addEventListener('keydown', key, true);
    no.addEventListener('click', function () { end(false); });
    yes.addEventListener('click', function () { end(true); });
    yes.focus();
  }
  // the rows' right-click menu: what the row is (row.__ck) decides
  function rowMenu(sb, e) {
    var r = e.target && e.target.closest ? e.target.closest('.ck-row') : null;
    var it = r && r.__ck; if (!it) return null;
    var what = it.kind === 'chat' ? 'chat ' + it.name : it.kind === 'clanker' ? 'clanker ' + short(it.path) : 'category ' + it.path.replace(/^\//, '') + '/';
    var note = it.kind === 'chat' ? 'Its log and its own prompt go with it. Open tabs showing it stay, marked deleted, until you close them.'
      : it.kind === 'clanker' ? 'Everything in it goes: its chats, memories, skills, tools and prompt. Open tabs showing it stay, marked deleted, until you close them.'
      : 'Every clanker and category inside it goes with it. Open tabs showing any of them stay, marked deleted, until you close them.';
    return [{ label: 'Delete…', danger: true, run: function () {
      takeover(sb, 'Delete ' + what + '?', note, 'delete', function () {
        return post('/api/delete', it.kind === 'chat' ? { path: it.proj, chat: it.name } : { path: it.path })
          .then(function (r) { if (it.url && sb.close) sb.close(it.url); return r; });   // the moment is gone: say so, where it was shown
      });
    } }];
  }

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
    var tree = null;
    function sub(p) { return p === '/' ? '' : p; }
    function count(node) { return (node.clankers || []).length + (node.categories || []).reduce(function (n, c) { return n + count(c); }, 0); }
    function plural(n, word) { return n + ' ' + word + (n === 1 ? '' : 's'); }
    // a clanker's state is its chats'; a category's is its clankers': asking
    // beats busy beats quiet, so the dot at every level says what is inside
    function dotOf(chats) { return chats.some(onUser) ? 'asking' : chats.some(function (c) { return c.busy; }) ? 'busy' : ''; }
    function status(node) {
      var states = (node.clankers || []).map(function (k) { return dotOf(k.chats || []); }).concat((node.categories || []).map(status));
      return states.indexOf('asking') >= 0 ? 'asking' : states.indexOf('busy') >= 0 ? 'busy' : '';
    }
    function draw(node, path, depth, list) {
      var pad = 12 + depth * 14;
      (node.categories || []).forEach(function (c) {
        var p = sub(path) + '/' + c.name, open = !closed[p];
        var r = el('div', 'ck-row cat');
        r.style.paddingLeft = pad + 'px';
        var st = status(c);
        r.appendChild(el('span', 'caret', open ? '▾' : '▸'));
        r.appendChild(el('span', 'dot' + (st ? ' ' + st : '')));
        var main = el('div', 'main'); main.appendChild(el('div', 'name', c.name)); r.appendChild(main);
        var n = count(c); if (n) r.appendChild(el('span', 'right', plural(n, 'clanker')));
        r.__ck = { kind: 'category', path: p };
        // a click folds or unfolds the category, nothing else: the new box
        // is a path from the root, never relative to what was clicked
        function toggle() { if (open) closed[p] = true; else delete closed[p]; remember(); render(); }
        r.addEventListener('click', toggle);
        // keys: Enter / → ← fold and unfold the category; ← at a top category does nothing
        r._nk = {
          open: toggle,
          folded: function () { return !!closed[p]; },
          fold: function (want) { if (want) delete closed[p]; else closed[p] = true; remember(); render(); },
          parent: function () { return rowFor(sub(path)); }
        };
        list.appendChild(r);
        if (open) {
          draw(c, p, depth + 1, list);
          // an open category with nothing in it says so, quietly (the
          // explorer's tree does the same): an open caret over blank space
          // reads as the list having failed
          if (!(c.categories || []).length && !(c.clankers || []).length) {
            var e = el('div', 'ck-row empty');
            e.style.paddingLeft = (pad + 20) + 'px';
            e.appendChild(el('div', 'main')).appendChild(el('div', 'name', 'empty'));
            list.appendChild(e);
          }
        }
      });
      (node.clankers || []).forEach(function (k) {
        var chats = k.chats || [];
        var r = row('', dotOf(chats), short(k.name), k.bundle || '', chats.length ? plural(chats.length, 'chat') : 'no chats');
        r.style.paddingLeft = (pad + 20) + 'px';   // its dot under the category's (past caret + gap)
        // relative to the dir this pane opened on (the collection root or
        // the category), however that dir is spelled: under @clanker the
        // link stays under @clanker
        var u = '.' + sub(path).slice(sub(parent).length).split('/').map(encodeURIComponent).join('/') + '/' + encodeURIComponent(k.name);
        r.__ck = { kind: 'clanker', path: sub(path) + '/' + k.name, url: u };
        r.addEventListener('click', function () { sb.go(u, 'dir', short(k.name)); });
        r._nk = { open: function (beside) { sb.go(u, 'dir', short(k.name), beside); }, parent: function () { return rowFor(sub(path)); } };
        list.appendChild(r);
      });
    }
    // the row showing a category path, for ← (parent); '' is the root: none
    function rowFor(p) { if (!p) return null; var rs = sb.list.querySelectorAll('.ck-row'); for (var i = 0; i < rs.length; i++) if (rs[i].__ck && rs[i].__ck.kind === 'category' && rs[i].__ck.path === p) return rs[i]; return null; }
    function render() {
      var list = sb.list; list.innerHTML = '';
      if (!tree) return;
      if (!count(tree) && !(tree.categories || []).length) { list.appendChild(el('div', 'ck-empty', 'No clankers yet. Name one above.')); return; }
      // the keyboard cursor survives a redraw: the row at the same path
      var was = sb.nk && sb.nk.cursor() && sb.nk.cursor().__ck ? sb.nk.cursor().__ck.path : null;
      draw(tree, parent, 0, list);
      if (was && sb.nk) { var rs = list.querySelectorAll('.ck-row'); for (var i = 0; i < rs.length; i++) if (rs[i].__ck && rs[i].__ck.path === was) { sb.nk.setCursor(rs[i]); break; } }
    }
    var sb = sidebar(root, opts, function () {
      return get(API + '/api/collection?path=' + encodeURIComponent(parent)).then(function (c) { tree = c; render(); });
    });
    // one box, a path from the root: `work/hatchery` makes the categories
    // on the way and a clanker at the end; `work/` (trailing slash) makes
    // just the category
    var name = el('input'); name.placeholder = 'new…  (a/b/name, or a/b/ for a category)'; name.spellcheck = false;
    sb.head.appendChild(name);
    function make() {
      var raw = name.value.trim(); if (!raw) { name.focus(); return; }
      var isCat = /\/$/.test(raw);
      var segs = raw.split('/').map(slug).filter(Boolean);
      if (!segs.length) { name.focus(); return; }
      var leaf = segs.pop();
      var parent = segs.length ? '/' + segs.join('/') : '/';
      name.disabled = true;
      post('/api/new', { kind: isCat ? 'category' : 'clanker', parent: parent, name: leaf })
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
          // the right side: what the chat has cost, when it has cost anything, else its size
          var sp = c.spent, cost = sp && sp.calls ? Number(sp.cost) : 0;
          var right = cost ? '$' + (cost < 0.01 ? cost.toFixed(4) : cost.toFixed(2)) : c.events ? c.events + (c.events === 1 ? ' event' : ' events') : '';
          var r = row('', chatDot(c), c.name, chatSub(c), right);
          r.__ck = { kind: 'chat', proj: proj, name: c.name, url: './' + encodeURIComponent(c.name) };   // relative to this chats/ dir, as spelled
          r.addEventListener('click', function () { sb.go('./' + encodeURIComponent(c.name), 'dir', c.name); });
          r._nk = { open: function (beside) { sb.go('./' + encodeURIComponent(c.name), 'dir', c.name, beside); } };
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
        .then(function () { name.value = ''; sb.go('./' + encodeURIComponent(n), 'dir', n); }, function (e) { sb.list.insertBefore(el('div', 'ck-err', 'could not make the chat: ' + e.message), sb.list.firstChild); })
        .then(function () { name.disabled = false; });
    }
    name.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); make(); } });
    sb.reload();
    return sb.handle;
  }

  // ---- record: the standing prompt, or one chat's own ----
  // The model and the provider are the config pane's; this is the prose.
  // Both save through /api/record, which merges field by field, so neither
  // pane clobbers what the other owns.
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
    var sys = el('textarea'); sys.spellcheck = false;
    var l3 = el('label', 'grow'); l3.appendChild(el('span', null, chat ? 'this chat’s prompt, on top of ' + short(proj) + '’s' : 'standing prompt (prompts/main.md)')); l3.appendChild(sys); box.appendChild(l3);
    var foot = el('div', 'foot'), save = el('button', null, 'save'), note = el('span', 'note', '');
    foot.appendChild(save); foot.appendChild(note); box.appendChild(foot);
    root.appendChild(box);
    sys.addEventListener('input', function () { dirty = true; note.textContent = 'unsaved changes'; });
    var rec = null;
    function fill() { if (dirty || !rec) return; sys.value = rec.system || ''; }
    function load() {
      if (dead) return;
      get(API + '/api/record' + qs).then(function (j) { if (!dead) { rec = j; fill(); } }, function (e) { if (!dead) note.textContent = 'could not load: ' + e.message; });
    }
    function doSave() {
      save.disabled = true; note.textContent = 'saving…';
      var body = chat ? { path: proj, chat: chat, system: sys.value } : { path: proj, system: sys.value };
      post('/api/record', body)
        .then(function () { dirty = false; note.textContent = 'saved'; load(); }, function (e) { note.textContent = 'save failed: ' + e.message; })
        .then(function () { save.disabled = false; });
    }
    save.addEventListener('click', doSave);
    box.addEventListener('keydown', function (e) { if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); doSave(); } });
    load();
    return handle;
  }

  // ---- config: which endpoint answers, which model, how many tokens ----
  // The providers are the ship's registry (/api/providers, from the list in
  // lib/clanker); the models come from the chosen provider's own
  // /api/models, the one shape every model-endpoint nexus answers. The
  // model stays a free-text field with the catalogue as typeahead, so an id
  // the catalogue has not synced is still reachable.
  function mountConfig(root, opts) {
    css();
    var proj = opts.args && typeof opts.args.proj === 'string' ? opts.args.proj : null;
    root.innerHTML = ''; root.classList.add('ck');
    var dead = false, dirty = false;
    var handle = { destroy: function () { dead = true; root.innerHTML = ''; root.classList.remove('ck'); }, onUpdate: function () { load(); } };
    if (!proj) { root.appendChild(el('div', 'ck-err', 'no clanker here')); return handle; }
    var box = el('div', 'ck-rec');
    box.appendChild(el('h2', null, short(proj) + ' · config'));
    box.appendChild(el('div', 'extra', 'Which endpoint answers this clanker, and with which model. Its prompt is the prompt tab.'));
    var prov = el('select');
    var model = el('input'); model.spellcheck = false;
    var max = el('input'); max.type = 'number'; max.min = '1';
    var dl = el('datalist'); dl.id = 'ck-models-' + Math.random().toString(36).slice(2);
    model.setAttribute('list', dl.id);
    var grid = el('div', 'grid');
    var lp = el('label'); lp.appendChild(el('span', null, 'provider')); lp.appendChild(prov);
    var lt = el('label'); lt.appendChild(el('span', null, 'max tokens')); lt.appendChild(max);
    grid.appendChild(lp); grid.appendChild(lt); box.appendChild(grid);
    var lm = el('label'); lm.appendChild(el('span', null, 'model')); lm.appendChild(model); box.appendChild(lm);
    box.appendChild(dl);
    var price = el('div', 'extra mono', ''); box.appendChild(price);
    var rest = el('div', 'extra mono', ''); box.appendChild(rest);
    var foot = el('div', 'foot'), save = el('button', null, 'save'), note = el('span', 'note', '');
    foot.appendChild(save); foot.appendChild(note); box.appendChild(foot);
    root.appendChild(box);
    var PROVIDERS = [], CAT = {};
    function current() { for (var i = 0; i < PROVIDERS.length; i++) if (PROVIDERS[i].name === prov.value) return PROVIDERS[i]; return null; }
    // what the chosen model costs, when the catalogue knows it. An id the
    // catalogue has not got is said so plainly rather than silently blank:
    // it is still sent, and a typo should not look like a price of nothing
    function showPrice() {
      var p = current(), rows = (p && CAT[p.name]) || [], id = model.value.trim(), hit = null;
      for (var i = 0; i < rows.length; i++) if (rows[i].id === id) { hit = rows[i]; break; }
      if (!p) { price.textContent = ''; return; }
      if (!rows.length) { price.textContent = 'no catalogue synced for ' + p.label; return; }
      if (!hit) { price.textContent = rows.length + ' models listed · this id is not among them (it is still sent)'; return; }
      var ctx = hit.context ? ' · ' + Number(hit.context).toLocaleString() + ' ctx' : '';
      price.textContent = 'in $' + hit['in'] + '/M · out $' + hit.out + '/M' + ctx;
    }
    function fillModels() {
      var p = current(); if (!p) return;
      dl.innerHTML = '';
      (CAT[p.name] || []).forEach(function (m) { var o = el('option'); o.value = m.id; dl.appendChild(o); });
      showPrice();
    }
    function catalogue(p) {
      if (!p) return;
      if (CAT[p.name]) { fillModels(); return; }
      get(p.route + '/api/models').then(function (j) {
        if (dead) return;
        var rows = (j && j.models) || [];
        rows.sort(function (a, b) { return a.id < b.id ? -1 : a.id > b.id ? 1 : 0; });
        CAT[p.name] = rows; fillModels();
      }, function () { if (!dead) { CAT[p.name] = []; fillModels(); } });
    }
    var rec = null;
    function fill() {
      if (dirty || !rec) return;
      var r = rec.record || {};
      prov.innerHTML = '';
      PROVIDERS.forEach(function (p) { var o = el('option', null, p.label); o.value = p.name; prov.appendChild(o); });
      prov.value = r.provider || (PROVIDERS[0] && PROVIDERS[0].name) || '';
      model.value = r.model || ''; max.value = r.max_tokens != null ? r.max_tokens : '';
      var skip = ['name', 'model', 'max_tokens', 'provider'];
      var ks = Object.keys(r).filter(function (k) { return skip.indexOf(k) < 0; });
      rest.textContent = ks.map(function (k) { return k + ': ' + (typeof r[k] === 'string' ? r[k] : JSON.stringify(r[k])); }).join('\n');
      catalogue(current());
    }
    function load() {
      if (dead) return;
      var first = PROVIDERS.length ? Promise.resolve() : get(API + '/api/providers').then(function (j) { PROVIDERS = Array.isArray(j) ? j : []; });
      first.then(function () { return get(API + '/api/record?path=' + encodeURIComponent(proj)); })
        .then(function (j) { if (!dead) { rec = j; fill(); } }, function (e) { if (!dead) note.textContent = 'could not load: ' + e.message; });
    }
    [prov, model, max].forEach(function (i) { i.addEventListener('input', function () { dirty = true; note.textContent = 'unsaved changes'; }); });
    prov.addEventListener('change', function () { catalogue(current()); });
    model.addEventListener('input', showPrice);
    function doSave() {
      save.disabled = true; note.textContent = 'saving…';
      var body = { path: proj, provider: prov.value, model: model.value.trim() };
      var mt = parseInt(max.value, 10); if (!isNaN(mt)) body.max_tokens = mt;
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
    defRow.appendChild(el('span', null, 'default verdict (rows set to “default”, and any tool added later)'));
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

  // ---- tip: the recipe run a chat is on, as the model sees it ----
  // One request to /api/tip: where the run stands and the block that
  // rides at the tail of the model's next request. The leave button
  // takes the chat out of the run (a poke; the log records it). Follows
  // run.json and the log, so a move or a leave redraws it.
  function mountTip(root, opts) {
    css();
    var proj = opts.args && typeof opts.args.proj === 'string' ? opts.args.proj : null;
    var chat = opts.args && typeof opts.args.chat === 'string' ? opts.args.chat : null;
    root.innerHTML = ''; root.classList.add('ck');
    var dead = false;
    var handle = { destroy: function () { dead = true; root.innerHTML = ''; root.classList.remove('ck'); }, onUpdate: function () { load(); } };
    if (!proj || !chat) { root.appendChild(el('div', 'ck-err', 'no chat here')); return handle; }
    var qs = '?path=' + encodeURIComponent(proj) + '&chat=' + encodeURIComponent(chat);
    var box = el('div', 'ck-rec');
    var note = el('div', 'extra', ''); box.appendChild(note);
    var stack = el('div', 'ck-stack'); box.appendChild(stack);
    root.appendChild(box);
    var TERM = { done: 'done', ask: 'ask', abort: 'abort' };
    function title(aim) { return (aim && aim.length) ? aim[0] : ''; }
    function body(aim) { return (aim || []).slice(1).join('\n').replace(/^\n+/, ''); }
    function io(input, output) {
      var g = el('div', 'fio');
      [['input', input], ['output', output]].forEach(function (p) {
        g.appendChild(el('span', 'k', p[0]));
        g.appendChild(el('span', 'v', (p[1] && p[1].length) ? p[1].join('\n') : '-'));
      });
      return g;
    }
    function left(cap, used) { return cap == null ? null : Math.max(0, cap - used); }
    function chip(label, n) {
      var c = el('span', 'fchip' + (n === 0 ? ' out' : ''));
      c.textContent = label + ' ' + (n == null ? '-' : n);
      return c;
    }
    function leaveAt(depth, btn) {
      btn.disabled = true;
      post('/api/leave', { path: proj, chat: chat, depth: depth })
        .then(function () { load(); }, function (e) { note.textContent = 'leave failed: ' + e.message; })
        .then(function () { btn.disabled = false; });
    }
    // one frame of the stack: its recipe and where it stands; the top one
    // opens into the step it is on, with what is left and the arrows out
    function frame(f, depth, top) {
      var r = f.recipe || {}, st = f.run || {}, lv = ((r.levels || {})[f.level] || {}), caps = lv.steps || {}, step = (r.steps || {})[f.step] || {};
      var fr = el('div', 'ck-frame' + (top ? ' top' : ''));
      fr.style.marginLeft = (depth * 18) + 'px';
      var head = el('div', 'fhead');
      head.appendChild(el('span', 'fname', f.name));
      head.appendChild(el('span', 'fstep', f.step));
      head.appendChild(el('span', 'flevel', 'level ' + f.level));
      if (f.asked) head.appendChild(el('span', 'fask', 'waiting on you'));
      var lb = el('button', 'quiet', depth === 0 ? 'leave' : 'leave this and above'); lb.type = 'button';
      lb.addEventListener('click', function () { leaveAt(depth, lb); });
      head.appendChild(lb);
      fr.appendChild(head);
      if (title(r.aim)) fr.appendChild(el('div', 'faim', title(r.aim)));
      if (!top) return fr;
      var card = el('div', 'fcard');
      card.appendChild(el('div', 'caim', title(step.aim)));
      if (body(step.aim)) card.appendChild(el('div', 'cdesc', body(step.aim)));
      card.appendChild(io(step.input, step.output));
      var cap = caps[f.step] || {};
      var dwellLeft = left(cap.dwell, st.dwell || 0), lifeLeft = left(cap.life, (st.spent || {})[f.step] || 0), runLeft = lv.run == null ? 0 : Math.max(0, lv.run - (st.run || 0));
      var chips = el('div', 'fchips');
      chips.appendChild(chip('dwell', dwellLeft)); chips.appendChild(chip('step', lifeLeft)); chips.appendChild(chip('run', runLeft));
      card.appendChild(chips);
      var ul = el('ul', 'farrows');
      Object.keys(step.next || {}).forEach(function (to) {
        var self = to === 'self' || to === 'stay';
        var ok = TERM[to] ? true : self ? (dwellLeft == null || dwellLeft > 0) : (function () { var c = caps[to] || {}; var l = left(c.life, (st.spent || {})[to] || 0); return l == null || l > 0; })();
        var li = el('li', ok ? '' : 'spent');
        li.appendChild(el('span', 'to' + (TERM[to] ? ' ' + to : ''), self ? 'stay' : to));
        li.appendChild(el('span', 'cond', step.next[to]));
        ul.appendChild(li);
      });
      card.appendChild(ul);
      if (f.tip) {
        var d = el('details'); d.appendChild(el('summary', null, 'as the model reads it'));
        d.appendChild(el('pre', 'ck-tip', f.tip)); card.appendChild(d);
      }
      fr.appendChild(card);
      return fr;
    }
    function load() {
      if (dead) return;
      get(API + '/api/tip' + qs).then(function (t) {
        if (dead) return;
        stack.innerHTML = '';
        var frames = (t && t.frames) || [];
        if (!frames.length) { note.textContent = 'no recipe engaged in this chat'; return; }
        note.textContent = frames.length === 1 ? '' : frames.length + ' recipes engaged, innermost last';
        frames.forEach(function (f, i) { stack.appendChild(frame(f, i, i === frames.length - 1)); });
      }, function (e) { if (!dead) note.textContent = 'could not load: ' + e.message; });
    }
    load();
    return handle;
  }

  window.Viewers = window.Viewers || {};
  window.Viewers['tip'] = { label: 'Tip', mount: mountTip };
  window.Viewers['tools'] = { label: 'Tools', mount: mountTools };
  window.Viewers['collection'] = { label: 'Clankers', mount: mountCollection };
  window.Viewers['chats'] = { label: 'Chats', mount: mountChats };
  window.Viewers['record'] = { label: 'Prompt', mount: mountRecord };
  window.Viewers['config'] = { label: 'Config', mount: mountConfig };
})();
