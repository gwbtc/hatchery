::  clanker: the grubbery chat workspace. See man/clanker.
::
::  THE FOUNDATION is the tree, not the engine. The workspace lives in the
::  namespace as durable structure:
::
::    /projects/<proj>/config.json          the project RECORD (data)
::    /projects/<proj>/chats/<chat>.json     one append-only event log
::    /main.sig                              the poke loop (turns, interrupt)
::    /http.sig, /requests/                  the page and its API
::
::  A project is DATA: name, system prompt, model, the advertised tool
::  schema, and WHERE its tools run (tools_root, a link-relative path to
::  a tools nexus). The engine only reads it, so adding a project is
::  writing a /projects/<name>/ dir, not a code change.
::
::  The STORED TRUTH of a chat is a log of EVENTS, never a messages array.
::  The request sent to the model is a DERIVED VIEW: +assemble folds the
::  log into Anthropic messages. v1 assembles append-all; a budgeted
::  +assemble later swaps in without touching the log or the loop.
::
::  Reuse: lib/clanker's door `ck` for the metered proxy round-trip
::  (+call-anthropic), persistence (+write-chat) and the interrupt-aware
::  take; lib/tools for the run-grub protocol a tools nexus speaks.
::
/<  clanker    /lib/clanker.hoon
/<  nex-tools  /lib/tools.hoon
/&  index-html  ./index.html
/&  app-js      ./app.js
/&  style-css   ./style.css
/&  icon        ./icon.svg
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
          [~ %'main.sig']
        (serve rail prod)
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
::  +ck: lib/clanker's door, used only for its generic plumbing. Its cfg
::  is unused by those arms: the per-project schema/prompt/model come
::  from the tree.
++  ck  ~(. clanker:clanker [%clanker [%a ~] '' [%o ~]])
++  srv  ~(. http-res:io [%| 1 %& ~ %'http.sig'])
::  +rows: the on-load tree. %fall for the workspace (seed once, then the
::  tree is the live, user-owned record); %over for product code.
++  rows
  ^-  (list row:loader)
  =/  proj=bole:tarball
    =/  b=bole:tarball  *bole:tarball
    =.  b  (~(put bo:tarball b) [/ %'config.json'] [[/ %json] grubbery-config])
    (put-bole:loader b /chats empty-dir:loader)
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
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      [%fall %& [/ %'http.sig'] [[/ %sig] ~]]
      [%fall %| /requests empty-dir:loader]
      [%fall %| /projects empty-dir:loader]
      [%fall %| /projects/grubbery proj]
  ==
::  +weir-ask: what this nexus needs to reach. The model proxy and the
::  tools nexus are found by name through /sys/link.
++  weir-ask
  ^-  json
  =/  road  |=([r=@t why=@t] (pairs:enjs:format ~[['road' s+r] ['why' s+why]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (road '/sys/bowl.sig' 'time, identity, entropy')
          (road '/sys/eyre/' 'serve its page over HTTP')
          (road '@anthropic/main.sig' 'metered model calls')
          (road '@mcp/tools/main.sig' 'the grubbery project runs its tools in the kernel tools nexus')
      ==
      :-  'peek'
      :-  %a
      :~  (road '/sys/link/' 'find the proxy and the tools nexus by name')
          (road '@anthropic/calls/' 'read a model call result')
          (road '@mcp/tools/runs/' 'read a tool run result')
      ==
  ==
::  +serve: the main.sig poke loop. Each {message, project, chat} poke
::  runs a turn; {action:'interrupt'} is swallowed here (it lands
::  mid-await inside a running turn, which cancels it).
++  serve
  |=  [=rail:tarball =prod:fiber:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  (rise-wait:io prod "%clanker main: failed")
  |-
  ;<  =sage:tarball  bind:m  take-poke:io
  =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
  =/  act=(unit @t)
    ?.  ?=([%o *] jon)  ~
    (bind (~(get by p.jon) 'action') |=(j=json ?>(?=(%s -.j) p.j)))
  ?:  ?=([~ %'interrupt'] act)  $
  =/  project=@t  =/(p=@t (jstr:clanker jon 'project') ?:(=('' p) 'grubbery' p))
  =/  chat=@t     =/(c=@t (jstr:clanker jon 'chat') ?:(=('' c) 'main' c))
  ;<  ~  bind:m  (turn-chat rail jon project chat)
  $
::  +turn-chat: one turn. Load the project record from the tree, append
::  the %input event to the chat log, persist (so a refresh shows it even
::  if the turn stalls), then run the loop with THIS project's prompt,
::  model, schema, and tools root.
++  turn-chat
  |=  [=rail:tarball jon=json project=@t chat=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (pure:m ~)
  =/  msg=(unit @t)
    (bind (~(get by p.jon) 'message') |=(j=json ?>(?=(%s -.j) p.j)))
  ?~  msg  (pure:m ~)
  ;<  pv=view:nexus  bind:m
    (peek:io (nex-road:io rail [%& [%projects project ~] %'config.json']) `[/ %json])
  ?.  ?=([%file *] pv)  (pure:m ~)
  =/  prec=json  (fall (mole |.(!<(json (need-vase:tarball sang.pv)))) [%o ~])
  =/  sys=@t     (jstr:clanker prec 'system')
  =/  model=@t   =/(mo=@t (jstr:clanker prec 'model') ?:(=('' mo) 'claude-sonnet-4-6' mo))
  =/  max=@ud    (jnum:clanker prec 'max_tokens' 4.096)
  =/  schema=json
    ?~  s=(~(get by ?>(?=([%o *] prec) p.prec)) 'tools')  [%a ~]
    u.s
  ;<  root=(unit path)  bind:m  (tools-root (jstr:clanker prec 'tools_root'))
  =/  road=road:tarball  (chat-road rail project chat)
  ;<  cur=view:nexus  bind:m  (peek:io road `[/ %json])
  =/  log=(list json)
    ?.  ?=([%file *] cur)  ~
    =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.cur)))) [%a ~])
    ?.(?=([%a *] j) ~ p.j)
  =/  existed=?  ?=([%file *] cur)
  =.  log  (snoc log (event-input u.msg))
  ;<  ~  bind:m  (write-chat:ck road existed log)
  (run road log sys model max schema root)
::  +run: the agent loop over the event log. Assemble the request from
::  the log, send it, append the %response event, persist. If the model
::  asked for tools, run them, append the %results event, persist, loop.
::  An interrupt (~ from the proxy / tools) stops with the log intact up
::  to the last persisted event.
++  run
  |=  [road=road:tarball log=(list json) sys=@t model=@t max=@ud schema=json root=(unit path)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-  ^-  form:m
  =/  messages=(list json)  (assemble log)
  ;<  answered=(unit json)  bind:m  (call-anthropic:ck (encode model max sys schema messages))
  ?~  answered  (pure:m ~)
  =/  resp=json  u.answered
  =/  content-arr=(list json)  (resp-content resp)
  =.  log  (snoc log (event-response content-arr (resp-stop resp) (resp-usage resp)))
  ;<  ~  bind:m  (write-chat:ck road %.y log)
  =/  tool-uses=(list json)
    %+  skim  content-arr
    |=(b=json ?&(?=([%o *] b) ?=([~ %s %'tool_use'] (~(get by p.b) 'type'))))
  ?~  tool-uses  (pure:m ~)
  ?~  root
    ::  the project advertises tools but names no tools nexus: answer the
    ::  model honestly and stop, so the log says why
    =/  results=(list json)
      %+  turn  tool-uses
      |=  tu=json
      %-  pairs:enjs:format
      :~  ['type' s+'tool_result']
          ['tool_use_id' s+(jstr:clanker tu 'id')]
          ['content' s+'this project has no tools nexus (tools_root unset or unresolvable)']
          ['is_error' b+%.y]
      ==
    =.  log  (snoc log (event-results results ~))
    (write-chat:ck road %.y log)
  ;<  ran=(unit [(list json) (list json)])  bind:m  (run-tools u.root tool-uses)
  ?~  ran  (pure:m ~)
  =.  log  (snoc log (event-results -.u.ran +.u.ran))
  ;<  ~  bind:m  (write-chat:ck road %.y log)
  $
::  +tools-root: a project's tools_root resolved to an absolute dir.
::  '@name/rest' resolves the name through /sys/link; '/abs/path' is
::  taken as is; '' is no tools.
++  tools-root
  |=  spec=@t
  =/  m  (fiber:fiber:nexus ,(unit path))
  ^-  form:m
  =/  t=tape  (trip spec)
  ?~  t  (pure:m ~)
  ?.  =('@' i.t)  (pure:m (rush spec stap))
  =/  sl=(unit @ud)  (find "/" t)
  ::  t is a lest after the ?~ above; scag/slag return ^+ their list, so
  ::  hand them a plain tape or their ~ case fails to nest
  =/  tt=tape  t
  =/  nm=@t  ?~(sl spec (crip (scag u.sl tt)))
  =/  rest=path  ?~(sl / (fall (rush (crip (slag u.sl tt)) stap) /))
  ;<  root=(unit lane:tarball)  bind:m  (resolve-link:io nm)
  ?.  ?=([~ %| *] root)  (pure:m ~)
  (pure:m `(weld p.u.root rest))
::  +run-tools: execute each tool_use against the project's tools nexus;
::  yield the tool_result blocks (for the model) and trace entries (for
::  the UI). ~ on interrupt.
++  run-tools
  |=  [root=path tool-uses=(list json)]
  =/  m  (fiber:fiber:nexus ,(unit [(list json) (list json)]))
  ^-  form:m
  =|  results=(list json)
  =|  trace=(list json)
  |-  ^-  form:m
  ?~  tool-uses  (pure:m `[(flop results) (flop trace)])
  =*  tu  i.tool-uses
  ?.  ?=([%o *] tu)  $(tool-uses t.tool-uses)
  =/  tid=@t   (jstr:clanker tu 'id')
  =/  name=@t  (jstr:clanker tu 'name')
  =/  input=json  (fall (~(get by p.tu) 'input') [%o ~])
  ;<  outcome=(unit [json @t])  bind:m  (call-tool root name input)
  ?~  outcome  (pure:m ~)
  =/  result=json
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result']
        ['tool_use_id' s+tid]
        ['content' -.u.outcome]
    ==
  =/  note=@t  +.u.outcome
  =/  te=json
    (pairs:enjs:format ~[['tool' s+name] ['arg' s+(first-arg:ck input)] ['note' s+note]])
  $(tool-uses t.tool-uses, results [result results], trace [te trace])
::  +call-tool: one run through a tools nexus (the calls protocol: poke
::  main.sig, await the run grub, read the result, cull). Yields the
::  tool_result content (a string, or a content array holding an image or
::  document block when the tool returned bytes) and a short note for the
::  trace. ~ on interrupt.
++  call-tool
  |=  [root=path name=@t args=json]
  =/  m  (fiber:fiber:nexus ,(unit [json @t]))
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  id=@t         (scot %uv (end [3 8] eny))
  =/  run-name=@ta  `@ta`id
  =/  main-road=road:tarball  [%& %& root %'main.sig']
  =/  run-road=road:tarball   [%& %& (snoc root %runs) run-name]
  ;<  *  bind:m  (keep:io /tool run-road ~)
  ;<  ~  bind:m
    %-  poke:io
    :+  main-road  [/ %json]
    %-  pairs:enjs:format
    :~  ['cmd' s+'call']  ['id' s+id]  ['name' s+name]  ['arguments' args]
    ==
  ;<  timed=(unit (unit json))  bind:m  (await-run run-road run-name)
  ;<  ~  bind:m  (drop:io /tool run-road)
  ;<  ~  bind:m
    %-  poke:io
    [main-road [/ %json] (pairs:enjs:format ~[['cmd' s+'cull'] ['id' s+id]])]
  ?~  timed  (pure:m ~)
  =/  res=(unit json)  u.timed
  ?~  res  (pure:m `[s+'(no result)' 'error'])
  ?.  ?=([%o *] u.res)  (pure:m `[s+'(bad result)' 'error'])
  ?:  ?=([~ %s %'error'] (~(get by p.u.res) 'type'))
    =/  msg  (fall (bind (~(get by p.u.res) 'message') |=(j=json ?>(?=(%s -.j) p.j))) 'error')
    (pure:m `[s+msg 'error'])
  ?:  ?=([~ %s %'mime'] (~(get by p.u.res) 'type'))
    =/  mt=@t   (jstr:clanker u.res 'media_type')
    =/  b64=@t  (jstr:clanker u.res 'data')
    =/  kind=@t  ?:(=('application/pdf' mt) 'document' 'image')
    =/  block=json
      %-  pairs:enjs:format
      :~  ['type' s+kind]
          :-  'source'
          %-  pairs:enjs:format
          :~  ['type' s+'base64']
              ['media_type' s+mt]
              ['data' s+b64]
          ==
      ==
    (pure:m `[[%a ~[block]] (crip "{(trip mt)}, {(a-co:co (div (mul 3 (met 3 b64)) 4))} bytes")])
  =/  txt=@t  (fall (bind (~(get by p.u.res) 'text') |=(j=json ?>(?=(%s -.j) p.j))) '')
  (pure:m `[s+txt (crip "{(a-co:co (met 3 txt))} bytes")])
::
++  await-run
  |=  [run-road=road:tarball run-name=@ta]
  =/  m  (fiber:fiber:nexus ,(unit (unit json)))
  ^-  form:m
  |-
  ;<  raw=(unit wave:nexus)  bind:m  (take-news-or-interrupt:ck /tool)
  ?~  raw  (pure:m ~)
  =/  hit=(unit cass:clay)
    ?~  fil.u.raw  ~
    (~(get by file.u.fil.u.raw) run-name)
  ?~  hit  $
  ;<  =view:nexus  bind:m  (peek-at:io run-road ~ [%ud ud.u.hit])
  ?.  ?=([%file *] view)  $
  =/  st=tool-state:nex-tools  !<(tool-state:nex-tools (need-vase:tarball sang.view))
  ?.  =(%done step.st)  $
  (pure:m `update.st)
::  +chat-road: where a chat's event log lives in the tree.
++  chat-road
  |=  [=rail:tarball project=@t chat=@t]
  ^-  road:tarball
  (nex-road:io rail [%& [%projects project %chats ~] (crip "{(trip chat)}.json")])
::  +assemble: THE context policy. Fold the event log into Anthropic
::  messages. v1 = append-all. %input -> a user turn; %response -> an
::  assistant turn carrying the stored content array (text + tool_use);
::  %results -> a user turn carrying the tool_result blocks.
++  assemble
  |=  log=(list json)
  ^-  (list json)
  %+  murn  log
  |=  ev=json
  ^-  (unit json)
  ?.  ?=([%o *] ev)  ~
  =/  k=@t  (jstr:clanker ev 'k')
  ?:  =('input' k)
    `(pairs:enjs:format ~[['role' s+'user'] ['content' s+(jstr:clanker ev 'body')]])
  ?:  |(=('response' k) =('results' k))
    =/  c=(unit json)  (~(get by p.ev) 'content')
    ?.  ?=([~ %a *] c)  ~
    =/  role=@t  ?:(=('response' k) 'assistant' 'user')
    `(pairs:enjs:format ~[['role' s+role] ['content' u.c]])
  ~
::  +encode: the anthropic codec, request side. (model schema items) -> wire.
++  encode
  |=  [model=@t max=@ud sys=@t schema=json messages=(list json)]
  ^-  json
  %-  pairs:enjs:format
  :~  ['model' s+model]
      ['max_tokens' (numb:enjs:format max)]
      ['system' s+sys]
      ['tools' schema]
      ['messages' [%a messages]]
  ==
::  +resp-content / +resp-stop / +resp-usage: the codec, response side.
++  resp-content
  |=  resp=json
  ^-  (list json)
  ?.  ?=([%o *] resp)  ~
  =/  c  (~(get by p.resp) 'content')
  ?.(?=([~ %a *] c) ~ p.u.c)
++  resp-stop
  |=  resp=json  ^-  @t  (jstr:clanker resp 'stop_reason')
++  resp-usage
  |=  resp=json
  ^-  json
  ?.  ?=([%o *] resp)  [%o ~]
  (fall (~(get by p.resp) 'usage') [%o ~])
::  +event-*: the log vocabulary, as stored json.
++  event-input
  |=  body=@t
  ^-  json
  (pairs:enjs:format ~[['k' s+'input'] ['body' s+body]])
++  event-response
  |=  [content=(list json) stop=@t usage=json]
  ^-  json
  (pairs:enjs:format ~[['k' s+'response'] ['content' [%a content]] ['stop' s+stop] ['usage' usage]])
++  event-results
  |=  [content=(list json) trace=(list json)]
  ^-  json
  (pairs:enjs:format ~[['k' s+'results'] ['content' [%a content]] ['trace' [%a trace]]])
::
::  HTTP: the page and its API. A request fiber lives at /requests/<id>,
::  one level under the nexus root, so the root is [%| 1 ...].
::
::    GET  /                         the page
::    GET  /api/projects             [{name, model, chats:[...]}]
::    GET  /api/log?project&chat     the event log
::    POST /api/send {project, chat, message}   -> pokes main.sig
::    POST /api/stop                            -> interrupts the running turn
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
  ?:  ?&(=(%'GET' method) =(~ suffix))
    (serve-file eyre-id 'index.html')
  ?:  ?&(=(%'GET' method) ?=([@ ~] suffix) |(=(%'app.js' i.suffix) =(%'style.css' i.suffix) =(%'icon.svg' i.suffix)))
    (serve-file eyre-id i.suffix)
  ?:  ?&(=(%'GET' method) =([%api %projects ~] suffix))
    ;<  body=json  bind:m  list-projects
    (send-json eyre-id (en:json:html body))
  ?:  ?&(=(%'GET' method) =([%api %log ~] suffix))
    =/  project=@t  =/(p=@t (arg 'project') ?:(=('' p) 'grubbery' p))
    =/  chat=@t     =/(c=@t (arg 'chat') ?:(=('' c) 'main' c))
    ;<  lv=view:nexus  bind:m
      (peek:io [%| 1 %& [%projects project %chats ~] (crip "{(trip chat)}.json")] `[/ %json])
    =/  log=json
      ?.  ?=([%file *] lv)  [%a ~]
      (fall (mole |.(!<(json (need-vase:tarball sang.lv)))) [%a ~])
    (send-json eyre-id (en:json:html log))
  ?:  ?&(=(%'POST' method) =([%api %send ~] suffix))
    =/  jon=json
      (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) *json)
    ?.  ?=([%o *] jon)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'bad json')])
      (pure:m ~)
    ;<  ~  bind:m  (poke:io [%| 1 %& ~ %'main.sig'] [[/ %json] jon])
    (send-json eyre-id '{"ok":true}')
  ?:  ?&(=(%'POST' method) =([%api %stop ~] suffix))
    ;<  ~  bind:m
      (poke:io [%| 1 %& ~ %'main.sig'] [[/ %json] (pairs:enjs:format ~[['action' s+'interrupt']])])
    (send-json eyre-id '{"ok":true}')
  ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
  (pure:m ~)
::  +list-projects: every dir under /projects with its record's model and
::  the chats it holds.
++  list-projects
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io [%| 1 %| /projects] ~)
  ?.  ?=([%ball *] dv)  (pure:m [%a ~])
  =/  names=(list @ta)  (sort ~(tap in ~(key by dir.ball.dv)) aor)
  =|  out=(list json)
  |-
  ?~  names  (pure:m [%a (flop out)])
  ;<  cv=view:nexus  bind:m
    (peek:io [%| 1 %& [%projects i.names ~] %'config.json'] `[/ %json])
  =/  cfg=json
    ?.  ?=([%file *] cv)  [%o ~]
    (fall (mole |.(!<(json (need-vase:tarball sang.cv)))) [%o ~])
  ;<  chv=view:nexus  bind:m  (peek:io [%| 1 %| [%projects i.names %chats ~]] ~)
  =/  chats=(list @ta)
    ?.  ?=([%ball *] chv)  ~
    ?~  fil.ball.chv  ~
    %+  murn  (sort ~(tap in ~(key by contents.u.fil.ball.chv)) aor)
    |=  n=@ta
    =/  t=tape  (trip n)
    =/  len=@ud  (lent t)
    ?.  &((gth len 5) =(".json" (slag (sub len 5) t)))  ~
    `(crip (scag (sub len 5) t))
  =/  entry=json
    %-  pairs:enjs:format
    :~  ['name' s+i.names]
        ['model' s+(jstr:clanker cfg 'model')]
        ['tools_root' s+(jstr:clanker cfg 'tools_root')]
        ['chats' [%a (turn chats |=(c=@ta s+c))]]
    ==
  $(names t.names, out [entry out])
::
++  serve-file
  |=  [eyre-id=@ta filename=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%| 1 %& ~ filename] `[/ %mime])
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
::  +grubbery-config: the seeded grubbery project RECORD. The engine reads
::  these fields; nothing here is special-cased in code. Its tools run in
::  the kernel's tools nexus, found by name.
++  grubbery-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['name' s+'grubbery']
      ['system' s+grubbery-system]
      ['model' s+'claude-sonnet-4-6']
      ['max_tokens' (numb:enjs:format 4.096)]
      ['tools_root' s+'@mcp/tools']
      ['tools' tool-schema]
  ==
::  +tool-schema: the grubbery project's advertised tools, a focused
::  self-editing set. Descriptions and param names mirror the kernel's
::  tool handlers.
++  tool-schema
  ^-  json
  :-  %a
  :~  %:  mk-tool-typed:clanker  'grep'
        'Search grubbery source for a string. Returns matching lines with file paths and line numbers.'
        :~  ['pattern' 'string' 'Text to search for']
            ['path' 'string' 'Optional directory path pattern, e.g. /nex/*']
            ['name' 'string' 'Optional filename pattern, e.g. *clanker*']
            ['blot' 'string' 'Optional blot pattern, e.g. hoon']
        ==
        ~['pattern']
      ==
      %:  mk-tool-typed:clanker  'read_grub'
        'Read a grub (file) from the grubbery ball. path is the directory, name is the filename.'
        :~  ['path' 'string' 'Directory path, e.g. /nex/clanker']
            ['name' 'string' 'Grub filename, e.g. app.hoon']
        ==
        ~['path' 'name']
      ==
      %:  mk-tool-typed:clanker  'edit_file'
        'Edit a text grub by exact string replacement. Fails if old_string is not found or ambiguous.'
        :~  ['path' 'string' 'Directory path']
            ['name' 'string' 'Filename']
            ['old_string' 'string' 'Exact text to find and replace']
            ['new_string' 'string' 'Replacement text']
            ['replace_all' 'boolean' 'Replace all occurrences (default false)']
        ==
        ~['path' 'name' 'old_string' 'new_string']
      ==
      %:  mk-tool-typed:clanker  'write_code'
        'Write or patch Hoon in the code namespace. Full write: give content. Edit: give old_string + new_string. path is the dir (e.g. /nex), name is the file stem (no extension).'
        :~  ['path' 'string' 'Directory in the code namespace, e.g. /nex or /lib']
            ['name' 'string' 'File stem without extension, e.g. clanker']
            ['content' 'string' 'Full Hoon source (full-write mode)']
            ['old_string' 'string' 'Text to find (edit mode)']
            ['new_string' 'string' 'Replacement text (edit mode)']
        ==
        ~['path' 'name']
      ==
      %:  mk-tool-typed:clanker  'check_bin'
        'Check whether a build artifact compiled. Returns the error tang if it failed. Run AFTER commit.'
        :~  ['path' 'string' 'Bins path, e.g. /nex or /lib']
            ['name' 'string' 'Artifact name, e.g. clanker']
            ['show' 'boolean' 'Show the compiled noun via +sell (default false)']
        ==
        ~['path' 'name']
      ==
      %:  mk-tool-typed:clanker  'commit'
        'Commit the grubbery (always mount_point "grubbery"). This triggers the build. Returns version info and build logs.'
        :~  ['mount_point' 'string' 'Always "grubbery"']
            ['timeout_seconds' 'number' 'Seconds to wait for logs (default 30)']
        ==
        ~['mount_point']
      ==
  ==
::  +grubbery-system: the grubbery project's standing prompt.
++  grubbery-system
  ^-  @t
  '''
  You are the grubbery coding assistant, embedded in the grubbery itself. You
  read and edit grubbery's own source and commit it, bounded by this chat's
  weir (what falls outside it simply isn't reachable).

  Tools:
  - grep / read_grub: find and read source in the grubbery ball.
  - write_code: write or patch Hoon in the code namespace (path = directory
    like /nex or /lib, name = file stem with no extension).
  - edit_file: exact-string edit of a text grub.
  - commit: commit the grubbery (always mount_point "grubbery"), which is what
    triggers the build.
  - check_bin: after committing, verify an artifact compiled (it reports the
    error tang if the build failed).

  Workflow: locate with grep/read_grub, make the change with write_code or
  edit_file, commit (mount_point "grubbery"), then check_bin to confirm it
  built. Be concrete, name the paths you touch, and verify the build before
  reporting done. If something isn't reachable within your weir, say so plainly
  rather than guessing.
  '''
--
