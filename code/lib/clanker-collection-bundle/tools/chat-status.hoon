/<  tools  /lib/tools.hoon
::  chat_status: one chat's state: idle, busy, asking (with the pending
::  tool uses), or stopped; its policy; its last reply.
::
!:
=<  ^-  tool:tools
    |%
++  name  'chat_status'
++  description
  '''
  The state of one chat of a clanker: idle, busy (a turn is running),
  asking (paused on the user: the pending tool uses are listed with their
  ids, names and inputs, to answer with resolve), or stopped; plus the
  chat's tool policy and its last reply. path is the clanker's path, e.g.
  "/forge/grubbery.clanker"; chat its chat name (default "main").
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
  ;<  status=(unit json)  bind:m  (chat-status:tools u.up u.dir chat)
  ;<  policy=(unit json)  bind:m  (read-json-up:tools u.up (welp u.dir [%chats `@ta`chat ~]) %'tools.json')
  ?~  status
    ;<  cv=view:nexus  bind:m  (peek:io [%| u.up %| (welp u.dir [%chats `@ta`chat ~])] ~)
    ?.  ?=([%ball *] cv)  (pure:m [%error (crip "no chat {(trip chat)} on {(trip proj)}")])
    (pure:m [%text 'idle (no turn has run in this chat yet)'])
  %-  pure:m
  :-  %text
  %-  en:json:html
  %-  pairs:enjs:format
  :~  ['status' u.status]
      ['policy' (fall policy ~)]
  ==
--
|%
--
