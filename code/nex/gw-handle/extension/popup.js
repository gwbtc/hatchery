const $ = (id) => document.getElementById(id);
const send = (msg) => chrome.runtime.sendMessage(msg);

let cfg = { endpoint: '', enabled: {}, last: {} };
let counts = {};

function status(text, err = false) {
  $('status').textContent = text;
  $('status').className = err ? 'err' : '';
}

function render() {
  const q = $('filter').value.trim().toLowerCase();
  const ul = $('domains');
  ul.innerHTML = '';
  // union of domains that have cookies and domains armed with none yet
  const all = new Set([...Object.keys(counts), ...Object.keys(cfg.enabled)]);
  const names = [...all].filter((d) => !q || d.includes(q));
  // enabled first, then alphabetical
  names.sort((a, b) => (!!cfg.enabled[b] - !!cfg.enabled[a]) || a.localeCompare(b));
  for (const d of names.slice(0, 300)) {
    const li = document.createElement('li');
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = !!cfg.enabled[d];
    cb.addEventListener('change', async () => {
      const r = await send({ type: 'set-enabled', domain: d, on: cb.checked });
      if (cb.checked) status(r.ok ? `synced ${d}` : `${d}: ${r.error}`, !r.ok);
      await load();
    });
    const name = document.createElement('span');
    name.className = 'd' + (cfg.enabled[d] ? ' on' : '');
    name.textContent = d;
    const n = document.createElement('span');
    n.className = 'n';
    n.textContent = counts[d] ? counts[d] : (cfg.enabled[d] ? 'armed' : '0');
    li.append(cb, name, n);
    const last = cfg.last[d];
    if (cfg.enabled[d] && last) {
      const l = document.createElement('span');
      l.className = 'last' + (last.ok ? '' : ' err');
      l.textContent = last.ok ? new Date(last.at).toLocaleTimeString() : (last.error || 'error');
      li.append(l);
    }
    ul.append(li);
  }
}

async function load() {
  cfg = await send({ type: 'get-config' });
  counts = await send({ type: 'list-domains' });
  $('endpoint').value = cfg.endpoint;
  render();
}

$('save').addEventListener('click', async () => {
  await send({ type: 'set-config', endpoint: $('endpoint').value.trim() });
  status('saved');
});
$('test').addEventListener('click', async () => {
  await send({ type: 'set-config', endpoint: $('endpoint').value.trim() });
  const r = await send({ type: 'test-endpoint' });
  status(r.ok ? 'endpoint ok' : `endpoint failed: ${r.error}`, !r.ok);
});
$('sync').addEventListener('click', async () => {
  const r = await send({ type: 'sync-now' });
  const bad = Object.entries(r).filter(([, v]) => !v.ok);
  status(bad.length ? `failed: ${bad.map(([d, v]) => `${d} (${v.error})`).join(', ')}` : `synced ${Object.keys(r).length} domain(s)`, !!bad.length);
  await load();
});
$('filter').addEventListener('input', render);
async function arm() {
  const d = $('add').value.trim().replace(/^https?:\/\//, '').replace(/\/.*$/, '').toLowerCase();
  if (!d) return;
  const r = await send({ type: 'set-enabled', domain: d, on: true });
  status(r.ok ? `armed ${d}` : `${d}: ${r.error}`, !r.ok);
  $('add').value = '';
  await load();
}
$('addbtn').addEventListener('click', arm);
$('add').addEventListener('keydown', (e) => { if (e.key === 'Enter') arm(); });

load();
