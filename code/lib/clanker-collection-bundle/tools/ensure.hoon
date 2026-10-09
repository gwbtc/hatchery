/<  tools  /lib/tools.hoon
::  ensure: make a clanker by name (and its chats), or bring an existing
::  one up to date: the collection's ensure protocol, as a tool.
::
!:
=<  ^-  tool:tools
    |%
++  name  'ensure'
++  description
  '''
  Make a clanker in this collection if it does not exist, with its chats,
  or update an existing one's host fields. parent is the category path
  ("/" or "/forge"), name the clanker's name (its directory is
  <name>.clanker). bundle is its tool set: default, kernel, repo, build.
  system is its standing prompt (seeded once). repo is a working tree
  path for repo/build bundles; roads grants extra weir roads
  {peek:[..], make:[..], poke:[..]} ("/dir/" for a subtree, "/dir/file");
  config adds fields to config.json. chats is a list of {name, system,
  policy} seeded once each (policy: {default, allow, ask, deny}).
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['parent' [%string 'category path, e.g. "/" or "/forge"']]
      ['name' [%string 'the clanker name']]
      ['bundle' [%string 'default | kernel | repo | build']]
      ['system' [%string 'standing prompt, seeded once']]
      ['repo' [%string 'working tree path (repo/build bundles)']]
      ['roads' [%object '{peek:[..], make:[..], poke:[..]} extra weir roads']]
      ['config' [%object 'extra config.json fields']]
      ['chats' [%array '[{name, system, policy}] seeded once each']]
  ==
++  required  ~['name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  name=@t  =/(v (~(get by args.st) 'name') ?:(?=([~ %s *] v) p.u.v ''))
  ?:  =('' name)  (pure:m [%error 'name required'])
  ;<  up=(unit @ud)  bind:m  collection-up:tools
  ?~  up  (pure:m [%error 'not running inside a clanker collection'])
  =/  ask=json  [%o (~(put by args.st) 'action' s+'ensure')]
  ;<  err=(unit tang)  bind:m
    (poke-soft:io [%| u.up %& / %'main.sig'] [/ %json] ask)
  ?^  err  (pure:m [%error 'the collection refused the ensure'])
  =/  parent=@t  =/(v (~(get by args.st) 'parent') ?:(?=([~ %s *] v) p.u.v '/'))
  =/  parent=tape  ?:(=("/" (trip parent)) "" (trip parent))
  (pure:m [%text (crip "ensured {parent}/{(trip name)}.clanker")])
--
|%
--
