::  lib/tools: types + shared helpers for tool fibers
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
::
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
::
+$  tool-handler  _*form:(fiber:fiber:nexus ,tool-result)
::  +mimes-to-bole: an (axal (map @ta mime)) dir-import -> a bole subtree,
::  each file laid in as a %hoon source grub. Used to seed a nexus's /code.
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
::  +seed-tools: a tools-nexus mount bole whose own /code holds a source
::  bundle (tools + transitive deps).
::
++  seed-tools
  |=  srcs=(axal (map @ta mime))
  ^-  bole:tarball
  =/  lib-bole=bole:tarball  (mimes-to-bole srcs)
  =/  code-nex=bole:tarball  [`[`[/ %code] ~ %.n ~] (malt ~[[%lib lib-bole]])]
  [`[`[/ %tools] ~ %.n ~] (malt ~[[%code code-nex]])]
::  +merge-boles: overlay `over` onto `base`, OVER winning every conflict.
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
--
