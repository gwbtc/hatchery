// itinerary panes: the explorer's viewers for a trip. Each is mounted by
// the explorer from +pick-viewer's answer and draws from the trip's doc
// (itinerary.json), which the pane follows with its body: a write by the
// agent, another pane, or the api redraws every pane showing it.
//   mount(root, {url, args, query, open, close}) -> {destroy, onUpdate(ev)}
//
//   trips     the collection: one row per trip (a navigator)
//   map       the map: pins, zones, a category filter strip
//   trip      the description, dates, zones
//   todos     the to-do list (toggle / remove write the doc)
//   places    pins by category; a row flies the map to the pin
//   events    scheduled and unscheduled events
//   schedule  the week grid
//
// Panes of one trip talk through one page-level event, itin-focus
// {doc, pin}: a places row asks, the map pane showing that doc answers.
(function () {
  'use strict';
  var API = '/grubbery/itinerary/api';
  var CSS_ID = 'itin-panes-css';
  var DEFAULT_CATEGORIES = {
    food: { color: '#e67e22', label: 'Food' }, bar: { color: '#3498db', label: 'Bars' },
    museum: { color: '#9b59b6', label: 'Museums' }, park: { color: '#27ae60', label: 'Parks' },
    nightlife: { color: '#e91e63', label: 'Nightlife' }, daytrip: { color: '#795548', label: 'Day Trips' },
    accommodation: { color: '#e74c3c', label: 'Accommodation' }
  };
  function css() {
    if (document.getElementById(CSS_ID)) return;
    var s = document.createElement('style'); s.id = CSS_ID;
    s.textContent =
      '.it{height:100%;display:flex;flex-direction:column;min-height:0;font:13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#24292f;background:#fff}' +
      '.it .body{flex:1;min-height:0;overflow:auto}' +
      '.it-head{flex:none;display:flex;padding:8px 10px;border-bottom:1px solid #d0d7de;background:#f6f8fa}.it-head input{flex:1;min-width:0;font:inherit;padding:4px 7px;border:1px solid #d0d7de;border-radius:6px;background:#fff}.it-head input:focus{outline:none;border-color:#0969da;box-shadow:0 0 0 2px rgba(9,105,218,.15)}' +
      '.it-row{display:flex;align-items:flex-start;gap:8px;padding:7px 12px;cursor:pointer;border-bottom:1px solid #eaeef2;min-width:0}.it-row:hover{background:#f6f8fa}' +
      '.it-row .main{flex:1;min-width:0}.it-row .name{font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.it-row .sub{color:#57606a;font-size:12px;margin-top:1px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}' +
      '.it-row .right{flex:none;color:#8b949e;font-size:11px;white-space:nowrap}' +
      '.it-dot{flex:none;width:10px;height:10px;border-radius:50%;margin-top:4px}.it-dot.zone{background:transparent!important;border:2px dashed}' +
      '.it-sec{display:flex;align-items:center;gap:6px;padding:10px 12px 4px;font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.04em;color:#57606a}' +
      '.it-sec .it-dot{width:8px;height:8px;margin:0}.it-sec .n{font-weight:400;color:#8b949e}' +
      '.it-empty{padding:14px 12px;color:#8b949e;font-style:italic}.it-err{padding:10px 12px;color:#cf222e}' +
      '.it-confirm{margin:14px 12px;padding:14px 16px;border:1px solid #d0d7de;border-radius:8px;background:#fff;box-shadow:0 1px 3px rgba(31,35,40,.06)}.it-confirm .t{font-weight:600;font-size:14px;margin-bottom:6px;overflow-wrap:anywhere}.it-confirm .n{color:#57606a;line-height:1.5;margin-bottom:12px}' +
      '.it-confirm .acts{display:flex;gap:8px;flex-wrap:wrap}.it-confirm .acts button{flex:1 1 auto;font:inherit;padding:5px 12px;border:1px solid #d0d7de;border-radius:6px;background:#fff;color:#24292f;cursor:pointer}.it-confirm .acts button.danger{border-color:#cf222e;background:#cf222e;color:#fff}.it-confirm .acts button:focus{outline:none;box-shadow:0 0 0 2px rgba(9,105,218,.25)}.it-confirm .acts button:disabled{opacity:.5;cursor:default}.it-confirm .it-err{padding:8px 0 0}' +
      '.it-notes{font-size:12px;color:#4a5058;margin:4px 12px 8px 30px;padding:7px 9px;background:#f4f5f7;border-radius:7px;line-height:1.5;word-break:break-word}' +
      '.it-notes p{margin:0 0 6px}.it-notes p:last-child{margin:0}.it-notes table{border-collapse:collapse;font-size:12px}.it-notes th,.it-notes td{border:1px solid #e0e3e8;padding:3px 9px}' +
      '.it-md{padding:12px 14px;font-size:13px;line-height:1.55;max-width:720px}.it-md h1,.it-md h2,.it-md h3{font-size:14px;margin:12px 0 4px}.it-md p{margin:6px 0}.it-md ul,.it-md ol{margin:6px 0;padding-left:20px}.it-md a{color:#0969da}' +
      '.it-meta{padding:10px 14px 0;color:#57606a;font-size:12px}' +
      '.it-todo{display:flex;align-items:baseline;gap:8px;padding:6px 12px;cursor:pointer;border-bottom:1px solid #f0f2f4}.it-todo input{accent-color:#1a1a1a}.it-todo .t{flex:1}.it-todo.done .t{text-decoration:line-through;color:#a0a6ae}' +
      '.it-todo .x{color:#c4c8cd;visibility:hidden;padding:0 4px}.it-todo:hover .x{visibility:visible}.it-todo .x:hover{color:#c0392b}' +
      '.it-armed{background:#fff5f5!important;box-shadow:inset 3px 0 0 #cf222e!important}.it-arm{margin-left:auto;flex:none;font-size:11px;color:#cf222e;white-space:nowrap;padding-left:8px;display:inline-flex;align-items:center;gap:6px}.it-card.it-armed{position:relative}.it-card .it-arm{position:absolute;right:10px;top:9px}.blk .it-arm{display:block;padding:0}' +
      // a write in flight: a small ring where the action happened, until the
      // doc comes back and the pane redraws; a failure flashes the place red
      '@keyframes it-spin{to{transform:rotate(360deg)}}.it-spin{display:inline-block;width:11px;height:11px;border:1.5px solid #d0d7de;border-top-color:#57606a;border-radius:50%;animation:it-spin .7s linear infinite;vertical-align:-1px;flex:none}' +
      '.it-todo .it-spin{width:13px;height:13px;margin:0 1px;position:relative;top:2px}.it-todo.busy input{display:none}.it-todo.busy .x{visibility:hidden}' +
      '.it-fail{background:#fff0f0!important;box-shadow:inset 3px 0 0 #cf222e!important;transition:background .6s}' +
      '.it-new-row{position:relative}.it-new-row .it-spin{position:absolute;right:22px;top:50%;margin-top:-6px}.it-new.fail{border-color:#cf222e!important;border-style:solid}' +
      '.it-new{margin:8px 12px;padding:7px 10px;border:1.5px dashed #d6dae0;border-radius:8px;font:inherit;font-size:12.5px;outline:none;width:calc(100% - 24px);box-sizing:border-box}.it-new:focus{border-color:#8a919a;border-style:solid}' +
      '.it-card{margin:8px 10px 0;border:1px solid #e6e8eb;border-left:3px solid var(--sc,#6a7280);border-radius:8px;padding:9px 11px}.it-card.tentative{border-style:dashed;border-left-style:dashed}' +
      '.it-card .h{display:flex;align-items:center;gap:7px}.it-card .t{font-weight:600;flex:1}.it-card .w{font-size:11px;color:#8a919a;margin-top:2px;font-variant-numeric:tabular-nums}.it-card .n{font-size:12px;color:#79808a;margin-top:4px;white-space:pre-wrap}' +
      '.it-badge{font-size:10px;padding:1px 8px;border-radius:9px;background:#eef0f3;color:#57606a}.it-badge.tentative{background:#fff;border:1px dashed #b3b9c2}' +
      // map
      '.it-map{position:relative;flex:1;min-height:0}.it-map .mapc{position:absolute;inset:0}' +
      '.it-filters{flex:none;display:flex;gap:6px;padding:6px 10px;background:#f8f8f8;border-bottom:1px solid #e8e8e8;overflow-x:auto}' +
      '.it-chip{padding:3px 11px;border-radius:20px;border:2px solid;background:#fff;font:inherit;font-size:12px;cursor:pointer;white-space:nowrap}.it-chip.off{opacity:.35}' +
      '.it-pin{width:14px;height:14px;border-radius:50%;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.4);cursor:pointer}' +
      '@keyframes it-pulse{0%{box-shadow:0 0 0 0 rgba(26,26,26,.45)}70%{box-shadow:0 0 0 18px rgba(26,26,26,0)}100%{box-shadow:0 0 0 0 rgba(26,26,26,0)}}.it-pin.pulse{animation:it-pulse .9s ease-out 2}' +
      '.it-pop .pn{font-weight:600;font-size:14px}.it-pop .pd{font-size:13px;color:#555;margin-top:2px}.it-pop .pf{font-size:11px;color:#999;margin-top:4px}' +
      '.it-pop .pnotes{font-size:12px;color:#6a707a;margin-top:5px;padding:6px 8px;background:#f4f5f7;border-radius:7px;max-height:130px;overflow:auto}' +
      // schedule
      '.it-shead{flex:none;display:flex;align-items:baseline;gap:10px;padding:8px 14px;border-bottom:1px solid #e8e8e8;background:#fff}.it-shead .t{font-weight:650}.it-shead .m{color:#57606a;font-size:12px}.it-shead .z{margin-left:auto;color:#8b949e;font-size:11px}' +
      '.it-sched{flex:1;min-height:0;overflow:auto}.it-sched .days{display:flex;min-width:100%}' +
      '.it-sched .mon{display:block;color:#8a919a;font-size:9.5px;letter-spacing:.04em;text-transform:uppercase;line-height:1}' +
      '.it-sched .gutter{flex:0 0 46px;position:sticky;left:0;z-index:6;background:#fff;border-right:1px solid #eee}.it-sched .gbody{position:relative}.it-sched .ghour{position:absolute;right:6px;font-size:9.5px;color:#b6bcc4;font-variant-numeric:tabular-nums}' +
      '.it-sched .col{flex:1;min-width:128px;border-right:1px solid #f2f2f2;display:flex;flex-direction:column}.it-sched .col.today .chead{background:#eef6f3}' +
      '.it-sched .chead{position:sticky;top:0;z-index:5;background:#fafafa;border-bottom:1px solid #eee;padding:5px 8px;font-size:12px;text-align:center;height:40px;box-sizing:border-box}' +
      '.it-sched .dow{color:#8a919a;text-transform:uppercase;font-size:10px;letter-spacing:.04em}.it-sched .dom{font-weight:700;font-size:13px;margin-left:4px}' +
      '.it-sched .allday{padding:3px 5px;border-bottom:1px solid #eee;background:#fcfcfd}.it-sched .allday .blk{position:relative;margin-bottom:3px;height:24px}' +
      '.it-sched .cbody{position:relative;background-image:repeating-linear-gradient(to bottom,transparent,transparent 43px,#f4f5f6 43px,#f4f5f6 44px)}' +
      '.it-sched .blk{--sc:#5b6470;position:relative;border-left:3px solid var(--sc);border-radius:5px;background:color-mix(in srgb,var(--sc) 13%,white);padding:3px 7px;font-size:11px;line-height:1.25;cursor:pointer;overflow:hidden;box-shadow:0 1px 2px rgba(0,0,0,.06);box-sizing:border-box}' +
      '.it-sched .blk.timed{position:absolute;left:4px;right:4px;z-index:2}.it-sched .blk.tentative{background:#fff;border:1.5px dashed var(--sc);border-left-width:3px;box-shadow:none;opacity:.85}' +
      '.it-sched .bt{font-weight:600;color:#23272d;white-space:nowrap;text-overflow:ellipsis;overflow:hidden}.it-sched .bm{font-size:9.5px;color:#79808a;font-variant-numeric:tabular-nums}';
    document.head.appendChild(s);
  }
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
  function esc(s) { var d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }
  function md(s) { if (window.marked) { try { return marked.parse(s || ''); } catch (e) {} } return esc(s); }
  function get(u) { return fetch(u, { cache: 'no-store' }).then(function (r) { if (!r.ok) throw new Error(r.status + ''); return r.json(); }); }
  // the trip's doc from a pane's url (the explorer's /grubbery/ball/<abs>/itinerary.json)
  function docOf(url) { return (url || '').replace(/\?.*$/, ''); }
  function tripIdOf(url) { var m = /\/itineraries\/([^/]+)\/itinerary\.json/.exec(docOf(url)); return m ? decodeURIComponent(m[1]) : ''; }
  function cats(doc) { return (doc && doc.categories) || DEFAULT_CATEGORIES; }
  function catColor(doc, c) { var k = cats(doc); return k[c] ? k[c].color : '#888'; }
  function catLabel(doc, c) { var k = cats(doc); return k[c] ? k[c].label : c; }
  function putDoc(id, doc) { return fetch(API + '/i/' + encodeURIComponent(id), { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify(doc) }); }
  // a pane over the doc: fetch once, redraw on the stream's bodies
  function docPane(root, opts, draw) {
    css();
    var box = el('div', 'it'); root.appendChild(box);
    var dead = false;
    var state = { doc: null, seq: 0, redraw: function () { if (!dead && state.doc) { state.seq++; draw(box, state.doc); } } };
    function refetch() { return get(docOf(opts.url)).then(function (d) { if (!dead) { state.doc = d; state.redraw(); } }).catch(function () {}); }
    // a write of the doc. The stream redraws the pane when the doc lands,
    // which is what clears a spinner; if no redraw comes within a few
    // seconds the pane refetches, so a spinner never outlives the write.
    // A failed write runs `fail` (undo the optimistic change), refetches,
    // and rejects so the caller can show it where it happened
    state.commit = function (pr, fail) {
      var at = state.seq;
      return pr.then(function (r) {
        if (r && r.ok === false) throw new Error(r.status + '');
        setTimeout(function () { if (!dead && state.seq === at) refetch(); }, 2500);
      }, function (e) { if (fail) fail(e); refetch(); throw e; });
    };
    get(docOf(opts.url)).then(function (d) { state.doc = d; state.redraw(); }).catch(function (e) { box.appendChild(el('div', 'it-err', 'could not load the trip: ' + e.message)); });
    return { box: box, state: state, handle: {
      destroy: function () { dead = true; box.remove(); },
      onUpdate: function (ev) { if (ev && ev.body && typeof ev.body === 'object') { state.doc = ev.body; state.redraw(); } else refetch(); }
    } };
  }
  // a write that failed, shown where it was asked for: the place flashes
  // red for a moment and its spinner goes
  function flashFail(node) {
    if (!node) return;
    node.classList.remove('busy'); var s = node.querySelector('.it-spin'); if (s) s.remove();
    node.classList.add('it-fail'); setTimeout(function () { node.classList.remove('it-fail'); }, 1600);
  }
  function focusPin(url, id) { window.dispatchEvent(new CustomEvent('itin-focus', { detail: { doc: docOf(url), pin: id } })); }

  // ---- trips: the collection ----
  function mountTrips(root, opts) {
    css();
    var box = el('div', 'it'), head = el('div', 'it-head'), list = el('div', 'body'); box.append(head, list); root.appendChild(box);
    var dead = false;
    // a new trip: its name typed here; the id is the name slugged. The api
    // makes the dir, the doc and the agent; the stream redraws the list
    var name = el('input'); name.placeholder = 'new trip\u2026'; name.spellcheck = false; head.appendChild(name);
    name.addEventListener('keydown', function (e) {
      if (e.key !== 'Enter') return;
      var n = name.value.trim(); if (!n) return;
      var id = n.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
      if (!id) return;
      name.disabled = true;
      putDoc(id, { name: n, desc: '', dates: {}, categories: DEFAULT_CATEGORIES, pins: {}, zones: {}, schedule: {}, todos: {} })
        .then(function (r) { if (!r.ok) throw new Error(r.status + ''); name.value = ''; })
        .catch(function (e) { list.insertBefore(el('div', 'it-err', 'could not make it: ' + e.message), list.firstChild); })
        .then(function () { name.disabled = false; });
    });
    function draw(trips) {
      list.textContent = '';
      if (!trips.length) { list.appendChild(el('div', 'it-empty', 'no trips yet')); return; }
      trips.forEach(function (t) {
        var r = el('div', 'it-row'); var main = el('div', 'main'); main.appendChild(el('div', 'name', t.name || t.id)); main.appendChild(el('div', 'sub', t.id)); r.appendChild(main);
        // the trip dir, relative to the itineraries dir this pane shows (under @itinerary it stays so)
        r._open = function (beside) { if (opts.open) opts.open('./' + encodeURIComponent(t.id), { name: t.name || t.id, beside: !!beside }); };
        r._trip = t;
        r.addEventListener('click', function () { r._open(false); });
        list.appendChild(r);
      });
      if (nk) nk.mark();
    }
    var nk = window.navKeys ? window.navKeys(list, { rows: function () { return Array.prototype.slice.call(list.querySelectorAll('.it-row')); }, open: function (row, m) { if (row._open) row._open(m && m.beside); } }) : null;
    function load() { get(API + '/list').then(function (t) { if (!dead) draw(Array.isArray(t) ? t : []); }).catch(function (e) { if (!dead) list.appendChild(el('div', 'it-err', 'could not list trips: ' + e.message)); }); }
    load();
    return {
      destroy: function () { dead = true; if (nk) nk.destroy(); box.remove(); },
      onUpdate: load,
      // right-click on a trip: delete it. The confirmation takes over this
      // list (the clanker navigator's pattern): Enter deletes, Esc cancels;
      // the stream redraws the list either way
      contextMenu: function (e) {
        var row = e.target.closest && e.target.closest('.it-row'); if (!row || !row._trip) return null;
        var t = row._trip;
        return [{ label: 'delete trip \u201c' + (t.name || t.id) + '\u201d', danger: true, run: function () {
          takeover(list, 'Delete ' + (t.name || t.id) + '?', 'Its document, attachments and agent go with it. Open tabs showing it stay, marked deleted, until you close them.', 'delete',
            function () { return fetch(API + '/i/' + encodeURIComponent(t.id), { method: 'DELETE' }).then(function (r) { if (!r.ok) throw new Error(r.status + ''); }); }, load);
        } }];
      }
    };
  }
  // a confirmation that takes over a navigator's list: what is about to
  // happen, cancel / the verb. Enter is the verb, Escape cancels (only while
  // focus is on the card). `after` redraws the list either way.
  function takeover(list, title, note, verb, act, after) {
    list.innerHTML = '';
    var card = el('div', 'it-confirm');
    card.appendChild(el('div', 't', title));
    card.appendChild(el('div', 'n', note));
    var acts = el('div', 'acts'), no = el('button', null, 'cancel'), yes = el('button', 'danger', verb);
    acts.append(no, yes); card.appendChild(acts);
    var err = el('div', 'it-err'); err.hidden = true; card.appendChild(err);
    list.appendChild(card);
    var done = false;
    function end(go) {
      if (done) return; done = true;
      document.removeEventListener('keydown', key, true);
      if (!go) { after(); return; }
      yes.disabled = true; yes.textContent = verb + '\u2026';
      act().then(function () { after(); }, function (e) { done = false; yes.disabled = false; yes.textContent = verb; err.hidden = false; err.textContent = 'failed: ' + e.message; document.addEventListener('keydown', key, true); });
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

  // ---- map ----
  var mapLibP = null;
  function mapLib() {
    if (window.maplibregl) return Promise.resolve();
    if (mapLibP) return mapLibP;
    var l = document.createElement('link'); l.rel = 'stylesheet'; l.href = 'https://unpkg.com/maplibre-gl@5/dist/maplibre-gl.css'; document.head.appendChild(l);
    mapLibP = new Promise(function (res, rej) { var s = document.createElement('script'); s.src = 'https://unpkg.com/maplibre-gl@5/dist/maplibre-gl.js'; s.onload = res; s.onerror = function () { rej(new Error('maplibre did not load')); }; document.head.appendChild(s); });
    return mapLibP;
  }
  function mountMap(root, opts) {
    css();
    var box = el('div', 'it'), filters = el('div', 'it-filters'), wrap = el('div', 'it-map'), mc = el('div', 'mapc');
    // The workspace asks content which axes it pans before claiming a swipe:
    // maplibre drags the map in both, and the filter strip scrolls sideways,
    // so neither should be taken for a pane swipe. The dots still move between
    // panes while you are on a map.
    mc.dataset.pan = 'xy';
    filters.dataset.pan = 'x';
    wrap.appendChild(mc); box.append(filters, wrap); root.appendChild(box);
    var map = null, ready = false, markers = {}, hidden = {}, doc = null, dead = false, popup = null, pending = null;
    function closePopup() { if (popup) { popup.remove(); popup = null; } }
    function popupDom(pin) {
      var d = el('div', 'it-pop'); d.appendChild(el('div', 'pn', pin.name || ''));
      if (pin.desc) d.appendChild(el('div', 'pd', pin.desc));
      if (pin.notes) { var n = el('div', 'pnotes'); n.innerHTML = md(pin.notes); d.appendChild(n); }
      if (pin.from && pin.from.length) d.appendChild(el('div', 'pf', pin.from.join(', ')));
      return d;
    }
    function openPopup(pin) { closePopup(); popup = new maplibregl.Popup({ offset: 12, maxWidth: '260px' }).setLngLat([pin.lng, pin.lat]).setDOMContent(popupDom(pin)).addTo(map); }
    function drawFilters() {
      filters.textContent = '';
      var k = cats(doc), keys = Object.keys(k);
      filters.hidden = !keys.length;
      keys.forEach(function (key) {
        var b = el('button', 'it-chip' + (hidden[key] ? ' off' : ''), k[key].label); b.style.borderColor = k[key].color; b.style.color = k[key].color;
        b.title = 'click: toggle · shift-click: only this one';
        b.onclick = function (e) {
          if (e.shiftKey) { var solo = !hidden[key] && keys.every(function (x) { return x === key || hidden[x]; }); hidden = {}; if (!solo) keys.forEach(function (x) { if (x !== key) hidden[x] = true; }); }
          else if (hidden[key]) delete hidden[key]; else hidden[key] = true;
          drawFilters(); drawMarkers(); drawZones();
        };
        filters.appendChild(b);
      });
    }
    function drawMarkers() {
      Object.keys(markers).forEach(function (id) { markers[id].remove(); }); markers = {};
      if (!map || !doc) return;
      var pins = doc.pins || {};
      Object.keys(pins).forEach(function (id) {
        var p = pins[id]; if (hidden[p.cat] || typeof p.lng !== 'number' || typeof p.lat !== 'number') return;
        var e = el('div', 'it-pin'); e.style.background = catColor(doc, p.cat);
        e.addEventListener('click', function (ev) { ev.stopPropagation(); openPopup(p); });
        markers[id] = new maplibregl.Marker({ element: e }).setLngLat([p.lng, p.lat]).addTo(map);
      });
    }
    function drawZones() {
      if (!ready || !doc) return;
      var feats = [], zones = doc.zones || {};
      Object.keys(zones).forEach(function (id) {
        var z = zones[id]; if (hidden[z.cat] || !z.points || z.points.length < 3) return;
        var ring = z.points.map(function (p) { return [p[1], p[0]]; }); ring.push(ring[0]);
        feats.push({ type: 'Feature', properties: { id: id, color: catColor(doc, z.cat) }, geometry: { type: 'Polygon', coordinates: [ring] } });
      });
      map.getSource('zones').setData({ type: 'FeatureCollection', features: feats });
    }
    function fit() {
      if (!map || !doc) return;
      var b = new maplibregl.LngLatBounds();
      Object.keys(doc.pins || {}).forEach(function (id) { var p = doc.pins[id]; if (typeof p.lng === 'number') b.extend([p.lng, p.lat]); });
      Object.keys(doc.zones || {}).forEach(function (id) { (doc.zones[id].points || []).forEach(function (pt) { b.extend([pt[1], pt[0]]); }); });
      if (!b.isEmpty()) map.fitBounds(b, { padding: 70, maxZoom: 15, animate: false });
      else if (doc.center && doc.center.length === 2) map.jumpTo({ center: [doc.center[1], doc.center[0]], zoom: doc.zoom || 13 });
    }
    function focus(id) {
      var p = doc && (doc.pins || {})[id]; if (!p || !map) return;
      map.flyTo({ center: [p.lng, p.lat], zoom: Math.max(map.getZoom(), 16) });
      openPopup(p);
      var m = markers[id]; if (m) { var e = m.getElement(); e.classList.remove('pulse'); void e.offsetWidth; e.classList.add('pulse'); setTimeout(function () { e.classList.remove('pulse'); }, 1800); }
    }
    var onFocus = function (ev) { if (ev.detail && ev.detail.doc === docOf(opts.url)) { if (doc) focus(ev.detail.pin); else pending = ev.detail.pin; } };
    window.addEventListener('itin-focus', onFocus);
    var fitted = false;
    function redraw() { if (dead) return; drawFilters(); drawMarkers(); drawZones(); if (!fitted && map && doc) { fit(); fitted = true; } if (pending && doc) { focus(pending); pending = null; } }
    Promise.all([mapLib(), get(docOf(opts.url))]).then(function (r) {
      if (dead) return;
      doc = r[1];
      map = new maplibregl.Map({ container: mc, style: 'https://tiles.openfreemap.org/styles/liberty', center: [0, 0], zoom: 2, attributionControl: { compact: true }, preserveDrawingBuffer: true });   // readable canvas: a snap of this pane shows the map
      // the keyboard lands on the map's canvas when the pane is chosen by
      // keyboard (the host's focusContent reads data-focus); maplibre's own
      // keys then apply: arrows pan, + - zoom, shift+arrows rotate and
      // pitch. The canvas is what maplibre focuses, so the mark goes there
      var canvas = map.getCanvas(); canvas.setAttribute('data-focus', ''); canvas.tabIndex = 0;
      mc._map = map;                                                 // the instance, for a hand at the console
      // ⌘-arrows: ↑↓ zoom (maplibre's own + and - stay), ←→ pan the same as
      // the bare arrows, so a hand holding ⌘ for zoom can steer without
      // letting go. A chord with the modifier the host never claims
      canvas.addEventListener('keydown', function (e) {
        if (!e.metaKey || e.ctrlKey || e.altKey) return;
        if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
          e.preventDefault(); e.stopPropagation();
          map.easeTo({ zoom: map.getZoom() + (e.key === 'ArrowUp' ? 1 : -1) * (e.shiftKey ? 2 : 1), duration: 300 });
        } else if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
          e.preventDefault(); e.stopPropagation();
          map.panBy([(e.key === 'ArrowRight' ? 100 : -100), 0], { duration: 300 });
        }
      });
      canvas.title = 'arrows pan \u00b7 + \u2212 or \u2318\u2191 \u2318\u2193 zoom \u00b7 shift+arrows rotate and pitch';
      map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right');
      map.on('load', function () {
        map.addSource('zones', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } });
        map.addLayer({ id: 'zones-fill', type: 'fill', source: 'zones', paint: { 'fill-color': ['get', 'color'], 'fill-opacity': 0.07 } });
        map.addLayer({ id: 'zones-line', type: 'line', source: 'zones', paint: { 'line-color': ['get', 'color'], 'line-width': 1.5, 'line-dasharray': [2, 2] } });
        ready = true; redraw();
      });
      if (window.ResizeObserver) new ResizeObserver(function () { if (map) map.resize(); }).observe(mc);
      redraw();
    }).catch(function (e) { if (!dead) wrap.appendChild(el('div', 'it-err', 'map: ' + e.message)); });
    return {
      destroy: function () { dead = true; window.removeEventListener('itin-focus', onFocus); closePopup(); if (map) { try { map.remove(); } catch (e) {} } box.remove(); },
      onUpdate: function (ev) { if (ev && ev.body && typeof ev.body === 'object') { doc = ev.body; redraw(); } else get(docOf(opts.url)).then(function (d) { doc = d; redraw(); }).catch(function () {}); }
    };
  }

  // ---- trip: description, dates, zones ----
  function mountTrip(root, opts) {
    var p = docPane(root, opts, function (box, doc) {
      box.textContent = '';
      var body = el('div', 'body'); box.appendChild(body);
      var ds = doc.dates || {}, meta = [];
      if (ds.start || ds.end) meta.push((ds.start || '?') + ' → ' + (ds.end || '?'));
      if (doc.tz) meta.push(doc.tz);
      if (meta.length) body.appendChild(el('div', 'it-meta', meta.join('  ·  ')));
      var m = el('div', 'it-md'); if (doc.desc) m.innerHTML = md(doc.desc); else { m.textContent = 'No description yet.'; m.style.color = '#8b949e'; } body.appendChild(m);
      var zones = doc.zones || {}, zids = Object.keys(zones).sort(function (a, b) { return (zones[a].name || '').localeCompare(zones[b].name || ''); });
      if (zids.length) {
        var sec = el('div', 'it-sec'); sec.appendChild(el('span', null, 'Zones')); sec.appendChild(el('span', 'n', String(zids.length))); body.appendChild(sec);
        zids.forEach(function (id) { var z = zones[id]; var r = el('div', 'it-row'); var d = el('span', 'it-dot zone'); d.style.borderColor = catColor(doc, z.cat); var main = el('div', 'main'); main.appendChild(el('div', 'name', z.name || id)); if (z.desc) main.appendChild(el('div', 'sub', z.desc)); r.append(d, main); body.appendChild(r); });
      }
    });
    return p.handle;
  }

  // the keys every navigator has (nav-keys.js) on a pane that redraws from
  // the stream: rows carry a key (_key), and the cursor is put back on the
  // same key after a redraw, so Enter on a to-do (which writes the doc and
  // redraws) leaves the cursor where it was
  //
  // Delete / Backspace on the cursored row arms its removal (the row says
  // so); Enter then removes it, any other key backs out. The pane host's
  // close works the same way. `remove(row)` writes the doc; the redraw
  // puts the cursor on the row that took its place.
  function keyedNav(box, rowSel, open, remove) {
    if (!window.navKeys) return null;
    var nk = window.navKeys(box, { rows: function () { return Array.prototype.slice.call(box.querySelectorAll(rowSel)); }, open: open });
    var last = null, armed = null, pinned = false;
    function disarm() { if (!armed) return; armed.classList.remove('it-armed'); var l = armed.querySelector('.it-arm'); if (l) l.remove(); armed = null; }
    function arm(row) { disarm(); armed = row; row.classList.add('it-armed'); row.appendChild(el('span', 'it-arm', 'delete? ⏎ / esc')); }
    if (remove) box.addEventListener('keydown', function (e) {
      if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      if (armed) {
        e.preventDefault(); e.stopImmediatePropagation();
        var row = armed, l = row.querySelector('.it-arm');
        armed = null; row.classList.remove('it-armed');
        if (e.key !== 'Enter') { if (l) l.remove(); return; }
        var rs = Array.prototype.slice.call(box.querySelectorAll(rowSel)), i = rs.indexOf(row);
        var next = rs[i + 1] || rs[i - 1]; last = next ? next._key : null; pinned = true;   // the cursor lands on the neighbour
        if (l) { l.textContent = ''; l.appendChild(el('span', 'it-spin')); }   // the label becomes the spinner
        row.classList.add('busy');
        Promise.resolve(remove(row)).catch(function () {
          pinned = false; if (l) { l.textContent = 'failed'; setTimeout(function () { l.remove(); }, 1600); }
          flashFail(row);
        });
        return;
      }
      if (e.key !== 'Delete' && e.key !== 'Backspace') return;
      var c = nk.cursor(); if (!c) return;
      e.preventDefault(); e.stopImmediatePropagation();
      arm(c);
    }, true);
    nk.remember = function () { var c = nk.cursor(); if (armed) return; if (pinned) { pinned = false; return; } last = c ? c._key : last; };
    nk.pin = function (k) { last = k; pinned = true; };   // the cursor for the next redraw, whatever it is now
    nk.restore = function () {
      armed = null;
      nk.mark();
      if (!last) return;
      var rs = Array.prototype.slice.call(box.querySelectorAll(rowSel));
      for (var i = 0; i < rs.length; i++) if (rs[i]._key === last) { nk.setCursor(rs[i]); return; }
    };
    return nk;
  }

  // ---- todos ----
  function mountTodos(root, opts) {
    var id = tripIdOf(opts.url);
    var p = docPane(root, opts, function (box, doc) {
      if (nk) nk.remember();
      // a redraw while typing a new to-do keeps the box and its draft
      var ae = document.activeElement, typing = !!(ae && ae.classList && ae.classList.contains('it-new') && box.contains(ae)), draft = typing ? ae.value : '';
      box.textContent = '';
      var body = el('div', 'body'); box.appendChild(body);
      var todos = doc.todos || {}, ids = Object.keys(todos);
      ids.sort(function (x, y) { var a = todos[x], b = todos[y]; if (!!a.done !== !!b.done) return a.done ? 1 : -1; return (a.text || '').localeCompare(b.text || ''); });
      if (!ids.length) body.appendChild(el('div', 'it-empty', 'nothing on the list'));
      ids.forEach(function (tid) {
        var t = todos[tid]; var row = el('label', 'it-todo' + (t.done ? ' done' : ''));
        var cb = el('input'); cb.type = 'checkbox'; cb.checked = !!t.done;
        // toggle: the spinner stands in for the checkbox until the doc is back
        cb.onchange = function () {
          row.classList.add('busy'); row.insertBefore(el('span', 'it-spin'), cb);
          t.done = cb.checked;
          p.state.commit(putDoc(id, doc), function () { t.done = !t.done; cb.checked = t.done; }).catch(function () { flashFail(row); });
        };
        var x = el('span', 'x', '×');
        x.onclick = function (e) { e.preventDefault(); row.classList.add('busy'); row.appendChild(el('span', 'it-spin')); delete doc.todos[tid]; p.state.commit(putDoc(id, doc)).catch(function () { flashFail(row); }); };
        row.append(cb, el('span', 't', t.text || ''), x); body.appendChild(row);
        row._key = tid;
        row._open = function () { cb.checked = !cb.checked; cb.onchange(); };   // Enter toggles
      });
      // the add box. Enter adds and puts the cursor on the new to-do, back in
      // the list; shift-Enter adds and stays here for another; Esc returns to
      // the list; Tab from the list reaches it
      var nrow = el('div', 'it-new-row'), inp = el('input', 'it-new'); inp.placeholder = 'Add a to-do…'; inp.spellcheck = false;
      inp.title = '⏎ adds, back to the list · ⇧⏎ adds and stays for another · esc back to the list';
      inp.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); inp.value = ''; if (nk) nk.focus(); return; }
        if (e.key !== 'Enter') return;
        e.preventDefault(); e.stopPropagation();
        var v = inp.value.trim();
        if (!v) { if (!e.shiftKey && nk) nk.focus(); return; }
        var tid = 't-' + Date.now().toString(36);
        doc.todos = doc.todos || {}; doc.todos[tid] = { text: v, done: false };
        inp.value = ''; inp.classList.remove('fail'); nrow.appendChild(el('span', 'it-spin'));
        if (!e.shiftKey && nk) { nk.pin(tid); nk.focus(); }
        p.state.commit(putDoc(id, doc), function () { delete doc.todos[tid]; }).catch(function () { inp.classList.add('fail'); inp.value = v; var s = nrow.querySelector('.it-spin'); if (s) s.remove(); });
      });
      nrow.appendChild(inp); box.appendChild(nrow);
      if (typing) { inp.value = draft; inp.focus(); }
      if (nk) nk.restore();
    });
    var nk = keyedNav(p.box, '.it-todo', function (row) { if (row._open) row._open(); }, function (row) { var d = p.state.doc; if (!d || !d.todos) return; var was = d.todos[row._key]; delete d.todos[row._key]; return p.state.commit(putDoc(id, d), function () { d.todos[row._key] = was; }); });
    var h = p.handle, d = h.destroy; h.destroy = function () { if (nk) nk.destroy(); d(); };
    return h;
  }

  // ---- places: pins by category ----
  function mountPlaces(root, opts) {
    var open = {};
    var p = docPane(root, opts, function (box, doc) {
      box.textContent = '';
      var body = el('div', 'body'); box.appendChild(body);
      var pins = doc.pins || {}, groups = {};
      Object.keys(pins).forEach(function (id) { var c = pins[id].cat; (groups[c] = groups[c] || []).push(id); });
      var keys = Object.keys(groups).sort(function (a, b) { return catLabel(doc, a).localeCompare(catLabel(doc, b)); });
      if (!keys.length) body.appendChild(el('div', 'it-empty', 'no pins yet'));
      keys.forEach(function (c) {
        var sec = el('div', 'it-sec'); var d = el('span', 'it-dot'); d.style.background = catColor(doc, c); sec.append(d, el('span', null, catLabel(doc, c)), el('span', 'n', String(groups[c].length))); body.appendChild(sec);
        groups[c].sort(function (a, b) { return (pins[a].name || '').localeCompare(pins[b].name || ''); }).forEach(function (id) {
          var pin = pins[id]; var r = el('div', 'it-row'); var dot = el('span', 'it-dot'); dot.style.background = catColor(doc, pin.cat);
          var main = el('div', 'main'); main.appendChild(el('div', 'name', pin.name || id)); if (pin.desc) main.appendChild(el('div', 'sub', pin.desc)); r.append(dot, main);
          r._open = function () { focusPin(opts.url, id); if (pin.notes) { open[id] = !open[id]; p.state.redraw(); } };
          r.addEventListener('click', function () { r._open(); });
          body.appendChild(r);
          if (pin.notes && open[id]) { var n = el('div', 'it-notes'); n.innerHTML = md(pin.notes); body.appendChild(n); }
        });
      });
      if (nk) nk.mark();
    });
    var nk = window.navKeys ? window.navKeys(p.box, { rows: function () { return Array.prototype.slice.call(p.box.querySelectorAll('.it-row')); }, open: function (row) { if (row._open) row._open(); } }) : null;
    var h = p.handle, d = h.destroy; h.destroy = function () { if (nk) nk.destroy(); d(); };
    return h;
  }

  // ---- events: scheduled, then unscheduled ----
  function schedCat(doc, s) { return (s.pin && doc.pins && doc.pins[s.pin]) ? doc.pins[s.pin].cat : ''; }
  function schedColor(doc, s) { var c = schedCat(doc, s); return c ? catColor(doc, c) : '#5b6470'; }
  function whenText(s, long) {
    if (!s.date) return 'unscheduled';
    var d = new Date(s.date + 'T12:00:00');
    return d.toLocaleDateString(undefined, long ? { weekday: 'long', month: 'long', day: 'numeric' } : { weekday: 'short', month: 'short', day: 'numeric' }) + (s.start ? ' · ' + s.start + (s.end ? '–' + s.end : '') : '');
  }
  function eventCard(doc, id, s, url) {
    var c = el('div', 'it-card' + (s.status === 'tentative' ? ' tentative' : '')); c.style.setProperty('--sc', schedColor(doc, s));
    var h = el('div', 'h'); var sc = schedCat(doc, s); if (sc) { var d = el('span', 'it-dot'); d.style.background = catColor(doc, sc); d.style.marginTop = '0'; h.appendChild(d); }
    h.appendChild(el('span', 't', s.title || id)); h.appendChild(el('span', 'it-badge' + (s.status === 'tentative' ? ' tentative' : ''), s.status || 'fixed')); c.appendChild(h);
    c.appendChild(el('div', 'w', whenText(s)));
    if (s.notes) c.appendChild(el('div', 'n', s.notes));
    if (s.pin) c.addEventListener('click', function () { focusPin(url, s.pin); });
    c._key = id;
    c._open = function () { if (s.pin) focusPin(url, s.pin); };   // Enter: the map flies to its place
    return c;
  }
  function mountEvents(root, opts) {
    var p = docPane(root, opts, function (box, doc) {
      if (nk) nk.remember();
      box.textContent = '';
      var body = el('div', 'body'); box.appendChild(body);
      var sched = doc.schedule || {}, ids = Object.keys(sched);
      ids.sort(function (x, y) { var a = sched[x], b = sched[y]; var ka = (a.date || '9999') + (a.start || '99:99'), kb = (b.date || '9999') + (b.start || '99:99'); return ka < kb ? -1 : ka > kb ? 1 : (a.title || '').localeCompare(b.title || ''); });
      var dated = ids.filter(function (i) { return sched[i].date; }), undated = ids.filter(function (i) { return !sched[i].date; });
      var s1 = el('div', 'it-sec'); s1.append(el('span', null, 'Scheduled'), el('span', 'n', String(dated.length))); body.appendChild(s1);
      if (!dated.length) body.appendChild(el('div', 'it-empty', 'nothing on the calendar yet'));
      dated.forEach(function (i) { body.appendChild(eventCard(doc, i, sched[i], opts.url)); });
      var s2 = el('div', 'it-sec'); s2.style.marginTop = '8px'; s2.append(el('span', null, 'Unscheduled'), el('span', 'n', String(undated.length))); body.appendChild(s2);
      if (!undated.length) body.appendChild(el('div', 'it-empty', 'no unscheduled events'));
      undated.forEach(function (i) { body.appendChild(eventCard(doc, i, sched[i], opts.url)); });
      if (nk) nk.restore();
    });
    var id = tripIdOf(opts.url);
    var nk = keyedNav(p.box, '.it-card', function (row) { if (row._open) row._open(); }, function (row) { var d = p.state.doc; if (!d || !d.schedule) return; var was = d.schedule[row._key]; delete d.schedule[row._key]; return p.state.commit(putDoc(id, d), function () { d.schedule[row._key] = was; }); });
    var h = p.handle, d = h.destroy; h.destroy = function () { if (nk) nk.destroy(); d(); };
    return h;
  }

  // ---- schedule: the week grid ----
  var H0 = 7, H1 = 24, PX = 44;
  function isoDay(d) { return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); }
  function minutes(t) { var m = /^(\d{1,2}):(\d{2})$/.exec(t || ''); return m ? (+m[1]) * 60 + (+m[2]) : null; }
  function dayList(doc) {
    var ds = doc.dates || {}, start = ds.start, end = ds.end;
    if (!start || !end) { var dates = Object.values(doc.schedule || {}).map(function (s) { return s.date; }).filter(Boolean).sort(); start = start || dates[0]; end = end || dates[dates.length - 1]; if (!start) return []; end = end || start; }
    var out = [], d = new Date(start + 'T12:00:00'), stop = new Date(end + 'T12:00:00');
    while (d <= stop && out.length < 31) { out.push(isoDay(d)); d.setDate(d.getDate() + 1); }
    return out;
  }
  function mountSchedule(root, opts) {
    var p = docPane(root, opts, function (box, doc) {
      if (nk) nk.remember();
      box.textContent = '';
      var list = dayList(doc), sched = doc.schedule || {}, today = isoDay(new Date());
      if (!list.length) { box.appendChild(el('div', 'it-empty', 'no dates set for this trip, and nothing scheduled: set dates (write_field dates, or the trip tab) to see the week')); return; }
      // the header says WHEN: the trip, its span as month(s) and year, its zone
      var d0 = new Date(list[0] + 'T12:00:00'), d1 = new Date(list[list.length - 1] + 'T12:00:00');
      var span = d0.getMonth() === d1.getMonth() && d0.getFullYear() === d1.getFullYear()
        ? d0.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })
        : d0.toLocaleDateString(undefined, { month: 'short', year: d0.getFullYear() !== d1.getFullYear() ? 'numeric' : undefined }) + ' \u2013 ' + d1.toLocaleDateString(undefined, { month: 'short', year: 'numeric' });
      var head = el('div', 'it-shead'); head.append(el('span', 't', doc.name || 'Schedule'), el('span', 'm', span)); if (doc.tz) head.appendChild(el('span', 'z', doc.tz)); box.appendChild(head);
      var scroll = el('div', 'it-sched'), days = el('div', 'days'); scroll.appendChild(days); box.appendChild(scroll);
      var maxAll = 0; list.forEach(function (date) { var n = Object.keys(sched).filter(function (i) { return sched[i].date === date && minutes(sched[i].start) === null; }).length; if (n > maxAll) maxAll = n; });
      var allH = maxAll ? maxAll * 27 + 6 : 0, bodyH = (H1 - H0) * PX;
      var g = el('div', 'gutter'); var gh = el('div', 'chead'); gh.innerHTML = '&nbsp;'; g.appendChild(gh); var ga = el('div', 'allday'); ga.style.height = allH + 'px'; g.appendChild(ga);
      var gb = el('div', 'gbody'); gb.style.height = bodyH + 'px'; for (var hh = H0 + 1; hh < H1; hh++) { var gl = el('div', 'ghour', hh + ':00'); gl.style.top = ((hh - H0) * PX - 7) + 'px'; gb.appendChild(gl); } g.appendChild(gb); days.appendChild(g);
      list.forEach(function (date) {
        var col = el('div', 'col' + (date === today ? ' today' : '')), d = new Date(date + 'T00:00:00');
        // the month rides the first column and any column where it changes
        var prev = list[list.indexOf(date) - 1], newMonth = !prev || new Date(prev + 'T12:00:00').getMonth() !== d.getMonth();
        var head = el('div', 'chead'); head.innerHTML = '<span class="dow">' + d.toLocaleDateString(undefined, { weekday: 'short' }) + '</span><span class="dom">' + d.getDate() + '</span>' + (newMonth ? '<span class="mon">' + d.toLocaleDateString(undefined, { month: 'short' }) + '</span>' : ''); col.appendChild(head);
        var all = el('div', 'allday'); all.style.height = allH + 'px'; col.appendChild(all);
        var body = el('div', 'cbody'); body.style.height = bodyH + 'px';
        Object.keys(sched).forEach(function (id) {
          var s = sched[id]; if (s.date !== date) return;
          var m0 = minutes(s.start), b = el('div', 'blk' + (s.status === 'tentative' ? ' tentative' : '')); b.style.setProperty('--sc', schedColor(doc, s));
          b.appendChild(el('div', 'bt', s.title || id)); if (s.start) b.appendChild(el('div', 'bm', s.start + (s.end ? '–' + s.end : '')));
          b.title = (s.title || id) + '\n' + whenText(s, true) + (s.notes ? '\n\n' + s.notes : '');
          if (s.pin) b.addEventListener('click', function () { focusPin(opts.url, s.pin); });
          b._key = id;
          b._open = function () { if (s.pin) focusPin(opts.url, s.pin); };
          if (m0 === null) all.appendChild(b);
          else { var m1 = minutes(s.end), top = ((m0 / 60) - H0) * PX, hgt = m1 !== null ? Math.max(24, ((m1 - m0) / 60) * PX - 2) : 32; b.style.top = Math.max(0, top) + 'px'; b.style.height = hgt + 'px'; b.classList.add('timed'); body.appendChild(b); }
        });
        col.appendChild(body); days.appendChild(col);
      });
      if (nk) nk.restore();
    });
    var id = tripIdOf(opts.url);
    var nk = keyedNav(p.box, '.blk', function (row) { if (row._open) row._open(); }, function (row) { var d = p.state.doc; if (!d || !d.schedule) return; var was = d.schedule[row._key]; delete d.schedule[row._key]; return p.state.commit(putDoc(id, d), function () { d.schedule[row._key] = was; }); });
    var h = p.handle, d = h.destroy; h.destroy = function () { if (nk) nk.destroy(); d(); };
    return h;
  }

  window.Viewers = window.Viewers || {};
  window.Viewers['itin-trips'] = { label: 'trips', mount: mountTrips };
  window.Viewers['itin-map'] = { label: 'map', mount: mountMap };
  window.Viewers['itin-trip'] = { label: 'trip', mount: mountTrip };
  window.Viewers['itin-todos'] = { label: 'todos', mount: mountTodos };
  window.Viewers['itin-places'] = { label: 'places', mount: mountPlaces };
  window.Viewers['itin-events'] = { label: 'events', mount: mountEvents };
  window.Viewers['itin-schedule'] = { label: 'schedule', mount: mountSchedule };
})();
