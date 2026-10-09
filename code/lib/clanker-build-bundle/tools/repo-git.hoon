/<  tools  /lib/tools.hoon
::  repo_git: one git command on the repository, through the forge's
::  serial command lane (the repo's run.git-action): poke it the command,
::  wait for the lane to log the outcome, report it. The lane runs one
::  command at a time, so a command queues behind a running one.
::
!:
=<  ^-  tool:tools
    |%
++  name  'repo_git'
++  description
  '''
  Run one git command on the repository through its forge lane and return
  the outcome. command is the git line without "git", e.g. "add",
  "commit -m \"message\"", "push", "pull", "status", "checkout <branch>".
  Stage with "add" before "commit". Commits use the repo's configured
  identity; a push needs the repo's connected account.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['command' [%string 'the git command line, without the leading "git"']]
  ==
++  required  ~['command']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  cmd=(unit @t)  (deg /command so:dejs:format)
  ?~  cmd  (pure:m [%error 'Missing required argument: command'])
  ?:  =('' u.cmd)  (pure:m [%error 'command must not be empty'])
  ;<  root=(each path @t)  bind:m  repo-root:tools
  ?:  ?=(%| -.root)  (pure:m [%error p.root])
  =/  inst=path  (repo-dir:tools p.root)
  =/  lane=road:tarball  [%& %& inst %'run.git-action']
  ::  the newest logged id before we ask, so we know our own outcome
  ;<  before=(unit json)  bind:m  (read-json-at:tools (snoc inst %'run.git-action'))
  =/  last-id=@ud  (newest-id before)
  ;<  err=(unit tang)  bind:m
    (poke-soft:io lane [/ %json] (pairs:enjs:format ~[['command' s+u.cmd]]))
  ?^  err
    =/  why=tape  (trip (of-wain:format (turn (flop u.err) |=(t=tank (crip (zing (wash [0 120] t)))))))
    (pure:m [%error (crip "the git lane refused the command: {why}")])
  ::  wait for an outcome newer than what was logged, up to a few minutes
  ::  (a push or pull talks to github)
  =/  tries=@ud  0
  |-  ^-  form:m
  ?:  (gte tries 240)
    (pure:m [%error (crip "no outcome from the git lane after 4 minutes for: {(trip u.cmd)}")])
  ;<  ~  bind:m  (sleep:io ~s1)
  ;<  now=(unit json)  bind:m  (read-json-at:tools (snoc inst %'run.git-action'))
  =/  hit=(unit [ok=? msg=@t])  (outcome-after now last-id)
  ?~  hit  $(tries +(tries))
  ?.  ok.u.hit  (pure:m [%error (crip "git {(trip u.cmd)}: {(trip msg.u.hit)}")])
  (pure:m [%text (crip "git {(trip u.cmd)}: {(trip msg.u.hit)}")])
--
|%
::  the lane's state as json: {log: [{id, ok, message, ...}], active, queue}
++  log-entries
  |=  j=(unit json)
  ^-  (list json)
  ?~  j  ~
  ?.  ?=([%o *] u.j)  ~
  =/  l  (~(get by p.u.j) 'log')
  ?.  ?=([~ %a *] l)  ~
  p.u.l
++  entry-id
  |=  e=json
  ^-  @ud
  ?.  ?=([%o *] e)  0
  =/  v  (~(get by p.e) 'id')
  ?.  ?=([~ %n *] v)  0
  (fall (rush p.u.v dem) 0)
++  newest-id
  |=  j=(unit json)
  ^-  @ud
  (roll (turn (log-entries j) entry-id) max)
::  +outcome-after: the oldest logged entry newer than `since` (ours, since
::  the lane is serial and we poked after `since` was logged), as [ok msg]
++  outcome-after
  |=  [j=(unit json) since=@ud]
  ^-  (unit [ok=? msg=@t])
  =/  newer=(list json)
    (skim (log-entries j) |=(e=json (gth (entry-id e) since)))
  ?~  newer  ~
  =/  e=json  (rear newer)
  ?.  ?=([%o *] e)  ~
  =/  ok=?  ?=([~ %b %.y] (~(get by p.e) 'ok'))
  =/  msg=@t
    =/  v  (~(get by p.e) 'message')
    ?:(?=([~ %s *] v) p.u.v '')
  `[ok msg]
--
