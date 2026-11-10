::  clankerio: how a host talks to the clankers. The shapes the clanker
::  collection's `ensure` poke takes, so a host builds its request from
::  named parts instead of nesting json by hand.
::
|%
::  A clanker as its host wants it. +to-json sends it as the collection's
::  ensure: make <parent>/<name>.clanker if it is not there, with its
::  chats, or fold a changed host field into one that is. bundle is its
::  tool set (default, kernel, repo, build, trip); system its standing
::  prompt, seeded once; repo a working tree for the repo and build
::  bundles; roads from +roads; chats from +chat, seeded once each; config
::  extra fields for its config.json.
::
+$  spec
  $:  parent=@t
      name=@t
      bundle=@t
      system=@t
      repo=@t
      roads=json
      chats=(list json)
      config=(list [@t json])
  ==
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
      ['roads' roads.req]
      ['chats' a+chats.req]
      ?~  config.req  ~
      ~[['config' (pairs:enjs:format config.req)]]
  ==
::  +roads: a clanker's extra weir roads, {peek, make, poke}, each a list
::  of roads: "/dir/" for a subtree, "/dir/file" for one grub.
::
++  roads
  |=  [peek=(list @t) make=(list @t) poke=(list @t)]
  ^-  json
  (pairs:enjs:format ~[['peek' (strs peek)] ['make' (strs make)] ['poke' (strs poke)]])
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
