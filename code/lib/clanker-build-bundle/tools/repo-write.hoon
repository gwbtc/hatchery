/<  tools  /lib/tools.hoon
::  repo_write: write one text file in the repository's working tree,
::  whole: created if new (with its directories), replaced if present.
::  The change is to the checkout only; repo_git commits it.
::
!:
=<  ^-  tool:tools
    |%
++  name  'repo_write'
++  description
  '''
  Write a text file in the repository's working tree: the whole content,
  creating the file (and its directories) or replacing it. path is
  relative to the repo root, e.g. "lib/foo.hoon". For a small change to an
  existing file prefer repo_edit. This changes the checkout only; use
  repo_git to stage, commit and push.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path relative to the repo root']]
      ['content' [%string 'the complete new content of the file']]
  ==
++  required  ~['path' 'content']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  rel=(unit @t)  (deg /path so:dejs:format)
  =/  content=(unit @t)  (deg /content so:dejs:format)
  ?~  rel  (pure:m [%error 'Missing required argument: path'])
  ?~  content  (pure:m [%error 'Missing required argument: content'])
  ;<  root=(each path @t)  bind:m  repo-root:tools
  ?:  ?=(%| -.root)  (pure:m [%error p.root])
  =/  full=(each path @t)  (repo-path:tools p.root u.rel)
  ?:  ?=(%| -.full)  (pure:m [%error p.full])
  ?:  =(p.root p.full)  (pure:m [%error 'path names the repo root, not a file'])
  ;<  err=(unit @t)  bind:m  (write-text-at:tools p.root p.full u.content)
  ?^  err  (pure:m [%error (crip "write failed: {(trip u.err)}")])
  (pure:m [%text (crip "Wrote {(trip u.rel)} ({(a-co:co (met 3 u.content))} bytes) to the working tree; not yet committed.")])
--
|%
--
