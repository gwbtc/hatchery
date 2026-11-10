::  itinerary nexus: one trip per itinerary, planned on a map.
::
::  An itinerary organizes a single well-scoped trip: a bounded span of days,
::  a bounded stretch of map and, in time, a bounded budget. The budget is
::  the ambition the document does not hold yet. Today itinerary.json holds the
::  trip's name and description, its dates and timezone, the map's center
::  and zoom, the categories that colour and group everything, and the
::  things planned: pins (places, with notes and who suggested them), zones
::  (areas drawn on the map), a schedule (dated entries, fixed or tentative,
::  each tied to a pin) and todos. Next to the document sits files/, the
::  trip's attachments: tickets, schedules, photos.
::
::  On disk a trip is the dir /itineraries/<id>/ under this nexus, and that
::  dir is the unit of everything: one grant covers a trip, one cull deletes
::  it. The page at /grubbery/itinerary is a collection of trips; a trip
::  opens as a workspace with the map and a tab per view (trip, places,
::  events, schedule, todos, files, chat). The page reads, writes and follows
::  the document itself through the kernel's dart API, so this nexus serves
::  no document endpoints of its own. The explorer can open the same dirs:
::  this nexus tells it which layout or pane each path wants.
::
::  Two companion apps are reached by name, through /sys/link, and the trip
::  is designed around them being there:
::
::    @clanker   every trip gets its own clanker in the clanker collection,
::               at itinerary/<id>.clanker: the trip's assistant, with tools
::               over the document and the attachments, and a plan chat. The
::               chat tab is that clanker. Absent, the tab reads as absent.
::    @geocode   the place lookup the trip's assistant uses to turn names
::               into coordinates and back. Absent, the assistant's geocode
::               tool is left out of its grant and says so.
::
::  This file: the imports (the page, the explorer's panes and layouts, the
::  app's declarations, the prompts, shared components), then the nexus core
::  (+on-load lays the app out, +on-file runs its poke, its HTTP binding and
::  its requests), then the helpers: the poke, the trip's roads, serving,
::  reading the document, the explorer's viewer rule, and the trip clanker.
::
::  The page and its assets.
::
/&  index-html  ./index.html
/&  home-html   ./home.html
/&  app-js      ./app.js
/&  style-css   ./style.css
/&  icon        ./icon.svg
/<  files-js    ./files.js
/<  chat-js     ./chat.js
::  Talking to the clankers, and text templating.
::
/<  clankerio  /lib/clankerio.hoon
/<  text       /lib/text.hoon
::  The explorer's panes for a trip, and the layouts its dirs open as: the
::  collection (trips, then a tab per trip) and a trip (map, then its tabs).
::  './' paths in a layout resolve against the dir being opened.
::
/&  panes-js     ./panes.js
/&  coll-layout  ./collection-layout.json
/&  trip-layout  ./trip-layout.json
::  What this app declares about itself, as data: its tile, its name, the
::  roads it asks for, and how the explorer opens it.
::
/&  tile  ./tile.json
/&  link  ./link.json
/&  weir  ./weir.json
/&  view  ./view.json
::  The prompts: the trip clanker's standing prompt, with {{id}} and {{at}}
::  filled per trip, and the plan chat's.
::
/&  trip-prompt  ./system-prompt/trip.md
/&  plan-prompt  ./system-prompt/plan.md
::  Shared web components from /lib/ui. The first six are served as one
::  file, kit-js; the last two are classic scripts served on their own.
::
/<  ui          /lib/ui.hoon
/&  sv-js       /lib/ui/split-view.js
/&  tg-js       /lib/ui/tab-group.js
/&  dm-js       /lib/ui/drop-menu.js
/&  md-js       /lib/ui/modal-dialog.js
/&  ft-js       /lib/ui/file-table.js
/&  fg-js       /lib/ui/file-grid.js
/&  fp-js       /lib/ui/file-preview.js
/&  fmgr-js     /lib/ui/file-manager.js
=/  kit-js      (bundle:ui ~[sv-js tg-js dm-js md-js ft-js fg-js])
::
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (as-json:loader link)]]
          [%over %& [/ %'weir.json'] [[/ %json] (as-json:loader weir)]]
          [%over %& [/ %'tile.json'] [[/ %json] (as-json:loader tile)]]
          ::  view.json is read by the explorer: where to ask how a path under
          ::  this root opens (+pick-viewer), and the chrome of an explorer here.
          ::
          [%over %& [/ %'view.json'] [[/ %json] (as-json:loader view)]]
          [%over %& [/ %'panes.js'] [[/ %mime] panes-js]]
          [%over %& [/ %'collection-layout.json'] [[/ %mime] coll-layout]]
          [%over %& [/ %'trip-layout.json'] [[/ %mime] trip-layout]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] index-html]]
          [%over %& [/ %'home.html'] [[/ %mime] home-html]]
          [%over %& [/ %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ %'style.css'] [[/ %mime] style-css]]
          [%fall %| /ui empty-dir:loader]
          [%over %& [/ui %'components.js'] [[/ %mime] kit-js]]
          [%over %& [/ui %'file-preview.js'] [[/ %mime] fp-js]]
          [%over %& [/ui %'file-manager.js'] [[/ %mime] fmgr-js]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'http.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          ::  One dir per trip, holding its document and its attachments, so
          ::  one grant covers a whole trip and deleting it is one cull.
          ::
          [%fall %| /itineraries empty-dir:loader]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  The poke protocol: {action:'open', trip} gives a trip its dir,
          ::  its files/ and its clanker. The work needs this app's own reach,
          ::  so it is a poke to us rather than an endpoint of ours.
          ::
          [~ %'main.sig']
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ;<  ~  bind:m  (handle-poke rail jon)
        $
          ::  The HTTP binding. Each request is a fiber under /requests, below.
          ::
          [~ %'http.sig']
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/itinerary])
        (http-dispatch:io %itinerary)
          ::  One HTTP request. Only our own ship is served.
          ::
          [[%requests ~] @]
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:http-res:io eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  prefix=path  /grubbery/itinerary
        =/  suffix=path
          %+  skip  (slag (lent prefix) site)
          |=(s=@ta =('' s))
        =/  method=@t  method.request.req
        ::  GET / is the home page, /app the trip page; the rest are its assets.
        ::
        ?:  ?&  =(%'GET' method)
                ?|  =(~ suffix)
                    =([%app ~] suffix)
                    =([%'app.js' ~] suffix)
                    =([%'style.css' ~] suffix)
                    =([%'icon.svg' ~] suffix)
                ==
            ==
          =/  filename=@ta
            ?~  suffix  'home.html'
            ?:  =([%app ~] suffix)  'index.html'
            i.suffix
          (serve-file eyre-id / filename)
        ::  GET /panes.js and /collection-layout.json: the explorer's panes and
        ::  the collection's layout, served as they are.
        ::
        ?:  ?&(=(%'GET' method) ?=([@ ~] suffix) |(=(%'panes.js' i.suffix) =(%'collection-layout.json' i.suffix)))
          (serve-file eyre-id / i.suffix)
        ::  GET /trip/<id>/layout.json: the trip's workspace layout, the
        ::  template with the id filled in so its chat tab can name the trip's
        ::  own clanker (@clanker/projects/itinerary/<id>.clanker/chats/plan).
        ::  Asking for the layout is what makes that clanker and its chat exist,
        ::  the way the forge does for a repo. Only a trip that has its document
        ::  gets a workspace: an unknown id must not conjure a trip dir.
        ::
        ?:  ?&(=(%'GET' method) ?=([%trip @ %'layout.json' ~] suffix))
          =/  id=@ta  i.t.suffix
          ;<  doc=(unit json)  bind:m  (load-itinerary rail id)
          ?~  doc
            ;<  ~  bind:m  (send-simple:http-res:io eyre-id [[404 ~] `(as-octs:mimes:html 'no such trip')])
            (pure:m ~)
          ;<  ~  bind:m  (ensure-trip rail id)
          ;<  *  bind:m  (ensure-trip-clanker id)
          ;<  tv=view:nexus  bind:m  (peek:io [%| 1 %& / %'trip-layout.json'] `[/ %mime])
          ?.  ?=([%file *] tv)  (send-json eyre-id '{}')
          =/  tpl=@t  (from-mime:text !<(mime (need-vase:tarball sang.tv)))
          ;<  ~  bind:m  (send-simple:http-res:io eyre-id (mime-response:http-utils [/application/json (as-octs:mimes:html (fill:text tpl '{trip}' id))]))
          (pure:m ~)
        ::  GET /api/viewer?path=&kind=&view=&mode=: the explorer asks how a
        ::  path under this root opens. +pick-viewer answers; an empty answer
        ::  means we have no opinion.
        ::
        ?:  ?&(=(%'GET' method) =([%api %viewer ~] suffix))
          =/  gq  |=(k=@t ^-(@t (fall (~(get by (malt args)) k) '')))
          ;<  root=(unit lane:tarball)  bind:m  (resolve-link:io '@itinerary')
          =/  abs=path  ?.(?=([~ %| *] root) / p.u.root)
          =/  segs=path  =/(p=@t (gq 'path') ?:(=('' p) / (fall (mole |.((stab p))) /)))
          =/  pick=(unit json)
            (pick-viewer abs segs =('dir' (gq 'kind')) (gq 'view') (gq 'mode'))
          ?~  pick  (send-json eyre-id '')
          (send-json eyre-id (en:json:html u.pick))
        ::  GET /ui/*: the welded component bundle and the two classic scripts.
        ::
        ?:  ?&(=(%'GET' method) =([%ui %'components.js' ~] suffix))
          (serve-file eyre-id /ui 'components.js')
        ?:  ?&(=(%'GET' method) =([%ui %'file-preview.js' ~] suffix))
          (serve-file eyre-id /ui 'file-preview.js')
        ?:  ?&(=(%'GET' method) =([%ui %'file-manager.js' ~] suffix))
          (serve-file eyre-id /ui 'file-manager.js')
        ::  The two tab panes built into this file: the files tab, a file
        ::  manager scoped to the trip's files/, and the chat tab, the trip's
        ::  clanker shown in the collection's own pane.
        ::
        ?:  ?=([%'files.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:http-res:io eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.files-js])
          (pure:m ~)
        ?:  ?=([%'chat.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:http-res:io eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.chat-js])
          (pure:m ~)
        ;<  ~  bind:m  (send-simple:http-res:io eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
        (pure:m ~)
      ==
    --
|%
::  +handle-poke: the poke protocol. {action:'open', trip} means the trip is
::  being opened: it gets its dir, its files/ and its clanker. The page
::  cannot do this itself, since the clanker's ensure payload (bundle,
::  roads, prompt) is ours to compose. Anything else is ignored.
::
++  handle-poke
  |=  [here=rail:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (pure:m ~)
  ?.  =([~ %s %'open'] (~(get by p.jon) 'action'))  (pure:m ~)
  =/  trip=(unit json)  (~(get by p.jon) 'trip')
  ?.  ?=([~ %s *] trip)  (pure:m ~)
  =/  id=@ta  p.u.trip
  ;<  doc=(unit json)  bind:m  (load-itinerary here id)
  ?~  doc  (pure:m ~)
  ;<  ~  bind:m  (ensure-trip here id)
  ;<  *  bind:m  (ensure-trip-clanker id)
  (pure:m ~)
::  The roads of a trip, built from the asking fiber's own rail: main.sig
::  runs at the app root, a request fiber one dir below it, and +nex-road
::  counts the steps so neither has to.
::
++  itin-dir                                            ::  /itineraries/<id>/
  |=  [here=rail:tarball itin-id=@ta]
  ^-  road:tarball
  (nex-road:io here [%| (snoc `path`/itineraries itin-id)])
++  itin-road                                           ::  the trip's document
  |=  [here=rail:tarball itin-id=@ta]
  ^-  road:tarball
  (nex-road:io here [%& (snoc `path`/itineraries itin-id) %'itinerary.json'])
++  files-dir                                           ::  the trip's attachments
  |=  [here=rail:tarball itin-id=@ta]
  ^-  road:tarball
  (nex-road:io here [%| (weld (snoc `path`/itineraries itin-id) `path`/files)])
::  +ensure-trip: the trip dir and its files/ exist. Idempotent. An older
::  trip missing its files/ gets it here, so no tab of its workspace reads
::  as absent.
::
++  ensure-trip
  |=  [here=rail:tarball itin-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io (itin-dir here itin-id) ~)
  ?.  ?=([%ball *] dv)
    %+  make:io  (itin-dir here itin-id)
    &+[`[~ ~ %.n ~] (malt `(list [@ta bole:tarball])`~[[%files empty-dir:loader]])]
  ;<  fv=view:nexus  bind:m  (peek:io (files-dir here itin-id) ~)
  ?:  ?=([%ball *] fv)  (pure:m ~)
  (make:io (files-dir here itin-id) &+empty-dir:loader)
::  +serve-file: one of our own grubs as the response, or a 404.
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
::  +load-itinerary: the trip's document as json; ~ if there is none or it
::  does not parse.
::
++  load-itinerary
  |=  [here=rail:tarball itin-id=@ta]
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (itin-road here itin-id) `[/ %json])
  ?.  ?=([%file *] view)
    (pure:m ~)
  ?:  (is-boom:tarball sang.view)
    (pure:m ~)
  =/  jon=json  !<(json (need-vase:tarball sang.view))
  (pure:m `jon)
::  +pick-viewer: which pane a path under this root opens in, from the path,
::  whether it is a dir, and the moment's ?view= and ?mode=. The answer is
::  the explorer's viewers json: {layout} for a dir that opens as a layout,
::  {view, script, args, follow} for a pane. `follow` names the roads the
::  pane depends on, absolute (abs is this root), with the document's body
::  riding along so a pane redraws from the stream.
::
::    /                                  the collection layout
::    /itineraries                       the trips navigator (follows the dir)
::    /itineraries/<id>                  the trip layout
::    /itineraries/<id>/itinerary.json   ?view=map|trip|todos|places|events|schedule
::
::  mode is 'mobile' or 'desktop' (empty from an older caller). Mobile is
::  the focused, fat-thumb context rather than a narrow desktop, so a rule
::  may answer it with a different pane. These answer the same one.
::
++  pick-viewer
  |=  [abs=path segs=path dir=? view=@t mode=@t]
  ^-  (unit json)
  =/  lay  |=(u=@t ^-((unit json) `(pairs:enjs:format ~[['layout' s+u]])))
  =/  pane
    |=  [v=@t road=@t body=? fold=?]
    ^-  (unit json)
    %-  some
    %-  pairs:enjs:format
    :~  ['view' s+v]
        ['script' s+'/grubbery/itinerary/panes.js']
        ['args' [%o ~]]
        ['follow' a+~[(pairs:enjs:format ~[['road' s+road] ['body' b+body] ['fold' b+fold]])]]
    ==
  ?~  segs  ?:(=('' view) (lay '/grubbery/itinerary/collection-layout.json') ~)
  ::  The trips navigator is the only way to look at /itineraries, so the
  ::  bare dir opens it too, as / and a trip dir already do.
  ::
  ?:  ?=([%itineraries ~] segs)
    ?.  |(=('trips' view) =('' view))  ~
    (pane 'itin-trips' (cat 3 (spat (weld abs /itineraries)) '/') %.n %.y)
  ?:  ?=([%itineraries @ ~] segs)
    ?:  &(dir =('' view))  (lay (crip "/grubbery/itinerary/trip/{(trip i.t.segs)}/layout.json"))
    ~
  ?:  ?=([%itineraries @ %'itinerary.json' ~] segs)
    =/  p=path  segs                                    ::  weld's wet gate cannot mull the narrowed segs
    =/  road=@t  (spat (weld abs p))
    ?:  =('map' view)       (pane 'itin-map' road %.y %.n)
    ?:  =('trip' view)      (pane 'itin-trip' road %.y %.n)
    ?:  =('todos' view)     (pane 'itin-todos' road %.y %.n)
    ?:  =('places' view)    (pane 'itin-places' road %.y %.n)
    ?:  =('events' view)    (pane 'itin-events' road %.y %.n)
    ?:  =('schedule' view)  (pane 'itin-schedule' road %.y %.n)
    ~
  ~
::  +ensure-trip-clanker: the trip's clanker in the clanker collection, at
::  itinerary/<id>.clanker. It is a "build" bundle with the trip dir as its
::  "repo", so its repo_read/repo_write/repo_edit tools reach the document
::  and the attachments, plus a `plan` chat with the trip prompt. Made if
::  missing by a poke to @clanker's main.sig; a host field that changed (the
::  roads, the prompt) is folded in. ~ when no clanker app is linked or the
::  poke never packs: the chat tab then reads as absent.
::
::  The geocode dependency is the two endpoints the trip's geocode tool uses
::  AND the name it looks them up by. Resolving @geocode is a peek on
::  /sys/link/geocode, so a grant naming only the endpoints is refused at
::  the tool's first line: it holds the key and may not read the address.
::  Absent a geocode app, those roads are left out and the tool says so.
::
++  ensure-trip-clanker
  |=  id=@ta
  =/  m  (fiber:fiber:nexus ,(unit ~))
  ^-  form:m
  ;<  cl=(unit lane:tarball)  bind:m  (resolve-link:io '@clanker')
  ?.  ?=([~ %| *] cl)  (pure:m ~)
  ;<  it=(unit lane:tarball)  bind:m  (resolve-link:io '@itinerary')
  ?.  ?=([~ %| *] it)  (pure:m ~)
  ;<  geo=(unit lane:tarball)  bind:m  (resolve-link:io '@geocode')
  =/  trip=@t  (spat (weld p.u.it (snoc `path`/itineraries id)))
  =/  trip-dir=@t  (cat 3 trip '/')
  =/  geo=[poke=(list @t) peek=(list @t)]  (geocode-roads geo)
  =/  req=spec:clankerio
    :*  parent='/itinerary'
        name=id
        bundle='trip'
        system=(fills:text (from-mime:text trip-prompt) ~[['{{id}}' id] ['{{at}}' trip]])
        repo=trip
        roads=(roads:clankerio [trip-dir peek.geo] ~[trip-dir] poke.geo)
        chats=~[(chat:clankerio 'plan' (from-mime:text plan-prompt) allow:clankerio)]
        config=~
    ==
  ::  One soft poke, no peek first and no deadline: our weir grants the poke
  ::  on the collection's main.sig and nothing else, so a peek of it, or the
  ::  behn timer a deadline needs, would be vetoed and crash this request. A
  ::  veto or a nack answers `~ tang; a pack answers ~.
  ::
  =/  sig=road:tarball  [%& %& p.u.cl %'main.sig']
  ;<  res=(unit tang)  bind:m  (poke-soft:io sig [/ %json] (to-json:clankerio req))
  ?^  res  (pure:m ~)
  (pure:m `~)
::  +geocode-roads: what the trip clanker's geocode tool needs from the
::  geocode app: its main.sig to poke, and to peek its calls/ and the name
::  it is looked up by. None without the app.
::
++  geocode-roads
  |=  geo=(unit lane:tarball)
  ^-  [poke=(list @t) peek=(list @t)]
  ?.  ?=([~ %| *] geo)  [~ ~]
  :-  ~[(crip "{(spud p.u.geo)}/main.sig")]
  ~[(crip "{(spud p.u.geo)}/calls/") '/sys/link/geocode/']
--
