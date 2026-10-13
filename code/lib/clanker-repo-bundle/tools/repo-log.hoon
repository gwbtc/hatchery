/<  tools  /lib/tools.hoon
::  repo_log: the repository's commit history, from the forge's
::  data/ui/commits.json beside the working tree (newest first). Filters
::  are optional: since/until as YYYY-MM-DD, author as a substring of the
::  author name or email, limit as a count.
::
!:
=<  ^-  tool:tools
    |%
++  name  'repo_log'
++  description
  '''
  List the repository's commits, newest first: short hash, date, author
  and subject, with the body when there is one. Optional filters: since
  and until (YYYY-MM-DD, inclusive), author (substring of name or email)
  and limit (default 50).
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['since' [%string 'earliest commit date to include, YYYY-MM-DD']]
      ['until' [%string 'latest commit date to include, YYYY-MM-DD']]
      ['author' [%string 'only commits whose author name or email contains this']]
      ['limit' [%number 'at most this many commits (default 50)']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  since=(unit @da)  (day-of (fall (deg /since so:dejs:format) ''))
  =/  until=(unit @da)  (day-of (fall (deg /until so:dejs:format) ''))
  =/  who=@t  (fall (deg /author so:dejs:format) '')
  =/  limit=@ud  (fall (deg /limit ni:dejs:format) 50)
  ;<  root=(each path @t)  bind:m  repo-root:tools
  ?:  ?=(%| -.root)  (pure:m [%error p.root])
  =/  ui=path  (snoc (snip `path`p.root) %ui)
  ;<  log=(unit json)  bind:m  (read-json-at:tools (snoc ui %'commits.json'))
  ?.  ?&(?=(^ log) ?=([%a *] u.log))
    (pure:m [%error 'this repository has no commit history yet'])
  =/  all=(list json)  p.u.log
  =/  kept=(list json)
    %+  skim  all
    |=  c=json
    =/  at=@da  (when c)
    ?&  ?~(since & (gte at u.since))
        ?~(until & (lth at (add u.until ~d1)))
        ?|  =('' who)
            ?=(^ (find (trip who) (trip (str c 'author'))))
            ?=(^ (find (trip who) (trip (str c 'authorEmail'))))
        ==
    ==
  ?~  kept  (pure:m [%text 'No commits match.'])
  =/  shown=(list json)  (scag limit kept)
  =/  head=tape
    "{(a-co:co (lent all))} commits in the repository, {(a-co:co (lent kept))} match, showing {(a-co:co (lent shown))}\0a"
  (pure:m [%text (crip (weld head (zing (turn shown render))))])
--
|%
::  a commit's field as text ('' when absent or not a string)
++  str
  |=  [c=json key=@t]
  ^-  @t
  ?.  ?=([%o *] c)  ''
  =/  r  (~(get by p.c) key)
  ?:(?=([~ %s *] r) p.u.r '')
::  a commit's author date (written by time:enjs, read by di:dejs)
++  when
  |=  c=json
  ^-  @da
  ?.  ?=([%o *] c)  *@da
  =/  r  (~(get by p.c) 'date')
  ?~  r  *@da
  (fall (mole |.((di:dejs:format u.r))) *@da)
::  YYYY-MM-DD to a date at midnight UTC, ~ when blank or malformed
++  day-of
  |=  t=@t
  ^-  (unit @da)
  ?:  =('' t)  ~
  =/  parts=(unit [y=@ud m=@ud d=@ud])
    %+  rush  t
    ;~((glue hep) dem dem dem)
  ?~  parts  ~
  ?.  &((gte m.u.parts 1) (lte m.u.parts 12) (gte d.u.parts 1) (lte d.u.parts 31))  ~
  `(year [[%.y y.u.parts] m.u.parts d.u.parts 0 0 0 ~])
::  one commit, rendered
++  render
  |=  c=json
  ^-  tape
  =/  at=@da  (when c)
  =/  d=date  (yore at)
  =/  stamp=tape
    "{(a-co:co y.d)}-{(pad (a-co:co m.d))}-{(pad (a-co:co d.t.d))}"
  =/  body=tape  (trip (str c 'body'))
  =/  subject=tape  (trip (str c 'message'))
  =/  rest=tape
    =/  nl=(unit @ud)  (find "\0a" body)
    ?~  nl  ""
    =/  tail=tape  (slag u.nl body)
    =/  tail=tape  |-(?:(?&(?=(^ tail) =('\0a' i.tail)) $(tail t.tail) tail))
    ?~  tail  ""
    "\0a    {(indent tail)}"
  =/  first=tape
    =/  nl=(unit @ud)  (find "\0a" body)
    ?~  body  subject
    ?~  nl  body
    (scag u.nl body)
  "\0a{(trip (str c 'short'))}  {stamp}  {(trip (str c 'author'))}  {first}{rest}\0a"
::  continuation lines of a body, each indented four
++  indent
  |=  t=tape
  ^-  tape
  =|  acc=tape
  |-
  ?~  t  (flop acc)
  ?:  =('\0a' i.t)  $(t t.t, acc (weld "    \0a" acc))
  $(t t.t, acc [i.t acc])
::
++  pad
  |=  t=tape
  ^-  tape
  ?:(=(1 (lent t)) ['0' t] t)
--
