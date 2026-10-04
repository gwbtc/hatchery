/<  tools  /lib/tools.hoon
::  remember: append one durable note to this clanker's memories. One file
::  per topic under memories/, a dated bullet per note, so the memory is
::  readable as a file and assembled into every later turn.
::
!:
=<  ^-  tool:tools
    |%
++  name  'remember'
++  description
  '''
  Remember something durably: append a dated note to memories/<topic>.md in
  this clanker's own directory. topic is a short kebab-case name
  ("user", "project", "decisions"); note is one or two sentences. Memories
  are read into every later turn, so keep them short and factual. To change
  or remove a memory, read_file and write_file the topic file.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['topic' [%string 'kebab-case topic, becomes memories/<topic>.md']]
      ['note' [%string 'the note to append']]
  ==
++  required  ~['topic' 'note']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  topic=(unit @t)  (deg /topic so:dejs:format)
  =/  note=(unit @t)   (deg /note so:dejs:format)
  ?:  |(?=(~ topic) ?=(~ note))  (pure:m [%error 'Missing required argument'])
  ;<  up=(unit @ud)  bind:m  clanker-up:tools
  ?~  up  (pure:m [%error 'not running inside a clanker'])
  =/  parsed=(each path @t)  (rel-path:tools u.topic)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?.  ?=([@ ~] p.parsed)  (pure:m [%error 'topic must be one name, no slashes'])
  =/  fname=@ta  (crip "{(trip i.p.parsed)}.md")
  =/  road=road:tarball  [%| u.up %& /memories fname]
  ;<  now=@da  bind:m  get-time:io
  =/  stamp=tape  (scow %da (sub now (mod now ~d1)))
  =/  line=@t  (crip "- {stamp} {(trip u.note)}\0a")
  ;<  ~  bind:m  (ensure-dirs:tools u.up /memories)
  ;<  cur=view:nexus  bind:m  (peek:io road ~)
  =/  prior=@t
    ?.  ?=([%file *] cur)  ''
    ?.  =([/ %mime] p.sang.cur)  ''
    =/  mim=mime  !<(mime (need-vase:tarball sang.cur))
    `@t`q.q.mim
  =/  body=@t  (cat 3 prior line)
  =/  src-mime=mime  [/text/markdown (as-octs:mimes:html body)]
  ?:  ?=([%file *] cur)
    ;<  ~  bind:m  (over:io road [[/ %mime] src-mime])
    (pure:m [%text (crip "Remembered in memories/{(trip fname)}")])
  ;<  ~  bind:m  (make:io road |+[[[/ %mime] src-mime] ~])
  (pure:m [%text (crip "Remembered in memories/{(trip fname)} (new)")])
--
|%
--
