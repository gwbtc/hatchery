::  lib/tools for a clanker's own tools nexus: the shared tool types and
::  helpers (a copy of /lib/tools.hoon, as every bundle carries), plus the
::  clanker-specific ones at the bottom: +clanker-up finds the enclosing
::  clanker by neck, +rel-path bounds a path to it, +reserved names what
::  the engine owns.
::
|%
::  Tool execution result
::
+$  tool-result
  $%  [%text text=@t]
      [%error message=@t]
      [%mime =mime]
  ==
::  Tool process state: args + step tag + step-specific data.
::  Step tag acts like a head-tagged union — handlers switch on it.
::  %start = fresh invocation. %done = finished with result.
::
+$  tool-state
  $:  tool=@t
      args=(map @t json)
      step=@tas
      data=json
      update=(unit json)
  ==
::  Parameter schema for tool discovery (MCP, Claude API, etc.)
::
+$  parameter-type
  $?  %string
      %number
      %boolean
      %array
      %object
  ==
::
+$  parameter-def
  $:  type=parameter-type
      description=@t
  ==
::  Tool definition: everything needed to advertise + execute a tool.
::  Built-in tools produce this directly. .hoon files must compile to this type.
::
+$  tool
  $_  ^?
  |%
  ++  name         *@t
  ++  description  *@t
  ++  parameters   *(map @t parameter-def)
  ++  required     *(list @t)
  ++  handler      *tool-handler
  --
::
+$  tool-handler  _*form:(fiber:fiber:nexus ,tool-result)
::  +so-loose: a lenient string decoder for a parameter typed %number.
::
++  so-loose
  |=  j=json
  ^-  @t
  ?+  j  (so:dejs:format j)
    [%n *]  p.j
  ==
::
++  mimes-to-bole
  |=  a=(axal (map @ta mime))
  ^-  bole:tarball
  =/  files=(map @ta [=bask:tarball gain=?])
    ?~  fil.a  ~
    %-  ~(run by u.fil.a)
    |=(=mime `[bask:tarball ?]`[[[/ %hoon] q.q.mime] %.y])
  =/  kids=(map @ta bole:tarball)
    %-  ~(urn by dir.a)
    |=([* kid=(axal (map @ta mime))] (mimes-to-bole kid))
  [`[~ ~ %.n files] kids]
::
++  seed-tools
  |=  srcs=(axal (map @ta mime))
  ^-  bole:tarball
  =/  lib-bole=bole:tarball  (mimes-to-bole srcs)
  =/  code-nex=bole:tarball  [`[`[/ %code] ~ %.n ~] (malt ~[[%lib lib-bole]])]
  [`[`[/ %tools] ~ %.n ~] (malt ~[[%code code-nex]])]
::
++  merge-boles
  |=  [base=bole:tarball over=bole:tarball]
  ^-  bole:tarball
  :-  ^-  (unit pulp:tarball)
      ?~  fil.over  fil.base
      ?~  fil.base  fil.over
      %-  some
      :^    ?~(neck.u.fil.over neck.u.fil.base neck.u.fil.over)
          ?~(weir.u.fil.over weir.u.fil.base weir.u.fil.over)
        gain.u.fil.over
      (~(uni by contents.u.fil.base) contents.u.fil.over)
  ^-  (map @ta bole:tarball)
  =/  keys=(set @ta)  (~(uni in ~(key by dir.base)) ~(key by dir.over))
  %-  ~(gas by *(map @ta bole:tarball))
  %+  turn  ~(tap in keys)
  |=  k=@ta
  ^-  [@ta bole:tarball]
  =/  b=(unit bole:tarball)  (~(get by dir.base) k)
  =/  o=(unit bole:tarball)  (~(get by dir.over) k)
  :-  k
  ?~  b  (need o)
  ?~  o  u.b
  (merge-boles u.b u.o)
::
++  strip-hoon
  |=  name=@ta
  ^-  @ta
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?.  (gth len 5)  name
  ?.  =(".hoon" (slag (sub len 5) t))  name
  (crip (scag (sub len 5) t))
::
++  seg-to-name
  |=  s=@ta
  ^-  @t
  (crip (turn (trip s) |=(c=@tD ?:(=('-' c) '_' c))))
::
++  name-to-seg
  |=  t=tape
  ^-  @ta
  (crip (turn t |=(c=@tD ?:(=('_' c) '-' c))))
::
++  split-name
  |=  t=tape
  ^-  (list tape)
  =|  cur=tape
  =|  acc=(list tape)
  |-
  ?~  t  (flop [(flop cur) acc])
  ?:  ?&  =('_' i.t)
          ?=(^ t.t)
          =('_' i.t.t)
      ==
    $(t t.t.t, acc [(flop cur) acc], cur ~)
  $(t t.t, cur [i.t cur])
::
++  derive-name
  |=  [sub=path file=@ta]
  ^-  @t
  =/  segs=(list @ta)  (snoc sub (strip-hoon file))
  %-  crip
  %-  zing
  %+  join  "__"
  (turn segs |=(s=@ta (trip (seg-to-name s))))
::
++  name-to-place
  |=  name=@t
  ^-  [sub=path arm=@ta]
  =/  parts=(list tape)  (split-name (trip name))
  =/  segs=(list @ta)  (turn parts name-to-seg)
  ?~  segs  [~ %$]
  [(snip `(list @ta)`segs) (rear segs)]
::
++  glob-match
  |=  [pat=tape txt=tape]
  ^-  ?
  ?~  pat  =(txt ~)
  ?:  =(i.pat '*')
    ?|  (glob-match t.pat txt)
        ?&(?=(^ txt) (glob-match pat t.txt))
    ==
  ?~  txt  %.n
  ?&(=(i.pat i.txt) (glob-match t.pat t.txt))
::
++  parse-path
  |=  t=@t
  ^-  (each path @t)
  =/  pax=(unit path)  (rush t stap)
  ?~  pax
    [%| (crip "Invalid path: {(trip t)} (must start with /)")]
  [%& u.pax]
::  Shared helper arms used by dynamic tool files
::
++  finish-commit
  |=  [args=(map @t json) data=json]
  =/  m  (fiber:fiber:nexus ,tool-result)
  ^-  form:m
  ?.  ?=([%o *] data)
    (pure:m [%error 'Commit state lost (stale tool grub). Please retry.'])
  =/  mount-point=@tas
    %.  [%o args]
    %-  ot:dejs:format
    :~  ['mount_point' so:dejs:format]
    ==
  ?~  (~(get by p.data) 'initial-ud')
    (pure:m [%error 'Commit state incomplete. Please retry.'])
  =/  initial-ud=@ud
    (~(dog jo:json-utils data) /initial-ud ni:dejs:format)
  =/  log-texts=(list @t)
    (~(dug jo:json-utils data) /logs (ar:dejs:format so:dejs:format) ~)
  ;<  final=cass:clay  bind:m  (clay-case:io mount-point)
  =/  result=tape
    %+  weld  "Initial version: {<initial-ud>}\0a"
    %+  weld  "Final version: {<ud.final>}\0a"
    %+  weld  "Logs ({<(lent log-texts)>}):\0a"
    (roll (flop log-texts) |=([log=@t acc=tape] (weld acc (trip log))))
  (pure:m [%text (crip result)])
::
++  finish-clay-write
  |=  [args=(map @t json) data=json]
  =/  m  (fiber:fiber:nexus ,tool-result)
  ^-  form:m
  ?.  ?=([%o *] data)
    (pure:m [%error 'Clay write state lost. Please retry.'])
  ?~  (~(get by p.data) 'initial-ud')
    (pure:m [%error 'Clay write state incomplete. Please retry.'])
  =/  initial-ud=@ud
    (~(dog jo:json-utils data) /initial-ud ni:dejs:format)
  =/  desk=@t
    (~(dog jo:json-utils data) /desk so:dejs:format)
  =/  file-path=@t
    (~(dog jo:json-utils data) /file-path so:dejs:format)
  =/  log-texts=(list @t)
    (~(dug jo:json-utils data) /logs (ar:dejs:format so:dejs:format) ~)
  =/  dek=@tas  (slav %tas desk)
  ;<  final=cass:clay  bind:m  (clay-case:io dek)
  =/  has-errors=?
    %+  lien  log-texts
    |=(t=@t !=(~ (find "ERROR" (trip t))))
  =/  result=tape
    ?:  has-errors
      %+  weld  "Clay write FAILED for {(trip file-path)} in %{(trip desk)}\0a"
      %+  weld  "Version unchanged: {<ud.final>}\0a"
      %+  weld  "Errors ({<(lent log-texts)>}):\0a"
      (roll (flop log-texts) |=([log=@t acc=tape] (weld acc (trip log))))
    %+  weld  "Wrote {(trip file-path)} to %{(trip desk)}\0a"
    %+  weld  "Version: {<initial-ud>} -> {<ud.final>}\0a"
    ?~  log-texts  ""
    %+  weld  "Logs ({<(lent log-texts)>}):\0a"
    (roll (flop log-texts) |=([log=@t acc=tape] (weld acc (trip log))))
  ?:  has-errors
    (pure:m [%error (crip result)])
  (pure:m [%text (crip result)])
::
++  sleep-or-crud
  |=  for=@dr
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  until=@da  (add now for)
  ;<  ~  bind:m  (send-wait:io until)
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %poke * *]
    ?.  =([/ %timer-wake] p.sage.u.in)
      [%skip ~]
    [%done ~]
  ==
::
+$  commit-event
  $%  [%timeout ~]
      [%quiet count=@ud]
      [%log =wave:nexus]
  ==
::
++  take-commit-event
  =/  m  (fiber:fiber:nexus ,commit-event)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %poke * *]
    ?.  =([/ %timer-wake] p.sage.u.in)
      [%skip ~]
    =/  wak=wire  !<(wire q.sage.u.in)
    ?+  wak  [%skip ~]
        [%commit-timeout ~]
      [%done %timeout ~]
        [%commit-quiet @ ~]
      [%done %quiet (slav %ud i.t.wak)]
    ==
      [~ %news [%dill %logs ~] *]
    [%done %log wave.u.in]
  ==
::
++  collect-logs
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  =commit-event  bind:m  take-commit-event
  ?-    -.commit-event
      %timeout  (pure:m ~)
      %quiet
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  logs=(list json)
      (~(dug jo:json-utils data.st) /logs (ar:dejs:format same:dejs:format) ~)
    ?.  =(count.commit-event (lent logs))
      $
    (pure:m ~)
      %log
    ;<  dill-view=view:nexus  bind:m  (peek:io [%& %& /sys/dill %'logs.dill-told'] ~)
    =/  log-text=tape
      ?.  ?=([%file *] dill-view)  ""
      ?.  ?=(%dill-told name.p.sang.dill-view)  ""
      (format-told !<(told:dill (need-vase:tarball sang.dill-view)))
    ?:  =(~ log-text)  $
    ;<  st=tool-state  bind:m  (get-state-as:io ,tool-state)
    =/  logs=(list json)
      (~(dug jo:json-utils data.st) /logs (ar:dejs:format same:dejs:format) ~)
    =/  new-data=json
      (~(put jo:json-utils data.st) /logs a+[s+(crip log-text) logs])
    =/  new-count=@ud  +((lent logs))
    ;<  ~  bind:m  (replace:io [tool.st args.st step.st new-data ~])
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m
      (set-timer:io /commit-quiet/(scot %ud new-count) (add now ~s1))
    $
  ==
::
++  format-told
  |=  log=told:dill
  ^-  tape
  ?-  -.log
      %crud
    =/  err-lines=wall  (zing (turn (flop q.log) (cury wash [0 80])))
    =/  lines-text=tape
      %-  zing
      %+  turn  err-lines
      |=(line=tape "{line}\0a")
    "ERROR [{<p.log>}]:\0a{lines-text}"
      %talk
    =/  talk-lines=wall  (zing (turn p.log (cury wash [0 80])))
    %-  zing
    %+  turn  talk-lines
    |=(line=tape "{line}\0a")
      %text
    "{p.log}\0a"
  ==
::
++  is-text-blot
  |=  name=@tas
  ^-  ?
  %-  ~(has in `(set @tas)`(sy ~[%json %txt %hoon %html %css %js %csv %xml %md %sig]))
  name
::
++  norm-mite
  |=  =mite
  ^-  ^mite
  ?.  ?=([@ ~] mite)  mite
  =/  t=tape  (trip i.mite)
  ?~  sl=(find "/" t)  mite
  ~[(crip (scag u.sl t)) (crip (slag +(u.sl) t))]
::
++  is-text-mime
  |=  =mite
  ^-  ?
  ?~  mite  %.n
  ?:  =('text' i.mite)  %.y
  ?.  =('application' i.mite)  %.n
  ?~  t.mite  %.n
  (~(has in (sy ~['json' 'xml' 'javascript' 'x-javascript' 'ecmascript'])) i.t.mite)
::
++  is-multimodal-mime
  |=  =mite
  ^-  ?
  ?~  mite  %.n
  ?|  =('image' i.mite)
      =([~['application' 'pdf']] mite)
  ==
::
++  mite-to-cord
  |=  =mite
  ^-  @t
  (crip (zing (join "/" (turn mite trip))))
::
++  render-mime
  |=  out=mime
  ^-  tool-result
  =.  p.out  (norm-mite p.out)
  ?:  (is-text-mime p.out)
    [%text (crip (trip q.q.out))]
  ?:  (is-multimodal-mime p.out)
    [%mime out]
  [%text (crip (trip q.q.out))]
::
++  render-grub-content
  |=  =view:nexus
  =/  m  (fiber:fiber:nexus ,tool-result)
  ^-  form:m
  ?>  ?=([%file *] view)
  ?:  ?=(%| -.q.sang.view)
    =/  =boom:tarball  p.q.sang.view
    =/  rendered=tape
      %-  zing
      %+  turn  (flop tang.boom)
      |=(=tank (weld ~(ram re tank) "\0a"))
    (pure:m [%error (crip "BOOM (mark %{(trip name.p.sang.view)})\0a{rendered}")])
  =/  =sage:tarball  (need-sage:tarball sang.view)
  =/  blot-text=@t
    (crip "[mark: {(spud (snoc path.p.sage name.p.sage))}]")
  ;<  result=tool-result  bind:m
    ?:  (is-text-blot name.p.sage)
      ?+  name.p.sage
        (pure:m [%text !<(@t q.sage)])
          %json  (pure:m [%text (en:json:html !<(json q.sage))])
          %txt   (pure:m [%text (of-wain:format !<(wain q.sage))])
          %hoon  (pure:m [%text !<(@t q.sage)])
      ==
    ?:  =(%mime name.p.sage)
      (pure:m (render-mime !<(mime q.sage)))
    ;<  convert=(unit tube:clay)  bind:m
      (get-tube:io [%& %| /code] [p.sage [/ %mime]])
    ?~  convert
      (pure:m [%error (crip "No conversion from {(trip name.p.sage)} to mime")])
    =/  out=mime  !<(mime (u.convert q.sage))
    (pure:m (render-mime out))
  ?:  ?=(%error -.result)  (pure:m result)
  ?:  ?=(%mime -.result)
    (pure:m [%mime mime.result])
  (pure:m [%text (crip "{(trip blot-text)}\0a{(trip text.result)}")])
::
++  lookup-grub
  |=  [pax=path file-name=@ta]
  =/  m  (fiber:fiber:nexus ,[name=@ta view=view:nexus])
  ^-  form:m
  ;<  =view:nexus  bind:m
    (peek:io [%& %& pax file-name] ~)
  (pure:m [file-name view])
::
++  tape-replace
  |=  [txt=tape old=tape new=tape all=?]
  ^-  (each tape @tas)
  =/  old-len=@ud  (lent old)
  ?:  =(0 old-len)  [%| %empty-search]
  =/  idx=(unit @ud)  (find old txt)
  ?~  idx  [%| %not-found]
  ?.  all
    =/  after=@ud  (add u.idx old-len)
    =/  rest=tape  (slag after txt)
    ?^  (find old rest)  [%| %not-unique]
    :-  %&
    :(weld (scag u.idx txt) new (slag after txt))
  =|  acc=tape
  =/  src=tape  txt
  |-
  =/  hit=(unit @ud)  (find old src)
  ?~  hit  [%& (weld acc src)]
  %=  $
    acc  :(weld acc (scag u.hit src) new)
    src  (slag (add u.hit old-len) src)
  ==
::
::  Clanker helpers. A tool runs inside <clanker>/tools/runs/<id>; the
::  clanker is the nearest ancestor whose neck is [/clanker %agent].
::
::  +clanker-up: steps from the running tool up to its clanker's root.
++  clanker-up
  =/  m  (fiber:fiber:nexus ,(unit @ud))
  ^-  form:m
  ;<  agent=road:tarball  bind:m
    (ancestor-road:io [/clanker %agent] [%| /])
  ?.  ?=(%| -.agent)  (pure:m ~)
  (pure:m `-.p.agent)
::  +rel-path: a relative "a/b/c" (or "") into a path, refusing anything
::  that could climb out of the clanker's root.
++  rel-path
  |=  rel=@t
  ^-  (each path @t)
  ?:  =('' rel)  [%& ~]
  =/  t=tape  (trip rel)
  =/  t=tape  ?~(t t ?:(=('/' i.t) t.t t))
  =/  t=tape  ?~(t t ?:(=('/' (rear t)) (snip `tape`t) t))
  ?~  t  [%& ~]
  =/  segs=(list @ta)
    =/  rest=tape  t
    =|  acc=(list @ta)
    =|  cur=tape
    |-  ^-  (list @ta)
    ?~  rest  (flop [(crip (flop cur)) acc])
    ?:  =('/' i.rest)  $(rest t.rest, acc [(crip (flop cur)) acc], cur ~)
    $(rest t.rest, cur [i.rest cur])
  ?:  (lien segs |=(s=@ta |(=('' s) =('..' s) =('.' s))))
    [%| 'path must not contain empty, "." or ".." segments']
  [%& segs]
::  +reserved: the subtrees the engine owns; tools may read them, never
::  write or delete.
++  reserved
  |=  p=path
  ^-  ?
  ?~  p  %.n
  |(=(%tools i.p) =(%chats i.p))
::  +ensure-dirs: make every missing folder from the clanker root (up
::  steps above us) down to `dir`.
++  ensure-dirs
  |=  [up=@ud dir=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  at=path  /
  |-
  ?~  dir  (pure:m ~)
  =/  here=path  (snoc at i.dir)
  ;<  v=view:nexus  bind:m  (peek:io [%| up %| here] ~)
  ;<  ~  bind:m
    ?:  ?=([%ball *] v)  (pure:m ~)
    (make:io [%| up %| here] &+[`[~ ~ %.n ~] ~])
  $(at here, dir t.dir)
::
++  ct-to-path
  |=  ct=@t
  ^-  path
  =/  t=tape  (trip ct)
  =/  idx=(unit @ud)  (find "/" t)
  ?~  idx  ~[ct]
  ~[(crip (scag u.idx t)) (crip (slag +(u.idx) t))]
::
++  guess-content-type
  |=  filename=@t
  ^-  @t
  =/  t=tape  (trip filename)
  =/  idx=(unit @ud)  (find "." (flop t))
  =/  ext=@t
    ?~  idx  ''
    (crip (slag (sub (lent t) u.idx) t))
  ?+  ext  'text/plain'
    %md    'text/markdown'
    %txt   'text/plain'
    %json  'application/json'
    %csv   'text/csv'
    %html  'text/html'
    %svg   'image/svg+xml'
    %xml   'application/xml'
    %hoon  'text/x-hoon'
    %js    'text/javascript'
    %css   'text/css'
  ==
::
++  join-mime
  |=  p=path
  ^-  tape
  ?~  p  "application/octet-stream"
  (trip (rap 3 (join '/' `(list @t)`p)))
--
