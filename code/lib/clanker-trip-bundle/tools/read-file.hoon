/<  tools  /lib/tools.hoon
::  read_file: read one attachment of the trip. Text files come back
::  verbatim; images and PDFs ride to the model as a multimodal block.
::
!:
=<  ^-  tool:tools
    |%
++  name  'read_file'
++  description
  '''
  Read a file attached to the trip. path is relative to the files root,
  e.g. "notes.md" or "tickets/train.pdf". Text files return their
  content; images and PDFs are shown to you directly.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path relative to the files root']]
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
  ?~  p.parsed  (pure:m [%error 'path names the files root, not a file'])
  =/  full=path  (weld p.fr p.parsed)
  ;<  =view:nexus  bind:m  (peek:io [%& %& (snip `path`full) (rear full)] ~)
  ?.  ?=([%file *] view)
    (pure:m [%error (crip "No such file: {(trip u.rel)}")])
  ;<  res=tool-result:tools  bind:m  (render-grub-content:tools view)
  ?.  ?=(%mime -.res)  (pure:m res)
  ?:  (lte p.q.mime.res 4.000.000)
    ::  phones mislabel: trust the bytes over the stored type
    (pure:m [%mime (sniff-mite p.mime.res q.mime.res) q.mime.res])
  =/  ct=tape  (join-mime:tools p.mime.res)
  %-  pure:m
  :-  %text
  (crip "{(trip u.rel)}: {ct}, {(a-co:co p.q.mime.res)} bytes, too large to view here.")
--
|%
++  sniff-mite
  |=  [fallback=mite =octs]
  ^-  mite
  =/  b  |=(i=@ud ^-(@ (cut 3 [i 1] q.octs)))
  ?:  (lth p.octs 12)  fallback
  ?:  &(=(0x89 (b 0)) =('P' (b 1)) =('N' (b 2)) =('G' (b 3)))  /image/png
  ?:  &(=(0xff (b 0)) =(0xd8 (b 1)) =(0xff (b 2)))  /image/jpeg
  ?:  &(=('G' (b 0)) =('I' (b 1)) =('F' (b 2)) =('8' (b 3)))  /image/gif
  ?:  &(=('R' (b 0)) =('I' (b 1)) =('F' (b 2)) =('F' (b 3)) =('W' (b 8)) =('E' (b 9)) =('B' (b 10)) =('P' (b 11)))
    /image/webp
  ?:  &(=('%' (b 0)) =('P' (b 1)) =('D' (b 2)) =('F' (b 3)))  /application/pdf
  fallback
--
