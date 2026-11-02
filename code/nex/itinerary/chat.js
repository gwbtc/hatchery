// Chat tab — the trip's clanker, in the page. The pane itself is the
// clanker collection's own viewer (window.Viewers.chat): it reads the
// chat log through the collection's API and sends turns there. This file
// only points it at the right clanker and tells it when the log moved.
//
// Nothing here talks to a backend of ours. A trip's assistant lives in
// @clanker, and this is a window onto it.
'use strict';

(function () {
  var mount = document.getElementById('chat-mount');
  if (!mount) return;
  var pane = null;
  var stream = null;
  var mountedFor = null;

  // the collection's api takes a path under projects/, and adds that
  // prefix itself; the road to the log spells it out in full
  function proj(id) { return '/itinerary/' + id + '.clanker'; }
  function projRoad(id) { return '/projects/itinerary/' + id + '.clanker'; }

  function teardown() {
    if (stream) { stream.close(); stream = null; }
    if (pane && pane.destroy) { try { pane.destroy(); } catch (e) {} }
    pane = null;
    mountedFor = null;
    mount.innerHTML = '';
  }

  // the log the pane reads, and the stream that tells it to re-read
  async function follow(id) {
    var root = await rootOf('clanker');
    if (!root) return null;
    return root + projRoad(id) + '/chats/plan/log.chat-log';
  }

  async function bind() {
    var id = window.currentId;
    if (!id || id === mountedFor) return;
    teardown();
    if (!window.Viewers || !window.Viewers.chat) {
      mount.innerHTML = '<div style="padding:20px;color:#8b949e">chat unavailable</div>';
      return;
    }
    var road = await follow(id);
    if (!road || window.currentId !== id) return;
    mountedFor = id;
    pane = window.Viewers.chat.mount(mount, {
      url: '/grubbery/ball' + road,
      args: { proj: proj(id), chat: 'plan' }
    });
    // every write to the log is a turn arriving
    stream = new EventSource(BALL + '/keep' + road);
    ['old', 'new', 'upd'].forEach(function (what) {
      stream.addEventListener(what + ' /log.chat-log', function () {
        if (pane && pane.onUpdate) pane.onUpdate({ path: 'log.chat-log' });
      });
    });
  }

  window.addEventListener('itin-changed', function () { bind(); });
  document.getElementById('side-tabs').addEventListener('tg-change', function (e) {
    if (e.detail.label === 'Chat') bind();
  });
  if (window.currentId) bind();
})();
