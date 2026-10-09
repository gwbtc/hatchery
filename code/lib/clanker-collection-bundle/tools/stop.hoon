/<  tools  /lib/tools.hoon
::  stop: interrupt a chat's running turn, or cancel its pending ask.
::
!:
=<  ^-  tool:tools
    |%
++  name  'stop'
++  description
  '''
  Stop one chat of a clanker: a running turn is interrupted, a pending
  ask is cancelled (the model is told its tool calls were stopped).
  path is the clanker, e.g. "/forge/grubbery.clanker"; chat its chat
  name (default "main").
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'the clanker, e.g. "/forge/grubbery.clanker"']]
      ['chat' [%string 'the chat name (default "main")']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  proj=@t  (fall (deg /path so:dejs:format) '')
  =/  chat=@t  =/(c=@t (fall (deg /chat so:dejs:format) '') ?:(=('' c) 'main' c))
  =/  dir=(unit path)  (proj-dir:tools proj)
  ?~  dir  (pure:m [%error 'path must be a clanker path like "/forge/grubbery.clanker"'])
  ;<  up=(unit @ud)  bind:m  collection-up:tools
  ?~  up  (pure:m [%error 'not running inside a clanker collection'])
  ;<  err=(unit tang)  bind:m
    %^  poke-soft:io  [%| u.up %& u.dir %'main.sig']  [/ %json]
    (pairs:enjs:format ~[['action' s+'interrupt'] ['chat' s+chat]])
  ?^  err  (pure:m [%error 'the clanker refused the stop'])
  (pure:m [%text (crip "stopped {(trip proj)} chat {(trip chat)}")])
--
|%
--
