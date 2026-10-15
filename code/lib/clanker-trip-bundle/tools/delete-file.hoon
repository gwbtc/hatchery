/<  tools  /lib/tools.hoon
::  delete_file: remove one attachment (or a whole subfolder) from the
::  trip's files root.
::
!:
^-  tool:tools
|%
++  name  'delete_file'
++  description
  '''
  Delete a file (or a whole subfolder) from the trip's attachments. path
  is relative to the files root, e.g. "old-notes.md" or "drafts". Cannot
  delete the root itself.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file or folder path relative to the files root']]
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
  ;<  fr=(each path @t)  bind:m  trip-files:tools
  ?:  ?=(%| -.fr)  (pure:m [%error p.fr])
  =/  parsed=(each path @t)  (rel-path:tools u.rel)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?~  p.parsed  (pure:m [%error 'refusing to delete the files root'])
  =/  full=path  (weld p.fr p.parsed)
  =/  frail=road:tarball  [%& %& (snip `path`full) (rear full)]
  ;<  exists=?  bind:m  (peek-exists:io frail)
  ?:  exists
    ;<  ~  bind:m  (cull:io frail)
    (pure:m [%text (crip "Deleted {(trip u.rel)}")])
  ;<  dv=view:nexus  bind:m  (peek:io [%& %| full] ~)
  ?.  ?=([%ball *] dv)
    (pure:m [%error (crip "No such file or folder: {(trip u.rel)}")])
  ;<  ~  bind:m  (cull:io [%& %| full])
  (pure:m [%text (crip "Deleted folder {(trip u.rel)}/")])
--
