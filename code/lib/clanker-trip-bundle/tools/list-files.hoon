/<  tools  /lib/tools.hoon
::  list_files: the trip's attachment directory (or a subdir of it).
::  Scoped by construction: paths are relative to the trip's files/ and
::  never escape it.
::
!:
^-  tool:tools
|%
++  name  'list_files'
++  description
  '''
  List the files attached to the trip (tickets, notes, images, PDFs the
  owner uploaded or you wrote). path is optional: a subfolder relative to
  the files root, e.g. "tickets". Folders end in "/". Each file shows its
  mime type and size.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'optional subfolder, relative to the files root']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  sub=(unit @t)   (deg /path so:dejs:format)
  ;<  fr=(each path @t)  bind:m  trip-files:tools
  ?:  ?=(%| -.fr)  (pure:m [%error p.fr])
  =/  rel=(each path @t)  (rel-path:tools (fall sub ''))
  ?:  ?=(%| -.rel)  (pure:m [%error p.rel])
  =/  dir=path  (weld p.fr p.rel)
  ;<  =view:nexus  bind:m  (peek:io [%& %| dir] ~)
  ?.  ?=([%ball *] view)
    ?~  p.rel  (pure:m [%text 'No files attached to this trip yet.'])
    (pure:m [%error (crip "No such folder: {(trip (fall sub ''))}")])
  =/  subs=(list @ta)  (sort ~(tap in ~(key by dir.ball.view)) aor)
  =/  files=(list [n=@ta desc=tape])
    ?~  fil.ball.view  ~
    %+  sort
      %+  turn  ~(tap by contents.u.fil.ball.view)
      |=  [n=@ta [c=sang:tarball gain=? bang=(unit tang)]]
      ^-  [@ta tape]
      [n (file-size:tools c)]
    |=([a=[n=@ta *] b=[n=@ta *]] (aor n.a n.b))
  ?:  &(?=(~ subs) ?=(~ files))
    (pure:m [%text 'Empty folder.'])
  =/  head=tape  ?~(p.rel "files/" "files{(spud p.rel)}/")
  =/  dir-text=tape
    (zing (turn subs |=(d=@ta "\0a  {(trip d)}/")))
  =/  file-text=tape
    (zing (turn files |=([n=@ta d=tape] "\0a  {(trip n)} {d}")))
  (pure:m [%text (crip "{head}{dir-text}{file-text}")])
--
