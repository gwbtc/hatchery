/<  tools  /lib/tools.hoon
::  send: a message to a clanker's chat, and (unless told not to) wait
::  for the turn to come to rest: a reply, an ask for the user, or a stop.
::
!:
=<  ^-  tool:tools
    |%
++  name  'send'
++  description
  '''
  Send a message to one chat of a clanker and wait for the turn to come
  to rest. Returns the chat's status: idle with the reply in `last`;
  asking with the pending tool uses (answer them with resolve); or
  stopped. path is the clanker, e.g. "/forge/grubbery.clanker"; chat its
  chat name (default "main"). wait=false returns at once. timeout is the
  most seconds to wait (default 180).
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'the clanker, e.g. "/forge/grubbery.clanker"']]
      ['chat' [%string 'the chat name (default "main")']]
      ['message' [%string 'the message to send']]
      ['wait' [%boolean 'wait for the turn to come to rest (default true)']]
      ['timeout' [%number 'seconds to wait at most (default 180)']]
  ==
++  required  ~['path' 'message']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  deg  ~(deg jo:json-utils [%o args.st])
  =/  proj=@t  (fall (deg /path so:dejs:format) '')
  =/  chat=@t  =/(c=@t (fall (deg /chat so:dejs:format) '') ?:(=('' c) 'main' c))
  =/  msg=@t  (fall (deg /message so:dejs:format) '')
  =/  wait=?  (fall (deg /wait bo:dejs:format) %.y)
  =/  timeout=@ud  (fall (bind (deg /timeout so-loose:tools) |=(t=@t (fall (rush t dem) 180))) 180)
  ?:  =('' msg)  (pure:m [%error 'message must not be empty'])
  =/  dir=(unit path)  (proj-dir:tools proj)
  ?~  dir  (pure:m [%error 'path must be a clanker path like "/forge/grubbery.clanker"'])
  ;<  up=(unit @ud)  bind:m  collection-up:tools
  ?~  up  (pure:m [%error 'not running inside a clanker collection'])
  ;<  cv=view:nexus  bind:m  (peek:io [%| u.up %| u.dir] ~)
  ?.  ?=([%ball *] cv)  (pure:m [%error (crip "no clanker at {(trip proj)}")])
  ;<  before=(unit json)  bind:m  (chat-status:tools u.up u.dir chat)
  =/  before-n=@ud  ?~(before 0 =/(e (jget:tools u.before 'events') ?:(?=([~ %n *] e) (fall (rush p.u.e dem) 0) 0)))
  ;<  err=(unit tang)  bind:m
    %^  poke-soft:io  [%| u.up %& u.dir %'main.sig']  [/ %json]
    (pairs:enjs:format ~[['chat' s+chat] ['message' s+msg]])
  ?^  err  (pure:m [%error 'the clanker refused the message'])
  ?.  wait  (pure:m [%text 'sent'])
  ::  rest = a status newer than before whose state is not busy
  =/  waited=@ud  0
  |-  ^-  form:m
  ?:  (gte waited timeout)
    ;<  now=(unit json)  bind:m  (chat-status:tools u.up u.dir chat)
    (pure:m [%text (crip "still busy after {(a-co:co timeout)}s: {(status-line:tools now)}")])
  ;<  ~  bind:m  (sleep:io ~s1)
  ;<  now=(unit json)  bind:m  (chat-status:tools u.up u.dir chat)
  =/  n=@ud  ?~(now 0 =/(e (jget:tools u.now 'events') ?:(?=([~ %n *] e) (fall (rush p.u.e dem) 0) 0)))
  ?:  |(?=(~ now) (lte n before-n) =('busy' (jstr:tools u.now 'state')))
    $(waited +(waited))
  (pure:m [%text (en:json:html u.now)])
--
|%
--
