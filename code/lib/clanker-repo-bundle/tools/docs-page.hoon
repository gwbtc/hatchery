/<  tools  /lib/tools.hoon
::  docs_page: a handbook page as the reader shows it. The page's
::  markdown from the working tree, with every ```live fence (a block
::  reference: file, lines, pinned commit) replaced by the code it
::  refers to AS OF ITS PIN, and each block's verdict against HEAD:
::  fresh, drifted, or gone. The resolved blocks come from the forge's
::  own cache for this repo (config "ui": its data/ui directory, where
::  docs-blocks.json is kept per page in document order), so the agent
::  reads exactly what a person reads, pins and drift included.
::
!:
=<  ^-  tool:tools
    |%
++  name  'docs_page'
++  description
  '''
  Read one handbook page the way the docs reader renders it: the page's
  markdown with each live code block expanded to the lines it cites at
  their pinned commit, labelled with the file, the line range, the pin,
  and whether that span is still fresh at HEAD, has drifted, or is gone.
  path is the page's path under .grubbery/docs, as docs.json lists it,
  e.g. "weirs.md" or "grubbery/intro.md". Prefer this over repo_read for
  handbook pages: repo_read shows the raw references, not the code.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'page path under .grubbery/docs, as in docs.json']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  page=(unit @t)  (deg /path so:dejs:format)
  ?~  page  (pure:m [%error 'Missing required argument: path'])
  ;<  cfg=(each json @t)  bind:m  repo-config:tools
  ?:  ?=(%| -.cfg)  (pure:m [%error p.cfg])
  =/  root=(each path @t)  (config-path:tools p.cfg 'repo')
  ?:  ?=(%| -.root)  (pure:m [%error p.root])
  =/  ui=(each path @t)  (config-path:tools p.cfg 'ui')
  ?:  ?=(%| -.ui)  (pure:m [%error p.ui])
  =/  rel=(each path @t)  (rel-path:tools u.page)
  ?:  ?=(%| -.rel)  (pure:m [%error p.rel])
  ?~  p.rel  (pure:m [%error 'path names the docs root, not a page'])
  ;<  txt=(unit @t)  bind:m  (read-text-at:tools (welp p.root (welp /'.grubbery'/docs p.rel)))
  ?~  txt  (pure:m [%error (crip "No such handbook page: {(trip u.page)}")])
  ;<  bl=(unit json)  bind:m  (read-json-at:tools (snoc p.ui %'docs-blocks.json'))
  =/  blocks=(list json)
    ?.  ?=([~ %o *] bl)  ~
    =/  b  (~(get by p.u.bl) u.page)
    ?:(?=([~ %a *] b) p.u.b ~)
  =/  out=tape  (expand (lines:tools u.txt) blocks)
  (pure:m [%text (crip "{(trip u.page)}\0a{out}")])
--
|%
::  +expand: the page's lines with each ```live fence (opened by a line
::  starting "```live", closed by the next "```") replaced by the next
::  resolved block, in document order. A fence past the cached blocks
::  keeps its reference text and says so.
++  expand
  |=  [ls=(list tape) blocks=(list json)]
  ^-  tape
  =|  acc=tape
  |-  ^-  tape
  ?~  ls  acc
  ?.  =("```live" (scag 7 i.ls))
    $(ls t.ls, acc (weld acc "{i.ls}\0a"))
  ::  the fence body: the reference lines up to the closing fence
  =/  body=(list tape)
    =/  rest=(list tape)  t.ls
    =|  b=(list tape)
    |-  ^-  (list tape)
    ?~  rest  (flop b)
    ?:  =("```" (scag 3 i.rest))  (flop b)
    $(rest t.rest, b [i.rest b])
  =/  after=(list tape)
    =/  rest=(list tape)  t.ls
    |-  ^-  (list tape)
    ?~  rest  ~
    ?:  =("```" (scag 3 i.rest))  t.rest
    $(rest t.rest)
  ?~  blocks
    =/  ref=tape  (zing (join "\0a" body))
    $(ls after, acc (weld acc "[live block, unresolved: {ref}]\0a"))
  $(ls after, blocks t.blocks, acc (weld acc (render i.blocks)))
::  +render: one resolved block as a labelled fenced code block.
++  render
  |=  b=json
  ^-  tape
  =/  str  |=(k=@t ^-(tape ?.(?=([%o *] b) "" =/(v (~(get by p.b) k) ?:(?=([~ %s *] v) (trip p.u.v) "")))))
  =/  num  |=(k=@t ^-(tape ?.(?=([%o *] b) "" =/(v (~(get by p.b) k) ?:(?=([~ %n *] v) (trip p.u.v) "")))))
  =/  file=tape  (str 'file')
  =/  short=tape  (str 'short')
  =/  status=tape  (str 'status')
  =/  head=tape  (str 'head')
  =/  from=tape  (num 'from')
  =/  to=tape  (num 'to')
  =/  code=(list tape)
    ?.  ?=([%o *] b)  ~
    =/  v  (~(get by p.b) 'lines')
    ?.  ?=([~ %a *] v)  ~
    (murn p.u.v |=(j=json ?:(?=([%s *] j) `(trip p.j) ~)))
  =/  verdict=tape
    ?:  =("fresh" status)  "fresh: unchanged at HEAD {head}"
    ?:  =("drifted" status)  "DRIFTED: these lines differ at HEAD {head}; the page shows the pinned version"
    ?:  =("gone" status)  "GONE: the span no longer exists at HEAD {head}"
    status
  =/  pin=tape  ?:(=("" short) "HEAD" "commit {short}")
  =/  lang=tape  (lang-of file)
  =/  body=tape  (zing (turn code |=(l=tape "{l}\0a")))
  ;:  weld
    "[live block: {file} lines {from}-{to} at {pin}; {verdict}]\0a"
    "```{lang}\0a"
    body
    "```\0a"
  ==
::  +lang-of: a fence language from the file's extension.
++  lang-of
  |=  file=tape
  ^-  tape
  =/  r=tape  (flop file)
  =/  dot=(unit @ud)  (find "." r)
  ?~  dot  ""
  =/  ext=tape  (flop (scag u.dot r))
  ?:  =("js" ext)  "javascript"
  ext
--
