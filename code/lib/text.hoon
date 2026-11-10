::  text: small operations on cords.
::
|%
::  +from-mime: a file read in as mime, as the text it holds. A /& import
::  arrives as mime; this is its body as a cord.
::
++  from-mime
  |=  =mime
  ^-  @t
  q.q.mime
::  +fill: every `from` in a template replaced with `to`. Cords, so a
::  placeholder like '{{id}}' needs no escaping.
::
++  fill
  |=  [tpl=@t from=@t to=@t]
  ^-  @t
  =/  f=tape  (trip from)
  =/  o=tape  (trip to)
  =/  t=tape  (trip tpl)
  |-  ^-  @t
  =/  i=(unit @ud)  (find f t)
  ?~  i  (crip t)
  $(t :(weld (scag u.i t) o (slag (add u.i (lent f)) t)))
::  +fills: several placeholders filled, in list order.
::
++  fills
  |=  [tpl=@t subs=(list [from=@t to=@t])]
  ^-  @t
  ?~  subs  tpl
  $(tpl (fill tpl i.subs), subs t.subs)
--
