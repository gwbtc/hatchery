// Files tab — the shared file-manager (lib/ui/file-manager.js) fenced to
// this trip's files/. The lib owns the markup, styling, viewer and every
// server call; this file only tells it which directory is the trip's and
// re-fences it when the trip changes. Mounts lazily: the listing is
// fetched the first time the tab is actually shown.
'use strict';

(function () {
  // the file manager speaks the kernel's file API, which takes absolute
  // paths. This app may live under /apps or under a desk, so it asks the
  // server where it is (resolved by name through /sys/link) and builds
  // the trip's files/ URL from that.
  var ITINS = null;
  var rootReady = fetch('/grubbery/itinerary/api/root')
    .then(function (r) { return r.json(); })
    .then(function (j) { ITINS = '/grubbery/ball' + j.root + '/itineraries'; })
    .catch(function () { ITINS = null; });
  var mount = document.getElementById('files-mount');
  var fm = FileManager.mount(mount, { persist: 'itin-files-view', rootLabel: 'files', lazy: true });
  var loaded = false;

  function visible() { return mount.offsetParent !== null; }
  function bind() {
    var id = window.currentId;
    loaded = false;
    Promise.all([fm.ready, rootReady]).then(function () {
      fm.setRoot(id && ITINS ? ITINS + '/' + encodeURIComponent(id) + '/files' : null);
      if (id && ITINS && visible()) { loaded = true; fm.load(); }
    });
  }
  window.addEventListener('itin-changed', bind);
  document.getElementById('side-tabs').addEventListener('tg-change', function (e) {
    if (e.detail.label === 'Files' && window.currentId && !loaded) { loaded = true; fm.load(); }
  });
  if (window.currentId) bind();
})();
