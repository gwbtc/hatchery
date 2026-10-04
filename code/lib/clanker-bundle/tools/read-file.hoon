/<  tools  /lib/tools.hoon
::  read_file: read one file in this clanker's own directory. Text comes
::  back verbatim; images and PDFs ride to the model as a multimodal block.
::
!:
=<  ^-  tool:tools
    |%
++  name  'read_file'
++  description
  '''
  Read one file in this clanker's own directory. path is relative to the
  clanker's root, e.g. "system.md", "memories/notes.md" or
  "skills/hoon-style.md". Text files return their content; images and PDFs
  are shown to you directly.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path relative to the clanker root']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  rel=(unit @t)   (deg /path so:dejs:format)
  ?~  rel
    (pure:m [%error 'Missing required argument'])
  ;<  up=(unit @ud)  bind:m  clanker-up:tools
  ?~  up  (pure:m [%error 'not running inside a clanker'])
  =/  parsed=(each path @t)  (rel-path:tools u.rel)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?~  p.parsed  (pure:m [%error 'path names the clanker root, not a file'])
  =/  pp=path  p.parsed
  =/  road=road:tarball  [%| u.up %& (snip pp) (rear pp)]
  ;<  =view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] view)
    (pure:m [%error (crip "No such file: {(trip u.rel)}")])
  ;<  res=tool-result:tools  bind:m  (render-grub-content:tools view)
  ?.  ?=(%mime -.res)  (pure:m res)
  ?:  (lte p.q.mime.res 4.000.000)  (pure:m res)
  =/  ct=tape  (join-mime:tools p.mime.res)
  %-  pure:m
  :-  %text
  (crip "{(trip u.rel)}: {ct}, {(a-co:co p.q.mime.res)} bytes, too large to view here.")
--
|%
--
