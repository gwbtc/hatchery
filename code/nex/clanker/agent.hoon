::  clanker agent: ONE clanker, as a nexus. The collection (./app.hoon)
::  mounts one of these per <name>.clanker dir, under a weir that is the
::  clanker's scope. Everything the clanker is lives in its own tree:
::
::    config.json         {name, model, max_tokens, bundle}
::    system.md           the standing prompt
::    memories/*.md       what it has learned (its tools write here)
::    skills/*.md         standing instructions, one per file
::    chats/<c>/log.json  one append-only event log per chat
::    chats/<c>/<sub>.clanker/   a clanker this chat spawned (nested)
::    tools/              its own tools nexus, seeded from a bundle
::
::  Every turn assembles the request from those files: system.md, then
::  the skills, then the memories, then the chat's events. The tools it
::  advertises are whatever its tools nexus lists, so adding a tool is
::  writing a file under tools/code/lib/tools, no schema anywhere.
::
::  Reuse: lib/clanker's door for the metered proxy round-trip
::  (+call-anthropic), persistence (+write-chat) and the interrupt-aware
::  take; lib/tools for the run-grub protocol the tools nexus speaks.
::
/<  clanker    /lib/clanker.hoon
/<  nex-tools  /lib/tools.hoon
/&  bundle         /lib/clanker-bundle/
/&  kernel-bundle  /lib/clanker-kernel-bundle/
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ::  the sandbox is NOT self-declared here: it is the weir the host
      ::  set on this nexus when it mounted it. This lays out the tree.
      ::  config.json's "bundle" (read from the ball) picks the tools:
      ::  "kernel" adds the grubbery self-editing set to the default.
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          [%fall %& [/ %'system.md'] [[/ %mime] [/text/markdown (as-octs:mimes:html '')]]]
          [%fall %| /memories empty-dir:loader]
          [%fall %| /skills empty-dir:loader]
          [%fall %| /chats empty-dir:loader]
          [%over %| /tools (tools-bole (bundle-of ball))]
      ==
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
      ==
    --
|%
++  ck  ~(. clanker:clanker [%clanker [%a ~] '' [%o ~]])
++  default-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['model' s+'claude-sonnet-4-6']
      ['max_tokens' (numb:enjs:format 4.096)]
      ['bundle' s+'default']
  ==
::  +bundle-of: config.json's "bundle" as it sits in the ball at load.
++  bundle-of
  |=  =ball:tarball
  ^-  @t
  ?~  fil.ball  'default'
  =/  got  (~(get by contents.u.fil.ball) %'config.json')
  ?~  got  'default'
  =/  res  (mule |.(!<(json (need-vase:tarball sang.u.got))))
  ?:  ?=(%| -.res)  'default'
  =/  b=@t  (jstr:clanker p.res 'bundle')
  ?:(=('' b) 'default' b)
::  +tools-bole: the tools nexus mount, seeded from the default bundle and,
::  for a "kernel" clanker, the grubbery self-editing tools on top.
++  tools-bole
  |=  which=@t
  ^-  bole:tarball
  =/  base=bole:tarball  (seed-tools:nex-tools bundle)
  ?.  =('kernel' which)  base
  (merge-boles:nex-tools base (seed-tools:nex-tools kernel-bundle))
::  +serve: the main.sig poke loop. {chat, message} runs a turn;
::  {action:'interrupt'} is swallowed here (it lands mid-await inside a
::  running turn, which cancels it). The tools nexus's list reply is a
::  json array poked back here; it is taken inside +list-tools, so a
::  stray one that arrives idle is dropped.
++  serve
  |=  [=rail:tarball =prod:fiber:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  (rise-wait:io prod "%clanker agent: failed")
  |-
  ;<  =sage:tarball  bind:m  take-poke:io
  =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
  ?.  ?=([%o *] jon)  $
  =/  act=(unit @t)
    (bind (~(get by p.jon) 'action') |=(j=json ?>(?=(%s -.j) p.j)))
  ?:  ?=([~ %'interrupt'] act)  $
  =/  chat=@t  =/(c=@t (jstr:clanker jon 'chat') ?:(=('' c) 'main' c))
  ;<  ~  bind:m  (turn-chat rail jon chat)
  $
::  +turn-chat: one turn. Append the %input event to the chat log, persist
::  (so a refresh shows it even if the turn stalls), assemble this
::  clanker's standing context from its files, ask its tools nexus what it
::  advertises, then run the loop.
++  turn-chat
  |=  [=rail:tarball jon=json chat=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (pure:m ~)
  =/  msg=(unit @t)
    (bind (~(get by p.jon) 'message') |=(j=json ?>(?=(%s -.j) p.j)))
  ?~  msg  (pure:m ~)
  ;<  cfg=json  bind:m  (read-json rail [%& / %'config.json'])
  =/  model=@t  =/(mo=@t (jstr:clanker cfg 'model') ?:(=('' mo) 'claude-sonnet-4-6' mo))
  =/  max=@ud   (jnum:clanker cfg 'max_tokens' 4.096)
  ;<  sys=@t  bind:m  (standing rail)
  ;<  schema=json  bind:m  (list-tools rail)
  ::  the chat dir, then its log
  =/  chat-dir=path  [%chats `@ta`chat ~]
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| chat-dir]) ~)
  ;<  ~  bind:m
    ?:  ?=([%ball *] dv)  (pure:m ~)
    (make:io (nex-road:io rail [%| chat-dir]) &+empty-dir:loader)
  =/  road=road:tarball  (nex-road:io rail [%& chat-dir %'log.json'])
  ;<  cur=view:nexus  bind:m  (peek:io road `[/ %json])
  =/  log=(list json)
    ?.  ?=([%file *] cur)  ~
    =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.cur)))) [%a ~])
    ?.(?=([%a *] j) ~ p.j)
  =/  existed=?  ?=([%file *] cur)
  =.  log  (snoc log (event-input u.msg))
  ;<  ~  bind:m  (write-chat:ck road existed log)
  (run rail chat road log sys model max schema)
::  +standing: the clanker's standing context, assembled from its files:
::  system.md, then every skill, then every memory. Each file is a
::  titled section so the model (and the context panel) can tell them
::  apart. v1 inlines everything; a budget comes later and lives here.
++  standing
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  sys=@t  bind:m  (read-text rail [%& / %'system.md'])
  ;<  skills=(list [@ta @t])  bind:m  (read-dir-texts rail /skills)
  ;<  memories=(list [@ta @t])  bind:m  (read-dir-texts rail /memories)
  =/  section
    |=  [title=tape files=(list [n=@ta body=@t])]
    ^-  tape
    =/  out=tape
      %-  zing
      %+  turn  files
      |=([n=@ta body=@t] "\0a## {(trip n)}\0a{(trip body)}\0a")
    ?:  =("" out)  ""
    (weld "\0a\0a# {title}\0a" out)
  %-  pure:m
  %-  crip
  ;:  weld
    (trip sys)
    (section "Skills" skills)
    (section "Memories" memories)
  ==
::  +list-tools: what this clanker's tools nexus advertises, as an
::  Anthropic tool schema array, plus the engine's own `spawn`. The tools
::  nexus answers a {cmd:'list'} poke by poking the array back to us.
++  list-tools
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  ~  bind:m
    (poke:io (nex-road:io rail [%& /tools %'main.sig']) [[/ %json] (pairs:enjs:format ~[['cmd' s+'list']])])
  ;<  listed=(list json)  bind:m  take-list
  =/  tools=(list json)
    %+  turn  listed
    |=  t=json
    ^-  json
    ::  the tools nexus speaks {name, description, parameters, required};
    ::  Anthropic wants input_schema
    ?.  ?=([%o *] t)  t
    %-  pairs:enjs:format
    :~  ['name' (fall (~(get by p.t) 'name') s+'')]
        ['description' (fall (~(get by p.t) 'description') s+'')]
        :-  'input_schema'
        %-  pairs:enjs:format
        :~  ['type' s+'object']
            ['properties' (fall (~(get by p.t) 'parameters') [%o ~])]
            ['required' (fall (~(get by p.t) 'required') [%a ~])]
        ==
    ==
  (pure:m [%a (snoc tools spawn-schema)])
::  +take-list: the list reply, a json array poked to main.sig. Anything
::  else that lands meanwhile is skipped (re-offered to the serve loop).
++  take-list
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]  [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    =/  jon=json  (fall (mole |.(!<(json q.sage.u.in))) *json)
    ?.  ?=([%a *] jon)  [%skip ~]
    [%done p.jon]
  ==
::  +is-clanker-seg: a path segment that names a clanker dir.
++  is-clanker-seg
  |=  n=@ta
  ^-  ?
  =/  t=tape  (trip n)
  =/  len=@ud  (lent t)
  &((gth len 8) =(".clanker" (slag (sub len 8) t)))
::  +spawn-schema: the one tool the engine provides itself.
++  spawn-schema
  ^-  json
  %:  mk-tool-typed:clanker  'spawn'
    'Delegate a task to a nested clanker of your own. It lives beneath this chat with its own prompt, memories and tools, and its full conversation is kept there. Reusing a name continues that clanker. Returns its reply.'
    :~  ['name' 'string' 'kebab-case name of the nested clanker']
        ['system' 'string' 'its standing prompt (used when it is created)']
        ['message' 'string' 'the task or question to send it']
    ==
    ~['name' 'message']
  ==
::  +run: the agent loop over the event log. Assemble the request from
::  the log, send it, append the %response event, persist. If the model
::  asked for tools, run them, append the %results event, persist, loop.
::  An interrupt (~ from the proxy / tools) stops with the log intact up
::  to the last persisted event.
++  run
  |=  [=rail:tarball chat=@t road=road:tarball log=(list json) sys=@t model=@t max=@ud schema=json]
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
  ;<  ran=(unit [(list json) (list json)])  bind:m  (run-tools rail chat tool-uses)
  ?~  ran  (pure:m ~)
  =.  log  (snoc log (event-results -.u.ran +.u.ran))
  ;<  ~  bind:m  (write-chat:ck road %.y log)
  $
::  +run-tools: execute each tool_use; `spawn` is the engine's own, every
::  other name goes to this clanker's tools nexus. Yields the tool_result
::  blocks (for the model) and trace entries (for the UI). ~ on interrupt.
++  run-tools
  |=  [=rail:tarball chat=@t tool-uses=(list json)]
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
  ;<  outcome=(unit [json @t])  bind:m
    ?:  =('spawn' name)  (spawn rail chat input)
    (call-tool rail name input)
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
::  +spawn: a nested clanker beneath THIS chat. Made on first use as a
::  nexus of this same kind (its own on-load lays out its tree and seeds
::  its tools); no weir of its own, so it is bounded by ours. Then one
::  turn: poke its main.sig and wait for its reply event.
++  spawn
  |=  [=rail:tarball chat=@t input=json]
  =/  m  (fiber:fiber:nexus ,(unit [json @t]))
  ^-  form:m
  =/  name=@t  (jstr:clanker input 'name')
  =/  msg=@t   (jstr:clanker input 'message')
  =/  sys=@t   (jstr:clanker input 'system')
  ?:  |(=('' name) =('' msg))
    (pure:m `[s+'spawn needs a name and a message' 'error'])
  ::  depth guard: a clanker three deep spawns no further
  =/  depth=@ud  (lent (skim path.rail is-clanker-seg))
  ?:  (gte depth 3)
    (pure:m `[s+'spawn refused: nesting is already three clankers deep' 'error'])
  =/  dir=path  [%chats `@ta`chat (crip "{(trip name)}.clanker") ~]
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| dir]) ~)
  =/  mu  (fiber:fiber:nexus ,~)
  ;<  ~  bind:m
    ?:  ?=([%ball *] dv)  (pure:mu ~)
    =/  b=bole:tarball  [`[`[/clanker %agent] ~ %.n ~] ~]
    =.  b  (~(put bo:tarball b) [/ %'config.json'] [[/ %json] default-config])
    =.  b  (~(put bo:tarball b) [/ %'system.md'] [[/ %mime] [/text/markdown (as-octs:mimes:html sys)]])
    (make:io (nex-road:io rail [%| dir]) &+b)
  =/  child-log=road:tarball  (nex-road:io rail [%& (weld dir /chats/main) %'log.json'])
  ;<  *  bind:m  (keep:io /spawn child-log ~)
  ;<  ~  bind:m
    %-  poke:io
    :+  (nex-road:io rail [%& dir %'main.sig'])  [/ %json]
    (pairs:enjs:format ~[['chat' s+'main'] ['message' s+msg]])
  ;<  reply=(unit @t)  bind:m  (await-reply child-log)
  ;<  ~  bind:m  (drop:io /spawn child-log)
  ?~  reply  (pure:m ~)
  (pure:m `[s+u.reply (crip "{(trip name)}")])
::  +await-reply: wait for the child's log to end in a finished response,
::  and return its text. ~ on interrupt.
++  await-reply
  |=  log-road=road:tarball
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  |-
  ;<  raw=(unit wave:nexus)  bind:m  (take-news-or-interrupt:ck /spawn)
  ?~  raw  (pure:m ~)
  ;<  lv=view:nexus  bind:m  (peek:io log-road `[/ %json])
  ?.  ?=([%file *] lv)  $
  =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.lv)))) [%a ~])
  ?.  ?=([%a ^] j)  $
  =/  last=json  (rear p.j)
  ?.  &(?=([%o *] last) =('response' (jstr:clanker last 'k')))  $
  ?:  =('tool_use' (jstr:clanker last 'stop'))  $
  =/  text=tape
    %-  zing
    %+  turn  (resp-content last)
    |=  b=json
    ?.  ?=([%o *] b)  ""
    ?.  ?=([~ %s %'text'] (~(get by p.b) 'type'))  ""
    (trip (jstr:clanker b 'text'))
  (pure:m `(crip text))
::  +call-tool: one run through this clanker's tools nexus (the calls
::  protocol: poke main.sig, await the run grub, read the result). The
::  run grub is KEPT, keyed by the time it was made, so a run can be
::  inspected after the fact; +prune-runs bounds the history.
++  call-tool
  |=  [=rail:tarball name=@t args=json]
  =/  m  (fiber:fiber:nexus ,(unit [json @t]))
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  id=@t         (scot %da now)
  =/  run-name=@ta  `@ta`id
  =/  main-road=road:tarball  (nex-road:io rail [%& /tools %'main.sig'])
  =/  run-road=road:tarball   (nex-road:io rail [%& /tools/runs run-name])
  ;<  *  bind:m  (keep:io /tool run-road ~)
  ;<  ~  bind:m
    %-  poke:io
    :+  main-road  [/ %json]
    %-  pairs:enjs:format
    :~  ['cmd' s+'call']  ['id' s+id]  ['name' s+name]  ['arguments' args]
    ==
  ;<  timed=(unit (unit json))  bind:m  (await-run run-road run-name)
  ;<  ~  bind:m  (drop:io /tool run-road)
  ;<  ~  bind:m  (prune-runs rail)
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
::  +prune-runs: keep the newest `keep-runs` runs; cull the rest. Run
::  names are @da, so name order is time order. The culls are %cull
::  pokes to the tools nexus (its runs are its grubs).
++  keep-runs  50
++  prune-runs
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /tools/runs]) ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  ?~  fil.ball.dv  (pure:m ~)
  =/  names=(list @ta)  (sort ~(tap in ~(key by contents.u.fil.ball.dv)) aor)
  =/  n=@ud  (lent names)
  ?:  (lte n keep-runs)  (pure:m ~)
  =/  old=(list @ta)  (scag (sub n keep-runs) names)
  =/  main-road=road:tarball  (nex-road:io rail [%& /tools %'main.sig'])
  |-
  ?~  old  (pure:m ~)
  ;<  ~  bind:m
    %-  poke:io
    [main-road [/ %json] (pairs:enjs:format ~[['cmd' s+'cull'] ['id' s+i.old]])]
  $(old t.old)
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
::  +assemble: THE context policy. Fold the event log into Anthropic
::  messages. v1 = append-all.
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
::  +encode: the anthropic codec, request side.
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
::  readers over this clanker's own tree
++  read-json
  |=  [=rail:tarball =lane:tarball]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek:io (nex-road:io rail lane) `[/ %json])
  ?.  ?=([%file *] v)  (pure:m [%o ~])
  (pure:m (fall (mole |.(!<(json (need-vase:tarball sang.v)))) [%o ~]))
++  read-text
  |=  [=rail:tarball =lane:tarball]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek:io (nex-road:io rail lane) `[/ %mime])
  ?.  ?=([%file *] v)  (pure:m '')
  ?:  (is-boom:tarball sang.v)  (pure:m '')
  (pure:m `@t`q.q:!<(mime (need-vase:tarball sang.v)))
::  +read-dir-texts: every file directly in a dir, as [name text], sorted.
++  read-dir-texts
  |=  [=rail:tarball dir=path]
  =/  m  (fiber:fiber:nexus ,(list [@ta @t]))
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| dir]) ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  ?~  fil.ball.dv  (pure:m ~)
  =/  names=(list @ta)  (sort ~(tap in ~(key by contents.u.fil.ball.dv)) aor)
  =|  out=(list [@ta @t])
  |-
  ?~  names  (pure:m (flop out))
  ;<  t=@t  bind:m  (read-text rail [%& dir i.names])
  $(names t.names, out [[i.names t] out])
--
