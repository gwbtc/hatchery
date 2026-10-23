// recipe pane: one recipe, as its graph and its aims.
//
// A recipe is a step graph, so the shape belongs in two dimensions: the
// left side draws it, the right side carries the prose. Neither answers
// the other's question: the graph says what shape this is and where a run
// went, the cards say what it actually asks of you.
//
// Layout and drawing are cytoscape's (dagre underneath): ranking, crossing
// minimisation and edge routing are not things to hand-roll the moment a
// recipe stops being a straight line. What stays here is the coupling to
// the cards, which is the part that is actually about recipes.
//
// Conditions are sentences, never edge labels: six of them on a diagram is
// unreadable at any layout quality, so they live in the cards and light up
// when you hover the edge they belong to.
//
// mount(root, {url, args, onNavigate}) -> {destroy, onUpdate}
(function () {
  'use strict';
  window.Viewers = window.Viewers || {};

  // the reserved exits, each its own kind: done ends the run with its
  // output, abort ends it without, ask pauses it on the user. A step
  // offers an exit only by naming it in next, so which exits a step has
  // is part of its shape and each is drawn in its own colour
  var TERM = { done: 1, abort: 1, ask: 1 };
  var SELF = { self: 1, stay: 1 };

  function el(tag, cls) { var e = document.createElement(tag); if (cls) e.className = cls; return e; }
  // an aim is [title, '', ...description]: the first line is the label
  function title(aim) { return (aim && aim.length) ? aim[0] : ''; }
  function body(aim) { return (aim || []).slice(1).join('\n').replace(/^\n+/, ''); }
  // input and output are part of the shape at both levels (the parser
  // refuses a file without them), so they are always drawn: an empty one
  // is the author saying "nothing", shown as a dash rather than dropped
  function ioBlock(input, output) {
    var box = el('div', 'io');
    [['input', input], ['output', output]].forEach(function (p) {
      var row = el('div', 'iorow');
      var k = el('span', 'iok'); k.textContent = p[0];
      var v = el('span', 'iov'); v.textContent = (p[1] && p[1].length) ? p[1].join('\n') : '-';
      row.appendChild(k); row.appendChild(v); box.appendChild(row);
    });
    return box;
  }

  var CSS =
    '.rcp{display:flex;height:100%;min-height:0;font:13px/1.5 -apple-system,BlinkMacSystemFont,sans-serif;color:#1f2328;background:#fff}' +
    '.rcp .graph{flex:none;width:44%;min-width:260px;overflow:hidden;border-right:1px solid #e2e7ee;background:#fbfcfd;position:relative}' +
    '.rcp .stage{position:absolute;inset:0}' +
    '.rcp .hint{position:absolute;z-index:2;left:8px;bottom:6px;font:10px ui-monospace,monospace;color:#b0b8c1;pointer-events:none}' +
    '.rcp .side{flex:1;min-width:0;overflow:auto;padding:14px 16px}' +
    '.rcp h2{margin:0 0 2px;font-size:15px}' +
    '.rcp .lede{color:#57606a;white-space:pre-wrap;margin:0 0 14px}' +
    '.rcp .levels{display:flex;gap:6px;margin:0 0 14px;flex-wrap:wrap;align-items:center}' +
    '.rcp .levels button{all:unset;cursor:pointer;padding:3px 11px;border-radius:7px;font-size:12px;color:#57606a;border:1px solid transparent}' +
    '.rcp .levels button:hover{background:#eaeef2;color:#24292f}' +
    '.rcp .levels button.on{background:#fff;border-color:#d0d7de;color:#24292f;font-weight:600}' +
    '.rcp .card{border:1px solid #e2e7ee;border-radius:8px;padding:10px 12px;margin:0 0 10px;background:#fff}' +
    '.rcp .card.on{border-color:#54aeff;box-shadow:0 0 0 2px #ddf4ff}' +
    '.rcp .card.here{border-color:#116329;box-shadow:0 0 0 2px #dafbe1}' +
    '.rcp .card.retired{opacity:.5}' +
    '.rcp .cname{font:600 12px ui-monospace,SFMono-Regular,Menlo,monospace;color:#24292f}' +
    '.rcp .chips{float:right;display:flex;gap:4px}' +
    '.rcp .chip{font:11px ui-monospace,monospace;color:#57606a;background:#eef1f4;border-radius:5px;padding:1px 7px}' +
    '.rcp .aim{font-weight:600;margin:6px 0 4px}' +
    '.rcp .desc{color:#57606a;white-space:pre-wrap;margin:0 0 8px}' +
    '.rcp .io{display:grid;grid-template-columns:max-content 1fr;gap:2px 10px;margin:0 0 10px;padding:6px 8px;background:#f6f8fa;border-radius:6px}' +
    '.rcp .io.top{margin:0 0 14px}' +
    '.rcp .iorow{display:contents}' +
    '.rcp .iok{font:11px ui-monospace,monospace;color:#8b949e;text-transform:uppercase;letter-spacing:.04em;padding-top:2px}' +
    '.rcp .iov{color:#24292f;white-space:pre-wrap;min-width:0}' +
    '.rcp .arrows{margin:0;padding:6px 0 0;list-style:none;border-top:1px solid #f0f2f5}' +
    '.rcp .arrows li{display:flex;gap:7px;padding:2px 4px;border-radius:5px}' +
    '.rcp .arrows li.on{background:#ddf4ff}' +
    '.rcp .to{font:11px ui-monospace,monospace;color:#0969da;flex:0 0 auto;min-width:5.5rem}' +
    '.rcp .to.back{color:#9a6700}' +
    '.rcp .to.done{color:#116329}' +
    '.rcp .to.ask{color:#9a6700;font-style:italic}' +
    '.rcp .to.abort{color:#cf222e}' +
    '.rcp .cond{color:#57606a;min-width:0}' +
    '.rcp .empty{color:#8b949e;padding:18px}';

  function injectCss() {
    if (document.getElementById('rcp-css')) return;
    var s = el('style'); s.id = 'rcp-css'; s.textContent = CSS;
    document.head.appendChild(s);
  }

  // graph.js is the vendored bundle: dagre, cytoscape, and the adapter that
  // joins them. Loaded once, lazily: only a pane that actually draws a
  // recipe pays for it.
  var GRAPH_URL = '/grubbery/ball/apps/explorer.explorer/graph.js';
  var graphReady = null;
  function loadGraph() {
    if (graphReady) return graphReady;
    graphReady = new Promise(function (ok, no) {
      if (window.cytoscape) return ok();
      var s = document.createElement('script');
      s.src = GRAPH_URL;
      s.onload = function () {
        try { if (window.cytoscape && window.cytoscapeDagre) window.cytoscape.use(window.cytoscapeDagre); } catch (_) {}
        ok();
      };
      s.onerror = function () { no(new Error('graph.js did not load')); };
      document.head.appendChild(s);
    });
    return graphReady;
  }

  // the elements cytoscape lays out and draws. `stay` is not an edge: a
  // self-loop carries one bit and costs a tangle, so it becomes a flag on
  // the node and the condition stays in the card.
  function elements(recipe, caps, run) {
    var steps = recipe.steps || {}, out = [], seenTerm = {};
    var visited = (run && run.spent) || {};
    Object.keys(steps).forEach(function (name) {
      var cap = caps[name] || {};
      out.push({ data: {
        id: name, label: steps[name].recipe ? name + ' ↳ ' + steps[name].recipe : name,
        life: cap.life == null ? 6 : cap.life,
        stay: !!(steps[name].next && (steps[name].next.self || steps[name].next.stay))
      }, classes: [
        run && run.step === name ? 'here' : '',
        visited[name] ? 'visited' : '',
        cap.life === 0 ? 'retired' : '',
        steps[name].recipe ? 'sub' : ''
      ].filter(Boolean).join(' ') });
    });
    Object.keys(steps).forEach(function (from) {
      var nx = steps[from].next || {};
      Object.keys(nx).forEach(function (to) {
        if (SELF[to]) return;
        if (TERM[to]) {
          if (!seenTerm[to]) { seenTerm[to] = 1; out.push({ data: { id: 't:' + to, label: to }, classes: 'term ' + to }); }
          out.push({ data: { id: from + '>' + to, source: from, target: 't:' + to, cond: nx[to] }, classes: 'toterm ' + to });
          return;
        }
        if (!steps[to]) return;
        out.push({ data: { id: from + '>' + to, source: from, target: to, cond: nx[to] } });
      });
    });
    return out;
  }

  var STYLE = [
    { selector: 'node', style: {
      'label': 'data(label)', 'text-valign': 'center', 'text-halign': 'center',
      'font-family': 'ui-monospace,SFMono-Regular,Menlo,monospace', 'font-size': 11,
      'color': '#24292f', 'shape': 'round-rectangle',
      'background-color': '#fff', 'border-color': '#57606a', 'border-width': 1.3,
      'width': 'label', 'height': 30, 'padding': '14px',
      'transition-property': 'border-color, background-color', 'transition-duration': '120ms'
    } },
    { selector: 'node.visited', style: { 'background-color': '#eef6ff' } },
    { selector: 'node.here', style: { 'background-color': '#dafbe1', 'border-color': '#116329', 'border-width': 2.5 } },
    { selector: 'node.retired', style: { 'border-color': '#d0d7de', 'color': '#8b949e', 'border-style': 'dashed' } },
    { selector: 'node[?stay]', style: { 'border-style': 'double', 'border-width': 3 } },
    // a step that is a recipe: a box in a box
    { selector: 'node.sub', style: { 'border-style': 'double', 'border-width': 4, 'background-color': '#f6f8fa', 'color': '#0969da' } },
    { selector: 'node.term', style: {
      'shape': 'round-rectangle', 'background-color': '#dafbe1', 'border-color': '#116329',
      'color': '#116329', 'height': 22, 'padding': '10px'
    } },
    { selector: 'node.term.ask', style: { 'shape': 'diamond', 'background-color': '#fff8c5', 'border-color': '#9a6700', 'color': '#9a6700', 'height': 30, 'padding': '12px' } },
    { selector: 'node.term.abort', style: { 'background-color': '#ffebe9', 'border-color': '#cf222e', 'color': '#cf222e' } },
    { selector: 'edge.toterm.ask', style: { 'line-color': '#9a6700', 'target-arrow-color': '#9a6700', 'line-style': 'dotted' } },
    { selector: 'edge.toterm.abort', style: { 'line-color': '#cf222e', 'target-arrow-color': '#cf222e' } },
    { selector: 'edge', style: {
      'width': 1.4, 'line-color': '#9aa4b0', 'target-arrow-color': '#9aa4b0',
      'target-arrow-shape': 'triangle', 'arrow-scale': 0.9,
      'curve-style': 'bezier', 'target-distance-from-node': 3
    } },
    { selector: 'edge.toterm', style: { 'line-color': '#116329', 'target-arrow-color': '#116329' } },
    { selector: 'edge.back', style: { 'line-color': '#bf8700', 'target-arrow-color': '#bf8700', 'line-style': 'dashed' } },
    { selector: 'edge.lit', style: { 'width': 3, 'line-color': '#0969da', 'target-arrow-color': '#0969da' } },
    { selector: 'node.lit', style: { 'border-color': '#0969da', 'border-width': 2.5 } }
  ];

  // cytoscape owns layout (dagre: ranking, crossing minimisation, edge
  // routing) and drawing (styles above). What stays mine is the coupling
  // to the cards, which is what the pane is actually for.
  function draw(host, recipe, caps, run, onPick, onEdge) {
    var cy = window.cytoscape({
      container: host,
      elements: elements(recipe, caps, run),
      style: STYLE,
      wheelSensitivity: 0.2,
      layout: { name: 'dagre', rankDir: 'TB', nodeSep: 42, rankSep: 56, edgeSep: 14 }
    });
    // a return is any edge that ends above where it started, once laid out
    cy.edges().forEach(function (e) {
      if (e.target().position('y') <= e.source().position('y')) e.addClass('back');
    });
    cy.on('mouseover', 'edge', function (e) {
      e.target.addClass('lit');
      onEdge(e.target.data('source'), e.target.data('target').replace(/^t:/, ''), true);
    });
    cy.on('mouseout', 'edge', function (e) {
      e.target.removeClass('lit');
      onEdge(e.target.data('source'), e.target.data('target').replace(/^t:/, ''), false);
    });
    cy.on('tap', 'node', function (e) { onPick(e.target.id()); });
    cy.fit(undefined, 28);
    return cy;
  }

  function mountRecipe(root, opts) {
    injectCss();
    var wrap = el('div', 'rcp'), gpane = el('div', 'graph'), side = el('div', 'side');
    wrap.appendChild(gpane);
    wrap.appendChild(side);
    root.appendChild(wrap);

    var recipe = null, run = null, level = null, cards = {}, cy = null;

    function caps() {
      var lv = (recipe.levels || {})[level];
      return (lv && lv.steps) || {};
    }

    function render() {
      gpane.textContent = '';
      side.textContent = '';
      cards = {};
      if (!recipe || !recipe.steps) {
        var e = el('div', 'empty');
        e.textContent = 'not a recipe: no steps';
        side.appendChild(e);
        return;
      }
      var cp = caps();
      var hint = el('div', 'hint');
      hint.textContent = 'scroll to zoom, drag to pan';
      gpane.appendChild(hint);
      var stage = el('div', 'stage');
      gpane.appendChild(stage);
      loadGraph().then(function () {
        if (!stage.isConnected) return;
        if (cy) { try { cy.destroy(); } catch (_) {} }
        cy = draw(stage, recipe, cp, run, function (n) {
          var c = cards[n];
          if (!c) return;
          Object.keys(cards).forEach(function (k) { cards[k].classList.toggle('on', k === n); });
          c.scrollIntoView({ block: 'nearest' });
        }, function (from, to, on) {
          var c = cards[from];
          if (!c) return;
          var li = c.querySelector('li[data-to="' + to + '"]');
          if (li) li.classList.toggle('on', on);
          if (on) c.scrollIntoView({ block: 'nearest' });
        });
      }).catch(function (err) {
        stage.textContent = '';
        var d = el('div', 'empty');
        d.textContent = 'the graph library did not load: ' + err;
        stage.appendChild(d);
      });

      var h = el('h2');
      h.textContent = recipe.recipe || 'recipe';
      side.appendChild(h);
      var lede = el('div', 'lede');
      lede.textContent = title(recipe.aim) + (body(recipe.aim) ? '\n\n' + body(recipe.aim) : '');
      side.appendChild(lede);
      var top = ioBlock(recipe.input, recipe.output);
      top.classList.add('top');
      side.appendChild(top);

      var lv = Object.keys(recipe.levels || {});
      if (lv.length) {
        var bar = el('div', 'levels');
        lv.forEach(function (k) {
          var b = el('button');
          b.type = 'button';
          b.textContent = k;
          if (k === level) b.className = 'on';
          b.addEventListener('click', function () { level = k; render(); });
          bar.appendChild(b);
        });
        var tot = (recipe.levels[level] || {}).run;
        if (tot != null) {
          var c = el('span', 'chip');
          c.textContent = 'run ' + tot + (run ? ', spent ' + (run.run || 0) : '');
          bar.appendChild(c);
        }
        side.appendChild(bar);
      }

      var order = Object.keys(recipe.steps);
      order.forEach(function (name) {
        var st = recipe.steps[name], cap = cp[name] || {};
        var card = el('div', 'card');
        cards[name] = card;
        if (run && run.step === name) card.classList.add('here');
        if (cap.life === 0) card.classList.add('retired');

        var chips = el('div', 'chips');
        if (cap.dwell != null) {
          var d = el('span', 'chip');
          d.textContent = 'dwell ' + cap.dwell;
          chips.appendChild(d);
        }
        var lf = el('span', 'chip');
        lf.textContent = 'life ' + (cap.life == null ? '-' : cap.life) +
          (run && run.spent && run.spent[name] ? ', spent ' + run.spent[name] : '');
        chips.appendChild(lf);
        card.appendChild(chips);

        var nm = el('div', 'cname');
        nm.textContent = name;
        card.appendChild(nm);
        if (st.recipe) {
          // a recipe-step: the recipe is the aim and the contract; link to it
          var rl = el('a', 'aim');
          rl.textContent = 'runs the recipe ' + st.recipe + ' →';
          rl.href = '#';
          rl.addEventListener('click', function (e) { e.preventDefault(); if (opts.onNavigate) opts.onNavigate('./' + st.recipe + '.json', 'file', { name: st.recipe }); });
          card.appendChild(rl);
        } else {
          var am = el('div', 'aim');
          am.textContent = title(st.aim);
          card.appendChild(am);
          if (body(st.aim)) {
            var de = el('div', 'desc');
            de.textContent = body(st.aim);
            card.appendChild(de);
          }
          card.appendChild(ioBlock(st.input, st.output));
        }

        var ul = el('ul', 'arrows');
        Object.keys(st.next || {}).forEach(function (to) {
          var li = el('li');
          li.setAttribute('data-to', to);
          var a = el('span', 'to');
          if (TERM[to]) a.className = 'to term ' + to;
          else if (!SELF[to] && recipe.steps[to] && order.indexOf(to) < order.indexOf(name)) a.className = 'to back';
          a.textContent = SELF[to] ? 'stay' : to;
          var cd = el('span', 'cond');
          cd.textContent = st.next[to];
          li.appendChild(a);
          li.appendChild(cd);
          ul.appendChild(li);
        });
        card.appendChild(ul);
        side.appendChild(card);
      });
    }

    function load() {
      return fetch(opts.url + '?raw=1', { cache: 'no-store' })
        .then(function (r) { return r.json(); })
        .then(function (j) {
          recipe = j;
          if (!level || !(recipe.levels || {})[level]) {
            var lv = Object.keys(recipe.levels || {});
            level = lv.indexOf('normal') >= 0 ? 'normal' : (lv[0] || null);
          }
          render();
        })
        .catch(function (err) {
          side.textContent = '';
          var d = el('div', 'empty');
          d.textContent = 'could not read this recipe: ' + err;
          side.appendChild(d);
        });
    }

    load();
    return {
      destroy: function () { if (cy) { try { cy.destroy(); } catch (_) {} cy = null; } if (wrap.parentNode) wrap.parentNode.removeChild(wrap); },
      onUpdate: function () { load(); }
    };
  }

  window.Viewers['recipe'] = { label: 'Recipe', mount: mountRecipe };
})();
