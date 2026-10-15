/<  tools  /lib/tools.hoon
::  write_file: write a text attachment into the trip's files root,
::  creating folders on the way; an existing file is replaced.
::
!:
^-  tool:tools
|%
++  name  'write_file'
++  description
  '''
  Write a text file into the trip's attachments (notes, a packing list, a
  markdown summary, a csv...). path is relative to the files root, e.g.
  "notes.md" or "research/hotels.md"; folders are created as needed.
  Overwrites an existing file. Binary files (images, PDFs) cannot be
  written this way; the owner uploads those from the files tab.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path relative to the files root']]
      ['content' [%string 'the text content']]
  ==
++  required  ~['path' 'content']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  rel=(unit @t)      (deg /path so:dejs:format)
  =/  content=(unit @t)  (deg /content so:dejs:format)
  ?:  |(?=(~ rel) ?=(~ content))
    (pure:m [%error 'Missing required argument'])
  ;<  root=(each path @t)  bind:m  repo-root:tools
  ?:  ?=(%| -.root)  (pure:m [%error p.root])
  =/  parsed=(each path @t)  (rel-path:tools u.rel)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?~  p.parsed  (pure:m [%error 'path names the files root, not a file'])
  =/  full=path  (weld (snoc p.root %files) p.parsed)
  ;<  err=(unit @t)  bind:m  (write-text-at:tools p.root full u.content)
  ?^  err  (pure:m [%error (crip "write failed: {(trip u.err)}")])
  (pure:m [%text (crip "Wrote {(trip u.rel)}")])
--
