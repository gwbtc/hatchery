/<  tools  /lib/tools.hoon
::  repo_read: read one file of the repository's working tree, whole or
::  a line range. Text comes back with line numbers when a range is
::  asked for; images and PDFs ride to the model as a multimodal block.
::
!:
=<  ^-  tool:tools
    |%
++  name  'repo_read'
++  description
  '''
  Read one file of the repository. path is relative to the repo root,
  e.g. "lib/foo.hoon" or ".grubbery/docs/docs.json". Optional from/to
  (1-based, inclusive) read a line range, numbered. Text files return
  their content; images and PDFs are shown to you directly.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'file path relative to the repo root']]
      ['from' [%number 'first line to read (1-based), optional']]
      ['to' [%number 'last line to read (inclusive), optional']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  rel=(unit @t)  (deg /path so:dejs:format)
  ?~  rel  (pure:m [%error 'Missing required argument: path'])
  =/  from=(unit @ud)  (bind (deg /from so-loose:tools) |=(t=@t (rash t dem)))
  =/  to=(unit @ud)  (bind (deg /to so-loose:tools) |=(t=@t (rash t dem)))
  ;<  root=(each path @t)  bind:m  repo-root:tools
  ?:  ?=(%| -.root)  (pure:m [%error p.root])
  =/  full=(each path @t)  (repo-path:tools p.root u.rel)
  ?:  ?=(%| -.full)  (pure:m [%error p.full])
  ?:  =(p.root p.full)  (pure:m [%error 'path names the repo root, not a file'])
  =/  pp=path  p.full
  ;<  =view:nexus  bind:m  (peek:io [%& %& (snip pp) (rear pp)] ~)
  ?.  ?=([%file *] view)
    (pure:m [%error (crip "No such file in the repo: {(trip u.rel)}")])
  ;<  res=tool-result:tools  bind:m  (render-grub-content:tools view)
  ?:  ?=(%error -.res)  (pure:m res)
  ?:  ?=(%mime -.res)
    ?:  (lte p.q.mime.res 4.000.000)  (pure:m res)
    =/  ct=tape  (join-mime:tools p.mime.res)
    %-  pure:m
    :-  %text
    (crip "{(trip u.rel)}: {ct}, {(a-co:co p.q.mime.res)} bytes, too large to view here.")
  ?:  &(?=(~ from) ?=(~ to))  (pure:m res)
  ::  a line range: the text after render's "[mark: ...]" header line
  =/  all=(list tape)  (lines:tools text.res)
  =/  body=(list tape)  ?~(all ~ t.all)
  =/  total=@ud  (lent body)
  =/  lo=@ud  (max 1 (fall from 1))
  =/  hi=@ud  (min total (fall to total))
  ?:  (gth lo hi)
    (pure:m [%error (crip "{(trip u.rel)} has {(a-co:co total)} lines; nothing in {(a-co:co lo)}-{(a-co:co hi)}")])
  =/  slice=(list tape)  (scag +((sub hi lo)) (slag (dec lo) body))
  =/  numbered=tape
    =/  n=@ud  lo
    =|  acc=tape
    |-  ^-  tape
    ?~  slice  acc
    $(slice t.slice, n +(n), acc (weld acc "{(a-co:co n)}: {i.slice}\0a"))
  (pure:m [%text (crip "{(trip u.rel)} lines {(a-co:co lo)}-{(a-co:co hi)} of {(a-co:co total)}\0a{numbered}")])
--
|%
--
