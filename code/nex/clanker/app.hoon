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
::    /ui/components.js                    the welded kit (tree, tabs, …)
::
::  This nexus runs no turns. It mounts clankers, keeps the tree, and
::  serves the page; a chat message is a poke to that clanker's own
::  main.sig. Files are edited through the kernel's file API, so the
::  page is the explorer's model: a tree on the left, tabs on the right.
::
/<  clanker    /lib/clanker.hoon
/<  nex-tools  /lib/tools.hoon
/&  index-html  ./index.html
/&  app-js      ./app.js
/&  style-css   ./style.css
/&  icon        ./icon.svg
::  shared web components from /lib/ui, welded into one served file
/&  sv-js       /lib/ui/split-view.js
/&  tg-js       /lib/ui/tab-group.js
/&  tv-js       /lib/ui/tree-view.js
/&  dm-js       /lib/ui/drop-menu.js
/&  md-js       /lib/ui/modal-dialog.js
/&  fp-js       /lib/ui/file-preview.js
/&  fv-js       /lib/ui/file-view.js
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
          [~ %'http.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%clanker http: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/clanker])
        (http-dispatch:io %clanker)
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
  =/  wrap
    |=  =mime  ^-  @
    (rap 3 ~[123 10 q.q.mime 10 125 10])
  =/  kit-js=mime
    :-  /application/javascript
    %-  as-octs:mimes:html
    (rap 3 ~[(wrap sv-js) (wrap tg-js) (wrap tv-js) (wrap dm-js) (wrap md-js)])
  =/  tile=json
    %-  pairs:enjs:format
    :~  title+s+'Clanker'
        info+s+'Chat workspace'
        color+s+'#3d3a45'
        image+s+'/grubbery/tiles/icon/clanker.clanker'
        href+s+'/grubbery/clanker'
    ==
  :~  (manifest:loader 0)
      [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'clanker'] ['description' s+'The grubbery chat workspace']])]]
      [%over %& [/ %'weir.json'] [[/ %json] weir-ask]]
      [%over %& [/ %'tile.json'] [[/ %json] tile]]
      [%over %& [/ %'index.html'] [[/ %mime] index-html]]
      [%over %& [/ %'app.js'] [[/ %mime] app-js]]
      [%over %& [/ %'style.css'] [[/ %mime] style-css]]
      [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
      [%fall %| /ui empty-dir:loader]
      [%over %& [/ui %'components.js'] [[/ %mime] kit-js]]
      [%over %& [/ui %'file-preview.js'] [[/ %mime] fp-js]]
      [%over %& [/ui %'file-view.js'] [[/ %mime] fv-js]]
      [%fall %& [/ %'http.sig'] [[/ %sig] ~]]
      [%fall %| /requests empty-dir:loader]
      [%fall %| /projects empty-dir:loader]
      ::  the grubbery clanker: the kernel self-editing tools, a wide weir.
      ::  Seeded without the proxy roads resolved (on-load cannot peek);
      ::  +sand-clanker re-sands it on every send.
      [%fall %| [%projects %'grubbery.clanker' ~] (clanker-bole 'grubbery' 'kernel' grubbery-system (kernel-weir ~))]
  ==
::  +weir-ask: what this nexus needs to reach. Clankers are nested here,
::  so their reach is bounded by ours: the proxy for every clanker, and
::  the kernel namespace for the grubbery one.
++  weir-ask
  ^-  json
  =/  road  |=([r=@t why=@t] (pairs:enjs:format ~[['road' s+r] ['why' s+why]]))
  %-  pairs:enjs:format
  :~  :-  'make'
      :-  %a
      :~  (road '/code/' 'the grubbery clanker edits kernel source')
      ==
      :-  'poke'
      :-  %a
      :~  (road '/sys/bowl.sig' 'time, identity, entropy')
          (road '/sys/eyre/' 'serve its page over HTTP')
          (road '/sys/' 'the grubbery clanker commits (hood) and reads clay')
          (road '@anthropic/main.sig' 'every clanker makes metered model calls')
      ==
      :-  'peek'
      :-  %a
      :~  (road '/sys/link/' 'find the proxy by name')
          (road '@anthropic/calls/' 'read a model call result')
          (road '/' 'the grubbery clanker reads kernel source and build results')
      ==
  ==
::
::  Clanker mounts. A clanker dir is an agent nexus: neck [/clanker %agent],
::  a weir that is its scope, and its two seed files; its own on-load lays
::  out the rest (memories/, skills/, chats/, tools/).
::
++  clanker-bole
  |=  [name=@t bundle=@t system=@t =weir:tarball]
  ^-  bole:tarball
  =/  cfg=json
    %-  pairs:enjs:format
    :~  ['name' s+name]
        ['model' s+'claude-sonnet-4-6']
        ['max_tokens' (numb:enjs:format 4.096)]
        ['bundle' s+bundle]
    ==
  =|  files=(map @ta [=bask:tarball gain=?])
  =.  files  (~(put by files) %'config.json' [[[/ %json] cfg] %.n])
  =.  files  (~(put by files) %'system.md' [[[/ %mime] [/text/markdown (as-octs:mimes:html system)]] %.n])
  [`[`[/clanker %agent] `weir %.n files] ~]
::  +default-weir: what any clanker may reach outside its own tree: time,
::  the model proxy. (Its own tree, its tools and its nested clankers are
::  inside it and need no grant.)
++  default-weir
  |=  anth=(unit path)
  ^-  weir:tarball
  =/  fil  |=([p=path n=@ta] `road:tarball`[%& %& p n])
  =/  dir  |=(p=path `road:tarball`[%& %| p])
  =/  opt  |=([u=(unit path) f=$-(path road:tarball)] ^-((list road:tarball) ?~(u ~ ~[(f u.u)])))
  :*  make=~
      poke=(sy (weld ~[(fil /sys 'bowl.sig')] (opt anth |=(p=path (fil p 'main.sig')))))
      peek=(sy (weld ~[(dir /sys/link/anthropic)] (opt anth |=(p=path (dir (snoc p %calls))))))
  ==
::  +kernel-weir: the grubbery clanker: the default plus the kernel
::  namespace its self-editing tools touch.
++  kernel-weir
  |=  anth=(unit path)
  ^-  weir:tarball
  =/  d=weir:tarball  (default-weir anth)
  :*  make=(~(put in make.d) `road:tarball`[%& %| /code])
      poke=(~(put in poke.d) `road:tarball`[%& %| /sys])
      peek=(~(put in peek.d) `road:tarball`[%& %| /])
  ==
::  +anthropic-root: the proxy, by name, when a fiber can look it up.
++  anthropic-root
  =/  m  (fiber:fiber:nexus ,(unit path))
  ^-  form:m
  ;<  anth=(unit lane:tarball)  bind:m  (resolve-link:io '@anthropic')
  (pure:m ?.(?=([~ %| *] anth) ~ `p.u.anth))
::  +sand-clanker: (re)set a clanker's weir with the proxy as it resolves
::  now. Called when a clanker is made and on every send, so one born
::  before the proxy existed, or seeded at load, still reaches it.
++  sand-clanker
  |=  [proj=path kernel=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  anth=(unit path)  bind:m  anthropic-root
  =/  w=weir:tarball  ?:(kernel (kernel-weir anth) (default-weir anth))
  (sand:io [%| 1 %| (welp /projects proj)] `w)
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
::    GET  /                             the page; /app.js /style.css /icon.svg
::    GET  /ui/<file>                    the welded kit, file-view, file-preview
::    GET  /api/root                     this instance's absolute root
::    GET  /api/tree                     the whole collection as {dirs, files}
::    GET  /api/record?path=             a clanker's config + system prompt
::    POST /api/record {path, system, model, max_tokens}
::    GET  /api/log?path=&chat=          one chat's event log
::    POST /api/send {path, chat, message}      -> pokes that clanker
::    POST /api/stop {path}                     -> interrupts that clanker
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
  ?:  ?&(=(%'GET' method) =(~ suffix))
    (serve-file eyre-id / 'index.html')
  ?:  ?&(=(%'GET' method) ?=([@ ~] suffix) |(=(%'app.js' i.suffix) =(%'style.css' i.suffix) =(%'icon.svg' i.suffix)))
    (serve-file eyre-id / i.suffix)
  ?:  ?&(=(%'GET' method) ?=([%ui @ ~] suffix))
    (serve-file eyre-id /ui i.t.suffix)
  ?:  ?&(=(%'GET' method) =([%api %root ~] suffix))
    ;<  root=(unit lane:tarball)  bind:m  (resolve-link:io '@clanker')
    ?.  ?=([~ %| *] root)
      (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'clanker is not in /sys/link')])
    (send-json eyre-id (en:json:html (pairs:enjs:format ~[['root' s+(spat p.u.root)]])))
  ?:  ?&(=(%'GET' method) =([%api %tree ~] suffix))
    ;<  dv=view:nexus  bind:m  (peek:io [%| 1 %| /projects] ~)
    ?.  ?=([%ball *] dv)  (send-json eyre-id '{"dirs":{},"files":[]}')
    (send-json eyre-id (en:json:html (tree-json ball.dv)))
  ?:  ?&(=(%'GET' method) =([%api %record ~] suffix))
    =/  proj=(unit path)  (parse-proj (arg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    ;<  cfg=json  bind:m  (read-json [%| 1 %& (welp /projects u.proj) %'config.json'])
    ;<  sys=@t  bind:m  (read-text [%| 1 %& (welp /projects u.proj) %'system.md'])
    %+  send-json  eyre-id
    (en:json:html (pairs:enjs:format ~[['path' s+(spat u.proj)] ['record' cfg] ['system' s+sys]]))
  ?:  ?&(=(%'POST' method) =([%api %record ~] suffix))
    =/  proj=(unit path)  (parse-proj (jarg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    =/  cfg-road=road:tarball  [%| 1 %& (welp /projects u.proj) %'config.json']
    ;<  cv=view:nexus  bind:m  (peek:io cfg-road `[/ %json])
    ?.  ?=([%file *] cv)  (bad eyre-id 'no such clanker')
    =/  cur=(map @t json)
      =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.cv)))) [%o ~])
      ?:(?=([%o *] j) p.j ~)
    =/  new=(map @t json)
      %+  roll  `(list @t)`~['model' 'max_tokens']
      |=  [k=@t acc=_cur]
      =/  v=(unit json)  ?.(?=([%o *] body) ~ (~(get by p.body) k))
      ?~(v acc (~(put by acc) k u.v))
    ;<  ~  bind:m  (over:io cfg-road [[/ %json] [%o new]])
    ;<  ~  bind:m
      =/  s=(unit json)  ?.(?=([%o *] body) ~ (~(get by p.body) 'system'))
      ?.  ?=([~ %s *] s)  (pure:m ~)
      %-  over:io
      :-  [%| 1 %& (welp /projects u.proj) %'system.md']
      [[/ %mime] [/text/markdown (as-octs:mimes:html p.u.s)]]
    (send-json eyre-id '{"ok":true}')
  ?:  ?&(=(%'GET' method) =([%api %log ~] suffix))
    =/  proj=(unit path)  (parse-proj (arg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    =/  chat=@t  =/(c=@t (arg 'chat') ?:(=('' c) 'main' c))
    ;<  log=json  bind:m
      (read-json [%| 1 %& (welp /projects (welp u.proj [%chats `@ta`chat ~])) %'log.json'])
    (send-json eyre-id (en:json:html ?:(?=([%a *] log) log [%a ~])))
  ?:  ?&(=(%'POST' method) =([%api %send ~] suffix))
    =/  proj=(unit path)  (parse-proj (jarg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    ;<  cfg=json  bind:m  (read-json [%| 1 %& (welp /projects u.proj) %'config.json'])
    ;<  ~  bind:m  (sand-clanker u.proj =('kernel' (jstr:clanker cfg 'bundle')))
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
      (pairs:enjs:format ~[['action' s+'interrupt']])
    (send-json eyre-id '{"ok":true}')
  ?:  ?&(=(%'POST' method) =([%api %new ~] suffix))
    =/  kind=@t  (jarg 'kind')
    =/  parent=(unit path)  (parse-proj =/(p=@t (jarg 'parent') ?:(=('' p) '/' p)))
    =/  name=@t  (jarg 'name')
    ?~  parent  (bad eyre-id 'bad parent')
    ?:  =('' name)  (bad eyre-id 'name required')
    ?:  =('category' kind)
      ;<  ~  bind:m
        (make:io [%| 1 %| (welp /projects (snoc u.parent `@ta`name))] &+empty-dir:loader)
      (send-json eyre-id '{"ok":true}')
    ?:  =('clanker' kind)
      =/  dir=@ta  (crip "{(trip name)}.clanker")
      =/  proj=path  (snoc u.parent dir)
      ;<  anth=(unit path)  bind:m  anthropic-root
      ;<  ~  bind:m
        (make:io [%| 1 %| (welp /projects proj)] &+(clanker-bole name 'default' '' (default-weir anth)))
      (send-json eyre-id '{"ok":true}')
    ?:  =('chat' kind)
      =/  dir=path  (welp /projects (welp u.parent [%chats `@ta`name ~]))
      ;<  dv=view:nexus  bind:m  (peek:io [%| 1 %| dir] ~)
      ;<  ~  bind:m
        ?:  ?=([%ball *] dv)  (pure:m ~)
        (make:io [%| 1 %| dir] &+empty-dir:loader)
      ;<  err=(unit tang)  bind:m
        (make-soft:io [%| 1 %& dir %'log.json'] |+[[[/ %json] [%a ~]] ~])
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
::  +tree-json: the collection as nested {dirs, files}, names only, one
::  deep peek. The page tells clankers from categories by name, chats by
::  position, so this stays a plain directory listing. A tools nexus is
::  folded: tools/code/lib/tools/*.hoon shows as tools/*.hoon, and its
::  runs/ stays as tools/runs/<id>, each run summarised from its state
::  ({tool, step, arg}) so the tree can show what ran and how it ended.
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
      ?.  =(%tools n)  [n (tree-json kid)]
      ::  tools/code/lib/tools/*.hoon -> tools/*.hoon
      =/  src=(unit ball:tarball)
        =/  a  (~(get by dir.kid) %code)
        ?~  a  ~
        =/  b  (~(get by dir.u.a) %lib)
        ?~  b  ~
        (~(get by dir.u.b) %tools)
      =/  names=(list @ta)
        ?~  src  ~
        ?~  fil.u.src  ~
        (sort ~(tap in ~(key by contents.u.fil.u.src)) aor)
      =/  runs=json  (runs-json (~(get by dir.kid) %runs))
      :-  n
      %-  pairs:enjs:format
      :~  ['dirs' [%o (malt `(list [@t json])`~[['runs' runs]])]]
          ['files' [%a (turn names |=(x=@ta s+x))]]
          ['tools' b+%.y]
      ==
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
