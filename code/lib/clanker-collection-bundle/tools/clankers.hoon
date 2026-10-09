/<  tools  /lib/tools.hoon
::  clankers: the collection's tree: every clanker (with its bundle) and
::  category, by the paths the other tools take.
::
!:
=<  ^-  tool:tools
    |%
++  name  'clankers'
++  description
  '''
  List the clankers in this collection, with their categories. Each
  clanker shows its path (as the other tools take it, e.g.
  "/forge/grubbery.clanker"), its bundle, and its chats with their
  state. A category is a plain directory grouping clankers.
  '''
++  parameters  *(map @t parameter-def:tools)
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  up=(unit @ud)  bind:m  collection-up:tools
  ?~  up  (pure:m [%error 'not running inside a clanker collection'])
  ;<  v=view:nexus  bind:m  (peek:io [%| u.up %| /projects] ~)
  ?.  ?=([%ball *] v)  (pure:m [%text 'No clankers yet.'])
  ::  walk the tree: a dir named <x>.clanker is a clanker (not descended
  ::  into), any other dir a category
  =/  found=(list [proj=path clanker=?])
    =/  todo=(list [p=path b=ball:tarball])  ~[[/ ball.v]]
    =|  out=(list [proj=path clanker=?])
    |-  ^-  (list [proj=path clanker=?])
    ?~  todo  (flop out)
    =/  kids=(list @ta)  (sort ~(tap in ~(key by dir.b.i.todo)) aor)
    =/  [more=(list [p=path b=ball:tarball]) here=(list [proj=path clanker=?])]
      %+  roll  kids
      |=  [k=@ta acc=[more=(list [p=path b=ball:tarball]) here=(list [proj=path clanker=?])]]
      =/  kp=path  (snoc p.i.todo k)
      ?:  (is-clanker-seg:tools k)  acc(here [[kp %.y] here.acc])
      acc(more [[kp (~(got by dir.b.i.todo) k)] more.acc], here [[kp %.n] here.acc])
    $(todo (weld t.todo (flop more)), out (weld here out))
  ;<  lines=(list tape)  bind:m
    =/  mu  (fiber:fiber:nexus ,(list tape))
    =|  acc=(list tape)
    =/  rest=(list [proj=path clanker=?])  found
    |-  ^-  form:mu
    ?~  rest  (pure:mu (flop acc))
    =/  shown=tape  (spud proj.i.rest)
    ?.  clanker.i.rest
      $(rest t.rest, acc ["{shown}/  (category)" acc])
    =/  dir=path  (welp /projects proj.i.rest)
    ;<  cfg=(unit json)  bind:mu  (read-json-up:tools u.up dir %'config.json')
    =/  bundle=tape  ?~(cfg "?" (trip (jstr:tools u.cfg 'bundle')))
    ;<  cv=view:nexus  bind:mu  (peek-shallow:io [%| u.up %| (snoc dir %chats)] ~)
    =/  chats=(list @ta)  ?.(?=([%ball *] cv) ~ (sort ~(tap in ~(key by dir.ball.cv)) aor))
    ;<  chat-lines=(list tape)  bind:mu
      =/  mc  (fiber:fiber:nexus ,(list tape))
      =|  cl=(list tape)
      =/  cs=(list @ta)  chats
      |-  ^-  form:mc
      ?~  cs  (pure:mc (flop cl))
      ;<  st=(unit json)  bind:mc  (chat-status:tools u.up dir `@t`i.cs)
      $(cs t.cs, cl ["    chat {(trip i.cs)}: {(status-line:tools st)}" cl])
    =/  head=tape  "{shown}  (clanker, bundle {bundle})"
    $(rest t.rest, acc (weld (flop chat-lines) [head acc]))
  (pure:m [%text (crip (zing (join "\0a" lines)))])
--
|%
--
