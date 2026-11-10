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
::  Talking to the clankers, text templating, and serving a page.
::
/<  clankerio  /lib/clankerio.hoon
/<  text       /lib/text.hoon
/<  nw         /lib/nexus-web.hoon
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
          (serve-file:web:nw eyre-id / filename)
        ::  GET /panes.js and /collection-layout.json: the explorer's panes and
        ::  the collection's layout, served as they are.
        ::
        ?:  ?&(=(%'GET' method) ?=([@ ~] suffix) |(=(%'panes.js' i.suffix) =(%'collection-layout.json' i.suffix)))
          (serve-file:web:nw eyre-id / i.suffix)
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
          ;<  *  bind:m  (ensure:clankerio (trip-clanker-spec id))
          ;<  tv=view:nexus  bind:m  (peek:io [%| 1 %& / %'trip-layout.json'] `[/ %mime])
          ?.  ?=([%file *] tv)  (send-json:web:nw eyre-id [%o ~])
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
          ?~  pick  (reply:web:nw eyre-id 200 '')
          (send-json:web:nw eyre-id u.pick)
        ::  GET /ui/*: the welded component bundle and the two classic scripts.
        ::
        ?:  ?&(=(%'GET' method) =([%ui %'components.js' ~] suffix))
          (serve-file:web:nw eyre-id /ui 'components.js')
        ?:  ?&(=(%'GET' method) =([%ui %'file-preview.js' ~] suffix))
          (serve-file:web:nw eyre-id /ui 'file-preview.js')
        ?:  ?&(=(%'GET' method) =([%ui %'file-manager.js' ~] suffix))
          (serve-file:web:nw eyre-id /ui 'file-manager.js')
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
  ;<  *  bind:m  (ensure:clankerio (trip-clanker-spec id))
  (pure:m ~)
::  +trip-roads: the roads of one trip, from the asking fiber's own rail:
::  main.sig runs at the app root, a request fiber one dir below it, and
::  +nex-road counts the steps so neither has to.
::
++  trip-roads
  |_  [here=rail:tarball id=@ta]
  ++  base   ^-(path (snoc `path`/itineraries id))
  ++  dir    ^-(road:tarball (nex-road:io here [%| base]))                  ::  /itineraries/<id>/
  ++  doc    ^-(road:tarball (nex-road:io here [%& base %'itinerary.json']))  ::  the document
  ++  files  ^-(road:tarball (nex-road:io here [%| (weld base `path`/files)]))  ::  the attachments
  --
::  +trip-tree: what a trip is on disk, a dir with files/ for its
::  attachments; the document is the page's to write.
::
++  trip-tree
  ^-  bole:tarball
  (dir:loader ~[[%files empty-dir:loader]])
::  +ensure-trip: the trip dir laid out, made or completed, so no tab of
::  its workspace reads as absent.
::
++  ensure-trip
  |=  [here=rail:tarball itin-id=@ta]
  (ensure-fold:io ~(dir trip-roads here itin-id) trip-tree)
::  +load-itinerary: the trip's document as json; ~ if there is none or it
::  does not parse.
::
++  load-itinerary
  |=  [here=rail:tarball itin-id=@ta]
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io ~(doc trip-roads here itin-id) `[/ %json])
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
::  +trip-clanker-spec: the trip's assistant, as a clanker in the clanker
::  collection at itinerary/<id>.clanker, described as the collection
::  takes it (+ensure:clankerio sends it).
::
++  trip-clanker-spec
  |=  id=@ta
  ^-  spec:clankerio
  ::  what the assistant reaches, by name: the trip dir, to read and
  ::  write, and the geocode app, its main.sig to poke and its calls/ to
  ::  read. No geocode app linked, no geocode roads.
  ::
  =/  trip=@t  (rap 3 '@itinerary/itineraries/' id '/' ~)
  ::  the assistant: the trip bundle's tools over the trip dir as its
  ::  repo, its standing prompt filled in for this trip, and a plan chat
  ::
  :*  parent='/itinerary'
      name=id
      bundle='trip'
      repo=trip
      ^=  roads
      :*  peek=~[trip '@geocode/calls/']
          make=~[trip]
          poke=~['@geocode/main.sig']
      ==
      ^=  system
      %+  fills:text  (from-mime:text trip-prompt)
      ~[['{{id}}' id] ['{{at}}' trip]]
      chats=~[(chat:clankerio 'plan' (from-mime:text plan-prompt) allow:clankerio)]
      config=~
  ==
--
