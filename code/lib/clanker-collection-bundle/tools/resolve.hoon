/<  tools  /lib/tools.hoon
::  resolve: answer a chat paused on an ask: which pending tool uses run.
::
!:
=<  ^-  tool:tools
    |%
++  name  'resolve'
++  description
  '''
  Answer a chat that is asking: say which of its pending tool uses may
  run. decisions maps each tool_use id (from chat_status) to true (run)
  or false (decline); an id left out runs. allow=true runs them all,
  allow=false declines them all. Then waits for the turn to come to rest
  and returns the status, as send does.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'the clanker, e.g. "/forge/grubbery.clanker"']]
      ['chat' [%string 'the chat name (default "main")']]
      ['decisions' [%object 'tool_use id -> true (run) | false (decline)']]
      ['allow' [%boolean 'run all (true) or decline all (false) pending uses']]
      ['timeout' [%number 'seconds to wait for rest (default 180)']]
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
  =/  timeout=@ud  (fall (bind (deg /timeout so-loose:tools) |=(t=@t (fall (rush t dem) 180))) 180)
  =/  dir=(unit path)  (proj-dir:tools proj)
  ?~  dir  (pure:m [%error 'path must be a clanker path like "/forge/grubbery.clanker"'])
  ;<  up=(unit @ud)  bind:m  collection-up:tools
  ?~  up  (pure:m [%error 'not running inside a clanker collection'])
  ;<  before=(unit json)  bind:m  (chat-status:tools u.up u.dir chat)
  ?~  before  (pure:m [%error 'this chat is not asking'])
  ?.  =('asking' (jstr:tools u.before 'state'))
    (pure:m [%error (crip "this chat is not asking; it is {(trip (jstr:tools u.before 'state'))}")])
  =/  ids=(list @t)
    =/  a  (jget:tools u.before 'asks')
    ?.  ?=([~ %a *] a)  ~
    (murn p.u.a |=(j=json =/(id (jstr:tools j 'id') ?:(=('' id) ~ `id))))
  =/  decisions=json
    =/  given=(unit json)  (~(get by args.st) 'decisions')
    =/  allow=(unit ?)  (deg /allow bo:dejs:format)
    ?^  allow  [%o (malt (turn ids |=(id=@t [id `json`b+u.allow])))]
    ?:  ?=([~ %o *] given)  u.given
    [%o ~]
  ?:  ?=([%o ~] decisions)  (pure:m [%error 'give decisions (id -> true|false) or allow (true|false)'])
  =/  before-n=@ud  =/(e (jget:tools u.before 'events') ?:(?=([~ %n *] e) (fall (rush p.u.e dem) 0) 0))
  ;<  err=(unit tang)  bind:m
    %^  poke-soft:io  [%| u.up %& u.dir %'main.sig']  [/ %json]
    (pairs:enjs:format ~[['action' s+'resolve'] ['chat' s+chat] ['decisions' decisions]])
  ?^  err  (pure:m [%error 'the clanker refused the answer'])
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
