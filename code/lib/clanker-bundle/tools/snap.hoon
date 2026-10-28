/<  tools  /lib/tools.hoon
::  snap: a picture of a gmux session as its attached browser shows it.
::  Finds the session (named, or the one whose spec shows a chat of this
::  clanker), reads its grub (no client attached: fail at once), then
::  writes a request into the explorer's snaps/ dir ({session, moment}).
::  The page attached to that session, the only thing that can see it,
::  renders the pane showing that moment (or the whole workspace) to a
::  PNG, uploads <id>.answer.json saying what it drew, then <id>.png.
::  The tool awaits the PNG, reads the answer, clears all three files,
::  and returns the image, or an error when the asked moment was not on
::  screen. Calls protocol, like geocode: keep the result road, then ask.
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
    ++  jget
      |=  [j=json k=@t]
      ^-  (unit json)
      ?.  ?=([%o *] j)  ~
      (~(get by p.j) k)
    ++  jstr
      |=  [j=json k=@t]
      ^-  @t
      =/  v  (jget j k)
      ?:(?=([~ %s *] v) p.u.v '')
    ++  jflag
      |=  [j=json k=@t]
      ^-  ?
      =/  v  (jget j k)
      ?:(?=([~ %b *] v) p.u.v %.n)
    ::  +clanker-seg: the clanker this tool runs under, by its directory
    ::  name (the innermost *.clanker segment of the run's rail)
    ++  clanker-seg
      |=  pax=path
      ^-  (unit @ta)
      =/  hit=(list @ta)
        %+  skim  pax
        |=  s=@ta
        =/  t=tape  (trip s)
        &((gth (lent t) 8) =(".clanker" (slag (sub (lent t) 8) t)))
      ?~  hit  ~
      `(rear hit)
    ::  +shows-clanker: does a session's spec show a chat of this clanker
    ++  shows-clanker
      |=  [spec=json seg=@ta]
      ^-  ?
      ?=(^ (find "/{(trip seg)}/chats/" (trip (en:json:html spec))))
    --
!:
^-  tool:tools
|%
++  name  'snap'
++  description
  '''
  Take a picture of a gmux session as the browser tab attached to it
  shows it right now. A session is a workspace the ship holds under
  /apps/explorer.explorer/sessions/<name>.json. Exactly one browser tab
  is attached to a session at a time, and that tab draws the picture:
  other tabs on the same session only mirror it and never answer, tabs
  on other sessions never answer, and a session with no tab attached
  cannot be pictured (the call fails at once, naming the session).
  session is optional: without it the session whose workspace shows a
  chat of this clanker is pictured; when none or several do, the call
  fails and names them, and you pass one. moment is optional: the
  moment a pane shows, spelled as in its navbar (a path with its ?args,
  e.g. "@clanker/projects/stage.clanker/chats/main/stage.layout?follow=1");
  that pane alone is pictured, and when no pane in the session shows it
  the call fails rather than picturing something else. With no moment
  the whole workspace is pictured, at the size of the attached tab's
  window. Use it to check your own work when it matters, not on every
  turn.
  '''
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['session' [%string 'optional: the session to picture, by name; omitted, the one showing this clanker']]
      ['moment' [%string 'optional: the moment (path?args) a pane shows, as spelled in its navbar']]
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
  =/  asked=@t
    =/  v=(unit json)  (~(get by args.st) 'session')
    ?:(?=([~ %s *] v) p.u.v '')
  ;<  ex=(unit lane:tarball)  bind:m  (resolve-link:io '@explorer')
  ?.  ?=([~ %| *] ex)  (pure:m [%error 'the explorer is not installed'])
  =/  sessions=path  (snoc p.u.ex %sessions)
  ::  which session: the one named, else the one showing this clanker
  ;<  session=(each @t @t)  bind:m
    =/  m  (fiber:fiber:nexus ,(each @t @t))
    ?.  =('' asked)  (pure:m [%& asked])
    ;<  here=rail:tarball  bind:m  get-here-abs:io
    =/  seg=(unit @ta)  (clanker-seg path.here)
    ?~  seg  (pure:m [%| 'not running inside a clanker; pass session'])
    ;<  dv=view:nexus  bind:m  (peek:io [%& %| sessions] ~)
    ?.  ?=([%ball *] dv)  (pure:m [%| 'no sessions exist; open one at /grubbery/explorer'])
    =/  names=(list @ta)  ~(tap in ~(key by dir.ball.dv))
    =|  hits=(list @t)
    |-  ^-  form:m
    ?~  names
      ?~  hits
        (pure:m [%| (crip "no open workspace shows a chat of {(trip u.seg)}; open the chat's stage tab, or pass session")])
      ?~  t.hits  (pure:m [%& i.hits])
      (pure:m [%| (crip "several workspaces show {(trip u.seg)}: {(zing (join ", " (turn hits trip)))}; pass session")])
    =/  nm=tape  (trip i.names)
    ?.  &((gth (lent nm) 5) =(".json" (slag (sub (lent nm) 5) nm)))  $(names t.names)
    ;<  sv=view:nexus  bind:m  (peek:io [%& %& sessions i.names] `[/ %json])
    ?.  &(?=([%file *] sv) !(is-boom:tarball sang.sv))  $(names t.names)
    =/  ses=json  !<(json (need-vase:tarball sang.sv))
    =/  spec=json  (fall (jget ses 'spec') ~)
    ?.  (shows-clanker spec u.seg)  $(names t.names)
    $(names t.names, hits [(crip (scag (sub (lent nm) 5) nm)) hits])
  ?:  ?=(%| -.session)  (pure:m [%error p.session])
  =/  name=@t  p.session
  ::  the session must have a tab attached, or nobody will answer
  =/  ses-road=road:tarball  [%& %& sessions (crip "{(trip name)}.json")]
  ;<  sv=view:nexus  bind:m  (peek:io ses-road `[/ %json])
  ?.  &(?=([%file *] sv) !(is-boom:tarball sang.sv))
    (pure:m [%error (crip "no such session: {(trip name)}")])
  =/  ses=json  !<(json (need-vase:tarball sang.sv))
  =/  client=json  (fall (jget ses 'client') ~)
  ?:  =('' (jstr client 'id'))
    (pure:m [%error (crip "no browser tab is attached to session {(trip name)}; open it at /grubbery/explorer/s/{(trip name)}")])
  =/  snaps=path  (snoc p.u.ex %snaps)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  id=@t  (scot %uv (end [3 8] eny))
  =/  req-road=road:tarball  [%& %& snaps (crip "{(trip id)}.json")]
  =/  ans-road=road:tarball  [%& %& snaps (crip "{(trip id)}.answer.json")]
  =/  png-road=road:tarball  [%& %& snaps (crip "{(trip id)}.png")]
  ;<  *  bind:m  (keep:io /snap png-road ~)
  ;<  ~  bind:m
    (make:io req-road |+[[[/ %json] (pairs:enjs:format ~[['session' s+name] ['moment' s+moment]])] ~])
  ::  the page answers within seconds; thirty is "the attached tab is not drawing"
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
    (pure:m [%error (crip "no picture arrived in 30s from the tab attached to session {(trip name)} (client {(trip (jstr client 'id'))}); is that tab still open?")])
  ?~  u.got
    (pure:m [%error 'the page answered but no picture appeared'])
  ::  the answer says what the page drew; it was written before the png
  ;<  av=view:nexus  bind:m  (peek:io ans-road `[/ %json])
  =/  ans=json
    ?.  &(?=([%file *] av) !(is-boom:tarball sang.av))  ~
    !<(json (need-vase:tarball sang.av))
  ;<  *  bind:m  (cull-soft:io ans-road)
  ;<  *  bind:m  (cull-soft:io png-road)
  ?:  &(!=('' moment) !(jflag ans 'found'))
    (pure:m [%error (crip "no pane in session {(trip name)} shows {(trip moment)}; nothing was pictured. Snap without a moment to see the whole workspace.")])
  (pure:m [%mime u.u.got])
--
