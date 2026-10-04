/<  tools  /lib/tools.hoon
::  delete_file: delete a file or folder in this clanker's own directory.
::  The root, tools/ and chats/ cannot be deleted.
::
!:
=<  ^-  tool:tools
    |%
++  name  'delete_file'
++  description
  '''
  Delete a file or a whole subfolder in this clanker's own directory. path
  is relative to the clanker's root, e.g. "memories/old.md". The root,
  tools/ and chats/ cannot be deleted.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file or folder path relative to the clanker root']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  rel=(unit @t)   (deg /path so:dejs:format)
  ?~  rel  (pure:m [%error 'Missing required argument'])
  ;<  up=(unit @ud)  bind:m  clanker-up:tools
  ?~  up  (pure:m [%error 'not running inside a clanker'])
  =/  parsed=(each path @t)  (rel-path:tools u.rel)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?~  p.parsed  (pure:m [%error 'cannot delete the clanker root'])
  ?:  (reserved:tools p.parsed)
    (pure:m [%error 'tools/ and chats/ belong to the engine'])
  =/  pp=path  p.parsed
  =/  file-road=road:tarball  [%| u.up %& (snip pp) (rear pp)]
  =/  dir-road=road:tarball   [%| u.up %| pp]
  ;<  fv=view:nexus  bind:m  (peek:io file-road ~)
  ?:  ?=([%file *] fv)
    ;<  *  bind:m  (cull-soft:io file-road)
    (pure:m [%text (crip "Deleted {(trip u.rel)}")])
  ;<  dv=view:nexus  bind:m  (peek:io dir-road ~)
  ?:  ?=([%ball *] dv)
    ;<  *  bind:m  (cull-soft:io dir-road)
    (pure:m [%text (crip "Deleted folder {(trip u.rel)}/")])
  (pure:m [%error (crip "No such file or folder: {(trip u.rel)}")])
--
|%
--
