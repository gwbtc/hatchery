// The collection's plain face. One clanker -- the assistant -- its chats,
// and a composer. Everything a workspace needs and a conversation does not
// (tree, panes, tool policy, prompts, costs) stays in the explorer at
// /grubbery/clanker/<path>, which this page links to and never duplicates.
//
// It reads and writes the SAME api the workspace does: /api/collection,
// /api/chats, /api/log, /api/send, /api/stop, /api/new, /api/resolve.
(function () {
  var API = '/grubbery/clanker/api';
  // the standing conversation, always present and always first: the one you
  // land in. Everything else is a chat you started about something.
  var MAIN = 'main', MAIN_TITLE = 'Groundwire Assistant';
  var PROJ = '/assistant/groundwire.clanker';   // the assistant the tile opens
  var chat = null, log = [], timer = null, chats = [], wasBusy = false;

  var $ = function (id) { return document.getElementById(id); };
  var el = function (tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  };
  var get = function (p) { return fetch(API + p, { cache: 'no-store' }).then(function (r) { return r.ok ? r.json() : null; }).catch(function () { return null; }); };
  var post = function (p, body) {
    return fetch(API + p, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })
      .then(function (r) { return r.ok ? r.json() : null; }).catch(function () { return null; });
  };

  // --- what the log says about the turn in flight -------------------------
  // The last event decides: a message, a tool result or a resolved ask all
  // mean the model owes a reply; a response that stopped to use tools is
  // still mid-turn.
  var last = function (l) { return l.length ? l[l.length - 1] : null; };
  var busy = function (l) {
    var e = last(l);
    return !!e && (e.k === 'input' || e.k === 'results' || e.k === 'resolved' || (e.k === 'response' && e.stop === 'tool_use'));
  };
  var asking = function (l) { var e = last(l); return !!e && e.k === 'ask' ? e : null; };

  // --- the thread ---------------------------------------------------------
  // the model writes markdown; what you typed stays exactly as typed
  function md(text) {
    if (window.marked) { try { return window.marked.parse(text); } catch (e) { /* plain */ } }
    return null;
  }
  function turn(kind, who, text) {
    var t = el('div', 'turn ' + kind);
    t.appendChild(el('div', 'who', who));
    var body = el('div', 'text');
    var html = kind === 'bot' ? md(text) : null;
    if (html != null) { body.className = 'text rich'; body.innerHTML = html; }
    else body.textContent = text;
    t.appendChild(body);
    return t;
  }
  // what a tool does, said plainly: the names are ours, not the reader's
  var VERB = {
    grep: 'searching', read_grub: 'reading', list_files: 'listing files',
    read_file: 'reading', write_file: 'writing', delete_file: 'deleting',
    remember: 'making a note', write_code: 'writing code', edit_file: 'editing',
    commit: 'saving', check_bin: 'checking the build'
  };
  // naming the chat is not looking at the ship: it gets its own mark, and
  // the result of it is already visible in the list
  function badge() { return el('div', 'act', 'Naming the chat'); }
  function activity(names, spinning) {
    var seen = [], a = el('div', 'act');
    names.forEach(function (n) { var v = VERB[n] || n; if (seen.indexOf(v) < 0) seen.push(v); });
    if (spinning) a.appendChild(el('span', 'dot'));
    a.appendChild(document.createTextNode('Looking at your ship' + (seen.length ? ' · ' + seen.join(', ') : '')));
    return a;
  }
  function paint() {
    var th = $('thread');
    var atEnd = th.scrollHeight - th.scrollTop - th.clientHeight < 80;
    th.textContent = '';
    if (!log.length) {
      var e = el('div', 'empty');
      e.appendChild(el('b', null, 'Ask about your ship'));
      e.appendChild(document.createTextNode('What is installed, where something lives, what a desk does — or ask it to go and look.'));
      th.appendChild(e);
    }
    // a turn of tool calls is many log events and one piece of work, so
    // they collapse into one line saying what is happening: a long look is
    // a quiet line, not a column of empty replies
    var acts = [], named = false;
    var flush = function (spinning) {
      if (named) { th.appendChild(badge()); named = false; }
      if (!acts.length) return;
      th.appendChild(activity(acts, !!spinning));
      acts = [];
    };
    log.forEach(function (ev) {
      if (ev.k === 'input') { flush(); th.appendChild(turn('user', 'You', ev.body || '')); }
      else if (ev.k === 'response') {
        var content = ev.content || [];
        var text = content.filter(function (c) { return c.type === 'text'; })
          .map(function (c) { return c.text; }).join('\n').trim();
        if (text) { flush(); th.appendChild(turn('bot', 'Assistant', text)); }
        content.forEach(function (c) {
          if (c.type !== 'tool_use') return;
          if (c.name === 'set_title') named = true; else acts.push(c.name);
        });
      } else if (ev.k === 'interrupt') { flush(); th.appendChild(el('div', 'note', 'Stopped.')); }
    });
    flush(busy(log));
    if (busy(log) && !th.querySelector('.act')) th.appendChild(activity([], true));
    if (atEnd) th.scrollTop = th.scrollHeight;
    paintAsk();
    var b = busy(log) || !!asking(log);
    $('send').disabled = b;
    $('stop').hidden = !b;
  }

  // A tool wants permission. The workspace lets you decide call by call;
  // here it is the whole pause, allowed or not.
  function paintAsk() {
    var box = $('ask');
    box.textContent = '';
    var a = asking(log);
    if (!a) return;
    var names = (a.ids || []).map(function (x) { return x.name || x; });
    var d = el('div', 'askbox');
    d.appendChild(document.createTextNode(
      'The assistant wants to ' + (names.length ? names.join(', ') : 'use a tool') + '.'));
    var ops = el('div', 'ops');
    var yes = el('button', 'go', 'Allow');
    var no = el('button', null, 'Not now');
    yes.onclick = function () { decide(true); };
    no.onclick = function () { decide(false); };
    ops.appendChild(yes); ops.appendChild(no);
    d.appendChild(ops);
    box.appendChild(d);
  }
  function decide(ok) {
    post('/resolve', { path: PROJ, chat: chat, allow: ok }).then(poll);
  }

  // --- data ---------------------------------------------------------------
  function loadLog() {
    return get('/log?path=' + encodeURIComponent(PROJ) + '&chat=' + encodeURIComponent(chat))
      .then(function (j) {
        var got = Array.isArray(j) ? j : (j && Array.isArray(j.events) ? j.events : []);
        // a message shown before the turn has written it must not be wiped
        // by the empty log that comes back in the meantime
        if (got.length || !log.length) log = got;
        paint();
        tick();
      });
  }
  // poll only while something is happening: a settled chat costs nothing.
  // A finished turn refreshes the list once -- the assistant names a new
  // chat with set_title while it is answering, and the sidebar is the only
  // place that shows it.
  function tick() {
    if (timer) { clearTimeout(timer); timer = null; }
    var b = busy(log);
    if (b) timer = setTimeout(poll, 1200);
    else if (wasBusy) loadChats();
    wasBusy = b;
  }
  function poll() { if (chat) loadLog(); }

  function paintChats() {
    var box = $('chats');
    box.textContent = '';
    chats.forEach(function (c) {
      var b = el('button', 'chat' + (c.name === chat ? ' on' : '') + (c.name === MAIN ? ' main' : ''));
      if (c.name === MAIN) b.appendChild(el('span', 'star', '\u2726'));
      b.appendChild(document.createTextNode(c.title || c.name));
      if (c.last) b.appendChild(el('span', 'last', String(c.last).replace(/\s+/g, ' ').slice(0, 60)));
      b.onclick = function () { select(c.name); };
      // the standing chat is not deletable: it is what the page opens in
      if (c.name !== MAIN) {
        var x = el('span', 'del', '\u00d7');
        x.title = 'delete this chat';
        x.onclick = function (e) { e.stopPropagation(); askDelete(c); };
        b.appendChild(x);
      }
      box.appendChild(b);
    });
  }
  // a chat's name is its directory, so it is chosen once, from the first
  // thing asked: five words of it, as a path segment. Until then the chat
  // does not exist -- New chat just clears the room.
  function nameFor(text) {
    var base = text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')
      .split('-').filter(Boolean).slice(0, 5).join('-').slice(0, 32).replace(/-+$/, '');
    if (!base || !/^[a-z]/.test(base)) base = 'chat' + (base ? '-' + base : '');
    var taken = chats.map(function (c) { return c.name; });
    if (taken.indexOf(base) < 0) return base;
    for (var i = 2; i < 99; i++) if (taken.indexOf(base + '-' + i) < 0) return base + '-' + i;
    return base + '-' + Date.now().toString(36).slice(-4);
  }
  // deleting is permanent, so it is asked for in the row itself rather
  // than behind a browser confirm the embedded views do not implement
  function askDelete(c) {
    var box = $('chats');
    var old = box.querySelector('.confirm');
    if (old) old.remove();
    var d = el('div', 'confirm');
    d.appendChild(el('div', 'q', 'Delete "' + (c.title || c.name) + '"? This cannot be undone.'));
    var ops = el('div', 'ops');
    var no = el('button', null, 'Cancel');
    var yes = el('button', 'danger', 'Delete');
    no.onclick = function () { d.remove(); };
    yes.onclick = function () {
      d.remove();
      post('/delete', { path: PROJ, chat: c.name }).then(function () {
        if (chat === c.name) { chat = null; log = []; }
        return loadChats();
      });
    };
    ops.appendChild(no); ops.appendChild(yes);
    d.appendChild(ops);
    box.insertBefore(d, box.firstChild);
  }
  function select(name) {
    chat = name;
    paintChats();
    $('thread').textContent = '';
    $('thread').appendChild(el('div', 'spin'));
    loadLog();
  }
  function loadChats() {
    return get('/chats?path=' + encodeURIComponent(PROJ)).then(function (j) {
      chats = Array.isArray(j) ? j : [];
      // the standing chat sorts first whatever the ship returns
      chats.sort(function (a, b) {
        return (a.name === MAIN ? -1 : 0) - (b.name === MAIN ? -1 : 0);
      });
      if (!chats.some(function (c) { return c.name === MAIN; })) return ensureMain();
      paintChats();
      if (chat == null) select(MAIN);
      else paint();
    });
  }
  // made once, on a ship that has never had it: the chat the page opens in
  function ensureMain() {
    return post('/new', { kind: 'chat', parent: PROJ, name: MAIN })
      .then(function () {
        return post('/record', {
          path: PROJ, chat: MAIN, title: MAIN_TITLE,
          system: 'This is the standing conversation. It already has a name, so do not call set_title here.'
        });
      })
      .then(loadChats);
  }
  // nothing is made here: the room is cleared and the first message names it
  function newChat() {
    chat = null; log = [];
    paintChats();
    paint();
    $('input').focus();
  }

  // --- composing ----------------------------------------------------------
  function send() {
    var i = $('input'), text = i.value.trim();
    if (!text) return;
    i.value = ''; grow();
    // shown immediately: the log catches up on the next poll
    log = log.concat([{ k: 'input', body: text }]);
    paint();
    var ready = chat ? Promise.resolve()
      : (function () {
          var name = nameFor(text);
          var title = text.replace(/\s+/g, ' ').trim();
          if (title.length > 60) title = title.slice(0, 57).replace(/\s+\S*$/, '') + '…';
          return post('/new', { kind: 'chat', parent: PROJ, name: name })
            .then(function () {
              chat = name;
              return post('/record', { path: PROJ, chat: name, title: title });
            });
        })();
    ready
      .then(function () { return post('/send', { path: PROJ, chat: chat, message: text }); })
      .then(function () { return loadChats(); })
      .then(poll);
  }
  function grow() {
    var i = $('input');
    i.style.height = 'auto';
    i.style.height = Math.min(i.scrollHeight, 180) + 'px';
  }

  $('send').onclick = send;
  $('stop').onclick = function () { post('/stop', { path: PROJ, chat: chat }).then(poll); };
  $('new').onclick = newChat;
  $('input').addEventListener('input', grow);
  $('input').addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); }
  });

  // the sidebar is a <split-view> pane: dragged, collapsed, and its size
  // remembered by the component. Collapsing leaves its reopen rail.
  $('collapse').onclick = function () {
    var sv = $('app');
    if (sv && typeof sv.toggle === 'function') sv.toggle();
  };

  loadChats();
})();
