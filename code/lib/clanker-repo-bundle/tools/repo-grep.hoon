/<  tools  /lib/tools.hoon
::  repo_grep: search the repository's working tree for a substring.
::  Case-insensitive, over text files only, optionally under one
::  directory and limited to filenames matching a glob. Reports
::  path:line: text, capped so a broad search stays readable.
::
!:
=<  ^-  tool:tools
    |%
++  name  'repo_grep'
++  description
  '''
  Search the repository's files for a text pattern (a plain substring,
  case-insensitive). Optional path narrows to a directory relative to
  the repo root (e.g. "lib"); optional glob keeps only filenames that
  match (e.g. "*.hoon", "*.md"). Returns path:line: text, at most 200
  hits.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['pattern' [%string 'substring to find (case-insensitive)']]
      ['path' [%string 'directory to search, relative to the repo root (default: whole repo)']]
      ['glob' [%string 'filename glob, e.g. "*.hoon" (default: all text files)']]
  ==
++  required  ~['pattern']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  pat=(unit @t)  (deg /pattern so:dejs:format)
  ?~  pat  (pure:m [%error 'Missing required argument: pattern'])
  ?:  =('' u.pat)  (pure:m [%error 'pattern must not be empty'])
  =/  sub=@t  (fall (deg /path so:dejs:format) '')
  =/  glob=@t  (fall (deg /glob so:dejs:format) '')
  ;<  root=(each path @t)  bind:m  repo-root:tools
  ?:  ?=(%| -.root)  (pure:m [%error p.root])
  =/  full=(each path @t)  (repo-path:tools p.root sub)
  ?:  ?=(%| -.full)  (pure:m [%error p.full])
  ;<  =view:nexus  bind:m  (peek:io [%& %| p.full] ~)
  ?.  ?=([%ball *] view)
    (pure:m [%error (crip "No such directory in the repo: {(trip sub)}")])
  =/  needle=tape  (cass (trip u.pat))
  =/  max=@ud  200
  =/  files=(list [p=path t=@t])  (walk-texts:tools ball.view (slag (lent p.root) p.full))
  =/  hits=(list tape)
    =|  acc=(list tape)
    =/  count=@ud  0
    |-  ^-  (list tape)
    ?~  files  (flop acc)
    ?:  (gte count max)  (flop acc)
    ?.  ?|  =('' glob)
            ?~(p.i.files %.n (glob-match:tools (trip glob) (trip (rear p.i.files))))
        ==
      $(files t.files)
    =/  shown=tape  (zing (join "/" (turn p.i.files trip)))
    =/  ls=(list tape)  (lines:tools t.i.files)
    =/  n=@ud  1
    |-  ^-  (list tape)
    ?~  ls  ^$(files t.files)
    ?:  (gte count max)  ^$(files t.files)
    ?~  (find needle (cass i.ls))  $(ls t.ls, n +(n))
    %=  $
      ls     t.ls
      n      +(n)
      count  +(count)
      acc    ["{shown}:{(a-co:co n)}: {i.ls}" acc]
    ==
  ?~  hits  (pure:m [%text (crip "No matches for \"{(trip u.pat)}\".")])
  =/  more=tape  ?:((gte (lent hits) max) "\0a(capped at {(a-co:co max)} hits; narrow with path or glob)" "")
  (pure:m [%text (crip "{(zing (join "\0a" hits))}{more}")])
--
|%
--
