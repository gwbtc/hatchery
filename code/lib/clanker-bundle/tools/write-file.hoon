/<  tools  /lib/tools.hoon
::  write_file: write a text file into this clanker's own directory.
::  Missing folders on the way are created; an existing file keeps its
::  blot. tools/ and chats/ are off limits: the engine owns those.
::
!:
=<  ^-  tool:tools
    |%
++  name  'write_file'
++  description
  '''
  Write (create or overwrite) a text file in this clanker's own directory:
  a memory under memories/, a skill under skills/, a note anywhere else.
  path is relative to the clanker's root, e.g. "memories/people.md" or
  "skills/commit-flow.md"; folders are created as needed. You may also
  rewrite system.md, your own standing prompt. tools/ and chats/ cannot be
  written.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path relative to the clanker root']]
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
  ;<  up=(unit @ud)  bind:m  clanker-up:tools
  ?~  up  (pure:m [%error 'not running inside a clanker'])
  =/  parsed=(each path @t)  (rel-path:tools u.rel)
  ?:  ?=(%| -.parsed)  (pure:m [%error p.parsed])
  ?~  p.parsed  (pure:m [%error 'path names the clanker root, not a file'])
  ?:  (reserved:tools p.parsed)
    (pure:m [%error 'tools/ and chats/ belong to the engine; write elsewhere'])
  =/  pp=path    p.parsed
  =/  dir=path   (snip pp)
  =/  fname=@ta  (rear pp)
  =/  road=road:tarball  [%| u.up %& dir fname]
  =/  src-mime=mime
    [(ct-to-path:tools (guess-content-type:tools fname)) (as-octs:mimes:html u.content)]
  ;<  ~  bind:m  (ensure-dirs:tools u.up dir)
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    ;<  cur=view:nexus  bind:m  (peek:io road ~)
    ;<  ~  bind:m
      ?:  ?&(?=([%file *] cur) !=([/ %mime] p.sang.cur))
        (over-as:io road [[/ %mime] src-mime] p.sang.cur)
      (over:io road [[/ %mime] src-mime])
    (pure:m [%text (crip "Updated {(trip u.rel)}")])
  ;<  ~  bind:m  (make:io road |+[[[/ %mime] src-mime] ~])
  (pure:m [%text (crip "Created {(trip u.rel)}")])
--
|%
--
