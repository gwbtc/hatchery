::  clanker agent: ONE clanker, as a nexus. The collection (./app.hoon)
::  mounts one of these per <name>.clanker dir, under a weir that is the
::  clanker's scope. Everything the clanker is lives in its own tree:
::
::    config.json         {name, model, max_tokens, bundle}
::    system.md           the standing prompt
::    memories/*.md       what it has learned (its tools write here)
::    skills/*.md         standing instructions, one per file
::    tools.json          the tool policy (optional): which tools run
::                        freely, which ask first, which are withheld
::    chats/<c>/log.chat-log     one append-only event log per chat
::    chats/<c>/system.md        that chat's own prompt (optional): the
::                               clanker is one identity, a chat is one
::                               standing role of it (docs, build, …)
::    chats/<c>/tools.json       that chat's own policy (optional), which
::                               can only tighten the clanker's
::    chats/<c>/<sub>.clanker/   a clanker this chat spawned (nested)
::    tools/              its own tools nexus, seeded from a bundle
::
::  Every turn assembles the request from those files: system.md, then
::  the chat's own system.md if it has one, then the skills, then the
::  memories, then the chat's events. Tools and memories are the
::  clanker's; a chat narrows the tools by policy, never widens them (a
::  chat that needs MORE is a different clanker, with its own weir). The
::  tools it advertises are whatever its tools nexus lists, so adding a
::  tool is writing a file under tools/code/lib/tools, no schema anywhere.
::
::  The tool policy (tools.json, at the clanker and/or a chat):
::    {"default": "ask", "allow": ["repo_read"], "deny": ["write_file"]}
::  Per tool NAME, nothing finer (a tool whose uses deserve different
::  answers is two tools). A matching deny wins, then a matching allow,
::  else the default; with no file at all everything is allowed. The
::  chat's verdict and the clanker's combine as the stricter of the two.
::    deny   the tool is not advertised to the model at all
::    allow  runs as it comes
::    ask    advertised; when the model calls it the turn pauses on an
::           %ask event, the chat pane offers run/decline per use, and a
::           {action:'resolve'} poke appends a %resolved event and the
::           turn goes on: accepted uses run, declined ones answer the
::           model with a refusal. The log is the truth, so a pending ask
::           survives a restart and a stop cancels it.
::
::  Reuse: lib/clanker's door for the metered proxy round-trip
::  (+call-anthropic), persistence (+write-chat) and the interrupt-aware
::  take; lib/tools for the run-grub protocol the tools nexus speaks.
::
/<  clanker    /lib/clanker.hoon
/<  nex-tools  /lib/tools.hoon
/&  bundle         /lib/clanker-bundle/
/&  kernel-bundle  /lib/clanker-kernel-bundle/
/&  repo-bundle    /lib/clanker-repo-bundle/
/&  build-bundle   /lib/clanker-build-bundle/
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
::  on top of it, the bundle config.json names: "kernel" = the grubbery
::  self-editing tools; "repo" = tools that read one git checkout (the
::  repo config.json points at, within the weir the host set).
++  tools-bole
  |=  which=@t
  ^-  bole:tarball
  =/  base=bole:tarball  (seed-tools:nex-tools bundle)
  ?:  =('kernel' which)
    (merge-boles:nex-tools base (seed-tools:nex-tools kernel-bundle))
  ?:  =('repo' which)
    (merge-boles:nex-tools base (seed-tools:nex-tools repo-bundle))
  ::  "build" = the repo set plus the tools that change the checkout and
  ::  drive its git lane (write, edit, git); which chats may use those is
  ::  the policy's business (tools.json), the weir's what they may reach
  ?:  =('build' which)
    %+  merge-boles:nex-tools
      (merge-boles:nex-tools base (seed-tools:nex-tools repo-bundle))
    (seed-tools:nex-tools build-bundle)
  base
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
  ;<  ~  bind:m  (resume rail)
  |-
  ;<  =sage:tarball  bind:m  take-poke:io
  =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
  ?.  ?=([%o *] jon)  $
  =/  act=(unit @t)
    (bind (~(get by p.jon) 'action') |=(j=json ?>(?=(%s -.j) p.j)))
  =/  chat=@t  =/(c=@t (jstr:clanker jon 'chat') ?:(=('' c) 'main' c))
  ::  an interrupt that lands idle: nothing runs, but a chat paused on an
  ::  ask is waiting on the user, and stop means no
  ?:  ?=([~ %'interrupt'] act)
    ;<  ~  bind:m  (cancel-ask rail chat)
    $
  ::  the user's answer to a pending ask: {action:'resolve', chat,
  ::  decisions:{<tool_use id>: true|false}}
  ?:  ?=([~ %'resolve'] act)
    ;<  ~  bind:m  (resolve-chat rail jon chat)
    $
  ;<  ~  bind:m  (turn-chat rail jon chat)
  $
::  +chat-log: a chat's log road and its events (~ when there is none).
++  chat-log
  |=  [=rail:tarball chat=@t]
  =/  m  (fiber:fiber:nexus ,[road=road:tarball existed=? log=(list json)])
  ^-  form:m
  =/  road=road:tarball  (nex-road:io rail [%& [%chats `@ta`chat ~] log-name])
  ;<  cur=view:nexus  bind:m  (peek:io road `[/ %json])
  =/  log=(list json)
    ?.  ?=([%file *] cur)  ~
    =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.cur)))) [%a ~])
    ?.(?=([%a *] j) ~ p.j)
  (pure:m [road ?=([%file *] cur) log])
::  +last-kind: the k of a log's last event ('' when empty).
++  last-kind
  |=  log=(list json)
  ^-  @t
  ?~(log '' (jstr:clanker (rear log) 'k'))
::  +cancel-ask: a chat paused on an ask is stopped: the ask is answered
::  by an interrupt, so the log is at rest and nothing resumes it.
++  cancel-ask
  |=  [=rail:tarball chat=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [road=road:tarball existed=? log=(list json)]  bind:m  (chat-log rail chat)
  ?.  =('ask' (last-kind log))  (pure:m ~)
  (write-log road existed (snoc log event-interrupt))
::  +resolve-chat: the user decided the pending ask. Append the %resolved
::  event (ids -> yes/no) and run on from there. A resolve with no ask
::  pending is dropped.
++  resolve-chat
  |=  [=rail:tarball jon=json chat=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [road=road:tarball existed=? log=(list json)]  bind:m  (chat-log rail chat)
  ?.  =('ask' (last-kind log))  (pure:m ~)
  =/  decisions=json
    ?.  ?=([%o *] jon)  [%o ~]
    (fall (~(get by p.jon) 'decisions') [%o ~])
  =.  log  (snoc log (event-resolved decisions))
  ;<  ~  bind:m  (write-log road existed log)
  ;<  cfg=json  bind:m  (read-json rail [%& / %'config.json'])
  =/  model=@t  =/(mo=@t (jstr:clanker cfg 'model') ?:(=('' mo) 'claude-sonnet-4-6' mo))
  =/  max=@ud   (jnum:clanker cfg 'max_tokens' 4.096)
  ;<  sys=@t  bind:m  (standing rail chat)
  ;<  pol=policy  bind:m  (read-policy rail chat)
  ;<  schema=json  bind:m  (list-tools rail pol)
  (run rail chat road log sys model max schema pol)
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
  ;<  sys=@t  bind:m  (standing rail chat)
  ;<  pol=policy  bind:m  (read-policy rail chat)
  ;<  schema=json  bind:m  (list-tools rail pol)
  ::  the chat dir, then its log
  =/  chat-dir=path  [%chats `@ta`chat ~]
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| chat-dir]) ~)
  ;<  ~  bind:m
    ?:  ?=([%ball *] dv)  (pure:m ~)
    (make:io (nex-road:io rail [%| chat-dir]) &+empty-dir:loader)
  ;<  [road=road:tarball existed=? log=(list json)]  bind:m  (chat-log rail chat)
  ::  a chat paused on an ask takes no new message until it is answered
  ::  (the model's pending tool uses must be answered first)
  ?:  =('ask' (last-kind log))  (pure:m ~)
  =.  log  (snoc log (event-input u.msg))
  ;<  ~  bind:m  (write-log road existed log)
  (run rail chat road log sys model max schema pol)
::  the chat log: one file per chat, its own mark (the explorer opens a
::  chat-log in the chat viewer), json inside
++  log-name  %'log.chat-log'
++  write-log
  |=  [road=road:tarball existed=? log=(list json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  (write-status road log)
  ?:  existed  (over:io road [[/ %chat-log] [%a log]])
  ;<  err=(unit tang)  bind:m  (make-soft:io road |+[[[/ %chat-log] [%a log]] ~])
  (pure:m ~)
::  +write-status: the chat's state as a sibling status.json, derived from
::  the log every time the log is written: {state, asks, last}. The log's
::  own mark is this app's, so a reader elsewhere (a tool, another app)
::  cannot validate it; plain json it can. state is one of idle, busy
::  (a turn runs), asking (paused on the user: `asks` lists the pending
::  tool uses, {id, name, input}, answered by {action:'resolve'}),
::  stopped. last is the latest assistant text.
++  write-status
  |=  [road=road:tarball log=(list json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  the log's road with the file name swapped, absolute or relative
  =/  status-road=(unit road:tarball)
    ?-  -.road
      %&  ?.(?=(%& -.p.road) ~ `road(name.p.p %'status.json'))
      %|  ?.(?=(%& -.q.p.road) ~ `road(name.p.q.p %'status.json'))
    ==
  ?~  status-road  (pure:m ~)
  =/  status-road=road:tarball  u.status-road
  =/  jon=json  (status-of log)
  ;<  v=view:nexus  bind:m  (peek:io status-road ~)
  ?:  ?=([%file *] v)  (over:io status-road [[/ %json] jon])
  ;<  *  bind:m  (make-soft:io status-road |+[[[/ %json] jon] ~])
  (pure:m ~)
++  status-of
  |=  log=(list json)
  ^-  json
  =/  k=@t  (last-kind log)
  =/  resp=json  (last-response log)
  =/  state=@t
    ?:  =('ask' k)  'asking'
    ?:  =('interrupt' k)  'stopped'
    ?:  (open-turn log)  'busy'
    'idle'
  =/  asks=(list json)
    ?.  =('ask' k)  ~
    =/  ids=(set @t)
      =/  l=json  (rear log)
      ?.  ?=([%o *] l)  ~
      =/  v  (~(get by p.l) 'ids')
      ?.  ?=([~ %a *] v)  ~
      (sy (murn p.u.v |=(j=json ?:(?=([%s *] j) `p.j ~))))
    %+  murn  (resp-content resp)
    |=  b=json
    ^-  (unit json)
    ?.  ?=([%o *] b)  ~
    ?.  ?=([~ %s %'tool_use'] (~(get by p.b) 'type'))  ~
    ?.  (~(has in ids) (jstr:clanker b 'id'))  ~
    `(pairs:enjs:format ~[['id' s+(jstr:clanker b 'id')] ['name' s+(jstr:clanker b 'name')] ['input' (fall (~(get by p.b) 'input') [%o ~])]])
  =/  last=@t
    %-  crip
    %-  zing
    %+  turn  (resp-content resp)
    |=  b=json
    ?.  ?=([%o *] b)  ""
    ?.  ?=([~ %s %'text'] (~(get by p.b) 'type'))  ""
    (trip (jstr:clanker b 'text'))
  %-  pairs:enjs:format
  :~  ['state' s+state]
      ['events' (numb:enjs:format (lent log))]
      ['asks' [%a asks]]
      ['last' s+last]
  ==
::  +resume: the restart contract. This fiber may be restarted at any
::  moment (a deploy, a crash); the log is the truth, so a chat whose log
::  ends mid-turn (an input or tool results not yet answered, or a
::  response still asking for tools) is picked up where it stopped. A
::  model call that was in flight is simply made again. A chat the user
::  stopped ends in an %interrupt event and is left alone.
++  resume
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  dv=view:nexus  bind:m  (peek:io (nex-road:io rail [%| /chats]) ~)
  ?.  ?=([%ball *] dv)  (pure:m ~)
  =/  chats=(list @ta)  ~(tap in ~(key by dir.ball.dv))
  |-
  ?~  chats  (pure:m ~)
  =/  road=road:tarball  (nex-road:io rail [%& [%chats i.chats ~] log-name])
  ;<  cur=view:nexus  bind:m  (peek:io road `[/ %json])
  =/  log=(list json)
    ?.  ?=([%file *] cur)  ~
    =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.cur)))) [%a ~])
    ?.(?=([%a *] j) ~ p.j)
  ?.  (open-turn log)  $(chats t.chats)
  ;<  cfg=json  bind:m  (read-json rail [%& / %'config.json'])
  =/  model=@t  =/(mo=@t (jstr:clanker cfg 'model') ?:(=('' mo) 'claude-sonnet-4-6' mo))
  =/  max=@ud   (jnum:clanker cfg 'max_tokens' 4.096)
  ;<  sys=@t  bind:m  (standing rail `@t`i.chats)
  ;<  pol=policy  bind:m  (read-policy rail `@t`i.chats)
  ;<  schema=json  bind:m  (list-tools rail pol)
  ;<  ~  bind:m  (run rail `@t`i.chats road log sys model max schema pol)
  $(chats t.chats)
::  +open-turn: does this log end mid-turn? An input or tool results
::  await a response; a response that stopped for tool_use awaits its
::  results; a resolved ask awaits its tools. Anything else (a finished
::  response, an interrupt, an ask still waiting on the user, an empty
::  log) is at rest.
++  open-turn
  |=  log=(list json)
  ^-  ?
  ?~  log  %.n
  =/  last=json  (rear log)
  =/  k=@t  (jstr:clanker last 'k')
  ?|  =('input' k)
      =('results' k)
      =('resolved' k)
      &(=('response' k) =('tool_use' (jstr:clanker last 'stop')))
  ==
::  the tool policy: a verdict per tool name. See the header.
+$  policy  [default=@t allow=(set @t) ask=(set @t) deny=(set @t)]
++  no-policy  `policy`['allow' ~ ~ ~]
::  +parse-policy: tools.json as a policy; a missing or malformed file
::  is no policy (everything allowed), a file with no default asks. An
::  "ask" list is accepted too (a name the default would allow, held to
::  asking) though the usual file needs only allow and deny.
++  parse-policy
  |=  jon=json
  ^-  (unit policy)
  ?.  ?=([%o *] jon)  ~
  =/  strs
    |=  k=@t
    ^-  (set @t)
    =/  v  (~(get by p.jon) k)
    ?.  ?=([~ %a *] v)  ~
    (sy (murn p.u.v |=(j=json ?:(?=([%s *] j) `p.j ~))))
  =/  d=@t  (jstr:clanker jon 'default')
  =/  d=@t  ?:(|(=('allow' d) =('ask' d) =('deny' d)) d 'ask')
  `[d (strs 'allow') (strs 'ask') (strs 'deny')]
::  +read-policy: the clanker's policy and the chat's, folded into one
::  that yields, per tool, the stricter of the two verdicts.
++  read-policy
  |=  [=rail:tarball chat=@t]
  =/  m  (fiber:fiber:nexus ,policy)
  ^-  form:m
  ;<  base=json  bind:m  (read-json rail [%& / %'tools.json'])
  ;<  own=json  bind:m  (read-json rail [%& [%chats `@ta`chat ~] %'tools.json'])
  =/  b=policy  (fall (parse-policy base) no-policy)
  =/  c=policy  (fall (parse-policy own) no-policy)
  =/  names=(set @t)
    %-  ~(gas in *(set @t))
    ;:  weld
      ~(tap in allow.b)  ~(tap in ask.b)  ~(tap in deny.b)
      ~(tap in allow.c)  ~(tap in ask.c)  ~(tap in deny.c)
    ==
  =/  out=policy  [(stricter default.b default.c) ~ ~ ~]
  %-  pure:m
  %+  roll  ~(tap in names)
  |=  [n=@t acc=_out]
  =/  v=@t  (stricter (verdict b n) (verdict c n))
  ?:  =('deny' v)  acc(deny (~(put in deny.acc) n))
  ?:  =('ask' v)  acc(ask (~(put in ask.acc) n))
  acc(allow (~(put in allow.acc) n))
++  stricter
  |=  [x=@t y=@t]
  ^-  @t
  =/  rank  |=(v=@t ^-(@ud ?:(=('deny' v) 2 ?:(=('ask' v) 1 0))))
  ?:((gte (rank x) (rank y)) x y)
::  +verdict: one tool's verdict under a policy: deny, else ask, else
::  allow, else the default.
++  verdict
  |=  [p=policy name=@t]
  ^-  @t
  ?:  (~(has in deny.p) name)  'deny'
  ?:  (~(has in ask.p) name)  'ask'
  ?:  (~(has in allow.p) name)  'allow'
  default.p
::  +standing: the clanker's standing context for one chat, assembled
::  from its files: system.md, then the chat's own system.md if it has
::  one (the chat's role on top of the clanker's identity), then every
::  skill, then every memory. Each file is a titled section so the model
::  (and the context panel) can tell them apart. v1 inlines everything; a
::  budget comes later and lives here.
++  standing
  |=  [=rail:tarball chat=@t]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  sys=@t  bind:m  (read-text rail [%& / %'system.md'])
  ;<  chat-sys=@t  bind:m  (read-text rail [%& [%chats `@ta`chat ~] %'system.md'])
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
    ?:(=('' chat-sys) "" "\0a\0a# This chat\0a{(trip chat-sys)}\0a")
    (section "Skills" skills)
    (section "Memories" memories)
  ==
::  +list-tools: what this clanker's tools nexus advertises, as an
::  Anthropic tool schema array, plus the engine's own `spawn`. The tools
::  nexus answers a {cmd:'list'} poke by poking the array back to us.
++  list-tools
  |=  [=rail:tarball pol=policy]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ::  the list comes back as a poke; one lost across a reboot of the tools
  ::  nexus must not park this fiber forever (every later poke would be
  ::  skipped behind it), so ask again after a deadline, a few times
  ;<  listed=(list json)  bind:m
    =/  mt  (fiber:fiber:nexus ,(list json))
    =/  tries=@ud  0
    |-  ^-  form:mt
    ;<  ~  bind:mt
      (poke:io (nex-road:io rail [%& /tools %'main.sig']) [[/ %json] (pairs:enjs:format ~[['cmd' s+'list']])])
    ;<  got=(unit (list json))  bind:mt
      %^  (with-timeout:io ,(list json))  /tool-list  ~s20
      take-list
    ?^  got  (pure:mt u.got)
    ?:  (gte tries 3)  (pure:mt ~)
    $(tries +(tries))
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
  ::  a denied tool is not advertised: the model never sees it
  =/  all=(list json)  (snoc tools spawn-schema)
  %-  pure:m
  :-  %a
  %+  skip  all
  |=(t=json =('deny' (verdict pol (jstr:clanker t 'name'))))
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
::  +run: the agent loop over the event log, driven by its tail. A log
::  ending in a response that asked for tools runs them and appends the
::  %results event; anything else assembles the request, sends it and
::  appends the %response event. Each event is persisted as it lands, so
::  a restart resumes from the tail (+resume). An interrupt (~ from the
::  proxy / tools) appends an %interrupt event and stops: the log is
::  intact and at rest.
++  run
  |=  [=rail:tarball chat=@t road=road:tarball log=(list json) sys=@t model=@t max=@ud schema=json pol=policy]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-  ^-  form:m
  =/  last=json  ?~(log [%o ~] (rear log))
  =/  k=@t  (jstr:clanker last 'k')
  ::  paused on the user: at rest until a resolve or a stop
  ?:  =('ask' k)  (pure:m ~)
  ::  the tool uses to run now: the last response's, straight (when it
  ::  just landed) or as the user resolved them (when the tail is the
  ::  resolved event; the response is the one before the ask)
  =/  resolved=(unit json)  ?.(=('resolved' k) ~ `last)
  =/  resp=json
    ?^  resolved  (last-response log)
    ?.  &(=('response' k) =('tool_use' (jstr:clanker last 'stop')))  [%o ~]
    last
  =/  tool-uses=(list json)
    %+  skim  (resp-content resp)
    |=(b=json ?&(?=([%o *] b) ?=([~ %s %'tool_use'] (~(get by p.b) 'type'))))
  ?^  tool-uses
    ::  a use whose tool asks first pauses the turn, unless the user
    ::  already answered (the resolved tail)
    =/  asks=(list @t)
      ?^  resolved  ~
      %+  murn  tool-uses
      |=(tu=json ?:(=('ask' (verdict pol (jstr:clanker tu 'name'))) `(jstr:clanker tu 'id') ~))
    ?^  asks
      (write-log road %.y (snoc log (event-ask asks)))
    =/  declined=(set @t)
      ?~  resolved  ~
      ?.  ?=([%o *] u.resolved)  ~
      =/  d  (~(get by p.u.resolved) 'decisions')
      ?.  ?=([~ %o *] d)  ~
      %-  sy
      %+  murn  ~(tap by p.u.d)
      |=([id=@t v=json] ?:(?=([%b %.n] v) `id ~))
    ;<  ran=(unit [(list json) (list json)])  bind:m  (run-tools rail chat tool-uses declined)
    ?~  ran
      (write-log road %.y (snoc log event-interrupt))
    =.  log  (snoc log (event-results -.u.ran +.u.ran))
    ;<  ~  bind:m  (write-log road %.y log)
    $
  =/  messages=(list json)  (assemble log)
  ;<  answered=(unit json)  bind:m  (call-anthropic:ck (encode model max sys schema messages))
  ?~  answered
    (write-log road %.y (snoc log event-interrupt))
  =/  resp=json  u.answered
  =/  content-arr=(list json)  (resp-content resp)
  =.  log  (snoc log (event-response content-arr (resp-stop resp) (resp-usage resp)))
  ;<  ~  bind:m  (write-log road %.y log)
  ?.  =('tool_use' (resp-stop resp))  (pure:m ~)
  $
::  +run-tools: execute each tool_use; `spawn` is the engine's own, every
::  other name goes to this clanker's tools nexus. Yields the tool_result
::  blocks (for the model) and trace entries (for the UI). ~ on interrupt.
++  run-tools
  |=  [=rail:tarball chat=@t tool-uses=(list json) declined=(set @t)]
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
    ::  a use the user declined does not run; the model is told so
    ?:  (~(has in declined) tid)
      =/  mo  (fiber:fiber:nexus ,(unit [json @t]))
      (pure:mo `[s+'The user declined to run this tool. Do not retry it; ask, or go on without it.' 'declined'])
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
  =/  child-log=road:tarball  (nex-road:io rail [%& (weld dir /chats/main) log-name])
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
::  +await-run: the run grub's %done, taken from its change notices, but
::  never only from them: a notice lost across a reboot would park this
::  fiber for good, so every few seconds the run is simply read, and a
::  run that is gone (the tools nexus reseeded, its runs/ with it) is
::  given up on as an error rather than waited on. ~ on interrupt.
++  await-run
  |=  [run-road=road:tarball run-name=@ta]
  =/  m  (fiber:fiber:nexus ,(unit (unit json)))
  ^-  form:m
  =/  misses=@ud  0
  |-
  ;<  timed=(unit (unit wave:nexus))  bind:m
    %^  (with-timeout:io ,(unit wave:nexus))  /run-poll  ~s5
    (take-news-or-interrupt:ck /tool)
  ?:  ?=([~ ~] timed)  (pure:m ~)
  ;<  =view:nexus  bind:m  (peek:io run-road ~)
  ?.  ?=([%file *] view)
    ?:  (gte misses 6)
      (pure:m `[~ (pairs:enjs:format ~[['type' s+'error'] ['message' s+'the tool run disappeared (the tools nexus reloaded); try again']])])
    $(misses +(misses))
  =/  res  (mule |.(!<(tool-state:nex-tools (need-vase:tarball sang.view))))
  ?:  ?=(%| -.res)  $
  ?.  =(%done step.p.res)  $
  (pure:m `update.p.res)
::  +assemble: THE context policy. Fold the event log into Anthropic
::  messages. v1 = append-all, with one repair: the API requires every
::  tool_use in an assistant turn to be answered by a tool_result in the
::  next user turn. A turn stopped between the two (an ask the user
::  cancelled, an interrupt mid-tools) leaves the call unanswered in the
::  log, and every later request would be refused. So a tool_use with no
::  results event after it is answered here with a synthetic result
::  saying it was stopped, folded into the next user turn.
++  assemble
  |=  log=(list json)
  ^-  (list json)
  =/  stopped
    |=  ids=(list @t)
    ^-  (list json)
    %+  turn  ids
    |=  id=@t
    %-  pairs:enjs:format
    :~  ['type' s+'tool_result']
        ['tool_use_id' s+id]
        ['content' s+'This tool call was stopped by the user before it ran.']
    ==
  =|  out=(list json)
  =|  pending=(list @t)
  |-  ^-  (list json)
  ?~  log
    ::  a trailing tool_use is the live turn (+run answers it); leave it
    (flop out)
  =*  ev  i.log
  ?.  ?=([%o *] ev)  $(log t.log)
  =/  k=@t  (jstr:clanker ev 'k')
  ?:  =('input' k)
    =/  text=json  (pairs:enjs:format ~[['type' s+'text'] ['text' s+(jstr:clanker ev 'body')]])
    =/  content=json
      ?~  pending  s+(jstr:clanker ev 'body')
      a+(snoc (stopped pending) text)
    %=  $
      log      t.log
      pending  ~
      out      [(pairs:enjs:format ~[['role' s+'user'] ['content' content]]) out]
    ==
  ?:  =('results' k)
    =/  c=(unit json)  (~(get by p.ev) 'content')
    ?.  ?=([~ %a *] c)  $(log t.log)
    %=  $
      log      t.log
      pending  ~
      out      [(pairs:enjs:format ~[['role' s+'user'] ['content' u.c]]) out]
    ==
  ?:  =('response' k)
    =/  c=(unit json)  (~(get by p.ev) 'content')
    ?.  ?=([~ %a *] c)  $(log t.log)
    ::  a response after an unanswered tool_use: answer it first
    =?  out  ?=(^ pending)
      [(pairs:enjs:format ~[['role' s+'user'] ['content' a+(stopped pending)]]) out]
    =/  uses=(list @t)
      %+  murn  p.u.c
      |=  b=json
      ?.  ?=([%o *] b)  ~
      ?.  ?=([~ %s %'tool_use'] (~(get by p.b) 'type'))  ~
      `(jstr:clanker b 'id')
    %=  $
      log      t.log
      pending  uses
      out      [(pairs:enjs:format ~[['role' s+'assistant'] ['content' u.c]]) out]
    ==
  $(log t.log)
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
::  the turn was stopped (by the user, or a tool/proxy interrupt): the
::  log is at rest here, and a restart does not resume it
++  event-interrupt
  ^-  json
  (pairs:enjs:format ~[['k' s+'interrupt']])
::  the turn is paused on the user: these tool_use ids (of the response
::  just before) ask first. At rest until resolved or stopped.
++  event-ask
  |=  ids=(list @t)
  ^-  json
  (pairs:enjs:format ~[['k' s+'ask'] ['ids' [%a (turn ids |=(i=@t `json`s+i))]]])
::  the user's answer: {id: true|false} per asked use. Only an explicit
::  false declines; an id left out runs.
++  event-resolved
  |=  decisions=json
  ^-  json
  (pairs:enjs:format ~[['k' s+'resolved'] ['decisions' decisions]])
::  +last-response: the newest response event in the log.
++  last-response
  |=  log=(list json)
  ^-  json
  =/  rs=(list json)  (skim log |=(e=json =('response' (jstr:clanker e 'k'))))
  ?~(rs [%o ~] (rear rs))
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
