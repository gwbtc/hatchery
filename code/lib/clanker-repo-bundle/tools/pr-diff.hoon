/<  tools  /lib/tools.hoon
::  pr_diff: a pull request's diff, as GitHub renders it, through the
::  ship's GitHub proxy. The hunks and nothing else: no title, no
::  description, no comments. What the PR says about itself is
::  pr_description's, and is read separately on purpose.
::
!:
=<  ^-  tool:tools
    |%
++  name  'pr_diff'
++  description
  '''
  Fetch a pull request's diff from GitHub: the unified diff of every file
  it changes, as `git diff` prints it. number is the PR number on this
  repository. Nothing but the hunks: the PR's title, description and
  comments are read with pr_description.
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
  ;<  res=(each @t @t)  bind:m  (github-get:tools p.cfg pax 'application/vnd.github.diff')
  ?:  ?=(%| -.res)  (pure:m [%error p.res])
  ?:  =('' p.res)  (pure:m [%error (crip "PR #{(a-co:co u.num)} has an empty diff")])
  (pure:m [%text (crip "PR #{(a-co:co u.num)} on {(trip p.repo)}, diff:\0a{(trip p.res)}")])
--
|%
--
