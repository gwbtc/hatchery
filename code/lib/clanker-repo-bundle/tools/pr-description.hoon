/<  tools  /lib/tools.hoon
::  pr_description: what a pull request says about itself, through the
::  ship's GitHub proxy: title, author, branches, state, and the body
::  the author wrote. The author's argument, kept apart from the diff on
::  purpose: pr_diff gives the hunks.
::
!:
=<  ^-  tool:tools
    |%
++  name  'pr_description'
++  description
  '''
  Fetch a pull request's own account of itself from GitHub: title, author,
  state, base and head branches, and the description the author wrote.
  number is the PR number on this repository. This is the author's
  argument, not evidence: the hunks are read with pr_diff.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['number' [%number 'the pull request number']]
  ==
++  required  ~['number']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  num=(unit @ud)  (bind (deg /number so-loose:tools) |=(t=@t (fall (rush t dem) 0)))
  ?:  |(?=(~ num) =(0 u.num))  (pure:m [%error 'number must be a pull request number'])
  ;<  cfg=(each json @t)  bind:m  repo-config:tools
  ?:  ?=(%| -.cfg)  (pure:m [%error p.cfg])
  =/  repo=(each @t @t)  (github-repo:tools p.cfg)
  ?:  ?=(%| -.repo)  (pure:m [%error p.repo])
  =/  pax=@t  (crip "/repos/{(trip p.repo)}/pulls/{(a-co:co u.num)}")
  ;<  res=(each @t @t)  bind:m  (github-get:tools p.cfg pax '')
  ?:  ?=(%| -.res)  (pure:m [%error p.res])
  =/  pr=json  (fall (de:json:html p.res) *json)
  ?.  ?=([%o *] pr)  (pure:m [%error 'GitHub did not answer with a pull request'])
  =/  str  |=(k=@t ^-(tape =/(v (~(get by p.pr) k) ?:(?=([~ %s *] v) (trip p.u.v) ""))))
  =/  sub  |=([k=@t j=@t] ^-(tape =/(v (~(get by p.pr) k) ?.(?=([~ %o *] v) "" =/(w (~(get by p.u.v) j) ?:(?=([~ %s *] w) (trip p.u.w) ""))))))
  =/  body=tape  (str 'body')
  %-  pure:m
  :-  %text
  %-  crip
  ;:  weld
    "PR #{(a-co:co u.num)} on {(trip p.repo)}: {(str 'title')}\0a"
    "author: {(sub 'user' 'login')}\0a"
    "state: {(str 'state')}; {(sub 'head' 'ref')} into {(sub 'base' 'ref')}\0a"
    "url: {(str 'html_url')}\0a\0a"
    ?:(=("" body) "(no description)\0a" "{body}\0a")
  ==
--
|%
--
