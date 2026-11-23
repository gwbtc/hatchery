::  gw-handle nexus: a handle on the browser, asked of exactly one stranger.
::
::  The ship cannot touch Chrome. It holds a reference to one and issues
::  operations through it: screenshot a page, read it, click in it, type
::  into it, navigate it.
::
::  This nexus owns the connection, the way @esplora owns the chain
::  provider and @github owns the token. Nothing else needs browser
::  reach, and nothing else gets it: a caller that may drive the browser
::  has a poke road to here, and one that may not is vetoed at the door.
::
::  It is the lifecycle-grub pattern its siblings share:
::
::    ask/<id>.json  {"status": "pending", "request": {...}}
::                -> {"status": "done", "request": {...},
::                    "ok": true, "body": <what the browser said>}
::
::  The request is KEPT beside the answer, so a reader can attribute a
::  result to what it answered.
::
::  The flow, for an asker:
::
::    1. pick an id and KEEP ask/<id>.json FIRST, before it exists
::    2. poke main.sig {"id": ..., "req": {...}}
::    3. read on news until status is done
::    4. drop, and cull the grub
::
::  Where this differs from @esplora: esplora answers inside its own
::  fiber, because it makes the call. This nexus cannot. Chrome polls IN
::  and the answer arrives as a write, so an ask sits pending until the
::  extension completes it. There is no run-ask arm here, by design.
::
::  What the ship drives is ONE tab group, and nothing else in the
::  browser. A tab the person opened is never reachable, whatever site it
::  is on — the group says whose windows these are. So `open` comes
::  first: it is how the ship gets a tab at all, and every other op
::  resolves within that group or fails.
::
::  Note what the group does NOT bound. Its tabs are in the person's own
::  profile and carry the person's own sessions, so a tab opened to a
::  site they are logged into arrives logged in. The group decides whose
::  windows, never which logins — that limit is the extension's armed
::  list, and a finer one belongs at this API.
::
::    {"op": "open",  "domain": "example.com", "url": "https://example.com/"}
::    {"op": "tabs",  "domain": "..."}                  what it is holding
::    {"op": "close", "domain": "...", "tabId": 7}
::    {"op": "screenshot", "domain": "..."}
::    {"op": "read",  "domain": "...", "selector": "#thing"}  selector optional
::    {"op": "click", "domain": "...", "selector": "#go"}
::    {"op": "type",  "domain": "...", "selector": "input", "text": "..."}
::    {"op": "navigate", "domain": "...", "url": "https://..."}
::
::  `domain` on a request is which site the job is for: it routes to a
::  group tab. It is not a permission, and not the armed list — driving
::  the ship's own tabs is not gated by arming. Arming is for collection:
::  which sites stream their cookies and traffic to the ship as the
::  person browses. The ship may open and drive any URL in its group;
::  what it may never do is reach a tab the person opened. The group is
::  the boundary, not the URL.
::
::  The extension's routes. There is no token: the extension is a client
::  of the ship like any other and signs in with the ship's own
::  credentials, so every route here answers only our own @p, judged from
::  the eyre session. A request from anyone else is refused at the door.
::
::    GET  /grubbery/gw-handle/api/next?domain=<d>   claim one pending ask
::    POST /grubbery/gw-handle/api/complete          {id, ok, body, error}
::    POST /grubbery/gw-handle/api/cookies           {domain, at, cookies}
::    POST /grubbery/gw-handle/api/traffic           {batch: [call, ...]}
::    POST /grubbery/gw-handle/api/ping              liveness, for the popup
::
::  A jar lands at cookies/<domain>, HttpOnly included, overwritten as the
::  browser's own changes. Observed calls land at traffic/<domain>/<at>,
::  never overwritten and never trimmed: the tap reports every call the
::  page makes and all of it is kept. Which calls are the site's API and
::  which are its telemetry is a judgement for the intelligence that reads
::  this later, not a filter applied at capture. The extension buffers the
::  firehose and posts a flush as one batch, so the ship takes writes at a
::  bounded rate while losing nothing.
::
::  Both exist because a site's own front end is the only honest account
::  of its API: the calls it makes are the spec, and the jar is what makes
::  them replayable away from the browser. This nexus only collects and
::  serves them. It has no /sys/iris reach and makes no outbound request
::  of its own — Chrome comes to it. Whatever reads this to build and
::  repair an adaptor is a separate app with its own weir, and the
::  separation is the point: the app holding every armed jar should not
::  also be able to call out.
::
::  Consent lives in the extension, in one place. It decides which
::  domains it will collect and which it will act on, and it is the right
::  place for both: it holds the cookies already, so a second list here
::  would refuse nothing that was not already out of the ship's hands,
::  and it is the half a person can see and untick.
::
::  This nexus keeps no allowlist. Which CALLER may ask it for what is a
::  weir question — the same question asked of every other nexus — and
::  belongs at this API, not in a config file shadowing the permission
::  system the namespace already has. Nothing finer than "holds a poke
::  road to main.sig" is enforced yet; that is the piece to build when
::  something other than a person starts asking.
::
/<  icon  ./icon.svg
::  the shell lib, for this nexus's own absolute path (grant.json), used to
::  build the tarball-download URL without naming the install path by hand
/<  sh  /lib/shell.hoon
::  the install page and its stylesheet, served to anyone the link is shared
::  with — getting the extension carries no secret
/&  install-html  ./install.html
/&  install-css   ./style.css
=<  ^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  =/  link-json=json
    %-  pairs:enjs:format
    :~  ['name' s+'gw-handle']
        ['description' s+'A handle on the browser: screenshot, read, click, type']
    ==
  ::  what it reaches outside its own tree. Notably NOT /sys/iris: this
  ::  nexus never makes an outbound request. Chrome comes to it.
  =/  wj=json
    =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
    %-  pairs:enjs:format
    :~  :-  'poke'
        :-  %a
        :~  (line '/sys/bowl.sig' 'time, identity, entropy — every fiber op')
            (line '/sys/eyre/' 'bind /grubbery/gw-handle for the extension to poll')
        ==
    ==
  =/  tile=json
    %-  pairs:enjs:format
    :~  ['title' s+'gw-handle']
        ['info' s+'The browser, on a leash']
        ['color' s+'#3b4a5a']
        ['href' s+'/grubbery/gw-handle']
    ==
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%over %& [/ %'link.json'] [[/ %json] link-json]]
      [%over %& [/ %'weir.json'] [[/ %json] wj]]
      [%over %& [/ %'tile.json'] [[/ %json] tile]]
      [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
      ::  takes the pokes that open a question
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      ::  every question asked and not yet collected
      [%fall %| /ask empty-dir:loader]
      ::  one jar per domain, as the browser last had it
      [%fall %| /cookies empty-dir:loader]
      ::  every call the site's own front end made, per domain
      [%fall %| /traffic empty-dir:loader]
      ::  the extension's two routes
      [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
      [%fall %| /requests empty-dir:loader]
      ::  grant.json: the shell writes it on approval and it carries this
      ::  app's own absolute address. Kept, or the approval is pruned on
      ::  the next load and every sandboxed read fails from then on.
      [%stay %& [/ %'grant.json']]
  ==
::
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      ::  the pokes that open a question
      [~ %'main.sig']
    (main-loop rail)
      ::  the extension's routes
      [~ %'web.sig']
    ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/gw-handle])
    http-dispatch:io
      ::  one request to it
      [[%requests ~] @]
    (serve rail name.rail)
  ==
--
::
|%
::  +jstr: a string field, or '' when it is not there or not a string
::
++  jstr
  |=  [j=json key=@t]
  ^-  @t
  ?.  ?=([%o *] j)  ''
  =/  v  (~(get by p.j) key)
  ?:(?=([~ %s *] v) p.u.v '')
::  +jget: a field, whatever its shape
::
++  jget
  |=  [j=json key=@t]
  ^-  (unit json)
  ?.  ?=([%o *] j)  ~
  (~(get by p.j) key)
::  +ask-road: where one question lives
::
::  +write-traffic: store one observed call under its own domain.
::
::    Everything the browser reports is kept, unfiltered and untrimmed —
::    which calls are the site's API and which are its telemetry is a
::    judgement for whatever reads this later, never a decision made at
::    the point of capture. The name is the moment plus an index, so
::    many calls landing in one batch do not collide, and the store
::    stays time-ordered.
::
++  write-traffic
  |=  [=rail:tarball now=@da idx=@ud entry=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  domain=@t  (jstr entry 'domain')
  ?:  =('' domain)  (pure:m ~)
  =/  name=@ta  (crip "{(scow %da now)}-{(scow %ud idx)}")
  =/  where=lane:tarball  [%& `path`[%traffic `@ta`domain ~] name]
  (make:io (nex-road:io rail where) |+[[[/ %json] entry] ~])
::
++  ask-road
  |=  [=rail:tarball id=@t]
  ^-  road:tarball
  (nex-road:io rail [%& /ask id])
::  +main-loop: open a question. The asker names the id, so it can keep
::  the road before there is anything there to keep.
::
++  main-loop
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ::  take-poke, not take-poke-from: an asker may be a nexus with a road
  ::  or a person with a curl, and the id in the poke is what identifies
  ::  the question either way.
  ;<  =sage:tarball  bind:m  take-poke:io
  ?.  =([/ %json] p.sage)
    ~&  >>>  [%gw-handle-unrecognized-poke mark=p.sage]
    $
  =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
  =/  id=@t   (jstr jon 'id')
  =/  req=json  (fall (jget jon 'req') *json)
  ?:  =('' id)
    ~&  >>>  "%gw-handle: poke missing id"
    $
  =/  content=json
    (pairs:enjs:format ~[['status' s+'pending'] ['request' req]])
  ;<  ~  bind:m  (make:io (ask-road rail id) |+[[[/ %json] content] ~])
  ::  retention on: the answer outlives the fiber that wrote it, so the
  ::  asker can still be reading when this loop has moved on
  ;<  ~  bind:m  (gain:io (ask-road rail id) %.y)
  $
::  +serve: the extension's two routes, and a status page.
::
++  serve
  |=  [=rail:tarball eyre-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  =/  prefix=path  /grubbery/gw-handle
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  ::  public, no owner check: the install page, its stylesheet, and the
  ::  download. The extension holds no secret, so sharing the link is how
  ::  someone else gets it.
  ?:  ?=(~ suffix)
    (send-simple:http-res:io eyre-id (mime-response:http-utils install-html))
  ?:  ?=([%'style.css' ~] suffix)
    (send-simple:http-res:io eyre-id (mime-response:http-utils install-css))
  ::  /download → the extension dir as a tarball, built by the kernel. The
  ::  nexus does not know its own code path, so it derives it from its data
  ::  path (grant.json): .../desk/data/gw-handle → .../desk/code/nex/gw-handle.
  ?:  ?=([%download ~] suffix)
    ;<  root=(unit @t)  bind:m  (here:sh rail)
    ?~  root
      ;<  ~  bind:m
        (send-simple:http-res:io eyre-id [[404 ~] `(as-octs:mimes:html 'not approved yet')])
      (pure:m ~)
    =/  dp=path  (stab u.root)
    =/  base=path  (scag (sub (lent dp) 2) dp)
    =/  code-ext=path  (weld base /code/nex/gw-handle/extension)
    =/  loc=@t  (crip (weld "/grubbery/api/peek" (weld (spud code-ext) "?as=tar")))
    ;<  ~  bind:m
      (send-simple:http-res:io eyre-id [[307 ~[['location' loc]]] ~])
    (pure:m ~)
  ::  everything below is the extension's own API, owner-only
  ?.  =(src our)
    ;<  ~  bind:m
      (send-simple:http-res:io eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
    (pure:m ~)
  ?+    suffix
    ;<  ~  bind:m
      (send-simple:http-res:io eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
      ::  the extension claims one pending ask for a domain
      [%api %next ~]
    =/  domain=@t  (fall (~(get by (malt args)) 'domain') '')
    ;<  pend=(unit [id=@t req=json])  bind:m  (next-pending rail domain)
    =/  body=json
      ?~  pend  (pairs:enjs:format ~[['job' ~]])
      %-  pairs:enjs:format
      :~  ['job' (pairs:enjs:format ~[['id' s+id.u.pend] ['req' req.u.pend]])]
      ==
    (send-json eyre-id body)
      ::  the extension writes an answer back
      [%api %complete ~]
    ?.  =(%'POST' method.request.req)
      ;<  ~  bind:m
        (send-simple:http-res:io eyre-id [[405 ~] `(as-octs:mimes:html 'Method not allowed')])
      (pure:m ~)
    =/  raw=@t
      ?~  body.request.req  ''
      q.u.body.request.req
    =/  jon=json  (fall (de:json:html raw) *json)
    =/  id=@t  (jstr jon 'id')
    ?:  =('' id)
      ;<  ~  bind:m
        (send-simple:http-res:io eyre-id [[400 ~] `(as-octs:mimes:html 'id required')])
      (pure:m ~)
    ;<  ~  bind:m  (finish rail id jon)
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+%.y]]))
      ::  the jar for one domain, as the browser last had it. Armed
      ::  domains only: an unarmed domain's jar is refused rather than
      ::  quietly kept, so what is here is what was consented to.
      [%api %cookies ~]
    ?.  =(%'POST' method.request.req)
      ;<  ~  bind:m
        (send-simple:http-res:io eyre-id [[405 ~] `(as-octs:mimes:html 'Method not allowed')])
      (pure:m ~)
    =/  raw=@t
      ?~  body.request.req  ''
      q.u.body.request.req
    =/  jon=json  (fall (de:json:html raw) *json)
    =/  domain=@t  (jstr jon 'domain')
    ?:  =('' domain)
      ;<  ~  bind:m
        (send-simple:http-res:io eyre-id [[400 ~] `(as-octs:mimes:html 'domain required')])
      (pure:m ~)
    ;<  ~  bind:m
      %+  over:io  (nex-road:io rail [%& /cookies domain])
      [[/ %json] jon]
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+%.y]]))
      ::  a batch of observed calls, each kept beside the others under its
      ::  own domain and never overwritten. A batch, not one at a time,
      ::  because the page is a firehose: the extension buffers the flood
      ::  and this writes a flush in one event, however fast the page talks.
      [%api %traffic ~]
    ?.  =(%'POST' method.request.req)
      ;<  ~  bind:m
        (send-simple:http-res:io eyre-id [[405 ~] `(as-octs:mimes:html 'Method not allowed')])
      (pure:m ~)
    =/  raw=@t
      ?~  body.request.req  ''
      q.u.body.request.req
    =/  jon=json  (fall (de:json:html raw) *json)
    ::  {"batch": [entry, ...]}; a bare entry is wrapped, so a single
    ::  unbuffered post still works
    =/  entries=(list json)
      =/  b  (jget jon 'batch')
      ?:  ?=([~ %a *] b)  p.u.b
      ~[jon]
    ;<  now=@da  bind:m  get-time:io
    =|  idx=@ud
    |-  ^-  form:m
    ?~  entries
      (send-json eyre-id (pairs:enjs:format ~[['ok' b+%.y]]))
    ;<  ~  bind:m  (write-traffic rail now idx i.entries)
    $(entries t.entries, idx +(idx))
      ::  liveness, so the extension can say whether it is paired
      [%api %ping ~]
    (send-json eyre-id (pairs:enjs:format ~[['ok' b+%.y] ['who' s+(scot %p our)]]))
  ==
::  +next-pending: one pending ask, marked dispatched so a second poll
::  does not take the same one. An empty domain matches ANY pending ask:
::  driving the ship's own tabs is not gated by the armed list — arming
::  is for collection — so the extension claims driving jobs with one
::  undomained poll, and a domain here only narrows when a caller wants
::  jobs for a particular site.
::
++  next-pending
  |=  [=rail:tarball domain=@t]
  =/  m  (fiber:fiber:nexus ,(unit [id=@t req=json]))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%| /ask]) ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  ?~  fil.ball.view  (pure:m ~)
  =/  entries=(list [name=@ta =sang:tarball gain=? bang=(unit tang)])
    ~(tap by contents.u.fil.ball.view)
  |-
  ?~  entries  (pure:m ~)
  =/  jon=json
    (fall (mole |.(!<(json (need-vase:tarball sang.i.entries)))) *json)
  =/  req=json  (fall (jget jon 'request') *json)
  ?.  ?&  =('pending' (jstr jon 'status'))
          |(=('' domain) =(domain (jstr req 'domain')))
      ==
    $(entries t.entries)
  =/  taken=json
    (pairs:enjs:format ~[['status' s+'sent'] ['request' req]])
  ;<  ~  bind:m
    (over:io (ask-road rail name.i.entries) [[/ %json] taken])
  (pure:m `[name.i.entries req])
::  +finish: write the browser's answer beside the question it answers.
::
++  finish
  |=  [=rail:tarball id=@t jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (ask-road rail id) `[/ %json])
  ?.  ?=([%file *] view)  (pure:m ~)
  =/  own=json
    (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
  =/  req=json  (fall (jget own 'request') *json)
  =/  ok=?  ?=([~ %b %.y] (jget jon 'ok'))
  =/  done=json
    %-  pairs:enjs:format
    :~  ['status' s+'done']
        ['request' req]
        ['ok' b+ok]
        ['body' (fall (jget jon 'body') ~)]
        ['error' s+(jstr jon 'error')]
    ==
  (over:io (ask-road rail id) [[/ %json] done])
::  +send-json: one json body, 200
::
++  send-json
  |=  [eyre-id=@ta body=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html body))
  ;<  ~  bind:m
    (send-simple:http-res:io eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
  (pure:m ~)
--
