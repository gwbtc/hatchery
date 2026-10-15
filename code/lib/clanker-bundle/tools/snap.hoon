/<  tools  /lib/tools.hoon
::  snap: a picture of the owner's explorer page. Writes a request into
::  the explorer's snaps/ dir ({moment}); the explorer PAGE, the only
::  thing that can see itself, renders the pane showing that moment (or
::  the whole workspace) to a PNG and uploads it beside the request. The
::  tool awaits the PNG, returns it as an image, and clears both files.
::  Calls protocol, like geocode: keep the result road, then ask.
::
=>  |%
    ++  take-news
      |=  =wire
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      |=  input:fiber:nexus
      :+  ~  q.state
      ?+  in  [%skip ~]
        ~              [%wait ~]
        [~ %news * *]  ?:(=(wire wire.u.in) [%done ~] [%skip ~])
      ==
    --
!:
^-  tool:tools
|%
++  name  'snap'
++  description
  '''
  Take a picture of the owner's explorer page as they see it right now.
  moment is optional: the moment a pane shows, spelled as in its navbar
  (a path with its ?args, e.g. "@clanker/projects/stage.clanker/files/stage.layout?follow=1");
  that pane is pictured. With no moment, or one no pane shows, the whole
  workspace is. Fails when no explorer page is open. Use it to check
  your own work when it matters, not on every turn.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['moment' [%string 'optional: the moment (path?args) a pane shows, as spelled in its navbar']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  moment=@t
    =/  v=(unit json)  (~(get by args.st) 'moment')
    ?:(?=([~ %s *] v) p.u.v '')
  ;<  ex=(unit lane:tarball)  bind:m  (resolve-link:io '@explorer')
  ?.  ?=([~ %| *] ex)  (pure:m [%error 'the explorer is not installed'])
  =/  snaps=path  (snoc p.u.ex %snaps)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  id=@t  (scot %uv (end [3 8] eny))
  =/  req-road=road:tarball  [%& %& snaps (crip "{(trip id)}.json")]
  =/  png-road=road:tarball  [%& %& snaps (crip "{(trip id)}.png")]
  ;<  *  bind:m  (keep:io /snap png-road ~)
  ;<  ~  bind:m
    (make:io req-road |+[[[/ %json] (pairs:enjs:format ~[['moment' s+moment]])] ~])
  ::  the page answers within seconds; thirty is "no page is open"
  ;<  got=(unit (unit mime))  bind:m
    %^  (with-timeout:io ,(unit mime))  /snap  ~s30
    =/  m  (fiber:fiber:nexus ,(unit mime))
    =|  tries=@ud
    |-  ^-  form:m
    ;<  ~  bind:m  (take-news /snap)
    ;<  v=view:nexus  bind:m  (peek:io png-road `[/ %mime])
    ?:  &(?=([%file *] v) !(is-boom:tarball sang.v))
      (pure:m `!<(mime (need-vase:tarball sang.v)))
    ?:  (gte tries 20)  (pure:m ~)
    $(tries +(tries))
  ;<  ~  bind:m  (drop:io /snap png-road)
  ;<  *  bind:m  (cull-soft:io req-road)
  ?~  got
    (pure:m [%error 'no picture arrived in 30s: is the explorer page open in a browser?'])
  ?~  u.got
    (pure:m [%error 'the page answered but no picture appeared'])
  ;<  *  bind:m  (cull-soft:io png-road)
  (pure:m [%mime u.u.got])
--
