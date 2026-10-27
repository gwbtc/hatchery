::  clanker: the chat workspace, a COLLECTION of clankers.
::
::  A clanker is a nexus (./agent.hoon): its standing prompt, memories,
::  skills, its own tools nexus, and its chats, all in its own tree, under
::  a weir that is its scope. The collection is a directory tree, the
::  assistants/usergroups rule: a dir named <name>.clanker IS a clanker
::  (mounted here as an agent nexus); any other dir is a category.
::
::    /projects/                           the collection root
::      grubbery.clanker/                  a clanker (see agent.hoon)
::      work/                              a category
::        hatchery.clanker/
::    /http.sig, /requests/                the page and its API
::    /viewer.js, /chats.js                the panes: a chat, a chats/ list
::
::  This nexus runs no turns. It mounts clankers, keeps the tree, and
::  serves its API; a chat message is a poke to that clanker's own
::  main.sig. The PAGE is the explorer's: /grubbery/clanker serves the
::  explorer's browse page (its <namespace-explorer> component) mounted
::  at this route and rooted at the collection, so /grubbery/clanker/
::  <path> is the explorer at that path. The same declaration points the
::  explorer at /api/viewer, where +pick-viewer says per file which pane
::  it opens in: a chat-log opens in the chat pane (viewer.js) in this
::  explorer, nowhere else. One explorer, one tree, one tab bar.
::
/<  clanker    /lib/clanker.hoon
/<  nex-tools  /lib/tools.hoon
::  the collection's own tools nexus: clankers, chat_status, send,
::  resolve, stop, ensure (what the page's api does, for a tool caller)
/&  coll-tools  /lib/clanker-collection-bundle/
/&  viewer-js   ./viewer.js
/&  chats-js    ./chats.js
/&  recipe-js   ./recipe.js
/<  rcp-lib     /lib/recipe.hoon
/&  icon        ./icon.svg
::  the layouts the explorer opens the collection's dirs as ('./' paths
::  resolve against the dir opened): the collection root or a category
::  (selector | a tab per clanker) and a clanker (its tree | chats, record)
/&  coll-layout     ./collection-layout.json
/&  clanker-layout  ./clanker-layout.json
/&  chat-layout     ./chat-layout.json
::  the nexus root itself (@clanker) opens as the collection, the way
::  @forge opens as the forge: the same selector | tabs, over ./projects
/&  root-layout     ./root-layout.json
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      (spin:loader ball rows)
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  main.sig: the collection's poke protocol (see +handle-poke),
          ::  how another app makes a clanker here by name
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%clanker main: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ;<  ~  bind:m  (handle-poke jon)
        $
          [~ %'http.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%clanker http: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/clanker])
        (http-dispatch:io %clanker)
          [~ %'sand.sig']
        (sand-watch prod)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%clanker request: failed")
        (handle-request name.rail)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'http.sig'])
::  +rows: the on-load tree. %fall for the workspace (seed once, then the
::  tree is the live, user-owned record); %over for product code.
++  rows
  ^-  (list row:loader)
  =/  tile=json
    %-  pairs:enjs:format
    :~  title+s+'Clanker'
        info+s+'Chat workspace, built from inside'
        color+s+'#3d3a45'
        image+s+'/grubbery/tiles/icon/clanker.clanker'
        href+s+'/grubbery/clanker'
    ==
  :~  (manifest:loader 0)
      [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'clanker'] ['description' s+'The grubbery chat workspace']])]]
      [%over %& [/ %'weir.json'] [[/ %json] weir-ask]]
      [%over %& [/ %'tile.json'] [[/ %json] tile]]
      ::  the panes +pick-viewer hands out: a chat-log's chat, a chats/ dir's list
      [%over %& [/ %'viewer.js'] [[/ %mime] viewer-js]]
      [%over %& [/ %'recipe.js'] [[/ %mime] recipe-js]]
      [%over %& [/ %'chats.js'] [[/ %mime] chats-js]]
      [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
      [%over %& [/ %'collection-layout.json'] [[/ %mime] coll-layout]]
      [%over %& [/ %'clanker-layout.json'] [[/ %mime] clanker-layout]]
      [%over %& [/ %'chat-layout.json'] [[/ %mime] chat-layout]]
      [%over %& [/ %'root-layout.json'] [[/ %mime] root-layout]]
      ::  the root declares its own view: the explorer landing ON the nexus
      ::  (by name, @clanker) asks /api/root-viewer and opens the root
      ::  layout; everything under /projects is governed by the
      ::  collection's view.json below, nearest one winning
      [%over %& [/ %'view.json'] [[/ %json] root-view-decl]]
      [%fall %& [/ %'http.sig'] [[/ %sig] ~]]
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      ::  the weir keeper: sands every clanker once on rise and again
      ::  whenever the proxy's name moves (+sand-watch); never per message
      [%fall %& [/ %'sand.sig'] [[/ %sig] ~]]
      [%over %| /tools (seed-tools:nex-tools coll-tools)]
      [%fall %| /requests empty-dir:loader]
      [%fall %| /projects empty-dir:loader]
      ::  the collection declares its views: an explorer rooted at or under
      ::  /projects finds this and asks /api/viewer per path (+pick-viewer)
      [%over %& [/projects %'view.json'] [[/ %json] view-decl]]
      ::  the grubbery clanker: the kernel self-editing tools, a wide weir.
      ::  Seeded without the proxy roads resolved (on-load cannot peek);
      ::  +sand-clanker re-sands it on every send.
      [%fall %| [%projects %'grubbery.clanker' ~] (clanker-bole 'grubbery' 'kernel' grubbery-system (kernel-weir ~) ~)]
  ==
::  +view-decl: /projects/view.json, what the explorer reads (see
::  explorer.hoon +find-view): where to ask which pane a path opens in,
::  and the chrome of an explorer rooted here.
++  view-decl
  ^-  json
  %-  pairs:enjs:format
  :~  ['viewers' s+'/grubbery/clanker/api/viewer']
      ['title' s+'clanker']
      ['icon' s+'/grubbery/clanker/icon.svg']
  ==
::  +root-view-decl: /view.json, the root's own declaration. Its viewers
::  endpoint answers for the root alone (the root layout); the paths under
::  /projects never reach it, the collection's own view.json is nearer.
++  root-view-decl
  ^-  json
  %-  pairs:enjs:format
  :~  ['viewers' s+'/grubbery/clanker/api/root-viewer']
      ['title' s+'clanker']
      ['icon' s+'/grubbery/clanker/icon.svg']
  ==
::  +weir-ask: what this nexus needs to reach: everything. The collection
::  is the container, not the sandbox: each clanker inside it sits under
::  its OWN weir (set when it is made, from its config), and that weir is
::  the bound that matters. Asking for the root once means a clanker's
::  reach can be widened by its host (forge granting a repo clanker its
::  working tree and git lane) without a new permit round every time.
++  weir-ask
  ^-  json
  =/  road  |=([r=@t why=@t] (pairs:enjs:format ~[['road' s+r] ['why' s+why]]))
  %-  pairs:enjs:format
  :~  ['make' a+~[(road '/' 'clankers write where their own weirs allow: kernel source, repo working trees')]]
      ['poke' a+~[(road '/' 'clankers poke where their own weirs allow: the model proxy, git lanes, the kernel')]]
      ['peek' a+~[(road '/' 'clankers read where their own weirs allow')]]
  ==
::
::  Clanker mounts. A clanker dir is an agent nexus: neck [/clanker %agent],
::  a weir that is its scope, and its two seed files; its own on-load lays
::  out the rest (memories/, skills/, chats/, tools/).
::
::  +clanker-config: config.json for a new clanker; `extra` adds the
::  fields a kind of clanker carries beyond the base (a repo clanker's
::  "repo" path and its "roads").
++  clanker-config
  |=  [name=@t bundle=@t extra=(list [@t json])]
  ^-  json
  %-  pairs:enjs:format
  %+  weld
    ^-  (list [@t json])
    :~  ['name' s+name]
        ['model' s+'claude-sonnet-4-6']
        ['max_tokens' (numb:enjs:format 4.096)]
        ['bundle' s+bundle]
    ==
  extra
++  clanker-bole
  |=  [name=@t bundle=@t system=@t =weir:tarball extra=(list [@t json])]
  ^-  bole:tarball
  =/  cfg=json  (clanker-config name bundle extra)
  =|  files=(map @ta [=bask:tarball gain=?])
  =.  files  (~(put by files) %'config.json' [[[/ %json] cfg] %.n])
  ::  the standing prompt lives under prompts/, beside the harness's
  ::  words that the agent's on-load seeds there
  =/  prompts=bole:tarball
    :-  `[~ ~ %.n (malt ~[[%'main.md' [[[/ %mime] [/text/markdown (as-octs:mimes:html system)]] %.n]]])]
    ~
  [`[`[/clanker %agent] `weir %.n files] (malt ~[[%prompts prompts]])]
::  +default-weir: what any clanker may reach outside its own tree: time,
::  the model proxy. Its own tree, its tools and its nested clankers are
::  inside it and need no grant, with one exception: a peek at the
::  clanker DIRECTORY itself crosses its weir (the entry belongs to the
::  parent), and that peek is how a tool finds its clanker (+clanker-up
::  walks up by neck). So the weir names its own directory, relatively:
::  [%| 0 %| /] resolves against the directory the weir sits on.
++  default-weir
  |=  prox=(list path)
  ^-  weir:tarball
  =/  fil  |=([p=path n=@ta] `road:tarball`[%& %& p n])
  =/  dir  |=(p=path `road:tarball`[%& %| p])
  =/  self=road:tarball  [%| 0 %| /]
  ::  every model proxy that resolves gets a road, not only the one this
  ::  clanker's config names: a weir is set per CAUSE, so a config edit
  ::  that switches provider must not have to wait for a re-sand
  =/  mains=(list road:tarball)  (turn prox |=(p=path (fil p 'main.sig')))
  =/  calls=(list road:tarball)  (turn prox |=(p=path (dir (snoc p %calls))))
  ::  and every provider's link registry, by name, so resolve-link works
  ::  for whichever one the config names
  =/  regs=(list road:tarball)
    %+  turn  providers:clanker
    |=  p=provider:clanker
    ^-  road:tarball
    =/  t=tape  (trip link.p)
    =/  nm=@ta  (crip ?:(&(?=(^ t) =('@' i.t)) t.t t))
    (dir (welp /sys/link ~[nm]))
  ::  time (bowl) and TIMERS (behn): a deadline or a sleep in the agent or
  ::  in a tool is a poke to behn; without this road the first timer is
  ::  vetoed and the fiber is parked
  :*  make=~
      poke=(sy (weld ~[(fil /sys 'bowl.sig') (fil /sys/behn 'main.behn-state')] mains))
      peek=(sy :(weld ~[self] regs calls))
  ==
::  +kernel-weir: the grubbery clanker: the default plus the kernel
::  namespace its self-editing tools touch.
++  kernel-weir
  |=  prox=(list path)
  ^-  weir:tarball
  =/  d=weir:tarball  (default-weir prox)
  :*  make=(~(put in make.d) `road:tarball`[%& %| /code])
      poke=(~(put in poke.d) `road:tarball`[%& %| /sys])
      peek=(~(put in peek.d) `road:tarball`[%& %| /])
  ==
::  +proxy-roots: the model proxies, by name, as they resolve now. The
::  anthropic and openrouter nexuses answer the SAME {id, body} protocol
::  and differ only in the dialect of the body, so a clanker needs a road
::  to whichever one its config names. A proxy that is not linked yet
::  simply contributes no road.
++  proxy-roots
  =/  m  (fiber:fiber:nexus ,(list path))
  ^-  form:m
  =|  out=(list path)
  =/  all=(list provider:clanker)  providers:clanker
  |-  ^-  form:m
  ?~  all  (pure:m (flop out))
  ;<  got=(unit lane:tarball)  bind:m  (resolve-link:io link.i.all)
  $(all t.all, out ?.(?=([~ %| *] got) out [p.u.got out]))
::  +config-weir: a clanker's weir from its config: the kernel set for
::  bundle "kernel", the default otherwise, plus the extra roads the
::  config grants it (config.json "roads": {"peek": [...], "make": [...],
::  "poke": [...]}, each a list of "/dir/" (the subtree) or "/dir/file"),
::  e.g. a repo clanker's working tree to read, and for a build clanker to
::  write, and its git lane to poke. Re-applied on every send, so the
::  proxy resolves and the extras survive a config edit.
++  config-weir
  |=  [cfg=json prox=(list path)]
  ^-  weir:tarball
  =/  base=weir:tarball
    ?:(=('kernel' (jstr:clanker cfg 'bundle')) (kernel-weir prox) (default-weir prox))
  =/  roads
    |=  key=@t
    ^-  (list road:tarball)
    ?.  ?=([%o *] cfg)  ~
    =/  rj  (~(get by p.cfg) 'roads')
    ?.  ?=([~ %o *] rj)  ~
    =/  pj  (~(get by p.u.rj) key)
    ?.  ?=([~ %a *] pj)  ~
    %+  murn  p.u.pj
    |=  j=json
    ^-  (unit road:tarball)
    ?.  ?=([%s *] j)  ~
    =/  t=tape  (trip p.j)
    ?~  t  ~
    =/  dir=?  =('/' (rear t))
    =/  pax=(unit path)  (rush (crip ?:(dir (snip `tape`t) t)) stap)
    ?~  pax  ~
    ?:  dir  `[%& %| u.pax]
    ?~  u.pax  ~
    `[%& %& (snip `path`u.pax) (rear u.pax)]
  %=  base
    peek  (~(gas in peek.base) (roads 'peek'))
    make  (~(gas in make.base) (roads 'make'))
    poke  (~(gas in poke.base) (roads 'poke'))
  ==
::  +sand-watch: the weirs are set once per CAUSE, never per message. On
::  every rise, one pass over the collection (+sand-all): a clanker seeded
::  at load was born before the proxy could be resolved (on-load cannot
::  peek), one made before the proxy was installed has no road to it.
::  Then the proxy's registry grub (/sys/link/anthropic/dest.lanes) is
::  kept, and every move of it is another pass. Making a clanker
::  (+handle-poke, /api/new) sands it then. A proxy not yet linked: the
::  keep finds nothing within the lull, so try again later.
++  sand-watch
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  (rise-wait:io prod "%clanker sand: failed")
  ;<  ~  bind:m  sand-all
  |-
  ;<  any=?  bind:m  keep-registries
  ?.  any
    ;<  ~  bind:m  (sleep:io ~m5)
    $
  |-
  ;<  ~  bind:m  (take-news-any registry-wires)
  ;<  ~  bind:m  sand-all
  $
::  +keep-registries: keep EVERY provider's link registry, each on its
::  own wire, so a proxy linked later also triggers a sand pass. Yields
::  whether any of them resolved: none means no proxy is linked yet, so
::  the caller waits and tries again rather than parking forever.
++  keep-registries
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  all=(list provider:clanker)  providers:clanker
  =|  any=?
  |-  ^-  form:m
  ?~  all  (pure:m any)
  ;<  got=(unit wave:nexus)  bind:m
    (keep-soft:io (registry-wire name.i.all) (link-road:io link.i.all) ~ ~s30)
  $(all t.all, any |(any ?=(^ got)))
::
++  registry-wire
  |=  nm=@t
  ^-  wire
  (welp /proxy ~[`@ta`nm])
::
++  registry-wires
  ^-  (list wire)
  (turn providers:clanker |=(p=provider:clanker (registry-wire name.p)))
::  +take-news-any: news on ANY of these wires. The sand pass does not
::  care which registry moved, only that one did.
++  take-news-any
  |=  wires=(list wire)
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?:((lien wires |=(w=wire =(w wire.u.in))) [%done ~] [%skip ~])
  ==
::  +sand-all: every clanker in the collection, at any depth, re-sanded
::  from its config with the proxy as it resolves now. Runs in sand.sig's
::  fiber, at the collection root (up 0).
++  sand-all
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  anth=(list path)  bind:m  proxy-roots
  =/  todo=(list path)  ~[/]
  |-  ^-  form:m
  ?~  todo  (pure:m ~)
  =/  here=path  i.todo
  ;<  dv=view:nexus  bind:m  (peek-shallow:io [%| 0 %| (welp /projects here)] ~)
  ?.  ?=([%ball *] dv)  $(todo t.todo)
  =/  names=(list @ta)  ~(tap in ~(key by dir.ball.dv))
  =/  kids=(list path)  (turn (skip names is-clanker) |=(n=@ta (snoc here n)))
  =/  clankers=(list path)  (turn (skim names is-clanker) |=(n=@ta (snoc here n)))
  ;<  ~  bind:m
    |-  ^-  form:m
    ?~  clankers  (pure:m ~)
    ;<  cfg=json  bind:m  (read-json [%| 0 %& (welp /projects i.clankers) %'config.json'])
    ;<  ~  bind:m  (sand:io [%| 0 %| (welp /projects i.clankers)] `(config-weir cfg anth))
    $(clankers t.clankers)
  $(todo (weld t.todo kids))
::  +sand-clanker: (re)set one clanker's weir from its config with the
::  proxy as it resolves now, when it is made.
++  sand-clanker
  |=  [proj=path cfg=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  anth=(list path)  bind:m  proxy-roots
  (sand:io [%| 1 %| (welp /projects proj)] `(config-weir cfg anth))
::  +handle-poke: the collection's poke protocol, for other apps (forge
::  makes a repo's clanker this way) and for tools. One action for now:
::    {action:'ensure', parent, name, bundle?, system?, repo?,
::     roads?:{peek:[...]}, config?:{...}, chat?, chat_system?,
::     recipes?:[{name, recipe, files?:{name: text}}]}
::  makes the category dirs along parent, the clanker <parent>/<name>.clanker
::  if missing (config, prompt, weir), the named chat (its log, and
::  its own prompt) if missing, and the recipes the host ships, each
::  with the files it ships with, if missing. The HOST'S config fields (bundle, repo,
::  roads, and whatever `config` carries) are re-written into an existing
::  clanker's config.json and its weir re-sanded, so a host that learns a
::  new road or path passes it on; the user's fields (model, max_tokens)
::  and the prompts are never overwritten. Runs in main.sig's own fiber,
::  so roads are relative to the collection root (up 0).
++  handle-poke
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  =('ensure' (jstr:clanker jon 'action'))  (pure:m ~)
  =/  name=@t  (jstr:clanker jon 'name')
  ?:  =('' name)  (pure:m ~)
  =/  parent=path
    (fall (rush =/(p=@t (jstr:clanker jon 'parent') ?:(=('' p) '/' p)) stap) /)
  =/  bundle=@t  =/(b=@t (jstr:clanker jon 'bundle') ?:(=('' b) 'default' b))
  =/  system=@t  (jstr:clanker jon 'system')
  =/  extra=(list [@t json])
    =/  repo=@t  (jstr:clanker jon 'repo')
    =/  roads=(unit json)  ?.(?=([%o *] jon) ~ (~(get by p.jon) 'roads'))
    =/  conf=(unit json)  ?.(?=([%o *] jon) ~ (~(get by p.jon) 'config'))
    ;:  weld
      ?:(=('' repo) ~ ~[['repo' s+repo]])
      ?~(roads ~ ~[['roads' u.roads]])
      ?.(?=([~ %o *] conf) ~ ~(tap by p.u.conf))
    ==
  ::  the category dirs along parent
  ;<  ~  bind:m
    =/  mu  (fiber:fiber:nexus ,~)
    =/  at=path  /projects
    =/  rest=path  parent
    |-  ^-  form:mu
    ?~  rest  (pure:mu ~)
    =/  here=path  (snoc at i.rest)
    ;<  v=view:nexus  bind:mu  (peek:io [%| 0 %| here] ~)
    ;<  ~  bind:mu
      ?:  ?=([%ball *] v)  (pure:mu ~)
      (make:io [%| 0 %| here] &+empty-dir:loader)
    $(at here, rest t.rest)
  ::  the clanker: made with its config, prompt and weir; or, existing,
  ::  its host fields folded into its config and its weir re-sanded
  =/  proj=path  (snoc parent (crip "{(trip name)}.clanker"))
  =/  dir=path  (welp /projects proj)
  ;<  anth=(list path)  bind:m  proxy-roots
  ;<  dv=view:nexus  bind:m  (peek:io [%| 0 %| dir] ~)
  ;<  ~  bind:m
    ?.  ?=([%ball *] dv)
      =/  cfg=json  (clanker-config name bundle extra)
      (make:io [%| 0 %| dir] &+(clanker-bole name bundle system (config-weir cfg anth) extra))
    =/  cfg-road=road:tarball  [%| 0 %& dir %'config.json']
    ;<  cur=json  bind:m  (read-json cfg-road)
    =/  merged=json
      :-  %o
      %-  ~(gas by ?:(?=([%o *] cur) p.cur *(map @t json)))
      [['bundle' s+bundle] extra]
    ;<  ~  bind:m  (over:io cfg-road [[/ %json] merged])
    (sand:io [%| 0 %| dir] `(config-weir merged anth))
  ::  the recipes the host ships, each with its files, made if missing
  ;<  ~  bind:m
    =/  rs=(list json)
      ?.  ?=([%o *] jon)  ~
      =/  rj  (~(get by p.jon) 'recipes')
      ?.  ?=([~ %a *] rj)  ~
      p.u.rj
    |-  ^-  form:m
    ?~  rs  (pure:m ~)
    ;<  ~  bind:m  (seed-recipe dir i.rs)
    $(rs t.rs)
  ::  the chats, each with its own prompt and policy, made if missing
  ::  (never overwritten): `chats: [{name, system, policy}]`, or the older
  ::  single `chat` + `chat_system`
  =/  chats=(list [name=@t system=@t policy=(unit json)])
    =/  one=@t  (jstr:clanker jon 'chat')
    =/  listed=(list [name=@t system=@t policy=(unit json)])
      ?.  ?=([%o *] jon)  ~
      =/  cj  (~(get by p.jon) 'chats')
      ?.  ?=([~ %a *] cj)  ~
      %+  murn  p.u.cj
      |=  c=json
      ^-  (unit [name=@t system=@t policy=(unit json)])
      ?.  ?=([%o *] c)  ~
      =/  n=@t  (jstr:clanker c 'name')
      ?:  =('' n)  ~
      `[n (jstr:clanker c 'system') (~(get by p.c) 'policy')]
    ?:  =('' one)  listed
    [[one (jstr:clanker jon 'chat_system') ~] listed]
  |-  ^-  form:m
  ?~  chats  (pure:m ~)
  =/  cdir=path  (welp dir [%chats `@ta`name.i.chats ~])
  ;<  cv=view:nexus  bind:m  (peek:io [%| 0 %| cdir] ~)
  ;<  ~  bind:m
    ?:  ?=([%ball *] cv)  (pure:m ~)
    (make:io [%| 0 %| cdir] &+empty-dir:loader)
  ;<  *  bind:m
    (make-soft:io [%| 0 %& cdir %'log.chat-log'] |+[[[/ %chat-log] [%a ~]] ~])
  ;<  *  bind:m
    ?:  =('' system.i.chats)  (pure:(fiber:fiber:nexus ,(unit tang)) ~)
    (make-soft:io [%| 0 %& cdir %'system.md'] |+[[[/ %mime] [/text/markdown (as-octs:mimes:html system.i.chats)]] ~])
  ;<  *  bind:m
    ?~  policy.i.chats  (pure:(fiber:fiber:nexus ,(unit tang)) ~)
    (make-soft:io [%| 0 %& cdir %'tools.json'] |+[[[/ %json] u.policy.i.chats] ~])
  $(chats t.chats)
::  +seed-recipe: one recipe a host ships with its clanker, made if
::  missing (never overwritten): {name, recipe, files: {name: text}} as
::  recipes/<name>.json and, for each file, recipes/<name>/<file>
++  seed-recipe
  |=  [dir=path r=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] r)  (pure:m ~)
  =/  n=@t  (jstr:clanker r 'name')
  =/  rcp=(unit json)  (~(get by p.r) 'recipe')
  ?~  rcp  (pure:m ~)
  ?:  =('' n)  (pure:m ~)
  =/  rdir=path  (welp dir /recipes)
  ;<  *  bind:m
    (make-soft:io [%| 0 %& rdir (crip "{(trip n)}.json")] |+[[[/ %mime] [/application/json (as-octs:mimes:html (en:json:html u.rcp))]] ~])
  =/  fs=(list [p=@t q=json])
    =/  fj  (~(get by p.r) 'files')
    ?.  ?=([~ %o *] fj)  ~
    ~(tap by p.u.fj)
  ?:  =(~ fs)  (pure:m ~)
  =/  fdir=path  (snoc rdir `@ta`n)
  ;<  fv=view:nexus  bind:m  (peek:io [%| 0 %| fdir] ~)
  ;<  ~  bind:m
    ?:  ?=([%ball *] fv)  (pure:m ~)
    (make:io [%| 0 %| fdir] &+empty-dir:loader)
  |-  ^-  form:m
  ?~  fs  (pure:m ~)
  ;<  *  bind:m
    ?.  ?=([%s *] q.i.fs)  (pure:(fiber:fiber:nexus ,(unit tang)) ~)
    (make-soft:io [%| 0 %& fdir `@ta`p.i.fs] |+[[[/ %mime] [/text/markdown (as-octs:mimes:html p.q.i.fs)]] ~])
  $(fs t.fs)
::
::  Paths. A clanker is addressed by its path under /projects, as the page
::  sends it: "/grubbery.clanker", "/work/hatchery.clanker". A category is
::  the same without the suffix; "/" is the collection root.
::
++  parse-proj
  |=  t=@t
  ^-  (unit path)
  (rush t stap)
++  is-clanker
  |=  n=@ta
  ^-  ?
  =/  t=tape  (trip n)
  =/  len=@ud  (lent t)
  &((gth len 8) =(".clanker" (slag (sub len 8) t)))
::
::  HTTP: the page and its API. A request fiber lives at /requests/<id>,
::  one level under the nexus root, so the root is [%| 1 ...].
::
::    GET  /<anything but api>           the explorer page, mounted here
::    GET  /viewer.js /icon.svg          the chat pane, the icon
::    GET  /api/root                     this instance's absolute root
::    GET  /api/viewer?path=&kind=&blot=&neck=   which pane a path opens in (+pick-viewer)
::    GET  /api/chats?path=              a clanker's chats: name, events, last, busy
::    GET  /api/tree                     the whole collection as {dirs, files}
::    GET  /api/record?path=             a clanker's config + system prompt
::    POST /api/record {path, system, model, max_tokens}
::    GET  /api/log?path=&chat=          one chat's event log
::    POST /api/send {path, chat, message}      -> pokes that clanker
::    POST /api/stop {path, chat}               -> interrupts that clanker
::    POST /api/resolve {path, chat, decisions} -> answers a pending ask
::    POST /api/new {kind, parent, name}        category | clanker | chat
::    POST /api/delete {path} | {path, chat}
::
++  handle-request
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
    (pure:m ~)
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  prefix=path  /grubbery/clanker
  =/  suffix=path
    %+  skip  (slag (lent prefix) site)
    |=(s=@ta =('' s))
  =/  method=@t  method.request.req
  =/  arg  |=(k=@t ^-(@t (fall (~(get by (malt args)) k) '')))
  =/  body=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
  =/  jarg  |=(k=@t ^-(@t (jstr:clanker body k)))
  ?:  ?&(=(%'GET' method) ?=([@ ~] suffix) |(=(%'viewer.js' i.suffix) =(%'chats.js' i.suffix) =(%'recipe.js' i.suffix) =(%'icon.svg' i.suffix) =(%'collection-layout.json' i.suffix) =(%'clanker-layout.json' i.suffix) =(%'chat-layout.json' i.suffix) =(%'root-layout.json' i.suffix)))
    (serve-file eyre-id / i.suffix)
  ::  the root's view: the nexus root itself opens as the root layout
  ::  (the collection over ./projects); anything else at the root keeps
  ::  the usual view
  ?:  ?&(=(%'GET' method) =([%api %root-viewer ~] suffix))
    =/  at=@t  (arg 'path')
    ?.  &(|(=('' at) =('/' at)) =('' (arg 'view')))  (send-json eyre-id '')
    (send-json eyre-id (en:json:html (pairs:enjs:format ~[['layout' s+'/grubbery/clanker/root-layout.json']])))
  ::  the page: the explorer, rooted at the collection. The explorer
  ::  finds this collection's views by itself (/projects/view.json), so
  ::  /grubbery/clanker/<path> is simply the explorer's own url for that
  ::  path under the collection
  ?:  ?&(=(%'GET' method) !?=([%api *] suffix))
    ;<  root=(unit lane:tarball)  bind:m  (resolve-link:io '@clanker')
    ?.  ?=([~ %| *] root)
      (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'clanker is not in /sys/link')])
    =/  coll=path  (snoc p.u.root %projects)
    =/  to=@t
      %-  crip
      ;:  weld
        "/grubbery/ball"  (spud coll)  ?~(suffix "" (spud suffix))
        "?scope="  (spud coll)
      ==
    (send-simple:srv eyre-id [[302 ~[['location' to]]] ~])
  ?:  ?&(=(%'GET' method) =([%api %root ~] suffix))
    ;<  root=(unit lane:tarball)  bind:m  (resolve-link:io '@clanker')
    ?.  ?=([~ %| *] root)
      (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'clanker is not in /sys/link')])
    (send-json eyre-id (en:json:html (pairs:enjs:format ~[['root' s+(spat p.u.root)]])))
  ?:  ?&(=(%'GET' method) =([%api %viewer ~] suffix))
    ::  follows are absolute roads, so the answer needs the collection's
    ::  absolute path: this instance, by name
    ;<  root=(unit lane:tarball)  bind:m  (resolve-link:io '@clanker')
    =/  coll=path  ?.(?=([~ %| *] root) /projects (snoc p.u.root %projects))
    =/  pax=(unit path)  (parse-proj (arg 'path'))
    =/  pick  (pick-viewer coll (fall pax ~) =('dir' (arg 'kind')) (arg 'blot') (arg 'neck') (arg 'view'))
    ?~  pick  (send-json eyre-id '')
    (send-json eyre-id (en:json:html u.pick))
  ?:  ?&(=(%'GET' method) =([%api %chats ~] suffix))
    =/  proj=(unit path)  (parse-proj (arg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    ;<  rows=(list json)  bind:m  (chats-of (welp /projects (snoc u.proj %chats)))
    (send-json eyre-id (en:json:html a+rows))
  ::  the collection root or a category, as its selector draws it: its
  ::  categories, and its clankers each with their chats' state, in one
  ::  answer
  ?:  ?&(=(%'GET' method) =([%api %collection ~] suffix))
    =/  parent=(unit path)  (parse-proj =/(p=@t (arg 'path') ?:(=('' p) '/' p)))
    ?~  parent  (bad eyre-id 'bad path')
    ;<  node=(unit json)  bind:m  (collection-of u.parent)
    ?~  node  (bad eyre-id 'no such category')
    (send-json eyre-id (en:json:html u.node))
  ?:  ?&(=(%'GET' method) =([%api %tree ~] suffix))
    ;<  dv=view:nexus  bind:m  (peek:io [%| 1 %| /projects] ~)
    ?.  ?=([%ball *] dv)  (send-json eyre-id '{"dirs":{},"files":[]}')
    (send-json eyre-id (en:json:html (tree-json ball.dv)))
  ::  with chat=, the record is that chat's own prompt (chats/<chat>/
  ::  system.md, the role it plays on top of the clanker's), nothing else
  ::  the providers a clanker may be pointed at, from the registry in
  ::  lib/clanker: {name, label, dialect, route}. The config form offers
  ::  these and reads each one's /api/models for its models.
  ?:  ?&(=(%'GET' method) =([%api %providers ~] suffix))
    (send-json eyre-id (en:json:html providers-json:clanker))
  ?:  ?&(=(%'GET' method) =([%api %record ~] suffix))
    =/  proj=(unit path)  (parse-proj (arg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    =/  chat=@t  (arg 'chat')
    ?.  =('' chat)
      ;<  sys=@t  bind:m  (read-text [%| 1 %& (welp /projects (welp u.proj [%chats `@ta`chat ~])) %'system.md'])
      %+  send-json  eyre-id
      (en:json:html (pairs:enjs:format ~[['path' s+(spat u.proj)] ['chat' s+chat] ['record' [%o ~]] ['system' s+sys]]))
    ;<  cfg=json  bind:m  (read-json [%| 1 %& (welp /projects u.proj) %'config.json'])
    ;<  sys=@t  bind:m  (read-text [%| 1 %& (welp /projects (snoc u.proj %prompts)) %'main.md'])
    %+  send-json  eyre-id
    (en:json:html (pairs:enjs:format ~[['path' s+(spat u.proj)] ['record' cfg] ['system' s+sys]]))
  ?:  ?&(=(%'POST' method) =([%api %record ~] suffix))
    =/  proj=(unit path)  (parse-proj (jarg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    =/  chat=@t  (jarg 'chat')
    ?.  =('' chat)
      =/  cdir=path  (welp /projects (welp u.proj [%chats `@ta`chat ~]))
      ;<  cv=view:nexus  bind:m  (peek:io [%| 1 %| cdir] ~)
      ?.  ?=([%ball *] cv)  (bad eyre-id 'no such chat')
      =/  s=(unit json)  ?.(?=([%o *] body) ~ (~(get by p.body) 'system'))
      ?.  ?=([~ %s *] s)  (bad eyre-id 'system required')
      =/  bask=bask:tarball  [[/ %mime] [/text/markdown (as-octs:mimes:html p.u.s)]]
      ;<  *  bind:m  (make-soft:io [%| 1 %& cdir %'system.md'] |+[bask ~])
      ;<  ~  bind:m  (over:io [%| 1 %& cdir %'system.md'] bask)
      (send-json eyre-id '{"ok":true}')
    =/  cfg-road=road:tarball  [%| 1 %& (welp /projects u.proj) %'config.json']
    ;<  cv=view:nexus  bind:m  (peek:io cfg-road `[/ %json])
    ?.  ?=([%file *] cv)  (bad eyre-id 'no such clanker')
    =/  cur=(map @t json)
      =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.cv)))) [%o ~])
      ?:(?=([%o *] j) p.j ~)
    =/  new=(map @t json)
      ::  provider picks which proxy answers ('anthropic', absent, or
      ::  'openrouter'); a key left out of the body is left alone, so a
      ::  form that does not know about it cannot clobber it
      %+  roll  `(list @t)`~['model' 'max_tokens' 'provider']
      |=  [k=@t acc=_cur]
      =/  v=(unit json)  ?.(?=([%o *] body) ~ (~(get by p.body) k))
      ?~(v acc (~(put by acc) k u.v))
    ;<  ~  bind:m  (over:io cfg-road [[/ %json] [%o new]])
    ;<  ~  bind:m
      =/  s=(unit json)  ?.(?=([%o *] body) ~ (~(get by p.body) 'system'))
      ?.  ?=([~ %s *] s)  (pure:m ~)
      %-  over:io
      :-  [%| 1 %& (welp /projects (snoc u.proj %prompts)) %'main.md']
      [[/ %mime] [/text/markdown (as-octs:mimes:html p.u.s)]]
    (send-json eyre-id '{"ok":true}')
  ::  the tool policy editor's data: the tool names this clanker's tools
  ::  nexus holds, its tools.json (null when none) and, with chat=, that
  ::  chat's own tools.json (null when none)
  ?:  ?&(=(%'GET' method) =([%api %tools ~] suffix))
    =/  proj=(unit path)  (parse-proj (arg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    =/  chat=@t  (arg 'chat')
    =/  pdir=path  (welp /projects u.proj)
    ;<  names=(list @t)  bind:m  (tool-names u.proj)
    ;<  base=(unit json)  bind:m  (read-json-maybe [%| 1 %& pdir %'tools.json'])
    ;<  own=(unit json)  bind:m
      ?:  =('' chat)  (pure:(fiber:fiber:nexus ,(unit json)) ~)
      (read-json-maybe [%| 1 %& (welp pdir [%chats `@ta`chat ~]) %'tools.json'])
    =/  bj=json  ?~(base ~ u.base)
    =/  oj=json  ?~(own ~ u.own)
    %+  send-json  eyre-id
    %-  en:json:html
    %-  pairs:enjs:format
    :~  ['path' s+(spat u.proj)]
        ['chat' s+chat]
        ::  the runtime tools (the agent's own: enter, step, spawn) take
        ::  verdicts by name like the rest, so they are listed with them
        ['tools' a+(turn (weld runtime-tools names) |=(n=@t `json`s+n))]
        ['clanker' bj]
        ['own' oj]
    ==
  ::  the tip of a chat's recipe run: where it stands and the block that
  ::  rides at the tail of the model's next request. null when no run is
  ::  live. Rendered from run.json as it is, so it is the state after the
  ::  last message was spent.
  ?:  ?&(=(%'GET' method) =([%api %tip ~] suffix))
    =/  proj=(unit path)  (parse-proj (arg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    =/  chat=@t  (arg 'chat')
    =/  pdir=path  (welp /projects u.proj)
    =/  cdir=path  (welp pdir [%chats `@ta`chat ~])
    ;<  rj=(unit json)  bind:m  (read-json-maybe [%| 1 %& cdir %'run.json'])
    =/  stk=stack:rcp-lib  ?~(rj ~ (stack-from-json:rcp-lib u.rj))
    ::  the tip's words: the clanker's own prompts/ files
    ;<  frags=frags:rcp-lib  bind:m
      =/  mf  (fiber:fiber:nexus ,frags:rcp-lib)
      =/  sdir=path  (snoc pdir %prompts)
      ;<  dv=view:nexus  bind:mf  (peek-shallow:io [%| 1 %| sdir] ~)
      ?.  ?=([%ball *] dv)  (pure:mf ~)
      ?~  fil.ball.dv  (pure:mf ~)
      =/  names=(list @ta)  ~(tap in ~(key by contents.u.fil.ball.dv))
      =|  acc=(list [@ta @t])
      |-  ^-  form:mf
      ?~  names  (pure:mf (frags-of-texts:rcp-lib acc))
      ;<  t=@t  bind:mf  (read-text [%| 1 %& sdir i.names])
      $(names t.names, acc [[i.names t] acc])
    ::  frames, bottom first. Each carries its run state and the recipe
    ::  file itself, so the pane renders the step from the source rather
    ::  than parsing the tip; the tip rides along as the model reads it
    ;<  frames=(list json)  bind:m
      =/  mf  (fiber:fiber:nexus ,(list json))
      =/  todo=(list state:rcp-lib)  (flop stk)
      =|  acc=(list json)
      |-  ^-  form:mf
      ?~  todo  (pure:mf (flop acc))
      =/  st=state:rcp-lib  i.todo
      ;<  raw=(unit json)  bind:mf
        (read-json-maybe [%| 1 %& (snoc pdir %recipes) (crip "{(trip name.st)}.json")])
      ?~  raw  $(todo t.todo)
      =/  rcp=(unit recipe:rcp-lib)  (parse:rcp-lib name.st u.raw)
      ?~  rcp  $(todo t.todo)
      ::  the frames beneath this one, in the top-first stack
      =/  outer=(list state:rcp-lib)  (slag +((lent t.todo)) stk)
      =/  fj=json
        %-  pairs:enjs:format
        :~  ['name' s+name.st]
            ['step' s+step.st]
            ['level' s+level.st]
            ['asked' b+asked.st]
            ['run' (state-to-json:rcp-lib st)]
            ['recipe' u.raw]
            ['tip' s+(tip-in:rcp-lib frags u.rcp st outer)]
        ==
      $(todo t.todo, acc [fj acc])
    %+  send-json  eyre-id
    %-  en:json:html
    (pairs:enjs:format ~[['frames' a+frames]])
  ::  the user takes a chat out of its recipe: two pokes in order. The
  ::  interrupt lands mid-await inside a running turn and cancels it
  ::  (idle, it is a no-op); the leave is taken next, on a log at rest
  ?:  ?&(=(%'POST' method) =([%api %leave ~] suffix))
    =/  proj=(unit path)  (parse-proj (jarg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    ;<  ~  bind:m
      %-  poke:io
      :+  [%| 1 %& (welp /projects u.proj) %'main.sig']  [/ %json]
      (pairs:enjs:format ~[['action' s+'interrupt'] ['chat' s+(jarg 'chat')]])
    ;<  ~  bind:m
      %-  poke:io
      :+  [%| 1 %& (welp /projects u.proj) %'main.sig']  [/ %json]
      %-  pairs:enjs:format
      :~  ['action' s+'leave']
          ['chat' s+(jarg 'chat')]
          ::  depth: the frame to leave, bottom = 0; it and everything
          ::  above it go. Omitted: the top.
          ['depth' ?.(?=([%o *] body) ~ (fall (~(get by p.body) 'depth') ~))]
      ==
    (send-json eyre-id '{"ok":true}')
  ::  write a policy: {path, chat?, policy: {default, allow, ask, deny}}
  ::  to the clanker's tools.json, or the chat's
  ?:  ?&(=(%'POST' method) =([%api %tools ~] suffix))
    =/  proj=(unit path)  (parse-proj (jarg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    =/  chat=@t  (jarg 'chat')
    =/  dir=path
      ?:  =('' chat)  (welp /projects u.proj)
      (welp /projects (welp u.proj [%chats `@ta`chat ~]))
    =/  pol=(unit json)  ?.(?=([%o *] body) ~ (~(get by p.body) 'policy'))
    ?.  ?=([~ %o *] pol)  (bad eyre-id 'policy required')
    ;<  dv=view:nexus  bind:m  (peek:io [%| 1 %| dir] ~)
    ?.  ?=([%ball *] dv)  (bad eyre-id 'no such clanker or chat')
    =/  road=road:tarball  [%| 1 %& dir %'tools.json']
    ;<  *  bind:m  (make-soft:io road |+[[[/ %json] u.pol] ~])
    ;<  ~  bind:m  (over:io road [[/ %json] u.pol])
    (send-json eyre-id '{"ok":true}')
  ?:  ?&(=(%'GET' method) =([%api %log ~] suffix))
    =/  proj=(unit path)  (parse-proj (arg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    =/  chat=@t  =/(c=@t (arg 'chat') ?:(=('' c) 'main' c))
    ;<  log=json  bind:m
      (read-json [%| 1 %& (welp /projects (welp u.proj [%chats `@ta`chat ~])) %'log.chat-log'])
    =/  evs=(list json)  ?:(?=([%a *] log) p.log ~)
    ::  a range of the log, never the whole thing: ?from=N (events N on),
    ::  ?to=M (up to M, exclusive), ?tail=K (the last K); the answer says
    ::  the total and where the slice starts, so a pane can hold a window
    ::  and ask for what is past it. No range: the whole array (legacy).
    =/  num
      |=  k=@t
      ^-  (unit @ud)
      =/  s=@t  (arg k)
      ?:(=('' s) ~ (rush s dem))
    =/  from=(unit @ud)  (num 'from')
    =/  to=(unit @ud)    (num 'to')
    =/  tail=(unit @ud)  (num 'tail')
    ?:  &(?=(~ from) ?=(~ to) ?=(~ tail))
      (send-json eyre-id (en:json:html a+evs))
    =/  total=@ud  (lent evs)
    =/  f=@ud
      ?^  from  (min u.from total)
      ?^  tail  (sub total (min u.tail total))
      0
    =/  t=@ud  ?^(to (min u.to total) total)
    =/  slice=(list json)  ?:((gte f t) ~ (scag (sub t f) (slag f evs)))
    %+  send-json  eyre-id
    %-  en:json:html
    %-  pairs:enjs:format
    :~  ['total' (numb:enjs:format total)]
        ['from' (numb:enjs:format f)]
        ['events' a+slice]
    ==
  ::  send is a poke and nothing else: the clanker's weir was set when it
  ::  was made and is kept current by +sand-watch, not here
  ?:  ?&(=(%'POST' method) =([%api %send ~] suffix))
    =/  proj=(unit path)  (parse-proj (jarg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    ;<  ~  bind:m
      %-  poke:io
      :+  [%| 1 %& (welp /projects u.proj) %'main.sig']  [/ %json]
      (pairs:enjs:format ~[['chat' s+(jarg 'chat')] ['message' s+(jarg 'message')]])
    (send-json eyre-id '{"ok":true}')
  ?:  ?&(=(%'POST' method) =([%api %stop ~] suffix))
    =/  proj=(unit path)  (parse-proj (jarg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    ;<  ~  bind:m
      %-  poke:io
      :+  [%| 1 %& (welp /projects u.proj) %'main.sig']  [/ %json]
      (pairs:enjs:format ~[['action' s+'interrupt'] ['chat' s+(jarg 'chat')]])
    (send-json eyre-id '{"ok":true}')
  ::  the user's answer to a chat paused on an ask: which tool uses run
  ?:  ?&(=(%'POST' method) =([%api %resolve ~] suffix))
    =/  proj=(unit path)  (parse-proj (jarg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    =/  decisions=json
      ?.  ?=([%o *] body)  [%o ~]
      (fall (~(get by p.body) 'decisions') [%o ~])
    ;<  ~  bind:m
      %-  poke:io
      :+  [%| 1 %& (welp /projects u.proj) %'main.sig']  [/ %json]
      (pairs:enjs:format ~[['action' s+'resolve'] ['chat' s+(jarg 'chat')] ['decisions' decisions]])
    (send-json eyre-id '{"ok":true}')
  ?:  ?&(=(%'POST' method) =([%api %new ~] suffix))
    =/  kind=@t  (jarg 'kind')
    =/  parent=(unit path)  (parse-proj =/(p=@t (jarg 'parent') ?:(=('' p) '/' p)))
    =/  name=@t  (jarg 'name')
    ?~  parent  (bad eyre-id 'bad parent')
    ?:  =('' name)  (bad eyre-id 'name required')
    ::  the category dirs along parent, made if missing: a path typed as
    ::  work/x/y makes work/ and work/x/ on the way to y
    ;<  ~  bind:m
      =/  mu  (fiber:fiber:nexus ,~)
      =/  at=path  /projects
      =/  rest=path  u.parent
      |-  ^-  form:mu
      ?~  rest  (pure:mu ~)
      =/  here=path  (snoc at i.rest)
      ;<  v=view:nexus  bind:mu  (peek:io [%| 1 %| here] ~)
      ;<  ~  bind:mu
        ?:  ?=([%ball *] v)  (pure:mu ~)
        (make:io [%| 1 %| here] &+empty-dir:loader)
      $(at here, rest t.rest)
    ?:  =('category' kind)
      ;<  ~  bind:m
        (make:io [%| 1 %| (welp /projects (snoc u.parent `@ta`name))] &+empty-dir:loader)
      (send-json eyre-id '{"ok":true}')
    ?:  =('clanker' kind)
      =/  dir=@ta  (crip "{(trip name)}.clanker")
      =/  proj=path  (snoc u.parent dir)
      ;<  anth=(list path)  bind:m  proxy-roots
      ;<  ~  bind:m
        (make:io [%| 1 %| (welp /projects proj)] &+(clanker-bole name 'default' '' (default-weir anth) ~))
      (send-json eyre-id '{"ok":true}')
    ?:  =('chat' kind)
      ::  a chat is a dir: its log, and optionally its own prompt
      ::  (system.md), the role this chat plays on top of the clanker's
      =/  dir=path  (welp /projects (welp u.parent [%chats `@ta`name ~]))
      =/  sys=@t  (jarg 'system')
      ;<  dv=view:nexus  bind:m  (peek:io [%| 1 %| dir] ~)
      ;<  ~  bind:m
        ?:  ?=([%ball *] dv)  (pure:m ~)
        (make:io [%| 1 %| dir] &+empty-dir:loader)
      ;<  err=(unit tang)  bind:m
        (make-soft:io [%| 1 %& dir %'log.chat-log'] |+[[[/ %chat-log] [%a ~]] ~])
      ;<  err=(unit tang)  bind:m
        ?:  =('' sys)  (pure:(fiber:fiber:nexus ,(unit tang)) ~)
        (make-soft:io [%| 1 %& dir %'system.md'] |+[[[/ %mime] [/text/markdown (as-octs:mimes:html sys)]] ~])
      (send-json eyre-id '{"ok":true}')
    (bad eyre-id 'kind must be category, clanker, or chat')
  ?:  ?&(=(%'POST' method) =([%api %delete ~] suffix))
    =/  proj=(unit path)  (parse-proj (jarg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    ?~  u.proj  (bad eyre-id 'the collection root stays')
    =/  chat=@t  (jarg 'chat')
    ?:  =('' chat)
      ;<  *  bind:m  (cull-soft:io [%| 1 %| (welp /projects u.proj)])
      (send-json eyre-id '{"ok":true}')
    ;<  *  bind:m
      (cull-soft:io [%| 1 %| (welp /projects (welp u.proj [%chats `@ta`chat ~]))])
    (send-json eyre-id '{"ok":true}')
  ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
  (pure:m ~)
::  +collection-of: a category (the root included) as the selector's tree
::  draws it: {path, categories: [the same shape, each with its name],
::  clankers: [{name, bundle, model, chats}]}, the whole subtree in one
::  answer. ~ when there is no such directory.
++  collection-of
  |=  parent=path
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  =/  pdir=path  (welp /projects parent)
  ;<  dv=view:nexus  bind:m  (peek-shallow:io [%| 1 %| pdir] ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  =/  names=(list @ta)  (sort ~(tap in ~(key by dir.ball.dv)) aor)
  ;<  clankers=(list json)  bind:m
    =/  mc  (fiber:fiber:nexus ,(list json))
    =/  todo=(list @ta)  (skim names is-clanker)
    =|  acc=(list json)
    |-  ^-  form:mc
    ?~  todo  (pure:mc (flop acc))
    =/  cdir=path  (snoc pdir i.todo)
    ;<  cfg=json  bind:mc  (read-json [%| 1 %& cdir %'config.json'])
    ;<  chats=(list json)  bind:mc  (chats-of (snoc cdir %chats))
    =/  row=json
      %-  pairs:enjs:format
      :~  ['name' s+i.todo]
          ['bundle' s+(jstr:clanker cfg 'bundle')]
          ['model' s+(jstr:clanker cfg 'model')]
          ['chats' a+chats]
      ==
    $(todo t.todo, acc [row acc])
  ;<  cats=(list json)  bind:m
    =/  mc  (fiber:fiber:nexus ,(list json))
    =/  todo=(list @ta)  (skip names is-clanker)
    =|  acc=(list json)
    |-  ^-  form:mc
    ?~  todo  (pure:mc (flop acc))
    ;<  sub=(unit json)  bind:mc  (collection-of (snoc parent i.todo))
    =/  row=json
      ?.  ?=([~ %o *] sub)  (pairs:enjs:format ~[['name' s+i.todo]])
      o+(~(put by p.u.sub) 'name' s+i.todo)
    $(todo t.todo, acc [row acc])
  %-  pure:m
  %-  some
  %-  pairs:enjs:format
  :~  ['path' s+(spat parent)]
      ['categories' a+cats]
      ['clankers' a+clankers]
  ==
::  +chats-of: the chats in a chats/ directory, each as the chat list
::  shows it. Read from the chat's status.json, the small record the
::  agent derives from the log on every write ({state, events, last,
::  input, asks}): the list never reads a transcript. A chat with no
::  status yet (never written since it was made) falls back to its log.
::  the tools the agent loop runs itself rather than sending to the tools
::  nexus (+run-tools in agent.hoon); policy applies to them by name
++  runtime-tools  ^-((list @t) ~['recipe_enter' 'recipe_step' 'spawn'])
++  chats-of
  |=  chats-dir=path
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek-shallow:io [%| 1 %| chats-dir] ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  =/  names=(list @ta)  (sort ~(tap in ~(key by dir.ball.dv)) aor)
  =|  acc=(list json)
  |-  ^-  form:m
  ?~  names  (pure:m (flop acc))
  =/  cdir=path  (snoc chats-dir i.names)
  ;<  st=(unit json)  bind:m  (read-json-maybe [%| 1 %& cdir %'status.json'])
  ;<  sys=@t  bind:m  (read-text [%| 1 %& cdir %'system.md'])
  ::  the recipe state is read from run.json here, not from the copy in
  ::  status.json: the copy is as old as the log's last write
  ;<  rj=(unit json)  bind:m  (read-json-maybe [%| 1 %& cdir %'run.json'])
  =/  stk=stack:rcp-lib  ?~(rj ~ (stack-from-json:rcp-lib u.rj))
  =/  recipe=json
    ?~  stk  ~
    %-  pairs:enjs:format
    :~  ['name' s+name.i.stk]
        ['step' s+step.i.stk]
        ['asked' b+asked.i.stk]
        ['depth' (numb:enjs:format (lent stk))]
    ==
  ;<  row=json  bind:m
    =/  mj  (fiber:fiber:nexus ,json)
    ^-  form:mj
    ?:  ?=([~ %o *] st)
      =/  state=@t  (jstr:clanker u.st 'state')
      %-  pure:mj
      %-  pairs:enjs:format
      :~  ['name' s+i.names]
          ['events' (fall (~(get by p.u.st) 'events') (numb:enjs:format 0))]
          ['last' s+(jstr:clanker u.st 'input')]
          ['busy' b+=('busy' state)]
          ['asking' b+=('asking' state)]
          ['prompt' b+!=('' sys)]
          ['recipe' recipe]
      ==
    ;<  log=json  bind:mj  (read-json [%| 1 %& cdir %'log.chat-log'])
    =/  evs=(list json)  ?:(?=([%a *] log) p.log ~)
    (pure:mj (chat-summary i.names evs !=('' sys)))
  $(names t.names, acc [row acc])
::  +chat-summary: one chat as the chats pane shows it: its name, how
::  many events its log holds, the last thing said to it, and whether a
::  turn is running (the log ends in an input, tool results, or a
::  response that asked for tools).
++  chat-summary
  |=  [name=@ta evs=(list json) prompt=?]
  ^-  json
  =/  key
    |=  [e=json k=@t]
    ^-  @t
    ?.  ?=([%o *] e)  ''
    =/  v=(unit json)  (~(get by p.e) k)
    ?:(?=([~ %s *] v) p.u.v '')
  =/  inputs=(list json)  (skim evs |=(e=json =('input' (key e 'k'))))
  =/  last=@t  ?~(inputs '' (key (rear inputs) 'body'))
  =/  k=@t  ?~(evs '' (key (rear evs) 'k'))
  =/  busy=?
    ?~  evs  %.n
    ?|  =('input' k)
        =('results' k)
        =('resolved' k)
        &(=('response' k) =('tool_use' (key (rear evs) 'stop')))
    ==
  %-  pairs:enjs:format
  :~  ['name' s+name]
      ['events' (numb:enjs:format (lent evs))]
      ['last' s+last]
      ['busy' b+busy]
      ['asking' b+=('ask' k)]
      ['prompt' b+prompt]
  ==
::  +tree-json: the collection as nested {dirs, files}, the directories
::  as they are, one deep peek, nothing folded. The page tells clankers
::  from categories by name, chats by position. Each dir node also says
::  whether it is a nexus (has a neck), and a dir named runs carries a
::  summary of each run grub in it ({tool, step, arg}), so the tree can
::  show what ran and how it ended.
++  tree-json
  |=  b=ball:tarball
  ^-  json
  =/  files=(list @ta)  ?~(fil.b ~ (sort ~(tap in ~(key by contents.u.fil.b)) aor))
  %-  pairs:enjs:format
  :~  :-  'dirs'
      :-  %o
      %-  ~(gas by *(map @t json))
      %+  turn  ~(tap by dir.b)
      |=  [n=@ta kid=ball:tarball]
      ^-  [@t json]
      =/  sub=json  ?:(=(%runs n) (runs-json `kid) (tree-json kid))
      ?>  ?=([%o *] sub)
      =/  necked=?  ?~(fil.kid %.n ?=(^ neck.u.fil.kid))
      [n o+(~(put by p.sub) 'nexus' b+necked)]
      ['files' [%a (turn files |=(x=@ta s+x))]]
  ==
::  +runs-json: a tools nexus's runs/ as a tree node with a `runs` map
::  beside the names: id -> {tool, step, arg}. A run's state is read
::  straight from the ball (no extra peek); one that won't read is
::  listed with no summary.
++  runs-json
  |=  rb=(unit ball:tarball)
  ^-  json
  =/  ids=(list @ta)
    ?~  rb  ~
    ?~  fil.u.rb  ~
    (sort ~(tap in ~(key by contents.u.fil.u.rb)) aor)
  =/  sums=(list [@t json])
    ?~  rb  ~
    ?~  fil.u.rb  ~
    %+  murn  ids
    |=  id=@ta
    ^-  (unit [@t json])
    =/  got  (~(get by contents.u.fil.u.rb) id)
    ?~  got  ~
    ?:  (is-boom:tarball sang.u.got)  ~
    =/  res  (mule |.(!<(tool-state:nex-tools (need-vase:tarball sang.u.got))))
    ?:  ?=(%| -.res)  ~
    `[id (run-summary p.res)]
  %-  pairs:enjs:format
  :~  ['dirs' [%o ~]]
      ['files' [%a (turn ids |=(x=@ta s+x))]]
      ['runs' [%o (malt sums)]]
  ==
::  +run-summary: {tool, step, arg}. step is the state's own step tag,
::  except a %done whose result is an error reads 'error'.
++  run-summary
  |=  st=tool-state:nex-tools
  ^-  json
  =/  failed=?
    ?~  update.st  %.n
    ?.  ?=([%o *] u.update.st)  %.n
    ?=([~ %s %'error'] (~(get by p.u.update.st) 'type'))
  =/  arg=@t
    =/  strs=(list @t)
      %+  murn  (sort ~(tap by args.st) |=([[a=@t *] [b=@t *]] (aor a b)))
      |=([k=@t v=json] ?:(?=([%s *] v) `p.v ~))
    ?~(strs '' i.strs)
  %-  pairs:enjs:format
  :~  ['tool' s+tool.st]
      ['step' s+?:(failed 'error' step.st)]
      ['arg' s+arg]
  ==
::  +tool-names: what a clanker's tools nexus holds, by name: the files
::  under tools/code/lib/tools as lib/tools derives their names (stem,
::  hyphens to underscores, subdirs joined with __), plus the engine's
::  own spawn. Sorted.
++  tool-names
  |=  proj=path
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  =/  root=path  (welp /projects (welp proj /tools/code/lib/tools))
  ;<  names=(list @t)  bind:m  (tool-names-in root /)
  (pure:m (snoc (sort names aor) 'spawn'))
++  tool-names-in
  |=  [root=path sub=path]
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek-shallow:io [%| 1 %| (welp root sub)] ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  =/  files=(list @t)
    ?~  fil.ball.dv  ~
    %+  turn  ~(tap in ~(key by contents.u.fil.ball.dv))
    |=(n=@ta (derive-name:nex-tools sub n))
  =/  dirs=(list @ta)  ~(tap in ~(key by dir.ball.dv))
  |-  ^-  form:m
  ?~  dirs  (pure:m files)
  ;<  more=(list @t)  bind:m  (tool-names-in root (snoc sub i.dirs))
  $(dirs t.dirs, files (weld files more))
::  +read-json-maybe: a json grub, or ~ when there is none
++  read-json-maybe
  |=  road=road:tarball
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek:io road `[/ %json])
  ?.  ?=([%file *] v)  (pure:m ~)
  (pure:m (mole |.(!<(json (need-vase:tarball sang.v)))))
::
++  read-json
  |=  road=road:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek:io road `[/ %json])
  ?.  ?=([%file *] v)  (pure:m [%o ~])
  (pure:m (fall (mole |.(!<(json (need-vase:tarball sang.v)))) [%o ~]))
++  read-text
  |=  road=road:tarball
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek:io road `[/ %mime])
  ?.  ?=([%file *] v)  (pure:m '')
  ?:  (is-boom:tarball sang.v)  (pure:m '')
  (pure:m `@t`q.q:!<(mime (need-vase:tarball sang.v)))
::
++  bad
  |=  [eyre-id=@ta msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html msg)])
::
::  +pick-viewer: which pane a path opens in, from where it is under the
::  collection, whether it is a file or a dir, a file's blot and a dir's
::  neck (the nexus it runs, '' when plain). Plain code: match the path,
::  match the blot or neck, name a view the script registers, and hand
::  the pane its context as args so it never has to read the tree's
::  shape out of a url. ~ means the usual view. A pane is about the path
::  it opens on; keep it that way.
::  The answer is the explorer's viewers json: {view, script, args, follow}
::  for a pane, or {layout} for a dir that opens as a layout. `view` is
::  the moment's own ?view= (the explorer's rows/grid/tree never reach
::  here): '' is the bare path, 'collection' and 'record' are ours.
::  `follow` names the roads the pane depends on, absolute, so the
::  explorer's stream tells it when they move (a log's body rides along).
++  pick-viewer
  |=  [coll=path pax=path dir=? blot=@t neck=@t view=@t]
  ^-  (unit json)
  =/  fol
    |=  [p=path body=? fold=?]
    ^-  json
    (pairs:enjs:format ~[['road' s+(cat 3 (spat p) ?:(fold '/' ''))] ['body' b+body] ['fold' b+fold]])
  =/  ans
    |=  [v=@t script=@t a=json f=(list json)]
    ^-  (unit json)
    `(pairs:enjs:format ~[['view' s+v] ['script' s+script] ['args' a] ['follow' a+f]])
  =/  lay  |=(u=@t ^-((unit json) `(pairs:enjs:format ~[['layout' s+u]])))
  =/  panes=@t  '/grubbery/clanker/chats.js'
  ::  the shell's tools panes: a tools nexus, and one tool on its source
  =/  tools-panes=@t  '/grubbery/tools/pane.js'
  =/  f=path  (flop pax)
  ::  a tool's source under a clanker's tools nexus: the clanker, and the
  ::  file's path under code/lib/tools
  =/  tool-file
    |=  p=path
    ^-  (unit [proj=path rel=path])
    =|  proj=path
    |-  ^-  (unit [path path])
    ?~  p  ~
    ?:  ?&  ?=([%tools %code %lib %tools ^] p)
            ?=(^ proj)
            (is-clanker (rear proj))
        ==
      `[proj t.t.t.t.p]
    $(p t.p, proj (snoc proj i.p))
  ::  a chat: its log file, or its directory. The pane follows the log
  ::  with its body (the mark grows to json) and the status beside it.
  =/  chat-ans
    |=  [proj=path chat=@ta]
    ^-  (unit json)
    =/  cdir=path  (welp coll (welp proj [%chats chat ~]))
    ::  the log is followed by NAME only: the pane holds a window of it and
    ::  fetches what is past that window on each change (/api/log?from=),
    ::  never the whole array on the stream
    %-  ans
    :^  'chat'  '/grubbery/clanker/viewer.js'
      (pairs:enjs:format ~[['proj' s+(spat proj)] ['chat' s+chat]])
    ~[(fol (snoc cdir %'log.chat-log') | |)]
  ::  (each ?= is the test of its own ?: so it narrows the path it matched)
  ?.  dir
    ::  a chat's log, by its blot or by its name (a restored log may sit
    ::  as plain mime until the agent next writes it)
    ?:  |(=('chat-log' blot) ?=([%'log.chat-log' *] f))
      ?.  ?=([@ @ %chats *] f)  ~
      ::  ?view=prompt on a chat's log: the chat's own prompt, as the
      ::  record form (its system.md may not exist yet, so the log is the
      ::  path the form opens on)
      ?.  |(=('prompt' view) =('tools' view) =('tip' view))  (chat-ans (flop t.t.t.f) i.t.f)
      =/  proj=path  (flop t.t.t.f)
      =/  pdir=path  (welp coll proj)
      =/  cdir=path  (welp pdir [%chats i.t.f ~])
      =/  a=json  (pairs:enjs:format ~[['proj' s+(spat proj)] ['chat' s+i.t.f]])
      ::  ?view=tip: the chat's recipe run, following run.json and the
      ::  log (a leave writes both; a move writes the run)
      ?:  =('tip' view)
        (ans 'tip' panes a ~[(fol (snoc cdir %'run.json') | |) (fol (snoc cdir %'log.chat-log') | |)])
      ::  ?view=tools: the chat's own tool policy, over the clanker's
      ?:  =('tools' view)
        (ans 'tools' panes a ~[(fol (snoc cdir %'tools.json') | |) (fol (snoc pdir %'tools.json') | |)])
      (ans 'record' panes a ~[(fol (snoc cdir %'system.md') | |)])
    ::  a tool: the shell's tool pane (description, schema, a form to run
    ::  it, the source), following the file so an edit redraws it
    =/  tf=(unit [proj=path rel=path])  (tool-file pax)
    ?^  tf
      =/  tdir=path  (welp coll (snoc proj.u.tf %tools))
      %-  ans
      :^  'tool'  tools-panes
        (pairs:enjs:format ~[['at' s+(spat tdir)] ['file' s+(spat rel.u.tf)]])
      ~[(fol (welp tdir (welp /code/lib/tools rel.u.tf)) & |)]
    ::  a recipe: its graph beside its aims. The pane follows the file
    ::  with its body, so editing the json redraws the graph.
    ?:  ?=([@ %recipes @ *] f)
      ?.  (is-clanker i.t.t.f)  ~
      =/  proj=path  (flop t.t.f)
      %-  ans
      :^  'recipe'  '/grubbery/clanker/recipe.js'
        (pairs:enjs:format ~[['proj' s+(spat proj)] ['name' s+i.f]])
      ~[(fol (welp coll (welp proj [%recipes i.f ~])) & |)]
    ::  a clanker's standing prompt, its settings, or its tool policy, as
    ::  three forms, all opened on its config.json. `record` is the prompt
    ::  alone: the model and the provider live in `config`, so the two are
    ::  edited and saved apart (the api merges, so neither clobbers the
    ::  other's fields).
    ?.  ?|(=('record' view) =('tools' view) =('config' view))  ~
    ?.  ?=([%'config.json' @ *] f)  ~
    ?.  (is-clanker i.t.f)  ~
    =/  proj=path  (flop t.f)
    =/  pdir=path  (welp coll proj)
    ?:  =('tools' view)
      %-  ans
      :^  'tools'  panes  (pairs:enjs:format ~[['proj' s+(spat proj)]])
      ~[(fol (snoc pdir %'tools.json') | |) (fol (welp pdir /tools/code/lib/tools) | &)]
    ?:  =('config' view)
      %-  ans
      :^  'config'  panes  (pairs:enjs:format ~[['proj' s+(spat proj)]])
      ~[(fol (snoc pdir %'config.json') & |)]
    %-  ans
    :^  'record'  panes  (pairs:enjs:format ~[['proj' s+(spat proj)]])
    ~[(fol (snoc (snoc pdir %prompts) %'main.md') | |)]
  ::  a clanker's tools/ directory is its tools nexus: the shell's tools
  ::  pane, live on the tools' code and on the runs
  ?:  ?=([%tools @ *] f)
    ?.  (is-clanker i.t.f)  ~
    ?.  =('' view)  ~
    =/  tdir=path  (welp coll (snoc (flop t.f) %tools))
    %-  ans
    :^  'tools-nexus'  tools-panes
      (pairs:enjs:format ~[['at' s+(spat tdir)]])
    ~[(fol (welp tdir /code/lib/tools) | &) (fol (welp tdir /runs) | &)]
  ::  a clanker's chats/ directory is its list of chats, live on the dir
  ?:  ?=([%chats @ *] f)
    =/  proj=path  (flop t.f)
    (ans 'chats' panes (pairs:enjs:format ~[['proj' s+(spat proj)]]) ~[(fol (welp coll (snoc proj %chats)) | &)])
  ::  a chat's own directory opens as the chat layout (the chat | its
  ::  prompt), rooted at it
  ?:  ?=([@ %chats @ *] f)
    ?.  (lien pax is-clanker)  ~
    ?.  =('' view)  ~
    (lay '/grubbery/clanker/chat-layout.json')
  ::  a clanker dir opens as the clanker layout, rooted at it; inside a
  ::  clanker everything else keeps the usual view. (The test narrows pax to
  ::  a cell, which the wet gates below cannot mull; p is the plain path.)
  ?:  ?=(^ pax)
    =/  p=path  pax
    ?:  &((is-clanker (rear p)) =('' view))
      (lay '/grubbery/clanker/clanker-layout.json')
    ?:  (lien p is-clanker)  ~
    ?:  =('collection' view)
      (ans 'collection' panes (pairs:enjs:format ~[['parent' s+(spat p)]]) ~[(fol (welp coll p) | &)])
    ?:  =('' view)  (lay '/grubbery/clanker/collection-layout.json')
    ~
  ::  the collection root, or a category: the selector pane when asked
  ::  for it (the layout's left side), the layout otherwise
  ?:  =('collection' view)
    (ans 'collection' panes (pairs:enjs:format ~[['parent' s+(spat pax)]]) ~[(fol (welp coll pax) | &)])
  ?:  =('' view)  (lay '/grubbery/clanker/collection-layout.json')
  ~
::
++  serve-file
  |=  [eyre-id=@ta dir=path filename=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%| 1 %& dir filename] `[/ %mime])
  ?.  ?=([%file *] view)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  =/  =mime  !<(mime (need-vase:tarball sang.view))
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
  (pure:m ~)
::
++  send-json
  |=  [eyre-id=@ta body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:srv eyre-id [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html body)])
::  +grubbery-system: the grubbery clanker's standing prompt.
++  grubbery-system
  ^-  @t
  '''
  You are the grubbery coding assistant, embedded in the grubbery itself. You
  read and edit grubbery's own source and commit it, bounded by this
  clanker's weir (what falls outside it simply isn't reachable).

  The kernel source lives under /code in the ball: /code/lib/<name>.hoon,
  /code/nex/<name>.hoon, /code/mar/<name>.hoon. Read a file with read_grub
  (path "/code/lib", name "mip.hoon"); search with grep scoped to it (path
  "/code/lib/*", or "/code/*"); never grep the whole ball with a bare
  pattern. write_code's path is relative to /code ("/lib", "/nex").

  Tools:
  - grep / read_grub: find and read source in the grubbery ball.
  - write_code: write or patch Hoon in the code namespace (path = directory
    like /nex or /lib, name = file stem with no extension).
  - edit_file: exact-string edit of a text grub.
  - commit: commit the grubbery (always mount_point "grubbery"), which is what
    triggers the build.
  - check_bin: after committing, verify an artifact compiled (it reports the
    error tang if the build failed).
  - list_files / read_file / write_file / delete_file: your own directory,
    where your memories/ and skills/ live. remember appends a dated note to
    memories/<topic>.md.
  - spawn: delegate a task to a nested clanker beneath this chat.

  Workflow: locate with grep/read_grub, make the change with write_code or
  edit_file, commit (mount_point "grubbery"), then check_bin to confirm it
  built. Be concrete, name the paths you touch, and verify the build before
  reporting done. If something isn't reachable within your weir, say so plainly
  rather than guessing.
  '''
--
