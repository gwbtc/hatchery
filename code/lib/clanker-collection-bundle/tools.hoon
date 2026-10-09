::  lib/tools for the clanker COLLECTION's own tools nexus: the shared
::  tool types and helpers every bundle carries, plus the collection
::  helpers at the bottom: +collection-up finds the collection root from
::  a running tool, the json readers address clankers and chats by the
::  same paths the page uses ("/forge/grubbery.clanker", a chat name).
::
|%
+$  tool-result
  $%  [%text text=@t]
      [%error message=@t]
      [%mime =mime]
  ==
+$  tool-state
  $:  tool=@t
      args=(map @t json)
      step=@tas
      data=json
      update=(unit json)
  ==
+$  parameter-type
  $?  %string
      %number
      %boolean
      %array
      %object
  ==
+$  parameter-def
  $:  type=parameter-type
      description=@t
  ==
+$  tool
  $_  ^?
  |%
  ++  name         *@t
  ++  description  *@t
  ++  parameters   *(map @t parameter-def)
  ++  required     *(list @t)
  ++  handler      *tool-handler
  --
+$  tool-handler  _*form:(fiber:fiber:nexus ,tool-result)
++  so-loose
  |=  j=json
  ^-  @t
  ?+  j  (so:dejs:format j)
    [%n *]  p.j
  ==
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
++  seed-tools
  |=  srcs=(axal (map @ta mime))
  ^-  bole:tarball
  =/  lib-bole=bole:tarball  (mimes-to-bole srcs)
  =/  code-nex=bole:tarball  [`[`[/ %code] ~ %.n ~] (malt ~[[%lib lib-bole]])]
  [`[`[/ %tools] ~ %.n ~] (malt ~[[%code code-nex]])]
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
++  strip-hoon
  |=  name=@ta
  ^-  @ta
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?.  (gth len 5)  name
  ?.  =(".hoon" (slag (sub len 5) t))  name
  (crip (scag (sub len 5) t))
++  seg-to-name
  |=  s=@ta
  ^-  @t
  (crip (turn (trip s) |=(c=@tD ?:(=('-' c) '_' c))))
++  name-to-seg
  |=  t=tape
  ^-  @ta
  (crip (turn t |=(c=@tD ?:(=('_' c) '-' c))))
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
++  derive-name
  |=  [sub=path file=@ta]
  ^-  @t
  =/  segs=(list @ta)  (snoc sub (strip-hoon file))
  %-  crip
  %-  zing
  %+  join  "__"
  (turn segs |=(s=@ta (trip (seg-to-name s))))
++  name-to-place
  |=  name=@t
  ^-  [sub=path arm=@ta]
  =/  parts=(list tape)  (split-name (trip name))
  =/  segs=(list @ta)  (turn parts name-to-seg)
  ?~  segs  [~ %$]
  [(snip `(list @ta)`segs) (rear segs)]
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
++  parse-path
  |=  t=@t
  ^-  (each path @t)
  =/  pax=(unit path)  (rush t stap)
  ?~  pax
    [%| (crip "Invalid path: {(trip t)} (must start with /)")]
  [%& u.pax]
++  is-text-blot
  |=  name=@tas
  ^-  ?
  %-  ~(has in `(set @tas)`(sy ~[%json %txt %hoon %html %css %js %csv %xml %md %sig]))
  name
++  norm-mite
  |=  =mite
  ^-  ^mite
  ?.  ?=([@ ~] mite)  mite
  =/  t=tape  (trip i.mite)
  ?~  sl=(find "/" t)  mite
  ~[(crip (scag u.sl t)) (crip (slag +(u.sl) t))]
++  is-text-mime
  |=  =mite
  ^-  ?
  ?~  mite  %.n
  ?:  =('text' i.mite)  %.y
  ?.  =('application' i.mite)  %.n
  ?~  t.mite  %.n
  (~(has in (sy ~['json' 'xml' 'javascript' 'x-javascript' 'ecmascript'])) i.t.mite)
++  is-multimodal-mime
  |=  =mite
  ^-  ?
  ?~  mite  %.n
  ?|  =('image' i.mite)
      =([~['application' 'pdf']] mite)
  ==
++  mite-to-cord
  |=  =mite
  ^-  @t
  (crip (zing (join "/" (turn mite trip))))
++  render-mime
  |=  out=mime
  ^-  tool-result
  =.  p.out  (norm-mite p.out)
  ?:  (is-text-mime p.out)
    [%text (crip (trip q.q.out))]
  ?:  (is-multimodal-mime p.out)
    [%mime out]
  [%text (crip (trip q.q.out))]
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
::  Collection helpers. A tool runs at <collection>/tools/runs/<id>; the
::  tools nexus (neck [/ %tools]) is found by neck, and the collection is
::  the directory it sits in: one step above it.
::
++  collection-up
  =/  m  (fiber:fiber:nexus ,(unit @ud))
  ^-  form:m
  ;<  tools=road:tarball  bind:m  (ancestor-road:io [/ %tools] [%| /])
  ?.  ?=(%| -.tools)  (pure:m ~)
  (pure:m `+(p.p.tools))
::  +proj-dir: a clanker's directory under the collection, from the path
::  the page uses ("/forge/grubbery.clanker"); ~ when malformed.
++  proj-dir
  |=  proj=@t
  ^-  (unit path)
  =/  p=(unit path)  (rush proj stap)
  ?~  p  ~
  `(welp /projects u.p)
++  jget
  |=  [j=json k=@t]
  ^-  (unit json)
  ?.  ?=([%o *] j)  ~
  (~(get by p.j) k)
++  jstr
  |=  [j=json k=@t]
  ^-  @t
  =/  v  (jget j k)
  ?:(?=([~ %s *] v) p.u.v '')
++  read-json-up
  |=  [up=@ud dir=path name=@ta]
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek:io [%| up %& dir name] `[/ %json])
  ?.  ?=([%file *] v)  (pure:m ~)
  ?:  (is-boom:tarball sang.v)  (pure:m ~)
  (pure:m (mole |.(!<(json (need-vase:tarball sang.v)))))
++  read-text-up
  |=  [up=@ud dir=path name=@ta]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  v=view:nexus  bind:m  (peek:io [%| up %& dir name] `[/ %mime])
  ?.  ?=([%file *] v)  (pure:m '')
  ?:  (is-boom:tarball sang.v)  (pure:m '')
  (pure:m `@t`q.q:!<(mime (need-vase:tarball sang.v)))
::  +chat-status: a chat's status.json (written by its clanker on every
::  log change), or ~ when the chat has none yet.
++  chat-status
  |=  [up=@ud dir=path chat=@t]
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  (read-json-up up (welp dir [%chats `@ta`chat ~]) %'status.json')
::  +status-line: one line of a status for a listing.
++  status-line
  |=  st=(unit json)
  ^-  tape
  ?~  st  "(no status yet)"
  =/  state=tape  (trip (jstr u.st 'state'))
  =/  asks=(list json)  =/(a (jget u.st 'asks') ?:(?=([~ %a *] a) p.u.a ~))
  =/  last=tape  (trip (jstr u.st 'last'))
  =/  last=tape  ?:((gth (lent last) 120) (weld (scag 117 last) "...") last)
  ;:  weld
    state
    ?~(asks "" " (asking: {(zing (join ", " (turn asks |=(a=json (trip (jstr a 'name'))))))})")
    ?:(=("" last) "" " | {last}")
  ==
++  is-clanker-seg
  |=  n=@ta
  ^-  ?
  =/  t=tape  (trip n)
  =/  len=@ud  (lent t)
  &((gth len 8) =(".clanker" (slag (sub len 8) t)))
--
