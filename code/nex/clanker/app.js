// clanker page: the stored event log, rendered as a thread. Nothing here
// holds chat state; every render is a fold over what the ship has.
(function () {
  var BASE = '/grubbery/clanker';
  var $ = function (id) { return document.getElementById(id); };
  var projectEl = $('project'), chatEl = $('chat'), threadEl = $('thread'), logEl = $('log');
  var statusEl = $('status'), modelEl = $('model'), msgEl = $('message'), loadBar = $('load-bar');
  var projects = [], lastKey = '', busy = false, timer = null, inflight = 0;

  function project() { return projectEl.value || 'grubbery'; }
  function chat() { return chatEl.value.trim() || 'main'; }

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
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

  function track(p) {
    inflight++; loadBar.classList.add('active');
    return p.finally(function () { if (--inflight <= 0) { inflight = 0; loadBar.classList.remove('active'); } });
  }

  // one tool call = the model's tool_use block + the matching tool_result,
  // folded into one expandable line
  function step(use, result, trace) {
    var d = el('details', 'step');
    var s = el('summary');
    s.appendChild(icon(ICO_TOOL));
    s.appendChild(el('span', 'tool', use.name));
    var arg = trace && trace.arg ? trace.arg : '';
    if (arg) s.appendChild(el('span', 'arg', arg));
    var note = el('span', 'note' + (trace && trace.note === 'error' ? ' err' : ''), result ? (trace ? trace.note : 'done') : 'running');
    s.appendChild(note);
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
      var e = el('div', 'empty');
      e.innerHTML = 'Talk to the <b>' + project() + '</b> project. Every turn is appended to this chat’s event log and the request is assembled from it.';
      threadEl.appendChild(e);
      return;
    }
    var pendingUses = null; // tool_use blocks awaiting their results event
    log.forEach(function (ev) {
      if (ev.k === 'input') {
        var u = el('div', 'msg user');
        u.appendChild(el('div', 'bubble', ev.body));
        threadEl.appendChild(u);
      } else if (ev.k === 'response') {
        var b = el('div', 'msg bot');
        var text = (ev.content || []).filter(function (c) { return c.type === 'text'; }).map(function (c) { return c.text; }).join('\n');
        if (ev.content && ev.content.length === 0 && ev.stop === '') {
          b.appendChild(el('div', 'err', 'empty response from the proxy'));
        }
        if (text) b.appendChild(el('div', 'bubble', text));
        var uses = (ev.content || []).filter(function (c) { return c.type === 'tool_use'; });
        if (uses.length) {
          var tr = el('div', 'trace');
          uses.forEach(function (use) { tr.appendChild(step(use, null, null)); });
          b.appendChild(tr);
          pendingUses = { el: tr, uses: uses };
        }
        var meta = [];
        if (ev.usage && ev.usage.input_tokens != null) meta.push(ev.usage.input_tokens + ' in · ' + ev.usage.output_tokens + ' out');
        if (ev.stop && ev.stop !== 'end_turn' && ev.stop !== 'tool_use') meta.push(ev.stop);
        if (meta.length) b.appendChild(el('div', 'meta', meta.join(' · ')));
        threadEl.appendChild(b);
      } else if (ev.k === 'results') {
        if (pendingUses) {
          pendingUses.el.innerHTML = '';
          pendingUses.uses.forEach(function (use, i) {
            var res = (ev.content || []).filter(function (r) { return r.tool_use_id === use.id; })[0];
            pendingUses.el.appendChild(step(use, res || null, (ev.trace || [])[i]));
          });
          pendingUses = null;
        }
      } else {
        threadEl.appendChild(el('div', 'err', JSON.stringify(ev)));
      }
    });
    var last = log[log.length - 1];
    var open = last.k === 'input' || last.k === 'results' || (last.k === 'response' && last.stop === 'tool_use');
    if (open) {
      var t = el('div', 'msg bot');
      var ty = el('div', 'typing');
      ty.appendChild(el('span')); ty.appendChild(el('span')); ty.appendChild(el('span'));
      t.appendChild(ty);
      threadEl.appendChild(t);
    }
    logEl.scrollTop = logEl.scrollHeight;
  }

  function loadLog() {
    return fetch(BASE + '/api/log?project=' + encodeURIComponent(project()) + '&chat=' + encodeURIComponent(chat()), { cache: 'no-store' })
      .then(function (r) { return r.json(); })
      .then(function (log) {
        var key = project() + '/' + chat() + '#' + log.length;
        if (key !== lastKey) { lastKey = key; render(log); }
        var last = log[log.length - 1];
        setBusy(!!last && (last.k === 'input' || last.k === 'results' || (last.k === 'response' && last.stop === 'tool_use')));
      })
      .catch(function () {});
  }

  function setBusy(b) {
    busy = b;
    statusEl.innerHTML = '';
    if (b) { statusEl.appendChild(el('span', 'dot')); statusEl.appendChild(el('span', null, 'thinking')); }
    $('send').disabled = b;
    $('stop').disabled = !b;
    if (b && !timer) timer = setInterval(loadLog, 1500);
    if (!b && timer) { clearInterval(timer); timer = null; }
  }

  function loadProjects() {
    return fetch(BASE + '/api/projects', { cache: 'no-store' })
      .then(function (r) { return r.json(); })
      .then(function (ps) {
        projects = ps;
        projectEl.innerHTML = '';
        ps.forEach(function (p) {
          var o = el('option', null, p.name);
          o.value = p.name;
          projectEl.appendChild(o);
        });
        showModel();
      });
  }
  function showModel() {
    var p = projects.filter(function (x) { return x.name === project(); })[0];
    modelEl.textContent = p && p.model ? p.model : '';
  }

  function autosize() {
    msgEl.style.height = 'auto';
    msgEl.style.height = Math.min(msgEl.scrollHeight, 200) + 'px';
  }

  $('compose').addEventListener('submit', function (e) {
    e.preventDefault();
    var text = msgEl.value.trim();
    if (!text || busy) return;
    msgEl.value = ''; autosize();
    track(fetch(BASE + '/api/send', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ project: project(), chat: chat(), message: text })
    })).then(function () { setBusy(true); loadLog(); });
  });

  $('stop').addEventListener('click', function () {
    track(fetch(BASE + '/api/stop', { method: 'POST' })).then(function () { setTimeout(loadLog, 600); });
  });

  msgEl.addEventListener('input', autosize);
  msgEl.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); $('compose').requestSubmit(); }
  });

  projectEl.addEventListener('change', function () { lastKey = ''; showModel(); loadLog(); });
  chatEl.addEventListener('change', function () { lastKey = ''; loadLog(); });

  $('stop').disabled = true;
  track(loadProjects()).then(loadLog);
})();
