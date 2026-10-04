/<  tools  /lib/tools.hoon
::  list_files: list this clanker's own directory (or a subdir of it).
::  Scoped by construction: the path is relative to the clanker's root,
::  found by neck above the running tool, and never escapes it.
::
!:
=<  ^-  tool:tools
    |%
++  name  'list_files'
++  description
  '''
  List the files in this clanker's own directory: its system.md, config,
  memories/, skills/, chats/ and tools/. path is optional: a subfolder
  relative to the clanker's root, e.g. "memories" or "skills". Folders end
  in "/". Each file shows its type and size.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'optional subfolder, relative to the clanker root']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  sub=(unit @t)   (deg /path so:dejs:format)
  ;<  up=(unit @ud)  bind:m  clanker-up:tools
  ?~  up  (pure:m [%error 'not running inside a clanker'])
  =/  rel=(each path @t)  (rel-path:tools (fall sub ''))
  ?:  ?=(%| -.rel)  (pure:m [%error p.rel])
  ;<  =view:nexus  bind:m  (peek:io [%| u.up %| p.rel] ~)
  ?.  ?=([%ball *] view)
    (pure:m [%error (crip "No such folder: {(trip (fall sub ''))}")])
  =/  subs=(list @ta)  (sort ~(tap in ~(key by dir.ball.view)) aor)
  =/  files=(list [n=@ta desc=tape])
    ?~  fil.ball.view  ~
    %+  sort
      %+  turn  ~(tap by contents.u.fil.ball.view)
      |=  [n=@ta [c=sang:tarball gain=? bang=(unit tang)]]
      ^-  [@ta tape]
      :-  n
      ?:  (is-boom:tarball c)  "(broken)"
      ?.  =(%mime name.p.c)  "[{(trip name.p.c)}]"
      =/  mim=mime  !<(mime (need-vase:tarball c))
      "({(join-mime:tools p.mim)}, {(a-co:co p.q.mim)} bytes)"
    |=([a=[n=@ta *] b=[n=@ta *]] (aor n.a n.b))
  ?:  &(?=(~ subs) ?=(~ files))
    (pure:m [%text 'Empty folder.'])
  =/  head=tape  ?~(p.rel "/" "{(spud p.rel)}/")
  =/  dir-text=tape
    (zing (turn subs |=(d=@ta "\0a  {(trip d)}/")))
  =/  file-text=tape
    (zing (turn files |=([n=@ta d=tape] "\0a  {(trip n)} {d}")))
  (pure:m [%text (crip "{head}{dir-text}{file-text}")])
--
|%
--
