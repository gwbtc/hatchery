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
::    /panes/<name>.js                     the panes: a chat, a clanker, a recipe
::
::  This nexus runs no turns. It mounts clankers, keeps the tree, and
::  serves its API; a chat message is a poke to that clanker's own
::  main.sig. The PAGE is the explorer's: /grubbery/clanker serves the
::  explorer's browse page (its <namespace-explorer> component) mounted
::  at this route and rooted at the collection, so /grubbery/clanker/
::  <path> is the explorer at that path. The same declaration points the
::  explorer, whose view.json rules say per path which pane it opens
::  in: a chat-log opens in the chat pane (panes/chat.js) in this
::  explorer, nowhere else. One explorer, one tree, one tab bar.
::
/<  clanker    /lib/clanker.hoon
/<  nex-tools  /lib/tools.hoon
::  the collection's own tools nexus: clankers, chat_status, send,
::  resolve, stop, ensure (what the page's api does, for a tool caller)
/&  coll-tools  /lib/clanker-collection-bundle/
/&  chat-pane-js     ./panes/chat.js
/&  clanker-pane-js  ./panes/clanker.js
/&  recipe-pane-js   ./panes/recipe.js
/<  rcp-lib     /lib/recipe.hoon
/&  icon        ./icon.svg
/&  chat-html   ./chat.html
/&  chat-js     ./chat.js
/&  chat-css    ./chat.css
::  the layouts the explorer opens the collection's dirs as ('./' paths
::  resolve against the dir opened): the collection root or a category
::  (selector | a tab per clanker) and a clanker (its tree | chats, record)
/&  coll-layout     ./collection-layout.json
/&  clanker-layout  ./clanker-layout.json
/&  chat-layout     ./chat-layout.json
/&  stage-layout    ./stage-layout.json
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
        http-dispatch:io
          [~ %'sand.sig']
        (sand-watch prod)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%clanker request: failed")
        (handle-request name.rail)
      ==
    --
|%
::  +rows: the on-load tree. %fall for the workspace (seed once, then the
::  tree is the live, user-owned record); %over for product code.
++  rows
  ^-  (list row:loader)
  =/  tile=json
    %-  pairs:enjs:format
    :~  title+s+'Clanker'
        kind+s+'app'
        info+s+'Chat workspace, built from inside'
        color+s+'#3d3a45'
        image+s+'/grubbery/tiles/icon/clanker.clanker'
        href+s+'/grubbery/clanker'
    ==
  :~  (manifest:loader 0)
      [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'clanker'] ['description' s+'The grubbery chat workspace']])]]
      [%over %& [/ %'weir.json'] [[/ %json] weir-ask]]
      [%over %& [/ %'tile.json'] [[/ %json] tile]]
      ::  the panes the rules hand out: a chat, a clanker's own forms
      ::  and lists, a recipe graph
      [%fall %| /panes empty-dir:loader]
      [%over %& [/panes %'chat.js'] [[/ %mime] chat-pane-js]]
      [%over %& [/panes %'recipe.js'] [[/ %mime] recipe-pane-js]]
      [%over %& [/panes %'clanker.js'] [[/ %mime] clanker-pane-js]]
      [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
      ::  the plain face: one assistant and a composer, which the tile
      ::  opens. The workspace is the explorer, a link away.
      [%over %& [/ %'chat.html'] [[/ %mime] chat-html]]
      [%over %& [/ %'chat.js'] [[/ %mime] chat-js]]
      [%over %& [/ %'chat.css'] [[/ %mime] chat-css]]
      [%over %& [/ %'collection-layout.json'] [[/ %mime] coll-layout]]
      [%over %& [/ %'clanker-layout.json'] [[/ %mime] clanker-layout]]
      [%over %& [/ %'chat-layout.json'] [[/ %mime] chat-layout]]
      [%over %& [/ %'stage-layout.json'] [[/ %mime] stage-layout]]
      [%over %& [/ %'root-layout.json'] [[/ %mime] root-layout]]
      ::  the nexus root declares every view: the explorer landing ON it
      ::  (by name, @clanker) opens the root layout, and the paths under
      ::  /projects match the rules that follow it in the same table. A
      ::  view.json is read at a nexus root and nowhere else
      ::  (explorer.hoon +find-views), and /projects is not one.
      [%over %& [/ %'view.json'] [[/ %json] view-decl]]
      [%fall %& [/ %'http.sig'] [[/ %sig] ~]]
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      ::  the weir keeper: sands every clanker once on rise and again
      ::  whenever the proxy's name moves (+sand-watch); never per message
      [%fall %& [/ %'sand.sig'] [[/ %sig] ~]]
      [%over %| /tools (seed-tools:nex-tools coll-tools)]
      [%fall %| /requests empty-dir:loader]
      [%fall %| /projects empty-dir:loader]
      ::  the grubbery clanker: the kernel self-editing tools, a wide weir.
      ::  Seeded without the proxy roads resolved (on-load cannot peek);
      ::  +sand-clanker re-sands it on every send.
      [%fall %| [%projects %'grubbery.clanker' ~] (clanker-bole 'grubbery' 'kernel' grubbery-system (kernel-weir ~) ~)]
      ::  the assistant the plain page opens: the same kernel tools, a
      ::  prompt that explains the ship rather than its source
      [%fall %| [%projects %assistant ~] empty-dir:loader]
      [%fall %| [%projects %assistant %'groundwire.clanker' ~] assistant-bole]
  ==
::  +view-decl: /view.json, what the explorer reads (see explorer.hoon
::  +find-views): the table of how this nexus's paths open, and the
::  chrome of an explorer rooted here. The first rule is the root itself
::  — landing on @clanker opens the root layout — and +view-rules has
::  the rest, matched from here, so a path is spelled 'projects/...'.
++  app-icon  ^-(@t '/grubbery/clanker/icon.svg')
++  view-decl
  ^-  json
  =/  root-rule=json
    %-  pairs:enjs:format
    :~  ['match' s+'']  ['kind' s+'dir']
        ['layout' s+'/grubbery/clanker/root-layout.json']
        ['icon' s+app-icon]
    ==
  %-  pairs:enjs:format
  :~  ['rules' a+[root-rule view-rules]]
      ['title' s+'clanker']
      ['icon' s+'/grubbery/clanker/icon.svg']
  ==
::  +view-rules: the table under +view-decl's root rule — which pane a
::  path in the collection opens in, from the path, whether it is a file
::  or a dir, and the moment's own view name ('' is the bare path;
::  'collection', 'record', 'tools', 'config', 'tip' and 'stage' are
::  ours). Matched from the nexus root, so every pattern and every
::  followed road names 'projects' first; the captures after it stay
::  relative to the collection, which is how /api/collection and the
::  panes spell a clanker. The first rule that
::  matches wins, so the specific paths come first and the collection's
::  own catch-alls last. The rule between them matches anything inside a
::  clanker and names nothing: that path is the explorer's own to render,
::  and the catch-alls do not get to claim it. `follow` names the roads a
::  pane depends on, so the explorer's stream tells it when they move. A
::  pane is about the path it opens on; keep it that way.
::
++  view-rules
  ^-  (list json)
  =/  fol
    |=  [road=@t body=? fold=?]
    ^-  json
    (pairs:enjs:format ~[['road' s+road] ['body' b+body] ['fold' b+fold]])
  =/  pane
    |=  [v=@t script=@t a=(list [@t json]) f=(list json)]
    ^-  (list [@t json])
    :_  ~
    :-  'pane'
    %-  pairs:enjs:format
    :~  ['view' s+v]  ['script' s+script]
        ['args' (pairs:enjs:format a)]  ['follow' a+f]
    ==
  =/  lay  |=(u=@t ^-((list [@t json]) ~[['layout' s+u]]))
  =/  rul
    |=  [match=@t kind=@t views=(list @t) body=(list [@t json])]
    ^-  json
    %-  pairs:enjs:format
    ;:  weld
      ~[['match' s+match]]
      ?:(=('' kind) ~ ~[['kind' s+kind]])
      ?~(views ~ ~[['view' a+(turn views |=(v=@t `json`s+v))]])
      body
    ==
  =/  panes=@t       '/grubbery/clanker/panes/clanker.js'
  =/  tool-panes=@t  '/grubbery/tools/pane.js'
  ::  a chat: {1} is the clanker it belongs to, {2} the chat's own name
  =/  log=@t   'projects/**/chats/*/log.chat-log'
  =/  chat=(list [@t json])  ~[['proj' s+'/{1}'] ['chat' s+'{2}']]
  ::  a clanker named anywhere in the tree: {1} is what it sits under,
  ::  {2} its name without the suffix, so './projects/{1}/{2}.clanker' is it
  =/  cfg=@t   'projects/**/*.clanker/config.json'
  =/  proj=(list [@t json])  ~[['proj' s+'/{1}/{2}.clanker']]
  :~
    ::  a chat's log: the chat itself, or one of the three forms over it
    ::  (its prompt, its tool policy, its recipe run). The log is followed
    ::  by name only -- the pane holds a window of it and fetches what is
    ::  past that window on each change, never the whole array.
      %^  rul  log  'file'
      :-  ~['prompt']
      %^  pane  'record'  panes
      [chat ~[(fol './projects/{1}/chats/{2}/system.md' | |)]]
      %^  rul  log  'file'
      :-  ~['tip']
      %^  pane  'tip'  panes
      :-  chat
      ~[(fol './projects/{1}/chats/{2}/run.json' | |) (fol './projects/{1}/chats/{2}/log.chat-log' | |)]
      %^  rul  log  'file'
      :-  ~['tools']
      %^  pane  'tools'  panes
      :-  chat
      ~[(fol './projects/{1}/chats/{2}/tools.json' | |) (fol './projects/{1}/tools.json' | |)]
      %^  rul  log  'file'
      :-  ~
      %^  pane  'chat'  '/grubbery/clanker/panes/chat.js'
      [chat ~[(fol './projects/{1}/chats/{2}/log.chat-log' | |)]]
    ::  a tool's source under a clanker's tools nexus: the shell's tool
    ::  pane, following the file so an edit redraws it
      %^  rul  'projects/**/*.clanker/tools/code/lib/tools/**'  'file'
      :-  ~
      %^  pane  'tool'  tool-panes
      :-  ~[['at' s+'./projects/{1}/{2}.clanker/tools'] ['file' s+'/{3}']]
      ~[(fol './projects/{1}/{2}.clanker/tools/code/lib/tools/{3}' & |)]
    ::  a recipe: its graph beside its aims, redrawn when the json changes
      %^  rul  'projects/**/*.clanker/recipes/*'  'file'
      :-  ~
      %^  pane  'recipe'  '/grubbery/clanker/panes/recipe.js'
      :-  ~[['proj' s+'/{1}/{2}.clanker'] ['name' s+'{3}']]
      ~[(fol './projects/{1}/{2}.clanker/recipes/{3}' & |)]
    ::  a clanker's standing prompt, its settings and its tool policy, as
    ::  three forms all opened on its config.json. The prompt is `record`
    ::  alone: the model and the provider live in `config`, so the two
    ::  are edited and saved apart and neither clobbers the other.
      %^  rul  cfg  'file'
      :-  ~['tools']
      %^  pane  'tools'  panes
      :-  proj
      :~  (fol './projects/{1}/{2}.clanker/tools.json' | |)
          (fol './projects/{1}/{2}.clanker/tools/code/lib/tools' | &)
      ==
      %^  rul  cfg  'file'
      :-  ~['config']
      %^  pane  'config'  panes
      [proj ~[(fol './projects/{1}/{2}.clanker/config.json' & |)]]
      %^  rul  cfg  'file'
      :-  ~['record']
      %^  pane  'record'  panes
      [proj ~[(fol './projects/{1}/{2}.clanker/prompts/main.md' | |)]]
    ::  a clanker's tools/ is its tools nexus: the shell's tools pane,
    ::  live on the tools' code and on the runs
      %^  rul  'projects/**/*.clanker/tools'  'dir'
      :-  ~
      %^  pane  'tools-nexus'  tool-panes
      :-  ~[['at' s+'./projects/{1}/{2}.clanker/tools']]
      :~  (fol './projects/{1}/{2}.clanker/tools/code/lib/tools' | &)
          (fol './projects/{1}/{2}.clanker/tools/runs' | &)
      ==
    ::  a clanker's chats/ is its list of chats, live on the dir
      %^  rul  'projects/**/chats'  'dir'
      :-  ~
      %^  pane  'chats'  panes
      [~[['proj' s+'/{1}']] ~[(fol './projects/{1}/chats/' | &)]]
    ::  a chat's own directory opens as the chat layout (the chat | its
    ::  prompt), rooted at it; ?view=stage is the staging view, the chat
    ::  in the left third and its stage.layout, followed, in the rest
      (rul 'projects/**/*.clanker/chats/*' 'dir' ~['stage'] (lay '/grubbery/clanker/stage-layout.json'))
      (rul 'projects/**/*.clanker/chats/*' 'dir' ~ (lay '/grubbery/clanker/chat-layout.json'))
    ::  a clanker itself opens as the clanker layout, rooted at it
      (rul 'projects/**.clanker' 'dir' ~ (lay '/grubbery/clanker/clanker-layout.json'))
    ::  anything else inside a clanker keeps the usual view, and the two
    ::  catch-alls below do not see it
      (rul 'projects/**/*.clanker/**' '' ~['*'] ~)
    ::  the collection root, or a category: the selector pane when asked
    ::  for it (the layout's left side), the layout otherwise. Two
    ::  patterns for each, because 'projects/**' takes what is under the
    ::  collection but not the collection itself. `parent` is the
    ::  category as /api/collection names it, from /projects down: the
    ::  root is '/', a category '/{1}', the capture after 'projects/'.
      %^  rul  'projects'  'dir'
      :-  ~['collection']
      %^  pane  'collection'  panes
      [~[['parent' s+'/']] ~[(fol './projects/' | &)]]
      %^  rul  'projects/**'  'dir'
      :-  ~['collection']
      %^  pane  'collection'  panes
      [~[['parent' s+'/{1}']] ~[(fol './projects/{1}/' | &)]]
      (rul 'projects' 'dir' ~ (lay '/grubbery/clanker/collection-layout.json'))
      (rul 'projects/**' 'dir' ~ (lay '/grubbery/clanker/collection-layout.json'))
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
::  +assistant-bole: the clanker the plain page opens, carrying the title
::  it is shown under so the workspace names it the same thing.
::
++  assistant-bole
  ^-  bole:tarball
  =/  b=bole:tarball  (clanker-bole 'groundwire' 'kernel' assistant-system (kernel-weir ~) ~)
  %+  ~(put bo:tarball b)  [/ %'meta.json']
  [[/ %json] (pairs:enjs:format ~[['title' s+'Groundwire Assistant']])]
::
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
::  "poke": [...]}), each as the host spelled it: "/dir/" for a subtree,
::  "/dir/file" for one grub, or named, "@app/dir/", resolved through
::  /sys/link now. A named road whose app is not linked is left out. Set
::  again on every cause, so a moved name is followed (+sand-watch).
::
++  config-weir
  |=  [cfg=json prox=(list path)]
  =/  m  (fiber:fiber:nexus ,weir:tarball)
  ^-  form:m
  =/  base=weir:tarball
    ?:(=('kernel' (jstr:clanker cfg 'bundle')) (kernel-weir prox) (default-weir prox))
  =/  spelled
    |=  key=@t
    ^-  (list @t)
    ?.  ?=([%o *] cfg)  ~
    =/  rj  (~(get by p.cfg) 'roads')
    ?.  ?=([~ %o *] rj)  ~
    =/  pj  (~(get by p.u.rj) key)
    ?.  ?=([~ %a *] pj)  ~
    (murn p.u.pj |=(j=json ?.(?=([%s *] j) ~ `p.j)))
  =/  roads
    |=  l=(list @t)
    =/  mr  (fiber:fiber:nexus ,(list road:tarball))
    =|  out=(list road:tarball)
    |-  ^-  form:mr
    ?~  l  (pure:mr (flop out))
    ;<  got=(unit lane:tarball)  bind:mr  (resolve-road i.l)
    $(l t.l, out ?~(got out [[%& u.got] out]))
  ;<  peek=(list road:tarball)  bind:m  (roads (spelled 'peek'))
  ;<  make=(list road:tarball)  bind:m  (roads (spelled 'make'))
  ;<  poke=(list road:tarball)  bind:m  (roads (spelled 'poke'))
  ::  every name the config refers to, in its roads or as its repo, is
  ::  one the clanker's own tools resolve too, by peeking its link: a
  ::  named road is granted together with the name it is looked up by
  =/  links=(list road:tarball)
    %+  murn  (weld (spelled 'peek') (weld (spelled 'make') (weld (spelled 'poke') ~[(jstr:clanker cfg 'repo')])))
    |=  s=@t
    ^-  (unit road:tarball)
    =/  t=tape  (trip s)
    ?.  &(?=(^ t) =('@' i.t))  ~
    =/  cut=(unit @ud)  (find "/" t)
    =/  name=@t  (crip ?~(cut t (scag u.cut `tape`t)))
    `[%& %| (weld /sys/link (link-segs:io name))]
  %-  pure:m
  %=  base
    peek  (~(gas in (~(gas in peek.base) peek)) links)
    make  (~(gas in make.base) make)
    poke  (~(gas in poke.base) poke)
  ==
::  +resolve-road: a road as a host spells it, "/dir/" for a subtree,
::  "/dir/file" for one grub, or named: "@app/dir/", "@app/file", where
::  @app resolves through /sys/link now. ~ for a name that does not
::  resolve, or text that is not a road.
::
++  resolve-road
  |=  s=@t
  =/  m  (fiber:fiber:nexus ,(unit lane:tarball))
  ^-  form:m
  =/  t=tape  (trip s)
  ?~  t  (pure:m ~)
  =/  dir=?  =('/' (rear t))
  =/  body=tape  ?:(dir (snip `tape`t) t)
  =/  as-lane
    |=  pax=path
    ^-  (unit lane:tarball)
    ?:  dir  `[%| pax]
    ?~  pax  ~
    `[%& (snip `path`pax) (rear pax)]
  ?~  body  (pure:m ~)
  ?.  =('@' i.body)
    =/  pax=(unit path)  (rush (crip body) stap)
    (pure:m ?~(pax ~ (as-lane u.pax)))
  =/  cut=(unit @ud)  (find "/" body)
  =/  name=@t  (crip ?~(cut body (scag u.cut `tape`body)))
  =/  rest=(unit path)  ?~(cut `/ (rush (crip (slag u.cut `tape`body)) stap))
  ?~  rest  (pure:m ~)
  ;<  root=(unit lane:tarball)  bind:m  (resolve-link:io name)
  ?.  ?=([~ %| *] root)  (pure:m ~)
  (pure:m (as-lane (weld p.u.root u.rest)))
::  +sand-watch: a clanker's weir is set once per CAUSE, never per
::  message and never per reload. The kernel carries every directory's
::  weir through a reload, so the pass at the start only sands clankers
::  that have NO weir yet: one seeded at load was born before the proxy
::  could be resolved (on-load cannot peek). Then the proxy's registry
::  grub (/sys/link/anthropic/dest.lanes) is kept, and every move of it
::  re-sands them all: the alias changed, so the weirs follow. Making a
::  clanker (+handle-poke, /api/new) sands it then. A proxy not yet
::  linked: the keep finds nothing within the lull, so try again later.
++  sand-watch
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  (rise-wait:io prod "%clanker sand: failed")
  ;<  ~  bind:m  (sand-all %.n)
  |-
  ;<  any=?  bind:m  keep-registries
  ::  and every name there is: a host's named road ("@geocode/calls/")
  ::  resolves at sand time, so a name that moves re-sands them all
  ;<  *  bind:m  (keep-soft:io /links [%& %| /sys/link] ~ ~s30)
  ?.  any
    ;<  ~  bind:m  (sleep:io ~m5)
    $
  |-
  ;<  ~  bind:m  (take-news-any [/links registry-wires])
  ;<  ~  bind:m  (sand-all %.y)
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
::  +sand-all: every clanker in the collection, at any depth, sanded
::  from its config with the proxy as it resolves now. Runs in sand.sig's
::  fiber, at the collection root (up 0). all=%.n sands only clankers
::  that have no weir yet; all=%.y every one (an alias moved).
++  sand-all
  |=  all=?
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
    =/  dir=road:tarball  [%| 0 %| (welp /projects i.clankers)]
    ;<  cv=view:nexus  bind:m  (peek-shallow:io dir ~)
    =/  sanded=?
      ?&  ?=([%ball *] cv)
          ?=(^ fil.ball.cv)
          ?=(^ weir.u.fil.ball.cv)
      ==
    ?:  &(!all sanded)  $(clankers t.clankers)
    ;<  cfg=json  bind:m  (read-json [%| 0 %& (welp /projects i.clankers) %'config.json'])
    ;<  w=weir:tarball  bind:m  (config-weir cfg anth)
    ;<  ~  bind:m  (sand:io dir `w)
    $(clankers t.clankers)
  $(todo (weld t.todo kids))
::  +sand-clanker: (re)set one clanker's weir from its config with the
::  proxy as it resolves now, when it is made.
++  sand-clanker
  |=  [proj=path cfg=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  anth=(list path)  bind:m  proxy-roots
  ;<  w=weir:tarball  bind:m  (config-weir cfg anth)
  (sand:io [%| 1 %| (welp /projects proj)] `w)
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
  =/  action=@t  (jstr:clanker jon 'action')
  ?.  ?=(?(%'ensure' %'remove') action)  (pure:m ~)
  =/  name=@t  (jstr:clanker jon 'name')
  ?:  =('' name)  (pure:m ~)
  =/  parent=path
    (fall (rush =/(p=@t (jstr:clanker jon 'parent') ?:(=('' p) '/' p)) stap) /)
  ::  {action:'remove', parent, name} — the host's thing is gone, so its
  ::  clanker goes with it. A host that makes a clanker owns its life;
  ::  nothing here hunts for clankers whose owner vanished.
  ?:  =('remove' action)
    =/  dir=path  (welp /projects (snoc parent (crip "{(trip name)}.clanker")))
    ;<  dv=view:nexus  bind:m  (peek:io [%| 0 %| dir] ~)
    ?.  ?=([%ball *] dv)  (pure:m ~)
    (cull:io [%| 0 %| dir])
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
      ;<  w=weir:tarball  bind:m  (config-weir cfg anth)
      (make:io [%| 0 %| dir] &+(clanker-bole name bundle system w extra))
    =/  cfg-road=road:tarball  [%| 0 %& dir %'config.json']
    ;<  cur=json  bind:m  (read-json cfg-road)
    =/  merged=json
      :-  %o
      %-  ~(gas by ?:(?=([%o *] cur) p.cur *(map @t json)))
      [['bundle' s+bundle] extra]
    ;<  ~  bind:m  (over:io cfg-road [[/ %json] merged])
    ;<  w=weir:tarball  bind:m  (config-weir merged anth)
    (sand:io [%| 0 %| dir] `w)
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
::    GET  /panes/chat.js /icon.svg     the chat pane, the icon
::    GET  /api/root                     this instance's absolute root
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
    ;<  ~  bind:m  (send-simple:http-res:io eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
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
  ::  the panes: /panes/<what they are about>.js
  ?:  ?&  =(%'GET' method)
          ?=([%panes @ ~] suffix)
          |(=(%'chat.js' i.t.suffix) =(%'clanker.js' i.t.suffix) =(%'recipe.js' i.t.suffix))
      ==
    (serve-file eyre-id /panes i.t.suffix)
  ?:  ?&(=(%'GET' method) ?=([@ ~] suffix) |(=(%'chat.js' i.suffix) =(%'chat.css' i.suffix) =(%'icon.svg' i.suffix) =(%'collection-layout.json' i.suffix) =(%'clanker-layout.json' i.suffix) =(%'chat-layout.json' i.suffix) =(%'stage-layout.json' i.suffix) =(%'root-layout.json' i.suffix)))
    (serve-file eyre-id / i.suffix)
  ::  the root's view: the nexus root itself opens as the root layout
  ::  (the collection over ./projects); anything else at the root keeps
  ::  the usual view
  ::  the page: the explorer, rooted at the collection. The explorer
  ::  finds this nexus's views by itself (the root view.json), so
  ::  /grubbery/clanker/<path> is simply the explorer's own url for that
  ::  path under the collection
  ::  the root: the plain page, which is what the tile links to. A path
  ::  under it is the workspace, below.
  ?:  ?&(=(%'GET' method) ?=(~ suffix))
    (serve-file eyre-id / %'chat.html')
  ?:  ?&(=(%'GET' method) !?=([%api *] suffix))
    ;<  root=(unit lane:tarball)  bind:m  (resolve-link:io '@clanker')
    ?.  ?=([~ %| *] root)
      (send-simple:http-res:io eyre-id [[404 ~] `(as-octs:mimes:html 'clanker is not in /sys/link')])
    =/  coll=path  (snoc p.u.root %projects)
    =/  to=@t
      %-  crip
      ;:  weld
        "/grubbery/ball"  (spud coll)  ?~(suffix "" (spud suffix))
        "?scope="  (spud coll)
      ==
    (send-simple:http-res:io eyre-id [[302 ~[['location' to]]] ~])
  ?:  ?&(=(%'GET' method) =([%api %root ~] suffix))
    ;<  root=(unit lane:tarball)  bind:m  (resolve-link:io '@clanker')
    ?.  ?=([~ %| *] root)
      (send-simple:http-res:io eyre-id [[404 ~] `(as-octs:mimes:html 'clanker is not in /sys/link')])
    (send-json eyre-id (en:json:html (pairs:enjs:format ~[['root' s+(spat p.u.root)]])))
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
      =/  cdir=path  (welp /projects (welp u.proj [%chats `@ta`chat ~]))
      ;<  sys=@t  bind:m  (read-text [%| 1 %& cdir %'system.md'])
      ;<  mt=(unit json)  bind:m  (read-json-maybe [%| 1 %& cdir %'meta.json'])
      %+  send-json  eyre-id
      %-  en:json:html
      %-  pairs:enjs:format
      :~  ['path' s+(spat u.proj)]  ['chat' s+chat]  ['record' [%o ~]]
          ['system' s+sys]  ['meta' (fall mt [%o ~])]
      ==
    ;<  cfg=json  bind:m  (read-json [%| 1 %& (welp /projects u.proj) %'config.json'])
    ;<  sys=@t  bind:m  (read-text [%| 1 %& (welp /projects (snoc u.proj %prompts)) %'main.md'])
    ;<  mt=(unit json)  bind:m  (read-json-maybe [%| 1 %& (welp /projects u.proj) %'meta.json'])
    %+  send-json  eyre-id
    %-  en:json:html
    %-  pairs:enjs:format
    :~  ['path' s+(spat u.proj)]  ['record' cfg]  ['system' s+sys]
        ['meta' (fall mt [%o ~])]
    ==
  ?:  ?&(=(%'POST' method) =([%api %record ~] suffix))
    =/  proj=(unit path)  (parse-proj (jarg 'path'))
    ?~  proj  (bad eyre-id 'path required')
    =/  chat=@t  (jarg 'chat')
    ?.  =('' chat)
      =/  cdir=path  (welp /projects (welp u.proj [%chats `@ta`chat ~]))
      ;<  cv=view:nexus  bind:m  (peek:io [%| 1 %| cdir] ~)
      ?.  ?=([%ball *] cv)  (bad eyre-id 'no such chat')
      ;<  named=?  bind:m  (put-meta cdir body)
      =/  s=(unit json)  ?.(?=([%o *] body) ~ (~(get by p.body) 'system'))
      ?:  ?=([~ %s *] s)
        =/  bask=bask:tarball  [[/ %mime] [/text/markdown (as-octs:mimes:html p.u.s)]]
        ;<  *  bind:m  (make-soft:io [%| 1 %& cdir %'system.md'] |+[bask ~])
        ;<  ~  bind:m  (over:io [%| 1 %& cdir %'system.md'] bask)
        (send-json eyre-id '{"ok":true}')
      ?:  named  (send-json eyre-id '{"ok":true}')
      (bad eyre-id 'system or title required')
    ;<  *  bind:m  (put-meta (welp /projects u.proj) body)
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
  ;<  ~  bind:m  (send-simple:http-res:io eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
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
          ['spent' (fall (~(get by p.u.st) 'spent') ~)]
          ['last' s+(jstr:clanker u.st 'input')]
          ['busy' b+=('busy' state)]
          ['asking' b+=('asking' state)]
          ['prompt' b+!=('' sys)]
          ['recipe' recipe]
      ==
    ;<  log=json  bind:mj  (read-json [%| 1 %& cdir %'log.chat-log'])
    =/  evs=(list json)  ?:(?=([%a *] log) p.log ~)
    (pure:mj (chat-summary i.names evs !=('' sys)))
  ::  how it is shown, if it has been named: the list is the only place a
  ::  chat is seen without being opened
  ;<  mt=(unit json)  bind:m  (read-json-maybe [%| 1 %& cdir %'meta.json'])
  =/  title=json
    ?.  ?=([~ %o *] mt)  ~
    (fall (~(get by p.u.mt) 'title') ~)
  =/  titled=json
    ?.  ?=([%o *] row)  row
    [%o (~(put by p.row) 'title' title)]
  $(names t.names, acc [titled acc])
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
::  +put-meta: merge the body's `meta` object (and a bare `title`) into a
::  directory's meta.json, answering whether anything was given. How a
::  thing is RENDERED -- a chat's or a clanker's title -- kept beside it
::  and out of its record, which is what it runs on.
::
++  put-meta
  |=  [dir=path body=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  given=(map @t json)
    =/  o=(unit json)  ?.(?=([%o *] body) ~ (~(get by p.body) 'meta'))
    =/  base=(map @t json)  ?:(?=([~ %o *] o) p.u.o ~)
    =/  t=(unit json)  ?.(?=([%o *] body) ~ (~(get by p.body) 'title'))
    ?.(?=([~ %s *] t) base (~(put by base) 'title' u.t))
  ?:  =(~ given)  (pure:m %.n)
  ;<  cur=(unit json)  bind:m  (read-json-maybe [%| 1 %& dir %'meta.json'])
  =/  was=(map @t json)  ?:(?=([~ %o *] cur) p.u.cur ~)
  =/  b=bask:tarball  [[/ %json] [%o (~(uni by was) given)]]
  ;<  *  bind:m  (make-soft:io [%| 1 %& dir %'meta.json'] |+[b ~])
  ;<  ~  bind:m  (over:io [%| 1 %& dir %'meta.json'] b)
  (pure:m %.y)
::
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
  (send-simple:http-res:io eyre-id [[400 ~] `(as-octs:mimes:html msg)])
::
::
++  serve-file
  |=  [eyre-id=@ta dir=path filename=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%| 1 %& dir filename] `[/ %mime])
  ?.  ?=([%file *] view)
    ;<  ~  bind:m  (send-simple:http-res:io eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  =/  =mime  !<(mime (need-vase:tarball sang.view))
  ;<  ~  bind:m  (send-simple:http-res:io eyre-id (mime-response:http-utils mime))
  (pure:m ~)
::
++  send-json
  |=  [eyre-id=@ta body=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:http-res:io eyre-id [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html body)])
::  +grubbery-system: the grubbery clanker's standing prompt.
++  assistant-system
  ^-  @t
  '''
  You help the person who owns this ship understand and use it. They may be
  new to urbit and to grubbery, so explain in plain words and keep urbit
  jargon to what you have to use -- and when you use a word like desk, nexus,
  grub or weir, say what it means the first time it comes up.

  The ship's state is a namespace: a tree of directories and files called
  grubs, which you read with your tools. Apps are nexuses installed under
  /apps; a desk is a package of them. What is installed, where a thing lives,
  what an app does and what it has stored are all questions you answer by
  looking, not by guessing.

  Look things up before answering. If you do not know where something is,
  grep for it, scoped to a directory rather than the whole namespace. If a
  question is about this ship, the answer is in the ship -- prefer reading it
  over describing how it usually works.

  Tools:
  - grep / read_grub: find and read anything in the namespace.
  - list_files / read_file / write_file / delete_file: your own directory,
    where your memories/ live. remember appends a dated note to
    memories/<topic>.md -- use it for what the person tells you about
    themselves and their ship.

  You can also change things, and that is what the permission prompts are
  for. Say plainly what you are about to do and why before you ask. Never
  edit or delete anything you were not asked to.

  Answer briefly. One or two short paragraphs is almost always enough; offer
  the longer version rather than writing it unasked.

  On your first reply in a new conversation, call set_title with a short name
  for it. Do this every time, before you answer.
  '''
::
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
