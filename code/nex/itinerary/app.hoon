::  itinerary nexus: one trip per itinerary, planned on a map.
::
::  An itinerary organizes a single well-scoped trip: a bounded span of days
::  and a bounded stretch of map. itinerary.json holds the trip's name and
::  description, its dates and timezone, the map's center and zoom, the
::  categories that colour and group everything, and the
::  things planned: pins (places, with notes and who suggested them), zones
::  (areas drawn on the map), a schedule (dated entries, fixed or tentative,
::  each tied to a pin) and todos. Next to the document sits files/, the
::  trip's attachments: tickets, schedules, photos. TODO: a budget.
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
::  its requests), then the helpers: the poke protocol and the trip's clanker
::  as a spec.
::
::  /itinerary frontend UI: page and assets.
::
/&  index-html  ./index.html         ::  the trip page
/&  home-html   ./home.html          ::  the home page, the collection of trips
/&  app-js      ./app.js
/&  style-css   ./style.css
/&  icon        ./icon.svg
/&  files-js    ./files.js           ::  the files tab
/&  chat-js     ./chat.js            ::  the chat tab
::  Helper libraries.
::
/<  clankerio   /lib/clankerio.hoon  ::  talking to the clankers
/<  text        /lib/text.hoon       ::  templating
/<  nw          /lib/nexus-web.hoon  ::  serving a page
::  The explorer's view of a trip.
::
/&  panes-js     ./panes.js                ::  its panes: map, trip, todos, places, events, schedule
/&  coll-layout  ./collection-layout.json  ::  how the collection opens: trips, then a tab per trip
/&  trip-layout  ./trip-layout.json        ::  how a trip opens: the map, then its tabs
::  What this app declares about itself, as data.
::
/&  tile  ./tile.json  ::  its launcher tile
/&  link  ./link.json  ::  its name
/&  weir  ./weir.json  ::  the roads it asks for
/&  view  ./view.json  ::  how the explorer opens it
::  The prompts.
::
/&  trip-prompt  ./system-prompt/trip.md  ::  the trip clanker's, {{id}} and {{at}} filled per trip
/&  plan-prompt  ./system-prompt/plan.md  ::  its plan chat's
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
=/  mount       /grubbery/itinerary                                   ::  where eyre sends our requests
=/  app-name    (cat 3 '@' (so:dejs:format (need (~(get jo:json-utils (as-json:loader link)) /name))))  ::  how we are reached, from link.json
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
          [%over %& [/ %'view.json'] [[/ %json] (as-json:loader view)]]      ::  the explorer's rules: how the paths under this root open
          [%over %& [/ %'panes.js'] [[/ %mime] panes-js]]
          [%over %& [/ %'collection-layout.json'] [[/ %mime] coll-layout]]
          [%over %& [/ %'trip-layout.json'] [[/ %mime] trip-layout]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] index-html]]
          [%over %& [/ %'home.html'] [[/ %mime] home-html]]
          [%over %& [/ %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ %'style.css'] [[/ %mime] style-css]]
          [%over %& [/ %'files.js'] [[/ %mime] files-js]]
          [%over %& [/ %'chat.js'] [[/ %mime] chat-js]]
          [%fall %| /ui empty-dir:loader]
          [%over %& [/ui %'components.js'] [[/ %mime] kit-js]]
          [%over %& [/ui %'file-preview.js'] [[/ %mime] fp-js]]
          [%over %& [/ui %'file-manager.js'] [[/ %mime] fmgr-js]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]                           ::  the poke protocol
          [%fall %& [/ %'http.sig'] [[/ %sig] ~]]                           ::  the http binding
          [%fall %| /requests empty-dir:loader]                             ::  one fiber per request
          [%fall %| /itineraries empty-dir:loader]                          ::  one dir per trip: its document and files/
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  json actions from the UI, one poke each, see +poke
          ::
          [~ %'main.sig']
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        ?.  =([/ %json] p.sage)  $
        ;<  ~  bind:m  (handle-poke rail !<(json q.sage))
        $
          ::  the http binding: eyre pokes http.sig once per request, and
          ::  +http-dispatch makes each a grub under /requests, run below
          ::
          [~ %'http.sig']
        ;<  ~  bind:m  (bind-http-self:io [~ mount])
        http-dispatch:io  ::  standard HTTP request-handling pattern
          ::  one request: who sent it, what it asks for, then by method and path.
          ::  The trip layout and the viewer answer are built here; every other
          ::  file is the kernel's to serve, so the request is sent on to it.
          ::
          [[%requests ~] @]
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)  (reply:web:nw eyre-id 403 'Forbidden')
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  route=path  (skip (slag (lent mount) site) |=(s=@ta =('' s)))  ::  the url after the mount, trailing slash dropped
        =*  web  web:nw
        ?+    method.request.req  (reply:web eyre-id 405 'Method not allowed')
            %'GET'
          ?+    route  (send-to-kernel:web eyre-id app-name route)
              ~                           (send-to-kernel:web eyre-id app-name ~[%'home.html'])
              [%app ~]                    (send-to-kernel:web eyre-id app-name ~[%'index.html'])
          ==
        ==
      ==
    --
|%
::  A poke to main.sig, json: what the page asks this nexus to do. A trip
::  is a directory under /itineraries with its document, files/ for its
::  attachments, and an assistant in the clanker collection; this nexus
::  makes and unmakes all three together. Editing the document is a
::  write, not a poke.
::
::    {action: 'create', trip: <id>, doc: <itinerary.json>}   +create-trip
::    {action: 'delete', trip: <id>}                          +delete-trip
::
+$  poke
  $%  [%create id=@ta doc=json]
      [%delete id=@ta]
  ==
::  +parse-poke: a poke's json as the action it names; ~ for any other.
::
++  parse-poke
  |=  jon=json
  ^-  (unit poke)
  =*  get  ~(get jo:json-utils jon)
  =/  trip  (get /trip)
  ?.  ?=([~ %s *] trip)  ~
  ?+    (get /action)  ~
      [~ %s %'create']
    =/  doc  (get /doc)
    ?~  doc  ~
    `[%create p.u.trip u.doc]
      [~ %s %'delete']
    `[%delete p.u.trip]
  ==
::  +handle-poke: one poke to main.sig, from this fiber's rail. Produces
::  nothing; a poke that names no action is ignored.
::
++  handle-poke
  |=  [here=rail:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  act=(unit poke)  (parse-poke jon)
  ?~  act  (pure:m ~)
  ?-  -.u.act
    %create  (create-trip here id.u.act doc.u.act)
    %delete  (delete-trip here id.u.act)
  ==
::  +create-trip: a new trip, by id, with its document. Its dir and
::  files/ first, then the document, then its assistant as
::  +trip-clanker-spec describes it. An id that already has a document
::  is a trip already, left as it is.
::
++  create-trip
  |=  [here=rail:tarball id=@ta doc=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  a trip is its document: one already there means the trip exists
  ;<  has=?  bind:m  (peek-exists:io (nex-road:io here [%& /itineraries/[id] %'itinerary.json']))
  ?:  has  (pure:m ~)
  ::  its dir, with files/ for attachments, before anything goes in it
  ;<  ~  bind:m
    %+  ensure-fold:io  (nex-road:io here [%| /itineraries/[id]])
    (dir:loader ~[[%files empty-dir:loader]])
  ::  the document, the trip itself
  ;<  ~  bind:m  (make:io (nex-road:io here [%& /itineraries/[id] %'itinerary.json']) |+[[[/ %json] doc] ~])
  ::  its assistant, last: its roads point into the dir, which now exists
  ;<  *  bind:m  (ensure:clankerio (trip-clanker-spec id))
  (pure:m ~)
::  +delete-trip: the trip, by id: its dir with everything in it, then
::  its assistant from the clanker collection.
::
++  delete-trip
  |=  [here=rail:tarball id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  the dir, and with it the document and the files
  ;<  ~  bind:m  (cull:io (nex-road:io here [%| /itineraries/[id]]))
  ::  its assistant, which we made, so it is ours to remove
  ;<  *  bind:m  (remove:clankerio '/itinerary' id)
  (pure:m ~)
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
      config=~[['web_search' (numb:enjs:format 5)]]                   ::  it may search the web, five times a turn
  ==
--
