/<  tools  /lib/tools.hoon
::  repo_list: list a directory of the repository's working tree. The
::  tree is the one this clanker's config names; path is relative to the
::  repo root and cannot climb out of it.
::
!:
=<  ^-  tool:tools
    |%
++  name  'repo_list'
++  description
  '''
  List a directory of the repository. path is optional and relative to
  the repo root, e.g. "" (the root), "lib" or "desk/gub/nex". Folders
  end in "/"; each file shows its type and size.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'directory, relative to the repo root (default: the root)']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  sub=@t  (fall (deg /path so:dejs:format) '')
  ;<  root=(each path @t)  bind:m  repo-root:tools
  ?:  ?=(%| -.root)  (pure:m [%error p.root])
  =/  full=(each path @t)  (repo-path:tools p.root sub)
  ?:  ?=(%| -.full)  (pure:m [%error p.full])
  ;<  =view:nexus  bind:m  (peek-shallow:io [%& %| p.full] ~)
  ?.  ?=([%ball *] view)
    (pure:m [%error (crip "No such directory in the repo: {(trip sub)}")])
  =/  subs=(list @ta)  (sort ~(tap in ~(key by dir.ball.view)) aor)
  =/  files=(list [n=@ta desc=tape])
    ?~  fil.ball.view  ~
    %+  sort
      %+  turn  ~(tap by contents.u.fil.ball.view)
      |=([n=@ta [c=sang:tarball *]] ^-([@ta tape] [n (file-size:tools c)]))
    |=([a=[n=@ta *] b=[n=@ta *]] (aor n.a n.b))
  ?:  &(?=(~ subs) ?=(~ files))
    (pure:m [%text 'Empty directory.'])
  =/  head=tape  ?:(=('' sub) "/" "{(trip sub)}/")
  =/  dir-text=tape  (zing (turn subs |=(d=@ta "\0a  {(trip d)}/")))
  =/  file-text=tape  (zing (turn files |=([n=@ta d=tape] "\0a  {(trip n)} {d}")))
  (pure:m [%text (crip "{head}{dir-text}{file-text}")])
--
|%
--
