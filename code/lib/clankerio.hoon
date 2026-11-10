::  clankerio: how a host talks to the clankers. The shapes the clanker
::  collection's `ensure` poke takes, so a host builds its request from
::  named parts instead of nesting json by hand.
::
|%
::  A clanker as its host wants it. +to-json sends it as the collection's
::  ensure: make <parent>/<name>.clanker if it is not there, with its
::  chats, or fold a changed host field into one that is. The bundle is
::  default, kernel, repo, build or trip.
::
::  The roads a host grants its clanker, each spelled as the collection
::  takes it: "/dir/" for a subtree, "/dir/file" for one grub, or named
::  under an app, "@geocode/calls/", "@geocode/main.sig". The collection
::  resolves a name when it grants the road, grants the link it is looked
::  up by along with it, and follows the name if it moves.
::
+$  roads  [peek=(list @t) make=(list @t) poke=(list @t)]
+$  spec
  $:  parent=@t                 ::  category path, "/" or "/forge"
      name=@t                   ::  its directory is <name>.clanker
      bundle=@t                 ::  its tool set
      repo=@t                   ::  a working tree, for the repo and build bundles
      roads=roads               ::  what it reaches beyond its bundle
      system=@t                 ::  its standing prompt, seeded once
      chats=(list json)         ::  +chat each, seeded once
      config=(list [@t json])   ::  extra config.json fields
  ==
::  +ensure: one clanker as its spec says, in the collection linked as
::  @clanker: made if missing, the host's fields folded in if it exists.
::  One soft poke, no peek first and no deadline: a host's weir grants the
::  poke on the collection's main.sig and nothing else, so a peek of it,
::  or the behn timer a deadline needs, would be vetoed and crash the
::  caller. ~ when no collection is linked or the poke never packs.
::
++  ensure
  |=  =spec
  =/  m  (fiber:fiber:nexus ,(unit ~))
  ^-  form:m
  ;<  cl=(unit lane:tarball)  bind:m  (resolve-link:io '@clanker')
  ?.  ?=([~ %| *] cl)  (pure:m ~)
  ;<  res=(unit tang)  bind:m
    (poke-soft:io [%& %& p.u.cl %'main.sig'] [/ %json] (to-json spec))
  (pure:m ?^(res ~ `~))
::  +remove: the clanker <parent>/<name>.clanker, gone from the
::  collection with everything in it. The host that made it owns its
::  life. Same soft poke as +ensure, for the same reasons.
::
++  remove
  |=  [parent=@t name=@t]
  =/  m  (fiber:fiber:nexus ,(unit ~))
  ^-  form:m
  ;<  cl=(unit lane:tarball)  bind:m  (resolve-link:io '@clanker')
  ?.  ?=([~ %| *] cl)  (pure:m ~)
  ;<  res=(unit tang)  bind:m
    %^  poke-soft:io  [%& %& p.u.cl %'main.sig']  [/ %json]
    (pairs:enjs:format ~[['action' s+'remove'] ['parent' s+parent] ['name' s+name]])
  (pure:m ?^(res ~ `~))
::  +to-json: a spec as the collection's main.sig takes it.
::
++  to-json
  |=  req=spec
  ^-  json
  %-  pairs:enjs:format
  :*  ['action' s+'ensure']
      ['parent' s+parent.req]
      ['name' s+name.req]
      ['bundle' s+bundle.req]
      ['system' s+system.req]
      ['repo' s+repo.req]
      ['roads' (pairs:enjs:format ~[['peek' (strs peek.roads.req)] ['make' (strs make.roads.req)] ['poke' (strs poke.roads.req)]])]
      ['chats' a+chats.req]
      ?~  config.req  ~
      ~[['config' (pairs:enjs:format config.req)]]
  ==
::  +chat: one chat a clanker is seeded with, under a policy (+allow, or
::  {default, allow, ask, deny} of your own).
::
++  chat
  |=  [name=@t system=@t policy=json]
  ^-  json
  (pairs:enjs:format ~[['name' s+name] ['system' s+system] ['policy' policy]])
::  +allow: the policy under which a chat's clanker may do everything it
::  asks to.
::
++  allow
  ^-  json
  (pairs:enjs:format ~[['default' s+'allow']])
::  +strs: a list of cords as a json array of strings.
::
++  strs
  |=  l=(list @t)
  ^-  json
  a+(turn l |=(s=@t `json`s+s))
--
