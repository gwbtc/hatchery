::  itinerary nexus: travel maps with pins, zones and metadata
::
::  Per trip — a dir under /itineraries/: itinerary.json + files/.
::  The page reads, writes and follows those documents itself through the
::  kernel's own dart API, so this nexus serves no document endpoints. It
::  binds its page, answers the two layout questions the explorer asks by
::  URL, and takes one poke: give a trip its clanker.
::
/&  index-html  ./index.html
/&  home-html   ./home.html
/&  app-js      ./app.js
/&  style-css   ./style.css
/&  icon        ./icon.svg
/<  files-js    ./files.js
/<  chat-js     ./chat.js
::  the explorer's panes for a trip, and the layouts its dirs open as
::  ('./' paths resolve against the dir opened): the collection (trips |
::  a tab per trip) and a trip (map | its tabs)
/&  panes-js     ./panes.js
/&  coll-layout  ./collection-layout.json
/&  trip-layout  ./trip-layout.json
::  shared web components from /lib/ui (see web-test.hoon for the pattern)
/&  sv-js       /lib/ui/split-view.js
/&  tg-js       /lib/ui/tab-group.js
/&  dm-js       /lib/ui/drop-menu.js
/&  md-js       /lib/ui/modal-dialog.js
/&  ft-js       /lib/ui/file-table.js
/&  fg-js       /lib/ui/file-grid.js
::  classic-script preview surface (svg/html/json/image/pdf) for the
::  Files tab viewer — served separately, not welded (it isn't a module)
/&  fp-js       /lib/ui/file-preview.js
/&  fmgr-js     /lib/ui/file-manager.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ::  weld the component modules into one served file (single request);
      ::  each wrapped in { } so top-level consts don't collide.
      =/  wrap
        |=  =mime  ^-  @
        (rap 3 ~[123 10 q.q.mime 10 125 10])
      =/  kit-js=mime
        :-  /application/javascript
        %-  as-octs:mimes:html
        (rap 3 ~[(wrap sv-js) (wrap tg-js) (wrap dm-js) (wrap md-js) (wrap ft-js) (wrap fg-js)])
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Itinerary'
            kind+s+'app'
            info+s+'Travel maps & pins'
            color+s+'#27ae60'
            ::  full folder name, not the slug
            ::  also slugs to 'itinerary', wins the scan, and 404s
            image+s+'/grubbery/tiles/icon/itinerary.itinerary'
            href+s+'/grubbery/itinerary'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'itinerary'] ['description' s+'Travel maps with pins']])]]
          [%over %& [/ %'weir.json'] [[/ %json] (pairs:enjs:format ~[['poke' a+~[(pairs:enjs:format ~[['road' s+'/sys/bowl.sig'] ['why' s+'time, identity, entropy — every fiber op']]) (pairs:enjs:format ~[['road' s+'/sys/eyre/'] ['why' s+'serve its page and the explorer layouts over HTTP']]) (pairs:enjs:format ~[['road' s+'@clanker/main.sig'] ['why' s+'make each trip its clanker in the clanker collection (the trip workspace chat)']])]] ['peek' a+~[(pairs:enjs:format ~[['road' s+'/sys/link/'] ['why' s+'find this app, the clanker collection and the geocode proxy by name (a trip clanker is granted geocode)']])]]])]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          ::  the explorer reads view.json: where to ask which pane a path
          ::  under this root opens in (+pick-viewer), and the chrome of an
          ::  explorer rooted here
          [%over %& [/ %'view.json'] [[/ %json] (pairs:enjs:format ~[['viewers' s+'/grubbery/itinerary/api/viewer'] ['title' s+'itinerary'] ['icon' s+'/grubbery/itinerary/icon.svg']])]]
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
          ::  /itineraries/<id>/ is a trip: itinerary.json (the doc) and
          ::  files/ (attachments, written by the page's file manager and by
          ::  the trip clanker's file tools). One dir per trip, so one grant
          ::  covers everything per-trip and delete is one cull.
          [%fall %| /itineraries empty-dir:loader]
          ::  a trip's assistant is its clanker in the clanker collection
          ::  (+ensure-trip-clanker), sandboxed by clanker. This app runs
          ::  no agent of its own and reaches no model.
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  main.sig: the poke protocol. {action:'open', trip} gives a
          ::  trip its clanker — the work needs this app's own reach, so
          ::  it is a dart to us, not an endpoint of ours.
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%itinerary main: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ;<  ~  bind:m  (handle-poke rail jon)
        $
          ::  http.sig: the page, and the two layouts the explorer asks for
          [~ %'http.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%itinerary http: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/itinerary])
        (http-dispatch:io %itinerary)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%itinerary request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  prefix=path  /grubbery/itinerary
        =/  suffix=path
          %+  skip  (slag (lent prefix) site)
          |=(s=@ta =('' s))
        =/  method=@t  method.request.req
        ::
        ::  static files: GET /, /app.js, /style.css
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
        ::  the explorer's panes and layouts
        ?:  ?&(=(%'GET' method) ?=([@ ~] suffix) |(=(%'panes.js' i.suffix) =(%'collection-layout.json' i.suffix)))
          (serve-file eyre-id / i.suffix)
        ::  /trip/<id>/layout.json → this trip's workspace layout: the template
        ::  with the trip's id filled in, so its chat tab can name the trip's
        ::  own clanker (@clanker/projects/itinerary/<id>.clanker/chats/plan)
        ::  as a pane. Asking for the layout is what makes that clanker and
        ::  its chat exist; forge does the same for a repo.
        ?:  ?&(=(%'GET' method) ?=([%trip @ %'layout.json' ~] suffix))
          =/  id=@ta  i.t.suffix
          ::  only a trip that exists (has its doc) gets a workspace: asking
          ::  for an unknown id must not conjure a trip dir
          ;<  doc=(unit json)  bind:m  (load-itinerary rail id)
          ?~  doc
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'no such trip')])
            (pure:m ~)
          ;<  ~  bind:m  (ensure-trip rail id)
          ;<  *  bind:m  (ensure-trip-clanker id)
          ;<  tv=view:nexus  bind:m  (peek:io [%| 1 %& / %'trip-layout.json'] `[/ %mime])
          ?.  ?=([%file *] tv)  (send-json eyre-id '{}')
          =/  tpl=@t  `@t`q.q:!<(mime (need-vase:tarball sang.tv))
          ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/application/json (as-octs:mimes:html (fill-trip tpl id))]))
          (pure:m ~)
        ::  GET /api/viewer?path=&kind=&view= — the explorer asks, per path
        ::  under this root, how it opens (+pick-viewer)
        ?:  ?&(=(%'GET' method) =([%api %viewer ~] suffix))
          =/  gq  |=(k=@t ^-(@t (fall (~(get by (malt args)) k) '')))
          ;<  root=(unit lane:tarball)  bind:m  (resolve-link:io '@itinerary')
          =/  abs=path  ?.(?=([~ %| *] root) / p.u.root)
          =/  segs=path  =/(p=@t (gq 'path') ?:(=('' p) / (fall (mole |.((stab p))) /)))
          ::  mode is 'mobile' or 'desktop': the phone is a distinct context, not
          ::  a narrow desktop, so a rule may answer it with a different pane
          =/  pick=(unit json)
            (pick-viewer abs segs =('dir' (gq 'kind')) (gq 'view') (gq 'mode'))
          ?~  pick  (send-json eyre-id '')
          (send-json eyre-id (en:json:html u.pick))
        ::
        ::  GET /ui/components.js — welded web-component bundle
        ::
        ?:  ?&(=(%'GET' method) =([%ui %'components.js' ~] suffix))
          (serve-file eyre-id /ui 'components.js')
        ?:  ?&(=(%'GET' method) =([%ui %'file-preview.js' ~] suffix))
          (serve-file eyre-id /ui 'file-preview.js')
        ?:  ?&(=(%'GET' method) =([%ui %'file-manager.js' ~] suffix))
          (serve-file eyre-id /ui 'file-manager.js')
        ::  files tab: explorer-scrap file manager scoped to the trip's files/
        ?:  ?=([%'files.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.files-js])
          (pure:m ~)
        ::  chat tab: the trip's clanker, shown in the collection's own pane
        ?:  ?=([%'chat.js' ~] suffix)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'text/javascript']]] `q.chat-js])
          (pure:m ~)
        ::
        ::  404
        ::
        ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
        (pure:m ~)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'http.sig'])
::  +handle-poke: this app's poke protocol.
::    {action:'open', trip} — the trip is being opened: it gets its dir,
::    its files/ and its clanker. The page cannot do this itself: the
::    ensure payload is ours to compose (bundle, roads, prompt).
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
::
::  a trip is the dir /itineraries/<id>/; its doc is itinerary.json inside.
::  Every road is built from the asking fiber's own rail — main.sig runs at
::  the app root, a request fiber one dir below it, and +nex-road counts the
::  steps so neither has to.
++  itin-dir
  |=  [here=rail:tarball itin-id=@ta]
  ^-  road:tarball
  (nex-road:io here [%| (snoc `path`/itineraries itin-id)])
++  itin-road
  |=  [here=rail:tarball itin-id=@ta]
  ^-  road:tarball
  (nex-road:io here [%& (snoc `path`/itineraries itin-id) %'itinerary.json'])
::  the trip's attachments
++  files-dir
  |=  [here=rail:tarball itin-id=@ta]
  ^-  road:tarball
  (nex-road:io here [%| (weld (snoc `path`/itineraries itin-id) `path`/files)])
::  +ensure-trip: the trip dir and its files/ exist. Idempotent.
::
++  ensure-trip
  |=  [here=rail:tarball itin-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io (itin-dir here itin-id) ~)
  ?.  ?=([%ball *] dv)
    %+  make:io  (itin-dir here itin-id)
    &+[`[~ ~ %.n ~] (malt `(list [@ta bole:tarball])`~[[%files empty-dir:loader]])]
  ::  an older trip missing its files/ gets it here, so no tab of its
  ::  workspace reads as absent
  ;<  fv=view:nexus  bind:m  (peek:io (files-dir here itin-id) ~)
  ?:  ?=([%ball *] fv)  (pure:m ~)
  (make:io (files-dir here itin-id) &+empty-dir:loader)
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
::
::  +load-itinerary: read an itinerary file, return its json
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
::  +pick-viewer: which pane a path under this root opens in, from where
::  it is, whether it is a dir, and the moment's own ?view=. The answer
::  is the explorer's viewers json: {layout} for a dir that opens as a
::  layout, {view, script, args, follow} for a pane. `follow` names the
::  roads the pane depends on, absolute (abs is this root), with the
::  doc's body riding along so a pane redraws from the stream.
::    /                                  the collection layout
::    /itineraries  ?view=trips          the trips navigator (follows the dir)
::    /itineraries/<id>                  the trip layout
::    /itineraries/<id>/itinerary.json  ?view=map|trip|todos|places|events|schedule
::    `mode` is 'mobile' or 'desktop' (empty from an older caller). Mobile is
::    the focused, fat-thumb context rather than a narrow desktop, so a rule
::    may answer it with a different pane — or the same one, as these do.
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
  ::  trips is the ONLY way to look at this dir, so the bare dir opens it
  ::  too — the same courtesy / and a trip dir already get. Naming the view
  ::  bought nothing and made the moment depend on an argument.
  ?:  ?=([%itineraries ~] segs)
    ?.  |(=('trips' view) =('' view))  ~
    (pane 'itin-trips' (cat 3 (spat (weld abs /itineraries)) '/') %.n %.y)
  ?:  ?=([%itineraries @ ~] segs)
    ?:  &(dir =('' view))  (lay (crip "/grubbery/itinerary/trip/{(trip i.t.segs)}/layout.json"))
    ~
  ?:  ?=([%itineraries @ %'itinerary.json' ~] segs)
    ::  (the test narrows segs to a cell, which weld's wet gate cannot
    ::  mull; p is the plain path)
    =/  p=path  segs
    =/  road=@t  (spat (weld abs p))
    ?:  =('map' view)       (pane 'itin-map' road %.y %.n)
    ?:  =('trip' view)      (pane 'itin-trip' road %.y %.n)
    ?:  =('todos' view)     (pane 'itin-todos' road %.y %.n)
    ?:  =('places' view)    (pane 'itin-places' road %.y %.n)
    ?:  =('events' view)    (pane 'itin-events' road %.y %.n)
    ?:  =('schedule' view)  (pane 'itin-schedule' road %.y %.n)
    ~
  ~
::  +ensure-trip-clanker: the trip's clanker in the clanker collection
::  (itinerary/<id>.clanker): bundle "build" with the trip dir as its
::  "repo", so its repo_read/repo_write/repo_edit tools reach the doc and
::  the attachments, and a `plan` chat with the trip prompt. Made if
::  missing by a poke to @clanker's main.sig; a host field that changed
::  (the roads, the prompt) is folded in. ~ when no clanker app is
::  linked or the poke never packs: the chat tab then reads as absent.
++  ensure-trip-clanker
  |=  id=@ta
  =/  m  (fiber:fiber:nexus ,(unit ~))
  ^-  form:m
  ;<  cl=(unit lane:tarball)  bind:m  (resolve-link:io '@clanker')
  ?.  ?=([~ %| *] cl)  (pure:m ~)
  ;<  it=(unit lane:tarball)  bind:m  (resolve-link:io '@itinerary')
  ?.  ?=([~ %| *] it)  (pure:m ~)
  ::  the geocode proxy, by name: the trip's geocode tool pokes it and
  ::  reads its calls; absent, the roads are left out and the tool says so
  ;<  geo=(unit lane:tarball)  bind:m  (resolve-link:io '@geocode')
  ::  The geocode dependency: the two endpoints the tool uses, AND the name it
  ::  looks them up by. Resolving @geocode is a peek on /sys/link/geocode, so a
  ::  grant that names only the endpoints is refused at the tool's first line —
  ::  it holds the key and may not read the address. That is what wedged the
  ::  somewhere trip: every geocode call banged on the lookup, the run never
  ::  left step 'start', and the chat waited on it. The clanker already does
  ::  this correctly for @anthropic; geocode was bolted on as resolved paths
  ::  and the lookup was forgotten. See "Reads don't resolve" in the README.
  =/  geo-roads=[poke=(list @t) peek=(list @t)]
    ?.  ?=([~ %| *] geo)  [~ ~]
    :-  ~[(crip "{(spud p.u.geo)}/main.sig")]
    ~[(crip "{(spud p.u.geo)}/calls/") '/sys/link/geocode/']
  =/  trip=@t  (spat (weld p.u.it (snoc `path`/itineraries id)))
  =/  strs  |=(l=(list @t) ^-(json a+(turn l |=(s=@t `json`s+s))))
  =/  ensure=json
    %-  pairs:enjs:format
    :~  ['action' s+'ensure']
        ['parent' s+'/itinerary']
        ['name' s+id]
        ['bundle' s+'trip']
        ['system' s+(trip-clanker-prompt id trip)]
        ['repo' s+trip]
        :-  'roads'
        %-  pairs:enjs:format
        :~  ['peek' (strs (weld ~[(cat 3 trip '/')] peek.geo-roads))]
            ['make' (strs ~[(cat 3 trip '/')])]
            ['poke' (strs poke.geo-roads)]
        ==
        :-  'chats'
        :-  %a
        :~  %-  pairs:enjs:format
            :~  ['name' s+'plan']
                ['system' s+'You are planning this trip with its owner. Keep the itinerary document current as plans firm up: add pins, schedule entries and todos as they are decided, and say what you changed.']
                ['policy' (pairs:enjs:format ~[['default' s+'allow']])]
            ==
        ==
    ==
  ::  one soft poke, no peek first and no deadline: our weir grants the
  ::  POKE on the collection's main.sig and nothing else (a peek of it,
  ::  or the behn timer a deadline needs, would be vetoed and crash this
  ::  request). A veto or a nack answers `~ tang; a pack answers ~.
  =/  sig=road:tarball  [%& %& p.u.cl %'main.sig']
  ;<  res=(unit tang)  bind:m  (poke-soft:io sig [/ %json] ensure)
  ?^  res  (pure:m ~)
  (pure:m `~)
::  +trip-clanker-prompt: the trip clanker's standing prompt: what the
::  trip dir holds and how the document is shaped.
++  trip-clanker-prompt
  |=  [id=@ta at=@t]
  ^-  @t
  %-  crip
  """
  You are the assistant for the trip "{(trip id)}". The trip lives at
  {(trip at)} in the grubbery namespace. Your tools work on it directly:
  read_itinerary (the whole document), write_entry / delete_entry (a pin
  or zone), write_field / delete_field (any field by slash path: desc,
  dates, schedule/<id>, todos/<id>, pins/<id>/notes ...), geocode (names
  to coordinates and back, never guess coordinates), and list_files /
  read_file / write_file / delete_file over the attachments.

  itinerary.json is the trip document, one JSON object:
    name, desc (markdown), dates \{start, end} (ISO days), tz, center
    [lat, lng], zoom, categories \{key: \{label, color}},
    pins \{id: \{name, desc, cat, lat, lng, notes, from: [who]}},
    zones \{id: \{name, desc, cat, points: [[lat, lng], ...]}},
    schedule \{id: \{title, date, start, end, status: fixed|tentative, pin, notes}},
    todos \{id: \{text, done}}.
  Colour and grouping come from the linked pin's category. Mark anything
  you guessed as tentative, and note sources in notes as "- source: X".
  files/ holds the trip's attachments (tickets, schedules, photos): read
  them when the owner points you at one.

  Say what you changed.
  """
::  +fill-trip: a layout template with every {{trip}} filled with the id
++  fill-trip
  |=  [tpl=@t id=@ta]
  ^-  @t
  =/  mark=tape  "\{trip}"
  =/  s=tape  (trip id)
  =/  t=tape  (trip tpl)
  |-  ^-  @t
  =/  i=(unit @ud)  (find mark t)
  ?~  i  (crip t)
  $(t :(weld (scag u.i t) s (slag (add u.i (lent mark)) t)))

--
